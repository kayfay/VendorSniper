-- ui.lua

local function CreateVendorSniperPanel()
    if VendorSniperPanel then return end

    -- Create the panel as a child of AuctionFrame
    VendorSniperPanel = CreateFrame("Frame", "VendorSniperPanel", AuctionFrame)
    
    -- Position it to fill the entire auction house content area
    -- This matches exactly where AuctionFrameBrowse content appears
    VendorSniperPanel:SetPoint("TOPLEFT", AuctionFrame, "TOPLEFT", 15, -85)
    VendorSniperPanel:SetPoint("BOTTOMRIGHT", AuctionFrame, "BOTTOMRIGHT", -15, 15)
    
    -- Set frame level to be above the auction house background but below UI elements
    VendorSniperPanel:SetFrameLevel(AuctionFrame:GetFrameLevel() + 1)
    
    -- Add a background to make the content area visible
    local bg = VendorSniperPanel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    
    -- Hide by default
    VendorSniperPanel:Hide()
    
    -- Create a scan overlay that covers the Browse tab during scanning
    local scanOverlay = CreateFrame("Frame", "VendorSniperScanOverlay", AuctionFrameBrowse)
    scanOverlay:SetAllPoints(true)
    scanOverlay:SetFrameLevel(AuctionFrameBrowse:GetFrameLevel() + 10)
    scanOverlay:Hide()
    
    -- Semi-transparent background
    local overlayBg = scanOverlay:CreateTexture(nil, "BACKGROUND")
    overlayBg:SetAllPoints(true)
    overlayBg:SetColorTexture(0, 0, 0, 0.7)
    
    -- Scan status text
    local scanStatusText = scanOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    scanStatusText:SetPoint("TOP", scanOverlay, "TOP", 0, -50)
    scanStatusText:SetText("VendorSniper Scanning...")
    scanStatusText:SetTextColor(1, 1, 0)
    
    -- Progress text
    local progressText = scanOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    progressText:SetPoint("TOP", scanStatusText, "BOTTOM", 0, -20)
    progressText:SetText("Processing auction house data...")
    progressText:SetTextColor(1, 1, 1)
    
    -- Progress bar
    local progressFrame = CreateFrame("Frame", nil, scanOverlay)
    progressFrame:SetSize(300, 20)
    progressFrame:SetPoint("TOP", progressText, "BOTTOM", 0, -20)
    
    local progressBg = progressFrame:CreateTexture(nil, "BACKGROUND")
    progressBg:SetAllPoints(true)
    progressBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    
    local progressBar = progressFrame:CreateTexture(nil, "ARTWORK")
    progressBar:SetPoint("TOPLEFT", progressFrame, "TOPLEFT", 1, -1)
    progressBar:SetPoint("BOTTOMLEFT", progressFrame, "BOTTOMLEFT", 1, 1)
    progressBar:SetWidth(0)
    progressBar:SetColorTexture(0, 1, 0, 0.8)
    
    local progressPercent = progressFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    progressPercent:SetPoint("CENTER", progressFrame, "CENTER", 0, 0)
    progressPercent:SetText("0%")
    
    -- Stop scan button
    local stopButton = CreateFrame("Button", nil, scanOverlay, "UIPanelButtonTemplate")
    stopButton:SetSize(100, 25)
    stopButton:SetPoint("TOP", progressFrame, "BOTTOM", 0, -20)
    stopButton:SetText("Stop Scan")
    stopButton:SetScript("OnClick", function()
        VendorSniper:StopScan()
    end)
    
    -- Store references
    scanOverlay.statusText = scanStatusText
    scanOverlay.progressText = progressText
    scanOverlay.progressBar = progressBar
    scanOverlay.progressPercent = progressPercent
    scanOverlay.stopButton = stopButton
    
    -- Store the overlay reference globally
    if VendorSniper then
        VendorSniper.ScanOverlay = scanOverlay
    else
        print("⚠️ VendorSniper namespace not found, overlay not stored")
    end

    -- Main title
    local title = VendorSniperPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetText("VendorSniper")
    title:SetPoint("TOP", VendorSniperPanel, "TOP", 0, -15)
    title:SetTextColor(1, 1, 1)

    -- STEP 1: Create main content area that fills the AH window
    local mainContentArea = CreateFrame("Frame", nil, VendorSniperPanel)
    mainContentArea:SetPoint("TOPLEFT", VendorSniperPanel, "TOPLEFT", 20, -50)
    mainContentArea:SetPoint("BOTTOMRIGHT", VendorSniperPanel, "BOTTOMRIGHT", -20, 20)

    -- STEP 2: Create top control bar (scan button, filters, and settings)
    local topControlBar = CreateFrame("Frame", nil, mainContentArea)
    topControlBar:SetPoint("TOPLEFT", mainContentArea, "TOPLEFT", 0, 0)
    topControlBar:SetPoint("TOPRIGHT", mainContentArea, "TOPRIGHT", 0, 0)
    topControlBar:SetHeight(120) -- Increased height for better spacing

    -- Add background for top control bar
    local topBarBg = topControlBar:CreateTexture(nil, "BACKGROUND")
    topBarBg:SetAllPoints(true)
    topBarBg:SetColorTexture(0.1, 0.1, 0.1, 0.3)

    -- STEP 3: Create scan button at top right
    local scanButton = CreateFrame("Button", nil, topControlBar, "UIPanelButtonTemplate")
    scanButton:SetSize(140, 30)
    scanButton:SetPoint("TOPRIGHT", topControlBar, "TOPRIGHT", -15, -15)
    scanButton:SetText("Start Scan")
    scanButton:SetScript("OnClick", function()
        if VendorSniper and VendorSniper.IsScanning then
            VendorSniper:StopScan()
            scanButton:SetText("Start Scan")
        elseif VendorSniper then
            VendorSniper:StartScan()
            scanButton:SetText("Stop Scan")
        else
            print("⚠️ VendorSniper not available")
        end
    end)

    -- STEP 4: Create configuration section on the left side of top bar
    local configSection = CreateFrame("Frame", nil, topControlBar)
    configSection:SetPoint("TOPLEFT", topControlBar, "TOPLEFT", 15, -15)
    configSection:SetPoint("BOTTOMRIGHT", topControlBar, "BOTTOMRIGHT", -200, 0) -- Reduced width to make room for centered filters

    -- Strategy dropdown (top left)
    local strategyLabel = configSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    strategyLabel:SetText("Strategy:")
    strategyLabel:SetPoint("TOPLEFT", configSection, "TOPLEFT", 0, 0)

    local strategyDropdown = CreateFrame("Frame", "VendorSniperStrategyDropdown", configSection, "UIDropDownMenuTemplate")
    strategyDropdown:SetPoint("TOPLEFT", strategyLabel, "BOTTOMLEFT", -20, -8)
    
    local strategyOptions = {
        {text = "Smart (Recommended)", value = "smart"},
        {text = "Broad (Fast)", value = "broad"},
        {text = "Targeted (Precise)", value = "targeted"},
        {text = "Deep Scan (All Items)", value = "deep"}
    }
    
    UIDropDownMenu_SetWidth(strategyDropdown, 160)
    UIDropDownMenu_Initialize(strategyDropdown, function(self, level)
        for _, option in ipairs(strategyOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function(self)
                VendorSniper.Config.searchStrategy = self.value
                UIDropDownMenu_SetSelectedValue(strategyDropdown, self.value)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    UIDropDownMenu_SetSelectedValue(strategyDropdown, VendorSniper.Config.searchStrategy)

    -- Profit settings (below strategy)
    local profitLabel = configSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    profitLabel:SetText("Profit:")
    profitLabel:SetPoint("TOPLEFT", strategyDropdown, "BOTTOMLEFT", 20, -20)

    local minProfitLabel = configSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    minProfitLabel:SetText("Min (copper):")
    minProfitLabel:SetPoint("TOPLEFT", profitLabel, "BOTTOMLEFT", 0, -8)

    local minProfitEditBox = CreateFrame("EditBox", nil, configSection, "InputBoxTemplate")
    minProfitEditBox:SetSize(80, 20)
    minProfitEditBox:SetPoint("TOPLEFT", minProfitLabel, "TOPRIGHT", 8, 0)
    minProfitEditBox:SetText(VendorSniper.Config.minProfitThreshold)
    minProfitEditBox:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())
        if value and value >= 0 then
            VendorSniper.Config.minProfitThreshold = value
        else
            self:SetText(VendorSniper.Config.minProfitThreshold)
        end
        self:ClearFocus()
    end)

    local minPercentLabel = configSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    minPercentLabel:SetText("Min %:")
    minPercentLabel:SetPoint("TOPLEFT", minProfitEditBox, "TOPRIGHT", 20, 0)

    local minPercentEditBox = CreateFrame("EditBox", nil, configSection, "InputBoxTemplate")
    minPercentEditBox:SetSize(60, 20)
    minPercentEditBox:SetPoint("TOPLEFT", minPercentLabel, "TOPRIGHT", 8, 0)
    minPercentEditBox:SetText(VendorSniper.Config.minProfitPercent)
    minPercentEditBox:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())
        if value and value >= 0 then
            VendorSniper.Config.minProfitPercent = value
        else
            self:SetText(VendorSniper.Config.minProfitPercent)
        end
        self:ClearFocus()
    end)

    -- STEP 5: Create filters section centered in the top bar
    local filtersSection = CreateFrame("Frame", nil, topControlBar)
    filtersSection:SetPoint("TOP", topControlBar, "TOP", 0, -15)
    filtersSection:SetPoint("BOTTOM", topControlBar, "BOTTOM", 0, 0)
    filtersSection:SetWidth(300) -- Fixed width for centering

    -- Filters title
    local filterTitle = filtersSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterTitle:SetText("Item Filters:")
    filterTitle:SetPoint("TOPLEFT", filtersSection, "TOPLEFT", 0, 0)

    -- Item filters (in two rows with better spacing)
    local checkboxes = {}
    local checkboxOptions = {
        {text = "Consumables", configKey = "includeConsumables"},
        {text = "Materials", configKey = "includeMaterials"},
        {text = "Equipment", configKey = "includeEquipment"},
        {text = "Trade Goods", configKey = "includeTradeGoods"}
    }

    for i, option in ipairs(checkboxOptions) do
        local checkbox = CreateFrame("CheckButton", nil, filtersSection, "UICheckButtonTemplate")
        local row = math.ceil(i / 2)
        local col = (i - 1) % 2
        checkbox:SetPoint("TOPLEFT", filterTitle, "BOTTOMLEFT", col * 140, -10 - (row - 1) * 25) -- Increased spacing
        checkbox:SetChecked(VendorSniper.Config[option.configKey])
        checkbox:SetScript("OnClick", function(self)
            VendorSniper.Config[option.configKey] = self:GetChecked()
        end)
        
        local checkboxText = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        checkboxText:SetText(option.text)
        checkboxText:SetPoint("LEFT", checkbox, "RIGHT", 8, 0) -- Increased text spacing
        
        checkboxes[option.configKey] = checkbox
    end

    -- STEP 6: Create performance section under the scan button
    local performanceSection = CreateFrame("Frame", nil, topControlBar)
    performanceSection:SetPoint("TOPLEFT", scanButton, "BOTTOMLEFT", 0, -15)
    performanceSection:SetPoint("BOTTOMRIGHT", topControlBar, "BOTTOMRIGHT", -15, 0)

    -- Performance settings (under scan button)
    local perfLabel = performanceSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    perfLabel:SetText("Performance:")
    perfLabel:SetPoint("TOPLEFT", performanceSection, "TOPLEFT", 0, 0)

    local cacheCheckbox = CreateFrame("CheckButton", nil, performanceSection, "UICheckButtonTemplate")
    cacheCheckbox:SetPoint("TOPLEFT", perfLabel, "BOTTOMLEFT", 0, -8)
    cacheCheckbox:SetChecked(VendorSniper.Config.enableCaching)
    cacheCheckbox:SetScript("OnClick", function(self)
        VendorSniper.Config.enableCaching = self:GetChecked()
    end)
    
    local cacheText = cacheCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cacheText:SetText("Cache")
    cacheText:SetPoint("LEFT", cacheCheckbox, "RIGHT", 8, 0) -- Increased text spacing

    local clearCacheButton = CreateFrame("Button", nil, performanceSection, "UIPanelButtonTemplate")
    clearCacheButton:SetSize(80, 20)
    clearCacheButton:SetPoint("TOPLEFT", cacheText, "TOPRIGHT", 20, 0) -- Increased button spacing
    clearCacheButton:SetText("Clear")
    clearCacheButton:SetScript("OnClick", function()
        VendorSniper:ClearCache()
    end)

    -- BVP status (automatic, no button)
    local bvpStatusText = performanceSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bvpStatusText:SetPoint("TOPLEFT", cacheCheckbox, "BOTTOMLEFT", 0, -8) -- Below cache checkbox
    bvpStatusText:SetText("BVP: Checking...")
    bvpStatusText:SetTextColor(1, 1, 0)

    -- STEP 7: Add progress bar (below scan button with proper spacing)
    local progressFrame = CreateFrame("Frame", nil, topControlBar)
    progressFrame:SetSize(250, 20)
    progressFrame:SetPoint("TOPLEFT", scanButton, "BOTTOMLEFT", 0, -15) -- Increased spacing
    progressFrame:Hide()

    local progressBg = progressFrame:CreateTexture(nil, "BACKGROUND")
    progressBg:SetAllPoints(true)
    progressBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

    local progressBar = progressFrame:CreateTexture(nil, "ARTWORK")
    progressBar:SetPoint("TOPLEFT", progressFrame, "TOPLEFT", 1, -1)
    progressBar:SetPoint("BOTTOMLEFT", progressFrame, "BOTTOMLEFT", 1, 1)
    progressBar:SetWidth(0)
    progressBar:SetColorTexture(0, 1, 0, 0.8)

    local progressText = progressFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    progressText:SetPoint("CENTER", progressFrame, "CENTER", 0, 0)
    progressText:SetText("0%")

    VendorSniperPanel.progressFrame = progressFrame
    VendorSniperPanel.progressBar = progressBar
    VendorSniperPanel.progressText = progressText

    -- STEP 7: Create results section (with proper spacing from top control bar)
    local resultsFrame = CreateFrame("Frame", nil, mainContentArea)
    resultsFrame:SetPoint("TOPLEFT", topControlBar, "BOTTOMLEFT", 0, -15) -- Increased spacing
    resultsFrame:SetPoint("BOTTOMRIGHT", mainContentArea, "BOTTOMRIGHT", 0, 0)

    -- STEP 8: Add subtle backgrounds for visual separation
    local configBg = configSection:CreateTexture(nil, "BACKGROUND")
    configBg:SetAllPoints(true)
    configBg:SetColorTexture(0.1, 0.1, 0.1, 0.2)

    local filtersBg = filtersSection:CreateTexture(nil, "BACKGROUND")
    filtersBg:SetAllPoints(true)
    filtersBg:SetColorTexture(0.1, 0.1, 0.1, 0.2)

    -- STEP 9: Add results title and content
    local resultsTitle = resultsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    resultsTitle:SetText("Scan Results")
    resultsTitle:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", 0, 0)
    
    -- Create background texture for Classic compatibility
    local bgTexture = resultsFrame:CreateTexture(nil, "BACKGROUND")
    bgTexture:SetAllPoints(true)
    bgTexture:SetColorTexture(0, 0, 0, 0.8)
    
    -- Create border textures for Classic compatibility
    local borderTop = resultsFrame:CreateTexture(nil, "BORDER")
    borderTop:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", -2, 2)
    borderTop:SetPoint("TOPRIGHT", resultsFrame, "TOPRIGHT", 2, 2)
    borderTop:SetHeight(2)
    borderTop:SetColorTexture(0.6, 0.6, 0.6, 1)
    
    local borderBottom = resultsFrame:CreateTexture(nil, "BORDER")
    borderBottom:SetPoint("BOTTOMLEFT", resultsFrame, "BOTTOMLEFT", -2, -2)
    borderBottom:SetPoint("BOTTOMRIGHT", resultsFrame, "BOTTOMRIGHT", 2, -2)
    borderBottom:SetHeight(2)
    borderBottom:SetColorTexture(0.6, 0.6, 0.6, 1)
    
    local borderLeft = resultsFrame:CreateTexture(nil, "BORDER")
    borderLeft:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", -2, 2)
    borderLeft:SetPoint("BOTTOMLEFT", resultsFrame, "BOTTOMLEFT", -2, -2)
    borderLeft:SetWidth(2)
    borderLeft:SetColorTexture(0.6, 0.6, 0.6, 1)
    
    local borderRight = resultsFrame:CreateTexture(nil, "BORDER")
    borderRight:SetPoint("TOPRIGHT", resultsFrame, "TOPRIGHT", 2, 2)
    borderRight:SetPoint("BOTTOMRIGHT", resultsFrame, "BOTTOMRIGHT", 2, -2)
    borderRight:SetWidth(2)
    borderRight:SetColorTexture(0.6, 0.6, 0.6, 1)

    -- Create scroll frame for results
    local scrollFrame = CreateFrame("ScrollFrame", nil, resultsFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", 8, -25)
    scrollFrame:SetPoint("BOTTOMRIGHT", resultsFrame, "BOTTOMRIGHT", -28, 8)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1000)
    scrollFrame:SetScrollChild(scrollChild)

    -- Create header
    local headerFrame = CreateFrame("Frame", nil, scrollChild)
    headerFrame:SetSize(scrollChild:GetWidth(), 20)
    headerFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)

    local headers = {
        { text = "Item", width = 200, point = "TOPLEFT" },
        { text = "Auction Price", width = 100, point = "TOPLEFT", offset = 200 },
        { text = "Vendor Price", width = 100, point = "TOPLEFT", offset = 300 },
        { text = "Profit", width = 100, point = "TOPLEFT", offset = 400 },
        { text = "Profit %", width = 80, point = "TOPLEFT", offset = 500 }
    }

    for i, header in ipairs(headers) do
        local headerText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        headerText:SetText(header.text)
        headerText:SetPoint(header.point, headerFrame, header.point, header.offset or 0, 0)
        headerText:SetTextColor(1, 1, 0)
    end

    -- Store references for later use
    VendorSniperPanel.scrollChild = scrollChild
    VendorSniperPanel.headerFrame = headerFrame

    -- Function to update progress
    function VendorSniperPanel:UpdateProgress(progress, searchTerm, current, total)
        if progress and progress > 0 and progress < 100 then
            self.progressFrame:Show()
            self.progressBar:SetWidth((progress / 100) * 248)
            self.progressText:SetText(string.format("%.1f%%", progress))
        else
            self.progressFrame:Hide()
        end
    end

    -- Function to add item in real-time
    function VendorSniperPanel:AddItemRealTime(itemData)
        local currentResults = VendorSniper:GetScanResults()
        local rowIndex = #currentResults
        
        local rowFrame = CreateFrame("Frame", nil, scrollChild)
        rowFrame:SetSize(scrollChild:GetWidth(), 20)
        rowFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -20 * (rowIndex + 1))

        -- Item name
        local itemText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        itemText:SetText(itemData.itemName)
        itemText:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 0, 0)
        itemText:SetWidth(190)

        -- Auction price
        local auctionText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        auctionText:SetText(VendorSniper:FormatMoney(itemData.auctionPrice))
        auctionText:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 200, 0)
        auctionText:SetTextColor(1, 1, 1)

        -- Vendor price
        local vendorText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        vendorText:SetText(VendorSniper:FormatMoney(itemData.vendorPrice))
        vendorText:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 300, 0)
        vendorText:SetTextColor(0, 1, 0)

        -- Profit
        local profitText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        profitText:SetText(VendorSniper:FormatMoney(itemData.profit))
        profitText:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 400, 0)
        profitText:SetTextColor(0, 1, 0)

        -- Profit percentage
        local percentText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        percentText:SetText(string.format("%.1f%%", itemData.profitPercent))
        percentText:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 500, 0)
        percentText:SetTextColor(0, 1, 0)

        -- Make row clickable to show item tooltip
        rowFrame:EnableMouse(true)
        rowFrame:SetScript("OnEnter", function()
            GameTooltip:SetOwner(rowFrame, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(itemData.itemID)
            GameTooltip:Show()
        end)
        rowFrame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -- Update scroll frame height
        scrollChild:SetHeight(math.max(1000, (#currentResults + 1) * 20))
    end

    -- Function to update the results display
    function VendorSniperPanel:UpdateResults()
        -- Clear existing results (but keep header)
        for i = 1, scrollChild:GetNumChildren() do
            local child = select(i, scrollChild:GetChildren())
            if child ~= headerFrame then
                child:Hide()
                child:SetParent(nil)
            end
        end

        local results = VendorSniper:GetScanResults()
        if not results or #results == 0 then
            statusText:SetText("No profitable items found")
            return
        end

        statusText:SetText(string.format("Found %d profitable items", #results))

        -- Create result rows
        for i, item in ipairs(results) do
            local rowFrame = CreateFrame("Frame", nil, scrollChild)
            rowFrame:SetSize(scrollChild:GetWidth(), 20)
            rowFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -20 * i)

            -- Item name
            local itemText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            itemText:SetText(item.itemName)
            itemText:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 0, 0)
            itemText:SetWidth(190)

            -- Auction price
            local auctionText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            auctionText:SetText(VendorSniper:FormatMoney(item.auctionPrice))
            auctionText:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 200, 0)
            auctionText:SetTextColor(1, 1, 1)

            -- Vendor price
            local vendorText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            vendorText:SetText(VendorSniper:FormatMoney(item.vendorPrice))
            vendorText:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 300, 0)
            vendorText:SetTextColor(0, 1, 0)

            -- Profit
            local profitText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            profitText:SetText(VendorSniper:FormatMoney(item.profit))
            profitText:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 400, 0)
            profitText:SetTextColor(0, 1, 0)

            -- Profit percentage
            local percentText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            percentText:SetText(string.format("%.1f%%", item.profitPercent))
            percentText:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 500, 0)
            percentText:SetTextColor(0, 1, 0)

            -- Make row clickable to show item tooltip
            rowFrame:EnableMouse(true)
            rowFrame:SetScript("OnEnter", function()
                GameTooltip:SetOwner(rowFrame, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(item.itemID)
                GameTooltip:Show()
            end)
            rowFrame:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end

        -- Update scroll frame height
        scrollChild:SetHeight(math.max(1000, (#results + 1) * 20))
    end

    -- Register the update function with the core
    VendorSniper.UpdateUIFunction = function()
        VendorSniperPanel:UpdateResults()
    end

    -- Set up progress callback
    VendorSniper:SetProgressCallback(function(progress, searchTerm, current, total, itemData)
        if itemData then
            -- Real-time item found
            VendorSniperPanel:AddItemRealTime(itemData)
        else
            -- Progress update
            VendorSniperPanel:UpdateProgress(progress, searchTerm, current, total)
        end
    end)

    -- Function to update BetterVendorPrice status (automatic)
    local function UpdateBvpStatus()
        if VendorSniper then
            local integration = VendorSniper:CheckBetterVendorPriceIntegration()
            if integration.working then
                bvpStatusText:SetText(string.format("BVP: ✅ (%s)", integration.version))
                bvpStatusText:SetTextColor(0, 1, 0)
            elseif integration.found then
                bvpStatusText:SetText("BVP: ⚠️ Found")
                bvpStatusText:SetTextColor(1, 1, 0)
            else
                bvpStatusText:SetText("BVP: ❌ Not found")
                bvpStatusText:SetTextColor(1, 0, 0)
            end
        end
    end

    -- Test BVP automatically at startup
    C_Timer.After(1.0, UpdateBvpStatus)

    -- Store references for later use
    VendorSniperPanel.scanButton = scanButton
    VendorSniperPanel.strategyDropdown = strategyDropdown
    VendorSniperPanel.minProfitEditBox = minProfitEditBox
    VendorSniperPanel.minPercentEditBox = minPercentEditBox
    VendorSniperPanel.checkboxes = checkboxes
    VendorSniperPanel.cacheCheckbox = cacheCheckbox
    VendorSniperPanel.bvpStatusText = bvpStatusText
end

local function CreateVendorSniperTab()
    local frame = AuctionFrame
    
    -- Wait longer to ensure all auction house tabs are fully loaded
    C_Timer.After(1.0, function()
        -- Check if our tab already exists
        for i = 1, frame.numTabs do
            local existingTab = frame["tab"..i]
            if existingTab and existingTab:GetText() == "VendorSniper" then
                print("✅ VendorSniper tab already exists")
                return
            end
        end
        
        -- Ensure we have the standard 3 tabs first (Browse, Auctions, Bid)
        if frame.numTabs < 3 then
            print("⚠️ Waiting for auction house tabs to load...")
            C_Timer.After(1.0, function()
                CreateVendorSniperTab()
            end)
            return
        end
        
        -- Force tab index to be 4 (after Browse, Auctions, Bid)
        local tabIndex = 4

        -- Use Blizzard's expected naming convention: "AuctionFrameTab4"
        local tabName = "AuctionFrameTab"..tabIndex
        local tab = CreateFrame("Button", tabName, frame, "CharacterFrameTabButtonTemplate")

        tab:SetID(tabIndex)
        tab:SetText("VendorSniper")
        
        -- Set the tab to auto-size based on text content
        tab:SetWidth(tab:GetTextWidth() + 30)
        
        -- Position the tab properly - try multiple approaches for Classic WoW
        local bidTab = _G["AuctionFrameTab3"] -- Bid tab
        local auctionsTab = _G["AuctionFrameTab2"] -- Auctions tab
        local browseTab = _G["AuctionFrameTab1"] -- Browse tab
        
        -- Calculate proper spacing based on Classic WoW tab system
        local spacing = 2 -- Classic WoW tabs typically have 2px gap
        
        if bidTab then
            -- Position after Bid tab with proper spacing
            tab:SetPoint("TOPLEFT", bidTab, "TOPRIGHT", spacing, 0)
        elseif auctionsTab then
            tab:SetPoint("TOPLEFT", auctionsTab, "TOPRIGHT", spacing, 0)
        elseif browseTab then
            tab:SetPoint("TOPLEFT", browseTab, "TOPRIGHT", spacing, 0)
        else
            -- Fallback to absolute positioning
            tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 7)
        end

        -- Register tab properly with Blizzard's system
        frame["tab"..tabIndex] = tab
        frame["Tab"..tabIndex] = tab  -- Blizzard expects both formats
        PanelTemplates_SetNumTabs(frame, tabIndex)
        PanelTemplates_EnableTab(frame, tabIndex)

        tab:SetScript("OnClick", function(self)
            -- Use Blizzard's tab system properly
            PanelTemplates_SetTab(frame, self:GetID())

            -- Hide all Auction House content panels
            if AuctionFrameBrowse then AuctionFrameBrowse:Hide() end
            if AuctionFrameAuctions then AuctionFrameAuctions:Hide() end
            if AuctionFrameBid then AuctionFrameBid:Hide() end
            
            -- Show our panel
            if VendorSniperPanel then
                VendorSniperPanel:Show()
                VendorSniperPanel:SetFrameLevel(AuctionFrame:GetFrameLevel() + 1)
            end
        end)
        
        -- Hook into other tab clicks to show appropriate panels when switching away from VendorSniper
        for i = 1, 3 do -- Only hook the 3 standard tabs
            local existingTab = _G["AuctionFrameTab"..i]
            if existingTab then
                local originalClick = existingTab:GetScript("OnClick")
                existingTab:SetScript("OnClick", function(self)
                    -- Use Blizzard's tab system properly
                    PanelTemplates_SetTab(frame, self:GetID())
                    
                    -- Hide our panel
                    if VendorSniperPanel then
                        VendorSniperPanel:Hide()
                    end
                    
                    -- Show the appropriate panel based on tab ID
                    if self:GetID() == 1 then
                        if AuctionFrameBrowse then AuctionFrameBrowse:Show() end
                    elseif self:GetID() == 2 then
                        if AuctionFrameAuctions then AuctionFrameAuctions:Show() end
                    elseif self:GetID() == 3 then
                        if AuctionFrameBid then AuctionFrameBid:Show() end
                    end
                    
                    -- Call original click handler if it exists
                    if originalClick then
                        originalClick(self)
                    end
                end)
            end
        end
        

    end)
end

local function SetupVendorSniperUI()
    print("✅ VendorSniper UI loaded")
    if not AuctionFrame then
        print("⚠️ AuctionFrame not loaded")
        return
    end

    CreateVendorSniperPanel()
    
    -- Wait for auction house to be fully ready before creating tab
    C_Timer.After(1.0, function()
        -- Ensure auction house tabs are loaded
        if not AuctionFrame.numTabs or AuctionFrame.numTabs < 3 then
            print("⚠️ Waiting for auction house tabs to fully load...")
            C_Timer.After(1.0, function()
                SetupVendorSniperUI()
            end)
            return
        end
        
        CreateVendorSniperTab()
        

    end)
end

-- Event hook
local f = CreateFrame("Frame")
f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:SetScript("OnEvent", function()
    print("⚙️ VendorSniper: Auction House opened")
    SetupVendorSniperUI()
end)