print("✅ VendorSniper core.lua loaded")

-- Initialize addon namespace
VendorSniper = VendorSniper or {}

-- Configuration
VendorSniper.Config = {
    minProfitThreshold = 1, -- Minimum profit in copper to show item
    maxItemsToShow = 50,    -- Maximum items to display
    scanDelay = 0.5,        -- Delay between searches
    searchTerms = {         -- Items to search for
        "cloth", "herb", "ore", "leather", "wool", "silk", "linen", "mageweave", "runecloth",
        "peacebloom", "silverleaf", "earthroot", "mageroyal", "briarthorn", "bruiseweed",
        "wild steelbloom", "kingsblood", "liferoot", "fadeleaf", "goldthorn", "khadgar's whisker",
        "wintersbite", "firebloom", "purple lotus", "arthas' tears", "sungrass", "blindweed",
        "ghost mushroom", "gromsblood", "golden sansam", "dreamfoil", "mountain silversage",
        "plaguebloom", "icecap", "black lotus", "copper", "tin", "iron", "mithril", "thorium",
        "rugged leather", "thick leather", "heavy leather", "medium leather", "light leather"
    }
}

-- Data storage
VendorSniper.ScanData = {}
VendorSniper.IsScanning = false
VendorSniper.CurrentSearchIndex = 1
VendorSniper.TotalSearches = 0
VendorSniper.ProgressCallback = nil

-- Utility functions
function VendorSniper:GetVendorPrice(itemID)
    -- Try to get vendor price from BetterVendorPrice if available
    if BetterVendorPrice and BetterVendorPrice.GetVendorPrice then
        return BetterVendorPrice:GetVendorPrice(itemID)
    end
    
    -- Fallback: return nil if BetterVendorPrice not available
    return nil
end

function VendorSniper:CalculateProfit(auctionPrice, vendorPrice)
    if not vendorPrice or vendorPrice <= 0 then
        return nil
    end
    
    -- Calculate profit (auction price should be lower than vendor price for profit)
    local profit = vendorPrice - auctionPrice
    return profit > 0 and profit or nil
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

function VendorSniper:StartScan()
    if self.IsScanning then
        print("⚠️ VendorSniper: Scan already in progress")
        return
    end
    
    print("🔍 VendorSniper: Starting comprehensive auction house scan...")
    self.IsScanning = true
    self.ScanData = {}
    self.CurrentSearchIndex = 1
    self.TotalSearches = #self.Config.searchTerms
    
    -- Start the scanning process (no tab switching)
    self:SearchNextTerm()
end

function VendorSniper:SearchNextTerm()
    if not self.IsScanning then return end
    
    if self.CurrentSearchIndex > #self.Config.searchTerms then
        -- Scan complete
        self:FinishScan()
        return
    end
    
    local searchTerm = self.Config.searchTerms[self.CurrentSearchIndex]
    local progress = (self.CurrentSearchIndex - 1) / #self.Config.searchTerms * 100
    
    print(string.format("🔍 VendorSniper: Searching '%s' (%d/%d - %.1f%%)", 
        searchTerm, self.CurrentSearchIndex, #self.Config.searchTerms, progress))
    
    -- Update progress if callback is set
    if self.ProgressCallback then
        self.ProgressCallback(progress, searchTerm, self.CurrentSearchIndex, #self.Config.searchTerms)
    end
    
    -- Search for the current term (background search, no tab switching)
    QueryAuctionItems(searchTerm, nil, nil, 0, 0, 0, 0, 0, 0, 0)
    
    -- Process results after a delay
    self:ScheduleProcess()
end

function VendorSniper:ScheduleProcess()
    local frame = CreateFrame("Frame")
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.time = (self.time or 0) + elapsed
        if self.time >= 1.0 then -- Wait 1 second for query to complete
            self:SetScript("OnUpdate", nil)
            VendorSniper:ProcessCurrentSearch()
        end
    end)
end

function VendorSniper:ProcessCurrentSearch()
    local numBatchAuctions = GetNumAuctionItems("list")
    
    if numBatchAuctions and numBatchAuctions > 0 then
        print(string.format("📊 VendorSniper: Processing %d items for '%s'", 
            numBatchAuctions, self.Config.searchTerms[self.CurrentSearchIndex]))
        
        for i = 1, numBatchAuctions do
            local name, texture, count, quality, canUse, price, minIncrement, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId = GetAuctionItemInfo("list", i)
            
            if name and itemId and buyoutPrice and buyoutPrice > 0 then
                local vendorPrice = self:GetVendorPrice(itemId)
                
                if vendorPrice then
                    local profit = self:CalculateProfit(buyoutPrice, vendorPrice)
                    
                    if profit and profit >= self.Config.minProfitThreshold then
                        local itemData = {
                            itemID = itemId,
                            itemName = name,
                            auctionPrice = buyoutPrice,
                            vendorPrice = vendorPrice,
                            profit = profit,
                            profitPercent = (profit / buyoutPrice) * 100
                        }
                        
                        table.insert(self.ScanData, itemData)
                        
                        -- Show item immediately if callback is set
                        if self.ProgressCallback then
                            self.ProgressCallback(nil, nil, nil, nil, itemData)
                        end
                        
                        print(string.format("💰 Found: %s - Buy: %s, Vendor: %s, Profit: %s (%.1f%%)", 
                            name, self:FormatMoney(buyoutPrice), self:FormatMoney(vendorPrice), 
                            self:FormatMoney(profit), itemData.profitPercent))
                    end
                end
            end
        end
    end
    
    -- Move to next search term
    self.CurrentSearchIndex = self.CurrentSearchIndex + 1
    
    -- Continue with next search after a delay
    if self.IsScanning then
        local frame = CreateFrame("Frame")
        frame:SetScript("OnUpdate", function(frame, elapsed)
            frame.time = (frame.time or 0) + elapsed
            if frame.time >= VendorSniper.Config.scanDelay then
                frame:SetScript("OnUpdate", nil)
                VendorSniper:SearchNextTerm()
            end
        end)
    end
end

function VendorSniper:FinishScan()
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
    
    print(string.format("✅ VendorSniper: Scan complete! Found %d profitable items", #self.ScanData))
    self.IsScanning = false
    
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
    print("⏹️ VendorSniper: Scan stopped")
end

function VendorSniper:SetProgressCallback(callback)
    self.ProgressCallback = callback
end
