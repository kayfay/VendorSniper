print("✅ VendorSniper core.lua loaded")

-- Initialize addon namespace
VendorSniper = VendorSniper or {}

-- Configuration
VendorSniper.Config = {
    minProfitThreshold = 1, -- Minimum profit in copper to show item
    maxItemsToShow = 50,    -- Maximum items to display
    scanDelay = 0.5,        -- Delay between pages
    itemsPerPage = 50,      -- Items per page (Classic default)
    debugMode = false,      -- Enable detailed debugging output (disabled by default)
    maxWaitTime = 5.0,      -- Maximum time to wait for auction data (increased from 2.0)
    retryAttempts = 3,      -- Number of retry attempts for failed queries
    
    -- NEW: Improved search configuration
    searchStrategy = "smart", -- "broad", "smart", "targeted"
    minItemQuality = 1,     -- Minimum item quality to scan (1=Common, 2=Uncommon, 3=Rare, 4=Epic, 5=Legendary)
    maxItemQuality = 5,     -- Maximum item quality to scan
    minItemLevel = 1,       -- Minimum item level to scan
    maxItemLevel = 60,      -- Maximum item level to scan (Classic cap)
    includeConsumables = true, -- Include potions, food, etc.
    includeMaterials = true,   -- Include crafting materials
    includeEquipment = true,   -- Include armor/weapons
    includeTradeGoods = true,  -- Include trade goods
    
    -- NEW: Profit calculation improvements
    considerStackSize = true,  -- Consider stack size in profit calculations
    minProfitPercent = 5.0,   -- Minimum profit percentage (5% = 5.0)
    maxBuyoutPrice = 1000000, -- Maximum buyout price to consider (1 gold = 10000 copper)
    
    -- NEW: Search optimization
    useItemCategories = true, -- Use item categories for targeted searches
    searchBatchSize = 10,     -- Number of item categories to search per batch
    categorySearchDelay = 1.0, -- Delay between category searches
    
    -- NEW: Performance settings
    enableCaching = true,     -- Cache vendor prices to reduce API calls
    cacheTimeout = 300,       -- Cache timeout in seconds (5 minutes)
    maxConcurrentQueries = 1, -- Maximum concurrent auction queries
    queryThrottle = 0.2,      -- Minimum time between queries
}

-- Data storage
VendorSniper.ScanData = {}
VendorSniper.IsScanning = false
VendorSniper.CurrentPage = 0
VendorSniper.TotalPages = 0
VendorSniper.ItemsProcessed = 0
VendorSniper.ProgressCallback = nil
VendorSniper.ScanFrame = nil
VendorSniper.ScanState = "idle" -- idle, searching, processing, complete
VendorSniper.EstimatedTotalPages = 0 -- Dynamic estimate of total pages
VendorSniper.RepeatedDataCount = 0 -- Track repeated data
VendorSniper.LastFirstItemName = "" -- Track last first item name
VendorSniper.WaitingForData = false -- Track if we're waiting for auction data
VendorSniper.LastQueryTime = 0 -- Track when we last queried

-- NEW: Improved data storage
VendorSniper.VendorPriceCache = {} -- Cache for vendor prices
VendorSniper.CacheTimestamps = {} -- Timestamps for cache entries
VendorSniper.SearchCategories = {} -- Item categories to search
VendorSniper.CurrentCategory = 1 -- Current category being searched
VendorSniper.CategorySearchState = "idle" -- idle, searching, complete
VendorSniper.LastQueryTimestamp = 0 -- Timestamp of last query for throttling
VendorSniper.ProfitableItemsFound = 0 -- Count of profitable items found
VendorSniper.TotalItemsScanned = 0 -- Total items scanned across all categories
VendorSniper.SearchStartTime = 0 -- When the search started
VendorSniper.CategoryResults = {} -- Results per category for analysis

-- Utility functions
function VendorSniper:GetVendorPrice(itemID)
    -- Check cache first if enabled
    if self.Config.enableCaching and self.VendorPriceCache[itemID] then
        local timestamp = self.CacheTimestamps[itemID] or 0
        if GetTime() - timestamp < self.Config.cacheTimeout then
            return self.VendorPriceCache[itemID]
        else
            -- Cache expired, remove it
            self.VendorPriceCache[itemID] = nil
            self.CacheTimestamps[itemID] = nil
        end
    end
    
    -- Try to get vendor price from BetterVendorPrice if available
    local vendorPrice = nil
    
    -- Method 1: BetterVendorPrice object (most common)
    if BetterVendorPrice and type(BetterVendorPrice) == "table" then
        if BetterVendorPrice.GetVendorPrice then
            vendorPrice = BetterVendorPrice:GetVendorPrice(itemID)
        elseif BetterVendorPrice.GetVendorPriceByItemID then
            vendorPrice = BetterVendorPrice:GetVendorPriceByItemID(itemID)
        elseif BetterVendorPrice.GetVendorPriceByItemLink then
            -- Some versions use item links
            local itemLink = select(2, GetItemInfo(itemID))
            if itemLink then
                vendorPrice = BetterVendorPrice:GetVendorPriceByItemLink(itemLink)
            end
        end
    end
    
    -- Method 2: BVP namespace (alternative)
    if not vendorPrice and BVP and BVP.GetVendorPrice then
        vendorPrice = BVP:GetVendorPrice(itemID)
    end
    
    -- Method 3: Global function (fallback)
    if not vendorPrice and _G.GetVendorPrice then
        vendorPrice = _G.GetVendorPrice(itemID)
    end
    
    -- Method 4: Direct API call as last resort (not recommended, but available)
    if not vendorPrice then
        local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemID)
        if sellPrice and sellPrice > 0 then
            vendorPrice = sellPrice
        end
    end
    
    -- Cache the result if enabled and we got a price
    if self.Config.enableCaching and vendorPrice and vendorPrice > 0 then
        self.VendorPriceCache[itemID] = vendorPrice
        self.CacheTimestamps[itemID] = GetTime()
    end
    
    -- Debug output for first few items to see what's happening
    if self.Config.debugMode or (self.ItemsProcessed and self.ItemsProcessed < 10) then
        if vendorPrice and vendorPrice > 0 then
            print(string.format("💰 BetterVendorPrice returned vendor price for item %d: %s", itemID, self:FormatMoney(vendorPrice)))
        else
            print(string.format("⚠️ BetterVendorPrice returned nil/zero for item %d", itemID))
            
            -- Try to get item name for better debugging
            local itemName = GetItemInfo(itemID)
            if itemName then
                print(string.format("   Item name: %s", itemName))
            end
        end
    end
    return vendorPrice
end

-- NEW: Enhanced BetterVendorPrice integration check
function VendorSniper:CheckBetterVendorPriceIntegration()
    local integrationStatus = {
        found = false,
        method = "none",
        version = "unknown",
        working = false
    }
    
    -- Check BetterVendorPrice object
    if BetterVendorPrice and type(BetterVendorPrice) == "table" then
        integrationStatus.found = true
        integrationStatus.method = "BetterVendorPrice object"
        
        if BetterVendorPrice.GetVendorPrice then
            integrationStatus.working = true
            integrationStatus.version = "standard"
        elseif BetterVendorPrice.GetVendorPriceByItemID then
            integrationStatus.working = true
            integrationStatus.version = "itemID method"
        elseif BetterVendorPrice.GetVendorPriceByItemLink then
            integrationStatus.working = true
            integrationStatus.version = "itemLink method"
        end
    end
    
    -- Check BVP namespace
    if not integrationStatus.working and BVP and BVP.GetVendorPrice then
        integrationStatus.found = true
        integrationStatus.method = "BVP namespace"
        integrationStatus.working = true
        integrationStatus.version = "BVP namespace"
    end
    
    -- Check global function
    if not integrationStatus.working and _G.GetVendorPrice then
        integrationStatus.found = true
        integrationStatus.method = "Global function"
        integrationStatus.working = true
        integrationStatus.version = "global function"
    end
    
    return integrationStatus
end

-- NEW: Test BetterVendorPrice with specific items
function VendorSniper:TestBetterVendorPriceIntegration()
    print("🧪 Testing BetterVendorPrice Integration...")
    
    local integration = self:CheckBetterVendorPriceIntegration()
    
    if not integration.found then
        print("❌ BetterVendorPrice not found!")
        print("Please install BetterVendorPrice addon for optimal functionality.")
        return false
    end
    
    if not integration.working then
        print("⚠️ BetterVendorPrice found but not working properly")
        print(string.format("Method: %s", integration.method))
        return false
    end
    
    print(string.format("✅ BetterVendorPrice found and working!"))
    print(string.format("Method: %s", integration.method))
    print(string.format("Version: %s", integration.version))
    
    -- Test with some common items
    local testItems = {
        {id = 17771, name = "Elementium Bar"},
        {id = 16799, name = "Arcanist Bindings"},
        {id = 12359, name = "Thorium Bar"},
        {id = 12360, name = "Arcanite Bar"},
        {id = 16802, name = "Arcanist Belt"}
    }
    
    local successCount = 0
    for _, item in ipairs(testItems) do
        local vendorPrice = self:GetVendorPrice(item.id)
        if vendorPrice and vendorPrice > 0 then
            successCount = successCount + 1
            print(string.format("✅ %s (ID: %d) - %s", item.name, item.id, self:FormatMoney(vendorPrice)))
        else
            print(string.format("❌ %s (ID: %d) - No vendor price", item.name, item.id))
        end
    end
    
    print(string.format("📊 Test Results: %d/%d items had vendor prices", successCount, #testItems))
    
    if successCount == 0 then
        print("⚠️ WARNING: No vendor prices found! BetterVendorPrice may not be working properly.")
        return false
    end
    
    return true
end

-- NEW: Improved profit calculation with stack size consideration
function VendorSniper:CalculateProfit(auctionPrice, vendorPrice, stackSize, itemQuality, itemLevel)
    if not vendorPrice or vendorPrice <= 0 then
        if self.Config.debugMode then
            print(string.format("⚠️ Invalid vendor price: %s", vendorPrice or "nil"))
        end
        return nil
    end
    
    -- Apply quality and level filters
    if itemQuality and (itemQuality < self.Config.minItemQuality or itemQuality > self.Config.maxItemQuality) then
        return nil
    end
    
    if itemLevel and (itemLevel < self.Config.minItemLevel or itemLevel > self.Config.maxItemLevel) then
        return nil
    end
    
    -- Calculate profit per item (auction price should be lower than vendor price for profit)
    local profitPerItem = vendorPrice - auctionPrice
    
    if profitPerItem <= 0 then
        return nil
    end
    
    -- Calculate total profit considering stack size
    local totalProfit = profitPerItem
    if self.Config.considerStackSize and stackSize and stackSize > 1 then
        totalProfit = profitPerItem * stackSize
    end
    
    -- Calculate profit percentage
    local profitPercent = (profitPerItem / auctionPrice) * 100
    
    -- Apply minimum profit percentage filter
    if profitPercent < self.Config.minProfitPercent then
        return nil
    end
    
    -- Apply maximum buyout price filter
    if auctionPrice > self.Config.maxBuyoutPrice then
        return nil
    end
    
    if self.Config.debugMode then
        print(string.format("💰 Profit calculation: Vendor %s - Auction %s = %s per item (%.1f%%)", 
            self:FormatMoney(vendorPrice), self:FormatMoney(auctionPrice), 
            self:FormatMoney(profitPerItem), profitPercent))
        
        if stackSize and stackSize > 1 then
            print(string.format("   Stack size: %d, Total profit: %s", stackSize, self:FormatMoney(totalProfit)))
        end
        
        print(string.format("✅ Profitable item found! Profit: %s (%.1f%%)", 
            self:FormatMoney(totalProfit), profitPercent))
    end
    
    return {
        profitPerItem = profitPerItem,
        totalProfit = totalProfit,
        profitPercent = profitPercent,
        stackSize = stackSize or 1
    }
end

-- NEW: Item filtering function
function VendorSniper:ShouldProcessItem(itemName, itemQuality, itemLevel, itemClass, itemSubClass)
    -- Quality filter
    if itemQuality and (itemQuality < self.Config.minItemQuality or itemQuality > self.Config.maxItemQuality) then
        return false
    end
    
    -- Level filter
    if itemLevel and (itemLevel < self.Config.minItemLevel or itemLevel > self.Config.maxItemLevel) then
        return false
    end
    
    -- Category filters based on item class and subclass
    if itemClass then
        if itemClass == 0 then -- Consumable
            if not self.Config.includeConsumables then
                return false
            end
        elseif itemClass == 1 then -- Container
            return false -- Skip containers
        elseif itemClass == 2 then -- Weapon
            if not self.Config.includeEquipment then
                return false
            end
        elseif itemClass == 3 then -- Jewelry
            if not self.Config.includeEquipment then
                return false
            end
        elseif itemClass == 4 then -- Armor
            if not self.Config.includeEquipment then
                return false
            end
        elseif itemClass == 5 then -- Reagent
            if not self.Config.includeMaterials then
                return false
            end
        elseif itemClass == 6 then -- Ammunition
            return false -- Skip ammunition
        elseif itemClass == 7 then -- Trade Goods
            if not self.Config.includeTradeGoods then
                return false
            end
        elseif itemClass == 8 then -- Generic
            return false -- Skip generic items
        elseif itemClass == 9 then -- Recipe
            return false -- Skip recipes
        elseif itemClass == 10 then -- Money
            return false -- Skip money
        elseif itemClass == 11 then -- Quiver
            return false -- Skip quivers
        elseif itemClass == 12 then -- Quest
            return false -- Skip quest items
        end
    end
    
    return true
end

-- NEW: Initialize search categories for targeted searching
function VendorSniper:InitializeSearchCategories()
    self.SearchCategories = {}
    
    if self.Config.searchStrategy == "broad" then
        -- Single broad search
        table.insert(self.SearchCategories, {
            name = "All Items",
            classIndex = 0,
            subclassIndex = 0,
            minLevel = self.Config.minItemLevel,
            maxLevel = self.Config.maxItemLevel
        })
    elseif self.Config.searchStrategy == "smart" then
        -- Smart category-based search focusing on most profitable items
        if self.Config.includeMaterials then
            table.insert(self.SearchCategories, {
                name = "Crafting Materials",
                classIndex = 7, -- Trade Goods
                subclassIndex = 0,
                minLevel = self.Config.minItemLevel,
                maxLevel = self.Config.maxItemLevel
            })
        end
        
        if self.Config.includeConsumables then
            table.insert(self.SearchCategories, {
                name = "Consumables",
                classIndex = 0, -- Consumable
                subclassIndex = 0,
                minLevel = self.Config.minItemLevel,
                maxLevel = self.Config.maxItemLevel
            })
        end
        
        if self.Config.includeEquipment then
            table.insert(self.SearchCategories, {
                name = "Equipment",
                classIndex = 2, -- Weapon
                subclassIndex = 0,
                minLevel = self.Config.minItemLevel,
                maxLevel = self.Config.maxItemLevel
            })
            
            table.insert(self.SearchCategories, {
                name = "Armor",
                classIndex = 4, -- Armor
                subclassIndex = 0,
                minLevel = self.Config.minItemLevel,
                maxLevel = self.Config.maxItemLevel
            })
        end
    elseif self.Config.searchStrategy == "targeted" then
        -- Very targeted search for specific high-value categories
        table.insert(self.SearchCategories, {
            name = "High-Value Materials",
            classIndex = 7, -- Trade Goods
            subclassIndex = 0,
            minLevel = 40, -- Focus on higher level materials
            maxLevel = self.Config.maxItemLevel
        })
        
        table.insert(self.SearchCategories, {
            name = "Rare Consumables",
            classIndex = 0, -- Consumable
            subclassIndex = 0,
            minLevel = 30, -- Focus on higher level consumables
            maxLevel = self.Config.maxItemLevel
        })
    elseif self.Config.searchStrategy == "deep" then
        -- Deep scan - search ALL item categories (comprehensive but slow)
        print("⚠️ Deep scan selected - this will take significantly longer but will find ALL profitable items")
        
        -- Search all major item categories
        table.insert(self.SearchCategories, {
            name = "All Consumables",
            classIndex = 0, -- Consumable
            subclassIndex = 0,
            minLevel = self.Config.minItemLevel,
            maxLevel = self.Config.maxItemLevel
        })
        
        table.insert(self.SearchCategories, {
            name = "All Containers",
            classIndex = 1, -- Container
            subclassIndex = 0,
            minLevel = self.Config.minItemLevel,
            maxLevel = self.Config.maxItemLevel
        })
        
        table.insert(self.SearchCategories, {
            name = "All Weapons",
            classIndex = 2, -- Weapon
            subclassIndex = 0,
            minLevel = self.Config.minItemLevel,
            maxLevel = self.Config.maxItemLevel
        })
        
        table.insert(self.SearchCategories, {
            name = "All Jewelry",
            classIndex = 3, -- Jewelry
            subclassIndex = 0,
            minLevel = self.Config.minItemLevel,
            maxLevel = self.Config.maxItemLevel
        })
        
        table.insert(self.SearchCategories, {
            name = "All Armor",
            classIndex = 4, -- Armor
            subclassIndex = 0,
            minLevel = self.Config.minItemLevel,
            maxLevel = self.Config.maxItemLevel
        })
        
        table.insert(self.SearchCategories, {
            name = "All Reagents",
            classIndex = 5, -- Reagent
            subclassIndex = 0,
            minLevel = self.Config.minItemLevel,
            maxLevel = self.Config.maxItemLevel
        })
        
        table.insert(self.SearchCategories, {
            name = "All Ammunition",
            classIndex = 6, -- Ammunition
            subclassIndex = 0,
            minLevel = self.Config.minItemLevel,
            maxLevel = self.Config.maxItemLevel
        })
        
        table.insert(self.SearchCategories, {
            name = "All Trade Goods",
            classIndex = 7, -- Trade Goods
            subclassIndex = 0,
            minLevel = self.Config.minItemLevel,
            maxLevel = self.Config.maxItemLevel
        })
        
        table.insert(self.SearchCategories, {
            name = "All Generic",
            classIndex = 8, -- Generic
            subclassIndex = 0,
            minLevel = self.Config.minItemLevel,
            maxLevel = self.Config.maxItemLevel
        })
        
        table.insert(self.SearchCategories, {
            name = "All Recipes",
            classIndex = 9, -- Recipe
            subclassIndex = 0,
            minLevel = self.Config.minItemLevel,
            maxLevel = self.Config.maxItemLevel
        })
        
        table.insert(self.SearchCategories, {
            name = "All Quivers",
            classIndex = 11, -- Quiver
            subclassIndex = 0,
            minLevel = self.Config.minItemLevel,
            maxLevel = self.Config.maxItemLevel
        })
        
        table.insert(self.SearchCategories, {
            name = "All Quest Items",
            classIndex = 12, -- Quest
            subclassIndex = 0,
            minLevel = self.Config.minItemLevel,
            maxLevel = self.Config.maxItemLevel
        })
    end
    
    print(string.format("📋 Initialized %d search categories for '%s' strategy", 
        #self.SearchCategories, self.Config.searchStrategy))
end

-- NEW: Clear cache function
function VendorSniper:ClearCache()
    self.VendorPriceCache = {}
    self.CacheTimestamps = {}
    print("🗑️ Vendor price cache cleared")
end

-- NEW: Get cache statistics
function VendorSniper:GetCacheStats()
    local cacheSize = 0
    for _ in pairs(self.VendorPriceCache) do
        cacheSize = cacheSize + 1
    end
    
    return {
        size = cacheSize,
        enabled = self.Config.enableCaching,
        timeout = self.Config.cacheTimeout
    }
end

function VendorSniper:FormatMoney(amount)
    if not amount then return "0c" end
    
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    
    if gold > 0 then
        return string.format("%dg %ds %dc", gold, silver, copper)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, copper)
    else
        return string.format("%dc", copper)
    end
end

-- Function to check if auction house is ready
function VendorSniper:IsAuctionHouseReady()
    if not AuctionFrame or not AuctionFrame:IsVisible() then
        return false, "Auction House not open"
    end
    
    -- Check if we're on VendorSniper tab (Browse tab will be hidden)
    local vendorSniperTab = nil
    for i = 1, AuctionFrame.numTabs do
        local tab = AuctionFrame["tab"..i]
        if tab and tab:GetText() == "VendorSniper" then
            vendorSniperTab = tab
            break
        end
    end
    
    -- If we're on VendorSniper tab, we need to switch to Browse tab first
    if vendorSniperTab and PanelTemplates_GetSelectedTab(AuctionFrame) == vendorSniperTab:GetID() then
        return false, "Need to switch to Browse tab first"
    end
    
    -- Check if Browse tab is visible (only if we're not on VendorSniper tab)
    if not AuctionFrameBrowse or not AuctionFrameBrowse:IsVisible() then
        return false, "Not on Browse tab"
    end
    
    local browseButton = _G["BrowseSearchButton"]
    if not browseButton then
        return false, "Browse button not found"
    end
    
    return true, "Ready"
end

function VendorSniper:StartScan()
    if self.IsScanning then
        print("⚠️ VendorSniper: Scan already in progress")
        return
    end
    
    print("🔍 VendorSniper: Starting improved auction house scan...")
    
    -- Check if auction house is ready
    local isReady, reason = self:IsAuctionHouseReady()
    if not isReady then
        print(string.format("⚠️ Auction house not ready: %s", reason))
        
        -- If we need to switch to Browse tab, do it automatically
        if reason == "Need to switch to Browse tab first" then
            print("📋 Automatically switching to Browse tab for scanning...")
            local browseTab = _G["AuctionFrameTab1"]
            if browseTab then
                browseTab:Click()
                -- Wait a moment for the switch to complete
                C_Timer.After(1.0, function()
                    self:StartScan()
                end)
                return
            else
                print("⚠️ Cannot find Browse tab")
                return
            end
        else
            return
        end
    end
    
    -- Additional check: ensure Browse button is available and enabled
    local browseButton = _G["BrowseSearchButton"]
    if not browseButton then
        print("❌ Browse button not found - cannot start scan")
        return
    end
    
    if not browseButton:IsEnabled() then
        print("⚠️ Browse button is disabled - waiting for it to become available...")
        -- Wait a bit and try again
        C_Timer.After(2.0, function()
            if self.IsScanning then
                self:StartScan()
            end
        end)
        return
    end
    
    print("✅ Browse button is ready - starting improved scan...")
    
    -- Initialize scan state
    self.IsScanning = true
    self.ScanData = {}
    self.CurrentPage = 0
    self.ItemsProcessed = 0
    self.EstimatedTotalPages = 0
    self.RepeatedDataCount = 0
    self.LastFirstItemName = ""
    self.ScanState = "searching"
    self.WaitingForData = false
    self.LastQueryTime = 0
    self.RetryCount = 0
    self.ProfitableItemsFound = 0
    self.TotalItemsScanned = 0
    self.SearchStartTime = GetTime()
    self.CategoryResults = {}
    
    -- Initialize search categories based on strategy
    self:InitializeSearchCategories()
    
    if #self.SearchCategories == 0 then
        print("❌ No search categories configured - cannot start scan")
        self:FinishScan()
        return
    end
    
    -- Reset category search state
    self.CurrentCategory = 1
    self.CategorySearchState = "searching"
    
    -- Show the scan overlay with error checking
    if self.ScanOverlay then
        self.ScanOverlay:Show()
        if self.ScanOverlay.statusText then
            self.ScanOverlay.statusText:SetText("VendorSniper Scanning...")
        end
        if self.ScanOverlay.progressText then
            self.ScanOverlay.progressText:SetText("Initializing scan...")
        end
        if self.ScanOverlay.progressBar then
            self.ScanOverlay.progressBar:SetWidth(0)
        end
        if self.ScanOverlay.progressPercent then
            self.ScanOverlay.progressPercent:SetText("0%")
        end
    else
        print("⚠️ Scan overlay not found!")
    end
    
    -- Create a frame to handle the scanning process
    if self.ScanFrame then
        self.ScanFrame:SetScript("OnUpdate", nil)
    end
    self.ScanFrame = CreateFrame("Frame")
    
    -- Start the scan with the first category
    self:StartCategorySearch()
end

-- NEW: Start searching a specific category
function VendorSniper:StartCategorySearch()
    if not self.IsScanning then
        return
    end
    
    if self.CurrentCategory > #self.SearchCategories then
        print("✅ All categories completed")
        self:FinishScan()
        return
    end
    
    local category = self.SearchCategories[self.CurrentCategory]
    print(string.format("📋 Starting search for category: %s", category.name))
    
    -- Reset page state for new category
    self.CurrentPage = 0
    self.RepeatedDataCount = 0
    self.LastFirstItemName = ""
    self.CategoryResults[self.CurrentCategory] = {
        name = category.name,
        itemsFound = 0,
        profitableItems = 0,
        pagesScanned = 0
    }
    
    -- Update progress
    local categoryProgress = ((self.CurrentCategory - 1) / #self.SearchCategories) * 100
    self:UpdateScanOverlay(categoryProgress, string.format("Searching: %s", category.name))
    
    -- Start the first page query for this category
    self:QueryNextPage()
end

-- NEW: Move to next category
function VendorSniper:NextCategory()
    if not self.IsScanning then
        return
    end
    
    -- Print category results
    local results = self.CategoryResults[self.CurrentCategory]
    if results then
        print(string.format("📊 Category '%s' complete: %d items scanned, %d profitable items found", 
            results.name, results.itemsFound, results.profitableItems))
    end
    
    self.CurrentCategory = self.CurrentCategory + 1
    
    -- Add delay between categories to avoid overwhelming the server
    C_Timer.After(self.Config.categorySearchDelay, function()
        if self.IsScanning then
            self:StartCategorySearch()
        end
    end)
end

function VendorSniper:QueryNextPage()
    if not self.IsScanning then
        return
    end
    
    -- Throttle queries to avoid overwhelming the server
    local currentTime = GetTime()
    if currentTime - self.LastQueryTimestamp < self.Config.queryThrottle then
        C_Timer.After(self.Config.queryThrottle, function()
            if self.IsScanning then
                self:QueryNextPage()
            end
        end)
        return
    end
    
    self.CurrentPage = self.CurrentPage + 1
    self.LastQueryTimestamp = currentTime
    
    local category = self.SearchCategories[self.CurrentCategory]
    print(string.format("📡 Querying %s - page %d...", category.name, self.CurrentPage))
    
    -- Set waiting flag
    self.WaitingForData = true
    self.LastQueryTime = GetTime()
    self.RetryCount = self.RetryCount or 0
    
    -- For the first page, we need to click Browse button first to load auction data
    if self.CurrentPage == 1 then
        print(string.format("🔍 First page for %s - clicking Browse button to load auction data...", category.name))
        local browseButton = _G["BrowseSearchButton"]
        if browseButton then
            browseButton:Click()
            -- Wait a bit longer for the first search to complete
            C_Timer.After(3.0, function()
                if self.IsScanning then
                    self:QueryNextPage()
                end
            end)
            return
        else
            print("❌ Browse button not found!")
            self:FinishScan()
            return
        end
    end
    
    -- Query the auction house for the current page with category filters
    -- Parameters: name, minLevel, maxLevel, invTypeIndex, classIndex, subclassIndex, page, isExact, qualityIndex
    QueryAuctionItems("", category.minLevel, category.maxLevel, 0, category.classIndex, category.subclassIndex, self.CurrentPage - 1, 0, 0, 0)
    
    -- Update progress
    local categoryProgress = ((self.CurrentCategory - 1) / #self.SearchCategories) * 100
    local pageProgress = (self.CurrentPage / 50) * (100 / #self.SearchCategories) -- Assume max 50 pages per category
    local totalProgress = math.min(categoryProgress + pageProgress, 95)
    
    if self.ProgressCallback then
        self.ProgressCallback(totalProgress, string.format("Querying %s - page %d", category.name, self.CurrentPage), self.CurrentPage, 0)
    end
    
    -- Update overlay
    self:UpdateScanOverlay(totalProgress, string.format("Querying %s - page %d", category.name, self.CurrentPage))
    
    -- Wait for data to load using OnUpdate timer with improved timing
    self.ScanFrame:SetScript("OnUpdate", function(frame, elapsed)
        frame.time = (frame.time or 0) + elapsed
        
        -- Wait for data to load with configurable timeout
        if frame.time >= self.Config.maxWaitTime then
            frame:SetScript("OnUpdate", nil)
            frame.time = 0
            
            if self.WaitingForData and self.IsScanning then
                self.WaitingForData = false
                
                -- Check if we got any data
                local numItems = GetNumAuctionItems("list")
                if not numItems or numItems == 0 then
                    -- No data received, retry if we haven't exceeded retry attempts
                    if self.RetryCount < self.Config.retryAttempts then
                        self.RetryCount = self.RetryCount + 1
                        print(string.format("⚠️ No data received for %s page %d, retrying... (attempt %d/%d)", 
                            category.name, self.CurrentPage, self.RetryCount, self.Config.retryAttempts))
                        
                        -- Wait a bit longer before retry
                        C_Timer.After(1.0, function()
                            if self.IsScanning then
                                self:QueryNextPage()
                            end
                        end)
                        return
                    else
                        print(string.format("⚠️ Failed to get data for %s page %d after %d attempts, moving to next category", 
                            category.name, self.CurrentPage, self.Config.retryAttempts))
                        self:NextCategory()
                        return
                    end
                else
                    -- Reset retry count on success
                    self.RetryCount = 0
                    self:ProcessCurrentPage()
                end
            end
        end
    end)
end

function VendorSniper:ProcessCurrentPage()
    if not self.IsScanning then
        return
    end
    
    local category = self.SearchCategories[self.CurrentCategory]
    print(string.format("📊 Processing %s - page %d...", category.name, self.CurrentPage))
    self.ScanState = "processing"
    
    -- Get the number of items on current page
    local numBatchAuctions = GetNumAuctionItems("list")
    
    if not numBatchAuctions or numBatchAuctions == 0 then
        print(string.format("⚠️ No items on %s page %d", category.name, self.CurrentPage))
        self:NextCategory()
        return
    end
    
    print(string.format("📊 Found %d items on %s page %d", numBatchAuctions, category.name, self.CurrentPage))
    
    -- In Classic WoW, if we get more than 50 items, it might be the total count
    -- We need to process only the actual items on this page (max 50)
    local actualItemsToProcess = numBatchAuctions
    if numBatchAuctions > 50 then
        print(string.format("⚠️ Got %d items, likely total count. Processing only page items...", numBatchAuctions))
        -- Count actual items on this page (max 50 in Classic)
        actualItemsToProcess = 0
        for i = 1, 50 do
            local name = select(1, GetAuctionItemInfo("list", i))
            if name and name ~= "" then
                actualItemsToProcess = actualItemsToProcess + 1
            else
                break
            end
        end
        print(string.format("📊 Corrected: Found %d actual items on current page", actualItemsToProcess))
    end
    
    -- Process all items on current page with improved filtering
    local itemsWithVendorPrice = 0
    local profitableItems = 0
    local filteredItems = 0
    
    for i = 1, actualItemsToProcess do
        local name, texture, count, quality, canUse, price, minIncrement, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId = GetAuctionItemInfo("list", i)
        
        if name and itemId and buyoutPrice and buyoutPrice > 0 then
            -- Get item info for filtering
            local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(itemId)
            
            -- Apply item filtering
            if self:ShouldProcessItem(itemName, quality, itemLevel, itemType, itemSubType) then
            local vendorPrice = self:GetVendorPrice(itemId)
            
            if vendorPrice then
                itemsWithVendorPrice = itemsWithVendorPrice + 1
                    local profit = self:CalculateProfit(buyoutPrice, vendorPrice, count, quality, itemLevel)
                
                    if profit and profit.totalProfit >= self.Config.minProfitThreshold then
                    profitableItems = profitableItems + 1
                        self.ProfitableItemsFound = self.ProfitableItemsFound + 1
                        
                    local itemData = {
                        itemID = itemId,
                        itemName = name,
                        auctionPrice = buyoutPrice,
                        vendorPrice = vendorPrice,
                            profit = profit.totalProfit,
                            profitPercent = profit.profitPercent,
                            stackSize = count,
                            itemQuality = quality,
                            itemLevel = itemLevel,
                            category = category.name
                    }
                    
                    table.insert(self.ScanData, itemData)
                    
                    -- Show item immediately if callback is set
                    if self.ProgressCallback then
                        self.ProgressCallback(nil, nil, nil, nil, itemData)
                    end
                    
                        print(string.format("💰 Found: %s - Buy: %s, Vendor: %s, Profit: %s (%.1f%%) [%s]", 
                        name, self:FormatMoney(buyoutPrice), self:FormatMoney(vendorPrice), 
                            self:FormatMoney(profit.totalProfit), profit.profitPercent, category.name))
                end
                end
            else
                -- Item was filtered out
                filteredItems = filteredItems + 1
            end
        end
        
        self.ItemsProcessed = self.ItemsProcessed + 1
        self.TotalItemsScanned = self.TotalItemsScanned + 1
    end
    
    -- Update category results
    if self.CategoryResults[self.CurrentCategory] then
        self.CategoryResults[self.CurrentCategory].itemsFound = self.CategoryResults[self.CurrentCategory].itemsFound + actualItemsToProcess
        self.CategoryResults[self.CurrentCategory].profitableItems = self.CategoryResults[self.CurrentCategory].profitableItems + profitableItems
        self.CategoryResults[self.CurrentCategory].pagesScanned = self.CategoryResults[self.CurrentCategory].pagesScanned + 1
    end
    
    print(string.format("📊 %s page %d: Processed %d items (%d filtered), %d had vendor prices, %d were profitable", 
        category.name, self.CurrentPage, actualItemsToProcess, filteredItems, itemsWithVendorPrice, profitableItems))
    
    -- Check for repeated data (same first item name)
    local currentFirstItemName = ""
    if actualItemsToProcess > 0 then
        local name = select(1, GetAuctionItemInfo("list", 1))
        currentFirstItemName = name or ""
    end
    
    if currentFirstItemName == self.LastFirstItemName and currentFirstItemName ~= "" then
        self.RepeatedDataCount = self.RepeatedDataCount + 1
        print(string.format("⚠️ Repeated data detected! Same first item '%s' for %d consecutive pages", 
            currentFirstItemName, self.RepeatedDataCount))
        
        -- If we've seen the same data for 2+ pages, we're likely stuck
        if self.RepeatedDataCount >= 2 then
            print("⚠️ Stuck on same data for 2+ pages, moving to next category")
            self:NextCategory()
            return
        end
    else
        self.RepeatedDataCount = 0
        self.LastFirstItemName = currentFirstItemName
    end
    
    -- Safety check: maximum page limit per category
    if self.CurrentPage >= 50 then
        print(string.format("⚠️ Reached maximum page limit (50) for %s, moving to next category", category.name))
        self:NextCategory()
        return
    end
    
    -- Check if we should continue to next page
    if actualItemsToProcess >= 50 then
        -- Full page, likely more pages available
        print(string.format("📄 Full page detected for %s, continuing to next page...", category.name))
        -- Add a small delay between pages to avoid overwhelming the server
        C_Timer.After(self.Config.scanDelay, function()
            if self.IsScanning then
                self:QueryNextPage()
            end
        end)
    else
        -- Partial page, likely the last page for this category
        print(string.format("📄 Partial page detected for %s, moving to next category", category.name))
        self:NextCategory()
    end
end

function VendorSniper:FinishScan()
    -- Calculate scan duration
    local scanDuration = GetTime() - self.SearchStartTime
    
    -- Sort by profit percentage (highest first)
    table.sort(self.ScanData, function(a, b)
        return a.profitPercent > b.profitPercent
    end)
    
    -- Limit results
    if #self.ScanData > self.Config.maxItemsToShow then
        for i = self.Config.maxItemsToShow + 1, #self.ScanData do
            self.ScanData[i] = nil
        end
    end
    
    -- Print comprehensive scan summary
    print("=" .. string.rep("=", 60))
    print("✅ VENDORSNIPER SCAN COMPLETE")
    print("=" .. string.rep("=", 60))
    print(string.format("📊 Scan Strategy: %s", self.Config.searchStrategy))
    print(string.format("⏱️  Scan Duration: %.1f seconds", scanDuration))
    print(string.format("📋 Categories Searched: %d", #self.SearchCategories))
    print(string.format("🔍 Total Items Scanned: %d", self.TotalItemsScanned))
    print(string.format("💰 Profitable Items Found: %d", self.ProfitableItemsFound))
    print(string.format("📈 Success Rate: %.2f%%", (self.ProfitableItemsFound / math.max(self.TotalItemsScanned, 1)) * 100))
    
    -- Print category breakdown
    print("\n📋 CATEGORY BREAKDOWN:")
    for i, results in ipairs(self.CategoryResults) do
        if results then
            print(string.format("  %s: %d items scanned, %d profitable (%.1f%%)", 
                results.name, results.itemsFound, results.profitableItems, 
                (results.profitableItems / math.max(results.itemsFound, 1)) * 100))
        end
    end
    
    -- Print top profitable items
    if #self.ScanData > 0 then
        print("\n💰 TOP PROFITABLE ITEMS:")
        for i = 1, math.min(5, #self.ScanData) do
            local item = self.ScanData[i]
            print(string.format("  %d. %s - Profit: %s (%.1f%%) [%s]", 
                i, item.itemName, self:FormatMoney(item.profit), item.profitPercent, item.category))
        end
    end
    
    -- Print cache statistics
    if self.Config.enableCaching then
        local cacheStats = self:GetCacheStats()
        print(string.format("\n🗄️  Cache Stats: %d items cached", cacheStats.size))
    end
    
    print("=" .. string.rep("=", 60))
    
    self.IsScanning = false
    self.ScanState = "complete"
    self.WaitingForData = false
    
    -- Hide the scan overlay
    if self.ScanOverlay then
        self.ScanOverlay:Hide()
    end
    
    -- Clean up scan frame and unregister events
    if self.ScanFrame then
        self.ScanFrame:SetScript("OnUpdate", nil)
    end
    
    -- Update progress to 100%
    if self.ProgressCallback then
        self.ProgressCallback(100, "Scan complete!", self.CurrentPage, self.CurrentPage)
    end
    
    -- Switch back to VendorSniper tab to show results
    C_Timer.After(0.5, function()
        local vendorSniperTab = nil
        for i = 1, AuctionFrame.numTabs do
            local tab = AuctionFrame["tab"..i]
            if tab and tab:GetText() == "VendorSniper" then
                vendorSniperTab = tab
                break
            end
        end
        
        if vendorSniperTab then
            print("📋 Switching back to VendorSniper tab to show results...")
            vendorSniperTab:Click()
        end
    end)
    
    -- Update UI if panel is visible
    if VendorSniperPanel and VendorSniperPanel:IsVisible() then
        self:UpdateUI()
    end
end

function VendorSniper:UpdateUI()
    -- This will be implemented in ui.lua
    if self.UpdateUIFunction then
        self.UpdateUIFunction()
    end
end

function VendorSniper:GetScanResults()
    return self.ScanData
end

function VendorSniper:StopScan()
    self.IsScanning = false
    self.ScanState = "idle"
    self.WaitingForData = false
    print("⏹️ VendorSniper: Scan stopped")
    
    -- Hide the scan overlay
    if self.ScanOverlay then
        self.ScanOverlay:Hide()
    end
    
    -- Clean up scan frame and unregister events
    if self.ScanFrame then
        self.ScanFrame:SetScript("OnUpdate", nil)
    end
    
    -- Update progress
    if self.ProgressCallback then
        self.ProgressCallback(0, "Scan stopped", 0, 0)
    end
end

function VendorSniper:SetProgressCallback(callback)
    self.ProgressCallback = callback
end

-- Function to force update the scan overlay
function VendorSniper:UpdateScanOverlay(progress, text)
    if self.ScanOverlay and self.ScanOverlay:IsVisible() then
        if self.ScanOverlay.progressText then
            self.ScanOverlay.progressText:SetText(text or "Processing...")
        end
        if self.ScanOverlay.progressBar then
            self.ScanOverlay.progressBar:SetWidth((progress / 100) * 298)
        end
        if self.ScanOverlay.progressPercent then
            self.ScanOverlay.progressPercent:SetText(string.format("%.1f%%", progress))
        end
    end
end 

-- Debug function to understand auction house data
function VendorSniper:DebugAuctionData()
    print("🔍 Debug: Analyzing auction house data...")
    
    -- Check different ways to get auction data
    local numList = GetNumAuctionItems("list")
    local numOwner = GetNumAuctionItems("owner")
    local numBidder = GetNumAuctionItems("bidder")
    
    print(string.format("🔍 GetNumAuctionItems('list'): %d", numList or 0))
    print(string.format("🔍 GetNumAuctionItems('owner'): %d", numOwner or 0))
    print(string.format("🔍 GetNumAuctionItems('bidder'): %d", numBidder or 0))
    
    -- Try to get some sample items
    if numList and numList > 0 then
        print("🔍 Sample items from 'list':")
        for i = 1, math.min(5, numList) do
            local name, texture, count, quality, canUse, price, minIncrement, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId = GetAuctionItemInfo("list", i)
            if name then
                print(string.format("  %d: %s (ID: %s, Buyout: %s)", i, name, itemId or "nil", buyoutPrice or "nil"))
            else
                print(string.format("  %d: No name", i))
            end
        end
    end
    
    -- Check if we're on the right tab
    if AuctionFrameBrowse then
        print(string.format("🔍 AuctionFrameBrowse visible: %s", AuctionFrameBrowse:IsVisible() and "yes" or "no"))
    else
        print("🔍 AuctionFrameBrowse not found")
    end
    
    -- Check search box
    local searchBox = _G["BrowseName"]
    if searchBox then
        print(string.format("🔍 Search box text: '%s'", searchBox:GetText() or ""))
    else
        print("🔍 Search box not found")
    end
end 

-- Test command function
function VendorSniper:TestCommand()
    print("🧪 VendorSniper Test Command")
    print("🧪 Testing auction house functionality...")
    
    -- Test BetterVendorPrice first
    print("🧪 Testing BetterVendorPrice integration...")
    if BetterVendorPrice and BetterVendorPrice.GetVendorPrice then
        print("✅ BetterVendorPrice found")
        
        -- Test with some common items
        local testItems = {17771, 16799, 12359, 12360} -- Elementium Bar, Arcanist Bindings, Thorium Bar, Arcanite Bar
        for _, itemID in ipairs(testItems) do
            local vendorPrice = BetterVendorPrice:GetVendorPrice(itemID)
            if vendorPrice then
                print(string.format("✅ Item %d vendor price: %s", itemID, self:FormatMoney(vendorPrice)))
            else
                print(string.format("⚠️ Item %d no vendor price", itemID))
            end
        end
    else
        print("❌ BetterVendorPrice not found or not working")
    end
    
    -- Check if auction house is ready
    local isReady, reason = self:IsAuctionHouseReady()
    if not isReady then
        print(string.format("⚠️ Auction house not ready: %s", reason))
        
        -- If we need to switch to Browse tab, do it automatically
        if reason == "Need to switch to Browse tab first" then
            print("📋 Automatically switching to Browse tab for testing...")
            local browseTab = _G["AuctionFrameTab1"]
            if browseTab then
                browseTab:Click()
                -- Wait a moment for the switch to complete, then test
                C_Timer.After(0.5, function()
                    VendorSniper:TestCommand()
                end)
                return
            else
                print("⚠️ Cannot find Browse tab")
                return
            end
        else
            return
        end
    end
    
    print("✅ Auction House is ready")
    
    -- Run debug analysis
    self:DebugAuctionData()
    
    -- Test Browse button activation
    print("🧪 Testing Browse button activation...")
    local browseButton = _G["BrowseSearchButton"]
    if browseButton then
        print("✅ Browse button found, clicking it...")
        browseButton:Click()
        
        -- Wait a moment and check results
        C_Timer.After(3.0, function() -- Increased wait time
            local numItems = GetNumAuctionItems("list")
            print(string.format("🧪 After Browse button click. Found %d items", numItems or 0))
            
            if numItems and numItems > 0 then
                print("✅ Browse activation successful!")
                -- Show first few items
                for i = 1, math.min(3, numItems) do
                    local name, texture, count, quality, canUse, price, minIncrement, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId = GetAuctionItemInfo("list", i)
                    if name then
                        print(string.format("  Item %d: %s (ID: %s, Buyout: %s)", i, name, itemId or "nil", buyoutPrice or "nil"))
                        
                        -- Test vendor price lookup for this item
                        if itemId then
                            local vendorPrice = self:GetVendorPrice(itemId)
                            if vendorPrice then
                                local profit = self:CalculateProfit(buyoutPrice, vendorPrice, count, quality, 0) -- Pass count, quality, level
                                if profit then
                                    print(string.format("    💰 PROFITABLE: Buy for %s, vendor for %s, profit %s", 
                                        self:FormatMoney(buyoutPrice), self:FormatMoney(vendorPrice), self:FormatMoney(profit.totalProfit)))
                                else
                                    print(string.format("    ❌ Not profitable: Buy for %s, vendor for %s", 
                                        self:FormatMoney(buyoutPrice), self:FormatMoney(vendorPrice)))
                                end
                            else
                                print(string.format("    ⚠️ No vendor price available for %s", name))
                            end
                        end
                    end
                end
                
                -- Test Next button
                local nextButton = _G["AuctionFrameBrowseNextButton"]
                if nextButton then
                    print(string.format("🧪 Next button found: enabled=%s", nextButton:IsEnabled() and "yes" or "no"))
                    
                    -- Test clicking Next button
                    if nextButton:IsEnabled() then
                        print("🧪 Testing Next button click...")
                        nextButton:Click()
                        
                        C_Timer.After(2.0, function()
                            local nextPageItems = GetNumAuctionItems("list")
                            print(string.format("🧪 After Next button click. Found %d items", nextPageItems or 0))
                            
                            if nextPageItems and nextPageItems > 0 then
                                print("✅ Next button working!")
                            else
                                print("⚠️ Next button may not be working properly")
                            end
                        end)
                    else
                        print("⚠️ Next button is disabled (may be last page)")
                    end
                else
                    print("⚠️ Next button not found")
                end
            else
                print("❌ Browse activation failed - no items found")
                print("🧪 Trying second Browse click...")
                browseButton:Click()
                
                C_Timer.After(2.0, function()
                    local numItems2 = GetNumAuctionItems("list")
                    print(string.format("🧪 After second Browse click. Found %d items", numItems2 or 0))
                    
                    if numItems2 and numItems2 > 0 then
                        print("✅ Second Browse attempt successful!")
                    else
                        print("❌ Second Browse attempt also failed")
                    end
                end)
            end
        end)
    else
        print("❌ Browse button not found")
    end
end

-- Simple BetterVendorPrice test function
function VendorSniper:TestBetterVendorPrice()
    print("🧪 Testing BetterVendorPrice...")
    
    local found = false
    
    -- Method 1: Direct BetterVendorPrice object
    if BetterVendorPrice and type(BetterVendorPrice) == "table" then
        print("✅ BetterVendorPrice object found")
        found = true
        
        if BetterVendorPrice.GetVendorPrice then
            print("✅ BetterVendorPrice.GetVendorPrice function found")
        else
            print("⚠️ BetterVendorPrice.GetVendorPrice function not found")
        end
        
        if BetterVendorPrice.GetVendorPriceByItemID then
            print("✅ BetterVendorPrice.GetVendorPriceByItemID function found")
        else
            print("⚠️ BetterVendorPrice.GetVendorPriceByItemID function not found")
        end
    else
        print("❌ BetterVendorPrice object not found")
    end
    
    -- Method 2: Global function
    if _G.GetVendorPrice then
        print("✅ Global GetVendorPrice function found")
        found = true
    else
        print("❌ Global GetVendorPrice function not found")
    end
    
    -- Method 3: BVP namespace
    if BVP and BVP.GetVendorPrice then
        print("✅ BVP namespace found with GetVendorPrice function")
        found = true
    else
        print("❌ BVP namespace not found")
    end
    
    if not found then
        print("❌ No BetterVendorPrice integration found")
        return
    end
    
    print("✅ BetterVendorPrice integration found, testing with sample items...")
    
    -- Test with some common items
    local testItems = {
        {id = 17771, name = "Elementium Bar"},
        {id = 16799, name = "Arcanist Bindings"},
        {id = 16802, name = "Arcanist Belt"},
        {id = 12359, name = "Thorium Bar"},
        {id = 12360, name = "Arcanite Bar"}
    }
    
    for _, item in ipairs(testItems) do
        local vendorPrice = self:GetVendorPrice(item.id)
        if vendorPrice then
            print(string.format("✅ %s (ID: %d) vendor price: %s", item.name, item.id, self:FormatMoney(vendorPrice)))
        else
            print(string.format("⚠️ %s (ID: %d) no vendor price", item.name, item.id))
        end
    end
end

-- Diagnostic function to check search readiness
function VendorSniper:DiagnoseSearchIssues()
    print("🔍 VendorSniper Search Diagnosis")
    print("=================================")
    
    -- Check 1: Auction House State
    print("1. Auction House State:")
    if not AuctionFrame then
        print("   ❌ Auction House not open")
        return
    end
    
    if not AuctionFrame:IsVisible() then
        print("   ❌ Auction House frame not visible")
        return
    end
    
    print("   ✅ Auction House is open and visible")
    
    -- Check 2: Current Tab
    print("2. Current Tab:")
    local currentTab = PanelTemplates_GetSelectedTab(AuctionFrame)
    local currentTabName = ""
    for i = 1, AuctionFrame.numTabs do
        local tab = AuctionFrame["tab"..i]
        if tab and tab:GetID() == currentTab then
            currentTabName = tab:GetText()
            break
        end
    end
    
    print(string.format("   Current tab: %s (ID: %d)", currentTabName, currentTab))
    
    if currentTabName == "VendorSniper" then
        print("   ⚠️ Currently on VendorSniper tab - will need to switch to Browse")
    elseif currentTabName == "Browse" then
        print("   ✅ Currently on Browse tab - ready for scanning")
    else
        print("   ⚠️ Not on Browse tab - may need to switch")
    end
    
    -- Check 3: Browse Tab Availability
    print("3. Browse Tab Availability:")
    if AuctionFrameBrowse then
        print("   ✅ AuctionFrameBrowse exists")
        if AuctionFrameBrowse:IsVisible() then
            print("   ✅ Browse tab is visible")
        else
            print("   ❌ Browse tab is not visible")
        end
    else
        print("   ❌ AuctionFrameBrowse not found")
    end
    
    -- Check 4: Browse Button
    print("4. Browse Button:")
    local browseButton = _G["BrowseSearchButton"]
    if browseButton then
        print("   ✅ Browse button found")
        if browseButton:IsEnabled() then
            print("   ✅ Browse button is enabled")
        else
            print("   ⚠️ Browse button is disabled")
        end
    else
        print("   ❌ Browse button not found")
    end
    
    -- Check 5: BetterVendorPrice Integration
    print("5. BetterVendorPrice Integration:")
    local bvpFound = false
    
    if BetterVendorPrice and type(BetterVendorPrice) == "table" then
        print("   ✅ BetterVendorPrice object found")
        bvpFound = true
        
        if BetterVendorPrice.GetVendorPrice then
            print("   ✅ GetVendorPrice function available")
        else
            print("   ❌ GetVendorPrice function not found")
        end
        
        if BetterVendorPrice.GetVendorPriceByItemID then
            print("   ✅ GetVendorPriceByItemID function available")
        else
            print("   ❌ GetVendorPriceByItemID function not found")
        end
    else
        print("   ❌ BetterVendorPrice object not found")
    end
    
    if _G.GetVendorPrice then
        print("   ✅ Global GetVendorPrice function found")
        bvpFound = true
    else
        print("   ❌ Global GetVendorPrice function not found")
    end
    
    if BVP and BVP.GetVendorPrice then
        print("   ✅ BVP namespace found")
        bvpFound = true
    else
        print("   ❌ BVP namespace not found")
    end
    
    if not bvpFound then
        print("   ⚠️ WARNING: No BetterVendorPrice integration found!")
        print("   This addon requires BetterVendorPrice to function properly.")
    end
    
    -- Check 6: Test Vendor Price Lookup
    print("6. Vendor Price Test:")
    if bvpFound then
        local testItems = {17771, 16799, 12359} -- Common items
        local successCount = 0
        
        for _, itemID in ipairs(testItems) do
            local vendorPrice = self:GetVendorPrice(itemID)
            if vendorPrice then
                successCount = successCount + 1
                print(string.format("   ✅ Item %d: %s", itemID, self:FormatMoney(vendorPrice)))
            else
                print(string.format("   ❌ Item %d: No vendor price", itemID))
            end
        end
        
        if successCount > 0 then
            print(string.format("   ✅ Vendor price lookup working (%d/%d items)", successCount, #testItems))
        else
            print("   ❌ Vendor price lookup not working")
        end
    else
        print("   ⚠️ Skipping vendor price test - BetterVendorPrice not available")
    end
    
    -- Check 7: Current Auction Data
    print("7. Current Auction Data:")
    local numItems = GetNumAuctionItems("list")
    if numItems and numItems > 0 then
        print(string.format("   ✅ Found %d items in current auction data", numItems))
        
        -- Show first few items
        for i = 1, math.min(3, numItems) do
            local name, texture, count, quality, canUse, price, minIncrement, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId = GetAuctionItemInfo("list", i)
            if name then
                print(string.format("   Item %d: %s (ID: %s, Buyout: %s)", i, name, itemId or "nil", buyoutPrice or "nil"))
            end
        end
    else
        print("   ❌ No auction data available")
        print("   This is normal if no search has been performed yet")
    end
    
    print("=================================")
    print("Diagnosis complete!")
    
    if not bvpFound then
        print("⚠️ CRITICAL ISSUE: BetterVendorPrice not found!")
        print("Please install BetterVendorPrice addon for this to work.")
    end
end

-- Register slash command
SLASH_VENDORSNIPER1 = "/vendorsniper"
SLASH_VENDORSNIPER2 = "/vs"
SlashCmdList["VENDORSNIPER"] = function(msg)
    if msg == "test" then
        VendorSniper:TestCommand()
    elseif msg == "bvp" then
        VendorSniper:TestBetterVendorPriceIntegration()
    elseif msg == "scan" then
        if VendorSniper.IsScanning then
            VendorSniper:StopScan()
        else
            VendorSniper:StartScan()
        end
    elseif msg == "debug" then
        VendorSniper:DebugAuctionData()
    elseif msg == "fixui" then
        -- Fix UI issues
        if AuctionFrame then
            print("🔧 Fixing UI issues...")
            -- Try to fix tab positioning
            for i = 1, AuctionFrame.numTabs do
                local tab = AuctionFrame["tab"..i]
                if tab and tab:GetText() == "VendorSniper" then
                    print(string.format("🔧 Found VendorSniper tab at position %d", i))
                    local textWidth = tab:GetTextWidth()
                    tab:SetWidth(textWidth + 20)
                    print(string.format("🔧 Set tab width to %d pixels", textWidth + 20))
                    
                    -- Reposition if needed
                    if i > 1 then
                        local prevTab = AuctionFrame["tab"..(i - 1)]
                        if prevTab then
                            tab:ClearAllPoints()
                            tab:SetPoint("TOPLEFT", prevTab, "TOPRIGHT", 0, 0)
                            print("✅ Tab repositioned")
                        end
                    end
                    break
                end
            end
        else
            print("⚠️ Auction House not open")
        end
    elseif msg == "debugon" then
        VendorSniper.Config.debugMode = true
        print("🔧 Debug mode enabled - detailed output will be shown during scanning")
    elseif msg == "debugoff" then
        VendorSniper.Config.debugMode = false
        print("🔧 Debug mode disabled - minimal output during scanning")
    elseif msg == "diagnose" then
        VendorSniper:DiagnoseSearchIssues()
    elseif msg == "browse" then
        -- Manually trigger Browse button to force a search
        print("🔍 Manually triggering Browse button...")
        
        -- Check if we're on the right tab
        local isReady, reason = VendorSniper:IsAuctionHouseReady()
        if not isReady then
            print(string.format("⚠️ Auction house not ready: %s", reason))
            
            -- Try to switch to Browse tab
            if reason == "Need to switch to Browse tab first" then
                print("📋 Switching to Browse tab...")
                local browseTab = _G["AuctionFrameTab1"]
                if browseTab then
                    browseTab:Click()
                    C_Timer.After(0.5, function()
                        VendorSniper:ManualBrowse()
                    end)
                    return
                end
            end
            return
        end
        
        VendorSniper:ManualBrowse()
    elseif msg == "testbrowse" then
        -- Test Browse button functionality
        print("🧪 Testing Browse button functionality...")
        
        -- Check current state
        local numItems = GetNumAuctionItems("list")
        print(string.format("📊 Current items in auction data: %d", numItems or 0))
        
        -- Click Browse button
        local browseButton = _G["BrowseSearchButton"]
        if browseButton then
            print("✅ Browse button found, clicking it...")
            browseButton:Click()
            
            -- Check results after a delay
            C_Timer.After(3.0, function()
                local newNumItems = GetNumAuctionItems("list")
                print(string.format("📊 After Browse click: %d items", newNumItems or 0))
                
                if newNumItems and newNumItems > 0 then
                    print("✅ Browse button working!")
                    
                    -- Show first few items
                    for i = 1, math.min(5, newNumItems) do
                        local name, texture, count, quality, canUse, price, minIncrement, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId = GetAuctionItemInfo("list", i)
                        if name then
                            print(string.format("  Item %d: %s (ID: %s, Buyout: %s)", i, name, itemId or "nil", buyoutPrice or "nil"))
                        end
                    end
                else
                    print("❌ Browse button failed - no items found")
                end
            end)
        else
            print("❌ Browse button not found")
        end
    elseif msg == "testitems" then
        -- Test BetterVendorPrice with actual auction house items
        print("🧪 Testing BetterVendorPrice with auction house items...")
        
        local numItems = GetNumAuctionItems("list")
        if not numItems or numItems == 0 then
            print("❌ No auction data available. Please run /vs testbrowse first.")
            return
        end
        
        print(string.format("📊 Testing vendor prices for first 10 items..."))
        
        local successCount = 0
        for i = 1, math.min(10, numItems) do
            local name, texture, count, quality, canUse, price, minIncrement, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId = GetAuctionItemInfo("list", i)
            
            if name and itemId then
                print(string.format("Item %d: %s (ID: %s)", i, name, itemId))
                
                -- Test vendor price lookup
                local vendorPrice = VendorSniper:GetVendorPrice(itemId)
                if vendorPrice then
                    successCount = successCount + 1
                    print(string.format("  ✅ Vendor price: %s", VendorSniper:FormatMoney(vendorPrice)))
                    
                    -- Test profit calculation
                    if buyoutPrice and buyoutPrice > 0 then
                        local profit = VendorSniper:CalculateProfit(buyoutPrice, vendorPrice, count, quality, 0) -- Pass count, quality, level
                        if profit then
                            print(string.format("  💰 PROFITABLE: Buy for %s, vendor for %s, profit %s", 
                                VendorSniper:FormatMoney(buyoutPrice), VendorSniper:FormatMoney(vendorPrice), VendorSniper:FormatMoney(profit.totalProfit)))
                        else
                            print(string.format("  ❌ Not profitable: Buy for %s, vendor for %s", 
                                VendorSniper:FormatMoney(buyoutPrice), VendorSniper:FormatMoney(vendorPrice)))
                        end
                    end
                else
                    print(string.format("  ❌ No vendor price available"))
                end
                print("") -- Empty line for readability
            end
        end
        
        print(string.format("📊 BetterVendorPrice test complete: %d/%d items had vendor prices", successCount, math.min(10, numItems)))
        
        if successCount == 0 then
            print("⚠️ WARNING: No vendor prices found! BetterVendorPrice may not be working properly.")
            print("Try running /bvp to check BetterVendorPrice status.")
        end
    elseif msg == "fixtab" then
        -- Manually fix tab positioning
        print("🔧 Manually fixing tab positioning...")
        if VendorSniper and VendorSniper.FixTabPositioning then
            VendorSniper.FixTabPositioning()
        elseif FixTabPositioning then
            FixTabPositioning()
        else
            print("❌ FixTabPositioning function not found!")
            print("🔧 Trying alternative fix...")
            -- Alternative fix using the UI function
            if VendorSniperPanel and VendorSniperPanel:IsVisible() then
                print("🔧 VendorSniper panel is visible, attempting to fix...")
                -- Force a UI update
                VendorSniper:UpdateUI()
            else
                print("⚠️ VendorSniper panel not visible")
            end
        end
    elseif msg == "debugpanel" then
        -- Debug panel status
        if VendorSniper and VendorSniper.DebugPanel then
            VendorSniper.DebugPanel()
        else
            print("❌ Debug panel function not available")
        end
    elseif msg == "forceshow" then
        -- Force show the panel
        if VendorSniper and VendorSniper.ForceShowPanel then
            VendorSniper.ForceShowPanel()
        else
            print("❌ Force show function not available")
        end
    elseif msg == "showpanel" then
        -- Simple panel show test
        print("🔧 Manually showing VendorSniper panel...")
        if VendorSniperPanel then
            VendorSniperPanel:Show()
            VendorSniperPanel:SetFrameLevel(AuctionFrame:GetFrameLevel() + 10)
            print("✅ Panel should now be visible!")
        else
            print("❌ VendorSniperPanel not found!")
        end
    elseif msg == "config" then
        -- Show current configuration
        print("⚙️ VendorSniper Configuration:")
        print(string.format("  Search Strategy: %s", VendorSniper.Config.searchStrategy))
        print(string.format("  Min Profit Threshold: %s", VendorSniper:FormatMoney(VendorSniper.Config.minProfitThreshold)))
        print(string.format("  Min Profit Percent: %.1f%%", VendorSniper.Config.minProfitPercent))
        print(string.format("  Max Buyout Price: %s", VendorSniper:FormatMoney(VendorSniper.Config.maxBuyoutPrice)))
        print(string.format("  Item Quality Range: %d-%d", VendorSniper.Config.minItemQuality, VendorSniper.Config.maxItemQuality))
        print(string.format("  Item Level Range: %d-%d", VendorSniper.Config.minItemLevel, VendorSniper.Config.maxItemLevel))
        print(string.format("  Include Consumables: %s", VendorSniper.Config.includeConsumables and "Yes" or "No"))
        print(string.format("  Include Materials: %s", VendorSniper.Config.includeMaterials and "Yes" or "No"))
        print(string.format("  Include Equipment: %s", VendorSniper.Config.includeEquipment and "Yes" or "No"))
        print(string.format("  Include Trade Goods: %s", VendorSniper.Config.includeTradeGoods and "Yes" or "No"))
        print(string.format("  Consider Stack Size: %s", VendorSniper.Config.considerStackSize and "Yes" or "No"))
        print(string.format("  Cache Enabled: %s", VendorSniper.Config.enableCaching and "Yes" or "No"))
    elseif msg == "cache" then
        -- Show cache statistics
        local cacheStats = VendorSniper:GetCacheStats()
        print("🗄️ Vendor Price Cache Statistics:")
        print(string.format("  Cache Enabled: %s", cacheStats.enabled and "Yes" or "No"))
        print(string.format("  Cached Items: %d", cacheStats.size))
        print(string.format("  Cache Timeout: %d seconds", cacheStats.timeout))
    elseif msg == "clearcache" then
        -- Clear the vendor price cache
        VendorSniper:ClearCache()
    elseif msg == "strategy" then
        -- Show available search strategies
        print("🎯 Available Search Strategies:")
        print("  broad - Single broad search (fastest, less targeted)")
        print("  smart - Category-based search (balanced, recommended)")
        print("  targeted - High-value focused search (slowest, most targeted)")
    elseif msg == "setstrategy" then
        -- Set search strategy (requires parameter)
        print("Usage: /vs setstrategy <strategy>")
        print("Available strategies: broad, smart, targeted")
    elseif msg:match("^setstrategy (.+)$") then
        -- Set search strategy with parameter
        local strategy = msg:match("^setstrategy (.+)$")
        if strategy == "broad" or strategy == "smart" or strategy == "targeted" then
            VendorSniper.Config.searchStrategy = strategy
            print(string.format("✅ Search strategy set to: %s", strategy))
        else
            print("❌ Invalid strategy. Use: broad, smart, or targeted")
        end
    else
        print("VendorSniper commands:")
        print("📋 Most settings are now available in the GUI configuration panel!")
        print("")
        print("🔧 Debug/Testing Commands:")
        print("/vs test - Test auction house functionality")
        print("/vs bvp - Test BetterVendorPrice integration")
        print("/vs debug - Debug auction house data")
        print("/vs diagnose - Diagnose search readiness and BetterVendorPrice integration")
        print("/vs browse - Manually trigger Browse button to force a search")
        print("/vs testbrowse - Test Browse button functionality and show results")
        print("/vs testitems - Test BetterVendorPrice with actual auction house items")
        print("/vs fixtab - Manually fix tab positioning issues")
        print("/vs debugpanel - Debug panel visibility and positioning")
        print("/vs forceshow - Force show VendorSniper panel")
        print("/vs showpanel - Manually show the panel")
        print("")
        print("⚙️ Configuration Commands (also available in GUI):")
        print("/vs config - Show current configuration settings")
        print("/vs cache - Show cache statistics")
        print("/vs clearcache - Clear vendor price cache")
        print("/vs strategy - Show available search strategies")
        print("/vs setstrategy <strategy> - Set search strategy (broad/smart/targeted/deep)")
        print("")
        print("🎯 Search Strategies:")
        print("  Smart (Recommended) - Balanced category-based search")
        print("  Broad (Fast) - Single broad search across all items")
        print("  Targeted (Precise) - Focus on high-value categories only")
        print("  Deep Scan (All Items) - Comprehensive search of ALL categories")
    end
end 

-- Function to manually trigger Browse button
function VendorSniper:ManualBrowse()
    local browseButton = _G["BrowseSearchButton"]
    if browseButton then
        print("✅ Browse button found, clicking it...")
        browseButton:Click()
        
        -- Wait and check results
        C_Timer.After(3.0, function()
            local numItems = GetNumAuctionItems("list")
            print(string.format("📊 After Browse click: Found %d items", numItems or 0))
            
            if numItems and numItems > 0 then
                print("✅ Browse activation successful!")
                
                -- Show sample items
                for i = 1, math.min(3, numItems) do
                    local name, texture, count, quality, canUse, price, minIncrement, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId = GetAuctionItemInfo("list", i)
                    if name then
                        print(string.format("  Item %d: %s (ID: %s, Buyout: %s)", i, name, itemId or "nil", buyoutPrice or "nil"))
                    end
                end
            else
                print("❌ Browse activation failed - no items found")
            end
        end)
    else
        print("❌ Browse button not found")
    end
end 