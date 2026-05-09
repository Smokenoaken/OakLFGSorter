local _, addonTable = ...
local L = addonTable.L

function addonTable.GetPendingNativeActivityKey(label)
    local text = strlower(tostring(label or ""))
    text = text:gsub("%s*%b()", "")
    text = text:gsub("[^%w%s]", " ")
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text
end

function addonTable.SearchModeUsesDifficulty(mode)
    return mode == "mythic_plus" or mode == "dungeon" or mode == "raid" or mode == "legacy_raid"
end

function addonTable.SearchModeUsesActivityFilters(mode)
    return mode == "mythic_plus" or mode == "dungeon" or mode == "raid" or mode == "legacy_raid" or mode == "delve"
end

function addonTable.SearchModeUsesHostedSearch(mode)
    return mode == "mythic_plus" or mode == "dungeon" or mode == "generic" or mode == "delve"
end

function addonTable.SearchModeUsesNativeDungeonFilters(mode)
    return mode == "mythic_plus" or mode == "dungeon"
end

function addonTable.GetSearchDifficultyOptions(mode)
    local config = addonTable.SearchConfig or {}
    local optionsByMode = config.DifficultyOptionsByMode or {}
    return optionsByMode[mode] or {}
end

function addonTable.SearchDifficultyIsValidForMode(mode, difficultyValue)
    if difficultyValue == "ANY" then
        return true
    end

    for _, option in ipairs(addonTable.GetSearchDifficultyOptions(mode)) do
        if option.value == difficultyValue then
            return true
        end
    end

    return false
end

function addonTable.GetSearchActivitySectionTitle(mode)
    if mode == "raid" or mode == "legacy_raid" then
        return L["Filter Raids"]
    elseif mode == "delve" then
        return L["Filter Delves"]
    elseif mode == "mythic_plus" or mode == "dungeon" then
        return L["Filter Dungeons"]
    end

    return nil
end

function addonTable.GetSearchQueryLabel(mode)
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

function addonTable.GetNeedsMyClassLabel()
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

function addonTable.GetLocalizedSeasonDungeonLabels()
    local config = addonTable.SearchConfig or {}
    local currentLocale = GetLocale and GetLocale() or "enUS"
    local localizedDefaults = config.LocalizedSeasonDungeons and config.LocalizedSeasonDungeons[currentLocale]
    local fallbackDefaults = config.DefaultSeasonDungeons or {}

    if not (C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapUIInfo) then
        return localizedDefaults or fallbackDefaults
    end

    local labels = {}
    local seen = {}
    local mapIDs = C_ChallengeMode.GetMapTable()
    if type(mapIDs) ~= "table" then
        return localizedDefaults or fallbackDefaults
    end

    local getRaidFilterLabel = addonTable.GetSearchRaidFilterLabel
    local normalizeScoreTargetLabel = addonTable.NormalizeSearchScoreTargetLabel

    for _, mapID in ipairs(mapIDs) do
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        local cleanName = getRaidFilterLabel and getRaidFilterLabel({ fullName = name }) or tostring(name or "")
        local key = normalizeScoreTargetLabel and normalizeScoreTargetLabel(cleanName) or strlower(cleanName)
        if cleanName ~= "" and key ~= "" and not seen[key] then
            seen[key] = true
            table.insert(labels, cleanName)
        end
    end

    if #labels > 0 then
        return labels
    end

    return localizedDefaults or fallbackDefaults
end
