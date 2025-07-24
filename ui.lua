-- ui.lua

local function CreateVendorSniperPanel()
    if VendorSniperPanel then return end

    VendorSniperPanel = CreateFrame("Frame", "VendorSniperPanel", AuctionFrame)
    VendorSniperPanel:SetSize(700, 400)
    VendorSniperPanel:SetPoint("TOPLEFT", AuctionFrame, "TOPLEFT", 15, -60)
    VendorSniperPanel:Hide()

    local bg = VendorSniperPanel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0.05, 0.05, 0.1, 0.85)

    local title = VendorSniperPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetText("VendorSniper")
    title:SetPoint("TOP", VendorSniperPanel, "TOP", 0, -10)
endq

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

    -- Register tab properly
    frame["tab"..tabIndex] = tab
    PanelTemplates_SetNumTabs(frame, tabIndex)
    PanelTemplates_EnableTab(frame, tabIndex)

    tab:SetScript("OnClick", function(self)
        PanelTemplates_SetTab(frame, self:GetID())
        VendorSniperPanel:Show()

        -- Hide other default AH panels
        if AuctionFrameBrowse then AuctionFrameBrowse:Hide() end
        if AuctionFrameAuctions then AuctionFrameAuctions:Hide() end
        if AuctionFrameBid then AuctionFrameBid:Hide() end
    end)

    local frame = AuctionFrame
    local tabIndex = frame.numTabs + 1

    local tab = CreateFrame("Button", "VendorSniperTab", frame, "CharacterFrameTabButtonTemplate")
    tab:SetID(tabIndex)
    tab:SetText("VendorSniper")
    tab:SetWidth(tab:GetTextWidth() + 30)
    tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", (tabIndex - 1) * 80, 7)

    -- Register tab
    PanelTemplates_SetNumTabs(frame, tabIndex)
    frame["tab"..tabIndex] = tab
    frame["tab"..tabIndex] = tab  -- this is fine, but we also must do:
    frame["Tab"..tabIndex] = tab  -- Blizzard may expect this format
    frame["tab"..tabIndex] = tab
    
    table.insert(frame.Tabs or {}, tab)

    tab:SetScript("OnClick", function(self)
        PanelTemplates_SetTab(frame, self:GetID())

        VendorSniperPanel:Show()

        if AuctionFrameBrowse then AuctionFrameBrowse:Hide() end
        if AuctionFrameAuctions then AuctionFrameAuctions:Hide() end
        if AuctionFrameBid then AuctionFrameBid:Hide() end
    end)
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
