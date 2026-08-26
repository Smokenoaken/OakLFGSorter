local _, addonTable = ...
local L = addonTable.L

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
    koKR = {
        "마이사라 동굴", "공결탑 제나스", "마법학자의 정원",
        "윈드러너 첨탑", "알게타르 대학", "삼두정의 권좌",
        "하늘탑", "사론의 구덩이",
    },
}

local defaultSeasonDelves_enUS = {
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
    "Gnarldor Isle",
    "The Ring of Glory",
}

local localizedSeasonDelves = {
    koKR = {
        "무리해 광장",
        "어둠의 은거처",
        "아탈아만",
        "대학 대소동",
        "어둠길",
        "황혼의 납골당",
        "기억의 만",
        "응어리의 구덩이",
        "어둠수호병 지점",
        "태양학살자 성소",
        "고통의 오름길",
    },
}

local currentLocale = GetLocale and GetLocale() or "enUS"
addonTable.SearchConfig.DefaultSeasonDelves = localizedSeasonDelves[currentLocale] or defaultSeasonDelves_enUS

addonTable.SearchConfig.DelveZoneMapIDs = {
    2393,
    2395,
    2405,
    2413,
    2437,
    2443,
    2424,
    2512, -- The Coiled Isle: Gnarldor Isle and The Ring of Glory
}

addonTable.SearchConfig.DelveLabelLookup = addonTable.SearchConfig.DelveLabelLookup or {}
wipe(addonTable.SearchConfig.DelveLabelLookup)

local function AddDelveLabelToLookup(delveName)
    if type(delveName) ~= "string" or delveName == "" then
        return
    end

    local normalizer = addonTable.GetPendingNativeActivityKey
    local key = normalizer and normalizer(delveName) or strlower(delveName)
    if key and key ~= "" then
        addonTable.SearchConfig.DelveLabelLookup[key] = true
    end

    addonTable.SearchConfig.DelveLabelLookup[strlower(delveName)] = true
end

for _, delveName in ipairs(addonTable.SearchConfig.DefaultSeasonDelves or {}) do
    AddDelveLabelToLookup(delveName)
end

local localizedDelves = addonTable.SearchConfig.GetSeasonDelves and addonTable.SearchConfig.GetSeasonDelves() or {}
for _, delveName in ipairs(localizedDelves) do
    AddDelveLabelToLookup(delveName)
end

local function NormalizeDelveLabel(label)
    local keyBuilder = addonTable.GetPendingNativeActivityKey
    if keyBuilder then
        return keyBuilder(label)
    end

    local text = strlower(tostring(label or ""))
    text = text:gsub("%s*%b()", "")
    text = text:gsub("[%(%)%[%]%-_:;,%.%!%?]", " ")
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
    { value = "ANY", label = L["Any Difficulty"] },
    { value = "NORMAL", label = L["Normal"] },
    { value = "HEROIC", label = L["Heroic"] },
    { value = "MYTHIC", label = L["Mythic"] },
    { value = "MYTHIC_PLUS", label = L["Mythic+"] },
}

addonTable.SearchConfig.DifficultyOptionsByMode = {
    mythic_plus = addonTable.SearchConfig.FiveManDifficultyOptions,
    dungeon = addonTable.SearchConfig.FiveManDifficultyOptions,
    raid = {
        { value = "ANY", label = L["Any Difficulty"] },
        { value = "NORMAL", label = L["Normal"] },
        { value = "HEROIC", label = L["Heroic"] },
        { value = "MYTHIC", label = L["Mythic"] },
    },
}
addonTable.SearchConfig.DifficultyOptionsByMode.legacy_raid = addonTable.SearchConfig.DifficultyOptionsByMode.raid
