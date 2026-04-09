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
if OakLFGSorterDB.hideMinimapButton == nil then OakLFGSorterDB.hideMinimapButton = false end
if OakLFGSorterDB.browserCategoryKey == nil then OakLFGSorterDB.browserCategoryKey = "DUNGEONS" end
if type(OakLFGSorterDB.browserCategoryOverrides) ~= "table" then OakLFGSorterDB.browserCategoryOverrides = {} end
if OakLFGSorterDB.autoHideFilledRoles == nil then OakLFGSorterDB.autoHideFilledRoles = false end
if OakLFGSorterDB.showRegions == nil then OakLFGSorterDB.showRegions = false end
if OakLFGSorterDB.lowLatencyOnly == nil then OakLFGSorterDB.lowLatencyOnly = false end
if OakLFGSorterDB.fontName == nil then OakLFGSorterDB.fontName = "OakUI Font" end
if OakLFGSorterDB.fontSize == nil then OakLFGSorterDB.fontSize = 12 end
if OakLFGSorterDB.windowOpacity == nil then OakLFGSorterDB.windowOpacity = 0.85 end
if OakLFGSorterDB.themeStyle == nil then OakLFGSorterDB.themeStyle = "OAK" end
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
local registeredFlatButtons = {}
local registeredCogButtons = {}

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

local function ClampColorChannel(value)
    return math.max(0, math.min(1, tonumber(value) or 0))
end

local function NormalizeThemeColor(color)
    color = color or {}
    local r = color.r
    local g = color.g
    local b = color.b
    local a = color.a

    if r == nil then r = color[1] end
    if g == nil then g = color[2] end
    if b == nil then b = color[3] end
    if a == nil then a = color[4] end

    return {
        r = ClampColorChannel(r),
        g = ClampColorChannel(g),
        b = ClampColorChannel(b),
        a = a ~= nil and ClampColorChannel(a) or nil,
    }
end

local function CopyThemeArray(color)
    color = NormalizeThemeColor(color)
    if color.a ~= nil then
        return { color.r, color.g, color.b, color.a }
    end
    return { color.r, color.g, color.b }
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

addonTable.ThemeStyles = {
    {
        id = "OAK",
        label = "Oak",
        colors = {
            bg = { 0.07, 0.10, 0.085, 0.93 },
            pane = { 0.11, 0.16, 0.13, 1.0 },
            border = { 0, 0, 0, 1.0 },
            rowA = { 0.17, 0.24, 0.19, 0.48 },
            rowB = { 0.08, 0.12, 0.10, 0.22 },
            stickyPanel = { 0.10, 0.19, 0.12, 0.97 },
            contextBar = { 0.11, 0.16, 0.13, 0.88 },
            quickSignupBar = { 0.11, 0.16, 0.13, 0.88 },
            sliderTrack = { 0.03, 0.05, 0.04, 1.0 },
            buttonInactive = { 0.11, 0.16, 0.13, 1.0 },
            toggleOffFill = { 0.06, 0.09, 0.075, 0.97 },
            titleBar = { 0.15, 0.22, 0.17, 1.0 },
            dropdownHover = { 0.86, 1.0, 0.90, 0.14 },
            stickyAccent = { 1.0, 1.0, 1.0, 1.0 },
            stickyAccentSoft = { 0.85, 0.95, 0.86, 0.95 },
            titleTint = { 0.90, 1.0, 0.90, 1.0 },
        },
    },
    {
        id = "DARK",
        label = "Dark",
        colors = {
            bg = { 0.045, 0.045, 0.055, 0.95 },
            pane = { 0.085, 0.085, 0.10, 1.0 },
            border = { 0.015, 0.015, 0.02, 1.0 },
            rowA = { 0.12, 0.12, 0.14, 0.55 },
            rowB = { 0.07, 0.07, 0.08, 0.35 },
            stickyPanel = { 0.06, 0.09, 0.06, 0.98 },
            contextBar = { 0.07, 0.07, 0.08, 0.88 },
            quickSignupBar = { 0.07, 0.07, 0.08, 0.88 },
            sliderTrack = { 0.025, 0.025, 0.03, 1.0 },
            buttonInactive = { 0.10, 0.10, 0.12, 1.0 },
            toggleOffFill = { 0.06, 0.06, 0.07, 0.97 },
            titleBar = { 0.09, 0.09, 0.10, 1.0 },
            dropdownHover = { 1, 1, 1, 0.08 },
            stickyAccent = { 1.0, 1.0, 1.0, 1.0 },
            stickyAccentSoft = { 0.82, 0.82, 0.82, 0.85 },
            titleTint = { 0.96, 0.96, 0.96, 1.0 },
        },
    },
    {
        id = "AMBER",
        label = "Amber",
        colors = {
            bg = { 0.20, 0.17, 0.12, 0.97 },
            pane = { 0.34, 0.28, 0.18, 1.0 },
            border = { 0.11, 0.08, 0.04, 1.0 },
            rowA = { 0.42, 0.33, 0.20, 0.55 },
            rowB = { 0.24, 0.19, 0.11, 0.28 },
            stickyPanel = { 0.29, 0.28, 0.14, 0.96 },
            contextBar = { 0.30, 0.24, 0.15, 0.90 },
            quickSignupBar = { 0.30, 0.24, 0.15, 0.90 },
            sliderTrack = { 0.16, 0.12, 0.07, 1.0 },
            buttonInactive = { 0.36, 0.29, 0.19, 1.0 },
            toggleOffFill = { 0.22, 0.17, 0.11, 0.98 },
            titleBar = { 0.42, 0.31, 0.16, 1.0 },
            dropdownHover = { 1.0, 0.93, 0.70, 0.18 },
            stickyAccent = { 1.0, 0.95, 0.80, 1.0 },
            stickyAccentSoft = { 0.96, 0.86, 0.58, 0.95 },
            titleTint = { 1.0, 0.94, 0.72, 1.0 },
        },
    },
    {
        id = "BLIZZARD",
        label = "Blizzard",
        colors = {
            bg = { 0.18, 0.15, 0.11, 0.96 },
            pane = { 0.28, 0.22, 0.14, 1.0 },
            border = { 0.09, 0.07, 0.03, 1.0 },
            rowA = { 0.37, 0.29, 0.18, 0.48 },
            rowB = { 0.22, 0.17, 0.10, 0.24 },
            stickyPanel = { 0.25, 0.24, 0.12, 0.95 },
            contextBar = { 0.26, 0.21, 0.13, 0.88 },
            quickSignupBar = { 0.26, 0.21, 0.13, 0.88 },
            sliderTrack = { 0.14, 0.10, 0.06, 1.0 },
            buttonInactive = { 0.30, 0.24, 0.15, 1.0 },
            toggleOffFill = { 0.20, 0.15, 0.09, 0.97 },
            titleBar = { 0.33, 0.25, 0.13, 1.0 },
            dropdownHover = { 1.0, 0.92, 0.68, 0.14 },
            stickyAccent = { 1.0, 0.95, 0.82, 1.0 },
            stickyAccentSoft = { 0.94, 0.84, 0.60, 0.92 },
            titleTint = { 1.0, 0.94, 0.76, 1.0 },
        },
    },
}

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

local function GetThemeStyleByID(styleID)
    for _, style in ipairs(addonTable.ThemeStyles) do
        if style.id == styleID then
            return style
        end
    end
    return addonTable.ThemeStyles[1]
end

local function GetThemePresetByID(themeID)
    for _, preset in ipairs(addonTable.ThemePresets) do
        if preset.id == themeID then
            return preset
        end
    end
    return addonTable.ThemePresets[1]
end

function addonTable.GetThemeStyle()
    return OakLFGSorterDB and OakLFGSorterDB.themeStyle or "OAK"
end

function addonTable.GetThemeStyleLabel(styleID)
    local style = GetThemeStyleByID(styleID or addonTable.GetThemeStyle())
    return style.label or style.id or "Oak"
end

function addonTable.GetThemeStyleColors(styleID)
    local style = GetThemeStyleByID(styleID or addonTable.GetThemeStyle())
    return style.colors or addonTable.ThemeStyles[1].colors
end

function addonTable.GetThemePreset()
    return OakLFGSorterDB and OakLFGSorterDB.themePreset or "CLASS"
end

function addonTable.GetThemeCustomColor()
    OakLFGSorterDB.themeCustomColor = NormalizeThemeColor(OakLFGSorterDB.themeCustomColor)
    return OakLFGSorterDB.themeCustomColor
end

function addonTable.GetThemeColor(name, styleID)
    local styleColors = addonTable.GetThemeStyleColors(styleID)
    local color = styleColors and styleColors[name]
    if not color then
        return nil
    end
    return CopyThemeArray(color)
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

local function RefreshRegisteredButtons()
    for key, button in pairs(registeredFlatButtons) do
        if button and button.SetBackdropColor then
            if addonTable.ApplyBackdropStyle then
                addonTable.ApplyBackdropStyle(button, "button")
            end
            button:SetBackdropColor(unpack(addonTable.OAK_COLOR_PANE))
            button:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
        else
            registeredFlatButtons[key] = nil
        end
    end

    for key, button in pairs(registeredCogButtons) do
        if button and button.SetBackdropColor then
            if addonTable.ApplyBackdropStyle then
                addonTable.ApplyBackdropStyle(button, "button")
            end
            button:SetBackdropColor(unpack(addonTable.OAK_COLOR_PANE))
            button:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
        else
            registeredCogButtons[key] = nil
        end
    end
end

function addonTable.ApplyTheme()
    local styleColors = addonTable.GetThemeStyleColors()
    addonTable.ClassColor = addonTable.GetThemeAccentColor()
    addonTable.OAK_COLOR_BG = CopyThemeArray(styleColors.bg)
    addonTable.OAK_COLOR_PANE = CopyThemeArray(styleColors.pane)
    addonTable.OAK_COLOR_BORDER = CopyThemeArray(styleColors.border)
    addonTable.ROW_COLOR_A = CopyThemeArray(styleColors.rowA)
    addonTable.ROW_COLOR_B = CopyThemeArray(styleColors.rowB)
    addonTable.OAK_COLOR_STICKY = CopyThemeArray(styleColors.stickyPanel)
    addonTable.OAK_COLOR_CONTEXT = CopyThemeArray(styleColors.contextBar)
    addonTable.OAK_COLOR_QUICKSIGNUP = CopyThemeArray(styleColors.quickSignupBar)
    addonTable.OAK_COLOR_SLIDER_TRACK = CopyThemeArray(styleColors.sliderTrack)
    addonTable.OAK_COLOR_TOGGLE_OFF = CopyThemeArray(styleColors.toggleOffFill)
    addonTable.OAK_COLOR_TITLEBAR = CopyThemeArray(styleColors.titleBar)
    addonTable.OAK_COLOR_DROPDOWN_HOVER = CopyThemeArray(styleColors.dropdownHover)
    addonTable.OAK_COLOR_STICKY_ACCENT = CopyThemeArray(styleColors.stickyAccent)
    addonTable.OAK_COLOR_STICKY_ACCENT_SOFT = CopyThemeArray(styleColors.stickyAccentSoft)
    addonTable.OAK_COLOR_TITLE_TINT = CopyThemeArray(styleColors.titleTint)
    RefreshRegisteredButtons()
    NotifyThemeRefreshers()
    if addonTable.ApplyWindowOpacity then addonTable.ApplyWindowOpacity() end
    if addonTable.RefreshRegisteredFontDropdowns then addonTable.RefreshRegisteredFontDropdowns() end
    if addonTable.UpdateDisplay then addonTable.UpdateDisplay() end
    if addonTable.UpdateTopBarActions then addonTable.UpdateTopBarActions() end
    if addonTable.UpdateSearchQuickSignupControls then addonTable.UpdateSearchQuickSignupControls() end
    if addonTable.RefreshOptionsPanel then addonTable.RefreshOptionsPanel() end
end

function addonTable.SetThemeStyle(styleID)
    OakLFGSorterDB.themeStyle = GetThemeStyleByID(styleID).id
    addonTable.ApplyTheme()
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
addonTable.FLAT_TEX = "Interface\\Buttons\\WHITE8X8"
addonTable.ClassColor = addonTable.GetThemeAccentColor()
addonTable.OAK_COLOR_BG = {0.106, 0.106, 0.129, 0.85}
addonTable.OAK_COLOR_PANE = {0.137, 0.141, 0.172, 1}
addonTable.OAK_COLOR_BORDER = {0, 0, 0, 1}
addonTable.ROW_COLOR_A = {0.2, 0.22, 0.28, 0.4}
addonTable.ROW_COLOR_B = {0, 0, 0, 0}

function addonTable.GetBackdropStyle(kind)
    local style = addonTable.GetThemeStyle and addonTable.GetThemeStyle() or "OAK"
    if style == "BLIZZARD" then
        if kind == "button" then
            return {
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            }
        elseif kind == "inset" then
            return {
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            }
        end
        return {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 24,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        }
    end

    return {
        bgFile = addonTable.FLAT_TEX,
        edgeFile = addonTable.FLAT_TEX,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    }
end

function addonTable.ApplyBackdropStyle(frame, kind)
    if frame and frame.SetBackdrop then
        frame:SetBackdrop(addonTable.GetBackdropStyle(kind))
    end
end

function addonTable.GetThemeFramePadding()
    local style = addonTable.GetThemeStyle and addonTable.GetThemeStyle() or "OAK"
    if style == "BLIZZARD" then
        return 8
    end
    return 0
end

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
    addonTable.ApplyBackdropStyle(btn, "button")
    btn:SetBackdropColor(unpack(addonTable.OAK_COLOR_PANE)) 
    btn:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))

    btn.text = btn:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(label)

    btn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER)) end)
    registeredFlatButtons[btn] = btn
    return btn
end

function addonTable.CreateSimpleDropdown(parent, width, labelProvider, optionListProvider, onSelect)
    local dropdownButton = addonTable.CreateFlatButton(parent, labelProvider(), width)
    dropdownButton.arrow = dropdownButton:CreateTexture(nil, "ARTWORK")
    dropdownButton.arrow:SetSize(10, 10)
    dropdownButton.arrow:SetPoint("RIGHT", dropdownButton, "RIGHT", -6, 0)
    dropdownButton.arrow:SetTexture("Interface\\BUTTONS\\Arrow-Down-Up")
    dropdownButton.arrow:SetVertexColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    dropdownButton.text:ClearAllPoints()
    dropdownButton.text:SetPoint("LEFT", dropdownButton, "LEFT", 8, 0)
    dropdownButton.text:SetPoint("RIGHT", dropdownButton.arrow, "LEFT", -4, 0)
    dropdownButton.text:SetJustifyH("CENTER")

    local listFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    addonTable.ApplyBackdropStyle(listFrame, "panel")
    listFrame:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
    listFrame:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    listFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    listFrame:Hide()

    fontDropdownCounter = fontDropdownCounter + 1
    local scrollFrame = CreateFrame("ScrollFrame", "OakLFGSimpleDropdownScroll" .. fontDropdownCounter, listFrame, "UIPanelScrollFrameTemplate")
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
        dropdownButton.text:SetText(labelProvider())
    end

    local function RefreshOptions()
        local options = optionListProvider() or {}
        local height = math.min(#options, 8) * 22 + 2
        listFrame:SetSize(width + 18, math.max(height, 24))
        child:SetHeight(math.max(1, #options * 22))

        for _, button in ipairs(optionButtons) do
            button:Hide()
        end

        for index, option in ipairs(options) do
            local optionButton = optionButtons[index]
            if not optionButton then
                optionButton = CreateFrame("Button", nil, child, "BackdropTemplate")
                optionButton.bg = optionButton:CreateTexture(nil, "BACKGROUND")
                optionButton.bg:SetAllPoints()
                optionButton.separator = optionButton:CreateTexture(nil, "ARTWORK")
                optionButton.separator:SetHeight(1)
                optionButton.separator:SetPoint("LEFT", optionButton, "LEFT", 8, 0)
                optionButton.separator:SetPoint("RIGHT", optionButton, "RIGHT", -8, 0)
                optionButton.text = optionButton:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
                optionButton.text:SetPoint("LEFT", optionButton, "LEFT", 8, 0)
                optionButton.text:SetPoint("RIGHT", optionButton, "RIGHT", -8, 0)
                optionButton.text:SetJustifyH("LEFT")
                optionButtons[index] = optionButton
            end

            optionButton:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -((index - 1) * 22))
            optionButton:SetSize(width, 22)
            optionButton.bg:SetColorTexture(unpack(addonTable.OAK_COLOR_BG))
            optionButton.text:SetText(option.label)
            if option.separator then
                optionButton.separator:SetColorTexture(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 0.45)
                optionButton.separator:Show()
                optionButton.text:ClearAllPoints()
                optionButton.text:SetPoint("CENTER", optionButton, "CENTER", 0, 0)
                optionButton.text:SetTextColor(0.85, 0.85, 0.85)
                optionButton:SetScript("OnEnter", nil)
                optionButton:SetScript("OnLeave", nil)
                optionButton:SetScript("OnClick", nil)
            else
                optionButton.separator:Hide()
                optionButton.text:ClearAllPoints()
                optionButton.text:SetPoint("LEFT", optionButton, "LEFT", 8, 0)
                optionButton.text:SetPoint("RIGHT", optionButton, "RIGHT", -8, 0)
                optionButton.text:SetTextColor(1, 1, 1)
                optionButton:SetScript("OnEnter", function(self)
                    self.bg:SetColorTexture(unpack(addonTable.OAK_COLOR_DROPDOWN_HOVER))
                end)
                optionButton:SetScript("OnLeave", function(self)
                    self.bg:SetColorTexture(unpack(addonTable.OAK_COLOR_BG))
                end)
                optionButton:SetScript("OnClick", function()
                    onSelect(option.id, option)
                    listFrame:Hide()
                end)
            end
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

    addonTable.RegisterThemeRefresh("simple_dropdown_" .. tostring(dropdownButton), function()
        listFrame:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
        listFrame:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
        if dropdownButton.arrow then
            dropdownButton.arrow:SetVertexColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
        end
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

function addonTable.CreateThemeDropdown(parent, width)
    return addonTable.CreateSimpleDropdown(
        parent,
        width,
        function() return addonTable.GetThemePresetLabel() end,
        function()
            local options = {}
            for _, preset in ipairs(addonTable.ThemePresets) do
                table.insert(options, { id = preset.id, label = preset.label })
            end
            return options
        end,
        function(id)
            addonTable.SetThemePreset(id)
        end
    )
end

function addonTable.CreateThemeStyleDropdown(parent, width)
    return addonTable.CreateSimpleDropdown(
        parent,
        width,
        function() return addonTable.GetThemeStyleLabel() end,
        function()
            local options = {}
            for _, style in ipairs(addonTable.ThemeStyles) do
                table.insert(options, { id = style.id, label = style.label })
            end
            return options
        end,
        function(id)
            addonTable.SetThemeStyle(id)
        end
    )
end

function addonTable.CreateCogButton(parent, size)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(size, size)
    addonTable.ApplyBackdropStyle(btn, "button")
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
    registeredCogButtons[btn] = btn

    return btn
end
