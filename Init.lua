local addonName, addonTable = ...

addonTable.Locales = addonTable.Locales or {}

local currentLocale = GetLocale and GetLocale() or "enUS"

function addonTable.NewLocale(localeName, isDefault)
    if not localeName then
        return nil
    end

    if not isDefault and localeName ~= currentLocale then
        return nil
    end

    local localeTable = addonTable.Locales[localeName]
    if not localeTable then
        localeTable = {}
        addonTable.Locales[localeName] = localeTable
    end

    if isDefault then
        addonTable.DefaultLocale = localeTable
    end

    return localeTable
end

addonTable.L = setmetatable({}, {
    __index = function(_, key)
        local active = addonTable.Locales[currentLocale]
        if active and active[key] ~= nil then
            return active[key]
        end

        local fallback = addonTable.DefaultLocale
        if fallback and fallback[key] ~= nil then
            return fallback[key]
        end

        return key
    end,
})

-- Global Database
OakLFGSorterDB = OakLFGSorterDB or {}
if OakLFGSorterDB.autoOpen == nil then OakLFGSorterDB.autoOpen = true end
if OakLFGSorterDB.scale == nil then OakLFGSorterDB.scale = 1.0 end
if OakLFGSorterDB.muteApplicantPing == nil then OakLFGSorterDB.muteApplicantPing = true end
if OakLFGSorterDB.hideNotes == nil then OakLFGSorterDB.hideNotes = false end
if OakLFGSorterDB.autoHideFilledRoles == nil then OakLFGSorterDB.autoHideFilledRoles = false end
if OakLFGSorterDB.showRegions == nil then OakLFGSorterDB.showRegions = false end
if OakLFGSorterDB.lowLatencyOnly == nil then OakLFGSorterDB.lowLatencyOnly = false end
if OakLFGSorterDB.fontName == nil then OakLFGSorterDB.fontName = "OakUI Font" end
if OakLFGSorterDB.fontSize == nil then OakLFGSorterDB.fontSize = 12 end
if OakLFGSorterDB.windowOpacity == nil then OakLFGSorterDB.windowOpacity = 0.85 end
if OakLFGSorterDB.themePreset == nil then OakLFGSorterDB.themePreset = "CLASS" end
if type(OakLFGSorterDB.themeCustomColor) ~= "table" then OakLFGSorterDB.themeCustomColor = { r = 0.74, g = 0.49, b = 0.93 } end
if type(OakLFGSorterDB.regionFilters) ~= "table" then OakLFGSorterDB.regionFilters = {} end
OakLFGSorterDB.browserFilters = OakLFGSorterDB.browserFilters or {}

local browserFilters = OakLFGSorterDB.browserFilters
if browserFilters.difficulty == nil then browserFilters.difficulty = "ANY" end
if browserFilters.playstyle == nil then browserFilters.playstyle = "ANY" end
if browserFilters.keyMin == nil then browserFilters.keyMin = "" end
if browserFilters.keyMax == nil then browserFilters.keyMax = "" end
if browserFilters.currentSeasonOnly == nil then browserFilters.currentSeasonOnly = false end
if browserFilters.needsTank == nil then browserFilters.needsTank = false end
if browserFilters.needsHealer == nil then browserFilters.needsHealer = false end
if browserFilters.needsDPS == nil then browserFilters.needsDPS = false end
if browserFilters.hasTank == nil then browserFilters.hasTank = false end
if browserFilters.hasHealer == nil then browserFilters.hasHealer = false end
if browserFilters.partyFit == nil then browserFilters.partyFit = false end
if browserFilters.needsLust == nil then browserFilters.needsLust = false end
if browserFilters.needsBrez == nil then browserFilters.needsBrez = false end
if browserFilters.hideDeclined == nil then browserFilters.hideDeclined = false end
if type(browserFilters.selectedActivities) ~= "table" then browserFilters.selectedActivities = {} end
if browserFilters.raidBossKills == nil then browserFilters.raidBossKills = "" end
if browserFilters.raidTanks    == nil then browserFilters.raidTanks    = "" end
if browserFilters.raidHealers  == nil then browserFilters.raidHealers  = "" end
if browserFilters.raidDps      == nil then browserFilters.raidDps      = "" end

-- Font Registration
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local defaultFontPath = "Interface\\AddOns\\OakLFGSorter\\media\\OakFont.ttf"

if LSM then LSM:Register("font", "OakUI Font", defaultFontPath) end

addonTable.Fonts = {
    Regular = CreateFont("OakLFG_FontRegular"),
    Large = CreateFont("OakLFG_FontLarge"),
    Small = CreateFont("OakLFG_FontSmall")
}

local function ResolveFontPath(fontName)
    if LSM and fontName and fontName ~= "" then
        local fetched = LSM:Fetch("font", fontName, true)
        if fetched and fetched ~= "" then
            return fetched
        end
    end
    return defaultFontPath
end

local function ApplyOakFont(fontPath)
    local baseSize = math.max(10, math.min(18, tonumber(OakLFGSorterDB and OakLFGSorterDB.fontSize) or 12))

    addonTable.Fonts.Regular:SetFont(fontPath, baseSize, "")
    addonTable.Fonts.Regular:SetShadowColor(0, 0, 0, 1)
    addonTable.Fonts.Regular:SetShadowOffset(1, -1)

    addonTable.Fonts.Large:SetFont(fontPath, baseSize + 2, "")
    addonTable.Fonts.Large:SetShadowColor(0, 0, 0, 1)
    addonTable.Fonts.Large:SetShadowOffset(1, -1)

    addonTable.Fonts.Small:SetFont(fontPath, math.max(8, baseSize - 2), "")
    addonTable.Fonts.Small:SetShadowColor(0, 0, 0, 1)
    addonTable.Fonts.Small:SetShadowOffset(1, -1)
end

local function ReapplySavedFont()
    local activeName = addonTable.GetActiveFontName and addonTable.GetActiveFontName() or "OakUI Font"
    local fontPath = ResolveFontPath(activeName)
    addonTable.ActiveFontPath = fontPath
    ApplyOakFont(fontPath)
    if addonTable.RefreshRegisteredFontDropdowns then addonTable.RefreshRegisteredFontDropdowns() end
    if addonTable.RefreshOptionsPanel then addonTable.RefreshOptionsPanel() end
    if addonTable.RefreshSearchOptionsPanel then addonTable.RefreshSearchOptionsPanel() end
end

function addonTable.GetAvailableFontNames()
    if LSM and LSM.HashTable then
        local fontMap = LSM:HashTable("font") or {}
        local names = {}
        for fontName in pairs(fontMap) do
            table.insert(names, fontName)
        end
        table.sort(names)
        return names
    end

    return { "OakUI Font" }
end

function addonTable.GetActiveFontName()
    return OakLFGSorterDB and OakLFGSorterDB.fontName or "OakUI Font"
end

function addonTable.GetFontPath(fontName)
    return ResolveFontPath(fontName)
end

function addonTable.SetActiveFont(fontName)
    local resolvedName = (fontName and fontName ~= "") and fontName or "OakUI Font"
    local fontPath = ResolveFontPath(resolvedName)
    OakLFGSorterDB.fontName = resolvedName
    addonTable.ActiveFontPath = fontPath
    ApplyOakFont(fontPath)
    if addonTable.RefreshOptionsPanel then addonTable.RefreshOptionsPanel() end
    if addonTable.RefreshSearchOptionsPanel then addonTable.RefreshSearchOptionsPanel() end
end

function addonTable.GetFontSize()
    return math.max(10, math.min(18, tonumber(OakLFGSorterDB and OakLFGSorterDB.fontSize) or 12))
end

function addonTable.SetFontSize(sizeValue)
    local baseSize = math.max(10, math.min(18, tonumber(sizeValue) or 12))
    OakLFGSorterDB.fontSize = baseSize
    ApplyOakFont(addonTable.ActiveFontPath or ResolveFontPath(addonTable.GetActiveFontName()))
end

function addonTable.GetWindowOpacity()
    return (OakLFGSorterDB and tonumber(OakLFGSorterDB.windowOpacity)) or 0.85
end

function addonTable.ApplyWindowOpacity()
    local alpha = addonTable.GetWindowOpacity()
    local baseColor = addonTable.OAK_COLOR_BG or {0.106, 0.106, 0.129, 0.85}
    local frames = {
        addonTable.OAK_LFG,
        addonTable.FilterPanel,
        addonTable.BrowserFilterPanel,
        addonTable.SupportersPanel,
        addonTable.OptionsPanel,
        addonTable.OAK_SEARCH,
        addonTable.SearchFilterPanel,
        addonTable.SearchSupportersPanel,
        addonTable.SearchOptionsPanel,
    }

    for _, frame in ipairs(frames) do
        if frame and frame.SetBackdropColor then
            frame:SetBackdropColor(baseColor[1], baseColor[2], baseColor[3], alpha)
        end
    end
end

function addonTable.SetWindowOpacity(value)
    local alpha = tonumber(value) or 0.85
    alpha = math.max(0.35, math.min(1.0, alpha))
    OakLFGSorterDB.windowOpacity = alpha
    addonTable.ApplyWindowOpacity()
end

local ROLE_REMAINING_KEYS = {
    TANK = "TANK_REMAINING",
    HEALER = "HEALER_REMAINING",
    DAMAGER = "DAMAGER_REMAINING",
}

local function GetAssignedRoleForUnit(unit)
    local assignedRole = UnitGroupRolesAssigned(unit)
    if assignedRole and assignedRole ~= "NONE" then
        return assignedRole
    end

    if unit == "player" and GetSpecialization and GetSpecializationInfo and GetSpecializationRoleByID then
        local specIndex = GetSpecialization()
        if specIndex then
            local specID = GetSpecializationInfo(specIndex)
            local specRole = specID and GetSpecializationRoleByID(specID)
            if specRole then
                return specRole
            end
        end
    end

    return "DAMAGER"
end

function addonTable.GetCurrentPartyRoleCounts()
    local counts = { TANK = 0, HEALER = 0, DAMAGER = 0 }
    local total = 1

    local playerRole = GetAssignedRoleForUnit("player")
    counts[playerRole] = (counts[playerRole] or 0) + 1

    if IsInGroup() then
        total = GetNumGroupMembers()
        for i = 1, total do
            local unit = IsInRaid() and ("raid" .. i) or ("party" .. i)
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                local role = GetAssignedRoleForUnit(unit)
                counts[role] = (counts[role] or 0) + 1
            end
        end
    end

    return counts, total
end

local function GetResultMaxPlayers(result)
    if type(result) ~= "table" then
        return 0
    end

    return tonumber(result.maxPlayers)
        or tonumber(result.activityInfo and (result.activityInfo.maxNumPlayers or result.activityInfo.maxPlayers))
        or 0
end

local function GetResultMemberTotal(result)
    if type(result) ~= "table" then
        return 0
    end

    return tonumber(result.numMembers or result.members) or 0
end

function addonTable.DoesResultFitCurrentParty(result)
    if type(result) ~= "table" then
        return false
    end

    local partyRoles, partySize = addonTable.GetCurrentPartyRoleCounts()
    local maxPlayers = GetResultMaxPlayers(result)
    local memberTotal = GetResultMemberTotal(result)

    if maxPlayers > 0 and memberTotal + partySize > maxPlayers then
        return false
    end

    local memberCounts = result.memberCounts
    local hasRemainingData = false
    if type(memberCounts) == "table" then
        for role, amount in pairs(partyRoles) do
            if amount > 0 then
                local remaining = tonumber(memberCounts[ROLE_REMAINING_KEYS[role]])
                if remaining ~= nil then
                    hasRemainingData = true
                    if remaining < amount then
                        return false
                    end
                end
            end
        end
    end

    if hasRemainingData then
        return true
    end

    if maxPlayers == 5 then
        local roleCounts = result.roleCounts or {}
        local tanks = tonumber(roleCounts.TANK) or tonumber(result.tanks) or 0
        local heals = tonumber(roleCounts.HEALER) or tonumber(result.heals) or 0
        local dps = tonumber(roleCounts.DAMAGER) or tonumber(result.dps) or 0
        return (tanks + (partyRoles.TANK or 0) <= 1)
            and (heals + (partyRoles.HEALER or 0) <= 1)
            and (dps + (partyRoles.DAMAGER or 0) <= 3)
            and (memberTotal + partySize <= 5)
    end

    return true
end

function addonTable.IsAppliedRoleFilled(result)
    if type(result) ~= "table" then
        return false
    end

    local isApplied = result.isApplied == true
    if not isApplied and addonTable.IsAppliedStatus then
        isApplied = addonTable.IsAppliedStatus(result.applicationStatus)
    end

    return isApplied and not addonTable.DoesResultFitCurrentParty(result)
end

local registeredFontDropdowns = {}
local fontDropdownCounter = 0
local registeredThemeRefreshers = {}

function addonTable.RegisterFontDropdown(button)
    if not button then
        return
    end
    table.insert(registeredFontDropdowns, button)
end

function addonTable.RegisterThemeRefresh(key, callback)
    if not key or type(callback) ~= "function" then
        return
    end
    registeredThemeRefreshers[key] = callback
end

function addonTable.UnregisterThemeRefresh(key)
    if key then
        registeredThemeRefreshers[key] = nil
    end
end

function addonTable.RefreshRegisteredFontDropdowns()
    for _, button in ipairs(registeredFontDropdowns) do
        if button and button.RefreshSelection then
            button:RefreshSelection()
        end
    end
end

local _, playerClass = UnitClass("player")
addonTable.PlayerClass = playerClass
addonTable.PlayerClassColor = RAID_CLASS_COLORS[playerClass] or { r = 1, g = 1, b = 1 }

addonTable.ThemePresets = {
    { id = "CLASS", label = "Class Colored" },
    { id = "SKY", label = "Sky Blue", color = { r = 0.30, g = 0.76, b = 0.98 } },
    { id = "MINT", label = "Class Mint", color = { r = 0.35, g = 0.90, b = 0.66 } },
    { id = "HORDE", label = "Horde", color = { r = 0.80, g = 0.16, b = 0.16 } },
    { id = "ALLIANCE", label = "Alliance", color = { r = 0.24, g = 0.51, b = 0.96 } },
    { id = "MIDNIGHT", label = "Midnight", color = { r = 0.52, g = 0.45, b = 0.92 } },
    { id = "AMBER", label = "Amber", color = { r = 0.98, g = 0.65, b = 0.18 } },
    { id = "ROSE", label = "Rose", color = { r = 0.92, g = 0.43, b = 0.61 } },
    { id = "EMERALD", label = "Emerald", color = { r = 0.20, g = 0.82, b = 0.58 } },
    { id = "CUSTOM", label = "Custom" },
}

local function ClampColorChannel(value)
    return math.max(0, math.min(1, tonumber(value) or 0))
end

local function NormalizeThemeColor(color)
    color = color or {}
    return {
        r = ClampColorChannel(color.r),
        g = ClampColorChannel(color.g),
        b = ClampColorChannel(color.b),
    }
end

local function GetThemePresetByID(themeID)
    for _, preset in ipairs(addonTable.ThemePresets) do
        if preset.id == themeID then
            return preset
        end
    end
    return addonTable.ThemePresets[1]
end

function addonTable.GetThemePreset()
    return OakLFGSorterDB and OakLFGSorterDB.themePreset or "CLASS"
end

function addonTable.GetThemeCustomColor()
    OakLFGSorterDB.themeCustomColor = NormalizeThemeColor(OakLFGSorterDB.themeCustomColor)
    return OakLFGSorterDB.themeCustomColor
end

function addonTable.GetThemeAccentColor(themeID)
    local preset = GetThemePresetByID(themeID or addonTable.GetThemePreset())
    if preset.id == "CLASS" then
        return addonTable.PlayerClassColor
    end
    if preset.id == "CUSTOM" then
        return addonTable.GetThemeCustomColor()
    end
    return NormalizeThemeColor(preset.color)
end

function addonTable.GetThemePresetLabel(themeID)
    local preset = GetThemePresetByID(themeID or addonTable.GetThemePreset())
    return preset.label or preset.id or "Class Colored"
end

local function NotifyThemeRefreshers()
    for _, callback in pairs(registeredThemeRefreshers) do
        pcall(callback)
    end
end

function addonTable.ApplyTheme()
    addonTable.ClassColor = addonTable.GetThemeAccentColor()
    NotifyThemeRefreshers()
    if addonTable.ApplyWindowOpacity then addonTable.ApplyWindowOpacity() end
    if addonTable.RefreshRegisteredFontDropdowns then addonTable.RefreshRegisteredFontDropdowns() end
    if addonTable.UpdateDisplay then addonTable.UpdateDisplay() end
    if addonTable.UpdateTopBarActions then addonTable.UpdateTopBarActions() end
    if addonTable.UpdateSearchQuickSignupControls then addonTable.UpdateSearchQuickSignupControls() end
    if addonTable.RefreshOptionsPanel then addonTable.RefreshOptionsPanel() end
end

function addonTable.SetThemePreset(themeID)
    OakLFGSorterDB.themePreset = GetThemePresetByID(themeID).id
    addonTable.ApplyTheme()
end

function addonTable.SetThemeCustomColor(color)
    OakLFGSorterDB.themeCustomColor = NormalizeThemeColor(color)
    OakLFGSorterDB.themePreset = "CUSTOM"
    addonTable.ApplyTheme()
end

function addonTable.OpenThemeColorPicker()
    local previousPreset = addonTable.GetThemePreset()
    local color = addonTable.GetThemeCustomColor()
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        local pickerInfo = {
            r = color.r,
            g = color.g,
            b = color.b,
            hasOpacity = false,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                addonTable.SetThemeCustomColor({ r = r, g = g, b = b })
            end,
            cancelFunc = function(previous)
                if previous then
                    OakLFGSorterDB.themeCustomColor = NormalizeThemeColor({
                        r = previous.r,
                        g = previous.g,
                        b = previous.b,
                    })
                    OakLFGSorterDB.themePreset = previousPreset
                    addonTable.ApplyTheme()
                end
            end,
        }
        ColorPickerFrame:SetupColorPickerAndShow(pickerInfo)
    end
end

function addonTable.CreateFontDropdown(parent, width)
    local dropdownButton = addonTable.CreateFlatButton(parent, addonTable.GetActiveFontName(), width)
    local listFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    listFrame:SetSize(width + 18, 224)
    listFrame:SetBackdrop({
        bgFile = addonTable.FLAT_TEX,
        edgeFile = addonTable.FLAT_TEX,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    listFrame:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
    listFrame:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    listFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    listFrame:Hide()

    fontDropdownCounter = fontDropdownCounter + 1
    local scrollFrame = CreateFrame("ScrollFrame", "OakLFGFontDropdownScroll" .. fontDropdownCounter, listFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 1, -1)
    scrollFrame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -24, 1)

    local scrollBar = _G[scrollFrame:GetName() .. "ScrollBar"]
    local scrollThumb
    if scrollBar then
        local upBtn = _G[scrollFrame:GetName() .. "ScrollBarScrollUpButton"]
        local downBtn = _G[scrollFrame:GetName() .. "ScrollBarScrollDownButton"]
        if upBtn then upBtn:Hide(); upBtn:SetSize(0.1, 0.1) end
        if downBtn then downBtn:Hide(); downBtn:SetSize(0.1, 0.1) end
        local topTex = _G[scrollFrame:GetName() .. "ScrollBarTop"]
        local bottomTex = _G[scrollFrame:GetName() .. "ScrollBarBottom"]
        local midTex = _G[scrollFrame:GetName() .. "ScrollBarMiddle"]
        if topTex then topTex:Hide() end
        if bottomTex then bottomTex:Hide() end
        if midTex then midTex:Hide() end
        scrollThumb = scrollBar:GetThumbTexture()
        if scrollThumb then
            scrollThumb:SetTexture(addonTable.FLAT_TEX)
            scrollThumb:SetVertexColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
            scrollThumb:SetSize(8, 60)
        end
        scrollBar:SetWidth(8)
    end

    local child = CreateFrame("Frame")
    child:SetSize(width, 1)
    scrollFrame:SetScrollChild(child)

    local optionButtons = {}

    local function RefreshOptions()
        local fontNames = addonTable.GetAvailableFontNames()
        child:SetHeight(math.max(1, #fontNames * 22))

        for _, button in ipairs(optionButtons) do
            button:Hide()
        end

        for index, fontName in ipairs(fontNames) do
            local optionButton = optionButtons[index]
            if not optionButton then
                optionButton = CreateFrame("Button", nil, child, "BackdropTemplate")
                optionButton.bg = optionButton:CreateTexture(nil, "BACKGROUND")
                optionButton.bg:SetAllPoints()
                optionButton.text = optionButton:CreateFontString(nil, "OVERLAY")
                optionButton.text:SetPoint("LEFT", optionButton, "LEFT", 8, 0)
                optionButton.text:SetPoint("RIGHT", optionButton, "RIGHT", -8, 0)
                optionButton.text:SetJustifyH("LEFT")
                optionButtons[index] = optionButton
            end

            optionButton:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -((index - 1) * 22))
            optionButton:SetSize(width, 22)
            optionButton.bg:SetColorTexture(unpack(addonTable.OAK_COLOR_BG))

            local fontPath = addonTable.GetFontPath(fontName)
            optionButton.text:SetFont(fontPath, 12, "")
            optionButton.text:SetShadowColor(0, 0, 0, 1)
            optionButton.text:SetShadowOffset(1, -1)
            optionButton.text:SetText(fontName)
            optionButton:SetScript("OnEnter", function(self)
                self.bg:SetColorTexture(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 0.28)
            end)
            optionButton:SetScript("OnLeave", function(self)
                self.bg:SetColorTexture(unpack(addonTable.OAK_COLOR_BG))
            end)
            optionButton:SetScript("OnClick", function()
                addonTable.SetActiveFont(fontName)
                addonTable.RefreshRegisteredFontDropdowns()
                listFrame:Hide()
            end)
            optionButton:Show()
        end
    end

    function dropdownButton:RefreshSelection()
        self.text:SetText(addonTable.GetActiveFontName())
    end

    dropdownButton:SetScript("OnClick", function(self)
        RefreshOptions()
        if listFrame:IsShown() then
            listFrame:Hide()
        else
            listFrame:ClearAllPoints()
            listFrame:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
            listFrame:Show()
        end
    end)

    addonTable.RegisterFontDropdown(dropdownButton)
    addonTable.RegisterThemeRefresh("font_dropdown_" .. tostring(dropdownButton), function()
        listFrame:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
        listFrame:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
        if scrollThumb then
            scrollThumb:SetVertexColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
        end
        if listFrame:IsShown() then
            RefreshOptions()
        end
    end)
    dropdownButton:RefreshSelection()

    return dropdownButton, listFrame
end

addonTable.SetActiveFont(OakLFGSorterDB.fontName)

local fontEventFrame = CreateFrame("Frame")
fontEventFrame:RegisterEvent("PLAYER_LOGIN")
fontEventFrame:SetScript("OnEvent", function()
    ReapplySavedFont()
    addonTable.ApplyTheme()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, ReapplySavedFont)
        C_Timer.After(0, addonTable.ApplyTheme)
        C_Timer.After(1, ReapplySavedFont)
        C_Timer.After(1, addonTable.ApplyTheme)
    end
end)

if LSM and LSM.RegisterCallback then
    pcall(function()
        LSM:RegisterCallback(addonTable, "LibSharedMedia_Registered", function(_, mediaType)
            if mediaType == "font" then
                ReapplySavedFont()
            end
        end)
    end)
end

-- Colors & Styling
addonTable.ClassColor = addonTable.GetThemeAccentColor()

addonTable.FLAT_TEX = "Interface\\Buttons\\WHITE8X8"
addonTable.OAK_COLOR_BG = {0.106, 0.106, 0.129, 0.85} 
addonTable.OAK_COLOR_PANE = {0.137, 0.141, 0.172, 1}
addonTable.OAK_COLOR_BORDER = {0, 0, 0, 1}
addonTable.ROW_COLOR_A = {0.2, 0.22, 0.28, 0.4} 
addonTable.ROW_COLOR_B = {0, 0, 0, 0} 

addonTable.RoleTexCoords = {
    ["TANK"] = {0, 19/64, 22/64, 41/64},
    ["HEALER"] = {20/64, 39/64, 1/64, 20/64},
    ["DAMAGER"] = {20/64, 39/64, 22/64, 41/64}
}

addonTable.ValidClasses = {
    "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER",
    "MAGE", "MONK", "PALADIN", "PRIEST", "ROGUE",
    "SHAMAN", "WARLOCK", "WARRIOR"
}

addonTable.LustClasses = {
    MAGE = true, SHAMAN = true, HUNTER = true, EVOKER = true,
}

addonTable.BrezClasses = {
    DEATHKNIGHT = true, DRUID = true, WARLOCK = true, PALADIN = true,
}

-- Custom Spec Abbreviations
addonTable.SpecShortNames = {
    -- Death Knight
    [250] = "BDK", [251] = "FDK", [252] = "Unh",
    -- Demon Hunter
    [577] = "Hav", [581] = "Veng", [1480] = "Devo",
    -- Druid
    [102] = "Bal", [103] = "Fer", [104] = "Guard", [105] = "Resto",
    -- Evoker
    [1467] = "Dev", [1468] = "Pres", [1473] = "Aug",
    -- Hunter
    [253] = "BM", [254] = "MM", [255] = "Surv",
    -- Mage
    [62] = "Arc", [63] = "Fire", [64] = "Frost",
    -- Monk
    [268] = "Brew", [269] = "WW", [270] = "MW",
    -- Paladin
    [65] = "Holy", [66] = "Prot", [70] = "Ret",
    -- Priest
    [256] = "Disc", [257] = "Holy", [258] = "Shad",
    -- Rogue
    [259] = "Assa", [260] = "Out", [261] = "Sub",
    -- Shaman
    [262] = "Ele", [263] = "Enh", [264] = "Resto",
    -- Warlock
    [265] = "Aff", [266] = "Demo", [267] = "Destro",
    -- Warrior
    [71] = "Arms", [72] = "Fury", [73] = "Prot"
}

function addonTable.ApplyClassColor(text, classStr)
    local c = RAID_CLASS_COLORS[string.upper(classStr or "")]
    if c then return string.format("|cFF%02x%02x%02x%s|r", c.r*255, c.g*255, c.b*255, text) end
    return "|cFFFFFFFF" .. (text or "") .. "|r"
end

function addonTable.ClassProvidesLust(classStr)
    return addonTable.LustClasses[string.upper(classStr or "")] or false
end

function addonTable.ClassProvidesBrez(classStr)
    return addonTable.BrezClasses[string.upper(classStr or "")] or false
end

function addonTable.GetCurrentViewMode()
    if C_LFGList and C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo() then
        return "applicants"
    end

    return "browser"
end

function addonTable.CreateFlatButton(parent, label, width)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, 22)
    btn:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
    btn:SetBackdropColor(unpack(addonTable.OAK_COLOR_PANE)) 
    btn:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    
    btn.text = btn:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(label)
    
    btn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER)) end)
    return btn
end

function addonTable.CreateThemeDropdown(parent, width)
    local dropdownButton = addonTable.CreateFlatButton(parent, addonTable.GetThemePresetLabel(), width)
    local listFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    listFrame:SetSize(width + 18, (#addonTable.ThemePresets * 22) + 2)
    listFrame:SetBackdrop({
        bgFile = addonTable.FLAT_TEX,
        edgeFile = addonTable.FLAT_TEX,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    listFrame:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
    listFrame:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    listFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    listFrame:Hide()

    fontDropdownCounter = fontDropdownCounter + 1
    local scrollFrame = CreateFrame("ScrollFrame", "OakLFGThemeDropdownScroll" .. fontDropdownCounter, listFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 1, -1)
    scrollFrame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -24, 1)

    local scrollBar = _G[scrollFrame:GetName() .. "ScrollBar"]
    local scrollThumb
    if scrollBar then
        local upBtn = _G[scrollFrame:GetName() .. "ScrollBarScrollUpButton"]
        local downBtn = _G[scrollFrame:GetName() .. "ScrollBarScrollDownButton"]
        if upBtn then upBtn:Hide(); upBtn:SetSize(0.1, 0.1) end
        if downBtn then downBtn:Hide(); downBtn:SetSize(0.1, 0.1) end
        local topTex = _G[scrollFrame:GetName() .. "ScrollBarTop"]
        local bottomTex = _G[scrollFrame:GetName() .. "ScrollBarBottom"]
        local midTex = _G[scrollFrame:GetName() .. "ScrollBarMiddle"]
        if topTex then topTex:Hide() end
        if bottomTex then bottomTex:Hide() end
        if midTex then midTex:Hide() end
        scrollThumb = scrollBar:GetThumbTexture()
        if scrollThumb then
            scrollThumb:SetTexture(addonTable.FLAT_TEX)
            scrollThumb:SetSize(8, 60)
        end
        scrollBar:SetWidth(8)
    end

    local child = CreateFrame("Frame")
    child:SetSize(width, 1)
    scrollFrame:SetScrollChild(child)

    local optionButtons = {}

    local function RefreshSelection()
        dropdownButton.text:SetText(addonTable.GetThemePresetLabel())
    end

    local function RefreshOptions()
        child:SetHeight(math.max(1, #addonTable.ThemePresets * 22))
        for _, button in ipairs(optionButtons) do
            button:Hide()
        end

        for index, preset in ipairs(addonTable.ThemePresets) do
            local optionButton = optionButtons[index]
            if not optionButton then
                optionButton = CreateFrame("Button", nil, child, "BackdropTemplate")
                optionButton.bg = optionButton:CreateTexture(nil, "BACKGROUND")
                optionButton.bg:SetAllPoints()
                optionButton.swatch = optionButton:CreateTexture(nil, "ARTWORK")
                optionButton.swatch:SetSize(10, 10)
                optionButton.swatch:SetPoint("LEFT", optionButton, "LEFT", 8, 0)
                optionButton.text = optionButton:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
                optionButton.text:SetPoint("LEFT", optionButton.swatch, "RIGHT", 8, 0)
                optionButton.text:SetPoint("RIGHT", optionButton, "RIGHT", -8, 0)
                optionButton.text:SetJustifyH("LEFT")
                optionButtons[index] = optionButton
            end

            optionButton:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -((index - 1) * 22))
            optionButton:SetSize(width, 22)
            optionButton.bg:SetColorTexture(unpack(addonTable.OAK_COLOR_BG))
            local swatchColor = addonTable.GetThemeAccentColor(preset.id)
            optionButton.swatch:SetColorTexture(swatchColor.r, swatchColor.g, swatchColor.b, 1)
            optionButton.text:SetText(preset.label)
            optionButton:SetScript("OnEnter", function(self)
                self.bg:SetColorTexture(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 0.28)
            end)
            optionButton:SetScript("OnLeave", function(self)
                self.bg:SetColorTexture(unpack(addonTable.OAK_COLOR_BG))
            end)
            optionButton:SetScript("OnClick", function()
                addonTable.SetThemePreset(preset.id)
                listFrame:Hide()
            end)
            optionButton:Show()
        end
    end

    function dropdownButton:RefreshSelection()
        RefreshSelection()
    end

    dropdownButton:SetScript("OnClick", function(self)
        RefreshOptions()
        if listFrame:IsShown() then
            listFrame:Hide()
        else
            listFrame:ClearAllPoints()
            listFrame:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
            listFrame:Show()
        end
    end)

    addonTable.RegisterThemeRefresh("theme_dropdown_" .. tostring(dropdownButton), function()
        listFrame:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
        listFrame:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
        if scrollThumb then
            scrollThumb:SetVertexColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
        end
        RefreshSelection()
        if listFrame:IsShown() then
            RefreshOptions()
        end
    end)
    dropdownButton:RefreshSelection()

    return dropdownButton, listFrame
end

function addonTable.CreateCogButton(parent, size)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(size, size)
    btn:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
    btn:SetBackdropColor(unpack(addonTable.OAK_COLOR_PANE))
    btn:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(size - 8, size - 8)
    btn.icon:SetPoint("CENTER")
    btn.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")

    btn.fallback = btn:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    btn.fallback:SetPoint("CENTER")
    btn.fallback:SetText("O")
    btn.fallback:SetAlpha(0)

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    end)

    return btn
end
