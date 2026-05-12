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

BINDING_HEADER_OAKLFGSORTER = "OAK LFG Sorter"
BINDING_NAME_OAKLFGSORTER_TOGGLEBROWSER = "Toggle Browser Window"

-- Global Database
OakLFGSorterDB = OakLFGSorterDB or SorterClassicDB or {}
OakLFGSorterCharDB = OakLFGSorterCharDB or SorterClassicCharDB or {}
SorterClassicDB = OakLFGSorterDB
SorterClassicCharDB = OakLFGSorterCharDB
if OakLFGSorterDB.autoOpen == nil then OakLFGSorterDB.autoOpen = true end
if OakLFGSorterDB.scale == nil then OakLFGSorterDB.scale = 1.0 end
if OakLFGSorterDB.muteApplicantPing == nil then OakLFGSorterDB.muteApplicantPing = true end
if OakLFGSorterDB.hideNotes == nil then OakLFGSorterDB.hideNotes = false end
if OakLFGSorterDB.hideMinimapButton == nil then OakLFGSorterDB.hideMinimapButton = false end
if OakLFGSorterDB.browserCategoryKey == nil then OakLFGSorterDB.browserCategoryKey = "DUNGEONS" end
if type(OakLFGSorterDB.browserCategoryOverrides) ~= "table" then OakLFGSorterDB.browserCategoryOverrides = {} end
if OakLFGSorterDB.autoHideFilledRoles == nil then OakLFGSorterDB.autoHideFilledRoles = false end
if OakLFGSorterDB.showRegions == nil then OakLFGSorterDB.showRegions = false end
if OakLFGSorterDB.showRegionFlags == nil then OakLFGSorterDB.showRegionFlags = false end
if OakLFGSorterDB.lowLatencyOnly == nil then OakLFGSorterDB.lowLatencyOnly = false end
if OakLFGSorterDB.showPartyKeys == nil then OakLFGSorterDB.showPartyKeys = true end
if OakLFGSorterDB.mythicPlusPanelSide == nil then OakLFGSorterDB.mythicPlusPanelSide = "RIGHT" end
if OakLFGSorterDB.mythicPlusPanelOpen == nil then
    OakLFGSorterDB.mythicPlusPanelOpen = OakLFGSorterDB.keepMythicPlusPanelOpen == true
end
OakLFGSorterDB.keepMythicPlusPanelOpen = nil
if OakLFGSorterDB.attachBrowserTooltipToCursor == nil then OakLFGSorterDB.attachBrowserTooltipToCursor = false end
if OakLFGSorterDB.fontName == nil then OakLFGSorterDB.fontName = "Friz Quadrata TT" end
if OakLFGSorterDB.fontSize == nil then OakLFGSorterDB.fontSize = 12 end
if OakLFGSorterDB.windowOpacity == nil then OakLFGSorterDB.windowOpacity = 0.85 end
if OakLFGSorterDB.frameStrata == nil then OakLFGSorterDB.frameStrata = "DIALOG" end
if OakLFGSorterDB.theme ~= "modern" then OakLFGSorterDB.theme = "classic" end
if OakLFGSorterDB.themeStyle == nil then OakLFGSorterDB.themeStyle = "MODERN_CLEAN" end
if OakLFGSorterDB.themePreset == nil then OakLFGSorterDB.themePreset = "OAK_TEAL" end
if type(OakLFGSorterDB.themeCustomColor) ~= "table" then OakLFGSorterDB.themeCustomColor = nil end
if type(OakLFGSorterDB.regionFilters) ~= "table" then OakLFGSorterDB.regionFilters = {} end
OakLFGSorterDB.browserFilters = OakLFGSorterDB.browserFilters or {}

local function CopyBooleanMap(source)
    local copy = {}
    if type(source) ~= "table" then
        return copy
    end

    for key, value in pairs(source) do
        if value ~= nil then
            copy[key] = value and true or false
        end
    end

    return copy
end

local function CopyTable(source)
    local copy = {}
    if type(source) ~= "table" then
        return copy
    end

    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = CopyTable(value)
        else
            copy[key] = value
        end
    end

    return copy
end

local charDB = OakLFGSorterCharDB
if type(charDB.browserFilters) ~= "table" then
    charDB.browserFilters = CopyTable(OakLFGSorterDB.browserFilters)
end
if charDB.browserCategoryKey == nil then
    charDB.browserCategoryKey = OakLFGSorterDB.browserCategoryKey or "DUNGEONS"
end
if type(charDB.browserCategoryOverrides) ~= "table" then
    charDB.browserCategoryOverrides = CopyTable(OakLFGSorterDB.browserCategoryOverrides)
end
if type(charDB.regionFilters) ~= "table" then
    charDB.regionFilters = CopyBooleanMap(OakLFGSorterDB.regionFilters)
end
if type(charDB.hiddenDeclinedGroups) ~= "table" then
    charDB.hiddenDeclinedGroups = {}
end
if type(charDB.applicantClassFilters) ~= "table" then
    charDB.applicantClassFilters = {}
end
if type(charDB.applicantRoleFilters) ~= "table" then
    charDB.applicantRoleFilters = {}
end
if charDB.autoHideFilledRoles == nil then
    charDB.autoHideFilledRoles = OakLFGSorterDB.autoHideFilledRoles == true
end
for _, classToken in ipairs(addonTable.ValidClasses or {}) do
    if charDB.applicantClassFilters[classToken] == nil then
        charDB.applicantClassFilters[classToken] = true
    end
end
for _, roleToken in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
    if charDB.applicantRoleFilters[roleToken] == nil then
        charDB.applicantRoleFilters[roleToken] = true
    end
end

function addonTable.GetCharacterDB()
    OakLFGSorterCharDB = OakLFGSorterCharDB or charDB or {}
    return OakLFGSorterCharDB
end

function addonTable.GetCharacterBrowserFilters()
    local db = addonTable.GetCharacterDB()
    db.browserFilters = db.browserFilters or {}
    return db.browserFilters
end

function addonTable.GetCharacterBrowserCategoryKey()
    local db = addonTable.GetCharacterDB()
    db.browserCategoryKey = db.browserCategoryKey or "DUNGEONS"
    return db.browserCategoryKey
end

function addonTable.GetCharacterBrowserCategoryOverrides()
    local db = addonTable.GetCharacterDB()
    db.browserCategoryOverrides = db.browserCategoryOverrides or {}
    return db.browserCategoryOverrides
end

function addonTable.GetCharacterRegionFilters()
    local db = addonTable.GetCharacterDB()
    db.regionFilters = db.regionFilters or {}
    return db.regionFilters
end

function addonTable.GetApplicantClassFilters()
    local db = addonTable.GetCharacterDB()
    db.applicantClassFilters = db.applicantClassFilters or {}
    return db.applicantClassFilters
end

function addonTable.GetHiddenDeclinedGroups()
    local db = addonTable.GetCharacterDB()
    db.hiddenDeclinedGroups = db.hiddenDeclinedGroups or {}
    return db.hiddenDeclinedGroups
end

function addonTable.GetApplicantRoleFilters()
    local db = addonTable.GetCharacterDB()
    db.applicantRoleFilters = db.applicantRoleFilters or {}
    return db.applicantRoleFilters
end

function addonTable.GetCharacterAutoHideFilledRoles()
    local db = addonTable.GetCharacterDB()
    return db.autoHideFilledRoles == true
end

local browserFilters = addonTable.GetCharacterBrowserFilters()
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
if browserFilters.lustMatch == nil then browserFilters.lustMatch = (browserFilters.needsLust == true or browserFilters.hasLust == true) end
if browserFilters.needsLust == nil then browserFilters.needsLust = false end
if browserFilters.needsBrez == nil then browserFilters.needsBrez = false end
if browserFilters.hideDeclined == nil then browserFilters.hideDeclined = false end
if browserFilters.keepUnavailable == nil then browserFilters.keepUnavailable = true end
if type(browserFilters.selectedActivities) ~= "table" then browserFilters.selectedActivities = {} end
if browserFilters.raidBossKills == nil then browserFilters.raidBossKills = "" end
if browserFilters.raidTanks    == nil then browserFilters.raidTanks    = "" end
if browserFilters.raidHealers  == nil then browserFilters.raidHealers  = "" end
if browserFilters.raidDps      == nil then browserFilters.raidDps      = "" end

-- Font Registration
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local defaultFontPath = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

if LSM then
    LSM:Register("font", "OakUI Font", "Interface\\AddOns\\OakLFGSorter\\Media\\OakFont.ttf")
    LSM:Register("font", "Friz Quadrata TT", defaultFontPath)
end

addonTable.Fonts = {
    Regular = CreateFont("SorterClassic_FontRegular"),
    Large = CreateFont("SorterClassic_FontLarge"),
    Small = CreateFont("SorterClassic_FontSmall")
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
    local activeName = addonTable.GetActiveFontName and addonTable.GetActiveFontName() or "Friz Quadrata TT"
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

    return { "Friz Quadrata TT", "OakUI Font" }
end

function addonTable.GetActiveFontName()
    return OakLFGSorterDB and OakLFGSorterDB.fontName or "Friz Quadrata TT"
end

function addonTable.GetFontPath(fontName)
    return ResolveFontPath(fontName)
end

function addonTable.SetActiveFont(fontName)
    local resolvedName = (fontName and fontName ~= "") and fontName or "Friz Quadrata TT"
    local fontPath = ResolveFontPath(resolvedName)
    OakLFGSorterDB.fontName = resolvedName
    addonTable.ActiveFontPath = fontPath
    ApplyOakFont(fontPath)
    if addonTable.RefreshOptionsPanel then addonTable.RefreshOptionsPanel() end
    if addonTable.RefreshSearchOptionsPanel then addonTable.RefreshSearchOptionsPanel() end
    if addonTable.UpdateTopBarLayout then addonTable.UpdateTopBarLayout() end
    if addonTable.RefreshFooterButtonWidths then addonTable.RefreshFooterButtonWidths() end
    if addonTable.UpdateBrowserFilterPanel then addonTable.UpdateBrowserFilterPanel() end
    if addonTable.RefreshBrowserResponsiveLayout then addonTable.RefreshBrowserResponsiveLayout() end
    if addonTable.UpdateDisplay then addonTable.UpdateDisplay() end
end

function addonTable.GetFontSize()
    return math.max(10, math.min(18, tonumber(OakLFGSorterDB and OakLFGSorterDB.fontSize) or 12))
end

function addonTable.SetFontSize(sizeValue)
    local baseSize = math.max(10, math.min(18, tonumber(sizeValue) or 12))
    OakLFGSorterDB.fontSize = baseSize
    ApplyOakFont(addonTable.ActiveFontPath or ResolveFontPath(addonTable.GetActiveFontName()))
    if addonTable.UpdateTopBarLayout then addonTable.UpdateTopBarLayout() end
    if addonTable.RefreshFooterButtonWidths then addonTable.RefreshFooterButtonWidths() end
    if addonTable.UpdateBrowserFilterPanel then addonTable.UpdateBrowserFilterPanel() end
    if addonTable.RefreshBrowserResponsiveLayout then addonTable.RefreshBrowserResponsiveLayout() end
    if addonTable.UpdateDisplay then addonTable.UpdateDisplay() end
end

local DUNGEON_TELEPORT_FALLBACKS = {
    [658] = 1254555,   -- Pit of Saron
    [1209] = 159898,   -- Skyreach
    [1753] = 1254551,  -- Seat of the Triumvirate
    [2526] = 393273,   -- Algeth'ar Academy
    [2805] = 1254400,  -- Windrunner Spire
    [2811] = 1254572,  -- Magisters' Terrace
    [2874] = 1254559,  -- Maisara Caverns
    [2915] = 1254563,  -- Nexus-Point Xenas
}

function addonTable.GetChallengeMapInfo(mapID)
    local numericMapID = tonumber(mapID)
    if not numericMapID or not (C_ChallengeMode and C_ChallengeMode.GetMapUIInfo) then
        return nil
    end

    local mapName, _, _, iconTexture, _, instanceMapID = C_ChallengeMode.GetMapUIInfo(numericMapID)
    if not mapName or mapName == "" then
        return nil
    end

    return {
        challengeMapID = numericMapID,
        instanceMapID = tonumber(instanceMapID) or numericMapID,
        name = mapName,
        iconTexture = iconTexture,
    }
end

function addonTable.GetDungeonTeleportSpellID(mapID)
    local numericMapID = tonumber(mapID)
    if not numericMapID then
        return nil
    end

    local challengeInfo = addonTable.GetChallengeMapInfo and addonTable.GetChallengeMapInfo(numericMapID) or nil
    local lookupIDs = {}
    local seen = {}

    local function AddLookupID(value)
        local numericValue = tonumber(value)
        if numericValue and not seen[numericValue] then
            seen[numericValue] = true
            lookupIDs[#lookupIDs + 1] = numericValue
        end
    end

    AddLookupID(challengeInfo and challengeInfo.instanceMapID)
    AddLookupID(challengeInfo and challengeInfo.challengeMapID)
    AddLookupID(numericMapID)

    if _G.QUI_DungeonData and _G.QUI_DungeonData.GetTeleportSpellID then
        for _, lookupID in ipairs(lookupIDs) do
            local spellID = _G.QUI_DungeonData.GetTeleportSpellID(lookupID)
            if tonumber(spellID) then
                return tonumber(spellID)
            end
        end
    end

    for _, lookupID in ipairs(lookupIDs) do
        local spellID = DUNGEON_TELEPORT_FALLBACKS[lookupID]
        if spellID then
            return spellID
        end
    end

    return nil
end

function addonTable.GetWindowOpacity()
    return (OakLFGSorterDB and tonumber(OakLFGSorterDB.windowOpacity)) or 0.85
end

function addonTable.ApplyWindowOpacity()
    local alpha = addonTable.GetWindowOpacity()
    local baseColor = addonTable.OAK_COLOR_BG or {0.205, 0.185, 0.165, 0.98}
    local paneColor = addonTable.OAK_COLOR_PANE or {0.11, 0.16, 0.13, 1.0}
    local frames = {
        addonTable.MythicPlusPanel,
        addonTable.PartyKeysPanel,
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

    if addonTable.OAK_LFG and addonTable.OAK_LFG.Bg then
        addonTable.OAK_LFG.Bg:SetAlpha(alpha)
    end
    if addonTable.ModernShell then
        if addonTable.ModernShell.bg then
            addonTable.ModernShell.bg:SetVertexColor(baseColor[1], baseColor[2], baseColor[3], alpha)
        end
        if addonTable.ModernShell.inner then
            addonTable.ModernShell.inner:SetVertexColor(paneColor[1], paneColor[2], paneColor[3], alpha)
        end
    end
    if addonTable.OAK_LFG and addonTable.OAK_LFG.Inset then
        if addonTable.OAK_LFG.Inset.Bg then
            addonTable.OAK_LFG.Inset.Bg:SetAlpha(alpha)
        end
        if addonTable.OAK_LFG.Inset.NineSlice then
            addonTable.OAK_LFG.Inset.NineSlice:SetAlpha(alpha)
        end
    end
    if addonTable.BrowserPaneBg then
        addonTable.BrowserPaneBg:SetVertexColor(0.04, 0.04, 0.04, math.max(0.12, alpha * 0.9))
    end
end

function addonTable.SetWindowOpacity(value)
    local alpha = tonumber(value) or 0.85
    alpha = math.max(0.35, math.min(1.0, alpha))
    OakLFGSorterDB.windowOpacity = alpha
    addonTable.ApplyWindowOpacity()
    if addonTable.UpdateDisplay then
        addonTable.UpdateDisplay()
    end
end

local function AnchorOakSidePanel(panel)
    if not panel then
        return
    end

    local anchorTarget = addonTable.OAK_LFG
    local anchorOffset = -2
    if addonTable.MythicPlusPanel and addonTable.MythicPlusPanel:IsShown()
            and OakLFGSorterDB and OakLFGSorterDB.mythicPlusPanelSide == "RIGHT" then
        anchorTarget = addonTable.MythicPlusPanel
        anchorOffset = 2
    end

    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", anchorTarget, "TOPRIGHT", anchorOffset, 0)
end

function addonTable.UpdateAuxPanelAnchors()
    AnchorOakSidePanel(addonTable.FilterPanel)
    AnchorOakSidePanel(addonTable.BrowserFilterPanel)
    AnchorOakSidePanel(addonTable.SupportersPanel)
    AnchorOakSidePanel(addonTable.OptionsPanel)
end

function addonTable.GetRightmostOakPanel()
    local candidates = {
        addonTable.OAK_LFG,
        addonTable.MythicPlusPanel,
        addonTable.FilterPanel,
        addonTable.BrowserFilterPanel,
        addonTable.SupportersPanel,
        addonTable.OptionsPanel,
        addonTable.SearchFilterPanel,
    }

    local bestFrame = addonTable.OAK_LFG
    local bestRight = nil
    for _, frame in ipairs(candidates) do
        if frame and frame.IsShown and frame:IsShown() and frame.GetRight then
            local right = frame:GetRight()
            if right and (not bestRight or right > bestRight) then
                bestRight = right
                bestFrame = frame
            end
        end
    end

    return bestFrame or addonTable.OAK_LFG
end

function addonTable.AnchorBrowserTooltip(tooltip, owner)
    if not tooltip then
        return
    end

    local tooltipOwner = owner or UIParent
    if OakLFGSorterDB and OakLFGSorterDB.attachBrowserTooltipToCursor then
        tooltip:SetOwner(tooltipOwner, "ANCHOR_CURSOR_RIGHT")
        return
    end

    local anchorTarget = addonTable.GetRightmostOakPanel and addonTable.GetRightmostOakPanel() or addonTable.OAK_LFG or tooltipOwner
    tooltip:SetOwner(tooltipOwner, "ANCHOR_NONE")
    tooltip:ClearAllPoints()
    tooltip:SetPoint("TOPLEFT", anchorTarget, "TOPRIGHT", 8, -8)
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

    local isApplied = result.isApplied == true or result.hasSelf == true
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
local textMeasureFrame

local function SetTextureVisible(texture, visible)
    if not texture then
        return
    end

    if visible then
        if texture.SetAlpha then
            texture:SetAlpha(1)
        end
        if texture.Show then
            texture:Show()
        end
    else
        if texture.SetAlpha then
            texture:SetAlpha(0)
        end
        if texture.Hide then
            texture:Hide()
        end
    end
end

local function IsProtectedButtonTexture(button, region)
    return region == button.icon
        or region == button.arrow
        or region == button.OakVisualFill
        or region == button.OakModernFill
        or region == button.OakModernBorderTop
        or region == button.OakModernBorderBottom
        or region == button.OakModernBorderLeft
        or region == button.OakModernBorderRight
end

local function ButtonHasNativeTemplateArt(button)
    return button
        and (
            button.OakUsesNativeButtonTheme
            or button.NormalTexture
            or button.PushedTexture
            or button.DisabledTexture
            or button.HighlightTexture
            or button.Left
            or button.Middle
            or button.Right
        )
end

local function SetModernButtonChromeVisible(button, visible)
    if not button then
        return
    end

    SetTextureVisible(button.OakModernFill, visible)
    SetTextureVisible(button.OakModernBorderTop, visible)
    SetTextureVisible(button.OakModernBorderBottom, visible)
    SetTextureVisible(button.OakModernBorderLeft, visible)
    SetTextureVisible(button.OakModernBorderRight, visible)
end

local function EnsureModernButtonChrome(button, fillColor, borderColor)
    if not button then
        return
    end

    if not button.OakModernFill then
        local fill = button:CreateTexture(nil, "BACKGROUND", nil, 0)
        fill:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        fill:SetTexture(addonTable.FLAT_TEX or "Interface\\Buttons\\WHITE8X8")
        button.OakModernFill = fill

        local top = button:CreateTexture(nil, "BORDER", nil, 1)
        top:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        top:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
        top:SetHeight(1)
        top:SetTexture(addonTable.FLAT_TEX or "Interface\\Buttons\\WHITE8X8")
        button.OakModernBorderTop = top

        local bottom = button:CreateTexture(nil, "BORDER", nil, 1)
        bottom:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
        bottom:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        bottom:SetHeight(1)
        bottom:SetTexture(addonTable.FLAT_TEX or "Interface\\Buttons\\WHITE8X8")
        button.OakModernBorderBottom = bottom

        local left = button:CreateTexture(nil, "BORDER", nil, 1)
        left:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        left:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
        left:SetWidth(1)
        left:SetTexture(addonTable.FLAT_TEX or "Interface\\Buttons\\WHITE8X8")
        button.OakModernBorderLeft = left

        local right = button:CreateTexture(nil, "BORDER", nil, 1)
        right:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
        right:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        right:SetWidth(1)
        right:SetTexture(addonTable.FLAT_TEX or "Interface\\Buttons\\WHITE8X8")
        button.OakModernBorderRight = right
    end

    fillColor = fillColor or addonTable.OAK_COLOR_PANE or { 0.11, 0.16, 0.13, 1 }
    borderColor = borderColor or { 0, 0, 0, 1 }

    button.OakModernFill:SetVertexColor(fillColor[1] or 0.11, fillColor[2] or 0.16, fillColor[3] or 0.13, fillColor[4] or 1)
    button.OakModernBorderTop:SetVertexColor(borderColor[1] or 0, borderColor[2] or 0, borderColor[3] or 0, borderColor[4] or 1)
    button.OakModernBorderBottom:SetVertexColor(borderColor[1] or 0, borderColor[2] or 0, borderColor[3] or 0, borderColor[4] or 1)
    button.OakModernBorderLeft:SetVertexColor(borderColor[1] or 0, borderColor[2] or 0, borderColor[3] or 0, borderColor[4] or 1)
    button.OakModernBorderRight:SetVertexColor(borderColor[1] or 0, borderColor[2] or 0, borderColor[3] or 0, borderColor[4] or 1)

    SetModernButtonChromeVisible(button, true)
end

local function HookModernBorderForwarding(button)
    if not button or button.OakBorderForwardingHooked or not button.SetBackdropBorderColor then
        return
    end

    button.OakOriginalSetBackdropBorderColor = button.OakOriginalSetBackdropBorderColor or button.SetBackdropBorderColor
    button.SetBackdropBorderColor = function(self, r, g, b, a)
        self:OakOriginalSetBackdropBorderColor(r, g, b, a)
        if self.OakModernBorderTop then
            self.OakModernBorderTop:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
        end
        if self.OakModernBorderBottom then
            self.OakModernBorderBottom:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
        end
        if self.OakModernBorderLeft then
            self.OakModernBorderLeft:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
        end
        if self.OakModernBorderRight then
            self.OakModernBorderRight:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
        end
    end
    button.OakBorderForwardingHooked = true
end

local function ApplyModernInteractiveBorder(button, hovered)
    if not button then
        return
    end

    local color = hovered and addonTable.ClassColor or nil
    local r, g, b, a
    if color then
        r, g, b, a = color.r or 1, color.g or 1, color.b or 1, color.a or 1
    else
        local border = addonTable.OAK_COLOR_BORDER or { 0, 0, 0, 1 }
        r, g, b, a = border[1] or 0, border[2] or 0, border[3] or 0, border[4] or 1
    end

    if button.SetBackdropBorderColor then
        button:SetBackdropBorderColor(r, g, b, a)
    end
    if button.OakModernBorderTop then
        button.OakModernBorderTop:SetVertexColor(r, g, b, a)
    end
    if button.OakModernBorderBottom then
        button.OakModernBorderBottom:SetVertexColor(r, g, b, a)
    end
    if button.OakModernBorderLeft then
        button.OakModernBorderLeft:SetVertexColor(r, g, b, a)
    end
    if button.OakModernBorderRight then
        button.OakModernBorderRight:SetVertexColor(r, g, b, a)
    end
end

addonTable.ApplyModernInteractiveBorder = ApplyModernInteractiveBorder

local function EnsureModernHoverFeedback(button)
    if not button or button.OakModernHoverFeedbackHooked then
        return
    end

    if not button.OakDefaultTextColor then
        button.OakDefaultTextColor = {
            addonTable.ClassColor.r or 1,
            addonTable.ClassColor.g or 1,
            addonTable.ClassColor.b or 1,
            1,
        }
    end

    button:HookScript("OnEnter", function(self)
        if addonTable.IsModernTheme and addonTable.IsModernTheme() then
            ApplyModernInteractiveBorder(self, true)
            if self.text and self.text.SetFontObject then
                self.text:SetFontObject("SorterClassic_FontRegular")
            end
            if self.text and self.text.SetTextColor then
                self.text:SetTextColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
            end
        end
    end)
    button:HookScript("OnLeave", function(self)
        if addonTable.IsModernTheme and addonTable.IsModernTheme() then
            ApplyModernInteractiveBorder(self, false)
            if self.text and self.text.SetFontObject then
                self.text:SetFontObject("SorterClassic_FontRegular")
            end
            if self.text and self.text.SetTextColor then
                local color = self.OakDefaultTextColor or { 1, 0.82, 0, 1 }
                self.text:SetTextColor(color[1], color[2], color[3], color[4])
            end
        end
    end)
    button.OakModernHoverFeedbackHooked = true
end

local function HideNativeButtonTextureRegions(button)
    if not button then
        return
    end

    SetTextureVisible(button.NormalTexture, false)
    SetTextureVisible(button.PushedTexture, false)
    SetTextureVisible(button.DisabledTexture, false)
    SetTextureVisible(button.HighlightTexture, false)
    SetTextureVisible(button.Left, false)
    SetTextureVisible(button.Middle, false)
    SetTextureVisible(button.Right, false)

    if button.GetNormalTexture then
        SetTextureVisible(button:GetNormalTexture(), false)
    end
    if button.GetPushedTexture then
        SetTextureVisible(button:GetPushedTexture(), false)
    end
    if button.GetDisabledTexture then
        SetTextureVisible(button:GetDisabledTexture(), false)
    end
    if button.GetHighlightTexture then
        SetTextureVisible(button:GetHighlightTexture(), false)
    end

    if button.GetRegions then
        local regions = { button:GetRegions() }
        for _, region in ipairs(regions) do
            if region
                and region.GetObjectType
                and region:GetObjectType() == "Texture"
                and not IsProtectedButtonTexture(button, region)
            then
                SetTextureVisible(region, false)
            end
        end
    end
end

local function HideNativeButtonTextures(button)
    if not button then
        return
    end

    HideNativeButtonTextureRegions(button)
    if button.SetNormalTexture then
        button:SetNormalTexture("")
    end
    if button.SetPushedTexture then
        button:SetPushedTexture("")
    end
    if button.SetDisabledTexture then
        button:SetDisabledTexture("")
    end
    if button.SetHighlightTexture then
        button:SetHighlightTexture("")
    end

    HideNativeButtonTextureRegions(button)
end

local function ApplyExplicitClassicButtonSkin(button)
    if not button then
        return
    end

    local hasTemplateSlices = button.Left or button.Middle or button.Right
    if not hasTemplateSlices then
        if button.SetNormalTexture then
            button:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
        end
        if button.SetPushedTexture then
            button:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
        end
        if button.SetDisabledTexture then
            button:SetDisabledTexture("Interface\\Buttons\\UI-Panel-Button-Disabled")
        end
    end
    if button.SetHighlightTexture then
        button:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
        local highlight = button:GetHighlightTexture()
        if highlight and highlight.SetBlendMode then
            highlight:SetBlendMode("ADD")
        end
        SetTextureVisible(highlight, true)
    end

    SetTextureVisible(button.Left, true)
    SetTextureVisible(button.Middle, true)
    SetTextureVisible(button.Right, true)
    SetModernButtonChromeVisible(button, false)

    if button.OakVisualFill then
        button.OakVisualFill:Hide()
    end
    if button.SetBackdropColor then
        button:SetBackdropColor(0, 0, 0, 0)
    end
    if button.SetBackdropBorderColor then
        button:SetBackdropBorderColor(0, 0, 0, 0)
    end

    if button.text then
        if button.text.SetFontObject then
            button.text:SetFontObject(GameFontNormal)
        end
        if button.text.SetShadowOffset then
            button.text:SetShadowOffset(0, 0)
        end
        if button.text.SetShadowColor then
            button.text:SetShadowColor(0, 0, 0, 0)
        end
    end
end

local function ApplyExplicitModernButtonSkin(button, flatButtonFill)
    if not button then
        return
    end

    if not button.SetBackdropBorderColor then
        function button:SetBackdropBorderColor() end
    end
    HookModernBorderForwarding(button)

    if ButtonHasNativeTemplateArt(button) then
        HideNativeButtonTextures(button)
    end
    if button.OakVisualFill then
        button.OakVisualFill:Hide()
    end

    if addonTable.ApplyBackdropStyle then
        addonTable.ApplyBackdropStyle(button, "button")
    end
    flatButtonFill = flatButtonFill or addonTable.OAK_COLOR_PANE or { 0.11, 0.16, 0.13, 1 }
    EnsureModernButtonChrome(button, flatButtonFill, { 0, 0, 0, 1 })
    button:SetBackdropColor(unpack(flatButtonFill))
    button:SetBackdropBorderColor(0, 0, 0, 1)
    EnsureModernHoverFeedback(button)

    if button.text then
        if button.text.SetFontObject then
            button.text:SetFontObject("SorterClassic_FontRegular")
        end
        if button.text.SetShadowOffset then
            button.text:SetShadowOffset(0, 0)
        end
        if button.text.SetShadowColor then
            button.text:SetShadowColor(0, 0, 0, 0)
        end
        button.OakDefaultTextColor = {
            addonTable.ClassColor.r or 1,
            addonTable.ClassColor.g or 1,
            addonTable.ClassColor.b or 1,
            1,
        }
    end
end

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

local CLASSIC_BLIZZARD_THEME = {
    bg = { 0.205, 0.185, 0.165, 0.98 },
    pane = { 0.255, 0.235, 0.205, 1.0 },
    border = { 0.11, 0.085, 0.05, 1.0 },
    rowA = { 0.16, 0.16, 0.16, 0.92 },
    rowB = { 0.11, 0.11, 0.11, 0.92 },
    stickyPanel = { 0.24, 0.22, 0.19, 0.96 },
    contextBar = { 0.245, 0.225, 0.195, 0.93 },
    quickSignupBar = { 0.255, 0.235, 0.205, 0.97 },
    sliderTrack = { 0.12, 0.105, 0.09, 1.0 },
    buttonInactive = { 0.255, 0.235, 0.205, 1.0 },
    toggleOffFill = { 0.18, 0.16, 0.14, 0.97 },
    titleBar = { 0.255, 0.235, 0.205, 1.0 },
    dropdownHover = { 1.0, 0.93, 0.68, 0.07 },
    stickyAccent = { 0.96, 0.93, 0.86, 1.0 },
    stickyAccentSoft = { 0.84, 0.81, 0.75, 0.82 },
    titleTint = { 0.96, 0.93, 0.84, 1.0 },
    toggleActiveFill = { 0.36, 0.29, 0.13, 0.98 },
    toggleActiveBorder = { 0.58, 0.48, 0.20, 1.0 },
    toggleInactiveFill = { 0.14, 0.14, 0.14, 0.95 },
    toggleInactiveBorder = { 0.34, 0.34, 0.34, 1.0 },
    text = { 0.96, 0.96, 0.96, 1.0 },
    textMuted = { 0.84, 0.84, 0.84, 1.0 },
    panelTitleBg = { 0.18, 0.18, 0.18, 0.96 },
    panelInner = { 0.28, 0.25, 0.21, 0.82 },
    panelInnerBorder = { 0.31, 0.31, 0.31, 0.70 },
    panelTrim = { 0.52, 0.44, 0.22, 0.45 },
}

local MODERN_CLEAN_THEME = {
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
    toggleActiveFill = { 0.15, 0.37, 0.23, 0.98 },
    toggleActiveBorder = { 0.34, 0.83, 0.52, 1.0 },
    toggleInactiveFill = { 0.066, 0.084, 0.070, 0.96 },
    toggleInactiveBorder = { 0.20, 0.29, 0.22, 1.0 },
    text = { 0.92, 0.95, 0.92, 1.0 },
    textMuted = { 0.68, 0.73, 0.68, 1.0 },
    panelTitleBg = { 0.10, 0.16, 0.13, 0.98 },
    panelInner = { 0.06, 0.09, 0.075, 0.84 },
    panelInnerBorder = { 0.18, 0.24, 0.20, 0.80 },
    panelTrim = { 0.85, 0.95, 0.86, 0.28 },
}

local MODERN_GROVE_THEME = {
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
    toggleActiveFill = { 0.46, 0.30, 0.13, 0.98 },
    toggleActiveBorder = { 1.0, 0.72, 0.28, 1.0 },
    toggleInactiveFill = { 0.24, 0.18, 0.11, 0.96 },
    toggleInactiveBorder = { 0.44, 0.31, 0.16, 1.0 },
    text = { 0.98, 0.94, 0.86, 1.0 },
    textMuted = { 0.82, 0.76, 0.66, 1.0 },
    panelTitleBg = { 0.30, 0.24, 0.15, 0.98 },
    panelInner = { 0.20, 0.15, 0.09, 0.84 },
    panelInnerBorder = { 0.42, 0.31, 0.16, 0.80 },
    panelTrim = { 1.0, 0.84, 0.52, 0.32 },
}

local THEME_MODE_CLASSIC = "classic"
local THEME_MODE_MODERN = "modern"
local MODERN_DEFAULT_STYLE = "OAK"
local MODERN_DEFAULT_PRESET = "CLASS"
local MODERN_CUSTOM_PRESET = "CUSTOM"

addonTable.ThemeModes = {
    { id = THEME_MODE_CLASSIC, label = "Classic" },
    { id = THEME_MODE_MODERN, label = "Modern" },
}
addonTable.ThemeStyles = {
    { id = "OAK", label = "Oak", colors = MODERN_CLEAN_THEME },
    { id = "DARK", label = "Dark", colors = {
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
        toggleActiveFill = { 0.31, 0.31, 0.35, 0.98 },
        toggleActiveBorder = { 0.72, 0.72, 0.78, 1.0 },
        toggleInactiveFill = { 0.06, 0.06, 0.07, 0.97 },
        toggleInactiveBorder = { 0.24, 0.24, 0.29, 1.0 },
        text = { 0.93, 0.93, 0.95, 1.0 },
        textMuted = { 0.72, 0.72, 0.76, 1.0 },
        panelTitleBg = { 0.09, 0.09, 0.10, 0.98 },
        panelInner = { 0.05, 0.05, 0.06, 0.84 },
        panelInnerBorder = { 0.20, 0.20, 0.22, 0.80 },
        panelTrim = { 0.82, 0.82, 0.86, 0.24 },
    } },
    { id = "AMBER", label = "Amber", colors = MODERN_GROVE_THEME },
    { id = "BLIZZARD", label = "Blizzard Brown", colors = CLASSIC_BLIZZARD_THEME },
    { id = "BLIZZARD_GRAY", label = "Blizzard Gray", colors = {
        bg = { 0.155, 0.145, 0.135, 0.965 },
        pane = { 0.215, 0.205, 0.192, 1.0 },
        border = { 0.08, 0.065, 0.04, 1.0 },
        rowA = { 0.255, 0.245, 0.232, 0.46 },
        rowB = { 0.175, 0.165, 0.154, 0.24 },
        stickyPanel = { 0.205, 0.198, 0.186, 0.95 },
        contextBar = { 0.20, 0.193, 0.182, 0.89 },
        quickSignupBar = { 0.29, 0.277, 0.255, 0.97 },
        sliderTrack = { 0.115, 0.108, 0.098, 1.0 },
        buttonInactive = { 0.29, 0.277, 0.255, 1.0 },
        toggleOffFill = { 0.165, 0.157, 0.147, 0.97 },
        titleBar = { 0.255, 0.243, 0.224, 1.0 },
        dropdownHover = { 1.0, 0.93, 0.68, 0.10 },
        stickyAccent = { 0.96, 0.93, 0.86, 1.0 },
        stickyAccentSoft = { 0.84, 0.81, 0.75, 0.92 },
        titleTint = { 0.96, 0.93, 0.84, 1.0 },
        toggleActiveFill = { 0.36, 0.29, 0.18, 0.98 },
        toggleActiveBorder = { 0.74, 0.60, 0.34, 1.0 },
        toggleInactiveFill = { 0.16, 0.15, 0.14, 0.97 },
        toggleInactiveBorder = { 0.36, 0.34, 0.30, 1.0 },
        text = { 0.94, 0.92, 0.88, 1.0 },
        textMuted = { 0.76, 0.74, 0.70, 1.0 },
        panelTitleBg = { 0.22, 0.21, 0.19, 0.98 },
        panelInner = { 0.14, 0.13, 0.12, 0.84 },
        panelInnerBorder = { 0.32, 0.30, 0.28, 0.80 },
        panelTrim = { 0.86, 0.76, 0.54, 0.26 },
    } },
}
addonTable.ThemePresets = {
    { id = "CLASS", label = "Class Color", color = nil },
    { id = "SKY", label = "Sky Blue", color = { r = 0.30, g = 0.76, b = 0.98 } },
    { id = "MINT", label = "Mint", color = { r = 0.35, g = 0.90, b = 0.66 } },
    { id = "LIGHT_GRAY", label = "Light Gray", color = { r = 0.741, g = 0.725, b = 0.706 } },
    { id = "HORDE", label = "Horde", color = { r = 0.80, g = 0.16, b = 0.16 } },
    { id = "ALLIANCE", label = "Alliance", color = { r = 0.24, g = 0.51, b = 0.96 } },
    { id = "MIDNIGHT", label = "Midnight", color = { r = 0.52, g = 0.45, b = 0.92 } },
    { id = "AMBER", label = "Amber", color = { r = 0.98, g = 0.65, b = 0.18 } },
    { id = "ROSE", label = "Rose", color = { r = 0.92, g = 0.43, b = 0.61 } },
    { id = "EMERALD", label = "Emerald", color = { r = 0.20, g = 0.82, b = 0.58 } },
    { id = MODERN_CUSTOM_PRESET, label = "Custom", color = { r = 0.31, g = 0.86, b = 0.88 } },
}

local function FindThemeOption(options, optionID)
    if type(options) ~= "table" then
        return nil
    end

    for _, option in ipairs(options) do
        if option.id == optionID then
            return option
        end
    end

    return nil
end

local function NormalizeThemeMode(themeMode)
    if themeMode == THEME_MODE_MODERN then
        return THEME_MODE_MODERN
    end
    return THEME_MODE_CLASSIC
end

local function NormalizeThemeStyleID(styleID)
    if styleID == "MODERN_CLEAN" then
        return "OAK"
    end
    if styleID == "MODERN_GROVE" then
        return "AMBER"
    end
    return styleID
end

local function NormalizeThemePresetID(presetID)
    if presetID == "OAK_TEAL" then
        return "CLASS"
    end
    if presetID == "LEAF" then
        return "EMERALD"
    end
    if presetID == "VIOLET" then
        return "MIDNIGHT"
    end
    return presetID
end

local function EnsureModernThemeDefaults()
    OakLFGSorterDB.themeStyle = NormalizeThemeStyleID(OakLFGSorterDB.themeStyle)
    OakLFGSorterDB.themePreset = NormalizeThemePresetID(OakLFGSorterDB.themePreset)
    if not FindThemeOption(addonTable.ThemeStyles, OakLFGSorterDB.themeStyle) then
        OakLFGSorterDB.themeStyle = MODERN_DEFAULT_STYLE
    end
    if not FindThemeOption(addonTable.ThemePresets, OakLFGSorterDB.themePreset) then
        OakLFGSorterDB.themePreset = MODERN_DEFAULT_PRESET
    end
    if OakLFGSorterDB.themePreset == MODERN_CUSTOM_PRESET and type(OakLFGSorterDB.themeCustomColor) ~= "table" then
        OakLFGSorterDB.themeCustomColor = CopyTable(FindThemeOption(addonTable.ThemePresets, MODERN_DEFAULT_PRESET).color)
    end
end

function addonTable.GetThemeMode()
    OakLFGSorterDB.theme = NormalizeThemeMode(OakLFGSorterDB.theme)
    return OakLFGSorterDB.theme
end

function addonTable.IsClassicTheme()
    return addonTable.GetThemeMode() == THEME_MODE_CLASSIC
end

function addonTable.IsModernTheme()
    return addonTable.GetThemeMode() == THEME_MODE_MODERN
end

function addonTable.GetThemeModeLabel()
    local mode = addonTable.GetThemeMode()
    local option = FindThemeOption(addonTable.ThemeModes, mode)
    return option and option.label or "Classic"
end

function addonTable.GetThemeStyle()
    if not addonTable.IsModernTheme() then
        return "CLASSIC_BLIZZARD"
    end
    EnsureModernThemeDefaults()
    return OakLFGSorterDB.themeStyle
end

function addonTable.GetThemeStyleLabel()
    if not addonTable.IsModernTheme() then
        return "Classic Blizzard"
    end
    local style = FindThemeOption(addonTable.ThemeStyles, addonTable.GetThemeStyle())
    return style and style.label or "Clean"
end

function addonTable.GetThemeStyleColors(styleID)
    if styleID == "CLASSIC_BLIZZARD" then
        return CLASSIC_BLIZZARD_THEME
    end

    if addonTable.IsModernTheme() or styleID then
        local style = FindThemeOption(addonTable.ThemeStyles, styleID or addonTable.GetThemeStyle())
        if style and style.colors then
            return style.colors
        end
    end

    return CLASSIC_BLIZZARD_THEME
end

function addonTable.GetThemePreset()
    if not addonTable.IsModernTheme() then
        return "CLASSIC_BLIZZARD"
    end
    EnsureModernThemeDefaults()
    return OakLFGSorterDB.themePreset
end

function addonTable.GetThemeCustomColor()
    if addonTable.IsModernTheme() and type(OakLFGSorterDB.themeCustomColor) == "table" then
        local color = NormalizeThemeColor(OakLFGSorterDB.themeCustomColor)
        return { r = color.r, g = color.g, b = color.b, a = color.a or 1 }
    end
    return { r = 0.31, g = 0.86, b = 0.88, a = 1 }
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
    if not addonTable.IsModernTheme() then
        return { r = 0.741, g = 0.725, b = 0.706, a = 1 }
    end

    local presetID = themeID or addonTable.GetThemePreset()
    if presetID == "CLASS" then
        local classColor = addonTable.PlayerClassColor or { r = 1, g = 1, b = 1 }
        return { r = classColor.r or 1, g = classColor.g or 1, b = classColor.b or 1, a = 1 }
    end
    if presetID == MODERN_CUSTOM_PRESET then
        return addonTable.GetThemeCustomColor()
    end

    local preset = FindThemeOption(addonTable.ThemePresets, presetID) or FindThemeOption(addonTable.ThemePresets, MODERN_DEFAULT_PRESET)
    local color = NormalizeThemeColor(preset and preset.color)
    return { r = color.r, g = color.g, b = color.b, a = color.a or 1 }
end

function addonTable.GetThemePresetLabel(themeID)
    if not addonTable.IsModernTheme() then
        return "Classic Blizzard"
    end
    local preset = FindThemeOption(addonTable.ThemePresets, themeID or addonTable.GetThemePreset())
    return preset and preset.label or "Oak Teal"
end

local function NotifyThemeRefreshers()
    for _, callback in pairs(registeredThemeRefreshers) do
        pcall(callback)
    end
end

local function RefreshRegisteredButtons()
    local style = addonTable.GetThemeStyle and addonTable.GetThemeStyle() or "OAK"
    local useQuickSignupFill = style == "BLIZZARD" or style == "BLIZZARD_GRAY" or style == "CLASSIC_BLIZZARD"
    local flatButtonFill = useQuickSignupFill and (addonTable.OAK_COLOR_QUICKSIGNUP or addonTable.OAK_COLOR_PANE) or addonTable.OAK_COLOR_PANE

    for key, button in pairs(registeredFlatButtons) do
        if button and button.SetBackdropColor then
            if button.OakVisualFill then
                button.OakVisualFill:Hide()
            end
            if addonTable.IsClassicTheme and addonTable.IsClassicTheme() then
                ApplyExplicitClassicButtonSkin(button)
                if button.RefreshAutoWidth then
                    button:RefreshAutoWidth()
                end
            else
                ApplyExplicitModernButtonSkin(button, flatButtonFill)
                if button.text and button.text.SetTextColor then
                    button.text:SetTextColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
                end
                if button.RefreshAutoWidth then
                    button:RefreshAutoWidth()
                end
            end
        else
            registeredFlatButtons[key] = nil
        end
    end

    for key, button in pairs(registeredCogButtons) do
        if button and button.SetBackdropColor then
            if button.OakVisualFill then
                button.OakVisualFill:Hide()
            end
            if addonTable.IsClassicTheme and addonTable.IsClassicTheme() then
                ApplyExplicitClassicButtonSkin(button)
            else
                ApplyExplicitModernButtonSkin(button, flatButtonFill)
            end
        else
            registeredCogButtons[key] = nil
        end
    end
end

function addonTable.ApplyTheme()
    local styleColors = addonTable.GetThemeStyleColors() or CLASSIC_BLIZZARD_THEME
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
    addonTable.OAK_COLOR_BUTTON_INACTIVE = CopyThemeArray(styleColors.buttonInactive)
    addonTable.OAK_COLOR_TOGGLE_ACTIVE = CopyThemeArray(styleColors.toggleActiveFill)
    addonTable.OAK_COLOR_TOGGLE_ACTIVE_BORDER = CopyThemeArray(styleColors.toggleActiveBorder)
    addonTable.OAK_COLOR_TOGGLE_INACTIVE = CopyThemeArray(styleColors.toggleInactiveFill)
    addonTable.OAK_COLOR_TOGGLE_INACTIVE_BORDER = CopyThemeArray(styleColors.toggleInactiveBorder)
    addonTable.OAK_COLOR_TEXT = CopyThemeArray(styleColors.text)
    addonTable.OAK_COLOR_TEXT_MUTED = CopyThemeArray(styleColors.textMuted)
    addonTable.OAK_COLOR_PANEL_TITLE_BG = CopyThemeArray(styleColors.panelTitleBg)
    addonTable.OAK_COLOR_PANEL_INNER = CopyThemeArray(styleColors.panelInner)
    addonTable.OAK_COLOR_PANEL_INNER_BORDER = CopyThemeArray(styleColors.panelInnerBorder)
    addonTable.OAK_COLOR_PANEL_TRIM = CopyThemeArray(styleColors.panelTrim)
    RefreshRegisteredButtons()
    NotifyThemeRefreshers()
    if addonTable.ApplyWindowOpacity then addonTable.ApplyWindowOpacity() end
    if addonTable.RefreshRegisteredFontDropdowns then addonTable.RefreshRegisteredFontDropdowns() end
    if addonTable.UpdateDisplay then addonTable.UpdateDisplay() end
    if addonTable.UpdateTopBarActions then addonTable.UpdateTopBarActions() end
    if addonTable.UpdateSearchQuickSignupControls then addonTable.UpdateSearchQuickSignupControls() end
    if addonTable.RefreshOptionsPanel then addonTable.RefreshOptionsPanel() end
end

function addonTable.SetThemeMode(themeMode)
    local previousTheme = addonTable.GetThemeMode and addonTable.GetThemeMode() or THEME_MODE_CLASSIC
    local nextTheme = NormalizeThemeMode(themeMode)
    if previousTheme == nextTheme then
        addonTable.ApplyTheme()
        return
    end

    OakLFGSorterDB.theme = nextTheme
    if nextTheme == THEME_MODE_MODERN then
        EnsureModernThemeDefaults()
    end

    if ReloadUI then
        ReloadUI()
        return
    end

    addonTable.ApplyTheme()
end

function addonTable.SetThemeStyle(styleID)
    if addonTable.IsModernTheme() and FindThemeOption(addonTable.ThemeStyles, styleID) then
        OakLFGSorterDB.themeStyle = styleID
    end
    addonTable.ApplyTheme()
end

function addonTable.SetThemePreset(themeID)
    if addonTable.IsModernTheme() and FindThemeOption(addonTable.ThemePresets, themeID) then
        OakLFGSorterDB.themePreset = themeID
        if themeID == MODERN_CUSTOM_PRESET and type(OakLFGSorterDB.themeCustomColor) ~= "table" then
            local accent = addonTable.GetThemeAccentColor(MODERN_DEFAULT_PRESET)
            OakLFGSorterDB.themeCustomColor = { r = accent.r, g = accent.g, b = accent.b, a = 1 }
        end
    end
    addonTable.ApplyTheme()
end

function addonTable.SetThemeCustomColor(color)
    if not addonTable.IsModernTheme() then
        return
    end
    local normalized = NormalizeThemeColor(color)
    OakLFGSorterDB.themeCustomColor = { r = normalized.r, g = normalized.g, b = normalized.b, a = normalized.a or 1 }
    OakLFGSorterDB.themePreset = MODERN_CUSTOM_PRESET
    addonTable.ApplyTheme()
end

function addonTable.OpenThemeColorPicker()
    if not addonTable.IsModernTheme() or not ColorPickerFrame then
        return
    end

    local current = addonTable.GetThemeAccentColor()
    local previous = { r = current.r, g = current.g, b = current.b, a = current.a or 1 }
    local function ApplyColor()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        addonTable.SetThemeCustomColor({ r = r, g = g, b = b, a = 1 })
    end
    local function CancelColor()
        addonTable.SetThemeCustomColor(previous)
    end

    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = current.r,
            g = current.g,
            b = current.b,
            hasOpacity = false,
            swatchFunc = ApplyColor,
            cancelFunc = CancelColor,
        })
        return
    end

    ColorPickerFrame.func = ApplyColor
    ColorPickerFrame.cancelFunc = CancelColor
    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame:SetColorRGB(current.r, current.g, current.b)
    ColorPickerFrame:Hide()
    ColorPickerFrame:Show()
end

function addonTable.GetThemeToggleColors(isActive)
    if isActive then
        return addonTable.OAK_COLOR_TOGGLE_ACTIVE or { 0.36, 0.29, 0.13, 0.98 },
            addonTable.OAK_COLOR_TOGGLE_ACTIVE_BORDER or { 0.58, 0.48, 0.20, 1 }
    end
    return addonTable.OAK_COLOR_TOGGLE_INACTIVE or { 0.14, 0.14, 0.14, 0.95 },
        addonTable.OAK_COLOR_TOGGLE_INACTIVE_BORDER or { 0.34, 0.34, 0.34, 1 }
end

function addonTable.ApplyToggleVisual(box, label, isActive)
    if not box then
        return
    end

    if not box.check then
        box.check = box:CreateTexture(nil, "OVERLAY")
        box.check:SetAtlas("common-icon-checkmark-yellow")
        box.check:SetSize(12, 12)
        box.check:SetPoint("CENTER")
    end

    local fill, border = addonTable.GetThemeToggleColors(isActive)
    box:SetBackdropColor(unpack(fill))
    box:SetBackdropBorderColor(unpack(border))
    if isActive then
        box.check:Show()
        if label then label:SetTextColor(unpack(addonTable.OAK_COLOR_TEXT or { 0.96, 0.96, 0.96, 1 })) end
    else
        box.check:Hide()
        if label then label:SetTextColor(unpack(addonTable.OAK_COLOR_TEXT_MUTED or { 0.84, 0.84, 0.84, 1 })) end
    end
end

function addonTable.ApplyToggleHoverVisual(box, label, isActive)
    addonTable.ApplyToggleVisual(box, label, isActive)
    if box and box.SetBackdropBorderColor then
        box:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    end
end

function addonTable.ApplySliderChrome(slider, width, thumbWidth, thumbHeight)
    if not slider then
        return nil
    end

    slider:SetHeight(10)
    slider:SetWidth(tonumber(width) or slider:GetWidth() or 120)
    if slider.SetBackdrop then
        slider:SetBackdrop(nil)
    end

    if slider.SetThumbTexture then
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    end

    local thumb = slider.GetThumbTexture and slider:GetThumbTexture()
    if thumb then
        thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        thumb:SetSize(tonumber(thumbWidth) or 16, tonumber(thumbHeight) or 24)
        if addonTable.IsModernTheme and addonTable.IsModernTheme() then
            local accent = addonTable.ClassColor or { r = 1, g = 1, b = 1 }
            thumb:SetVertexColor(accent.r or 1, accent.g or 1, accent.b or 1, 1)
        else
            thumb:SetVertexColor(1, 1, 1, 1)
        end
    end
    return thumb
end

function addonTable.ApplyEditBoxChrome(editBox)
    if not editBox then
        return
    end
    if addonTable.ApplyBackdropStyle then
        addonTable.ApplyBackdropStyle(editBox, "inset")
    end
    if editBox.SetBackdropColor then
        editBox:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG or { 0.05, 0.05, 0.05, 1 }))
    end
    if editBox.SetBackdropBorderColor then
        if addonTable.IsClassicTheme and addonTable.IsClassicTheme() then
            editBox:SetBackdropBorderColor(1, 1, 1, 1)
        else
            editBox:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER or { 0, 0, 0, 1 }))
        end
    end
end

function addonTable.ApplyPanelChrome(panel, titleFontString)
    if not panel then
        return
    end

    if addonTable.ApplyBackdropStyle then
        addonTable.ApplyBackdropStyle(panel, "panel")
    end
    if panel.SetBackdropBorderColor then
        if addonTable.IsModernTheme and addonTable.IsModernTheme() then
            panel:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER or { 0, 0, 0, 1 }))
        else
            panel:SetBackdropBorderColor(1, 1, 1, 1)
        end
    end

    if not panel.OakTitleBg then
        panel.OakTitleBg = panel:CreateTexture(nil, "BORDER")
        panel.OakTitleBg:SetTexture(addonTable.FLAT_TEX or "Interface\\Buttons\\WHITE8X8")
        panel.OakTitleBg:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
        panel.OakTitleBg:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
        panel.OakTitleBg:SetHeight(24)
    end
    panel.OakTitleBg:SetVertexColor(unpack(addonTable.OAK_COLOR_PANEL_TITLE_BG or { 0.18, 0.18, 0.18, 0.96 }))

    if not panel.OakTopTrim then
        panel.OakTopTrim = panel:CreateTexture(nil, "BORDER")
        panel.OakTopTrim:SetTexture(addonTable.FLAT_TEX or "Interface\\Buttons\\WHITE8X8")
        panel.OakTopTrim:SetPoint("TOPLEFT", panel.OakTitleBg, "BOTTOMLEFT", 0, -2)
        panel.OakTopTrim:SetPoint("TOPRIGHT", panel.OakTitleBg, "BOTTOMRIGHT", 0, -2)
        panel.OakTopTrim:SetHeight(1)
    end
    panel.OakTopTrim:SetVertexColor(unpack(addonTable.OAK_COLOR_PANEL_TRIM or { 0.52, 0.44, 0.22, 0.45 }))

    if not panel.OakInnerShade then
        panel.OakInnerShade = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
        panel.OakInnerShade:SetTexture(addonTable.FLAT_TEX or "Interface\\Buttons\\WHITE8X8")
        panel.OakInnerShade:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -36)
        panel.OakInnerShade:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 10)
    end
    panel.OakInnerShade:SetVertexColor(unpack(addonTable.OAK_COLOR_PANEL_INNER or { 0.28, 0.25, 0.21, 0.82 }))

    if not panel.OakInnerBorder then
        panel.OakInnerBorder = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        panel.OakInnerBorder:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -36)
        panel.OakInnerBorder:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 10)
        panel.OakInnerBorder:SetBackdrop({
            bgFile = addonTable.FLAT_TEX or "Interface\\Buttons\\WHITE8X8",
            edgeFile = addonTable.FLAT_TEX or "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        panel.OakInnerBorder:SetBackdropColor(0, 0, 0, 0)
    end
    panel.OakInnerBorder:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_PANEL_INNER_BORDER or { 0.31, 0.31, 0.31, 0.70 }))

    if titleFontString then
        titleFontString:ClearAllPoints()
        titleFontString:SetPoint("CENTER", panel.OakTitleBg, "CENTER", 0, 0)
    end
end

function addonTable.ApplyScrollBarChrome(scrollBar)
    if not scrollBar then
        return
    end

    local thumb = (scrollBar.GetThumbTexture and scrollBar:GetThumbTexture()) or (scrollBar.Track and scrollBar.Track.Thumb)
    if thumb and thumb.SetVertexColor then
        if thumb.SetTexture then
            thumb:SetTexture(addonTable.FLAT_TEX)
        end
        if addonTable.IsModernTheme and addonTable.IsModernTheme() then
            local accent = addonTable.ClassColor or { r = 1, g = 1, b = 1 }
            thumb:SetVertexColor(accent.r or 1, accent.g or 1, accent.b or 1, 1)
        else
            thumb:SetVertexColor(1, 1, 1, 1)
        end
    end
end

function addonTable.CreateFontDropdown(parent, width)
    local dropdownButton = addonTable.CreateFlatButton(parent, addonTable.GetActiveFontName(), width)
    local listFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    listFrame:SetSize(width + 18, 224)
    listFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 24,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    listFrame:SetBackdropColor(1, 1, 1, 1)
    listFrame:SetBackdropBorderColor(1, 1, 1, 1)
    listFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    listFrame:Hide()

    fontDropdownCounter = fontDropdownCounter + 1
    local scrollFrame = CreateFrame("ScrollFrame", "SorterClassicFontDropdownScroll" .. fontDropdownCounter, listFrame, "UIPanelScrollFrameTemplate")
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
        if addonTable.ApplyScrollBarChrome then
            addonTable.ApplyScrollBarChrome(scrollBar)
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
                optionButton = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
                optionButton.text = optionButton.Text
                if optionButton.text then
                    optionButton.text:SetJustifyH("LEFT")
                end
                optionButtons[index] = optionButton
            end

            optionButton:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -((index - 1) * 22))
            optionButton:SetSize(width, 22)

            local fontPath = addonTable.GetFontPath(fontName)
            optionButton.text:SetFont(fontPath, 12, "")
            optionButton.text:SetShadowColor(0, 0, 0, 1)
            optionButton.text:SetShadowOffset(1, -1)
            optionButton:SetText(fontName)
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
        if scrollBar and addonTable.ApplyScrollBarChrome then
            addonTable.ApplyScrollBarChrome(scrollBar)
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
local initialThemeColors = addonTable.GetThemeStyleColors() or CLASSIC_BLIZZARD_THEME
addonTable.ClassColor = addonTable.GetThemeAccentColor()
addonTable.OAK_COLOR_BG = CopyThemeArray(initialThemeColors.bg)
addonTable.OAK_COLOR_PANE = CopyThemeArray(initialThemeColors.pane)
addonTable.OAK_COLOR_BORDER = CopyThemeArray(initialThemeColors.border)
addonTable.ROW_COLOR_A = CopyThemeArray(initialThemeColors.rowA)
addonTable.ROW_COLOR_B = CopyThemeArray(initialThemeColors.rowB)
addonTable.OAK_COLOR_STICKY = CopyThemeArray(initialThemeColors.stickyPanel)
addonTable.OAK_COLOR_CONTEXT = CopyThemeArray(initialThemeColors.contextBar)
addonTable.OAK_COLOR_QUICKSIGNUP = CopyThemeArray(initialThemeColors.quickSignupBar)
addonTable.OAK_COLOR_SLIDER_TRACK = CopyThemeArray(initialThemeColors.sliderTrack)
addonTable.OAK_COLOR_TOGGLE_OFF = CopyThemeArray(initialThemeColors.toggleOffFill)
addonTable.OAK_COLOR_TITLEBAR = CopyThemeArray(initialThemeColors.titleBar)
addonTable.OAK_COLOR_DROPDOWN_HOVER = CopyThemeArray(initialThemeColors.dropdownHover)
addonTable.OAK_COLOR_STICKY_ACCENT = CopyThemeArray(initialThemeColors.stickyAccent)
addonTable.OAK_COLOR_STICKY_ACCENT_SOFT = CopyThemeArray(initialThemeColors.stickyAccentSoft)
addonTable.OAK_COLOR_TITLE_TINT = CopyThemeArray(initialThemeColors.titleTint)
addonTable.OAK_COLOR_BUTTON_INACTIVE = CopyThemeArray(initialThemeColors.buttonInactive)
addonTable.OAK_COLOR_TOGGLE_ACTIVE = CopyThemeArray(initialThemeColors.toggleActiveFill)
addonTable.OAK_COLOR_TOGGLE_ACTIVE_BORDER = CopyThemeArray(initialThemeColors.toggleActiveBorder)
addonTable.OAK_COLOR_TOGGLE_INACTIVE = CopyThemeArray(initialThemeColors.toggleInactiveFill)
addonTable.OAK_COLOR_TOGGLE_INACTIVE_BORDER = CopyThemeArray(initialThemeColors.toggleInactiveBorder)
addonTable.OAK_COLOR_TEXT = CopyThemeArray(initialThemeColors.text)
addonTable.OAK_COLOR_TEXT_MUTED = CopyThemeArray(initialThemeColors.textMuted)
addonTable.OAK_COLOR_PANEL_TITLE_BG = CopyThemeArray(initialThemeColors.panelTitleBg)
addonTable.OAK_COLOR_PANEL_INNER = CopyThemeArray(initialThemeColors.panelInner)
addonTable.OAK_COLOR_PANEL_INNER_BORDER = CopyThemeArray(initialThemeColors.panelInnerBorder)
addonTable.OAK_COLOR_PANEL_TRIM = CopyThemeArray(initialThemeColors.panelTrim)

function addonTable.GetBackdropStyle(kind)
    if kind == "button" then
        return {
            bgFile = addonTable.FLAT_TEX,
            edgeFile = addonTable.FLAT_TEX,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        }
    end

    if addonTable.IsModernTheme and addonTable.IsModernTheme() then
        return {
            bgFile = addonTable.FLAT_TEX,
            edgeFile = addonTable.FLAT_TEX,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        }
    end

    if kind == "inset" then
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

function addonTable.ApplyBackdropStyle(frame, kind)
    if frame and frame.SetBackdrop then
        frame:SetBackdrop(addonTable.GetBackdropStyle(kind))
    end
end

function addonTable.GetThemeFramePadding()
    return 8
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
    local useModernConstructor = OakLFGSorterDB and OakLFGSorterDB.theme == THEME_MODE_MODERN
    if not useModernConstructor then
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(width, 22)
        btn:SetText(label)
        btn.OakUsesNativeButtonTheme = true
        btn.text = btn.Text
        if not btn.text then
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            btn.text:SetPoint("CENTER")
            btn:SetFontString(btn.text)
        end
        ApplyExplicitClassicButtonSkin(btn)
        if not btn.SetBackdropColor then
            function btn:SetBackdropColor() end
        end
        if not btn.SetBackdropBorderColor then
            function btn:SetBackdropBorderColor() end
        end

        function btn:SetLabel(text)
            self:SetText(text or "")
            self:RefreshAutoWidth()
        end

        function btn:SetAutoWidth(minWidth, maxWidth, padding)
            self.autoWidthMin = tonumber(minWidth) or self:GetWidth() or 0
            self.autoWidthMax = tonumber(maxWidth)
            self.autoWidthPadding = tonumber(padding) or 20
            self:RefreshAutoWidth()
        end

        function btn:RefreshAutoWidth()
            if not self.autoWidthMin then
                return
            end

            if not textMeasureFrame then
                textMeasureFrame = UIParent:CreateFontString(nil, "ARTWORK", "SorterClassic_FontRegular")
                textMeasureFrame:Hide()
            end

            local fontObject = self.text:GetFontObject() or GameFontNormal
            if fontObject then
                textMeasureFrame:SetFontObject(fontObject)
            end
            textMeasureFrame:SetText(self:GetText() or "")

            local targetWidth = math.ceil((textMeasureFrame:GetUnboundedStringWidth() or 0) + (self.autoWidthPadding or 20))
            targetWidth = math.max(self.autoWidthMin or 0, targetWidth)
            if self.autoWidthMax then
                targetWidth = math.min(self.autoWidthMax, targetWidth)
            end

            self:SetWidth(targetWidth)
        end

        registeredFlatButtons[btn] = btn
        return btn
    end

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, 22)
    btn.OakUsesNativeButtonTheme = false
    addonTable.ApplyBackdropStyle(btn, "button")
    HookModernBorderForwarding(btn)
    btn:SetBackdropColor(unpack(addonTable.OAK_COLOR_PANE))
    btn:SetBackdropBorderColor(0, 0, 0, 1)

    btn.text = btn:CreateFontString(nil, "OVERLAY", "SorterClassic_FontRegular")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(label)
    ApplyExplicitModernButtonSkin(btn, addonTable.OAK_COLOR_PANE)

    function btn:SetLabel(text)
        self.text:SetText(text or "")
        self:RefreshAutoWidth()
    end

    function btn:SetAutoWidth(minWidth, maxWidth, padding)
        self.autoWidthMin = tonumber(minWidth) or self:GetWidth() or 0
        self.autoWidthMax = tonumber(maxWidth)
        self.autoWidthPadding = tonumber(padding) or 20
        self:RefreshAutoWidth()
    end

    function btn:RefreshAutoWidth()
        if not self.autoWidthMin then
            return
        end

        if not textMeasureFrame then
            textMeasureFrame = UIParent:CreateFontString(nil, "ARTWORK", "SorterClassic_FontRegular")
            textMeasureFrame:Hide()
        end

        local fontObject = self.text:GetFontObject() or _G["SorterClassic_FontRegular"]
        if fontObject then
            textMeasureFrame:SetFontObject(fontObject)
        end
        textMeasureFrame:SetText(self.text:GetText() or "")

        local targetWidth = math.ceil((textMeasureFrame:GetUnboundedStringWidth() or 0) + (self.autoWidthPadding or 20))
        targetWidth = math.max(self.autoWidthMin or 0, targetWidth)
        if self.autoWidthMax then
            targetWidth = math.min(self.autoWidthMax, targetWidth)
        end

        self:SetWidth(targetWidth)
    end

    EnsureModernHoverFeedback(btn)
    registeredFlatButtons[btn] = btn
    return btn
end

function addonTable.CreateSimpleDropdown(parent, width, labelProvider, optionListProvider, onSelect)
    local useModernConstructor = OakLFGSorterDB and OakLFGSorterDB.theme == THEME_MODE_MODERN
    if useModernConstructor then
        local dropdownButton = addonTable.CreateFlatButton(parent, labelProvider(), width)
        local inheritedSetAutoWidth = dropdownButton.SetAutoWidth
        dropdownButton.arrow = dropdownButton:CreateTexture(nil, "ARTWORK")
        dropdownButton.arrow:SetSize(10, 10)
        dropdownButton.arrow:SetPoint("RIGHT", dropdownButton, "RIGHT", -6, 0)
        dropdownButton.arrow:SetTexture("Interface\\BUTTONS\\Arrow-Down-Up")
        dropdownButton.arrow:SetVertexColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
        dropdownButton.text:ClearAllPoints()
        dropdownButton.text:SetPoint("LEFT", dropdownButton, "LEFT", 8, 0)
        dropdownButton.text:SetPoint("RIGHT", dropdownButton.arrow, "LEFT", -4, 0)
        dropdownButton.text:SetJustifyH("CENTER")
        dropdownButton:HookScript("OnEnter", function(self)
            ApplyModernInteractiveBorder(self, true)
            if self.text then
                self.text:SetTextColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
            end
            if self.arrow then
                self.arrow:SetVertexColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
            end
        end)
        dropdownButton:HookScript("OnLeave", function(self)
            ApplyModernInteractiveBorder(self, false)
            if self.text then
                self.text:SetTextColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
            end
            if self.arrow then
                self.arrow:SetVertexColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
            end
        end)

        local listFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        addonTable.ApplyBackdropStyle(listFrame, "panel")
        listFrame:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
        listFrame:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
        listFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        listFrame:Hide()

        fontDropdownCounter = fontDropdownCounter + 1
        local scrollFrame = CreateFrame("ScrollFrame", "SorterClassicSimpleDropdownScroll" .. fontDropdownCounter, listFrame, "UIPanelScrollFrameTemplate")
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
            if dropdownButton.RefreshAutoWidth then
                dropdownButton:RefreshAutoWidth()
            end
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
                    optionButton.text = optionButton:CreateFontString(nil, "OVERLAY", "SorterClassic_FontRegular")
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

        function dropdownButton:SetAutoWidth(minWidth, maxWidth, padding)
            local extraPadding = (tonumber(padding) or 24) + 14
            if type(inheritedSetAutoWidth) == "function" then
                inheritedSetAutoWidth(self, minWidth, maxWidth, extraPadding)
            end
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

    local dropdownButton = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdownButton:SetWidth(width)
    dropdownButton:SetFrameLevel((parent:GetFrameLevel() or 1) + 2)

    local function GetSelectedOptionID()
        local options = optionListProvider() or {}
        local selectedLabel = tostring(labelProvider() or "")
        for _, option in ipairs(options) do
            if not option.separator and option.label == selectedLabel then
                return option.id
            end
        end
        return nil
    end

    local function RefreshSelection()
        local text = labelProvider() or ""
        local textWidget = dropdownButton.Text or (dropdownButton.GetFontString and dropdownButton:GetFontString()) or dropdownButton.text
        if textWidget and textWidget.SetText then
            textWidget:SetText(text)
        elseif dropdownButton.SetDefaultText then
            dropdownButton:SetDefaultText(text)
        elseif dropdownButton.OverrideText then
            dropdownButton:OverrideText(text)
        end
    end

    dropdownButton:SetupMenu(function(_, rootDescription)
        local options = optionListProvider() or {}
        local selectedID = GetSelectedOptionID()

        local function IsSelected(option)
            return option and option.id == selectedID
        end

        local function SelectOption(option)
            onSelect(option.id, option)
            C_Timer.After(0, RefreshSelection)
            return MenuResponse and (MenuResponse.CloseAll or MenuResponse.Close) or nil
        end

        for _, option in ipairs(options) do
            if option.separator then
                rootDescription:CreateTitle(option.label or "")
            else
                rootDescription:CreateRadio(option.label or "", IsSelected, SelectOption, option)
            end
        end
    end)

    function dropdownButton:RefreshSelection()
        RefreshSelection()
    end

    function dropdownButton:SetAutoWidth(minWidth, maxWidth, padding)
        if not textMeasureFrame then
            textMeasureFrame = UIParent:CreateFontString(nil, "ARTWORK", "SorterClassic_FontRegular")
            textMeasureFrame:Hide()
        end
        textMeasureFrame:SetFontObject(GameFontNormal)
        textMeasureFrame:SetText(labelProvider() or "")
        local targetWidth = math.ceil((textMeasureFrame:GetUnboundedStringWidth() or 0) + (tonumber(padding) or 32))
        targetWidth = math.max(tonumber(minWidth) or width or 0, targetWidth)
        if maxWidth then
            targetWidth = math.min(maxWidth, targetWidth)
        end
        self:SetWidth(targetWidth)
    end

    addonTable.RegisterThemeRefresh("simple_dropdown_" .. tostring(dropdownButton), function()
        RefreshSelection()
    end)
    dropdownButton:RefreshSelection()

    return dropdownButton, nil
end

function addonTable.CreateThemeModeDropdown(parent, width)
    return addonTable.CreateSimpleDropdown(
        parent,
        width,
        function() return addonTable.GetThemeModeLabel() end,
        function()
            local options = {}
            for _, themeMode in ipairs(addonTable.ThemeModes) do
                table.insert(options, { id = themeMode.id, label = themeMode.label })
            end
            return options
        end,
        function(id)
            addonTable.SetThemeMode(id)
        end
    )
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
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(size, size)
    btn:SetText("")
    btn.OakUsesNativeButtonTheme = true

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(size - 6, size - 6)
    btn.icon:SetPoint("CENTER")
    btn.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    btn.icon:SetTexCoord(0, 1, 0, 1)

    btn.fallback = btn:CreateFontString(nil, "OVERLAY", "SorterClassic_FontRegular")
    btn.fallback:SetPoint("CENTER")
    btn.fallback:SetText("O")
    btn.fallback:SetAlpha(0)
    if not btn.SetBackdropColor then
        function btn:SetBackdropColor() end
    end
    if not btn.SetBackdropBorderColor then
        function btn:SetBackdropBorderColor() end
    end
    HookModernBorderForwarding(btn)

    registeredCogButtons[btn] = btn
    if addonTable.IsClassicTheme and addonTable.IsClassicTheme() then
        ApplyExplicitClassicButtonSkin(btn)
    else
        ApplyExplicitModernButtonSkin(btn, addonTable.OAK_COLOR_PANE)
    end

    btn:HookScript("OnEnter", function(self)
        if addonTable.IsModernTheme and addonTable.IsModernTheme() then
            ApplyModernInteractiveBorder(self, true)
        end
    end)
    btn:HookScript("OnLeave", function(self)
        if addonTable.IsModernTheme and addonTable.IsModernTheme() then
            ApplyModernInteractiveBorder(self, false)
        end
    end)

    return btn
end
