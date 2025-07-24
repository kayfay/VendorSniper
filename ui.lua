-- ui.lua

local function CreateVendorSniperPanel()
    if VendorSniperPanel then return end

    VendorSniperPanel = CreateFrame("Frame", "VendorSniperPanel", AuctionFrame)
    -- Make the panel cover the entire content area of the Auction House
    VendorSniperPanel:SetPoint("TOPLEFT", AuctionFrame, "TOPLEFT", 15, -60)
    VendorSniperPanel:SetPoint("BOTTOMRIGHT", AuctionFrame, "BOTTOMRIGHT", -15, 15)
    VendorSniperPanel:Hide()

    local bg = VendorSniperPanel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0.05, 0.05, 0.1, 0.85)

    local title = VendorSniperPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetText("VendorSniper")
    title:SetPoint("TOP", VendorSniperPanel, "TOP", 0, -15)

    -- Create scan button with more spacing
    local scanButton = CreateFrame("Button", nil, VendorSniperPanel, "UIPanelButtonTemplate")
    scanButton:SetSize(100, 25)
    scanButton:SetPoint("TOPLEFT", VendorSniperPanel, "TOPLEFT", 10, -50)
    scanButton:SetText("Start Scan")
    scanButton:SetScript("OnClick", function()
        if VendorSniper.IsScanning then
            VendorSniper:StopScan()
            scanButton:SetText("Start Scan")
        else
            VendorSniper:StartScan()
            scanButton:SetText("Stop Scan")
        end
    end)

    -- Create status text with proper spacing
    local statusText = VendorSniperPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("TOPLEFT", scanButton, "TOPRIGHT", 15, 0)
    statusText:SetText("Ready to scan")
    VendorSniperPanel.statusText = statusText

    -- Create progress bar with more spacing
    local progressFrame = CreateFrame("Frame", nil, VendorSniperPanel)
    progressFrame:SetSize(200, 20)
    progressFrame:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -25)
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

    -- Create results frame that fills most of the panel
    local resultsFrame = CreateFrame("Frame", nil, VendorSniperPanel)
    resultsFrame:SetPoint("TOPLEFT", VendorSniperPanel, "TOPLEFT", 10, -110)
    resultsFrame:SetPoint("BOTTOMRIGHT", VendorSniperPanel, "BOTTOMRIGHT", -10, 10)
    
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
    scrollFrame:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", 8, -8)
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
    VendorSniperPanel.scanButton = scanButton

    -- Function to update progress
    function VendorSniperPanel:UpdateProgress(progress, searchTerm, current, total)
        if progress then
            self.progressFrame:Show()
            self.progressBar:SetWidth((progress / 100) * 198) -- 200 - 2 for borders
            self.progressText:SetText(string.format("%.1f%%", progress))
            
            if searchTerm then
                statusText:SetText(string.format("Scanning: %s (%d/%d)", searchTerm, current, total))
            end
        else
            self.progressFrame:Hide()
            statusText:SetText("Ready to scan")
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
        -- Clear existing results
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
end

local function CreateVendorSniperTab()
    local frame = AuctionFrame
    local tabIndex = frame.numTabs + 1

    -- Use Blizzard's expected naming convention: "AuctionFrameTab4"
    local tabName = "AuctionFrameTab"..tabIndex
    local tab = CreateFrame("Button", tabName, frame, "CharacterFrameTabButtonTemplate")

    tab:SetID(tabIndex)
    tab:SetText("VendorSniper")
    tab:SetWidth(tab:GetTextWidth() + 30)
    tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", (tabIndex - 1) * 80, 7)

    -- Register tab properly with Blizzard's system
    frame["tab"..tabIndex] = tab
    frame["Tab"..tabIndex] = tab  -- Blizzard expects both formats
    PanelTemplates_SetNumTabs(frame, tabIndex)
    PanelTemplates_EnableTab(frame, tabIndex)

    tab:SetScript("OnClick", function(self)
        PanelTemplates_SetTab(frame, self:GetID())
        
        -- Hide all Auction House content panels
        if AuctionFrameBrowse then AuctionFrameBrowse:Hide() end
        if AuctionFrameAuctions then AuctionFrameAuctions:Hide() end
        if AuctionFrameBid then AuctionFrameBid:Hide() end
        
        -- Show our panel
        VendorSniperPanel:Show()
    end)
    
    -- Hook into other tab clicks to show appropriate panels when switching away from VendorSniper
    -- Use the proper tab references based on the frame structure
    for i = 1, frame.numTabs - 1 do
        local tab = frame["tab"..i]
        if tab then
            local originalClick = tab:GetScript("OnClick")
            if originalClick then
                tab:SetScript("OnClick", function(self)
                    -- Hide our panel
                    VendorSniperPanel:Hide()
                    
                    -- Show the appropriate panel based on tab ID
                    if self:GetID() == 1 then
                        if AuctionFrameBrowse then AuctionFrameBrowse:Show() end
                    elseif self:GetID() == 2 then
                        if AuctionFrameAuctions then AuctionFrameAuctions:Show() end
                    elseif self:GetID() == 3 then
                        if AuctionFrameBid then AuctionFrameBid:Show() end
                    end
                    
                    originalClick(self)
                end)
            end
        end
    end
end

local function SetupVendorSniperUI()
    print("✅ VendorSniper UI loaded")
    if not AuctionFrame then
        print("⚠️ AuctionFrame not loaded")
        return
    end

    CreateVendorSniperPanel()
    CreateVendorSniperTab()
end

-- Event hook
local f = CreateFrame("Frame")
f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:SetScript("OnEvent", function()
    print("⚙️ VendorSniper: Auction House opened")
    SetupVendorSniperUI()
end)
