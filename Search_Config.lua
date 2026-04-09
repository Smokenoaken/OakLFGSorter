local _, addonTable = ...

addonTable.SearchConfig = addonTable.SearchConfig or {}

addonTable.SearchConfig.DefaultSeasonDungeons = {
    "Maisara Caverns", "Nexus-Point Xenas", "Magisters' Terrace",
    "Windrunner Spire", "Algeth'ar Academy", "Seat of the Triumvirate",
    "Skyreach", "Pit of Saron",
}

addonTable.SearchConfig.LocalizedSeasonDungeons = addonTable.SearchConfig.LocalizedSeasonDungeons or {
    ruRU = {
        "Пещеры Майсары", "Узел Нексуса Зенас", "Терраса Магистров",
        "Шпиль Ветрокрылых", "Академия Алгет'ар", "Престол Триумвирата",
        "Небесный Путь", "Яма Сарона",
    },
}

addonTable.SearchConfig.DefaultSeasonDelves = {
    "Parhelion Plaza",
    "The Shadow Enclave",
    "Atal'Aman",
    "Collegiate Calamity",
    "The Darkway",
    "Twilight Crypts",
    "The Gulf of Memory",
    "The Grudge Pit",
    "Shadowguard Point",
    "Sunkiller Sanctum",
    "Torment's Rise",
}

addonTable.SearchConfig.DelveZoneMapIDs = {
    2393,
    2395,
    2405,
    2413,
    2437,
    2443,
    2424,
}

addonTable.SearchConfig.DelveLabelLookup = addonTable.SearchConfig.DelveLabelLookup or {}
wipe(addonTable.SearchConfig.DelveLabelLookup)
for _, delveName in ipairs(addonTable.SearchConfig.DefaultSeasonDelves) do
    addonTable.SearchConfig.DelveLabelLookup[strlower(delveName)] = true
end

local function NormalizeDelveLabel(label)
    local keyBuilder = addonTable.GetPendingNativeActivityKey
    if keyBuilder then
        return keyBuilder(label)
    end

    local text = strlower(tostring(label or ""))
    text = text:gsub("%s*%b()", "")
    text = text:gsub("[^%w%s']", " ")
    text = text:gsub("%s+", " ")
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

function addonTable.GetCurrentBountifulDelveLookup()
    local lookup = addonTable.SearchConfig.CurrentBountifulDelveLookup
    if type(lookup) ~= "table" then
        lookup = {}
        addonTable.SearchConfig.CurrentBountifulDelveLookup = lookup
    end
    return lookup
end

function addonTable.RefreshCurrentBountifulDelves()
    local lookup = addonTable.GetCurrentBountifulDelveLookup()
    local nextLookup = {}

    if not (C_AreaPoiInfo and C_AreaPoiInfo.GetDelvesForMap and C_AreaPoiInfo.GetAreaPOIInfo) then
        return false, lookup
    end

    for _, mapID in ipairs(addonTable.SearchConfig.DelveZoneMapIDs or {}) do
        local delvePoiIDs = C_AreaPoiInfo.GetDelvesForMap(mapID)
        if type(delvePoiIDs) == "table" then
            for _, poiID in ipairs(delvePoiIDs) do
                local poiInfo = C_AreaPoiInfo.GetAreaPOIInfo(mapID, poiID)
                if poiInfo and poiInfo.atlasName == "delves-bountiful" and poiInfo.name then
                    local normalized = NormalizeDelveLabel(poiInfo.name)
                    if normalized ~= "" then
                        nextLookup[normalized] = true
                    end
                end
            end
        end
    end

    local changed = false
    for key in pairs(lookup) do
        if not nextLookup[key] then
            changed = true
            break
        end
    end
    if not changed then
        for key in pairs(nextLookup) do
            if not lookup[key] then
                changed = true
                break
            end
        end
    end

    if changed then
        wipe(lookup)
        for key in pairs(nextLookup) do
            lookup[key] = true
        end
    end

    return changed, lookup
end

function addonTable.IsCurrentBountifulDelve(label)
    local normalized = NormalizeDelveLabel(label)
    if normalized == "" then
        return false
    end

    local lookup = addonTable.GetCurrentBountifulDelveLookup()
    if next(lookup) == nil then
        local _, refreshedLookup = addonTable.RefreshCurrentBountifulDelves()
        lookup = refreshedLookup or lookup
    end

    return lookup[normalized] == true
end

addonTable.SearchConfig.FiveManDifficultyOptions = {
    { value = "ANY", label = "Any Difficulty" },
    { value = "NORMAL", label = "Normal" },
    { value = "HEROIC", label = "Heroic" },
    { value = "MYTHIC", label = "Mythic" },
    { value = "MYTHIC_PLUS", label = "Mythic+" },
}

addonTable.SearchConfig.DifficultyOptionsByMode = {
    mythic_plus = addonTable.SearchConfig.FiveManDifficultyOptions,
    dungeon = addonTable.SearchConfig.FiveManDifficultyOptions,
    raid = {
        { value = "ANY", label = "Any Difficulty" },
        { value = "NORMAL", label = "Normal" },
        { value = "HEROIC", label = "Heroic" },
        { value = "MYTHIC", label = "Mythic" },
    },
}
