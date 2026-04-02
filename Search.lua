local addonName, addonTable = ...

-- ==========================================
-- 1. Shared Constants & Colors
-- ==========================================
local FLAT_TEX = "Interface\\Buttons\\WHITE8X8"
local OAK_COLOR_BG = {0.106, 0.106, 0.129, 0.85} 
local OAK_COLOR_PANE = {0.137, 0.141, 0.172, 1}
local OAK_COLOR_BORDER = {0, 0, 0, 1}
local ROW_COLOR_A = {0.2, 0.22, 0.28, 0.4} 
local ROW_COLOR_B = {0, 0, 0, 0} 
local ROW_HEIGHT = 34 

local _, playerClass = UnitClass("player")
local classColor = RAID_CLASS_COLORS[playerClass] or {r = 1, g = 1, b = 1}
local CreateFlatButton
local supportersPanel
local filterPanel
local ApplySearchNotesLayout
local RequestUpdate
local ApplyOakSearchQuery
local ScheduleSearchRefresh
local searchQueryBtn
local resetFiltersBtn
local ResetSearchFilters
local GetNativeSearchBox
local AttachNativeSearchBoxToOak
local RestoreNativeSearchBox
local ShouldHostNativeSearchBox
local AutoPositionSearch
local UpdateSearchFilterPane

local function ApplyClassColor(text, classStr)
    local c = RAID_CLASS_COLORS[string.upper(classStr or "")]
    if c then return string.format("|cFF%02x%02x%02x%s|r", c.r*255, c.g*255, c.b*255, text) end
    return "|cFFFFFFFF" .. (text or "") .. "|r"
end

-- ==========================================
-- 2. Search Frame Setup
-- ==========================================
local OAK_SEARCH = CreateFrame("Frame", "OakensoulLFGSearchFrame", UIParent, "BackdropTemplate")
OAK_SEARCH:SetSize(660, 444) 
OAK_SEARCH:SetPoint("CENTER") 
OAK_SEARCH:SetMovable(true)
OAK_SEARCH:SetResizable(true)
OAK_SEARCH:SetResizeBounds(510, 444, 660, 800) 
OAK_SEARCH:EnableMouse(true)
OAK_SEARCH:RegisterForDrag("LeftButton")
OAK_SEARCH:SetFrameStrata("DIALOG")
OAK_SEARCH:Hide()
addonTable.OAK_SEARCH = OAK_SEARCH

OakLFGSorterDB = OakLFGSorterDB or {}
if OakLFGSorterDB.autoOpenSearch == nil then OakLFGSorterDB.autoOpenSearch = true end
if OakLFGSorterDB.searchScale == nil then OakLFGSorterDB.searchScale = 1.0 end
if OakLFGSorterDB.searchHideNotes == nil then OakLFGSorterDB.searchHideNotes = false end

local function SaveSearchFramePosition()
    local point, _, relativePoint, xOfs, yOfs = OAK_SEARCH:GetPoint(1)
    if point then
        OakLFGSorterDB.searchFramePos = { point, relativePoint or point, xOfs or 0, yOfs or 0 }
        OakLFGSorterDB.searchFrameUserPlaced = true
    end
end

local function RestoreSearchFramePosition()
    if OakLFGSorterDB.searchFramePos then
        local pos = OakLFGSorterDB.searchFramePos
        OAK_SEARCH:ClearAllPoints()
        OAK_SEARCH:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
        return true
    end
    return false
end

local function HasSavedSearchFramePosition()
    return OakLFGSorterDB
        and OakLFGSorterDB.searchFrameUserPlaced
        and type(OakLFGSorterDB.searchFramePos) == "table"
        and #OakLFGSorterDB.searchFramePos >= 4
end

local function ApplySearchScale(scaleValue)
    local rounded = math.floor((tonumber(scaleValue) or 1.0) * 100 + 0.5) / 100

    OAK_SEARCH:SetScale(rounded)
    OakLFGSorterDB.searchScale = rounded

    if HasSavedSearchFramePosition() then
        RestoreSearchFramePosition()
    else
        AutoPositionSearch()
    end

    if addonTable.RefreshRIOAnchor then
        addonTable.RefreshRIOAnchor()
    elseif addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(OAK_SEARCH)
    end
end

local function HideApplicantWindow()
    if addonTable.OAK_LFG and addonTable.OAK_LFG:IsShown() then
        addonTable.OAK_LFG:Hide()
    end
end

OAK_SEARCH:SetScript("OnDragStart", OAK_SEARCH.StartMoving)
OAK_SEARCH:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveSearchFramePosition()
end)

tinsert(UISpecialFrames, "OakensoulLFGSearchFrame") -- Enables closing with Escape key

OAK_SEARCH:SetBackdrop({
    bgFile = FLAT_TEX, edgeFile = FLAT_TEX,
    tile = false, edgeSize = 1, 
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
})
OAK_SEARCH:SetBackdropColor(unpack(OAK_COLOR_BG))
OAK_SEARCH:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)

local titleHeader = CreateFrame("Frame", nil, OAK_SEARCH)
titleHeader:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", 1, -1) 
titleHeader:SetPoint("TOPRIGHT", OAK_SEARCH, "TOPRIGHT", -1, -1) 
titleHeader:SetHeight(30)
local thBg = titleHeader:CreateTexture(nil, "BACKGROUND")
thBg:SetAllPoints(); thBg:SetColorTexture(unpack(OAK_COLOR_PANE))

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
scaleSlider:SetBackdrop({bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1})
scaleSlider:SetBackdropColor(0.05, 0.05, 0.05, 1)
scaleSlider:SetBackdropBorderColor(0, 0, 0, 1)

local thumb = scaleSlider:CreateTexture(nil, "ARTWORK")
thumb:SetTexture(FLAT_TEX)
thumb:SetVertexColor(classColor.r, classColor.g, classColor.b, 1)
thumb:SetSize(10, 14)
scaleSlider:SetThumbTexture(thumb)

local scaleLabel = scaleSlider:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
scaleLabel:SetPoint("RIGHT", scaleSlider, "LEFT", -8, 0)
scaleLabel:SetText("Scale")

local scaleEdit = CreateFrame("EditBox", nil, titleHeader, "BackdropTemplate")
scaleEdit:SetSize(35, 18)
scaleEdit:SetPoint("LEFT", scaleSlider, "RIGHT", 10, 0)
scaleEdit:SetAutoFocus(false)
scaleEdit:SetFontObject("OakLFG_FontRegular")
scaleEdit:SetJustifyH("CENTER")
scaleEdit:SetBackdrop({bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1})
scaleEdit:SetBackdropColor(unpack(OAK_COLOR_BG))
scaleEdit:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))

local closeBtn = CreateFrame("Button", nil, titleHeader)
closeBtn:SetSize(30, 30); closeBtn:SetPoint("RIGHT", titleHeader, "RIGHT", 0, 0)
local clBg = closeBtn:CreateTexture(nil, "BACKGROUND")
clBg:SetAllPoints(); clBg:SetColorTexture(0, 0, 0, 0)
closeBtn.text = closeBtn:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
closeBtn.text:SetPoint("CENTER"); closeBtn.text:SetText("X")
closeBtn:SetScript("OnClick", function() OAK_SEARCH:Hide() end)
closeBtn:SetScript("OnEnter", function() clBg:SetColorTexture(classColor.r, classColor.g, classColor.b, 0.5) end)
closeBtn:SetScript("OnLeave", function() clBg:SetColorTexture(0, 0, 0, 0) end)

function CreateFlatButton(parent, label, width)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, 22)
    btn:SetBackdrop({bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1})
    btn:SetBackdropColor(unpack(OAK_COLOR_PANE)) 
    btn:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))
    btn.text = btn:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    btn.text:SetPoint("CENTER"); btn.text:SetText(label)
    btn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER)) end)
    return btn
end

local scaleReset = CreateFlatButton(titleHeader, "Reset", 45)
scaleReset:SetPoint("LEFT", scaleEdit, "RIGHT", 5, 0)

local resizeGrip = CreateFrame("Button", nil, OAK_SEARCH, "PanelResizeButtonTemplate")
resizeGrip:SetPoint("BOTTOMRIGHT", OAK_SEARCH, "BOTTOMRIGHT", -2, 2)
resizeGrip:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then OAK_SEARCH:StartSizing("BOTTOMRIGHT") end
end)
resizeGrip:SetScript("OnMouseUp", function(self, button)
    OAK_SEARCH:StopMovingOrSizing()
    SaveSearchFramePosition()
end)

local toggleFiltersBtn = CreateFlatButton(titleHeader, "Filters", 60)
toggleFiltersBtn:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)

local refreshBtn = CreateFlatButton(titleHeader, "Refresh", 60)
refreshBtn:SetPoint("RIGHT", toggleFiltersBtn, "LEFT", -5, 0)
refreshBtn:SetScript("OnClick", function()
    if LFGListFrame and LFGListFrame.SearchPanel then
        LFGListSearchPanel_DoSearch(LFGListFrame.SearchPanel)
        if RequestUpdate then
            C_Timer.After(0.15, function()
                RequestUpdate()
            end)
        end
    end
end)

OAK_SEARCH.footerText = OAK_SEARCH:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
OAK_SEARCH.footerText:SetPoint("BOTTOMLEFT", OAK_SEARCH, "BOTTOMLEFT", 15, 7)
OAK_SEARCH.footerText:SetTextColor(0.6, 0.6, 0.6)

local suppBtn = CreateFlatButton(OAK_SEARCH, "Supporters and Social Links", 190)
suppBtn:SetPoint("BOTTOM", OAK_SEARCH, "BOTTOM", 0, 2)

scaleSlider:SetScript("OnMouseDown", function(self) self.isDragging = true end)
scaleSlider:SetScript("OnMouseUp", function(self)
    self.isDragging = false
    local rounded = math.floor(self:GetValue() * 100 + 0.5) / 100
    ApplySearchScale(rounded)
end)
scaleSlider:SetScript("OnValueChanged", function(self, value)
    local rounded = math.floor(value * 100 + 0.5) / 100
    scaleEdit:SetText(string.format("%.2f", rounded))
    if not self.isDragging then
        ApplySearchScale(rounded)
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

AutoPositionSearch = function()
    if HasSavedSearchFramePosition() and RestoreSearchFramePosition() then
        if addonTable.AnchorRIOPanelToOak then
            addonTable.AnchorRIOPanelToOak(OAK_SEARCH)
        end
        return
    end
    if PVEFrame and PVEFrame:IsShown() then
        OAK_SEARCH:ClearAllPoints()
        OAK_SEARCH:SetPoint("TOPLEFT", PVEFrame, "TOPRIGHT", 2, 0)
        if addonTable.AnchorRIOPanelToOak then
            addonTable.AnchorRIOPanelToOak(OAK_SEARCH)
        end
    elseif not OAK_SEARCH:GetPoint() then
        OAK_SEARCH:ClearAllPoints()
        OAK_SEARCH:SetPoint("CENTER")
    end
end

function addonTable.ResetSearchWindow()
    OakLFGSorterDB.searchFramePos = nil
    OakLFGSorterDB.searchFrameUserPlaced = false
    OakLFGSorterDB.searchScale = 1.0
    OakLFGSorterDB.searchHideNotes = false
    scaleSlider:SetValue(1.0)
    scaleEdit:SetText("1.00")
    ApplySearchScale(1.0)
    ApplySearchNotesLayout()
end

scaleReset:SetScript("OnClick", function()
    addonTable.ResetSearchWindow()
end)

scaleSlider:SetValue(OakLFGSorterDB.searchScale)
scaleEdit:SetText(string.format("%.2f", OakLFGSorterDB.searchScale))
ApplySearchScale(OakLFGSorterDB.searchScale)
AutoPositionSearch()

supportersPanel = CreateFrame("Frame", nil, OAK_SEARCH, "BackdropTemplate")
addonTable.SearchSupportersPanel = supportersPanel
supportersPanel:SetSize(190, 444)
supportersPanel:SetPoint("TOPLEFT", OAK_SEARCH, "TOPRIGHT", -2, 0)
supportersPanel:Hide()
supportersPanel:SetFrameLevel(OAK_SEARCH:GetFrameLevel() - 1)
supportersPanel:SetBackdrop({
    bgFile = FLAT_TEX, edgeFile = FLAT_TEX, tile = false, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
})
supportersPanel:SetBackdropColor(unpack(OAK_COLOR_BG))
supportersPanel:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
supportersPanel:HookScript("OnShow", function()
    if addonTable.RefreshRIOAnchor then
        addonTable.RefreshRIOAnchor()
    elseif addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(OAK_SEARCH)
    end
end)
supportersPanel:HookScript("OnHide", function()
    if addonTable.RefreshRIOAnchor then
        addonTable.RefreshRIOAnchor()
    elseif addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(OAK_SEARCH)
    end
end)

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
    if supportersPanel:IsShown() then
        supportersPanel:Hide()
    else
        filterPanel:Hide()
        supportersPanel:Show()
    end
    if addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(OAK_SEARCH)
    end
end)

-- ==========================================
-- 3. Filter Panel Setup
-- ==========================================
filterPanel = CreateFrame("Frame", nil, OAK_SEARCH, "BackdropTemplate")
addonTable.SearchFilterPanel = filterPanel
filterPanel:SetSize(205, 444) 
filterPanel:SetPoint("TOPLEFT", OAK_SEARCH, "TOPRIGHT", -2, 0)
filterPanel:Hide()
filterPanel:SetFrameLevel(OAK_SEARCH:GetFrameLevel() - 1) 
filterPanel:SetBackdrop({
    bgFile = FLAT_TEX, edgeFile = FLAT_TEX, tile = false, edgeSize = 1, 
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
})
filterPanel:SetBackdropColor(unpack(OAK_COLOR_BG))
filterPanel:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
filterPanel:HookScript("OnShow", function()
    if addonTable.RefreshRIOAnchor then
        addonTable.RefreshRIOAnchor()
    elseif addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(OAK_SEARCH)
    end
end)
filterPanel:HookScript("OnHide", function()
    if addonTable.RefreshRIOAnchor then
        addonTable.RefreshRIOAnchor()
    elseif addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(OAK_SEARCH)
    end
end)

local filterTitle = filterPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontLarge")
filterTitle:SetPoint("TOP", filterPanel, "TOP", 0, -10)
filterTitle:SetText("Search Filters")
filterTitle:SetTextColor(classColor.r, classColor.g, classColor.b)

toggleFiltersBtn:SetScript("OnClick", function()
    if filterPanel:IsShown() then
        filterPanel:Hide()
        if RestoreNativeSearchBox then
            RestoreNativeSearchBox()
        end
    else
        supportersPanel:Hide()
        filterPanel:Show()
        if AttachNativeSearchBoxToOak then
            AttachNativeSearchBoxToOak()
        end
    end
    if addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(OAK_SEARCH)
    end
end)

local function CreateOakDropdown(parent, width, defaultText, options, callback)
    local frame = CreateFrame("Button", nil, parent, "BackdropTemplate")
    frame:SetSize(width, 22)
    frame:SetBackdrop({bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1})
    frame:SetBackdropColor(unpack(OAK_COLOR_PANE)) 
    frame:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))
    
    frame.text = frame:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    frame.text:SetPoint("LEFT", frame, "LEFT", 8, 0)
    frame.text:SetText(defaultText)
    
    local arrow = frame:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\BUTTONS\\Arrow-Down-Up")
    arrow:SetSize(12, 12)
    arrow:SetPoint("RIGHT", frame, "RIGHT", -5, 0)

    local listFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -1)
    listFrame:SetWidth(width)
    listFrame:SetHeight(#options * 22 + 2)
    listFrame:SetBackdrop({bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1})
    listFrame:SetBackdropColor(unpack(OAK_COLOR_PANE))
    listFrame:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
    listFrame:SetFrameStrata("TOOLTIP")
    listFrame:Hide()
    frame.optionButtons = {}
    frame.options = {}
    
    frame:SetScript("OnClick", function()
        if listFrame:IsShown() then listFrame:Hide() else listFrame:Show() end
    end)
    frame:SetScript("OnHide", function() listFrame:Hide() end)

    function frame:SetValue(selectedValue)
        self.selectedValue = selectedValue
        for _, option in ipairs(self.options) do
            if option.value == selectedValue then
                self.text:SetText(option.label)
                return
            end
        end
        self.text:SetText(defaultText)
    end

    function frame:SetOptions(newOptions)
        self.options = newOptions or {}
        listFrame:SetHeight((#self.options * 22) + 2)

        for index, option in ipairs(self.options) do
            local btn = self.optionButtons[index]
            if not btn then
                btn = CreateFrame("Button", nil, listFrame, "BackdropTemplate")
                btn:SetSize(width - 2, 22)

                local btnBg = btn:CreateTexture(nil, "BACKGROUND")
                btnBg:SetAllPoints()
                btnBg:SetColorTexture(unpack(OAK_COLOR_BG))

                local hoverBg = btn:CreateTexture(nil, "HIGHLIGHT")
                hoverBg:SetAllPoints()
                hoverBg:SetColorTexture(classColor.r, classColor.g, classColor.b, 0.3)

                btn.text = btn:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
                btn.text:SetPoint("LEFT", btn, "LEFT", 8, 0)
                self.optionButtons[index] = btn
            end

            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 1, -((index - 1) * 22) - 1)
            btn.text:SetText(option.label)
            btn:SetScript("OnClick", function()
                frame:SetValue(option.value)
                listFrame:Hide()
                if callback then callback(option.value, option.label, index) end
            end)
            btn:Show()
        end

        for index = #self.options + 1, #self.optionButtons do
            self.optionButtons[index]:Hide()
        end
    end

    frame:SetOptions(options)
    return frame
end

local DEFAULT_SEASON_DUNGEONS = {
    "Maisara Caverns", "Nexus-Point Xenas", "Magisters' Terrace",
    "Windrunner Spire", "Algeth'ar Academy", "Seat of the Triumvirate",
    "Skyreach", "Pit of Saron"
}

local DEFAULT_SEASON_DELVES = {
    "Atal'Aman",
    "Collegiate Calamity",
    "Parhelion Plaza",
    "Shadowguard Point",
    "Sunkiller Sanctum",
    "The Darkway",
    "The Grudge Pit",
    "The Gulf of Memory",
    "The Shadow Enclave",
    "Torment's Rise",
    "Twilight Crypts",
}

local SEARCH_DELVE_LABEL_LOOKUP = {}
for _, delveName in ipairs(DEFAULT_SEASON_DELVES) do
    SEARCH_DELVE_LABEL_LOOKUP[strlower(delveName)] = true
end

local SEARCH_FIVE_MAN_DIFFICULTY_OPTIONS = {
    { value = "ANY", label = "Any Difficulty" },
    { value = "NORMAL", label = "Normal" },
    { value = "HEROIC", label = "Heroic" },
    { value = "MYTHIC", label = "Mythic" },
    { value = "MYTHIC_PLUS", label = "Mythic+" },
}

local SEARCH_DIFFICULTY_OPTIONS = {
    mythic_plus = SEARCH_FIVE_MAN_DIFFICULTY_OPTIONS,
    dungeon = SEARCH_FIVE_MAN_DIFFICULTY_OPTIONS,
    raid = {
        { value = "ANY", label = "Any Difficulty" },
        { value = "NORMAL", label = "Normal" },
        { value = "HEROIC", label = "Heroic" },
        { value = "MYTHIC", label = "Mythic" },
    },
}

local currentSearchMode = "generic"
local currentActivityFilters = {}
local filterDungeonButtons = {}
local filterActivityTitle
local keyRangeLabel
local keyRangeHint
local keyQueryBox
local boxNeedTank
local boxHasTank
local boxNeedHeal
local boxHasHeal
local boxNeedDPS
local boxParty
local boxLust
local boxBrez
local divTexture
local filterDungeonContainer
local nativeDungeonFilterScroll
local nativeDungeonFilterContent
local nativeDungeonActivityButtons = {}
local nativeNeedsTankBox
local nativeNeedsHealBox
local nativeNeedsDpsBox
local nativeNeedsMyClassBox
local nativeHasTankBox
local nativeHasHealBox
local nativePartyBox
local nativeLustBox
local nativeBrezBox
local nativeMinimumRatingLabel
local nativeMinimumRatingBox
local nativeActivityLabel
local nativePGFWarningBox
local nativePGFWarningText
local nativeSearchBoxHost
local nativeSearchBoxOriginalState
local nativeAutoCompleteOriginalState

local OAK_F = {
    Difficulty = "ANY",
    HasTank = false,
    NeedTank = false,
    HasHeal = false,
    NeedHeal = false,
    NeedDPS = false,
    NeedLust = false,
    NeedBrez = false,
    PartyFit = false,
    SearchQuery = "",
    Activities = {},
}

for _, dun in ipairs(DEFAULT_SEASON_DUNGEONS) do
    OAK_F.Activities[dun] = false
end
for _, delve in ipairs(DEFAULT_SEASON_DELVES) do
    OAK_F.Activities[delve] = false
end

local function SearchModeUsesDifficulty(mode)
    return mode == "mythic_plus" or mode == "dungeon" or mode == "raid"
end

local function SearchModeUsesActivityFilters(mode)
    return mode == "mythic_plus" or mode == "dungeon" or mode == "raid" or mode == "delve"
end

local function SearchModeUsesHostedSearch(mode)
    return mode == "mythic_plus" or mode == "dungeon" or mode == "generic" or mode == "delve"
end

local function SearchModeUsesNativeDungeonFilters(mode)
    return mode == "mythic_plus" or mode == "dungeon"
end

local function GetSearchDifficultyOptions(mode)
    return SEARCH_DIFFICULTY_OPTIONS[mode] or {}
end

local function SearchDifficultyIsValidForMode(mode, difficultyValue)
    if difficultyValue == "ANY" then
        return true
    end

    for _, option in ipairs(GetSearchDifficultyOptions(mode)) do
        if option.value == difficultyValue then
            return true
        end
    end

    return false
end

local function GetSearchActivitySectionTitle(mode)
    if mode == "raid" then
        return "Filter Raids"
    elseif mode == "delve" then
        return "Filter Delves"
    elseif mode == "mythic_plus" or mode == "dungeon" then
        return "Filter Dungeons"
    end

    return nil
end

local function GetSearchQueryLabel(mode)
    if mode == "mythic_plus" then
        return "Examples: 12-13, <10, 12 pit", ""
    elseif mode == "dungeon" or mode == "delve" or mode == "generic" then
        return "Use Blizzard search terms", ""
    end

    return "", ""
end

local function GetAdvancedSearchFilter()
    if C_LFGList and C_LFGList.GetAdvancedFilter then
        return C_LFGList.GetAdvancedFilter() or {}
    end

    return {}
end

local function IsAddonLoadedCompat(addonNameToCheck)
    if not addonNameToCheck or addonNameToCheck == "" then
        return false
    end

    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local loaded = C_AddOns.IsAddOnLoaded(addonNameToCheck)
        if loaded then
            return true
        end
    end

    if IsAddOnLoaded then
        local loaded = IsAddOnLoaded(addonNameToCheck)
        if loaded then
            return true
        end
    end

    return false
end

local function IsPGFDetected()
    local addonNames = {
        "PremadeGroupsFilter",
        "PremadeGroupFilter",
        "PGF",
    }

    for _, addonKey in ipairs(addonNames) do
        if IsAddonLoadedCompat(addonKey) then
            return true
        end
    end

    return false
end

local function SaveAdvancedSearchFilter(mutator)
    if not (C_LFGList and C_LFGList.SaveAdvancedFilter) then
        OAK_SEARCH:UpdateDisplay()
        return
    end

    local adv = GetAdvancedSearchFilter()
    if mutator then
        mutator(adv)
    end
    C_LFGList.SaveAdvancedFilter(adv)
    if OAK_SEARCH and OAK_SEARCH.UpdateDisplay then
        OAK_SEARCH:UpdateDisplay()
    end
end

-- Native API Syncer for Advanced Filters
local function SyncNativeFilters()
    SaveAdvancedSearchFilter(function(adv)
        adv.needsTank = OAK_F.NeedTank and true or nil
        adv.needsHealer = OAK_F.NeedHeal and true or nil
        adv.needsDamage = OAK_F.NeedDPS and true or nil
        adv.hasTank = OAK_F.HasTank and true or nil
        adv.hasHealer = OAK_F.HasHeal and true or nil
    end)
end

local function CreateOakToggleBox(parent, label, stateKey, triggersSync)
    local box = CreateFrame("Button", nil, parent, "BackdropTemplate")
    box:SetSize(16, 16) 
    box:SetBackdrop({bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1})
    local text = parent:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    text:SetPoint("LEFT", box, "RIGHT", 5, 0); text:SetText(label)
    box.labelText = text

    function box:SetState(isActive)
        if isActive then
            self:SetBackdropColor(classColor.r, classColor.g, classColor.b, 1) 
            self:SetBackdropBorderColor(0, 0, 0, 1) 
        else
            self:SetBackdropColor(0.106, 0.106, 0.129, 0.95)
            self:SetBackdropBorderColor(classColor.r * 0.65, classColor.g * 0.65, classColor.b * 0.65, 1)
        end
    end
    
    box:SetState(OAK_F[stateKey])
    box:SetScript("OnClick", function(self)
        OAK_F[stateKey] = not OAK_F[stateKey]
        self:SetState(OAK_F[stateKey])
        if triggersSync then SyncNativeFilters() else OAK_SEARCH:UpdateDisplay() end
    end)
    return box
end

local function CreateStandaloneToggleBox(parent, label)
    local box = CreateFrame("Button", nil, parent, "BackdropTemplate")
    box:SetSize(16, 16)
    box:SetBackdrop({bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1})
    box:SetBackdropColor(0.106, 0.106, 0.129, 0.95)
    box:SetBackdropBorderColor(classColor.r * 0.65, classColor.g * 0.65, classColor.b * 0.65, 1)

    local text = parent:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    text:SetPoint("LEFT", box, "RIGHT", 5, 0)
    text:SetText(label or "")
    box.labelText = text

    function box:SetLabel(newLabel)
        self.labelText:SetText(newLabel or "")
    end

    function box:SetState(isActive)
        if isActive then
            self:SetBackdropColor(classColor.r, classColor.g, classColor.b, 1)
            self:SetBackdropBorderColor(0, 0, 0, 1)
        else
            self:SetBackdropColor(0.106, 0.106, 0.129, 0.95)
            self:SetBackdropBorderColor(classColor.r * 0.65, classColor.g * 0.65, classColor.b * 0.65, 1)
        end
    end

    return box
end

local function CreateStandaloneNumberBox(parent, width)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetFontObject("OakLFG_FontRegular")
    box:SetJustifyH("CENTER")
    box:SetBackdrop({ bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1 })
    box:SetBackdropColor(unpack(OAK_COLOR_PANE))
    box:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))
    return box
end

GetNativeSearchBox = function()
    return LFGListFrame and LFGListFrame.SearchPanel and LFGListFrame.SearchPanel.SearchBox
end

AttachNativeSearchBoxToOak = function()
    local searchBox = GetNativeSearchBox()
    if not (searchBox and keyQueryBox) then
        return
    end
    if not ShouldHostNativeSearchBox() then
        return
    end

    if not nativeSearchBoxOriginalState then
        local point, relativeTo, relativePoint, xOfs, yOfs = searchBox:GetPoint(1)
        nativeSearchBoxOriginalState = {
            parent = searchBox:GetParent(),
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs,
            width = searchBox:GetWidth(),
            height = searchBox:GetHeight(),
            frameLevel = searchBox:GetFrameLevel(),
            frameStrata = searchBox:GetFrameStrata(),
            onEnterPressed = searchBox:GetScript("OnEnterPressed"),
            onEscapePressed = searchBox:GetScript("OnEscapePressed"),
        }
    end

    keyQueryBox.SearchBox = searchBox
    if LFGListFrame and LFGListFrame.SearchPanel then
        keyQueryBox.AutoCompleteFrame = LFGListFrame.SearchPanel.AutoCompleteFrame
        if keyQueryBox.AutoCompleteFrame then
            local autoCompleteFrame = keyQueryBox.AutoCompleteFrame
            if not nativeAutoCompleteOriginalState then
                local point, relativeTo, relativePoint, xOfs, yOfs = autoCompleteFrame:GetPoint(1)
                nativeAutoCompleteOriginalState = {
                    parent = autoCompleteFrame:GetParent(),
                    point = point,
                    relativeTo = relativeTo,
                    relativePoint = relativePoint,
                    xOfs = xOfs,
                    yOfs = yOfs,
                    frameLevel = autoCompleteFrame:GetFrameLevel(),
                    frameStrata = autoCompleteFrame:GetFrameStrata(),
                }
            end
            autoCompleteFrame:SetParent(filterPanel)
            autoCompleteFrame:ClearAllPoints()
            autoCompleteFrame:SetPoint("TOPLEFT", keyQueryBox, "BOTTOMLEFT", 0, -2)
            autoCompleteFrame:SetFrameStrata("TOOLTIP")
            autoCompleteFrame:SetFrameLevel(filterPanel:GetFrameLevel() + 30)
        end
    end
    searchBox:ClearAllPoints()
    searchBox:SetParent(keyQueryBox)
    searchBox:SetPoint("TOPLEFT", keyQueryBox, "TOPLEFT", 0, 0)
    searchBox:SetPoint("BOTTOMRIGHT", keyQueryBox, "BOTTOMRIGHT", 0, 0)
    searchBox:SetFrameStrata("DIALOG")
    searchBox:SetFrameLevel(keyQueryBox:GetFrameLevel() + 5)
    searchBox:SetScript("OnEnterPressed", function(self)
        LFGListSearchPanel_DoSearch(LFGListFrame.SearchPanel)
        if RequestUpdate then
            C_Timer.After(0.15, function()
                RequestUpdate()
            end)
        end
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    searchBox:Show()
end

RestoreNativeSearchBox = function()
    local searchBox = GetNativeSearchBox()
    if not (searchBox and nativeSearchBoxOriginalState) then
        return
    end

    keyQueryBox.SearchBox = nil
    keyQueryBox.AutoCompleteFrame = nil
    if nativeAutoCompleteOriginalState and LFGListFrame and LFGListFrame.SearchPanel and LFGListFrame.SearchPanel.AutoCompleteFrame then
        local autoCompleteFrame = LFGListFrame.SearchPanel.AutoCompleteFrame
        autoCompleteFrame:SetParent(nativeAutoCompleteOriginalState.parent)
        autoCompleteFrame:ClearAllPoints()
        if nativeAutoCompleteOriginalState.point and nativeAutoCompleteOriginalState.relativeTo then
            autoCompleteFrame:SetPoint(
                nativeAutoCompleteOriginalState.point,
                nativeAutoCompleteOriginalState.relativeTo,
                nativeAutoCompleteOriginalState.relativePoint,
                nativeAutoCompleteOriginalState.xOfs,
                nativeAutoCompleteOriginalState.yOfs
            )
        end
        if nativeAutoCompleteOriginalState.frameStrata then
            autoCompleteFrame:SetFrameStrata(nativeAutoCompleteOriginalState.frameStrata)
        end
        if nativeAutoCompleteOriginalState.frameLevel then
            autoCompleteFrame:SetFrameLevel(nativeAutoCompleteOriginalState.frameLevel)
        end
    end
    searchBox:ClearAllPoints()
    if nativeSearchBoxOriginalState.parent then
        searchBox:SetParent(nativeSearchBoxOriginalState.parent)
    end
    if nativeSearchBoxOriginalState.point and nativeSearchBoxOriginalState.relativeTo then
        searchBox:SetPoint(
            nativeSearchBoxOriginalState.point,
            nativeSearchBoxOriginalState.relativeTo,
            nativeSearchBoxOriginalState.relativePoint,
            nativeSearchBoxOriginalState.xOfs,
            nativeSearchBoxOriginalState.yOfs
        )
    end
    if nativeSearchBoxOriginalState.width and nativeSearchBoxOriginalState.height then
        searchBox:SetSize(nativeSearchBoxOriginalState.width, nativeSearchBoxOriginalState.height)
    end
    if nativeSearchBoxOriginalState.frameStrata then
        searchBox:SetFrameStrata(nativeSearchBoxOriginalState.frameStrata)
    end
    if nativeSearchBoxOriginalState.frameLevel then
        searchBox:SetFrameLevel(nativeSearchBoxOriginalState.frameLevel)
    end
    if nativeSearchBoxOriginalState.onEnterPressed then
        searchBox:SetScript("OnEnterPressed", nativeSearchBoxOriginalState.onEnterPressed)
    end
    if nativeSearchBoxOriginalState.onEscapePressed then
        searchBox:SetScript("OnEscapePressed", nativeSearchBoxOriginalState.onEscapePressed)
    end
    searchBox:Show()
end

-- Dropdowns
local diffDropdown = CreateOakDropdown(filterPanel, 175, "Any Difficulty", GetSearchDifficultyOptions(currentSearchMode), function(value)
    OAK_F.Difficulty = value
    if ApplyOakSearchQuery then
        ApplyOakSearchQuery(false)
    end
    OAK_SEARCH:UpdateDisplay()
end)
diffDropdown:SetPoint("TOP", filterPanel, "TOP", 0, -35)

keyRangeLabel = filterPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
keyRangeLabel:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, -67)
keyRangeLabel:SetWidth(175)
keyRangeLabel:SetJustifyH("LEFT")
keyRangeLabel:SetText("Examples: 12-13, <10, 12 pit")
keyRangeLabel:SetTextColor(0.68, 0.68, 0.68)

keyRangeHint = filterPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
keyRangeHint:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, -82)
keyRangeHint:SetWidth(175)
keyRangeHint:SetJustifyH("LEFT")
keyRangeHint:SetText("")
keyRangeHint:SetTextColor(0.7, 0.7, 0.7)

keyQueryBox = CreateFrame("Frame", nil, filterPanel, "BackdropTemplate")
keyQueryBox:SetSize(175, 22)
keyQueryBox:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, -88)
keyQueryBox:SetBackdrop({ bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1 })
keyQueryBox:SetBackdropColor(unpack(OAK_COLOR_PANE))
keyQueryBox:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))

searchQueryBtn = CreateFlatButton(filterPanel, "Search", 175)
searchQueryBtn:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, -116)
searchQueryBtn:SetScript("OnClick", function()
    if ApplyOakSearchQuery then
        ApplyOakSearchQuery(true)
    end
end)

resetFiltersBtn = CreateFlatButton(filterPanel, "Reset", 84)
resetFiltersBtn:SetPoint("TOPLEFT", searchQueryBtn, "TOPRIGHT", 7, 0)
resetFiltersBtn:SetScript("OnClick", function()
    ResetSearchFilters()
end)

-- Modern 2-Column Exact Layout Match
local startY = -148
local col1X = 16
local col2X = 110

boxNeedTank = CreateOakToggleBox(filterPanel, "Need Tank", "NeedTank", true)
boxNeedTank:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", col1X, startY)

boxHasTank = CreateOakToggleBox(filterPanel, "Has Tank", "HasTank", false)
boxHasTank:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", col2X, startY)

boxNeedHeal = CreateOakToggleBox(filterPanel, "Need Heals", "NeedHeal", true)
boxNeedHeal:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", col1X, startY - 22)

boxHasHeal = CreateOakToggleBox(filterPanel, "Has Heals", "HasHeal", false)
boxHasHeal:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", col2X, startY - 22)

boxNeedDPS = CreateOakToggleBox(filterPanel, "Need DPS", "NeedDPS", true)
boxNeedDPS:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", col1X, startY - 44)

boxParty = CreateOakToggleBox(filterPanel, "Party Fit", "PartyFit", false)
boxParty:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", col2X, startY - 44)

boxLust = CreateOakToggleBox(filterPanel, "Need Lust", "NeedLust", false)
boxLust:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", col1X, startY - 66)

boxBrez = CreateOakToggleBox(filterPanel, "Need BRez", "NeedBrez", false)
boxBrez:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", col2X, startY - 66)

divTexture = filterPanel:CreateTexture(nil, "ARTWORK")
divTexture:SetColorTexture(classColor.r, classColor.g, classColor.b, 0.5)
divTexture:SetSize(175, 1)
divTexture:SetPoint("TOP", filterPanel, "TOP", 0, startY - 90)

filterActivityTitle = filterPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
filterActivityTitle:SetPoint("TOP", filterPanel, "TOPLEFT", 95, startY - 100)
filterActivityTitle:SetText("Filter Dungeons")
filterActivityTitle:SetTextColor(classColor.r, classColor.g, classColor.b)

filterDungeonContainer = CreateFrame("Frame", nil, filterPanel)
filterDungeonContainer:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 10, startY - 115)
filterDungeonContainer:SetPoint("BOTTOMRIGHT", filterPanel, "BOTTOMRIGHT", -10, 10)

local dy = -5
for index = 1, 18 do
    local box = CreateFrame("Button", nil, filterDungeonContainer, "BackdropTemplate")
    box:SetSize(14, 14)
    box:SetBackdrop({bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1})
    box:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))

    box.text = box:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
    box.text:SetPoint("LEFT", box, "RIGHT", 5, 0)
    box.text:SetWidth(155)
    box.text:SetJustifyH("LEFT")
    box.text:SetWordWrap(false)
    box:SetBackdropColor(0.106, 0.106, 0.129, 1)

    box:SetScript("OnClick", function(self)
        if not self.activityName or self.activityName == "" then
            return
        end
        OAK_F.Activities[self.activityName] = not OAK_F.Activities[self.activityName]
        if OAK_F.Activities[self.activityName] then
            self:SetBackdropColor(classColor.r, classColor.g, classColor.b, 1)
        else
            self:SetBackdropColor(0.106, 0.106, 0.129, 1)
        end
        OAK_SEARCH:UpdateDisplay()
    end)
    box:SetPoint("TOPLEFT", filterDungeonContainer, "TOPLEFT", 5, dy)
    box:Hide()
    dy = dy - 15
    filterDungeonButtons[index] = box
end

nativeDungeonFilterScroll = CreateFrame("ScrollFrame", "OakLFGNativeDungeonFilterScroll", filterPanel, "UIPanelScrollFrameTemplate")
nativeDungeonFilterScroll:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 10, -148)
nativeDungeonFilterScroll:SetPoint("BOTTOMRIGHT", filterPanel, "BOTTOMRIGHT", -12, 10)
nativeDungeonFilterScroll:Hide()

do
    local scrollBar = _G[nativeDungeonFilterScroll:GetName() .. "ScrollBar"]
    if scrollBar then
        local upBtn = _G[scrollBar:GetName() .. "ScrollUpButton"]
        local downBtn = _G[scrollBar:GetName() .. "ScrollDownButton"]
        if upBtn then upBtn:Hide(); upBtn:SetSize(0.1, 0.1) end
        if downBtn then downBtn:Hide(); downBtn:SetSize(0.1, 0.1) end
        local topTex = _G[scrollBar:GetName() .. "Top"]
        local bottomTex = _G[scrollBar:GetName() .. "Bottom"]
        local midTex = _G[scrollBar:GetName() .. "Middle"]
        if topTex then topTex:Hide() end
        if bottomTex then bottomTex:Hide() end
        if midTex then midTex:Hide() end
        local thumb = scrollBar:GetThumbTexture()
        if thumb then
            thumb:SetTexture(FLAT_TEX)
            thumb:SetVertexColor(classColor.r, classColor.g, classColor.b, 1)
            thumb:SetSize(8, 40)
        end
        scrollBar:SetWidth(8)
    end
end

nativeDungeonFilterContent = CreateFrame("Frame", nil, nativeDungeonFilterScroll)
nativeDungeonFilterContent:SetSize(175, 1)
nativeDungeonFilterScroll:SetScrollChild(nativeDungeonFilterContent)

nativePGFWarningBox = CreateFrame("Frame", nil, nativeDungeonFilterContent, "BackdropTemplate")
nativePGFWarningBox:SetBackdrop({bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1})
nativePGFWarningBox:SetBackdropColor(0.24, 0.16, 0.04, 0.92)
nativePGFWarningBox:SetBackdropBorderColor(classColor.r * 0.8, classColor.g * 0.8, classColor.b * 0.8, 1)
nativePGFWarningBox:SetHeight(38)
nativePGFWarningBox:Hide()

nativePGFWarningText = nativePGFWarningBox:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
nativePGFWarningText:SetPoint("TOPLEFT", nativePGFWarningBox, "TOPLEFT", 6, -5)
nativePGFWarningText:SetPoint("TOPRIGHT", nativePGFWarningBox, "TOPRIGHT", -6, -5)
nativePGFWarningText:SetJustifyH("LEFT")
nativePGFWarningText:SetJustifyV("TOP")
nativePGFWarningText:SetTextColor(1, 0.9, 0.45)
nativePGFWarningText:SetText("PGF detected. Blizzard dungeon filters are shared, so PGF and Oak may overwrite each other's selections.")

nativeNeedsTankBox = CreateStandaloneToggleBox(nativeDungeonFilterContent, "Need Tank")
nativeNeedsHealBox = CreateStandaloneToggleBox(nativeDungeonFilterContent, "Need Healer")
nativeNeedsDpsBox = CreateStandaloneToggleBox(nativeDungeonFilterContent, "Need Damage")
nativeNeedsMyClassBox = CreateStandaloneToggleBox(nativeDungeonFilterContent, "")
nativeNeedsMyClassBox.labelText:SetFontObject("OakLFG_FontSmall")
nativeHasTankBox = CreateStandaloneToggleBox(nativeDungeonFilterContent, "Has Tank")
nativeHasHealBox = CreateStandaloneToggleBox(nativeDungeonFilterContent, "Has Healer")
nativePartyBox = CreateStandaloneToggleBox(nativeDungeonFilterContent, "Party Fit")
nativeLustBox = CreateStandaloneToggleBox(nativeDungeonFilterContent, "Need Lust")
nativeBrezBox = CreateStandaloneToggleBox(nativeDungeonFilterContent, "Need BRez")

nativeMinimumRatingLabel = nativeDungeonFilterContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
nativeMinimumRatingLabel:SetText("Min Rating")
nativeMinimumRatingLabel:SetTextColor(classColor.r, classColor.g, classColor.b)

nativeMinimumRatingBox = CreateStandaloneNumberBox(nativeDungeonFilterContent, 56)

nativeActivityLabel = nativeDungeonFilterContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
nativeActivityLabel:SetText("Dungeons")
nativeActivityLabel:SetTextColor(classColor.r, classColor.g, classColor.b)
nativeActivityLabel:SetFontObject("OakLFG_FontSmall")

nativeNeedsTankBox:SetScript("OnClick", function()
    local adv = GetAdvancedSearchFilter()
    local nextState = not (adv.needsTank == true)
    nativeNeedsTankBox:SetState(nextState)
    SaveAdvancedSearchFilter(function(state)
        state.needsTank = nextState and true or nil
    end)
end)
nativeNeedsHealBox:SetScript("OnClick", function()
    local adv = GetAdvancedSearchFilter()
    local nextState = not (adv.needsHealer == true)
    nativeNeedsHealBox:SetState(nextState)
    SaveAdvancedSearchFilter(function(state)
        state.needsHealer = nextState and true or nil
    end)
end)
nativeNeedsDpsBox:SetScript("OnClick", function()
    local adv = GetAdvancedSearchFilter()
    local nextState = not (adv.needsDamage == true)
    nativeNeedsDpsBox:SetState(nextState)
    SaveAdvancedSearchFilter(function(state)
        state.needsDamage = nextState and true or nil
    end)
end)
nativeNeedsMyClassBox:SetScript("OnClick", function()
    local adv = GetAdvancedSearchFilter()
    local nextState = not (adv.needsMyClass == true)
    nativeNeedsMyClassBox:SetState(nextState)
    SaveAdvancedSearchFilter(function(state)
        state.needsMyClass = nextState and true or nil
    end)
end)
nativeHasTankBox:SetScript("OnClick", function()
    local adv = GetAdvancedSearchFilter()
    local nextState = not (adv.hasTank == true)
    nativeHasTankBox:SetState(nextState)
    SaveAdvancedSearchFilter(function(state)
        state.hasTank = nextState and true or nil
    end)
end)
nativeHasHealBox:SetScript("OnClick", function()
    local adv = GetAdvancedSearchFilter()
    local nextState = not (adv.hasHealer == true)
    nativeHasHealBox:SetState(nextState)
    SaveAdvancedSearchFilter(function(state)
        state.hasHealer = nextState and true or nil
    end)
end)
nativePartyBox:SetScript("OnClick", function(self)
    OAK_F.PartyFit = not OAK_F.PartyFit
    self:SetState(OAK_F.PartyFit)
    OAK_SEARCH:UpdateDisplay()
end)
nativeLustBox:SetScript("OnClick", function(self)
    OAK_F.NeedLust = not OAK_F.NeedLust
    self:SetState(OAK_F.NeedLust)
    OAK_SEARCH:UpdateDisplay()
end)
nativeBrezBox:SetScript("OnClick", function(self)
    OAK_F.NeedBrez = not OAK_F.NeedBrez
    self:SetState(OAK_F.NeedBrez)
    OAK_SEARCH:UpdateDisplay()
end)

nativeMinimumRatingBox:SetScript("OnEnterPressed", function(self)
    local value = tonumber(self:GetText())
    SaveAdvancedSearchFilter(function(state)
        state.minimumRating = value and math.max(0, math.floor(value)) or nil
    end)
    self:ClearFocus()
end)
nativeMinimumRatingBox:SetScript("OnEditFocusLost", function(self)
    local value = tonumber(self:GetText())
    SaveAdvancedSearchFilter(function(state)
        state.minimumRating = value and math.max(0, math.floor(value)) or nil
    end)
end)

-- ==========================================
-- 4. Scroll Frame Setup
-- ==========================================
local scrollFrame = CreateFrame("ScrollFrame", "OakLFGSearchScrollFrame", OAK_SEARCH, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", 10, -70)
scrollFrame:SetPoint("BOTTOMRIGHT", OAK_SEARCH, "BOTTOMRIGHT", -25, 26) 

local scrollBar = _G[scrollFrame:GetName() .. "ScrollBar"]
if scrollBar then
    local upBtn, downBtn = _G[scrollBar:GetName() .. "ScrollUpButton"], _G[scrollBar:GetName() .. "ScrollDownButton"]
    if upBtn then upBtn:Hide(); upBtn:SetSize(0.1, 0.1) end
    if downBtn then downBtn:Hide(); downBtn:SetSize(0.1, 0.1) end
    local topTex, bottomTex, midTex = _G[scrollBar:GetName() .. "Top"], _G[scrollBar:GetName() .. "Bottom"], _G[scrollBar:GetName() .. "Middle"]
    if topTex then topTex:Hide() end; if bottomTex then bottomTex:Hide() end; if midTex then midTex:Hide() end
    
    local thumb = scrollBar:GetThumbTexture()
    if thumb then thumb:SetTexture(FLAT_TEX); thumb:SetVertexColor(classColor.r, classColor.g, classColor.b, 1); thumb:SetSize(8, 60) end
    scrollBar:SetWidth(8)
end

local scrollChild = CreateFrame("Frame")
scrollChild:SetSize(scrollFrame:GetWidth(), 1)
scrollFrame:SetScrollChild(scrollChild)

OAK_SEARCH:SetScript("OnSizeChanged", function(self, width, height)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    if nativeDungeonFilterContent and nativeDungeonFilterScroll then
        nativeDungeonFilterContent:SetWidth(math.max(1, nativeDungeonFilterScroll:GetWidth()))
    end
end)

-- ==========================================
-- 5. Sorting & Headers (Pinned Applications)
-- ==========================================
local searchResults = {}
local currentSortBy = "rating"
local currentIsAscending = false
local SEARCH_FULL_WIDTH = 660
local SEARCH_COLLAPSED_WIDTH = 540
local SEARCH_NOTE_FULL_WIDTH = 155
local SEARCH_NOTE_COLLAPSED_WIDTH = 42
local SEARCH_ROW_X_OFFSET = 10
local SEARCH_ROLE_SQUARE_SIZE = 15
local SEARCH_ROLE_SQUARE_SPACING = 1
local SEARCH_NOTES_RIGHT_MARGIN = 41

local SEARCH_LAYOUT_EXPANDED = {
    dungeonX = 15, dungeonWidth = 145,
    setupX = 165, setupWidth = 98,
    titleX = 267, titleWidth = 98,
    ratingX = 370, ratingWidth = 65,
    ageX = 440, ageWidth = 35,
    notesX = 480, notesWidth = SEARCH_NOTE_FULL_WIDTH,
    roleStartX = 177,
    roleSummaryX = {175, 205, 235},
}

local SEARCH_LAYOUT_COLLAPSED = {
    dungeonX = 15, dungeonWidth = 145,
    setupX = 165, setupWidth = 98,
    titleX = 267, titleWidth = 98,
    ratingX = 370, ratingWidth = 65,
    ageX = 440, ageWidth = 35,
    notesX = 482, notesWidth = SEARCH_NOTE_COLLAPSED_WIDTH,
    roleStartX = 177,
    roleSummaryX = {175, 205, 235},
}

local function GetSearchRoleStartX(layout)
    return layout.setupX + 6
end

local function GetSearchRoleSummaryX(layout)
    local startX = layout.setupX + 4
    return startX, startX + 30, startX + 60
end

local function GetSearchActionRightInset()
    if OakLFGSorterDB and OakLFGSorterDB.searchHideNotes then
        return -10
    end
    return -15
end

ShouldHostNativeSearchBox = function()
    return SearchModeUsesHostedSearch(currentSearchMode)
end

local function GetCollapsedSearchActionCenterX(layout)
    return layout.notesX + math.floor(layout.notesWidth / 2) - SEARCH_ROW_X_OFFSET
end

local function GetSearchLayout()
    if OakLFGSorterDB and OakLFGSorterDB.searchHideNotes then
        return SEARCH_LAYOUT_COLLAPSED
    end
    return SEARCH_LAYOUT_EXPANDED
end

local function GetPinnedRowPriority(group)
    local priority = 0
    if group.isApplied then
        priority = priority + 100
    end
    if group.isFriend then
        priority = priority + 50
    end
    return priority
end

local function SortGroups(grpA, grpB, sortBy, isAscending)
    local priorityA = GetPinnedRowPriority(grpA)
    local priorityB = GetPinnedRowPriority(grpB)
    if priorityA ~= priorityB then
        return priorityA > priorityB
    end

    local valA, valB
    if sortBy == "dungeon" then valA, valB = grpA.dungeon, grpB.dungeon
    elseif sortBy == "title" then valA, valB = grpA.titleStr or "", grpB.titleStr or ""
    elseif sortBy == "rating" then valA, valB = grpA.rating, grpB.rating
    elseif sortBy == "age" then valA, valB = grpA.age, grpB.age
    else valA, valB = grpA.id, grpB.id end 
    
    if valA ~= valB then
        if isAscending then return valA < valB else return valA > valB end
    end
    return grpA.id < grpB.id 
end

local headers = {}
local dungeonHeader
local setupHeader
local titleHeader
local ratingHeader
local ageHeader

function OAK_SEARCH.UpdateHeaderVisuals()
    if dungeonHeader then
        if currentSearchMode == "raid" or currentSearchMode == "legacy_raid" then
            dungeonHeader.baseText = "Raid"
        elseif currentSearchMode == "rated_pvp" or currentSearchMode == "pvp" or currentSearchMode == "open_world" then
            dungeonHeader.baseText = "Activity"
        else
            dungeonHeader.baseText = "Dungeon"
        end
    end

    if ratingHeader then
        if currentSearchMode == "rated_pvp" or currentSearchMode == "pvp" then
            ratingHeader.baseText = "PVP Rating"
        elseif currentSearchMode == "raid" or currentSearchMode == "legacy_raid" then
            ratingHeader.baseText = "Progress"
        else
            ratingHeader.baseText = "Rating"
        end
    end

    for _, header in ipairs(headers) do
        local arrowStr = ""
        if currentSortBy == header.sortKey then
            arrowStr = currentIsAscending and " |TInterface\\BUTTONS\\Arrow-Up-Up:10|t" or " |TInterface\\BUTTONS\\Arrow-Down-Up:10|t"
        end
        header.text:SetText(header.baseText .. arrowStr)
    end
end

local function CreateHeader(label, sortKey, width, xOffset)
    local btn = CreateFrame("Button", nil, OAK_SEARCH, "BackdropTemplate")
    btn:SetSize(width, 22)
    btn:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", xOffset, -43)
    btn:SetBackdrop({bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1})
    btn:SetBackdropColor(unpack(OAK_COLOR_PANE))
    btn:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))
    btn.baseText = label; btn.sortKey = sortKey
    btn.text = btn:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    btn.text:SetPoint("CENTER"); btn.text:SetText(label)
    
    if sortKey ~= "none" then
        btn:SetScript("OnClick", function()
            if currentSortBy == sortKey then currentIsAscending = not currentIsAscending
            else currentSortBy = sortKey; currentIsAscending = false end
            OAK_SEARCH.UpdateHeaderVisuals(); OAK_SEARCH:UpdateDisplay()
        end)
    end
    table.insert(headers, btn)
    return btn
end

dungeonHeader = CreateHeader("Dungeon", "dungeon", SEARCH_LAYOUT_EXPANDED.dungeonWidth, SEARCH_LAYOUT_EXPANDED.dungeonX)
setupHeader = CreateHeader("Comp", "members", SEARCH_LAYOUT_EXPANDED.setupWidth, SEARCH_LAYOUT_EXPANDED.setupX)
titleHeader = CreateHeader("Title", "title", SEARCH_LAYOUT_EXPANDED.titleWidth, SEARCH_LAYOUT_EXPANDED.titleX)
ratingHeader = CreateHeader("Rating", "rating", SEARCH_LAYOUT_EXPANDED.ratingWidth, SEARCH_LAYOUT_EXPANDED.ratingX)
ageHeader = CreateHeader("Age", "age", SEARCH_LAYOUT_EXPANDED.ageWidth, SEARCH_LAYOUT_EXPANDED.ageX)

local notesToggleBtn = CreateFlatButton(OAK_SEARCH, "Notes", SEARCH_NOTE_FULL_WIDTH)
notesToggleBtn:SetHeight(22)
notesToggleBtn:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", SEARCH_LAYOUT_EXPANDED.notesX, -43)
notesToggleBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if OakLFGSorterDB.searchHideNotes then
        GameTooltip:SetText("Show Notes", 1, 1, 1)
        GameTooltip:AddLine("Expand the Notes column and restore the full search window width.", 1, 1, 1, true)
    else
        GameTooltip:SetText("Hide Notes", 1, 1, 1)
        GameTooltip:AddLine("Collapse the Notes column to make the search window more compact.", 1, 1, 1, true)
    end
    GameTooltip:Show()
end)
notesToggleBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)

local function UpdateSearchHeaderVisuals()
    local layout = GetSearchLayout()
    OAK_SEARCH.UpdateHeaderVisuals()
    dungeonHeader:SetWidth(layout.dungeonWidth)
    dungeonHeader:ClearAllPoints()
    dungeonHeader:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", layout.dungeonX, -43)

    setupHeader:SetWidth(layout.setupWidth)
    setupHeader:ClearAllPoints()
    setupHeader:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", layout.setupX, -43)

    titleHeader:SetWidth(layout.titleWidth)
    titleHeader:ClearAllPoints()
    titleHeader:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", layout.titleX, -43)

    ratingHeader:SetWidth(layout.ratingWidth)
    ratingHeader:ClearAllPoints()
    ratingHeader:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", layout.ratingX, -43)

    ageHeader:SetWidth(layout.ageWidth)
    ageHeader:ClearAllPoints()
    ageHeader:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", layout.ageX, -43)

    notesToggleBtn:SetWidth(layout.notesWidth)
    notesToggleBtn.text:SetText((OakLFGSorterDB and OakLFGSorterDB.searchHideNotes) and "Notes" or "Hide Notes")
    notesToggleBtn:ClearAllPoints()
    notesToggleBtn:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", layout.notesX, -43)
end

-- ==========================================
-- 6. Logic Helpers
-- ==========================================
local function GetMyPartyRoles()
    local t, h, d = 0, 0, 0
    local num = GetNumGroupMembers()
    if num == 0 then
        local role = UnitGroupRolesAssigned("player")
        if role == "TANK" then t = 1 elseif role == "HEALER" then h = 1 else d = 1 end
    else
        for i=1, num do
            local unit = IsInRaid() and "raid"..i or "party"..i
            if i == num and not IsInRaid() then unit = "player" end
            local role = UnitGroupRolesAssigned(unit)
            if role == "TANK" then t = t + 1 elseif role == "HEALER" then h = h + 1 else d = d + 1 end
        end
    end
    return t, h, d
end

local function GetRoleTexCoords(role)
    if role == "TANK" then return 0, 19/64, 22/64, 41/64 end
    if role == "HEALER" then return 20/64, 39/64, 1/64, 20/64 end
    if role == "DAMAGER" then return 20/64, 39/64, 22/64, 41/64 end
    return 0, 0, 0, 0 
end

local function CreateRoleSquare(parent, size)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(size, size)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(); frame.bg:SetColorTexture(0.2, 0.2, 0.2, 0.5) 
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(size - 2, size - 2); frame.icon:SetPoint("CENTER")
    frame.icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
    return frame
end

local function CreateRoleSummary(parent, role, xOffset)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(28, 16)
    frame:SetPoint("LEFT", parent, "LEFT", xOffset, 0)

    frame.icon = frame:CreateTexture(nil, "OVERLAY")
    frame.icon:SetSize(14, 14)
    frame.icon:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
    local l, r, t, b = GetRoleTexCoords(role)
    frame.icon:SetTexCoord(l, r, t, b)

    frame.count = frame:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
    frame.count:SetPoint("LEFT", frame.icon, "RIGHT", 2, 0)
    frame.count:SetJustifyH("LEFT")
    frame.count:SetText("0")

    return frame
end

local function GetSetupLayoutMode(group)
    local maxPlayers = tonumber(group.maxPlayers) or 0
    local activityText = strlower(tostring(group.activityName or ""))

    if maxPlayers > 5 or activityText:find("raid", 1, true) or activityText:find("world", 1, true) or activityText:find("outdoor", 1, true) then
        return "summary"
    end

    if activityText:find("arena", 1, true) or activityText:find("2v2", 1, true) or activityText:find("3v3", 1, true) or activityText:find("shuffle", 1, true) then
        return "pvp_small"
    end

    return "party"
end

local function BuildSetupSlots(group)
    local layoutMode = GetSetupLayoutMode(group)
    local sortedMembers = {}
    local roleOrder = { TANK = 1, HEALER = 2, DAMAGER = 3 }

    for _, member in ipairs(group.memberDetails or {}) do
        table.insert(sortedMembers, member)
    end

    table.sort(sortedMembers, function(a, b)
        return (roleOrder[a.role] or 99) < (roleOrder[b.role] or 99)
    end)

    if layoutMode == "summary" then
        return nil, layoutMode
    end

    local targetSlots
    if layoutMode == "pvp_small" then
        targetSlots = math.max(2, math.min(tonumber(group.maxPlayers) or #sortedMembers or 3, 5))
    else
        targetSlots = 5
    end

    local slots = {}
    for index = 1, targetSlots do
        local member = sortedMembers[index]
        if member then
            slots[index] = { role = member.role, class = member.class, filled = true }
        else
            slots[index] = { role = "DAMAGER", class = nil, filled = false }
        end
    end

    return slots, layoutMode
end

-- ==========================================
-- 7. Row Generation & Deep Tooltips
-- ==========================================
local rows = {}
local function FormatTime(seconds)
    if seconds < 60 then return seconds .. "s" end
    return math.floor(seconds / 60) .. "m"
end

local function GetPreferredScoreColor(score, defaultR, defaultG, defaultB)
    if RaiderIO and RaiderIO.GetScoreColor then
        local r, g, b = RaiderIO.GetScoreColor(score)
        if r and g and b then
            return r, g, b
        end
    end
    return defaultR, defaultG, defaultB
end

local function GetSearchListingMode(activityInfo)
    if not activityInfo then
        return "generic"
    end

    local activityText = strlower((activityInfo.fullName or "") .. " " .. (activityInfo.shortName or ""))
    local cleanFullName = strlower(tostring(activityInfo.fullName or ""):gsub("%s*%(.+%)", ""))
    local cleanShortName = strlower(tostring(activityInfo.shortName or ""):gsub("%s*%(.+%)", ""))
    local maxPlayers = tonumber(activityInfo.maxNumPlayers or activityInfo.maxPlayers) or 0

    if activityInfo.isMythicPlusActivity then
        return "mythic_plus"
    elseif activityText:find("mythic keystone", 1, true) or activityText:find("keystone", 1, true) then
        return "mythic_plus"
    elseif activityInfo.isRatedPvpActivity then
        return "rated_pvp"
    elseif activityInfo.isPvpActivity then
        return "pvp"
    elseif activityInfo.isCurrentRaidActivity then
        return "raid"
    elseif activityText:find("legacy", 1, true) and activityText:find("raid", 1, true) then
        return "legacy_raid"
    elseif activityText:find("world", 1, true) or activityText:find("outdoor", 1, true) then
        return "open_world"
    elseif activityText:find("delve", 1, true) or SEARCH_DELVE_LABEL_LOOKUP[cleanFullName] or SEARCH_DELVE_LABEL_LOOKUP[cleanShortName] then
        return "delve"
    elseif maxPlayers > 0 and maxPlayers <= 5 then
        if activityText:find("mythic", 1, true) or activityText:find("heroic", 1, true) or activityText:find("normal", 1, true) then
            return "dungeon"
        end
    end

    return "generic"
end

local function GetSearchDifficultyToken(activityInfo)
    if not activityInfo then
        return "ANY"
    end

    local source = strlower(table.concat({
        tostring(activityInfo.fullName or ""),
        tostring(activityInfo.shortName or ""),
    }, " "))

    if activityInfo.isMythicPlusActivity or source:find("mythic keystone", 1, true) or source:find("mythic%+") then
        return "MYTHIC_PLUS"
    elseif source:find("mythic", 1, true) then
        return "MYTHIC"
    elseif source:find("heroic", 1, true) then
        return "HEROIC"
    elseif source:find("normal", 1, true) then
        return "NORMAL"
    end

    return "ANY"
end

local function ParsePlaystyleText(resultInfo)
    local haystack = strlower((resultInfo and resultInfo.name or "") .. " " .. (resultInfo and resultInfo.comment or ""))
    if haystack:find("carry", 1, true) or haystack:find("boost", 1, true) then
        return "Carry Offered"
    elseif haystack:find("learn", 1, true) then
        return "Learning"
    elseif haystack:find("relax", 1, true) or haystack:find("chill", 1, true) then
        return "Relaxed"
    elseif haystack:find("comp", 1, true) or haystack:find("push", 1, true) then
        return "Competitive"
    end

    return nil
end

local function GetSearchPlaystyle(resultInfo, activityInfo)
    local playstyleValue = tonumber(resultInfo and resultInfo.generalPlaystyle) or 0
    local label = "Any"

    if playstyleValue > 0 and C_LFGList and C_LFGList.GetPlaystyleString then
        local success, playstyleString = pcall(C_LFGList.GetPlaystyleString, nil, playstyleValue, activityInfo)
        if success and type(playstyleString) == "string" and playstyleString ~= "" then
            label = playstyleString
        end
    end

    label = ParsePlaystyleText(resultInfo) or label
    return playstyleValue, label
end

local function GetSearchPvpBracketLabel(pvpRatingInfo, activityInfo, numMembers)
    if type(GetPvpBracketLabel) == "function" then
        local label = GetPvpBracketLabel(pvpRatingInfo)
        if label and label ~= "" then
            return label
        end
    end

    local activityText = strlower(table.concat({
        tostring(activityInfo and activityInfo.fullName or ""),
        tostring(activityInfo and activityInfo.shortName or ""),
    }, " "))
    local maxPlayers = tonumber(activityInfo and activityInfo.maxPlayers) or tonumber(numMembers) or 0
    if activityText:find("2v2", 1, true) or activityText:find("2 v 2", 1, true) then
        return "2v2"
    elseif activityText:find("3v3", 1, true) or activityText:find("3 v 3", 1, true) then
        return "3v3"
    elseif activityText:find("solo", 1, true) or activityText:find("shuffle", 1, true) then
        return "Solo"
    elseif activityText:find("blitz", 1, true) then
        return "Blitz"
    elseif activityText:find("battleground", 1, true) or activityText:find("rbg", 1, true) then
        return "RBG"
    elseif maxPlayers == 2 then
        return "2v2"
    elseif maxPlayers == 3 then
        return "3v3"
    end

    return nil
end

local function GetRaidFilterLabel(activityInfo)
    local label = tostring(activityInfo and (activityInfo.fullName or activityInfo.shortName) or "")
    label = label:gsub("%s*%(.+%)", "")
    return label
end

local function GetSearchFilterLabel(mode, activityInfo, pvpBracket)
    if mode == "rated_pvp" or mode == "pvp" then
        return pvpBracket or GetRaidFilterLabel(activityInfo)
    end
    return GetRaidFilterLabel(activityInfo)
end

local function GetNeedsMyClassLabel()
    local localizedClassName = select(1, UnitClass("player"))
    if localizedClassName and localizedClassName ~= "" then
        return string.format("No %s in group", localizedClassName)
    end

    return "No duplicate class"
end

local function GetNativeDungeonActivityEntries()
    local entries = {}
    local seen = {}
    local defaultOrder = {}

    if currentSearchMode == "mythic_plus" then
        for index, label in ipairs(DEFAULT_SEASON_DUNGEONS) do
            defaultOrder[strlower(label)] = index
            seen[strlower(label)] = { label = label, groupID = nil }
            table.insert(entries, seen[strlower(label)])
        end
    end

    for _, group in ipairs(searchResults) do
        if group.mode == "mythic_plus" or group.mode == "dungeon" then
            local label = GetRaidFilterLabel({ fullName = group.filterLabel })
            local key = strlower(label or "")
            if key ~= "" then
                local existing = seen[key]
                if existing then
                    if not existing.groupID and group.activityGroupID and group.activityGroupID > 0 then
                        existing.groupID = group.activityGroupID
                    end
                else
                    local entry = {
                        label = label,
                        groupID = group.activityGroupID,
                    }
                    seen[key] = entry
                    table.insert(entries, entry)
                end
            end
        end
    end

    table.sort(entries, function(a, b)
        local aKey = strlower(a.label or "")
        local bKey = strlower(b.label or "")
        local aOrder = defaultOrder[aKey]
        local bOrder = defaultOrder[bKey]
        if aOrder and bOrder then
            return aOrder < bOrder
        elseif aOrder then
            return true
        elseif bOrder then
            return false
        end
        return (a.label or "") < (b.label or "")
    end)

    return entries
end

ResetSearchFilters = function()
    OAK_F.Difficulty = "ANY"
    OAK_F.HasTank = false
    OAK_F.NeedTank = false
    OAK_F.HasHeal = false
    OAK_F.NeedHeal = false
    OAK_F.NeedDPS = false
    OAK_F.NeedLust = false
    OAK_F.NeedBrez = false
    OAK_F.PartyFit = false

    for activityName in pairs(OAK_F.Activities) do
        OAK_F.Activities[activityName] = false
    end

    if C_LFGList and C_LFGList.SaveAdvancedFilter then
        local adv = GetAdvancedSearchFilter()
        adv.needsTank = nil
        adv.needsHealer = nil
        adv.needsDamage = nil
        adv.needsMyClass = nil
        adv.hasTank = nil
        adv.hasHealer = nil
        adv.minimumRating = nil
        adv.activities = {}
        C_LFGList.SaveAdvancedFilter(adv)
    end

    if UpdateSearchFilterPane then
        UpdateSearchFilterPane()
    end
    if OAK_SEARCH and OAK_SEARCH.UpdateDisplay then
        OAK_SEARCH:UpdateDisplay()
    end
end

local function UpdateNativeDungeonFilterPane(topOffset)
    local adv = GetAdvancedSearchFilter()
    local selectedActivities = {}
    local y = -4
    local showPGFWarning = IsPGFDetected()

    nativeDungeonFilterScroll:ClearAllPoints()
    nativeDungeonFilterScroll:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 10, topOffset)
    nativeDungeonFilterScroll:SetPoint("BOTTOMRIGHT", filterPanel, "BOTTOMRIGHT", -12, 10)

    if type(adv.activities) == "table" then
        for _, groupID in ipairs(adv.activities) do
            selectedActivities[tonumber(groupID) or 0] = true
        end
    end

    nativeNeedsMyClassBox:SetLabel(GetNeedsMyClassLabel())

    if showPGFWarning then
        nativePGFWarningBox:ClearAllPoints()
        nativePGFWarningBox:SetPoint("TOPLEFT", nativeDungeonFilterContent, "TOPLEFT", 5, y)
        nativePGFWarningBox:SetPoint("TOPRIGHT", nativeDungeonFilterContent, "TOPRIGHT", -8, y)
        nativePGFWarningBox:Show()
        nativePGFWarningText:Show()
        y = y - 46
    else
        nativePGFWarningBox:Hide()
        nativePGFWarningText:Hide()
    end

    local topGrid = {
        { box = nativeNeedsTankBox, active = adv.needsTank == true, x = 5, row = 0 },
        { box = nativeHasTankBox, active = adv.hasTank == true, x = 95, row = 0 },
        { box = nativeNeedsHealBox, active = adv.needsHealer == true, x = 5, row = 1 },
        { box = nativeHasHealBox, active = adv.hasHealer == true, x = 95, row = 1 },
        { box = nativeNeedsDpsBox, active = adv.needsDamage == true, x = 5, row = 2 },
        { box = nativeNeedsMyClassBox, active = adv.needsMyClass == true, x = 95, row = 2 },
    }

    for _, entry in ipairs(topGrid) do
        entry.box:ClearAllPoints()
        entry.box:SetPoint("TOPLEFT", nativeDungeonFilterContent, "TOPLEFT", entry.x, y - (entry.row * 22))
        entry.box:SetState(entry.active)
        entry.box:Show()
        if entry.box.labelText then
            entry.box.labelText:Show()
        end
    end
    y = y - 70

    nativeMinimumRatingLabel:ClearAllPoints()
    nativeMinimumRatingLabel:SetPoint("TOPLEFT", nativeDungeonFilterContent, "TOPLEFT", 5, y - 2)
    nativeMinimumRatingLabel:Show()
    nativeMinimumRatingBox:ClearAllPoints()
    nativeMinimumRatingBox:SetPoint("TOPRIGHT", nativeDungeonFilterContent, "TOPRIGHT", -8, y + 2)
    nativeMinimumRatingBox:SetText((tonumber(adv.minimumRating) or 0) > 0 and tostring(math.floor(adv.minimumRating)) or "")
    nativeMinimumRatingBox:Show()
    y = y - 28

    local localUtilityControls = {
        { box = nativePartyBox, active = OAK_F.PartyFit, x = 5, row = 0 },
        { box = nativeLustBox, active = OAK_F.NeedLust, x = 95, row = 0 },
        { box = nativeBrezBox, active = OAK_F.NeedBrez, x = 5, row = 1 },
    }

    for _, entry in ipairs(localUtilityControls) do
        entry.box:ClearAllPoints()
        entry.box:SetPoint("TOPLEFT", nativeDungeonFilterContent, "TOPLEFT", entry.x, y - (entry.row * 22))
        entry.box:SetState(entry.active)
        entry.box:Show()
        if entry.box.labelText then
            entry.box.labelText:Show()
        end
    end
    y = y - 46

    nativeActivityLabel:ClearAllPoints()
    nativeActivityLabel:SetPoint("TOPLEFT", nativeDungeonFilterContent, "TOPLEFT", 5, y)
    nativeActivityLabel:Show()
    y = y - 16

    local activityEntries = GetNativeDungeonActivityEntries()
    for index, entry in ipairs(activityEntries) do
        local button = nativeDungeonActivityButtons[index]
        if not button then
            button = CreateStandaloneToggleBox(nativeDungeonFilterContent, "")
            button.labelText:SetFontObject("OakLFG_FontSmall")
            button:SetScript("OnClick", function(self)
                if not self.activityGroupID or self.activityGroupID <= 0 then
                    return
                end

                local isSelected = false
                local current = GetAdvancedSearchFilter()
                local groups = {}
                if type(current.activities) == "table" then
                    for _, groupID in ipairs(current.activities) do
                        local numericID = tonumber(groupID)
                        if numericID and numericID > 0 then
                            groups[numericID] = true
                        end
                    end
                end
                isSelected = groups[self.activityGroupID] == true

                SaveAdvancedSearchFilter(function(state)
                    local nextGroups = {}
                    if type(state.activities) == "table" then
                        for _, groupID in ipairs(state.activities) do
                            local numericID = tonumber(groupID)
                            if numericID and numericID > 0 then
                                nextGroups[numericID] = true
                            end
                        end
                    end

                    if isSelected then
                        nextGroups[self.activityGroupID] = nil
                    else
                        nextGroups[self.activityGroupID] = true
                    end

                    state.activities = {}
                    for groupID in pairs(nextGroups) do
                        table.insert(state.activities, groupID)
                    end
                    table.sort(state.activities)
                end)
                self:SetState(not isSelected)
            end)
            nativeDungeonActivityButtons[index] = button
        end

        button.activityGroupID = tonumber(entry.groupID) or 0
        button:SetLabel(entry.label)
        button:SetState(button.activityGroupID > 0 and selectedActivities[button.activityGroupID] == true)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", nativeDungeonFilterContent, "TOPLEFT", 5, y)
        if button.activityGroupID > 0 then
            button:Enable()
            button.labelText:SetTextColor(1, 1, 1)
        else
            button:Disable()
            button:SetState(false)
            button.labelText:SetTextColor(0.55, 0.55, 0.55)
        end
        button:Show()
        if button.labelText then
            button.labelText:Show()
        end
        y = y - 18
    end

    for index = #activityEntries + 1, #nativeDungeonActivityButtons do
        local button = nativeDungeonActivityButtons[index]
        if button then
            button:Hide()
            if button.labelText then
                button.labelText:Hide()
            end
        end
    end

    nativeDungeonFilterContent:SetHeight(math.max(1, -y + 8))
end

local function GetResultRatingData(searchResultInfo, activityInfo)
    local mode = GetSearchListingMode(activityInfo)
    local rating = tonumber(searchResultInfo and searchResultInfo.leaderOverallDungeonScore) or 0
    local ratingLabel = "M+ Rating"
    local pvpRating = 0
    local pvpBracket = nil

    if (mode == "rated_pvp" or mode == "pvp") and type(searchResultInfo.leaderPvpRatingInfo) == "table" then
        local pvpInfo = searchResultInfo.leaderPvpRatingInfo
        local selectedInfo = nil
        if pvpInfo.rating then
            selectedInfo = pvpInfo
        else
            for _, info in ipairs(pvpInfo) do
                if type(info) == "table" and (not selectedInfo or (tonumber(info.rating) or 0) > (tonumber(selectedInfo.rating) or 0)) then
                    selectedInfo = info
                end
            end
        end

        if selectedInfo then
            pvpRating = tonumber(selectedInfo.rating) or 0
            pvpBracket = GetSearchPvpBracketLabel(selectedInfo, activityInfo, searchResultInfo and searchResultInfo.numMembers)
        end
        rating = pvpRating
        ratingLabel = "PVP Rating"
    elseif mode == "raid" or mode == "legacy_raid" then
        ratingLabel = "Progress"
    end

    return mode, rating, ratingLabel, pvpRating, pvpBracket
end

local function ParseListedKeyLevel(searchResultInfo, activityInfo)
    local title = tostring(searchResultInfo and searchResultInfo.name or "")
    local comment = tostring(searchResultInfo and searchResultInfo.comment or "")
    local activityText = strlower(table.concat({
        tostring(activityInfo and activityInfo.fullName or ""),
        tostring(activityInfo and activityInfo.shortName or ""),
    }, " "))

    local function NormalizeKey(raw)
        local value = tonumber(raw)
        if value and value >= 2 and value <= 30 then
            return value
        end
        return nil
    end

    local function FindKey(text)
        text = tostring(text or "")
        local key = NormalizeKey(
            text:match("^%s*%+?(%d%d?)%f[%A]")
            or text:match("^%s*%+?(%d%d?)%s*[%-%>]")
            or text:match("^%s*%+?(%d%d?)%s+[A-Za-z]")
        )
        if key then
            return key
        end

        key = NormalizeKey(text:match("%+(%d%d?)"))
        if key then
            return key
        end

        key = NormalizeKey(
            text:match("%f[%w](%d%d?)%s*[Cc][Oo][Mm][Pp]")
            or text:match("%f[%w](%d%d?)%s*[Rr][Ee][Ll][Aa][Xx]")
            or text:match("%f[%w](%d%d?)%s*[Ll][Ee][Aa][Rr][Nn]")
            or text:match("%f[%w](%d%d?)%s*[Pp][Uu][Ss][Hh]")
            or text:match("%f[%w](%d%d?)%s*[Ww][Ee][Ee][Kk]")
        )
        if key then
            return key
        end

        return nil
    end

    local key = FindKey(title)
    if key then
        return key
    end

    key = FindKey(comment)
    if key then
        return key
    end

    if activityInfo and (activityInfo.isMythicPlusActivity or activityText:find("mythic keystone", 1, true) or activityText:find("mythic+", 1, true)) then
        local firstNumber = NormalizeKey(title:match("(%d%d?)"))
        if firstNumber then
            return firstNumber
        end
    end

    return 0
end

local function GetCurrentSearchActivityLabels()
    local labels = {}
    local seen = {}

    if currentSearchMode == "mythic_plus" then
        for _, label in ipairs(DEFAULT_SEASON_DUNGEONS) do
            if not seen[label] then
                seen[label] = true
                table.insert(labels, label)
            end
        end
    elseif currentSearchMode == "delve" then
        for _, label in ipairs(DEFAULT_SEASON_DELVES) do
            if not seen[label] then
                seen[label] = true
                table.insert(labels, label)
            end
        end
    end

    for _, group in ipairs(searchResults) do
        local label = group.filterLabel
        if label and label ~= "" and not seen[label] then
            seen[label] = true
            table.insert(labels, label)
        end
    end

    table.sort(labels)
    return labels
end

local function GetSearchResultActivityID(searchResultInfo)
    if not searchResultInfo then
        return nil
    end

    local activityID = tonumber(searchResultInfo.activityID)
    if not activityID and securecallfunction then
        activityID = securecallfunction(function(info)
            local ids = info and info.activityIDs
            local firstID = type(ids) == "table" and ids[1] or nil
            return tonumber(firstID)
        end, searchResultInfo)
    end
    if activityID == 0 then
        activityID = nil
    end

    return activityID
end

local function SetControlVisible(control, visible)
    if not control then
        return
    end

    if visible then
        control:Show()
        if control.labelText then
            control.labelText:Show()
        end
    else
        control:Hide()
        if control.labelText then
            control.labelText:Hide()
        end
    end
end

UpdateSearchFilterPane = function()
    local showSearchQuery = SearchModeUsesHostedSearch(currentSearchMode)
    local showNativeDungeonFilters = SearchModeUsesNativeDungeonFilters(currentSearchMode)
    local showDifficulty = SearchModeUsesDifficulty(currentSearchMode)
    local showActivityFilters = SearchModeUsesActivityFilters(currentSearchMode)

    if not showSearchQuery then
        OAK_F.SearchQuery = ""
    end

    if not SearchDifficultyIsValidForMode(currentSearchMode, OAK_F.Difficulty) then
        OAK_F.Difficulty = "ANY"
    end
    diffDropdown:SetOptions(GetSearchDifficultyOptions(currentSearchMode))
    diffDropdown:SetValue(OAK_F.Difficulty)
    local queryLabel, queryHint = GetSearchQueryLabel(currentSearchMode)
    keyRangeLabel:SetText(queryLabel)
    keyRangeHint:SetText(queryHint)

    SetControlVisible(diffDropdown, showDifficulty)
    SetControlVisible(keyRangeLabel, showSearchQuery)
    SetControlVisible(keyRangeHint, showSearchQuery)
    SetControlVisible(keyQueryBox, showSearchQuery)
    SetControlVisible(searchQueryBtn, showSearchQuery)
    if showSearchQuery and filterPanel:IsShown() then
        if AttachNativeSearchBoxToOak then
            AttachNativeSearchBoxToOak()
        end
    else
        if RestoreNativeSearchBox then
            RestoreNativeSearchBox()
        end
    end

    local activitySectionTitle = GetSearchActivitySectionTitle(currentSearchMode)
    if activitySectionTitle then
        filterActivityTitle:SetText(activitySectionTitle)
    end

    local difficultyTopY = -35
    local queryLabelTopY = showDifficulty and -67 or -35
    local queryHintTopY = queryLabelTopY - 15
    local queryBoxTopY = queryHintTopY - 6
    local searchButtonTopY = queryBoxTopY - 28
    local baseY

    diffDropdown:ClearAllPoints()
    diffDropdown:SetPoint("TOP", filterPanel, "TOP", 0, difficultyTopY)

    keyRangeLabel:ClearAllPoints()
    keyRangeLabel:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, queryLabelTopY)
    keyRangeHint:ClearAllPoints()
    keyRangeHint:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, queryHintTopY)
    keyQueryBox:ClearAllPoints()
    keyQueryBox:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, queryBoxTopY)
    searchQueryBtn:ClearAllPoints()
    resetFiltersBtn:ClearAllPoints()

    if showNativeDungeonFilters then
        searchQueryBtn:SetWidth(84)
        searchQueryBtn.text:SetText("Refresh")
        searchQueryBtn:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, searchButtonTopY)
        resetFiltersBtn:SetPoint("TOPLEFT", searchQueryBtn, "TOPRIGHT", 7, 0)
        resetFiltersBtn:Show()
        SetControlVisible(boxNeedTank, false)
        SetControlVisible(boxNeedHeal, false)
        SetControlVisible(boxNeedDPS, false)
        SetControlVisible(boxHasTank, false)
        SetControlVisible(boxHasHeal, false)
        SetControlVisible(boxParty, false)
        SetControlVisible(boxLust, false)
        SetControlVisible(boxBrez, false)
        SetControlVisible(divTexture, false)
        SetControlVisible(filterActivityTitle, false)
        SetControlVisible(filterDungeonContainer, false)

        nativeDungeonFilterScroll:Show()
        UpdateNativeDungeonFilterPane(searchButtonTopY - 34)
        return
    else
        nativeDungeonFilterScroll:Hide()
        nativePGFWarningBox:Hide()
        nativePGFWarningText:Hide()
        nativeMinimumRatingLabel:Hide()
        nativeMinimumRatingBox:Hide()
        nativeActivityLabel:Hide()
        for _, box in ipairs(nativeDungeonActivityButtons) do
            box:Hide()
            if box.labelText then box.labelText:Hide() end
        end
        nativeNeedsTankBox:Hide(); if nativeNeedsTankBox.labelText then nativeNeedsTankBox.labelText:Hide() end
        nativeNeedsHealBox:Hide(); if nativeNeedsHealBox.labelText then nativeNeedsHealBox.labelText:Hide() end
        nativeNeedsDpsBox:Hide(); if nativeNeedsDpsBox.labelText then nativeNeedsDpsBox.labelText:Hide() end
        nativeNeedsMyClassBox:Hide(); if nativeNeedsMyClassBox.labelText then nativeNeedsMyClassBox.labelText:Hide() end
        nativeHasTankBox:Hide(); if nativeHasTankBox.labelText then nativeHasTankBox.labelText:Hide() end
        nativeHasHealBox:Hide(); if nativeHasHealBox.labelText then nativeHasHealBox.labelText:Hide() end
        nativePartyBox:Hide(); if nativePartyBox.labelText then nativePartyBox.labelText:Hide() end
        nativeLustBox:Hide(); if nativeLustBox.labelText then nativeLustBox.labelText:Hide() end
        nativeBrezBox:Hide(); if nativeBrezBox.labelText then nativeBrezBox.labelText:Hide() end
    end

    searchQueryBtn:SetWidth(175)
    searchQueryBtn.text:SetText("Search")
    searchQueryBtn:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, searchButtonTopY)
    resetFiltersBtn:Hide()

    SetControlVisible(boxNeedTank, true)
    SetControlVisible(boxNeedHeal, true)
    SetControlVisible(boxNeedDPS, true)
    SetControlVisible(boxHasTank, true)
    SetControlVisible(boxHasHeal, true)
    SetControlVisible(boxParty, true)
    SetControlVisible(boxLust, true)
    SetControlVisible(boxBrez, true)
    SetControlVisible(divTexture, showActivityFilters)
    SetControlVisible(filterActivityTitle, showActivityFilters)
    SetControlVisible(filterDungeonContainer, showActivityFilters)

    if showSearchQuery then
        baseY = showDifficulty and -148 or -116
    else
        baseY = showDifficulty and -78 or -46
    end

    boxNeedTank:ClearAllPoints()
    boxNeedTank:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 16, baseY)
    boxHasTank:ClearAllPoints()
    boxHasTank:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 116, baseY)
    boxNeedHeal:ClearAllPoints()
    boxNeedHeal:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 16, baseY - 22)
    boxHasHeal:ClearAllPoints()
    boxHasHeal:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 116, baseY - 22)
    boxNeedDPS:ClearAllPoints()
    boxNeedDPS:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 16, baseY - 44)
    boxParty:ClearAllPoints()
    boxParty:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 116, baseY - 44)
    boxLust:ClearAllPoints()
    boxLust:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 16, baseY - 66)
    boxBrez:ClearAllPoints()
    boxBrez:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 116, baseY - 66)
    divTexture:ClearAllPoints()
    divTexture:SetPoint("TOP", filterPanel, "TOP", 0, baseY - 84)
    filterActivityTitle:ClearAllPoints()
    filterActivityTitle:SetPoint("TOP", filterPanel, "TOPLEFT", 95, baseY - 94)
    filterDungeonContainer:ClearAllPoints()
    filterDungeonContainer:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 10, baseY - 106)
    filterDungeonContainer:SetPoint("BOTTOMRIGHT", filterPanel, "BOTTOMRIGHT", -10, 10)

    currentActivityFilters = showActivityFilters and GetCurrentSearchActivityLabels() or {}
    for index, box in ipairs(filterDungeonButtons) do
        local label = currentActivityFilters[index]
        if label and showActivityFilters then
            if OAK_F.Activities[label] == nil then
                OAK_F.Activities[label] = false
            end
            box.activityName = label
            box.text:SetText(label)
            if OAK_F.Activities[label] then
                box:SetBackdropColor(classColor.r, classColor.g, classColor.b, 1)
            else
                box:SetBackdropColor(0.106, 0.106, 0.129, 1)
            end
            box:Show()
        else
            box.activityName = nil
            box:Hide()
        end
    end
end

local function DetermineSearchMode()
    local modeCounts = {}
    local priority = {
        "raid",
        "legacy_raid",
        "rated_pvp",
        "pvp",
        "delve",
        "dungeon",
        "mythic_plus",
        "open_world",
        "generic",
    }

    for _, group in ipairs(searchResults) do
        local mode = group.mode or "generic"
        local filterLabel = strlower(tostring(group.filterLabel or ""))
        if mode == "generic" and SEARCH_DELVE_LABEL_LOOKUP[filterLabel] then
            mode = "delve"
        end
        modeCounts[mode] = (modeCounts[mode] or 0) + 1
    end

    for _, mode in ipairs(priority) do
        if (modeCounts[mode] or 0) > 0 then
            return mode
        end
    end

    if currentSearchMode and currentSearchMode ~= "generic" then
        return currentSearchMode
    end

    if addonTable and addonTable.CurrentSearchContext and addonTable.CurrentSearchContext.mode then
        return addonTable.CurrentSearchContext.mode
    end

    return "generic"
end

local function BuildRoleClassBreakdown(memberDetails)
    local buckets = {
        DAMAGER = {},
        TANK = {},
        HEALER = {},
    }

    for _, member in ipairs(memberDetails or {}) do
        local role = member.role or "DAMAGER"
        if role ~= "TANK" and role ~= "HEALER" then
            role = "DAMAGER"
        end
        local class = member.class or "UNKNOWN"
        buckets[role][class] = (buckets[role][class] or 0) + 1
    end

    return buckets
end

local function AddRoleClassLines(tooltip, roleLabel, roleKey, members)
    local classes = {}
    local total = 0
    for class, count in pairs(members[roleKey] or {}) do
        total = total + count
        table.insert(classes, class)
    end

    if total == 0 then
        return
    end

    table.sort(classes)
    tooltip:AddLine(roleLabel .. ":", 1, 0.82, 0)
    for _, class in ipairs(classes) do
        local localized = LOCALIZED_CLASS_NAMES_MALE[class] or LOCALIZED_CLASS_NAMES_FEMALE[class] or class
        local line = string.format("%d %s", members[roleKey][class], localized)
        local color = RAID_CLASS_COLORS[class]
        if color then
            tooltip:AddLine(line, color.r, color.g, color.b)
        else
            tooltip:AddLine(line, 1, 1, 1)
        end
    end
end

local function GetCondensedSearchTitle(title)
    local text = tostring(title or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
        return ""
    end

    local key = text:match("^%+(%d%d?)")
        or text:match("^(%d%d?)%s*$")
        or text:match("^(%d%d?)%s*[%-%>]")
        or text:match("^(%d%d?)%s+")
    if key then
        return "+" .. tostring(tonumber(key) or key)
    end

    return text
end

local function TrimString(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function EscapePattern(text)
    return (tostring(text or ""):gsub("([%%%^%$%(%)%%.%[%]%*%+%-%?])", "%%%1"))
end

local function IsSearchKeyMode()
    return currentSearchMode == "mythic_plus" or OAK_F.Difficulty == "MYTHIC_PLUS"
end

local function BuildNativeKeyQuery()
    if not IsSearchKeyMode() then
        return ""
    end

    return TrimString(OAK_F.SearchQuery)
end

ApplyOakSearchQuery = function(triggerSearch)
    local searchBox = GetNativeSearchBox()
    if not searchBox then
        return
    end

    OAK_F.SearchQuery = TrimString(searchBox:GetText())

    if triggerSearch then
        LFGListSearchPanel_DoSearch(LFGListFrame.SearchPanel)
        if RequestUpdate then
            C_Timer.After(0.15, function()
                RequestUpdate()
            end)
        end
    end
end

ApplySearchNotesLayout = function(preserveLeftEdge)
    local hideNotes = OakLFGSorterDB and OakLFGSorterDB.searchHideNotes
    local targetWidth = hideNotes and SEARCH_COLLAPSED_WIDTH or SEARCH_FULL_WIDTH

    OAK_SEARCH:SetResizeBounds(targetWidth, 444, targetWidth, 800)

    if preserveLeftEdge and HasSavedSearchFramePosition() then
        local left = OAK_SEARCH:GetLeft()
        local bottom = OAK_SEARCH:GetBottom()

        OAK_SEARCH:SetWidth(targetWidth)
        if left and bottom then
            OAK_SEARCH:ClearAllPoints()
            OAK_SEARCH:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
            OakLFGSorterDB.searchFramePos = { "BOTTOMLEFT", "BOTTOMLEFT", left, bottom }
            OakLFGSorterDB.searchFrameUserPlaced = true
        end
    else
        OAK_SEARCH:SetWidth(targetWidth)
        if HasSavedSearchFramePosition() then
            RestoreSearchFramePosition()
        else
            AutoPositionSearch()
        end
    end

    scrollChild:SetWidth(scrollFrame:GetWidth())

    UpdateSearchHeaderVisuals()

    local layout = GetSearchLayout()
    for _, row in ipairs(rows) do
        row.dungeonText:SetWidth(layout.dungeonWidth)
        row.playstyleText:SetWidth(layout.dungeonWidth)

        for index, square in ipairs(row.roleSquares) do
            square:ClearAllPoints()
            if index == 1 then
                square:SetPoint("LEFT", row, "LEFT", GetSearchRoleStartX(layout) - SEARCH_ROW_X_OFFSET, 0)
            else
                square:SetPoint("LEFT", row.roleSquares[index - 1], "RIGHT", SEARCH_ROLE_SQUARE_SPACING, 0)
            end
        end

        local summaryX1, summaryX2, summaryX3 = GetSearchRoleSummaryX(layout)
        for index, summary in ipairs(row.roleSummaries) do
            summary:ClearAllPoints()
            local summaryX = (index == 1 and summaryX1) or (index == 2 and summaryX2) or summaryX3
            summary:SetPoint("LEFT", row, "LEFT", summaryX - SEARCH_ROW_X_OFFSET, 0)
        end

        row.titleText:ClearAllPoints()
        row.titleText:SetPoint("LEFT", row, "LEFT", layout.titleX - SEARCH_ROW_X_OFFSET, 0)
        row.titleText:SetWidth(layout.titleWidth)

        row.ratingText:ClearAllPoints()
        row.ratingText:SetPoint("CENTER", row, "LEFT", layout.ratingX + (layout.ratingWidth / 2) - SEARCH_ROW_X_OFFSET, 0)
        row.ratingText:SetWidth(layout.ratingWidth)

        row.ageText:ClearAllPoints()
        row.ageText:SetPoint("CENTER", row, "LEFT", layout.ageX + (layout.ageWidth / 2) - SEARCH_ROW_X_OFFSET, 0)
        row.ageText:SetWidth(layout.ageWidth)

        row.notesText:ClearAllPoints()
        row.notesText:SetPoint("LEFT", row, "LEFT", layout.notesX - SEARCH_ROW_X_OFFSET, 0)
        row.notesText:SetPoint("RIGHT", row.applyBtn, "LEFT", -6, 0)
        if row.notesText then
            if hideNotes then
                row.notesText:Hide()
            else
                row.notesText:Show()
            end
        end

        row.applyBtn:ClearAllPoints()
        row.cancelBtn:ClearAllPoints()
        if hideNotes then
            local collapsedCenterX = GetCollapsedSearchActionCenterX(layout)
            row.applyBtn:SetPoint("CENTER", row, "LEFT", collapsedCenterX, 0)
            row.cancelBtn:SetPoint("CENTER", row, "LEFT", collapsedCenterX, 0)
        else
            local actionInset = GetSearchActionRightInset()
            row.applyBtn:SetPoint("RIGHT", row, "RIGHT", actionInset, 0)
            row.cancelBtn:SetPoint("RIGHT", row, "RIGHT", actionInset, 0)
        end
    end
end

notesToggleBtn:SetScript("OnClick", function()
    OakLFGSorterDB.searchHideNotes = not OakLFGSorterDB.searchHideNotes
    ApplySearchNotesLayout(true)
    RequestUpdate()
end)

local function CreateRow(index)
    local row = CreateFrame("Button", nil, scrollChild)
    row:SetHeight(ROW_HEIGHT)
    if index == 1 then row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0); row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
    else row:SetPoint("TOPLEFT", rows[index-1], "BOTTOMLEFT", 0, 0); row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0) end

    row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints()
    row.hoverBg = row:CreateTexture(nil, "ARTWORK"); row.hoverBg:SetAllPoints(); row.hoverBg:SetColorTexture(1, 1, 1, 0.1); row.hoverBg:Hide()

    row:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
    row:SetScript("OnDoubleClick", function(self)
        if self.groupData and self.groupData.id and not self.groupData.isApplied and not self.groupData.isDeclined and LFGListFrame and LFGListFrame.SearchPanel then
            LFGListSearchPanel_SelectResult(LFGListFrame.SearchPanel, self.groupData.id)
            LFGListSearchPanel_SignUp(LFGListFrame.SearchPanel)
        end
    end)

    row:SetScript("OnEnter", function(self) 
        self.hoverBg:Show() 
        if self.groupData then
            local grp = self.groupData
            local mode = grp.mode or "generic"
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()

            if mode == "raid" or mode == "legacy_raid" then
                GameTooltip:AddLine(string.format("%d/%d/%d", grp.tanks or 0, grp.heals or 0, grp.dps or 0), 1, 1, 1)
                GameTooltip:AddLine(grp.activityName or "Unknown Raid", 1, 0.82, 0)
                if grp.playstyleLabel and grp.playstyleLabel ~= "" and grp.playstyleLabel ~= "Any" then
                    GameTooltip:AddLine(grp.playstyleLabel, 0.2, 1, 0.2)
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine("Leader:", grp.leaderNameRaw or "Unknown", 1, 1, 1, 1, 1, 1)
                GameTooltip:AddDoubleLine("Members:", string.format("%d (%d/%d/%d)", grp.members or 0, grp.tanks or 0, grp.heals or 0, grp.dps or 0), 1, 1, 1, 1, 1, 1)
                GameTooltip:AddDoubleLine("Created:", FormatTime(grp.age or 0) .. " ago", 1, 1, 1, 1, 1, 1)

                local roleGroups = BuildRoleClassBreakdown(grp.memberDetails)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Class Roles", 1, 0.82, 0)
                AddRoleClassLines(GameTooltip, "Damage", "DAMAGER", roleGroups)
                AddRoleClassLines(GameTooltip, "Tank", "TANK", roleGroups)
                AddRoleClassLines(GameTooltip, "Healer", "HEALER", roleGroups)

                if grp.raidProgress then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Raider.IO Raid Progress", 1, 0.82, 0)
                    GameTooltip:AddDoubleLine(grp.raidProgress.raidName or "Current Tier", grp.raidProgress.longText or grp.raidProgress.displayText or "--", 1, 1, 1, 0.2, 1, 0.2)
                end
            elseif mode == "rated_pvp" or mode == "pvp" then
                GameTooltip:AddLine(grp.activityName or "Unknown Activity", 1, 1, 1)
                if grp.playstyleLabel and grp.playstyleLabel ~= "" and grp.playstyleLabel ~= "Any" then
                    GameTooltip:AddLine(grp.playstyleLabel, 0.2, 1, 0.2)
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine("Leader:", grp.leaderNameRaw or "Unknown", 1, 1, 1, 1, 1, 1)
                GameTooltip:AddDoubleLine("Members:", string.format("%d (%d/%d/%d)", grp.members or 0, grp.tanks or 0, grp.heals or 0, grp.dps or 0), 1, 1, 1, 1, 1, 1)
                GameTooltip:AddDoubleLine("Created:", FormatTime(grp.age or 0) .. " ago", 1, 1, 1, 1, 1, 1)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("PVP Profile (Leader)", 0.2, 1, 0.2)
                GameTooltip:AddDoubleLine("Rating:", (grp.pvpRating and grp.pvpRating > 0) and grp.pvpRating or "--", 1, 1, 1, 1, 1, 1)
                if grp.pvpBracket then
                    GameTooltip:AddDoubleLine("Bracket:", grp.pvpBracket, 1, 1, 1, 1, 1, 1)
                end
            else
                GameTooltip:AddLine((grp.displayTitle ~= "" and grp.displayTitle or "--"), 1, 1, 1)
                GameTooltip:AddLine(grp.activityName or "Unknown Activity", 1, 0.82, 0)
                if grp.playstyleLabel and grp.playstyleLabel ~= "" and grp.playstyleLabel ~= "Any" then
                    GameTooltip:AddLine(grp.playstyleLabel, 0.2, 1, 0.2)
                end

                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine("Leader:", grp.leaderNameRaw or "Unknown", 1, 1, 1, 1, 1, 1)
                GameTooltip:AddLine("Mythic+ Profile (Leader)", 0.2, 1, 0.2)

                local score = math.floor(grp.rating or 0)
                local cR, cG, cB = GetPreferredScoreColor(score, 1, 1, 1)
                GameTooltip:AddDoubleLine("Overall Rating:", score > 0 and score or "--", 1, 1, 1, cR, cG, cB)

                if grp.rioProfile and type(grp.rioProfile.mythicKeystoneProfile) == "table" then
                    local mPlus = grp.rioProfile.mythicKeystoneProfile
                    local mainScore = math.floor(mPlus.mainCurrentScore or 0)
                    if mainScore > score then
                        local mcR, mcG, mcB = GetPreferredScoreColor(mainScore, 0.5, 0.5, 0.5)
                        GameTooltip:AddDoubleLine("Main Rating:", mainScore, 0.5, 0.5, 0.5, mcR, mcG, mcB)
                    end

                    if type(mPlus.sortedDungeons) == "table" and #mPlus.sortedDungeons > 0 then
                        local bestRun = mPlus.sortedDungeons[1]
                        if type(bestRun) == "table" and type(bestRun.level) == "number" and bestRun.level > 0 then
                            local bestName = (type(bestRun.dungeon) == "table" and (bestRun.dungeon.shortName or bestRun.dungeon.name)) or "Unknown"
                            GameTooltip:AddDoubleLine("Best Run:", "+" .. bestRun.level .. " " .. bestName, 1, 1, 1, 1, 1, 1)
                        end

                        local bestForDungeon = nil
                        for _, dungeon in ipairs(mPlus.sortedDungeons) do
                            local shortName = type(dungeon.dungeon) == "table" and (dungeon.dungeon.shortName or dungeon.dungeon.name) or ""
                            if shortName ~= "" and grp.dungeon and strlower(shortName) == strlower(grp.dungeon) then
                                bestForDungeon = dungeon
                                break
                            end
                        end
                        if bestForDungeon and type(bestForDungeon.level) == "number" and bestForDungeon.level > 0 then
                            GameTooltip:AddDoubleLine("Best for Dungeon:", "+" .. bestForDungeon.level .. " " .. (bestForDungeon.dungeon.shortName or grp.dungeon), 1, 1, 1, 1, 1, 1)
                        end
                    end
                end

                if grp.keyLevel and grp.keyLevel > 0 then
                    GameTooltip:AddDoubleLine("Parsed Key:", "+" .. grp.keyLevel, 1, 1, 1, 1, 1, 1)
                end

                local roleGroups = BuildRoleClassBreakdown(grp.memberDetails)
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine("Members:", string.format("%d (%d/%d/%d)", grp.members or 0, grp.tanks or 0, grp.heals or 0, grp.dps or 0), 1, 1, 1, 1, 1, 1)
                GameTooltip:AddLine("Members", 1, 0.82, 0)
                AddRoleClassLines(GameTooltip, "Tank", "TANK", roleGroups)
                AddRoleClassLines(GameTooltip, "Healer", "HEALER", roleGroups)
                AddRoleClassLines(GameTooltip, "Damage", "DAMAGER", roleGroups)

                if grp.rioProfile and type(grp.rioProfile.mythicKeystoneProfile) == "table" and type(grp.rioProfile.mythicKeystoneProfile.sortedDungeons) == "table" then
                    local dungeons = grp.rioProfile.mythicKeystoneProfile.sortedDungeons
                    if #dungeons > 0 then
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("Top R.IO Runs", 1, 0.82, 0)
                        for i = 1, math.min(3, #dungeons) do
                            local dungeon = dungeons[i]
                            if type(dungeon) == "table" and type(dungeon.level) == "number" and dungeon.level > 0 then
                                local upgrades = (type(dungeon.numUpgrades) == "number" and dungeon.numUpgrades > 0) and string.rep("+", dungeon.numUpgrades) or ""
                                local dungeonName = (type(dungeon.dungeon) == "table" and (dungeon.dungeon.shortName or dungeon.dungeon.name)) or "Unknown"
                                GameTooltip:AddDoubleLine(dungeonName, "+" .. dungeon.level .. upgrades, 1, 1, 1, 0.2, 1, 0.2)
                            end
                        end
                    end
                end

                GameTooltip:AddDoubleLine("Created:", FormatTime(grp.age or 0) .. " ago", 1, 1, 1, 1, 1, 1)

                if grp.raidProgress then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Raider.IO Raid Progress", 1, 0.82, 0)
                    GameTooltip:AddDoubleLine(grp.raidProgress.raidName or "Current Tier", grp.raidProgress.longText or grp.raidProgress.displayText or "--", 1, 1, 1, 0.2, 1, 0.2)
                end
            end

            if grp.commentStr and grp.commentStr ~= "" then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Group Note:", 1, 0.8, 0)
                GameTooltip:AddLine(grp.commentStr, 0.85, 0.85, 0.85, true)
            end
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self) self.hoverBg:Hide(); GameTooltip:Hide() end)

    row.dungeonText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    row.dungeonText:SetPoint("TOPLEFT", row, "TOPLEFT", 5, 0)
    row.dungeonText:SetWidth(SEARCH_LAYOUT_EXPANDED.dungeonWidth); row.dungeonText:SetHeight(30); row.dungeonText:SetJustifyH("LEFT"); row.dungeonText:SetJustifyV("MIDDLE"); row.dungeonText:SetWordWrap(true)
    
    row.playstyleText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.playstyleText:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 5, 4)
    row.playstyleText:SetWidth(SEARCH_LAYOUT_EXPANDED.dungeonWidth); row.playstyleText:SetJustifyH("LEFT"); row.playstyleText:SetWordWrap(false)
    
    row.roleSquares = {}
    local startX = GetSearchRoleStartX(SEARCH_LAYOUT_EXPANDED) - SEARCH_ROW_X_OFFSET
    for i = 1, 5 do
        local sq = CreateRoleSquare(row, SEARCH_ROLE_SQUARE_SIZE)
        if i == 1 then sq:SetPoint("LEFT", row, "LEFT", startX, 0)
        else sq:SetPoint("LEFT", row.roleSquares[i-1], "RIGHT", SEARCH_ROLE_SQUARE_SPACING, 0) end
        row.roleSquares[i] = sq
    end
    local summaryX1, summaryX2, summaryX3 = GetSearchRoleSummaryX(SEARCH_LAYOUT_EXPANDED)
    row.roleSummaries = {
        CreateRoleSummary(row, "TANK", summaryX1 - SEARCH_ROW_X_OFFSET),
        CreateRoleSummary(row, "HEALER", summaryX2 - SEARCH_ROW_X_OFFSET),
        CreateRoleSummary(row, "DAMAGER", summaryX3 - SEARCH_ROW_X_OFFSET),
    }

    row.titleText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    row.titleText:SetPoint("LEFT", row, "LEFT", SEARCH_LAYOUT_EXPANDED.titleX - SEARCH_ROW_X_OFFSET, 0); row.titleText:SetWidth(SEARCH_LAYOUT_EXPANDED.titleWidth); row.titleText:SetJustifyH("LEFT")

    row.ratingText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    row.ratingText:SetPoint("CENTER", row, "LEFT", SEARCH_LAYOUT_EXPANDED.ratingX + (SEARCH_LAYOUT_EXPANDED.ratingWidth / 2) - SEARCH_ROW_X_OFFSET, 0); row.ratingText:SetWidth(SEARCH_LAYOUT_EXPANDED.ratingWidth); row.ratingText:SetJustifyH("CENTER")

    row.ageText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    row.ageText:SetPoint("CENTER", row, "LEFT", SEARCH_LAYOUT_EXPANDED.ageX + (SEARCH_LAYOUT_EXPANDED.ageWidth / 2) - SEARCH_ROW_X_OFFSET, 0); row.ageText:SetWidth(SEARCH_LAYOUT_EXPANDED.ageWidth); row.ageText:SetJustifyH("CENTER")

    row.notesText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    row.notesText:SetPoint("LEFT", row, "LEFT", SEARCH_LAYOUT_EXPANDED.notesX - SEARCH_ROW_X_OFFSET, 0)
    row.notesText:SetPoint("RIGHT", row, "RIGHT", -SEARCH_NOTES_RIGHT_MARGIN, 0)
    row.notesText:SetJustifyH("LEFT")
    row.notesText:SetWordWrap(false)
    row.notesText:SetTextColor(0.7, 0.7, 0.7)
    if row.notesText.SetMaxLines then
        row.notesText:SetMaxLines(1)
    end

    -- Sign Up Button (Green Checkmark)
    row.applyBtn = CreateFrame("Button", nil, row)
    row.applyBtn:SetSize(20, 20)
    row.applyBtn:SetPoint("RIGHT", row, "RIGHT", GetSearchActionRightInset(), 0)
    row.applyBtn:SetNormalTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
    row.applyBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
    row.applyBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sign Up", 0.2, 1, 0.2)
        GameTooltip:Show()
    end)
    row.applyBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    row.applyBtn:SetScript("OnClick", function(self)
        if row.groupData and row.groupData.id and not row.groupData.isApplied and not row.groupData.isDeclined and LFGListFrame and LFGListFrame.SearchPanel then
            LFGListSearchPanel_SelectResult(LFGListFrame.SearchPanel, row.groupData.id)
            LFGListSearchPanel_SignUp(LFGListFrame.SearchPanel)
        end
    end)

    -- Cancel Button (Red X)
    row.cancelBtn = CreateFrame("Button", nil, row)
    row.cancelBtn:SetSize(20, 20)
    row.cancelBtn:SetPoint("RIGHT", row, "RIGHT", GetSearchActionRightInset(), 0)
    row.cancelBtn:SetNormalTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
    row.cancelBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
    row.cancelBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Cancel Application", 1, 0.2, 0.2)
        GameTooltip:Show()
    end)
    row.cancelBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    row.cancelBtn:SetScript("OnClick", function(self)
        if row.groupData and row.groupData.id then
            C_LFGList.CancelApplication(row.groupData.id)
        end
    end)

    row.notesText:ClearAllPoints()
    row.notesText:SetPoint("LEFT", row, "LEFT", SEARCH_LAYOUT_EXPANDED.notesX - SEARCH_ROW_X_OFFSET, 0)
    row.notesText:SetPoint("RIGHT", row.applyBtn, "LEFT", -6, 0)

    return row
end

function OAK_SEARCH:UpdateDisplay()
    local myT, myH, myD = GetMyPartyRoles()
    local filteredGroups = {}
    local useNativeDungeonFilters = SearchModeUsesNativeDungeonFilters(currentSearchMode)
    local adv = useNativeDungeonFilters and GetAdvancedSearchFilter() or nil
    local selectedActivityGroups = {}
    local playerClassToken = select(2, UnitClass("player"))

    if adv and type(adv.activities) == "table" then
        for _, groupID in ipairs(adv.activities) do
            local numericID = tonumber(groupID)
            if numericID and numericID > 0 then
                selectedActivityGroups[numericID] = true
            end
        end
    end
    
    for _, group in ipairs(searchResults) do
        local skip = false

        if useNativeDungeonFilters then
            local selectedCount = 0
            for _ in pairs(selectedActivityGroups) do
                selectedCount = selectedCount + 1
            end
            if selectedCount > 0 and not selectedActivityGroups[tonumber(group.activityGroupID) or 0] then
                skip = true
            end

            if adv.hasTank and group.tanks == 0 then skip = true end
            if adv.hasHealer and group.heals == 0 then skip = true end
        else
            local anyFilterActive = false
            local matchFound = false
            for _, activityName in ipairs(currentActivityFilters) do
                if OAK_F.Activities[activityName] then
                    anyFilterActive = true
                    if group.filterLabel == activityName then
                        matchFound = true
                    end
                end
            end
            if anyFilterActive and not matchFound then skip = true end

            if OAK_F.HasTank and group.tanks == 0 then skip = true end
            if OAK_F.HasHeal and group.heals == 0 then skip = true end
        end

        local maxPlayers = tonumber(group.maxPlayers) or 0
        if useNativeDungeonFilters then
            if adv.needsTank and group.tanks >= 1 then skip = true end
            if adv.needsHealer and group.heals >= 1 then skip = true end
            if adv.needsDamage and group.dps >= 3 then skip = true end
            if adv.minimumRating and (tonumber(group.rating) or 0) < tonumber(adv.minimumRating) then
                skip = true
            end
            if adv.needsMyClass and playerClassToken then
                local foundClass = false
                for _, member in ipairs(group.memberDetails or {}) do
                    if member.class and string.upper(member.class) == playerClassToken then
                        foundClass = true
                        break
                    end
                end
                if foundClass then
                    skip = true
                end
            end
        else
            if currentSearchMode == "mythic_plus" or currentSearchMode == "dungeon" or currentSearchMode == "generic" or currentSearchMode == "delve" or currentSearchMode == "rated_pvp" or currentSearchMode == "pvp" then
                if OAK_F.NeedTank and group.tanks >= 1 then skip = true end
                if OAK_F.NeedHeal and group.heals >= 1 then skip = true end
                if OAK_F.NeedDPS and group.dps >= 3 then skip = true end
            elseif maxPlayers > 5 then
                local targetTanks = math.max(1, math.min(2, math.ceil(maxPlayers / 10)))
                local targetHeals = math.max(2, math.floor(maxPlayers / 5))
                local targetDps = math.max(0, maxPlayers - targetTanks - targetHeals)

                if OAK_F.NeedTank and group.tanks >= targetTanks then skip = true end
                if OAK_F.NeedHeal and group.heals >= targetHeals then skip = true end
                if OAK_F.NeedDPS and (group.dps >= targetDps or group.members >= maxPlayers) then skip = true end
            end
        end

        if OAK_F.NeedLust and group.hasLust then skip = true end
        if OAK_F.NeedBrez and group.hasBrez then skip = true end

        if SearchModeUsesDifficulty(currentSearchMode) then
            if OAK_F.Difficulty == "NORMAL" and group.difficultyToken ~= "NORMAL" then skip = true end
            if OAK_F.Difficulty == "HEROIC" and group.difficultyToken ~= "HEROIC" then skip = true end
            if OAK_F.Difficulty == "MYTHIC" and group.difficultyToken ~= "MYTHIC" then skip = true end
            if OAK_F.Difficulty == "MYTHIC_PLUS" and group.difficultyToken ~= "MYTHIC_PLUS" then skip = true end
        end

        local rowMode = group.mode or currentSearchMode
        local isKeyListing = rowMode == "mythic_plus" or rowMode == "generic" or rowMode == "delve" or group.difficultyToken == "MYTHIC_PLUS" or (tonumber(group.keyLevel) or 0) > 0
        local isPvpListing = rowMode == "rated_pvp" or rowMode == "pvp"

        if isPvpListing then
            local pvpQuery = TrimString(OAK_F.SearchQuery)
            local exactRating = tonumber(pvpQuery)
            if exactRating and (tonumber(group.pvpRating) or 0) ~= exactRating then
                skip = true
            end
        end

        if OAK_F.PartyFit then
            if maxPlayers == 5 then
                if (group.tanks + myT > 1) or (group.heals + myH > 1) or (group.dps + myD > 3) or (group.members + myT + myH + myD > 5) then
                    skip = true
                end
            elseif maxPlayers > 0 and (group.members + myT + myH + myD > maxPlayers) then
                skip = true
            end
        end

        if not skip then table.insert(filteredGroups, group) end
    end

    table.sort(filteredGroups, function(a, b) return SortGroups(a, b, currentSortBy, currentIsAscending) end)

    for _, row in ipairs(rows) do row:Hide() end

    local displayIndex = 1
    local isAltColor = false 

    for _, group in ipairs(filteredGroups) do
        if not rows[displayIndex] then rows[displayIndex] = CreateRow(displayIndex) end
        local row = rows[displayIndex]
        
        row.groupData = group
        
        if group.isApplied then
            row.bg:SetColorTexture(0.2, 0.6, 0.2, 0.6) 
        elseif group.isDeclined then
            row.bg:SetColorTexture(0.6, 0.1, 0.1, 0.5) 
        elseif group.isFriend then
            row.bg:SetColorTexture(0.15, 0.4, 0.6, 0.6) 
        else
            row.bg:SetColorTexture(unpack(isAltColor and ROW_COLOR_B or ROW_COLOR_A))
        end
        
        -- Exact short native string directly displayed
        row.dungeonText:SetText(group.dungeon)
        
        if group.playstyleLabel and group.playstyleLabel ~= "" and group.playstyleLabel ~= "Any" then
            row.playstyleText:SetText(group.playstyleLabel)
        else
            row.playstyleText:SetText("")
        end
        
        row.titleText:SetText(group.titleStr or "")
        row.notesText:SetText(tostring(group.commentStr or ""))
        
        local setupSlots, setupMode = BuildSetupSlots(group)
        if setupMode == "summary" then
            for _, square in ipairs(row.roleSquares) do
                square:Hide()
            end
            local summaryCounts = {
                TANK = group.tanks or 0,
                HEALER = group.heals or 0,
                DAMAGER = group.dps or 0,
            }
            local summaryRoles = { "TANK", "HEALER", "DAMAGER" }
            for index, role in ipairs(summaryRoles) do
                local summary = row.roleSummaries[index]
                local l, r, t, b = GetRoleTexCoords(role)
                summary.icon:SetTexCoord(l, r, t, b)
                summary.count:SetText(tostring(summaryCounts[role] or 0))
                summary:Show()
            end
        else
            for _, summary in ipairs(row.roleSummaries) do
                summary:Hide()
            end
            for index, square in ipairs(row.roleSquares) do
                local slotInfo = setupSlots and setupSlots[index]
                if slotInfo then
                    square:Show()
                    if slotInfo.filled and slotInfo.class then
                        local c = RAID_CLASS_COLORS[slotInfo.class]
                        if c then
                            square.bg:SetColorTexture(c.r, c.g, c.b, 0.8)
                        else
                            square.bg:SetColorTexture(0.5, 0.5, 0.5, 0.8)
                        end
                        local l, r, t, b = GetRoleTexCoords(slotInfo.role)
                        square.icon:SetTexCoord(l, r, t, b)
                        square.icon:SetDesaturated(false)
                        square.icon:SetAlpha(1.0)
                    else
                        square.bg:SetColorTexture(0, 0, 0, 0.3)
                        local l, r, t, b = GetRoleTexCoords(slotInfo and slotInfo.role or "DAMAGER")
                        square.icon:SetTexCoord(l, r, t, b)
                        square.icon:SetDesaturated(true)
                        square.icon:SetAlpha(0.3)
                    end
                else
                    square:Hide()
                end
            end
        end
        
        local rNum = math.floor(group.rating or 0)
        local rStr = (rNum > 0 and tostring(rNum)) or "--"
        if group.mode == "raid" or group.mode == "legacy_raid" then
            rStr = (group.raidProgress and group.raidProgress.displayText) or "--"
        elseif group.mode == "rated_pvp" or group.mode == "pvp" then
            rStr = (rNum > 0 and tostring(rNum)) or "--"
        elseif rNum > 0 then
            local r, g, b = GetPreferredScoreColor(rNum, 1, 1, 1)
            rStr = string.format("|cFF%02x%02x%02x%s|r", (r or 1)*255, (g or 1)*255, (b or 1)*255, rStr)
        end
        row.ratingText:SetText(rStr)
        
        if group.isDeclined then
            row.applyBtn:Hide()
            row.cancelBtn:Hide()
            row.ageText:SetText("Declined")
            row.ageText:SetTextColor(1, 0.2, 0.2)
        elseif group.isApplied then
            row.applyBtn:Hide()
            row.cancelBtn:Show()
            row.ageText:SetText("Pending")
            row.ageText:SetTextColor(0.2, 1, 0.2)
        else
            row.applyBtn:Show()
            row.cancelBtn:Hide()
            row.ageText:SetText(FormatTime(group.age))
            row.ageText:SetTextColor(1, 1, 1)
        end

        row:Show(); displayIndex = displayIndex + 1; isAltColor = not isAltColor
    end

    scrollChild:SetHeight(math.max(1, (displayIndex - 1) * ROW_HEIGHT))
    OAK_SEARCH.footerText:SetText(string.format("Showing %d of %d groups", #filteredGroups, #searchResults))
end

-- ==========================================
-- 8. Data Retrieval & Events
-- ==========================================
local function FetchSearchResults()
    wipe(searchResults)
    local first, second = C_LFGList.GetSearchResults()
    local results = type(first) == "table" and first or second
    if type(results) ~= "table" then
        currentSearchMode = "generic"
        UpdateSearchFilterPane()
        OAK_SEARCH.UpdateHeaderVisuals()
        return
    end

    for _, resultID in ipairs(results) do
        local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)
        
        if searchResultInfo and not searchResultInfo.isDelisted then
            local activityID = GetSearchResultActivityID(searchResultInfo)
            local activityInfo = activityID and C_LFGList.GetActivityInfoTable(activityID) or nil
            local memberCounts = C_LFGList.GetSearchResultMemberCounts(resultID) or {}
            
            local appID, appStatus = C_LFGList.GetApplicationInfo(resultID)
            local isApplied = (appStatus == "applied" or appStatus == "invited")
            local isDeclined = (appStatus == "declined" or appStatus == "declined_delisted" or appStatus == "declined_full" or appStatus == "failed" or appStatus == "timedout")
            
            if activityInfo then
                local mode, rating, ratingLabel, pvpRating, pvpBracket = GetResultRatingData(searchResultInfo, activityInfo)

                local hasLust, hasBrez = false, false
                local memberDetails = {}
                local playstyleValue, playstyleLabel = GetSearchPlaystyle(searchResultInfo, activityInfo)

                for i = 1, tonumber(searchResultInfo.numMembers) or 0 do
                    local role, classStr = C_LFGList.GetSearchResultMemberInfo(resultID, i)
                    if classStr and role then
                        table.insert(memberDetails, {role = role, class = classStr})
                        local c = string.upper(classStr)
                        if c == "MAGE" or c == "SHAMAN" or c == "HUNTER" or c == "EVOKER" then hasLust = true end
                        if c == "DEATHKNIGHT" or c == "DRUID" or c == "WARLOCK" or c == "PALADIN" then hasBrez = true end
                    end
                end
                
                local isFriend = (searchResultInfo.numBNetFriends or 0) > 0 or (searchResultInfo.numCharFriends or 0) > 0 or (searchResultInfo.numGuildMates or 0) > 0
                local rawFullName = activityInfo.fullName or "Unknown"
                local dName = string.gsub(rawFullName, "%s*%(.+%)", "")
                local keyLevel = ParseListedKeyLevel(searchResultInfo, activityInfo)

                local rioProfile = nil
                if searchResultInfo.leaderName and RaiderIO and RaiderIO.GetProfile then
                    local charName, charRealm = strsplit("-", searchResultInfo.leaderName)
                    if not charRealm or charRealm == "" then charRealm = GetNormalizedRealmName() or "" end
                    rioProfile = RaiderIO.GetProfile(charName, charRealm)
                end

                local raidProgress = nil
                if rioProfile and addonTable.GetRaidProgressSummary then
                    raidProgress = addonTable.GetRaidProgressSummary(rioProfile, dName)
                end

                if (mode == "rated_pvp" or mode == "pvp") and not pvpBracket then
                    pvpBracket = GetSearchPvpBracketLabel(nil, activityInfo, searchResultInfo.numMembers)
                end

                local displayActivity = dName
                if mode == "rated_pvp" or mode == "pvp" then
                    displayActivity = pvpBracket or dName
                elseif mode == "open_world" then
                    displayActivity = GetSearchFilterLabel(mode, activityInfo)
                end

                table.insert(searchResults, {
                    id = resultID,
                    dungeon = displayActivity,
                    filterLabel = GetSearchFilterLabel(mode, activityInfo, pvpBracket),
                    activityGroupID = tonumber(activityInfo.groupFinderActivityGroupID or activityInfo.groupID) or 0,
                    activityName = rawFullName,
                    difficulty = activityInfo.difficultyID or 0,
                    difficultyToken = GetSearchDifficultyToken(activityInfo),
                    mode = mode,
                    leaderNameRaw = searchResultInfo.leaderName or "Unknown",
                    isFriend = isFriend,
                    isApplied = isApplied,
                    isDeclined = isDeclined,
                    tanks = memberCounts.TANK or 0,
                    heals = memberCounts.HEALER or 0,
                    dps = memberCounts.DAMAGER or 0,
                    hasLust = hasLust,
                    hasBrez = hasBrez,
                    members = searchResultInfo.numMembers or 0,
                    memberDetails = memberDetails,
                    maxPlayers = tonumber(activityInfo.maxPlayers) or tonumber(searchResultInfo.numMembers) or 0,
                    ilvl = searchResultInfo.requiredItemLevel or 0,
                    rating = rating or 0,
                    ratingLabel = ratingLabel,
                    pvpRating = pvpRating or 0,
                    pvpBracket = pvpBracket,
                    age = searchResultInfo.age or 0,
                    titleStr = tostring(searchResultInfo.name or searchResultInfo.comment or ""),
                    displayTitle = GetCondensedSearchTitle(searchResultInfo.name or searchResultInfo.comment or ""),
                    commentStr = tostring(searchResultInfo.comment or ""),
                    playstyleValue = playstyleValue,
                    playstyleLabel = playstyleLabel,
                    keyLevel = keyLevel,
                    rioProfile = rioProfile,
                    raidProgress = raidProgress,
                    numBNetFriends = tonumber(searchResultInfo.numBNetFriends) or 0,
                    numCharFriends = tonumber(searchResultInfo.numCharFriends) or 0,
                    numGuildMates = tonumber(searchResultInfo.numGuildMates) or 0,
                })
            end
        end
    end

    currentSearchMode = DetermineSearchMode()
    UpdateSearchFilterPane()
    OAK_SEARCH.UpdateHeaderVisuals()
end

local isUpdating = false
RequestUpdate = function()
    if isUpdating then return end
    isUpdating = true
    C_Timer.After(0.1, function()
        if OAK_SEARCH:IsShown() then
            FetchSearchResults()
            OAK_SEARCH:UpdateDisplay()
        end
        isUpdating = false
    end)
end

ScheduleSearchRefresh = function()
    local delays = {0.08, 0.25, 0.5}
    for _, delay in ipairs(delays) do
        C_Timer.After(delay, function()
            if OAK_SEARCH and OAK_SEARCH:IsShown() and RequestUpdate then
                RequestUpdate()
            end
        end)
    end
end

OAK_SEARCH:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
OAK_SEARCH:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
OAK_SEARCH:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
OAK_SEARCH:RegisterEvent("LFG_LIST_APPLICANT_UPDATED")

OAK_SEARCH:SetScript("OnEvent", function(self, event, ...) RequestUpdate() end)
OAK_SEARCH:SetScript("OnShow", function(self)
    HideApplicantWindow()
    scaleSlider:SetValue(OakLFGSorterDB.searchScale or 1.0)
    AutoPositionSearch()
    ApplySearchScale(OakLFGSorterDB.searchScale or 1.0)
    ApplySearchNotesLayout()
    if addonTable.RefreshRIOAnchor then
        addonTable.RefreshRIOAnchor()
    elseif addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(OAK_SEARCH)
    end
    RequestUpdate()
    OAK_SEARCH.UpdateHeaderVisuals()
end)
OAK_SEARCH:SetScript("OnHide", function()
    if filterPanel then filterPanel:Hide() end
    if supportersPanel then supportersPanel:Hide() end
    if RestoreNativeSearchBox then
        RestoreNativeSearchBox()
    end
    if addonTable.RefreshRIOAnchor then
        addonTable.RefreshRIOAnchor()
    end
end)

if PVEFrame then
    hooksecurefunc(PVEFrame, "SetPoint", function()
        if OAK_SEARCH:IsShown() and not HasSavedSearchFramePosition() then
            AutoPositionSearch()
            ApplySearchScale(OakLFGSorterDB.searchScale or 1.0)
        end
    end)
end

-- ==========================================
-- 9. Hooking the Start Search Button & Native Toggle
-- ==========================================
local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == addonName or loadedAddon == "Blizzard_LookingForGroupUI" then
        if addonTable.OAK_LFG and not addonTable.OAK_LFG.OakSearchMutualHooked then
            addonTable.OAK_LFG:HookScript("OnShow", function()
                if OAK_SEARCH:IsShown() then
                    OAK_SEARCH:Hide()
                end
            end)
            addonTable.OAK_LFG.OakSearchMutualHooked = true
        end

        if LFGListFrame and LFGListFrame.SearchPanel and not LFGListFrame.SearchPanel.OakSearchToggleHooked then
            local toggleHolder = CreateFrame("Frame", nil, LFGListFrame.SearchPanel)
            toggleHolder:SetSize(170, 18)
            toggleHolder:SetPoint("TOP", LFGListFrame.SearchPanel, "TOP", 0, -32)

            local toggleBox = CreateFrame("Button", nil, toggleHolder, "BackdropTemplate")
            toggleBox:SetSize(16, 16)
            toggleBox:SetPoint("LEFT", toggleHolder, "LEFT", 0, 0)
            toggleBox:SetBackdrop({bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1})
            
            local lbl = toggleHolder:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
            lbl:SetPoint("LEFT", toggleBox, "RIGHT", 8, 0)
            lbl:SetText("Auto-Open Sorter")
            
            OakLFGSorterDB = OakLFGSorterDB or {}
            if OakLFGSorterDB.autoOpenSearch == nil then OakLFGSorterDB.autoOpenSearch = true end
            
            local function UpdateState()
                if OakLFGSorterDB.autoOpenSearch then
                    toggleBox:SetBackdropColor(classColor.r, classColor.g, classColor.b, 1)
                    toggleBox:SetBackdropBorderColor(0, 0, 0, 1)
                else
                    toggleBox:SetBackdropColor(0.106, 0.106, 0.129, 1)
                    toggleBox:SetBackdropBorderColor(0, 0, 0, 1)
                end
            end
            
            UpdateState()
            toggleBox:SetScript("OnClick", function()
                OakLFGSorterDB.autoOpenSearch = not OakLFGSorterDB.autoOpenSearch
                UpdateState()
                if OakLFGSorterDB.autoOpenSearch then
                    OAK_SEARCH:Show()
                else
                    OAK_SEARCH:Hide()
                end
            end)
            
            LFGListFrame.SearchPanel:HookScript("OnShow", function()
                if OakLFGSorterDB.autoOpenSearch then
                    OAK_SEARCH:Show()
                else
                    OAK_SEARCH:Hide()
                end
            end)

            LFGListFrame.SearchPanel:HookScript("OnHide", function()
                OAK_SEARCH:Hide()
            end)
            
            LFGListFrame.SearchPanel.OakSearchToggleHooked = true
        end
    end
end)
