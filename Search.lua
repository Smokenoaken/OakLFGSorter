local addonName, addonTable = ...
local L = addonTable.L

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

local playerClass = select(2, UnitClass("player"))
local classColor = RAID_CLASS_COLORS[playerClass] or {r = 1, g = 1, b = 1}
local CreateFlatButton
local filterPanel
local ApplySearchNotesLayout
local RequestUpdate
local ApplyOakSearchQuery
local ScheduleSearchRefresh
local ResetSearchFilters
local AutoPositionSearch
local UpdateSearchFilterPane
local GetNativeDungeonActivityEntries
local nativeSearchHost = {}

function addonTable.SyncSearchRegionToggle()
    if addonTable.OAK_SEARCH and addonTable.OAK_SEARCH.UpdateDisplay then
        addonTable.OAK_SEARCH:UpdateDisplay()
    end
end

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
OAK_SEARCH:SetClampedToScreen(true)
OAK_SEARCH:Hide()
addonTable.OAK_SEARCH = OAK_SEARCH

OakLFGSorterDB = OakLFGSorterDB or {}
if OakLFGSorterDB.autoOpenSearch == nil then OakLFGSorterDB.autoOpenSearch = true end
if OakLFGSorterDB.searchScale == nil then OakLFGSorterDB.searchScale = 1.0 end
if OakLFGSorterDB.searchHideNotes == nil then OakLFGSorterDB.searchHideNotes = false end
if OakLFGSorterDB.searchQuickSignup == nil then OakLFGSorterDB.searchQuickSignup = false end
if OakLFGSorterDB.searchQuickSignupNote == nil then OakLFGSorterDB.searchQuickSignupNote = "" end

local SEARCH_COLUMN_HEADER_Y = -67
local SEARCH_SCROLL_TOP_Y = -94

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

    if addonTable.ClampFrameToScreen then
        addonTable.ClampFrameToScreen(OAK_SEARCH, OakLFGSorterDB, "searchFramePos")
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
    if addonTable.ClampFrameToScreen then
        addonTable.ClampFrameToScreen(OAK_SEARCH, OakLFGSorterDB, "searchFramePos")
    end
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

addonTable.SearchFrameTheme = {
    FLAT_TEX = FLAT_TEX,
    OAK_COLOR_BG = OAK_COLOR_BG,
    OAK_COLOR_PANE = OAK_COLOR_PANE,
    OAK_COLOR_BORDER = OAK_COLOR_BORDER,
    classColor = classColor,
    playerClass = playerClass,
    CreateFlatButton = CreateFlatButton,
}
addonTable.SearchApplyScale = ApplySearchScale
addonTable.SearchSaveFramePosition = SaveSearchFramePosition
addonTable.SearchRestoreFramePosition = RestoreSearchFramePosition
addonTable.SearchHasSavedFramePosition = HasSavedSearchFramePosition
addonTable.SearchHideApplicantWindow = HideApplicantWindow
addonTable.SearchNativeHost = nativeSearchHost

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
addonTable.SearchAutoPosition = AutoPositionSearch

function addonTable.ResetSearchWindow()
    OakLFGSorterDB.searchFramePos = nil
    OakLFGSorterDB.searchFrameUserPlaced = false
    OakLFGSorterDB.searchScale = 1.0
    OakLFGSorterDB.searchHideNotes = false
    if OAK_SEARCH.ScaleSlider then
        OAK_SEARCH.ScaleSlider:SetValue(1.0)
    end
    if OAK_SEARCH.ScaleEdit then
        OAK_SEARCH.ScaleEdit:SetText("1.00")
    end
    ApplySearchScale(1.0)
    if ApplySearchNotesLayout then
        ApplySearchNotesLayout()
    end
end

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
if addonTable.ApplyWindowOpacity then
    addonTable.ApplyWindowOpacity()
end
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
filterTitle:SetText(L["Search Filters"])
filterTitle:SetTextColor(classColor.r, classColor.g, classColor.b)

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
local raidRoleRangeControls = {}
local pendingNativeActivitySelections = {}

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
    MatchMyRaidLockout = false,
    RaidBossesRange = "",
    RaidTankRange = "",
    RaidHealerRange = "",
    RaidDpsRange = "",
    SearchQuery = "",
    Activities = {},
}

for _, dun in ipairs(DEFAULT_SEASON_DUNGEONS) do
    OAK_F.Activities[dun] = false
end
for _, delve in ipairs(DEFAULT_SEASON_DELVES) do
    OAK_F.Activities[delve] = false
end

local function GetPendingNativeActivityKey(label)
    local text = strlower(tostring(label or ""))
    text = text:gsub("%s*%b()", "")
    text = text:gsub("[^%w%s]", "")
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text
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
        return L["Filter Raids"]
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
    elseif mode == "dungeon" then
        return "Examples: 10-11, <10, <12", ""
    elseif mode == "delve" then
        return "Examples: tier 8, bountyful, healer", ""
    elseif mode == "generic" then
        return "Examples: chill, farm, quest, weekly", ""
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

local function SyncNativeDifficultyFilter()
    SaveAdvancedSearchFilter(function(state)
        if currentSearchMode == "mythic_plus" then
            state.difficultyNormal = nil
            state.difficultyHeroic = nil
            state.difficultyMythic = nil
            state.difficultyMythicPlus = true
            return
        end

        if currentSearchMode ~= "dungeon" then
            return
        end

        state.difficultyNormal = (OAK_F.Difficulty == "NORMAL") and true or nil
        state.difficultyHeroic = (OAK_F.Difficulty == "HEROIC") and true or nil
        state.difficultyMythic = (OAK_F.Difficulty == "MYTHIC") and true or nil
        state.difficultyMythicPlus = (OAK_F.Difficulty == "MYTHIC_PLUS") and true or nil
    end)
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
            self:SetBackdropColor(0.08, 0.08, 0.10, 0.95)
            self:SetBackdropBorderColor(0, 0, 0, 1)
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
    box:SetBackdropColor(0.08, 0.08, 0.10, 0.95)
    box:SetBackdropBorderColor(0, 0, 0, 1)

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
            self:SetBackdropColor(0.08, 0.08, 0.10, 0.95)
            self:SetBackdropBorderColor(0, 0, 0, 1)
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

nativeSearchHost.GetNativeSearchBox = function()
    return LFGListFrame and LFGListFrame.SearchPanel and LFGListFrame.SearchPanel.SearchBox
end

nativeSearchHost.AttachNativeSearchBoxToOak = function()
    local searchBox = nativeSearchHost.GetNativeSearchBox()
    if not (searchBox and keyQueryBox) then
        return
    end
    if not nativeSearchHost.ShouldHostNativeSearchBox() then
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

nativeSearchHost.RestoreNativeSearchBox = function()
    local searchBox = nativeSearchHost.GetNativeSearchBox()
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
    SyncNativeDifficultyFilter()
    if ApplyOakSearchQuery then
        ApplyOakSearchQuery(false)
    end
    OAK_SEARCH:UpdateDisplay()
end)
diffDropdown:SetPoint("TOP", filterPanel, "TOP", 0, -35)

keyRangeLabel = filterPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
keyRangeLabel:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, -67)
keyRangeLabel:SetWidth(114)
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

addonTable.SearchQueryButton = CreateFlatButton(filterPanel, L["Search"], 175)
addonTable.SearchQueryButton:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, -116)
addonTable.SearchQueryButton:SetScript("OnClick", function()
    if ApplyOakSearchQuery then
        ApplyOakSearchQuery(true)
    end
end)
addonTable.SearchQueryButton:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    if SearchModeUsesNativeDungeonFilters(currentSearchMode) then
        GameTooltip:SetText("Refresh", 1, 1, 1)
        GameTooltip:AddLine("After changing Blizzard-backed dungeon filters, click Refresh to request updated results from Blizzard.", 1, 1, 1, true)
    else
        GameTooltip:SetText("Search", 1, 1, 1)
        GameTooltip:AddLine("Run the current Oak search/filter query.", 1, 1, 1, true)
    end
    GameTooltip:Show()
end)
addonTable.SearchQueryButton:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)

addonTable.SearchResetButton = CreateFlatButton(filterPanel, L["Reset"], 84)
addonTable.SearchResetButton:SetPoint("TOPLEFT", addonTable.SearchQueryButton, "TOPRIGHT", 7, 0)
addonTable.SearchResetButton:SetScript("OnClick", function()
    ResetSearchFilters()
end)

filterPanel.raidBossRangeLabel = filterPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
filterPanel.raidBossRangeLabel:SetText("Boss Kills")
filterPanel.raidBossRangeLabel:SetTextColor(1, 1, 1)

filterPanel.raidBossRangeHint = filterPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
filterPanel.raidBossRangeHint:SetText("e.g. 1-2, <3, >1, 5")
filterPanel.raidBossRangeHint:SetTextColor(0.72, 0.72, 0.72)

filterPanel.raidBossRangeBox = CreateFrame("EditBox", nil, filterPanel, "BackdropTemplate")
filterPanel.raidBossRangeBox:SetSize(120, 20)
filterPanel.raidBossRangeBox:SetAutoFocus(false)
filterPanel.raidBossRangeBox:SetFontObject("OakLFG_FontRegular")
filterPanel.raidBossRangeBox:SetJustifyH("CENTER")
filterPanel.raidBossRangeBox:SetBackdrop({bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1})
filterPanel.raidBossRangeBox:SetBackdropColor(unpack(OAK_COLOR_BG))
filterPanel.raidBossRangeBox:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))

filterPanel.raidBossRangeResetButton = CreateFlatButton(filterPanel, "R", 20)
filterPanel.raidBossRangeResetButton:SetHeight(20)

local function CommitRaidBossRange()
    OAK_F.RaidBossesRange = filterPanel.raidBossRangeBox:GetText() or ""
    OAK_SEARCH:UpdateDisplay()
end

filterPanel.raidBossRangeBox:SetScript("OnEnterPressed", function(self)
    CommitRaidBossRange()
    self:ClearFocus()
end)
filterPanel.raidBossRangeBox:SetScript("OnEditFocusLost", CommitRaidBossRange)
filterPanel.raidBossRangeResetButton:SetScript("OnClick", function()
    OAK_F.RaidBossesRange = ""
    filterPanel.raidBossRangeBox:SetText("")
    OAK_SEARCH:UpdateDisplay()
end)
filterPanel.raidBossRangeResetButton:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Reset Boss Kills", 1, 1, 1)
    GameTooltip:AddLine("Clears the raid boss min/max range without resetting the rest of your filters.", 1, 1, 1, true)
    GameTooltip:Show()
end)
filterPanel.raidBossRangeResetButton:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)

local function CreateRaidRoleRangeControl(key, labelText, hintText)
    local control = {}
    control.label = filterPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    control.label:SetText(labelText)
    control.label:SetTextColor(1, 1, 1)

    control.hint = filterPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
    control.hint:SetText(hintText)
    control.hint:SetTextColor(0.72, 0.72, 0.72)

    control.box = CreateFrame("EditBox", nil, filterPanel, "BackdropTemplate")
    control.box:SetSize(120, 20)
    control.box:SetAutoFocus(false)
    control.box:SetFontObject("OakLFG_FontRegular")
    control.box:SetJustifyH("CENTER")
    control.box:SetBackdrop({bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1})
    control.box:SetBackdropColor(unpack(OAK_COLOR_BG))
    control.box:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))

    control.resetButton = CreateFlatButton(filterPanel, "R", 20)
    control.resetButton:SetHeight(20)

    local function Commit()
        OAK_F[key] = control.box:GetText() or ""
        OAK_SEARCH:UpdateDisplay()
    end

    control.box:SetScript("OnEnterPressed", function(self)
        Commit()
        self:ClearFocus()
    end)
    control.box:SetScript("OnEditFocusLost", Commit)
    control.resetButton:SetScript("OnClick", function()
        OAK_F[key] = ""
        control.box:SetText("")
        OAK_SEARCH:UpdateDisplay()
    end)
    control.resetButton:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Reset " .. labelText, 1, 1, 1)
        GameTooltip:AddLine("Clears this raid role range without resetting the rest of your filters.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    control.resetButton:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))
        GameTooltip:Hide()
    end)

    table.insert(raidRoleRangeControls, control)
    return control
end

filterPanel.raidTankRange = CreateRaidRoleRangeControl("RaidTankRange", L["Tanks"], "e.g. 1-2, <2, >0, 1")
filterPanel.raidHealerRange = CreateRaidRoleRangeControl("RaidHealerRange", L["Healers"], "e.g. 2-4, <3, >1, 2")
filterPanel.raidDpsRange = CreateRaidRoleRangeControl("RaidDpsRange", "DPS", "e.g. 12-14, <10, >11, 13")

-- Modern 2-Column Exact Layout Match
local startY = -148
local col1X = 16
local col2X = 110

boxNeedTank = CreateOakToggleBox(filterPanel, L["Need Tank"], "NeedTank", true)
boxNeedTank:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", col1X, startY)

boxHasTank = CreateOakToggleBox(filterPanel, L["Has Tank"], "HasTank", false)
boxHasTank:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", col2X, startY)

boxNeedHeal = CreateOakToggleBox(filterPanel, L["Need Heals"], "NeedHeal", true)
boxNeedHeal:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", col1X, startY - 22)

boxHasHeal = CreateOakToggleBox(filterPanel, L["Has Heals"], "HasHeal", false)
boxHasHeal:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", col2X, startY - 22)

boxNeedDPS = CreateOakToggleBox(filterPanel, L["Need DPS"], "NeedDPS", true)
boxNeedDPS:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", col1X, startY - 44)

boxParty = CreateOakToggleBox(filterPanel, L["Party Fit"], "PartyFit", false)
boxParty:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", col2X, startY - 44)

boxLust = CreateOakToggleBox(filterPanel, L["Need Lust"], "NeedLust", false)
boxLust:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", col1X, startY - 66)

boxBrez = CreateOakToggleBox(filterPanel, L["Need BRez"], "NeedBrez", false)
boxBrez:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", col2X, startY - 66)

filterPanel.matchMyRaidLockoutBox = CreateOakToggleBox(filterPanel, L["Match My Lockout"], "MatchMyRaidLockout", false)
filterPanel.matchMyRaidLockoutBox:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", col1X, startY - 88)

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
nativeDungeonFilterScroll:SetPoint("BOTTOMRIGHT", filterPanel, "BOTTOMRIGHT", -6, 10)
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
        scrollBar:Hide()
        scrollBar:SetAlpha(0)
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

nativeNeedsTankBox = CreateStandaloneToggleBox(nativeDungeonFilterContent, L["Need Tank"])
nativeNeedsHealBox = CreateStandaloneToggleBox(nativeDungeonFilterContent, "Need Healer")
nativeNeedsDpsBox = CreateStandaloneToggleBox(nativeDungeonFilterContent, "Need Damage")
nativeNeedsMyClassBox = CreateStandaloneToggleBox(nativeDungeonFilterContent, "")
nativeNeedsMyClassBox.labelText:SetFontObject("OakLFG_FontSmall")
nativeNeedsMyClassBox.labelText:SetWidth(74)
nativeNeedsMyClassBox.labelText:SetWordWrap(false)
nativeNeedsMyClassBox.labelText:SetJustifyH("LEFT")
nativeHasTankBox = CreateStandaloneToggleBox(nativeDungeonFilterContent, L["Has Tank"])
nativeHasHealBox = CreateStandaloneToggleBox(nativeDungeonFilterContent, "Has Healer")
nativePartyBox = CreateStandaloneToggleBox(nativeDungeonFilterContent, L["Party Fit"])
nativeLustBox = CreateStandaloneToggleBox(nativeDungeonFilterContent, L["Need Lust"])
nativeBrezBox = CreateStandaloneToggleBox(nativeDungeonFilterContent, L["Need BRez"])

nativeMinimumRatingLabel = nativeDungeonFilterContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
nativeMinimumRatingLabel:SetText("Min Rating")
nativeMinimumRatingLabel:SetTextColor(classColor.r, classColor.g, classColor.b)

nativeMinimumRatingBox = CreateStandaloneNumberBox(nativeDungeonFilterContent, 56)

nativeActivityLabel = nativeDungeonFilterContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
nativeActivityLabel:SetText("Dungeons")
nativeActivityLabel:SetTextColor(classColor.r, classColor.g, classColor.b)
nativeActivityLabel:SetFontObject("OakLFG_FontSmall")
nativeDungeonFilterContent.activityGroupCache = nativeDungeonFilterContent.activityGroupCache or {}
nativeDungeonFilterContent.selectAllButton = CreateFlatButton(nativeDungeonFilterContent, "A", 14)
nativeDungeonFilterContent.selectAllButton.text:SetFontObject("OakLFG_FontSmall")
nativeDungeonFilterContent.selectAllButton.text:SetText("A")
nativeDungeonFilterContent.selectNoneButton = CreateFlatButton(nativeDungeonFilterContent, "N", 14)
nativeDungeonFilterContent.selectNoneButton.text:SetFontObject("OakLFG_FontSmall")
nativeDungeonFilterContent.selectNoneButton.text:SetText("N")
nativeDungeonFilterContent.selectAllButton:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Select All", 1, 1, 1)
    GameTooltip:AddLine("Select every dungeon in this list.", 1, 1, 1, true)
    GameTooltip:Show()
end)
nativeDungeonFilterContent.selectAllButton:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)
nativeDungeonFilterContent.selectNoneButton:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Select None", 1, 1, 1)
    GameTooltip:AddLine("Clear every dungeon in this list.", 1, 1, 1, true)
    GameTooltip:Show()
end)
nativeDungeonFilterContent.selectNoneButton:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)

nativeDungeonFilterContent.scoreHeader = nativeDungeonFilterContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
nativeDungeonFilterContent.scoreHeader:SetText("Gives Score")
nativeDungeonFilterContent.scoreHeader:SetTextColor(0.40, 1.00, 0.55)
nativeDungeonFilterContent.scoreHeader:SetJustifyH("RIGHT")
nativeDungeonFilterContent.scoreHeaderHitbox = CreateFrame("Button", nil, nativeDungeonFilterContent)
nativeDungeonFilterContent.scoreHeaderHitbox:SetSize(62, 16)
nativeDungeonFilterContent.scoreHeaderHitbox:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Gives Score", 1, 1, 1)
    GameTooltip:AddLine("Shows the lowest timed key level that should increase your score for that dungeon, plus the estimated score gain.", 1, 1, 1, true)
    GameTooltip:Show()
end)
nativeDungeonFilterContent.scoreHeaderHitbox:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
nativeDungeonFilterContent.selectAllButton:SetScript("OnClick", function()
    local activityIDs = {}
    for _, entry in ipairs(GetNativeDungeonActivityEntries()) do
        local groupID = tonumber(entry.groupID)
        local key = GetPendingNativeActivityKey(entry.label)
        if key ~= "" then
            pendingNativeActivitySelections[key] = true
        end
        if groupID and groupID > 0 then
            table.insert(activityIDs, groupID)
        end
    end
    table.sort(activityIDs)
    SaveAdvancedSearchFilter(function(state)
        state.activities = activityIDs
    end)
end)
nativeDungeonFilterContent.selectNoneButton:SetScript("OnClick", function()
    wipe(pendingNativeActivitySelections)
    SaveAdvancedSearchFilter(function(state)
        state.activities = {}
    end)
end)

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
scrollFrame:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", 10, SEARCH_SCROLL_TOP_Y)
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
    if self:IsShown() and addonTable.ClampFrameToScreen then
        addonTable.ClampFrameToScreen(self, OakLFGSorterDB, "searchFramePos")
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
local SEARCH_REGION_WIDTH = 42

local SEARCH_LAYOUT_EXPANDED = {
    dungeonX = 15, dungeonWidth = 145,
    setupX = 165, setupWidth = 98,
    titleX = 267, titleWidth = 98,
    modeX = nil, modeWidth = 0,
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
    modeX = nil, modeWidth = 0,
    ratingX = 370, ratingWidth = 65,
    ageX = 440, ageWidth = 35,
    notesX = 482, notesWidth = SEARCH_NOTE_COLLAPSED_WIDTH,
    roleStartX = 177,
    roleSummaryX = {175, 205, 235},
}

local SEARCH_LAYOUT_EXPANDED_RAID = {
    dungeonX = 15, dungeonWidth = 132,
    modeX = 151, modeWidth = 56,
    setupX = 211, setupWidth = 92,
    titleX = 307, titleWidth = 86,
    ratingX = 397, ratingWidth = 30,
    ageX = 431, ageWidth = 35,
    notesX = 471, notesWidth = SEARCH_NOTE_FULL_WIDTH,
    roleStartX = 222,
    roleSummaryX = {220, 248, 276},
}

local SEARCH_LAYOUT_COLLAPSED_RAID = {
    dungeonX = 15, dungeonWidth = 132,
    modeX = 151, modeWidth = 56,
    setupX = 211, setupWidth = 92,
    titleX = 307, titleWidth = 86,
    ratingX = 397, ratingWidth = 30,
    ageX = 431, ageWidth = 35,
    notesX = 473, notesWidth = SEARCH_NOTE_COLLAPSED_WIDTH,
    roleStartX = 222,
    roleSummaryX = {220, 248, 276},
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

local function UpdateSearchRegionDisplay(row, layout)
    if not (row and row.regionText and row.dungeonText) then
        return
    end

    local regionBadge = addonTable.GetRegionBadgeMarkup and addonTable.GetRegionBadgeMarkup(row.groupData and row.groupData.regionInfo) or ""
    row.regionText:ClearAllPoints()
    row.regionText:SetPoint("TOPRIGHT", row, "LEFT", layout.dungeonX + layout.dungeonWidth - SEARCH_ROW_X_OFFSET - 2, -2)
    row.regionText:SetWidth(SEARCH_REGION_WIDTH)
    row.regionText:SetJustifyH("RIGHT")

    if regionBadge ~= "" then
        row.regionText:SetText(regionBadge)
        row.regionText:Show()
        row.dungeonText:SetWidth(math.max(40, layout.dungeonWidth - SEARCH_REGION_WIDTH - 4))
    else
        row.regionText:SetText("")
        row.regionText:Hide()
        row.dungeonText:SetWidth(layout.dungeonWidth)
    end
end

nativeSearchHost.ShouldHostNativeSearchBox = function()
    return SearchModeUsesHostedSearch(currentSearchMode)
end

local function GetCollapsedSearchActionCenterX(layout)
    return layout.notesX + math.floor(layout.notesWidth / 2) - SEARCH_ROW_X_OFFSET
end

local function SearchUsesRaidColumns()
    return currentSearchMode == "raid" or currentSearchMode == "legacy_raid"
end

local function GetSearchLayout()
    if SearchUsesRaidColumns() then
        if OakLFGSorterDB and OakLFGSorterDB.searchHideNotes then
            return SEARCH_LAYOUT_COLLAPSED_RAID
        end
        return SEARCH_LAYOUT_EXPANDED_RAID
    end

    if OakLFGSorterDB and OakLFGSorterDB.searchHideNotes then
        return SEARCH_LAYOUT_COLLAPSED
    end
    return SEARCH_LAYOUT_EXPANDED
end

local function GetPinnedRowPriority(group)
    local priority = 0
    if group.isRoleFilled then
        priority = priority + 200
    end
    if group.isApplied then
        priority = priority + 100
    end
    if group.isFriend then
        priority = priority + 50
    end
    return priority
end

local function GetRaidDungeonSortKey(grp)
    local raidName = tostring((grp and grp.dungeon) or (grp and grp.activityFilterLabel) or (grp and grp.activityName) or "--")
    local difficultyLabel = tostring((grp and grp.raidListing and grp.raidListing.difficultyLabel) or "")
    return string.lower(raidName .. "\t" .. difficultyLabel)
end

local function GetRaidDifficultySortKey(grp)
    local token = tostring((grp and grp.difficultyToken) or "")
    local tokenOrder = {
        NORMAL = 1,
        HEROIC = 2,
        MYTHIC = 3,
    }

    local baseOrder = tokenOrder[token] or tonumber(grp and grp.difficulty) or 0
    local label = tostring((grp and grp.raidListing and grp.raidListing.difficultyLabel) or token or "")
    return string.format("%03d\t%s", baseOrder, string.lower(label))
end

local function SortGroups(grpA, grpB, sortBy, isAscending)
    local priorityA = GetPinnedRowPriority(grpA)
    local priorityB = GetPinnedRowPriority(grpB)
    if priorityA ~= priorityB then
        return priorityA > priorityB
    end

    local valA, valB
    if sortBy == "dungeon" then
        if grpA.mode == "raid" or grpA.mode == "legacy_raid" or grpB.mode == "raid" or grpB.mode == "legacy_raid" then
            valA, valB = GetRaidDungeonSortKey(grpA), GetRaidDungeonSortKey(grpB)
        else
            valA, valB = grpA.dungeon, grpB.dungeon
        end
    elseif sortBy == "mode" then
        if grpA.mode == "raid" or grpA.mode == "legacy_raid" or grpB.mode == "raid" or grpB.mode == "legacy_raid" then
            valA, valB = GetRaidDifficultySortKey(grpA), GetRaidDifficultySortKey(grpB)
        else
            valA, valB = grpA.mode or "", grpB.mode or ""
        end
    elseif sortBy == "title" then valA, valB = grpA.titleStr or "", grpB.titleStr or ""
    elseif sortBy == "rating" then
        if grpA.mode == "raid" or grpA.mode == "legacy_raid" or grpB.mode == "raid" or grpB.mode == "legacy_raid" then
            valA = tonumber(grpA.raidListing and grpA.raidListing.bossesKilled) or 0
            valB = tonumber(grpB.raidListing and grpB.raidListing.bossesKilled) or 0
        else
            valA, valB = grpA.rating, grpB.rating
        end
    elseif sortBy == "age" then valA, valB = grpA.age, grpB.age
    elseif sortBy == "note" then valA, valB = grpA.commentStr or "", grpB.commentStr or ""
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
local modeHeader
local ratingHeader
local ageHeader
local notesHeader
local notesVisibilityBtn

function OAK_SEARCH.UpdateHeaderVisuals()
    if dungeonHeader then
        if currentSearchMode == "raid" or currentSearchMode == "legacy_raid" then
            dungeonHeader.baseText = L["Raid"]
        elseif currentSearchMode == "rated_pvp" or currentSearchMode == "pvp" or currentSearchMode == "open_world" then
            dungeonHeader.baseText = "Activity"
        else
            dungeonHeader.baseText = L["Dungeon"]
        end
    end

    if ratingHeader then
        if currentSearchMode == "rated_pvp" or currentSearchMode == "pvp" then
            ratingHeader.baseText = "PVP Rating"
        elseif currentSearchMode == "raid" or currentSearchMode == "legacy_raid" then
            ratingHeader.baseText = L["Kills"]
        else
            ratingHeader.baseText = L["Rating"]
        end
    end

    if modeHeader then
        modeHeader.baseText = SearchUsesRaidColumns() and L["Difficulty"] or ""
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
    btn:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", xOffset, SEARCH_COLUMN_HEADER_Y)
    btn:SetBackdrop({bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1})
    btn:SetBackdropColor(unpack(OAK_COLOR_PANE))
    btn:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))
    btn:EnableMouse(true)
    btn:SetFrameLevel(OAK_SEARCH:GetFrameLevel() + 10)
    btn.baseText = label; btn.sortKey = sortKey
    btn.text = btn:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    btn.text:SetPoint("CENTER"); btn.text:SetText(label)

    local function HandleClick()
        if sortKey ~= "none" then
            if currentSortBy == sortKey then currentIsAscending = not currentIsAscending
            else currentSortBy = sortKey; currentIsAscending = false end
            OAK_SEARCH.UpdateHeaderVisuals(); OAK_SEARCH:UpdateDisplay()
        end
    end

    local function HandleEnter(self)
        local title, description = addonTable.GetSearchHeaderTooltipData and addonTable.GetSearchHeaderTooltipData(self.sortKey, currentSearchMode)
        if title and description then
            btn:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(title, 1, 1, 1)
            GameTooltip:AddLine(description, 1, 1, 1, true)
            GameTooltip:AddLine("Click to sort. Click again to reverse the order.", 0.75, 0.75, 0.75, true)
            GameTooltip:Show()
        end
    end

    local function HandleLeave()
        btn:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))
        GameTooltip:Hide()
    end

    btn:SetScript("OnClick", HandleClick)
    btn:SetScript("OnEnter", HandleEnter)
    btn:SetScript("OnLeave", HandleLeave)

    btn.hitbox = CreateFrame("Button", nil, OAK_SEARCH)
    btn.hitbox:SetAllPoints(btn)
    btn.hitbox:SetFrameStrata("DIALOG")
    btn.hitbox:SetFrameLevel(btn:GetFrameLevel() + 5)
    btn.hitbox:EnableMouse(true)
    btn.hitbox.sortKey = sortKey
    btn.hitbox:SetScript("OnClick", HandleClick)
    btn.hitbox:SetScript("OnEnter", HandleEnter)
    btn.hitbox:SetScript("OnLeave", HandleLeave)
    table.insert(headers, btn)
    return btn
end

dungeonHeader = CreateHeader(L["Dungeon"], "dungeon", SEARCH_LAYOUT_EXPANDED.dungeonWidth, SEARCH_LAYOUT_EXPANDED.dungeonX)
setupHeader = CreateHeader(L["Comp"], "members", SEARCH_LAYOUT_EXPANDED.setupWidth, SEARCH_LAYOUT_EXPANDED.setupX)
titleHeader = CreateHeader(L["Title"], "title", SEARCH_LAYOUT_EXPANDED.titleWidth, SEARCH_LAYOUT_EXPANDED.titleX)
modeHeader = CreateHeader("Mode", "mode", 1, SEARCH_LAYOUT_EXPANDED.titleX + SEARCH_LAYOUT_EXPANDED.titleWidth + 4)
ratingHeader = CreateHeader(L["Rating"], "rating", SEARCH_LAYOUT_EXPANDED.ratingWidth, SEARCH_LAYOUT_EXPANDED.ratingX)
ageHeader = CreateHeader(L["Age"], "age", SEARCH_LAYOUT_EXPANDED.ageWidth, SEARCH_LAYOUT_EXPANDED.ageX)

local notesToggleBtn = CreateFlatButton(OAK_SEARCH, L["Notes"], SEARCH_NOTE_FULL_WIDTH)
notesToggleBtn:SetHeight(22)
notesToggleBtn:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", SEARCH_LAYOUT_EXPANDED.notesX, SEARCH_COLUMN_HEADER_Y)
notesHeader = CreateHeader(L["Notes"], "note", SEARCH_NOTE_FULL_WIDTH - 24, SEARCH_LAYOUT_EXPANDED.notesX)
notesVisibilityBtn = CreateFlatButton(OAK_SEARCH, "-", 20)
notesVisibilityBtn:SetHeight(22)
notesToggleBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if OakLFGSorterDB.searchHideNotes then
        GameTooltip:SetText("Show Notes", 1, 1, 1)
        GameTooltip:AddLine("Expand the Notes column and restore the full search window width.", 1, 1, 1, true)
    else
        GameTooltip:SetText(L["Hide Notes"], 1, 1, 1)
        GameTooltip:AddLine(L["Collapse the Notes column to make the search window more compact."], 1, 1, 1, true)
    end
    GameTooltip:Show()
end)
notesToggleBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)
notesVisibilityBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L["Hide Notes"], 1, 1, 1)
    GameTooltip:AddLine(L["Collapse the Notes column to make the search window more compact."], 1, 1, 1, true)
    GameTooltip:Show()
end)
notesVisibilityBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)

local function UpdateSearchHeaderVisuals()
    local layout = GetSearchLayout()
    OAK_SEARCH.UpdateHeaderVisuals()
    dungeonHeader:SetWidth(layout.dungeonWidth)
    dungeonHeader:ClearAllPoints()
    dungeonHeader:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", layout.dungeonX, SEARCH_COLUMN_HEADER_Y)

    setupHeader:SetWidth(layout.setupWidth)
    setupHeader:ClearAllPoints()
    setupHeader:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", layout.setupX, SEARCH_COLUMN_HEADER_Y)

    titleHeader:SetWidth(layout.titleWidth)
    titleHeader:ClearAllPoints()
    titleHeader:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", layout.titleX, SEARCH_COLUMN_HEADER_Y)

    if modeHeader then
        if layout.modeWidth and layout.modeWidth > 0 and layout.modeX then
            modeHeader:SetWidth(layout.modeWidth)
            modeHeader:ClearAllPoints()
            modeHeader:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", layout.modeX, SEARCH_COLUMN_HEADER_Y)
            modeHeader:Show()
        else
            modeHeader:Hide()
        end
    end

    ratingHeader:SetWidth(layout.ratingWidth)
    ratingHeader:ClearAllPoints()
    ratingHeader:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", layout.ratingX, SEARCH_COLUMN_HEADER_Y)

    ageHeader:SetWidth(layout.ageWidth)
    ageHeader:ClearAllPoints()
    ageHeader:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", layout.ageX, SEARCH_COLUMN_HEADER_Y)

    if OakLFGSorterDB and OakLFGSorterDB.searchHideNotes then
        notesToggleBtn:SetWidth(layout.notesWidth)
        notesToggleBtn.text:SetText("Notes")
        notesToggleBtn:ClearAllPoints()
        notesToggleBtn:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", layout.notesX, SEARCH_COLUMN_HEADER_Y)
        notesToggleBtn:Show()
        notesHeader:Hide()
        if notesHeader.hitbox then
            notesHeader.hitbox:Hide()
        end
        notesVisibilityBtn:Hide()
    else
        local headerWidth = math.max(40, layout.notesWidth - 24)
        notesHeader:SetWidth(headerWidth)
        notesHeader:ClearAllPoints()
        notesHeader:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", layout.notesX, SEARCH_COLUMN_HEADER_Y)
        notesHeader:Show()
        notesVisibilityBtn:SetWidth(20)
        notesVisibilityBtn.text:SetText("-")
        notesVisibilityBtn:ClearAllPoints()
        notesVisibilityBtn:SetPoint("TOPLEFT", notesHeader, "TOPRIGHT", 4, 0)
        notesVisibilityBtn:Show()
        notesToggleBtn:Hide()
    end

    for _, header in ipairs(headers) do
        if header.hitbox then
            header.hitbox:ClearAllPoints()
            header.hitbox:SetAllPoints(header)
            if header:IsShown() then
                header.hitbox:Show()
            else
                header.hitbox:Hide()
            end
        end
    end
end

-- ==========================================
-- 6. Logic Helpers
-- ==========================================
local function GroupMatchesPartyFit(group)
    if addonTable.DoesResultFitCurrentParty then
        return addonTable.DoesResultFitCurrentParty(group)
    end
    return true
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

local function GetRaidEncounterListText(grp)
    local raidListing = grp and grp.raidListing
    if type(raidListing) ~= "table" then
        return nil
    end

    if type(raidListing.defeatedBossList) == "table" and #raidListing.defeatedBossList > 0 then
        return table.concat(raidListing.defeatedBossList, ", ")
    end

    if type(raidListing.defeatedBossNames) ~= "table" then
        return nil
    end

    local names = {}
    for bossName in pairs(raidListing.defeatedBossNames) do
        table.insert(names, bossName)
    end
    table.sort(names)

    if #names == 0 then
        return nil
    end

    return table.concat(names, ", ")
end

local function GetRaidRowTitle(grp)
    local baseTitle = tostring(grp.displayTitle or grp.titleStr or "")
    if baseTitle == "" then
        return "--"
    end

    return baseTitle
end

local function GetRaidDungeonDisplay(grp)
    local raidName = tostring((grp and grp.dungeon) or "")
    if raidName == "" then
        raidName = tostring((grp and grp.activityFilterLabel) or (grp and grp.activityName) or "--")
    end
    raidName = raidName:gsub("%s*%((Normal|Heroic|Mythic)%)$", "")
    return raidName ~= "" and raidName or "--"
end

local function GetColoredRaidDifficultyLabel(label)
    local text = tostring(label or "")
    local lowered = strlower(text)
    if lowered == "normal" then
        return "|cff0070dd" .. text .. "|r"
    elseif lowered == "heroic" then
        return "|cffa335ee" .. text .. "|r"
    elseif lowered == "mythic" then
        return "|cffff8000" .. text .. "|r"
    end
    return text
end

local function GetRaidModeDisplay(grp)
    local difficultyLabel = grp and grp.raidListing and grp.raidListing.difficultyLabel or nil
    if type(difficultyLabel) ~= "string" or difficultyLabel == "" then
        return "--"
    end
    return GetColoredRaidDifficultyLabel(difficultyLabel)
end

local function GetRaidKillsDisplay(grp)
    local raidListing = grp and grp.raidListing
    if type(raidListing) ~= "table" then
        return "--"
    end

    if raidListing.progressText and raidListing.progressText ~= "" and raidListing.progressText ~= "--" then
        return raidListing.progressText
    end

    if raidListing.bossesKilled ~= nil then
        return tostring(tonumber(raidListing.bossesKilled) or 0)
    end

    return "--"
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

local function NormalizeScoreTargetLabel(label)
    local normalized = strlower(GetRaidFilterLabel({ fullName = tostring(label or "") }))
    normalized = normalized:gsub("[^%w%s]", " ")
    normalized = normalized:gsub("%s+", " ")
    normalized = normalized:gsub("^%s+", ""):gsub("%s+$", "")
    return normalized
end

local function GetLocalizedSeasonDungeonLabels()
    if not (C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapUIInfo) then
        return DEFAULT_SEASON_DUNGEONS
    end

    local labels = {}
    local seen = {}
    local mapIDs = C_ChallengeMode.GetMapTable()
    if type(mapIDs) ~= "table" then
        return DEFAULT_SEASON_DUNGEONS
    end

    for _, mapID in ipairs(mapIDs) do
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        local cleanName = GetRaidFilterLabel({ fullName = name })
        local key = NormalizeScoreTargetLabel(cleanName)
        if cleanName ~= "" and key ~= "" and not seen[key] then
            seen[key] = true
            table.insert(labels, cleanName)
        end
    end

    if #labels > 0 then
        return labels
    end

    return DEFAULT_SEASON_DUNGEONS
end

addonTable.GetSearchHeaderTooltipData = function(sortKey, mode)
    if sortKey == "dungeon" then
        if mode == "raid" or mode == "legacy_raid" then
            return "Raid", "Sort by raid name."
        elseif mode == "rated_pvp" or mode == "pvp" then
            return "Activity", "Sort by activity or bracket."
        end
        return "Dungeon", "Sort by dungeon or activity name."
    elseif sortKey == "members" then
        return "Comp", "Sort by party setup and group composition."
    elseif sortKey == "title" then
        return "Title", "Sort by the listing title shown by the group leader."
    elseif sortKey == "mode" then
        return "Difficulty", "Sort by the raid difficulty on the listing."
    elseif sortKey == "rating" then
        if mode == "raid" or mode == "legacy_raid" then
            return "Kills", "Sort by the number of bosses already defeated in the listed raid."
        elseif mode == "rated_pvp" or mode == "pvp" then
            return "PVP Rating", "Sort by the leader's PVP rating."
        end
        return "Rating", "Sort by the leader's Mythic+ rating."
    elseif sortKey == "age" then
        return L["Age"], L["Sort by how long ago the listing was created."]
    elseif sortKey == "note" then
        return L["Notes"], L["Sort by the listing note text."]
    end
    return nil, nil
end

addonTable.GetSearchGroupFriendNames = function(group)
    local names = {}
    local seen = {}
    local playerNames = {}

    local function AddPlayerNameVariants(name)
        local text = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if text == "" then
            return
        end
        local lowered = strlower(text)
        playerNames[lowered] = text
        local short = lowered:match("^([^%-]+)")
        if short and short ~= "" then
            playerNames[short] = text
        end
    end

    for _, member in ipairs(group and group.memberDetails or {}) do
        AddPlayerNameVariants(member.name)
    end

    if next(playerNames) == nil then
        return names
    end

    local function AddMatchedName(name)
        local lowered = strlower(tostring(name or ""))
        if lowered == "" then
            return
        end
        local matched = playerNames[lowered] or playerNames[(lowered:match("^([^%-]+)") or "")]
        if matched and not seen[matched] then
            seen[matched] = true
            table.insert(names, matched)
        end
    end

    if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
        for friendIndex = 1, C_FriendList.GetNumFriends() or 0 do
            local info = C_FriendList.GetFriendInfoByIndex(friendIndex)
            if type(info) == "table" then
                AddMatchedName(info.name)
            end
        end
    elseif GetNumFriends and GetFriendInfo then
        for friendIndex = 1, GetNumFriends() or 0 do
            AddMatchedName((GetFriendInfo(friendIndex)))
        end
    end

    if IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo then
        for guildIndex = 1, GetNumGuildMembers() or 0 do
            AddMatchedName((GetGuildRosterInfo(guildIndex)))
        end
    end

    if C_BattleNet and C_BattleNet.GetFriendAccountInfo and BNGetNumFriends then
        for friendIndex = 1, BNGetNumFriends() or 0 do
            local accountInfo = C_BattleNet.GetFriendAccountInfo(friendIndex)
            if type(accountInfo) == "table" then
                local gameAccountInfo = accountInfo.gameAccountInfo
                if type(gameAccountInfo) == "table" then
                    AddMatchedName(gameAccountInfo.characterName)
                    if gameAccountInfo.characterName and gameAccountInfo.realmName then
                        AddMatchedName(gameAccountInfo.characterName .. "-" .. gameAccountInfo.realmName)
                    end
                end
                if type(accountInfo.gameAccountInfos) == "table" then
                    for _, altGameAccount in ipairs(accountInfo.gameAccountInfos) do
                        if type(altGameAccount) == "table" then
                            AddMatchedName(altGameAccount.characterName)
                            if altGameAccount.characterName and altGameAccount.realmName then
                                AddMatchedName(altGameAccount.characterName .. "-" .. altGameAccount.realmName)
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(names)
    return names
end

addonTable.GetMythicPlusScoreTargets = function()
    if not (C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapUIInfo and C_MythicPlus and C_MythicPlus.GetSeasonBestAffixScoreInfoForMap) then
        return {}
    end

    if C_MythicPlus.RequestMapInfo then
        pcall(C_MythicPlus.RequestMapInfo)
    end

    local function GetRatingCalcValues()
        local seasonCalcValues = {
            [11] = {
                baseRating = 20,
                firstAffixLevel = 2,
                fistAffixValue = 10,
                secondAffixLevel = 7,
                secondAffixValue = 10,
                thirdAffixLevel = 14,
                thirdAffixValue = 10,
                thresholdLevel = 10,
                preThresholdValue = 5,
                postThresholdValue = 7,
            },
            [12] = {
                baseRating = 70,
                firstAffixLevel = 2,
                fistAffixValue = 10,
                secondAffixLevel = 5,
                secondAffixValue = 10,
                thirdAffixLevel = 10,
                thirdAffixValue = 10,
                thresholdLevel = 1,
                preThresholdValue = 7,
                postThresholdValue = 7,
            },
            [13] = {
                baseRating = 120,
                firstAffixLevel = 2,
                fistAffixValue = 15,
                secondAffixLevel = 4,
                secondAffixValue = 10,
                thirdAffixLevel = 7,
                thirdAffixValue = 15,
                fourthAffixLevel = 10,
                fourthAffixValue = 10,
                fifthAffixLevel = 12,
                fifthAffixValue = 15,
                thresholdLevel = 1,
                preThresholdValue = 15,
                postThresholdValue = 15,
            },
            [14] = {
                baseRating = 125,
                firstAffixLevel = 4,
                fistAffixValue = 15,
                secondAffixLevel = 7,
                secondAffixValue = 15,
                thirdAffixLevel = 10,
                thirdAffixValue = 15,
                fourthAffixLevel = 12,
                fourthAffixValue = 15,
                fifthAffixLevel = 12,
                fifthAffixValue = 0,
                thresholdLevel = 1,
                preThresholdValue = 15,
                postThresholdValue = 15,
            },
        }

        local currentSeason = tonumber(C_MythicPlus.GetCurrentSeason and C_MythicPlus.GetCurrentSeason()) or 0
        if seasonCalcValues[currentSeason] then
            return seasonCalcValues[currentSeason]
        end

        local fallbackSeason = 0
        for seasonID in pairs(seasonCalcValues) do
            if seasonID > fallbackSeason then
                fallbackSeason = seasonID
            end
        end
        return seasonCalcValues[fallbackSeason]
    end

    local seasonVars = GetRatingCalcValues()
    if not seasonVars then
        return {}
    end

    local function GetTimedRunScore(level)
        level = tonumber(level) or 0
        if level < 2 then
            return 0
        end

        local baseRating = seasonVars.baseRating
        local firstRating
        if level >= seasonVars.thresholdLevel then
            firstRating = seasonVars.thresholdLevel * seasonVars.preThresholdValue
        else
            firstRating = level * seasonVars.preThresholdValue
        end

        local secondRating = 0
        if level > seasonVars.thresholdLevel then
            secondRating = (level - seasonVars.thresholdLevel) * seasonVars.postThresholdValue
        end

        local affixScore = 0
        if level >= seasonVars.firstAffixLevel then
            affixScore = affixScore + seasonVars.fistAffixValue
        end
        if level >= seasonVars.secondAffixLevel then
            affixScore = affixScore + seasonVars.secondAffixValue
        end
        if level >= seasonVars.thirdAffixLevel then
            affixScore = affixScore + seasonVars.thirdAffixValue
        end
        if seasonVars.fourthAffixLevel and seasonVars.fourthAffixValue and level >= seasonVars.fourthAffixLevel then
            affixScore = affixScore + seasonVars.fourthAffixValue
        end
        if seasonVars.fifthAffixLevel and seasonVars.fifthAffixValue and level >= seasonVars.fifthAffixLevel then
            affixScore = affixScore + seasonVars.fifthAffixValue
        end

        return baseRating + firstRating + secondRating + affixScore
    end

    local function BuildEstimatedScoreGain(baseLevel, currentOverall)
        local level = tonumber(baseLevel)
        if not level or level <= 0 then
            return nil
        end

        local timedScore = GetTimedRunScore(level)
        local twoChestScore = GetTimedRunScore(math.min(30, level + 1))
        local threeChestScore = GetTimedRunScore(math.min(30, level + 2))

        return {
            timed = math.max(1, math.floor((timedScore - currentOverall) + 0.5)),
            plusTwo = math.max(1, math.floor((twoChestScore - currentOverall) + 0.5)),
            plusThree = math.max(1, math.floor((threeChestScore - currentOverall) + 0.5)),
        }
    end

    local targets = {}
    local mapIDs = C_ChallengeMode.GetMapTable() or {}
    local missingMapNames = false
    local missingMapData = #mapIDs == 0

    for _, mapID in ipairs(mapIDs) do
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        if not name or name == "" then
            missingMapNames = true
        end

        local labelKey = NormalizeScoreTargetLabel(name)
        if labelKey ~= "" then
            local mapScores, bestOverallScore = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(mapID)
            local currentOverall = tonumber(bestOverallScore) or 0

            if currentOverall <= 0 and type(mapScores) == "table" then
                for _, info in ipairs(mapScores) do
                    if type(info) == "table" then
                        currentOverall = math.max(currentOverall, tonumber(info.score) or 0)
                    end
                end
            end

            local targetLevel
            for level = 2, 30 do
                if GetTimedRunScore(level) > currentOverall then
                    targetLevel = level
                    break
                end
            end

            if targetLevel then
                local targetScore = GetTimedRunScore(targetLevel)
                local estimatedGain = BuildEstimatedScoreGain(targetLevel, currentOverall)
                targets[labelKey] = {
                    level = targetLevel,
                    estimatedGain = estimatedGain and estimatedGain.timed or nil,
                    estimatedGainBreakdown = estimatedGain,
                    projectedScore = targetScore,
                    currentScore = currentOverall,
                }
            else
                targets[labelKey] = nil
            end
        end
    end

    if next(targets) == nil and (missingMapNames or missingMapData) and not addonTable.PendingScoreTargetRefresh then
        addonTable.PendingScoreTargetRefresh = true
        C_Timer.After(0.5, function()
            addonTable.PendingScoreTargetRefresh = false
            if OAK_SEARCH and OAK_SEARCH:IsShown() then
                if UpdateSearchFilterPane then
                    UpdateSearchFilterPane()
                end
                if OAK_SEARCH.UpdateDisplay then
                    OAK_SEARCH:UpdateDisplay()
                end
            end
        end)
    end

    return targets
end

local function SearchModeShowsScoreTargets(mode)
    return mode == "mythic_plus" or mode == "dungeon"
end

local function GetSearchFilterLabel(mode, activityInfo, pvpBracket)
    if mode == "rated_pvp" or mode == "pvp" then
        return pvpBracket or GetRaidFilterLabel(activityInfo)
    end
    return GetRaidFilterLabel(activityInfo)
end

local function GetNeedsMyClassLabel()
    local _, classToken = UnitClass("player")
    local pluralLabel = ({
        DEATHKNIGHT = "DKs",
        DEMONHUNTER = "DHs",
        DRUID = "Druids",
        EVOKER = "Evokers",
        HUNTER = "Hunters",
        MAGE = "Mages",
        MONK = "Monks",
        PALADIN = "Pallies",
        PRIEST = "Priests",
        ROGUE = "Rogues",
        SHAMAN = "Shamans",
        WARLOCK = "Warlocks",
        WARRIOR = "Warriors",
    })[classToken or ""]
    if pluralLabel and pluralLabel ~= "" then
        return "No " .. pluralLabel
    end

    return "No class dupes"
end

GetNativeDungeonActivityEntries = function()
    local entries = {}
    local seen = {}
    local defaultOrder = {}
    local cachedGroups = nativeDungeonFilterContent and nativeDungeonFilterContent.activityGroupCache or {}
    local scoreTargets = SearchModeShowsScoreTargets(currentSearchMode) and addonTable.GetMythicPlusScoreTargets and addonTable.GetMythicPlusScoreTargets() or nil
    local defaultSeasonDungeons = GetLocalizedSeasonDungeonLabels()

    if currentSearchMode == "mythic_plus" or currentSearchMode == "dungeon" then
        for index, label in ipairs(defaultSeasonDungeons) do
            local normalizedLabel = NormalizeScoreTargetLabel(label)
            defaultOrder[normalizedLabel] = index
            seen[normalizedLabel] = {
                label = label,
                groupID = cachedGroups[normalizedLabel],
                scoreTarget = scoreTargets and scoreTargets[normalizedLabel] or nil,
            }
            table.insert(entries, seen[normalizedLabel])
        end
    end

    local context = addonTable.UpdateSearchContext and addonTable.UpdateSearchContext() or nil
    local categoryID = context and (context.categoryID or context.selectedCategoryID) or nil
    local groupID = context and context.groupID or nil
    if categoryID and groupID and C_LFGList and C_LFGList.GetAvailableActivities then
        local success, activityIDs = pcall(C_LFGList.GetAvailableActivities, categoryID, groupID, Enum and Enum.LFGListFilter and Enum.LFGListFilter.CurrentSeason or 0x40)
        if success and type(activityIDs) == "table" then
            for _, activityID in ipairs(activityIDs) do
                local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
                local label = GetRaidFilterLabel(activityInfo)
                local key = NormalizeScoreTargetLabel(label)
                local resolvedGroupID = tonumber(activityInfo and (activityInfo.groupFinderActivityGroupID or activityInfo.groupID)) or 0
                if key ~= "" and resolvedGroupID > 0 then
                    cachedGroups[key] = resolvedGroupID
                    if seen[key] then
                        seen[key].groupID = seen[key].groupID or resolvedGroupID
                    else
                        local entry = {
                            label = label,
                            groupID = resolvedGroupID,
                            scoreTarget = scoreTargets and scoreTargets[key] or nil,
                        }
                        seen[key] = entry
                        table.insert(entries, entry)
                    end
                end
            end
        end
    end

    for _, group in ipairs(searchResults) do
        if group.mode == "mythic_plus" or group.mode == "dungeon" then
            local label = GetRaidFilterLabel({ fullName = group.filterLabel })
            local key = NormalizeScoreTargetLabel(label)
            if key ~= "" then
                local groupID = tonumber(group.activityGroupID)
                if groupID and groupID > 0 then
                    cachedGroups[key] = groupID
                end
                local existing = seen[key]
                if existing then
                    if not existing.groupID and cachedGroups[key] then
                        existing.groupID = cachedGroups[key]
                    end
                else
                    local entry = {
                        label = label,
                        groupID = cachedGroups[key] or group.activityGroupID,
                        scoreTarget = scoreTargets and scoreTargets[key] or nil,
                    }
                    seen[key] = entry
                    table.insert(entries, entry)
                end
            end
        end
    end

    table.sort(entries, function(a, b)
        local aKey = NormalizeScoreTargetLabel(a.label)
        local bKey = NormalizeScoreTargetLabel(b.label)
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
    OAK_F.MatchMyRaidLockout = false
    OAK_F.RaidBossesRange = ""
    OAK_F.RaidTankRange = ""
    OAK_F.RaidHealerRange = ""
    OAK_F.RaidDpsRange = ""
    wipe(pendingNativeActivitySelections)

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
        adv.difficultyNormal = nil
        adv.difficultyHeroic = nil
        adv.difficultyMythic = nil
        adv.difficultyMythicPlus = nil
        C_LFGList.SaveAdvancedFilter(adv)
    end

    if UpdateSearchFilterPane then
        UpdateSearchFilterPane()
    end
    if OAK_SEARCH and OAK_SEARCH.UpdateDisplay then
        OAK_SEARCH:UpdateDisplay()
    end
end

local function ParseRaidBossRangeExpression(text)
    local raw = tostring(text or "")
    raw = raw:gsub("%s+", "")
    if raw == "" then
        return nil, nil
    end

    local minValue, maxValue
    local startRange, endRange = raw:match("^(%-?%d+)%-(%-?%d+)$")
    if startRange and endRange then
        minValue = tonumber(startRange)
        maxValue = tonumber(endRange)
        if minValue and maxValue and minValue > maxValue then
            minValue, maxValue = maxValue, minValue
        end
        return minValue, maxValue
    end

    local lowerOnly = raw:match("^<(%-?%d+)$")
    if lowerOnly then
        return nil, tonumber(lowerOnly) - 1
    end

    local greaterOnly = raw:match("^>(%-?%d+)$")
    if greaterOnly then
        return tonumber(greaterOnly) + 1, nil
    end

    local exact = tonumber(raw)
    if exact then
        return exact, exact
    end

    return nil, nil
end

local function ParseMinimumFriendlyRangeExpression(text)
    local raw = tostring(text or "")
    raw = raw:gsub("%s+", "")
    if raw == "" then
        return nil, nil
    end

    local minValue, maxValue = ParseRaidBossRangeExpression(raw)
    if raw:match("^%-?%d+$") then
        return tonumber(raw), nil
    end

    return minValue, maxValue
end

local function ResultMatchesNumericRange(value, expression, bareNumberMeansMinimum)
    local minValue, maxValue
    if bareNumberMeansMinimum then
        minValue, maxValue = ParseMinimumFriendlyRangeExpression(expression)
    else
        minValue, maxValue = ParseRaidBossRangeExpression(expression)
    end
    if minValue and value < minValue then
        return false
    end
    if maxValue and value > maxValue then
        return false
    end
    return true
end

local function UpdateNativeDungeonFilterPane(topOffset)
    local adv = GetAdvancedSearchFilter()
    local selectedActivities = {}
    local y = -4
    local showPGFWarning = IsPGFDetected()

    nativeDungeonFilterScroll:ClearAllPoints()
    nativeDungeonFilterScroll:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 10, topOffset)
    nativeDungeonFilterScroll:SetPoint("BOTTOMRIGHT", filterPanel, "BOTTOMRIGHT", -6, 10)

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
        entry.box:SetPoint("TOPLEFT", nativeDungeonFilterContent, "TOPLEFT", entry.x, y - (entry.row * 20))
        entry.box:SetState(entry.active)
        entry.box:Show()
        if entry.box.labelText then
            entry.box.labelText:Show()
        end
    end
    y = y - 62

    nativeMinimumRatingLabel:ClearAllPoints()
    nativeMinimumRatingLabel:SetPoint("TOPLEFT", nativeDungeonFilterContent, "TOPLEFT", 5, y - 2)
    nativeMinimumRatingLabel:Show()
    nativeMinimumRatingBox:ClearAllPoints()
    nativeMinimumRatingBox:SetPoint("TOPRIGHT", nativeDungeonFilterContent, "TOPRIGHT", -8, y + 2)
    nativeMinimumRatingBox:SetText((tonumber(adv.minimumRating) or 0) > 0 and tostring(math.floor(adv.minimumRating)) or "")
    nativeMinimumRatingBox:Show()
    y = y - 24

    local localUtilityControls = {
        { box = nativePartyBox, active = OAK_F.PartyFit, x = 5, row = 0 },
        { box = nativeLustBox, active = OAK_F.NeedLust, x = 95, row = 0 },
        { box = nativeBrezBox, active = OAK_F.NeedBrez, x = 5, row = 1 },
    }

    for _, entry in ipairs(localUtilityControls) do
        entry.box:ClearAllPoints()
        entry.box:SetPoint("TOPLEFT", nativeDungeonFilterContent, "TOPLEFT", entry.x, y - (entry.row * 20))
        entry.box:SetState(entry.active)
        entry.box:Show()
        if entry.box.labelText then
            entry.box.labelText:Show()
        end
    end
    y = y - 40

    nativeActivityLabel:ClearAllPoints()
    nativeActivityLabel:SetPoint("TOPLEFT", nativeDungeonFilterContent, "TOPLEFT", 5, y)
    nativeActivityLabel:Show()
    nativeDungeonFilterContent.selectAllButton:ClearAllPoints()
    nativeDungeonFilterContent.selectAllButton:SetPoint("LEFT", nativeActivityLabel, "RIGHT", 28, 0)
    nativeDungeonFilterContent.selectAllButton:Show()
    nativeDungeonFilterContent.selectNoneButton:ClearAllPoints()
    nativeDungeonFilterContent.selectNoneButton:SetPoint("LEFT", nativeDungeonFilterContent.selectAllButton, "RIGHT", 3, 0)
    nativeDungeonFilterContent.selectNoneButton:Show()
    nativeDungeonFilterContent.scoreHeader:ClearAllPoints()
    nativeDungeonFilterContent.scoreHeader:SetPoint("TOPRIGHT", nativeDungeonFilterContent, "TOPRIGHT", -8, y)
    nativeDungeonFilterContent.scoreHeaderHitbox:ClearAllPoints()
    nativeDungeonFilterContent.scoreHeaderHitbox:SetPoint("TOPRIGHT", nativeDungeonFilterContent, "TOPRIGHT", -8, y + 2)
    if SearchModeShowsScoreTargets(currentSearchMode) then
        nativeDungeonFilterContent.scoreHeader:Show()
        nativeDungeonFilterContent.scoreHeaderHitbox:Show()
    else
        nativeDungeonFilterContent.scoreHeader:Hide()
        nativeDungeonFilterContent.scoreHeaderHitbox:Hide()
    end
    y = y - 14

    local activityEntries = GetNativeDungeonActivityEntries()
    for index, entry in ipairs(activityEntries) do
        local button = nativeDungeonActivityButtons[index]
        if not button then
            button = CreateStandaloneToggleBox(nativeDungeonFilterContent, "")
            button.labelText:SetFontObject("OakLFG_FontSmall")
            button.labelText:SetWidth(104)
            button.labelText:SetJustifyH("LEFT")
            button.scoreText = nativeDungeonFilterContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
            button.scoreText:SetWidth(48)
            button.scoreText:SetJustifyH("RIGHT")
            button.scoreHitbox = CreateFrame("Button", nil, nativeDungeonFilterContent)
            button.scoreHitbox:SetSize(52, 16)
            button.scoreHitbox:SetScript("OnEnter", function(self)
                local entryData = self.entryData
                if not entryData then
                    return
                end
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetText(entryData.label or "Gives Score", 1, 1, 1)
                local targetLevel = tonumber(entryData.scoreTarget and entryData.scoreTarget.level)
                local estimatedGain = tonumber(entryData.scoreTarget and entryData.scoreTarget.estimatedGain)
                local gainBreakdown = entryData.scoreTarget and entryData.scoreTarget.estimatedGainBreakdown
                if targetLevel and targetLevel > 0 then
                    if estimatedGain and estimatedGain > 0 then
                        GameTooltip:AddLine(string.format("A timed +%d should increase your score by about %d points for this dungeon.", targetLevel, estimatedGain), 0.40, 1.00, 0.55, true)
                    else
                        GameTooltip:AddLine(string.format("A timed +%d should increase your score for this dungeon.", targetLevel), 0.40, 1.00, 0.55, true)
                    end
                    if type(gainBreakdown) == "table" then
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine(string.format("+%d (%d)  ++%d (%d)  +++%d (%d)", targetLevel, tonumber(gainBreakdown.timed) or 0, targetLevel, tonumber(gainBreakdown.plusTwo) or 0, targetLevel, tonumber(gainBreakdown.plusThree) or 0), 0.75, 1.00, 0.80, true)
                    end
                else
                    GameTooltip:AddLine("Oak could not determine a score-gain target for this dungeon yet.", 1, 1, 1, true)
                end
                GameTooltip:Show()
            end)
            button.scoreHitbox:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            button:SetScript("OnClick", function(self)
                local pendingKey = GetPendingNativeActivityKey(self.entryLabel or "")
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
                if self.activityGroupID and self.activityGroupID > 0 then
                    isSelected = groups[self.activityGroupID] == true
                elseif pendingKey ~= "" then
                    isSelected = pendingNativeActivitySelections[pendingKey] == true
                end

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

                    if self.activityGroupID and self.activityGroupID > 0 then
                        if isSelected then
                            nextGroups[self.activityGroupID] = nil
                            if pendingKey ~= "" then
                                pendingNativeActivitySelections[pendingKey] = nil
                            end
                        else
                            nextGroups[self.activityGroupID] = true
                            if pendingKey ~= "" then
                                pendingNativeActivitySelections[pendingKey] = true
                            end
                        end
                    elseif pendingKey ~= "" then
                        if isSelected then
                            pendingNativeActivitySelections[pendingKey] = nil
                        else
                            pendingNativeActivitySelections[pendingKey] = true
                        end
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
        button.entryLabel = entry.label
        button:SetLabel(entry.label)
        button:SetState((button.activityGroupID > 0 and selectedActivities[button.activityGroupID] == true) or pendingNativeActivitySelections[GetPendingNativeActivityKey(entry.label)] == true)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", nativeDungeonFilterContent, "TOPLEFT", 5, y)
        if button.scoreText then
            button.scoreText:ClearAllPoints()
            button.scoreText:SetPoint("RIGHT", nativeDungeonFilterContent, "RIGHT", -8, 0)
            button.scoreText:SetPoint("CENTER", button, "CENTER", 0, 0)
            if button.scoreHitbox then
                button.scoreHitbox:ClearAllPoints()
                button.scoreHitbox:SetPoint("RIGHT", nativeDungeonFilterContent, "RIGHT", -6, 0)
                button.scoreHitbox:SetPoint("CENTER", button, "CENTER", 0, 0)
                button.scoreHitbox.entryData = entry
            end
            local targetLevel = tonumber(entry.scoreTarget and entry.scoreTarget.level)
            local estimatedGain = tonumber(entry.scoreTarget and entry.scoreTarget.estimatedGain)
            if SearchModeShowsScoreTargets(currentSearchMode) and targetLevel and targetLevel > 0 then
                if estimatedGain and estimatedGain > 0 then
                    button.scoreText:SetText(string.format("|cff66ff8a+%d|r |cff9dffb8(%d)|r", targetLevel, estimatedGain))
                else
                    button.scoreText:SetText(string.format("|cff66ff8a+%d|r", targetLevel))
                end
            elseif SearchModeShowsScoreTargets(currentSearchMode) then
                button.scoreText:SetText("|cff888888--|r")
            else
                button.scoreText:SetText("")
            end
            button.scoreText:Show()
            if button.scoreHitbox then
                button.scoreHitbox:SetShown(SearchModeShowsScoreTargets(currentSearchMode))
            end
        end
        button:Enable()
        if button.activityGroupID > 0 then
            button.labelText:SetTextColor(1, 1, 1)
        else
            button.labelText:SetTextColor(0.65, 0.65, 0.65)
        end
        button:Show()
        if button.labelText then
            button.labelText:Show()
        end
        y = y - 16
    end

    for index = #activityEntries + 1, #nativeDungeonActivityButtons do
        local button = nativeDungeonActivityButtons[index]
        if button then
            button:Hide()
            if button.scoreText then
                button.scoreText:Hide()
            end
            if button.scoreHitbox then
                button.scoreHitbox:Hide()
            end
            if button.labelText then
                button.labelText:Hide()
            end
        end
    end

    nativeDungeonFilterContent:SetHeight(math.max(1, -y + 8))

    local hasPendingResolutions = false
    for _, entry in ipairs(activityEntries) do
        local pendingKey = GetPendingNativeActivityKey(entry.label)
        if pendingNativeActivitySelections[pendingKey] and tonumber(entry.groupID or 0) > 0 then
            hasPendingResolutions = true
            break
        end
    end

    if hasPendingResolutions then
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

            for _, entry in ipairs(activityEntries) do
                local pendingKey = GetPendingNativeActivityKey(entry.label)
                local groupID = tonumber(entry.groupID) or 0
                if pendingNativeActivitySelections[pendingKey] and groupID > 0 then
                    nextGroups[groupID] = true
                end
            end

            state.activities = {}
            for groupID in pairs(nextGroups) do
                table.insert(state.activities, groupID)
            end
            table.sort(state.activities)
        end)
    end
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
        ratingLabel = "Kills"
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
        for _, label in ipairs(GetLocalizedSeasonDungeonLabels()) do
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

local function GetSearchResultActivityID(searchResultInfo, searchResultID)
    if not searchResultInfo then
        return nil
    end

    local activityID = tonumber(searchResultInfo.activityID)
    if not activityID and searchResultID and securecallfunction and C_LFGList and C_LFGList.GetSearchResultInfo then
        activityID = securecallfunction(function(resultID)
            local secureResultInfo = C_LFGList.GetSearchResultInfo(resultID)
            local ids = secureResultInfo and secureResultInfo.activityIDs
            local firstID = type(ids) == "table" and ids[1] or nil
            return tonumber(firstID)
        end, searchResultID)
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
    local showRaidBossRange = currentSearchMode == "raid" or currentSearchMode == "legacy_raid"
    local showRaidRoleRanges = showRaidBossRange
    local showRaidUtilityToggles = showRaidBossRange
    local showRoleNeedToggles = not showRaidBossRange

    if not showSearchQuery then
        OAK_F.SearchQuery = ""
    end

    if not SearchDifficultyIsValidForMode(currentSearchMode, OAK_F.Difficulty) then
        OAK_F.Difficulty = "ANY"
    end
    diffDropdown:SetOptions(GetSearchDifficultyOptions(currentSearchMode))
    diffDropdown:SetValue(OAK_F.Difficulty)
    if SearchModeUsesNativeDungeonFilters(currentSearchMode) then
        SyncNativeDifficultyFilter()
    end
    local queryLabel, queryHint = GetSearchQueryLabel(currentSearchMode)
    keyRangeLabel:SetText(queryLabel)
    keyRangeHint:SetText(queryHint)

    SetControlVisible(diffDropdown, showDifficulty)
    SetControlVisible(keyRangeLabel, showSearchQuery)
    SetControlVisible(keyRangeHint, showSearchQuery)
    SetControlVisible(keyQueryBox, showSearchQuery)
    SetControlVisible(addonTable.SearchQueryButton, showSearchQuery)
    SetControlVisible(filterPanel.raidBossRangeLabel, showRaidBossRange)
    SetControlVisible(filterPanel.raidBossRangeHint, showRaidBossRange)
    SetControlVisible(filterPanel.raidBossRangeBox, showRaidBossRange)
    SetControlVisible(filterPanel.raidBossRangeResetButton, showRaidBossRange)
    for _, control in ipairs(raidRoleRangeControls) do
        SetControlVisible(control.label, showRaidRoleRanges)
        SetControlVisible(control.hint, showRaidRoleRanges)
        SetControlVisible(control.box, showRaidRoleRanges)
        SetControlVisible(control.resetButton, showRaidRoleRanges)
    end
    if showSearchQuery and filterPanel:IsShown() then
        if nativeSearchHost.AttachNativeSearchBoxToOak then
            nativeSearchHost.AttachNativeSearchBoxToOak()
        end
    else
        if nativeSearchHost.RestoreNativeSearchBox then
            nativeSearchHost.RestoreNativeSearchBox()
        end
    end

    local activitySectionTitle = GetSearchActivitySectionTitle(currentSearchMode)
    if activitySectionTitle then
        filterActivityTitle:SetText(activitySectionTitle)
    end

    local difficultyTopY = -35
    local queryLabelTopY = showDifficulty and -67 or -35
    local queryHintTopY = queryLabelTopY - 13
    local queryBoxTopY = queryHintTopY - 17
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
    filterPanel.raidBossRangeLabel:ClearAllPoints()
    filterPanel.raidBossRangeLabel:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, queryLabelTopY)
    filterPanel.raidBossRangeHint:ClearAllPoints()
    filterPanel.raidBossRangeHint:SetPoint("LEFT", filterPanel.raidBossRangeLabel, "RIGHT", 8, 0)
    filterPanel.raidBossRangeBox:ClearAllPoints()
    filterPanel.raidBossRangeBox:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, queryBoxTopY + 8)
    if not filterPanel.raidBossRangeBox:HasFocus() then
        filterPanel.raidBossRangeBox:SetText(OAK_F.RaidBossesRange or "")
    end
    filterPanel.raidBossRangeResetButton:ClearAllPoints()
    filterPanel.raidBossRangeResetButton:SetPoint("LEFT", filterPanel.raidBossRangeBox, "RIGHT", 6, 0)
    if not filterPanel.raidTankRange.box:HasFocus() then
        filterPanel.raidTankRange.box:SetText(OAK_F.RaidTankRange or "")
    end
    if not filterPanel.raidHealerRange.box:HasFocus() then
        filterPanel.raidHealerRange.box:SetText(OAK_F.RaidHealerRange or "")
    end
    if not filterPanel.raidDpsRange.box:HasFocus() then
        filterPanel.raidDpsRange.box:SetText(OAK_F.RaidDpsRange or "")
    end
    addonTable.SearchQueryButton:ClearAllPoints()
    addonTable.SearchResetButton:ClearAllPoints()

    if showNativeDungeonFilters then
        addonTable.SearchQueryButton:SetWidth(84)
        addonTable.SearchQueryButton.text:SetText("Refresh")
        addonTable.SearchQueryButton:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, searchButtonTopY)
        addonTable.SearchResetButton:SetPoint("TOPLEFT", addonTable.SearchQueryButton, "TOPRIGHT", 7, 0)
        addonTable.SearchResetButton:Show()
        SetControlVisible(boxNeedTank, false)
        SetControlVisible(boxNeedHeal, false)
        SetControlVisible(boxNeedDPS, false)
        SetControlVisible(boxHasTank, false)
        SetControlVisible(boxHasHeal, false)
        SetControlVisible(boxParty, false)
        SetControlVisible(boxLust, false)
        SetControlVisible(boxBrez, false)
        SetControlVisible(filterPanel.matchMyRaidLockoutBox, false)
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
        nativeDungeonFilterContent.selectAllButton:Hide()
        nativeDungeonFilterContent.selectNoneButton:Hide()
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

    addonTable.SearchQueryButton:SetWidth(175)
    addonTable.SearchQueryButton.text:SetText("Search")
    addonTable.SearchQueryButton:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, searchButtonTopY)
    addonTable.SearchResetButton:Hide()

    SetControlVisible(boxNeedTank, showRoleNeedToggles)
    SetControlVisible(boxNeedHeal, showRoleNeedToggles)
    SetControlVisible(boxNeedDPS, showRoleNeedToggles)
    SetControlVisible(boxHasTank, showRoleNeedToggles)
    SetControlVisible(boxHasHeal, showRoleNeedToggles)
    SetControlVisible(boxParty, showRaidUtilityToggles or not showRaidBossRange)
    SetControlVisible(boxLust, showRaidUtilityToggles or not showRaidBossRange)
    SetControlVisible(boxBrez, showRaidUtilityToggles or not showRaidBossRange)
    SetControlVisible(filterPanel.matchMyRaidLockoutBox, showRaidUtilityToggles)
    boxNeedTank:SetState(OAK_F.NeedTank)
    boxHasTank:SetState(OAK_F.HasTank)
    boxNeedHeal:SetState(OAK_F.NeedHeal)
    boxHasHeal:SetState(OAK_F.HasHeal)
    boxNeedDPS:SetState(OAK_F.NeedDPS)
    boxParty:SetState(OAK_F.PartyFit)
    boxLust:SetState(OAK_F.NeedLust)
    boxBrez:SetState(OAK_F.NeedBrez)
    filterPanel.matchMyRaidLockoutBox:SetState(OAK_F.MatchMyRaidLockout)
    SetControlVisible(divTexture, showActivityFilters)
    SetControlVisible(filterActivityTitle, showActivityFilters)
    SetControlVisible(filterDungeonContainer, showActivityFilters)

    if showSearchQuery then
        baseY = showDifficulty and -148 or -116
    else
        baseY = showDifficulty and -78 or -46
    end
    if showRaidBossRange then
        baseY = baseY - 24
        baseY = baseY - 140
    end

    if showRaidBossRange then
        boxParty:ClearAllPoints()
        boxParty:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 16, baseY - 14)
        boxLust:ClearAllPoints()
        boxLust:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 16, baseY - 36)
        boxBrez:ClearAllPoints()
        boxBrez:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 104, baseY - 36)
        filterPanel.matchMyRaidLockoutBox:ClearAllPoints()
        filterPanel.matchMyRaidLockoutBox:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 16, baseY - 58)

        filterPanel.raidTankRange.label:ClearAllPoints()
        filterPanel.raidTankRange.label:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, queryBoxTopY - 30)
        filterPanel.raidTankRange.hint:ClearAllPoints()
        filterPanel.raidTankRange.hint:SetPoint("LEFT", filterPanel.raidTankRange.label, "RIGHT", 8, 0)
        filterPanel.raidTankRange.box:ClearAllPoints()
        filterPanel.raidTankRange.box:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, queryBoxTopY - 44)
        filterPanel.raidTankRange.resetButton:ClearAllPoints()
        filterPanel.raidTankRange.resetButton:SetPoint("LEFT", filterPanel.raidTankRange.box, "RIGHT", 6, 0)

        filterPanel.raidHealerRange.label:ClearAllPoints()
        filterPanel.raidHealerRange.label:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, queryBoxTopY - 64)
        filterPanel.raidHealerRange.hint:ClearAllPoints()
        filterPanel.raidHealerRange.hint:SetPoint("LEFT", filterPanel.raidHealerRange.label, "RIGHT", 8, 0)
        filterPanel.raidHealerRange.box:ClearAllPoints()
        filterPanel.raidHealerRange.box:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, queryBoxTopY - 78)
        filterPanel.raidHealerRange.resetButton:ClearAllPoints()
        filterPanel.raidHealerRange.resetButton:SetPoint("LEFT", filterPanel.raidHealerRange.box, "RIGHT", 6, 0)

        filterPanel.raidDpsRange.label:ClearAllPoints()
        filterPanel.raidDpsRange.label:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, queryBoxTopY - 98)
        filterPanel.raidDpsRange.hint:ClearAllPoints()
        filterPanel.raidDpsRange.hint:SetPoint("LEFT", filterPanel.raidDpsRange.label, "RIGHT", 8, 0)
        filterPanel.raidDpsRange.box:ClearAllPoints()
        filterPanel.raidDpsRange.box:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, queryBoxTopY - 112)
        filterPanel.raidDpsRange.resetButton:ClearAllPoints()
        filterPanel.raidDpsRange.resetButton:SetPoint("LEFT", filterPanel.raidDpsRange.box, "RIGHT", 6, 0)

        boxParty:ClearAllPoints()
        boxParty:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 16, baseY - 8)
        boxLust:ClearAllPoints()
        boxLust:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 16, baseY - 28)
        boxBrez:ClearAllPoints()
        boxBrez:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 104, baseY - 28)
        filterPanel.matchMyRaidLockoutBox:ClearAllPoints()
        filterPanel.matchMyRaidLockoutBox:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 16, baseY - 48)
    else
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
        filterPanel.matchMyRaidLockoutBox:ClearAllPoints()
        filterPanel.matchMyRaidLockoutBox:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 16, baseY - 88)
    end
    divTexture:ClearAllPoints()
    divTexture:SetPoint("TOP", filterPanel, "TOP", 0, baseY - (showRaidBossRange and 78 or 84))
    filterActivityTitle:ClearAllPoints()
    filterActivityTitle:SetPoint("TOP", filterPanel, "TOPLEFT", 95, baseY - (showRaidBossRange and 88 or 94))
    filterDungeonContainer:ClearAllPoints()
    filterDungeonContainer:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 10, baseY - (showRaidBossRange and 100 or 106))
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

local function GetTooltipMemberSpecLabel(member)
    if type(member) ~= "table" then
        return ""
    end

    if member.specID and addonTable.SpecShortNames and addonTable.SpecShortNames[member.specID] then
        return addonTable.SpecShortNames[member.specID]
    end

    local specName = tostring(member.specName or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if specName ~= "" then
        return specName
    end

    return ""
end

local function AddDungeonMemberSpecLines(tooltip, group)
    if type(tooltip) ~= "table" or type(group) ~= "table" then
        return
    end

    local members = group.memberDetails or {}
    if #members == 0 then
        return
    end

    local roleOrder = {
        { key = "TANK", label = "Tank" },
        { key = "HEALER", label = "Healer" },
        { key = "DAMAGER", label = "Damage" },
    }

    local addedAny = false
    for _, roleInfo in ipairs(roleOrder) do
        local lines = {}
        for _, member in ipairs(members) do
            local role = member.role or "DAMAGER"
            if role ~= "TANK" and role ~= "HEALER" then
                role = "DAMAGER"
            end
            if role == roleInfo.key then
                local specLabel = GetTooltipMemberSpecLabel(member)
                local classLabel = LOCALIZED_CLASS_NAMES_MALE[member.class or ""] or LOCALIZED_CLASS_NAMES_FEMALE[member.class or ""] or (member.class or "")
                local display = specLabel ~= "" and specLabel or classLabel
                if display ~= "" then
                    table.insert(lines, addonTable.ApplyClassColor(display, member.class or ""))
                end
            end
        end

        if #lines > 0 then
            if not addedAny then
                tooltip:AddLine(" ")
                tooltip:AddLine("Members", 1, 0.82, 0)
                addedAny = true
            end
            tooltip:AddLine(roleInfo.label .. ": " .. table.concat(lines, ", "), 1, 1, 1, true)
        end
    end
end

local function TryShowNativeDungeonSearchTooltip(tooltip, owner, group)
    if type(tooltip) ~= "table" or type(group) ~= "table" then
        return false
    end

    if not (group.id and LFGListUtil_SetSearchEntryTooltip) then
        return false
    end

    tooltip:SetOwner(owner, "ANCHOR_RIGHT")
    tooltip:ClearLines()

    local ok = pcall(LFGListUtil_SetSearchEntryTooltip, tooltip, group.id)
    if not ok or tooltip:NumLines() <= 0 then
        return false
    end

    AddDungeonMemberSpecLines(tooltip, group)
    tooltip:Show()
    return true
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
    local searchBox = nativeSearchHost.GetNativeSearchBox()
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
        UpdateSearchRegionDisplay(row, layout)

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

        row.modeText:ClearAllPoints()
        if layout.modeWidth and layout.modeWidth > 0 and layout.modeX then
            row.modeText:SetPoint("CENTER", row, "LEFT", layout.modeX + (layout.modeWidth / 2) - SEARCH_ROW_X_OFFSET, 0)
            row.modeText:SetWidth(layout.modeWidth)
            row.modeText:Show()
        else
            row.modeText:Hide()
        end

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
notesVisibilityBtn:SetScript("OnClick", function()
    OakLFGSorterDB.searchHideNotes = true
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
        if self.groupData and self.groupData.id and not self.groupData.isApplied and not self.groupData.isDeclined then
            if addonTable.BeginSearchSignup then
                addonTable.BeginSearchSignup(self.groupData.id)
            else
                LFGListSearchPanel_SelectResult(LFGListFrame.SearchPanel, self.groupData.id)
                LFGListSearchPanel_SignUp(LFGListFrame.SearchPanel)
            end
        end
    end)

    row:SetScript("OnEnter", function(self) 
        self.hoverBg:Show() 
        if self.groupData then
            local grp = self.groupData
            local mode = grp.mode or "generic"
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            self._oakShiftTooltipState = IsShiftKeyDown and IsShiftKeyDown() or false
            self:SetScript("OnUpdate", function(widget)
                local shiftDown = IsShiftKeyDown and IsShiftKeyDown() or false
                if widget._oakShiftTooltipState ~= shiftDown then
                    widget._oakShiftTooltipState = shiftDown
                    local onEnter = widget:GetScript("OnEnter")
                    if onEnter then
                        onEnter(widget)
                    end
                end
            end)

            if addonTable.TryShowRaiderIOProfileTooltip and addonTable.TryShowRaiderIOProfileTooltip(GameTooltip, grp.leaderNameRaw or grp.leaderName) then
                return
            end

            if mode == "raid" or mode == "legacy_raid" then
                local regionBadge = addonTable.GetRegionBadgeMarkup and addonTable.GetRegionBadgeMarkup(grp.regionInfo) or ""
                local titleText = (grp.displayTitle ~= "" and grp.displayTitle) or (grp.titleStr ~= "" and grp.titleStr) or "--"
                GameTooltip:AddLine((regionBadge ~= "" and (regionBadge .. " " .. titleText)) or titleText, 1, 1, 1)
                GameTooltip:AddLine(grp.activityName or "Unknown Raid", 1, 0.82, 0)
                if grp.playstyleLabel and grp.playstyleLabel ~= "" and grp.playstyleLabel ~= "Any" then
                    GameTooltip:AddLine(grp.playstyleLabel, 0.2, 1, 0.2)
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine("Leader:", grp.leaderNameRaw or "Unknown", 1, 1, 1, 1, 1, 1)
                if addonTable.AddRegionTooltipLine then
                    addonTable.AddRegionTooltipLine(GameTooltip, grp.regionInfo)
                end
                GameTooltip:AddDoubleLine("Members:", string.format("%d (%d/%d/%d)", grp.members or 0, grp.tanks or 0, grp.heals or 0, grp.dps or 0), 1, 1, 1, 1, 1, 1)
                if grp.isFriend then
                    local friendNames = addonTable.GetSearchGroupFriendNames and addonTable.GetSearchGroupFriendNames(grp) or {}
                    GameTooltip:AddLine("Friends in this group", 0.40, 0.85, 1)
                    if #friendNames > 0 then
                        for _, friendName in ipairs(friendNames) do
                            GameTooltip:AddLine(friendName, 1, 1, 1)
                        end
                    elseif (grp.numBNetFriends or 0) > 0 then
                        GameTooltip:AddLine("Battle.net friend detected", 1, 1, 1)
                    else
                        GameTooltip:AddLine("Friend detected", 1, 1, 1)
                    end
                end
                GameTooltip:AddDoubleLine("Created:", FormatTime(grp.age or 0) .. " ago", 1, 1, 1, 1, 1, 1)
                if grp.raidListing and grp.raidListing.difficultyLabel and grp.raidListing.difficultyLabel ~= "" then
                    GameTooltip:AddDoubleLine("Difficulty:", grp.raidListing.difficultyLabel, 1, 1, 1, 1, 1, 1)
                end
                if grp.raidListing and grp.raidListing.progressText and grp.raidListing.progressText ~= "--" then
                    GameTooltip:AddDoubleLine("Progress:", grp.raidListing.progressText, 1, 1, 1, 1, 1, 1)
                end
                local defeatedText = GetRaidEncounterListText(grp)
                GameTooltip:AddDoubleLine("Bosses Defeated:", defeatedText or "--", 1, 1, 1, 1, 0.2, 0.2)

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
                local regionBadge = addonTable.GetRegionBadgeMarkup and addonTable.GetRegionBadgeMarkup(grp.regionInfo) or ""
                local titleText = grp.activityName or "Unknown Activity"
                GameTooltip:AddLine((regionBadge ~= "" and (regionBadge .. " " .. titleText)) or titleText, 1, 1, 1)
                if grp.playstyleLabel and grp.playstyleLabel ~= "" and grp.playstyleLabel ~= "Any" then
                    GameTooltip:AddLine(grp.playstyleLabel, 0.2, 1, 0.2)
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine("Leader:", grp.leaderNameRaw or "Unknown", 1, 1, 1, 1, 1, 1)
                if addonTable.AddRegionTooltipLine then
                    addonTable.AddRegionTooltipLine(GameTooltip, grp.regionInfo)
                end
                GameTooltip:AddDoubleLine("Members:", string.format("%d (%d/%d/%d)", grp.members or 0, grp.tanks or 0, grp.heals or 0, grp.dps or 0), 1, 1, 1, 1, 1, 1)
                if grp.isFriend then
                    local friendNames = addonTable.GetSearchGroupFriendNames and addonTable.GetSearchGroupFriendNames(grp) or {}
                    GameTooltip:AddLine("Friends in this group", 0.40, 0.85, 1)
                    if #friendNames > 0 then
                        for _, friendName in ipairs(friendNames) do
                            GameTooltip:AddLine(friendName, 1, 1, 1)
                        end
                    elseif (grp.numBNetFriends or 0) > 0 then
                        GameTooltip:AddLine("Battle.net friend detected", 1, 1, 1)
                    else
                        GameTooltip:AddLine("Friend detected", 1, 1, 1)
                    end
                end
                GameTooltip:AddDoubleLine("Created:", FormatTime(grp.age or 0) .. " ago", 1, 1, 1, 1, 1, 1)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("PVP Profile (Leader)", 0.2, 1, 0.2)
                GameTooltip:AddDoubleLine("Rating:", (grp.pvpRating and grp.pvpRating > 0) and grp.pvpRating or "--", 1, 1, 1, 1, 1, 1)
                if grp.pvpBracket then
                    GameTooltip:AddDoubleLine("Bracket:", grp.pvpBracket, 1, 1, 1, 1, 1, 1)
                end
            else
                if (mode == "dungeon" or mode == "mythic_plus") and not (IsShiftKeyDown and IsShiftKeyDown()) then
                    if TryShowNativeDungeonSearchTooltip(GameTooltip, self, grp) then
                        return
                    end
                end

                local regionBadge = addonTable.GetRegionBadgeMarkup and addonTable.GetRegionBadgeMarkup(grp.regionInfo) or ""
                local titleText = (grp.displayTitle ~= "" and grp.displayTitle or "--")
                GameTooltip:AddLine((regionBadge ~= "" and (regionBadge .. " " .. titleText)) or titleText, 1, 1, 1)
                GameTooltip:AddLine(grp.activityName or "Unknown Activity", 1, 0.82, 0)
                if grp.playstyleLabel and grp.playstyleLabel ~= "" and grp.playstyleLabel ~= "Any" then
                    GameTooltip:AddLine(grp.playstyleLabel, 0.2, 1, 0.2)
                end

                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine("Leader:", grp.leaderNameRaw or "Unknown", 1, 1, 1, 1, 1, 1)
                if addonTable.AddRegionTooltipLine then
                    addonTable.AddRegionTooltipLine(GameTooltip, grp.regionInfo)
                end
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
                if grp.isFriend then
                    local friendNames = addonTable.GetSearchGroupFriendNames and addonTable.GetSearchGroupFriendNames(grp) or {}
                    GameTooltip:AddLine("Friends in this group", 0.40, 0.85, 1)
                    if #friendNames > 0 then
                        for _, friendName in ipairs(friendNames) do
                            GameTooltip:AddLine(friendName, 1, 1, 1)
                        end
                    elseif (grp.numBNetFriends or 0) > 0 then
                        GameTooltip:AddLine("Battle.net friend detected", 1, 1, 1)
                    else
                        GameTooltip:AddLine("Friend detected", 1, 1, 1)
                    end
                end
                GameTooltip:AddLine("Members", 1, 0.82, 0)
                AddRoleClassLines(GameTooltip, "Tank", "TANK", roleGroups)
                AddRoleClassLines(GameTooltip, "Healer", "HEALER", roleGroups)
                AddRoleClassLines(GameTooltip, "Damage", "DAMAGER", roleGroups)

                if grp.rioProfile and addonTable.AppendMythicPlusMilestonesToTooltip then
                    addonTable.AppendMythicPlusMilestonesToTooltip(GameTooltip, grp.rioProfile)
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
    row:SetScript("OnLeave", function(self)
        self.hoverBg:Hide()
        self._oakShiftTooltipState = nil
        self:SetScript("OnUpdate", nil)
        GameTooltip:Hide()
    end)

    row.dungeonText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    row.dungeonText:SetPoint("TOPLEFT", row, "TOPLEFT", 5, 0)
    row.dungeonText:SetWidth(SEARCH_LAYOUT_EXPANDED.dungeonWidth); row.dungeonText:SetHeight(30); row.dungeonText:SetJustifyH("LEFT"); row.dungeonText:SetJustifyV("MIDDLE"); row.dungeonText:SetWordWrap(true)
    row.regionText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
    row.regionText:SetText("")
    row.regionText:SetJustifyH("RIGHT")
    row.regionText:Hide()
    
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

    row.modeText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    row.modeText:SetPoint("CENTER", row, "LEFT", SEARCH_LAYOUT_EXPANDED_RAID.modeX + (SEARCH_LAYOUT_EXPANDED_RAID.modeWidth / 2) - SEARCH_ROW_X_OFFSET, 0)
    row.modeText:SetWidth(SEARCH_LAYOUT_EXPANDED_RAID.modeWidth)
    row.modeText:SetJustifyH("CENTER")
    row.modeText:Hide()

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
        if row.groupData and row.groupData.id and not row.groupData.isApplied and not row.groupData.isDeclined then
            if addonTable.BeginSearchSignup then
                addonTable.BeginSearchSignup(row.groupData.id)
            else
                LFGListSearchPanel_SelectResult(LFGListFrame.SearchPanel, row.groupData.id)
                LFGListSearchPanel_SignUp(LFGListFrame.SearchPanel)
            end
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
        group.isRoleFilled = addonTable.IsAppliedRoleFilled and addonTable.IsAppliedRoleFilled(group) or false

        if addonTable.ResultMatchesPlayerRegion and not addonTable.ResultMatchesPlayerRegion(group) then
            skip = true
        end

        if not skip and useNativeDungeonFilters then
            local selectedCount = 0
            for _ in pairs(selectedActivityGroups) do
                selectedCount = selectedCount + 1
            end
            if selectedCount > 0 and not selectedActivityGroups[tonumber(group.activityGroupID) or 0] then
                skip = true
            end

            if adv.hasTank and group.tanks == 0 then skip = true end
            if adv.hasHealer and group.heals == 0 then skip = true end
        elseif not skip then
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
        if not skip and useNativeDungeonFilters then
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
        elseif not skip then
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

        if not skip and OAK_F.NeedLust and group.hasLust then skip = true end
        if not skip and OAK_F.NeedBrez and group.hasBrez then skip = true end

        if not skip and SearchModeUsesDifficulty(currentSearchMode) then
            if OAK_F.Difficulty == "NORMAL" and group.difficultyToken ~= "NORMAL" then skip = true end
            if OAK_F.Difficulty == "HEROIC" and group.difficultyToken ~= "HEROIC" then skip = true end
            if OAK_F.Difficulty == "MYTHIC" and group.difficultyToken ~= "MYTHIC" then skip = true end
            if OAK_F.Difficulty == "MYTHIC_PLUS" and group.difficultyToken ~= "MYTHIC_PLUS" then skip = true end
        end

        if not skip and (currentSearchMode == "raid" or currentSearchMode == "legacy_raid") then
            local bossesKilled = tonumber(group.raidListing and group.raidListing.bossesKilled) or 0
            local minBosses, maxBosses = ParseRaidBossRangeExpression(OAK_F.RaidBossesRange)
            if minBosses and bossesKilled < minBosses then
                skip = true
            end
            if maxBosses and bossesKilled > maxBosses then
                skip = true
            end
            if not skip and OAK_F.MatchMyRaidLockout and addonTable.ResultMatchesRaidLockout then
                skip = not addonTable.ResultMatchesRaidLockout(group, { matchMyRaidLockout = true })
            end
            if not skip and not ResultMatchesNumericRange(tonumber(group.tanks) or 0, OAK_F.RaidTankRange, true) then
                skip = true
            end
            if not skip and not ResultMatchesNumericRange(tonumber(group.heals) or 0, OAK_F.RaidHealerRange, true) then
                skip = true
            end
            if not skip and not ResultMatchesNumericRange(tonumber(group.dps) or 0, OAK_F.RaidDpsRange, true) then
                skip = true
            end
        end

        local rowMode = group.mode or currentSearchMode
        local isKeyListing = rowMode == "mythic_plus" or rowMode == "generic" or rowMode == "delve" or group.difficultyToken == "MYTHIC_PLUS" or (tonumber(group.keyLevel) or 0) > 0
        local isPvpListing = rowMode == "rated_pvp" or rowMode == "pvp"

        if not skip and isPvpListing then
            local pvpQuery = TrimString(OAK_F.SearchQuery)
            local exactRating = tonumber(pvpQuery)
            if exactRating and (tonumber(group.pvpRating) or 0) ~= exactRating then
                skip = true
            end
        end

        if not skip and OAK_F.PartyFit then
            skip = not GroupMatchesPartyFit(group)
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
        
        if group.isRoleFilled then
            row.bg:SetColorTexture(0.58, 0.38, 0.10, 0.62)
        elseif group.isApplied then
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

        if group.mode == "raid" or group.mode == "legacy_raid" then
            row.dungeonText:SetText(GetRaidDungeonDisplay(group))
            row.titleText:SetText(GetRaidRowTitle(group))
            row.modeText:SetText(GetRaidModeDisplay(group))
            row.modeText:Show()
        else
            row.dungeonText:SetText(group.dungeon)
            row.titleText:SetText(group.titleStr or "")
            row.modeText:SetText("")
            row.modeText:Hide()
        end
        UpdateSearchRegionDisplay(row, GetSearchLayout())
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
            rStr = GetRaidKillsDisplay(group)
        elseif currentSearchMode == "raid" or currentSearchMode == "legacy_raid" then
            rStr = "N/A"
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
            if group.isRoleFilled then
                row.ageText:SetText("Filled")
                row.ageText:SetTextColor(1.0, 0.82, 0.30)
                row.cancelBtn:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Role Filled - Cancel Application", 1, 0.82, 0.30)
                    GameTooltip:Show()
                end)
            else
                row.ageText:SetText("Pending")
                row.ageText:SetTextColor(0.2, 1, 0.2)
                row.cancelBtn:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Cancel Application", 1, 0.2, 0.2)
                    GameTooltip:Show()
                end)
            end
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
        ApplySearchNotesLayout()
        return
    end

    for _, resultID in ipairs(results) do
        local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)
        
        if searchResultInfo then
            local activityID = GetSearchResultActivityID(searchResultInfo, resultID)
            local activityInfo = activityID and C_LFGList.GetActivityInfoTable(activityID) or nil
            local memberCounts = C_LFGList.GetSearchResultMemberCounts(resultID) or {}
            
            local appID, appStatus = C_LFGList.GetApplicationInfo(resultID)
            local isApplied = (appStatus == "applied" or appStatus == "invited")
            local isDeclined = (appStatus == "declined" or appStatus == "declined_delisted" or appStatus == "declined_full" or appStatus == "failed" or appStatus == "timedout")
            
            if activityInfo then
                local mode, rating, ratingLabel, pvpRating, pvpBracket = GetResultRatingData(searchResultInfo, activityInfo)
                local maxPlayers = tonumber(activityInfo.maxNumPlayers or activityInfo.maxPlayers) or tonumber(searchResultInfo.numMembers) or 0
                local numMembers = tonumber(searchResultInfo.numMembers) or 0

                if not ((mode == "dungeon" or mode == "mythic_plus") and maxPlayers > 0 and numMembers >= maxPlayers) then
                    local hasLust, hasBrez = false, false
                    local memberDetails = (addonTable.GetSearchResultPlayers and addonTable.GetSearchResultPlayers(resultID, tonumber(searchResultInfo.numMembers) or 0)) or {}
                    local playstyleValue, playstyleLabel = GetSearchPlaystyle(searchResultInfo, activityInfo)
                    local regionInfo = addonTable.GetRegionInfoFromLeaderName and addonTable.GetRegionInfoFromLeaderName(searchResultInfo.leaderName) or nil

                    for _, member in ipairs(memberDetails) do
                        local c = member.class and string.upper(member.class)
                        if c == "MAGE" or c == "SHAMAN" or c == "HUNTER" or c == "EVOKER" then hasLust = true end
                        if c == "DEATHKNIGHT" or c == "DRUID" or c == "WARLOCK" or c == "PALADIN" then hasBrez = true end
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
                    local raidListing = nil
                    if (mode == "raid" or mode == "legacy_raid") and addonTable.GetRaidListingInfo then
                        raidListing = addonTable.GetRaidListingInfo(resultID, searchResultInfo, activityInfo)
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
                        memberCounts = memberCounts,
                        hasLust = hasLust,
                        hasBrez = hasBrez,
                        members = numMembers,
                        memberDetails = memberDetails,
                        maxPlayers = maxPlayers,
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
                        raidListing = raidListing,
                        regionInfo = regionInfo,
                        numBNetFriends = tonumber(searchResultInfo.numBNetFriends) or 0,
                        numCharFriends = tonumber(searchResultInfo.numCharFriends) or 0,
                        numGuildMates = tonumber(searchResultInfo.numGuildMates) or 0,
                    })
                end
            end
        end
    end

    currentSearchMode = DetermineSearchMode()
    UpdateSearchFilterPane()
    ApplySearchNotesLayout()
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
addonTable.RequestSearchUpdate = RequestUpdate

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
    if OAK_SEARCH.ScaleSlider then
        OAK_SEARCH.ScaleSlider:SetValue(OakLFGSorterDB.searchScale or 1.0)
    end
    AutoPositionSearch()
    ApplySearchScale(OakLFGSorterDB.searchScale or 1.0)
    ApplySearchNotesLayout()
    if addonTable.UpdateSearchQuickSignupControls then
        addonTable.UpdateSearchQuickSignupControls()
    end
    if addonTable.EnsureSearchSignupHooks then
        addonTable.EnsureSearchSignupHooks()
    end
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
    if addonTable.SearchSupportersPanel then addonTable.SearchSupportersPanel:Hide() end
    if addonTable.SearchOptionsPanel then addonTable.SearchOptionsPanel:Hide() end
    if nativeSearchHost.RestoreNativeSearchBox then
        nativeSearchHost.RestoreNativeSearchBox()
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
