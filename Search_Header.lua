local addonName, addonTable = ...

local OAK_SEARCH = addonTable.OAK_SEARCH
local theme = addonTable.SearchFrameTheme or {}
if not OAK_SEARCH or not theme.CreateFlatButton then
    return
end

local FLAT_TEX = theme.FLAT_TEX
local OAK_COLOR_BG = theme.OAK_COLOR_BG
local OAK_COLOR_PANE = theme.OAK_COLOR_PANE
local OAK_COLOR_BORDER = theme.OAK_COLOR_BORDER
local classColor = theme.classColor
local playerClass = theme.playerClass
local CreateFlatButton = theme.CreateFlatButton
local nativeSearchHost = addonTable.SearchNativeHost or {}

local searchOptions = {}
local supportersPanel

local function ApplyClassColor(text, classStr)
    local c = RAID_CLASS_COLORS[string.upper(classStr or "")]
    if c then
        return string.format("|cFF%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, text)
    end
    return "|cFFFFFFFF" .. (text or "") .. "|r"
end

local function RefreshSearchRIOAnchor()
    if addonTable.RefreshRIOAnchor then
        addonTable.RefreshRIOAnchor()
    elseif addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(OAK_SEARCH)
    end
end

local function GetSearchFilterPanel()
    return addonTable.SearchFilterPanel
end

local function GetSearchSupportersPanel()
    return addonTable.SearchSupportersPanel
end

local function GetSearchOptionsPanel()
    return addonTable.SearchOptionsPanel
end

local titleHeader = CreateFrame("Frame", nil, OAK_SEARCH)
titleHeader:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", 1, -1)
titleHeader:SetPoint("TOPRIGHT", OAK_SEARCH, "TOPRIGHT", -1, -1)
titleHeader:SetHeight(30)
local titleHeaderBg = titleHeader:CreateTexture(nil, "BACKGROUND")
titleHeaderBg:SetAllPoints()
titleHeaderBg:SetColorTexture(unpack(OAK_COLOR_PANE))

OAK_SEARCH.title = titleHeader:CreateFontString(nil, "OVERLAY", "OakLFG_FontLarge")
OAK_SEARCH.title:SetPoint("LEFT", titleHeader, "LEFT", 15, 0)
OAK_SEARCH.title:SetText(ApplyClassColor("OAK", playerClass) .. " LFG Sorter")

local scaleSlider = CreateFrame("Slider", "OakSearchScaleSlider", titleHeader, "BackdropTemplate")
scaleSlider:SetSize(80, 10)
scaleSlider:SetPoint("LEFT", OAK_SEARCH.title, "RIGHT", 45, 0)
scaleSlider:SetMinMaxValues(0.5, 1.5)
scaleSlider:SetValueStep(0.05)
scaleSlider:SetObeyStepOnDrag(true)
scaleSlider:SetOrientation("HORIZONTAL")
scaleSlider:SetBackdrop({ bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1 })
scaleSlider:SetBackdropColor(0.05, 0.05, 0.05, 1)
scaleSlider:SetBackdropBorderColor(0, 0, 0, 1)
local scaleThumb = scaleSlider:CreateTexture(nil, "ARTWORK")
scaleThumb:SetTexture(FLAT_TEX)
scaleThumb:SetVertexColor(classColor.r, classColor.g, classColor.b, 1)
scaleThumb:SetSize(10, 14)
scaleSlider:SetThumbTexture(scaleThumb)
local scaleLabel = scaleSlider:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
scaleLabel:SetPoint("RIGHT", scaleSlider, "LEFT", -8, 0)
scaleLabel:SetText("Scale")

local scaleEdit = CreateFrame("EditBox", nil, titleHeader, "BackdropTemplate")
scaleEdit:SetSize(35, 18)
scaleEdit:SetPoint("LEFT", scaleSlider, "RIGHT", 10, 0)
scaleEdit:SetAutoFocus(false)
scaleEdit:SetFontObject("OakLFG_FontRegular")
scaleEdit:SetJustifyH("CENTER")
scaleEdit:SetBackdrop({ bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1 })
scaleEdit:SetBackdropColor(unpack(OAK_COLOR_BG))
scaleEdit:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))

local closeBtn = CreateFrame("Button", nil, titleHeader)
closeBtn:SetSize(30, 30)
closeBtn:SetPoint("RIGHT", titleHeader, "RIGHT", 0, 0)
local closeBg = closeBtn:CreateTexture(nil, "BACKGROUND")
closeBg:SetAllPoints()
closeBg:SetColorTexture(0, 0, 0, 0)
closeBtn.text = closeBtn:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
closeBtn.text:SetPoint("CENTER")
closeBtn.text:SetText("X")
closeBtn:SetScript("OnClick", function() OAK_SEARCH:Hide() end)
closeBtn:SetScript("OnEnter", function()
    closeBg:SetColorTexture(classColor.r, classColor.g, classColor.b, 0.5)
end)
closeBtn:SetScript("OnLeave", function()
    closeBg:SetColorTexture(0, 0, 0, 0)
end)

local scaleReset = CreateFlatButton(titleHeader, "Reset", 45)
scaleReset:SetPoint("LEFT", scaleEdit, "RIGHT", 5, 0)

local toggleFiltersBtn = CreateFlatButton(titleHeader, "Filters", 60)
toggleFiltersBtn:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)

local refreshBtn = CreateFlatButton(titleHeader, "Refresh", 60)
refreshBtn:SetPoint("RIGHT", toggleFiltersBtn, "LEFT", -5, 0)

OAK_SEARCH.footerText = OAK_SEARCH:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
OAK_SEARCH.footerText:SetPoint("BOTTOMLEFT", OAK_SEARCH, "BOTTOMLEFT", 15, 7)
OAK_SEARCH.footerText:SetTextColor(0.6, 0.6, 0.6)

OAK_SEARCH.footerVersionText = OAK_SEARCH:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
OAK_SEARCH.footerVersionText:SetPoint("BOTTOMRIGHT", OAK_SEARCH, "BOTTOMRIGHT", -18, 7)
OAK_SEARCH.footerVersionText:SetTextColor(0.53, 0.53, 0.53)
local addonVersion = "dev"
if C_AddOns and C_AddOns.GetAddOnMetadata then
    addonVersion = C_AddOns.GetAddOnMetadata(addonName, "Version") or addonVersion
elseif GetAddOnMetadata then
    addonVersion = GetAddOnMetadata(addonName, "Version") or addonVersion
end
OAK_SEARCH.footerVersionText:SetText(string.format("|cff888888v%s|r", addonVersion))

local suppBtn = CreateFlatButton(OAK_SEARCH, "Supporters & Links", 150)
suppBtn:SetPoint("BOTTOM", OAK_SEARCH, "BOTTOM", -14, 2)

local optionsBtn = addonTable.CreateCogButton(OAK_SEARCH, 22)
optionsBtn:SetPoint("LEFT", suppBtn, "RIGHT", 6, 0)
optionsBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Options", 1, 1, 1)
    GameTooltip:AddLine("Open shared Oak display options.", 1, 1, 1, true)
    GameTooltip:Show()
end)
optionsBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)

OAK_SEARCH.ScaleSlider = scaleSlider
OAK_SEARCH.ScaleEdit = scaleEdit
OAK_SEARCH.ScaleReset = scaleReset
OAK_SEARCH.ToggleFiltersBtn = toggleFiltersBtn
OAK_SEARCH.RefreshBtn = refreshBtn
OAK_SEARCH.SupportersButton = suppBtn
OAK_SEARCH.OptionsButton = optionsBtn

local resizeGrip = CreateFrame("Button", nil, OAK_SEARCH, "PanelResizeButtonTemplate")
resizeGrip:SetPoint("BOTTOMRIGHT", OAK_SEARCH, "BOTTOMRIGHT", -2, 2)
resizeGrip:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then
        OAK_SEARCH:StartSizing("BOTTOMRIGHT")
    end
end)
resizeGrip:SetScript("OnMouseUp", function()
    OAK_SEARCH:StopMovingOrSizing()
    if addonTable.SearchSaveFramePosition then
        addonTable.SearchSaveFramePosition()
    end
end)

scaleSlider:SetScript("OnMouseDown", function(self)
    self.isDragging = true
end)
scaleSlider:SetScript("OnMouseUp", function(self)
    self.isDragging = false
    local rounded = math.floor(self:GetValue() * 100 + 0.5) / 100
    if addonTable.SearchApplyScale then
        addonTable.SearchApplyScale(rounded)
    end
end)
scaleSlider:SetScript("OnValueChanged", function(self, value)
    local rounded = math.floor(value * 100 + 0.5) / 100
    scaleEdit:SetText(string.format("%.2f", rounded))
    if not self.isDragging and addonTable.SearchApplyScale then
        addonTable.SearchApplyScale(rounded)
    end
end)
scaleEdit:SetScript("OnEnterPressed", function(self)
    local val = tonumber(self:GetText())
    if val then
        val = math.max(0.5, math.min(1.5, val))
        scaleSlider:SetValue(val)
    end
    self:ClearFocus()
end)

scaleReset:SetScript("OnClick", function()
    if addonTable.ResetSearchWindow then
        addonTable.ResetSearchWindow()
    end
end)

refreshBtn:SetScript("OnClick", function()
    if LFGListFrame and LFGListFrame.SearchPanel then
        LFGListSearchPanel_DoSearch(LFGListFrame.SearchPanel)
        if addonTable.RequestSearchUpdate then
            C_Timer.After(0.15, function()
                if addonTable.RequestSearchUpdate then
                    addonTable.RequestSearchUpdate()
                end
            end)
        end
    end
end)

supportersPanel = CreateFrame("Frame", nil, OAK_SEARCH, "BackdropTemplate")
addonTable.SearchSupportersPanel = supportersPanel
supportersPanel:SetSize(190, 444)
supportersPanel:SetPoint("TOPLEFT", OAK_SEARCH, "TOPRIGHT", -2, 0)
supportersPanel:Hide()
supportersPanel:SetFrameLevel(OAK_SEARCH:GetFrameLevel() - 1)
supportersPanel:SetBackdrop({
    bgFile = FLAT_TEX, edgeFile = FLAT_TEX, tile = false, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
supportersPanel:SetBackdropColor(unpack(OAK_COLOR_BG))
supportersPanel:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
supportersPanel:HookScript("OnShow", RefreshSearchRIOAnchor)
supportersPanel:HookScript("OnHide", RefreshSearchRIOAnchor)

searchOptions.panel = CreateFrame("Frame", nil, OAK_SEARCH, "BackdropTemplate")
addonTable.SearchOptionsPanel = searchOptions.panel
searchOptions.panel:SetSize(205, 476)
searchOptions.panel:SetPoint("TOPLEFT", OAK_SEARCH, "TOPRIGHT", -2, 0)
searchOptions.panel:Hide()
searchOptions.panel:SetFrameLevel(OAK_SEARCH:GetFrameLevel() - 1)
searchOptions.panel:SetBackdrop({
    bgFile = FLAT_TEX, edgeFile = FLAT_TEX, tile = false, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
searchOptions.panel:SetBackdropColor(unpack(OAK_COLOR_BG))
searchOptions.panel:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
searchOptions.panel:HookScript("OnShow", RefreshSearchRIOAnchor)
searchOptions.panel:HookScript("OnHide", RefreshSearchRIOAnchor)

searchOptions.title = searchOptions.panel:CreateFontString(nil, "OVERLAY", "OakLFG_FontLarge")
searchOptions.title:SetPoint("TOP", searchOptions.panel, "TOP", 0, -10)
searchOptions.title:SetText("Options")
searchOptions.title:SetTextColor(classColor.r, classColor.g, classColor.b)

searchOptions.regionBox = CreateFrame("Button", nil, searchOptions.panel, "BackdropTemplate")
searchOptions.regionBox:SetSize(16, 16)
searchOptions.regionBox:SetBackdrop({ bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1 })
searchOptions.regionBox:SetPoint("TOPLEFT", searchOptions.panel, "TOPLEFT", 15, -42)
searchOptions.regionLabel = searchOptions.panel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
searchOptions.regionLabel:SetPoint("LEFT", searchOptions.regionBox, "RIGHT", 8, 0)
searchOptions.regionLabel:SetText("Show Regions")

function searchOptions.regionBox:SetState(isActive)
    if isActive then
        self:SetBackdropColor(classColor.r, classColor.g, classColor.b, 1)
        self:SetBackdropBorderColor(0, 0, 0, 1)
        searchOptions.regionLabel:SetTextColor(1, 1, 1)
    else
        self:SetBackdropColor(0.08, 0.08, 0.10, 0.95)
        self:SetBackdropBorderColor(classColor.r * 0.65, classColor.g * 0.65, classColor.b * 0.65, 1)
        searchOptions.regionLabel:SetTextColor(0.84, 0.84, 0.84)
    end
end

searchOptions.regionBox:SetScript("OnClick", function(self)
    OakLFGSorterDB.showRegions = not (OakLFGSorterDB and OakLFGSorterDB.showRegions == true)
    if addonTable.SyncSharedRegionToggles then
        addonTable.SyncSharedRegionToggles()
    end
    if addonTable.SyncSearchRegionToggle then
        addonTable.SyncSearchRegionToggle()
    else
        self:SetState(OakLFGSorterDB.showRegions == true)
    end
    if OAK_SEARCH.UpdateDisplay then
        OAK_SEARCH:UpdateDisplay()
    end
    if addonTable.UpdateDisplay then
        addonTable.UpdateDisplay()
    end
end)
searchOptions.regionBox:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Regions", 1, 1, 1)
    GameTooltip:AddLine("Show visible region abbreviations in Oak rows and add region details to tooltips.", 1, 1, 1, true)
    GameTooltip:Show()
end)
searchOptions.regionBox:SetScript("OnLeave", function(self)
    self:SetState(OakLFGSorterDB and OakLFGSorterDB.showRegions == true)
    GameTooltip:Hide()
end)

searchOptions.lowLatencyBox = CreateFrame("Button", nil, searchOptions.panel, "BackdropTemplate")
searchOptions.lowLatencyBox:SetSize(16, 16)
searchOptions.lowLatencyBox:SetBackdrop({ bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1 })
searchOptions.lowLatencyBox:SetPoint("TOPLEFT", searchOptions.panel, "TOPLEFT", 15, -74)
searchOptions.lowLatencyLabel = searchOptions.panel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
searchOptions.lowLatencyLabel:SetPoint("LEFT", searchOptions.lowLatencyBox, "RIGHT", 8, 0)
searchOptions.lowLatencyLabel:SetText("Low Latency")

function searchOptions.lowLatencyBox:SetState(isActive)
    if isActive then
        self:SetBackdropColor(classColor.r, classColor.g, classColor.b, 1)
        self:SetBackdropBorderColor(0, 0, 0, 1)
        searchOptions.lowLatencyLabel:SetTextColor(1, 1, 1)
    else
        self:SetBackdropColor(0.08, 0.08, 0.10, 0.95)
        self:SetBackdropBorderColor(classColor.r * 0.65, classColor.g * 0.65, classColor.b * 0.65, 1)
        searchOptions.lowLatencyLabel:SetTextColor(0.84, 0.84, 0.84)
    end
end

searchOptions.lowLatencyBox:SetScript("OnClick", function(self)
    OakLFGSorterDB.lowLatencyOnly = not (OakLFGSorterDB and OakLFGSorterDB.lowLatencyOnly == true)
    if addonTable.SyncSharedLowLatencyToggles then
        addonTable.SyncSharedLowLatencyToggles()
    else
        self:SetState(OakLFGSorterDB.lowLatencyOnly == true)
        if OAK_SEARCH.UpdateDisplay then
            OAK_SEARCH:UpdateDisplay()
        end
        if addonTable.UpdateDisplay then
            addonTable.UpdateDisplay()
        end
    end
end)
searchOptions.lowLatencyBox:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Low Latency", 1, 1, 1)
    GameTooltip:AddLine("Show only groups from your own region to avoid higher-latency listings.", 1, 1, 1, true)
    GameTooltip:Show()
end)
searchOptions.lowLatencyBox:SetScript("OnLeave", function(self)
    self:SetState(OakLFGSorterDB and OakLFGSorterDB.lowLatencyOnly == true)
    GameTooltip:Hide()
end)

searchOptions.fontLabel = searchOptions.panel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
searchOptions.fontLabel:SetPoint("TOPLEFT", searchOptions.panel, "TOPLEFT", 15, -106)
searchOptions.fontLabel:SetText("Addon Font")
searchOptions.fontButton, searchOptions.fontList = addonTable.CreateFontDropdown(searchOptions.panel, 170)
searchOptions.fontButton:SetPoint("TOPLEFT", searchOptions.panel, "TOPLEFT", 15, -126)

searchOptions.fontSizeLabel = searchOptions.panel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
searchOptions.fontSizeLabel:SetPoint("TOPLEFT", searchOptions.panel, "TOPLEFT", 15, -162)
searchOptions.fontSizeLabel:SetText("Font Size")
searchOptions.fontSizeValue = searchOptions.panel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
searchOptions.fontSizeValue:SetPoint("RIGHT", searchOptions.panel, "TOPRIGHT", -15, -162)

searchOptions.fontSizeSlider = CreateFrame("Slider", nil, searchOptions.panel, "BackdropTemplate")
searchOptions.fontSizeSlider:SetSize(170, 10)
searchOptions.fontSizeSlider:SetPoint("TOPLEFT", searchOptions.panel, "TOPLEFT", 15, -184)
searchOptions.fontSizeSlider:SetMinMaxValues(10, 18)
searchOptions.fontSizeSlider:SetValueStep(1)
searchOptions.fontSizeSlider:SetObeyStepOnDrag(true)
searchOptions.fontSizeSlider:SetOrientation("HORIZONTAL")
searchOptions.fontSizeSlider:SetBackdrop({ bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1 })
searchOptions.fontSizeSlider:SetBackdropColor(0.05, 0.05, 0.05, 1)
searchOptions.fontSizeSlider:SetBackdropBorderColor(0, 0, 0, 1)
local fontSizeThumb = searchOptions.fontSizeSlider:CreateTexture(nil, "ARTWORK")
fontSizeThumb:SetTexture(FLAT_TEX)
fontSizeThumb:SetVertexColor(classColor.r, classColor.g, classColor.b, 1)
fontSizeThumb:SetSize(10, 14)
searchOptions.fontSizeSlider:SetThumbTexture(fontSizeThumb)
searchOptions.fontSizeSlider:SetScript("OnValueChanged", function(_, value)
    local rounded = math.floor((value or 12) + 0.5)
    searchOptions.fontSizeValue:SetText(tostring(rounded))
    if addonTable.SetFontSize then
        addonTable.SetFontSize(rounded)
        addonTable.RefreshRegisteredFontDropdowns()
    end
end)
searchOptions.fontSizeSlider:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Font Size", 1, 1, 1)
    GameTooltip:AddLine("Adjust the base Oak font size used throughout the addon.", 1, 1, 1, true)
    GameTooltip:Show()
end)
searchOptions.fontSizeSlider:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

searchOptions.opacityLabel = searchOptions.panel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
searchOptions.opacityLabel:SetPoint("TOPLEFT", searchOptions.panel, "TOPLEFT", 15, -220)
searchOptions.opacityLabel:SetText("Window Opacity")
searchOptions.opacityValue = searchOptions.panel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
searchOptions.opacityValue:SetPoint("RIGHT", searchOptions.panel, "TOPRIGHT", -15, -220)

searchOptions.opacitySlider = CreateFrame("Slider", nil, searchOptions.panel, "BackdropTemplate")
searchOptions.opacitySlider:SetSize(170, 10)
searchOptions.opacitySlider:SetPoint("TOPLEFT", searchOptions.panel, "TOPLEFT", 15, -242)
searchOptions.opacitySlider:SetMinMaxValues(0.35, 1.0)
searchOptions.opacitySlider:SetValueStep(0.05)
searchOptions.opacitySlider:SetObeyStepOnDrag(true)
searchOptions.opacitySlider:SetOrientation("HORIZONTAL")
searchOptions.opacitySlider:SetBackdrop({ bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1 })
searchOptions.opacitySlider:SetBackdropColor(0.05, 0.05, 0.05, 1)
searchOptions.opacitySlider:SetBackdropBorderColor(0, 0, 0, 1)
local opacityThumb = searchOptions.opacitySlider:CreateTexture(nil, "ARTWORK")
opacityThumb:SetTexture(FLAT_TEX)
opacityThumb:SetVertexColor(classColor.r, classColor.g, classColor.b, 1)
opacityThumb:SetSize(10, 14)
searchOptions.opacitySlider:SetThumbTexture(opacityThumb)
searchOptions.opacitySlider:SetScript("OnValueChanged", function(_, value)
    local rounded = math.floor(value * 100 + 0.5) / 100
    searchOptions.opacityValue:SetText(string.format("%d%%", rounded * 100))
    if addonTable.SetWindowOpacity then
        addonTable.SetWindowOpacity(rounded)
    end
end)
searchOptions.opacitySlider:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Window Opacity", 1, 1, 1)
    GameTooltip:AddLine("Adjust the background opacity used by Oak's windows and side panels.", 1, 1, 1, true)
    GameTooltip:Show()
end)
searchOptions.opacitySlider:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
searchOptions.opacitySlider:SetValue(addonTable.GetWindowOpacity and addonTable.GetWindowOpacity() or 0.85)
searchOptions.fontSizeSlider:SetValue(addonTable.GetFontSize and addonTable.GetFontSize() or 12)

function searchOptions:Refresh()
    if self.regionBox and self.regionBox.SetState then
        self.regionBox:SetState(OakLFGSorterDB and OakLFGSorterDB.showRegions == true)
    end
    if self.lowLatencyBox and self.lowLatencyBox.SetState then
        self.lowLatencyBox:SetState(OakLFGSorterDB and OakLFGSorterDB.lowLatencyOnly == true)
    end
    if self.fontButton and self.fontButton.RefreshSelection then
        self.fontButton:RefreshSelection()
    end
    if self.fontSizeSlider and addonTable.GetFontSize then
        self.fontSizeSlider:SetValue(addonTable.GetFontSize())
    end
    if self.opacitySlider and addonTable.GetWindowOpacity then
        self.opacitySlider:SetValue(addonTable.GetWindowOpacity())
    end
end

addonTable.RefreshSearchOptionsPanel = function()
    if searchOptions.Refresh then
        searchOptions:Refresh()
    end
end

local function ToggleSearchOptionsPanel()
    local filterPanel = GetSearchFilterPanel()
    if searchOptions.panel:IsShown() then
        searchOptions.panel:Hide()
    else
        if GetSearchSupportersPanel() then
            GetSearchSupportersPanel():Hide()
        end
        if filterPanel then
            filterPanel:Hide()
        end
        if searchOptions.Refresh then
            searchOptions:Refresh()
        end
        searchOptions.panel:Show()
    end
    RefreshSearchRIOAnchor()
end

optionsBtn:SetScript("OnClick", ToggleSearchOptionsPanel)

if addonTable.ApplyWindowOpacity then
    addonTable.ApplyWindowOpacity()
end

local suppTitle = supportersPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontLarge")
suppTitle:SetPoint("TOP", supportersPanel, "TOP", 0, -10)
suppTitle:SetText("Supporters")
suppTitle:SetTextColor(classColor.r, classColor.g, classColor.b)

local suppScroll = CreateFrame("ScrollFrame", "OakSearchSupportersScroll", supportersPanel, "UIPanelScrollFrameTemplate")
suppScroll:SetPoint("TOPLEFT", supportersPanel, "TOPLEFT", 10, -35)
suppScroll:SetPoint("BOTTOMRIGHT", supportersPanel, "BOTTOMRIGHT", -25, 160)
local suppScrollChild = CreateFrame("Frame")
suppScrollChild:SetSize(suppScroll:GetWidth(), 1)
suppScroll:SetScrollChild(suppScrollChild)

local suppScrollBar = _G[suppScroll:GetName() .. "ScrollBar"]
if suppScrollBar then
    local upBtn = _G[suppScroll:GetName() .. "ScrollBarScrollUpButton"]
    local downBtn = _G[suppScroll:GetName() .. "ScrollBarScrollDownButton"]
    if upBtn then upBtn:Hide(); upBtn:SetSize(0.1, 0.1) end
    if downBtn then downBtn:Hide(); downBtn:SetSize(0.1, 0.1) end
    local topTex = _G[suppScroll:GetName() .. "ScrollBarTop"]
    local bottomTex = _G[suppScroll:GetName() .. "ScrollBarBottom"]
    local midTex = _G[suppScroll:GetName() .. "ScrollBarMiddle"]
    if topTex then topTex:Hide() end
    if bottomTex then bottomTex:Hide() end
    if midTex then midTex:Hide() end
    local thumbTex = suppScrollBar:GetThumbTexture()
    if thumbTex then
        thumbTex:SetTexture(FLAT_TEX)
        thumbTex:SetVertexColor(classColor.r, classColor.g, classColor.b, 1)
        thumbTex:SetSize(8, 60)
    end
    suppScrollBar:SetWidth(8)
end

local syOffset = 0
if addonTable.Patreons then
    for _, name in ipairs(addonTable.Patreons) do
        local pt = suppScrollChild:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
        pt:SetPoint("TOPLEFT", suppScrollChild, "TOPLEFT", 5, syOffset)
        pt:SetText(name)
        pt:SetTextColor(0.8, 0.8, 0.8)
        syOffset = syOffset - 18
    end
end
suppScrollChild:SetHeight(math.max(1, math.abs(syOffset)))

local socialY = -275
if addonTable.Socials then
    for _, social in ipairs(addonTable.Socials) do
        local btn = CreateFlatButton(supportersPanel, social.name, 160)
        btn:SetPoint("TOP", supportersPanel, "TOP", 0, socialY)
        btn:SetScript("OnClick", function()
            StaticPopup_Show("OAK_LFG_URL_COPY", "", "", social.url)
        end)
        socialY = socialY - 25
    end
end

suppBtn:SetScript("OnClick", function()
    local filterPanel = GetSearchFilterPanel()
    if supportersPanel:IsShown() then
        supportersPanel:Hide()
    else
        if filterPanel then
            filterPanel:Hide()
        end
        if searchOptions.panel then
            searchOptions.panel:Hide()
        end
        supportersPanel:Show()
    end
    RefreshSearchRIOAnchor()
end)

toggleFiltersBtn:SetScript("OnClick", function()
    local filterPanel = GetSearchFilterPanel()
    if not filterPanel then
        return
    end
    if filterPanel:IsShown() then
        filterPanel:Hide()
        if nativeSearchHost.RestoreNativeSearchBox then
            nativeSearchHost.RestoreNativeSearchBox()
        end
    else
        supportersPanel:Hide()
        if searchOptions.panel then
            searchOptions.panel:Hide()
        end
        filterPanel:Show()
        if nativeSearchHost.AttachNativeSearchBoxToOak then
            nativeSearchHost.AttachNativeSearchBoxToOak()
        end
    end
    RefreshSearchRIOAnchor()
end)

scaleSlider:SetValue(OakLFGSorterDB.searchScale or 1.0)
scaleEdit:SetText(string.format("%.2f", OakLFGSorterDB.searchScale or 1.0))
if addonTable.SearchApplyScale then
    addonTable.SearchApplyScale(OakLFGSorterDB.searchScale or 1.0)
end
if addonTable.SearchAutoPosition then
    addonTable.SearchAutoPosition()
end
