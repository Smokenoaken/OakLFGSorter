local addonName, addonTable = ...

local REGION_COLORS = {
    OCE = { 0.00, 0.60, 0.00 },
    LA = { 0.95, 0.95, 0.95 },
    CHI = { 0.95, 0.95, 0.95 },
    MEX = { 0.20, 0.85, 0.40 },
    BZL = { 0.85, 0.80, 0.10 },
    ENG = { 0.34, 0.82, 1.00 },
    GER = { 1.00, 0.84, 0.10 },
    FRA = { 1.00, 0.36, 0.36 },
    ITA = { 0.29, 1.00, 0.53 },
    SPA = { 1.00, 0.62, 0.11 },
    POR = { 0.74, 0.58, 0.98 },
    RUS = { 0.92, 0.92, 0.92 },
    OTHER = { 0.82, 0.82, 0.82 },
}

local REGION_META = {
    OCE = { code = "OCE", shortLabel = "OCE", label = "Oceanic", groupfinderRegion = "US" },
    LA = { code = "LA", shortLabel = "LA", label = "Los Angeles", groupfinderRegion = "US" },
    CHI = { code = "CHI", shortLabel = "CHI", label = "Chicago", groupfinderRegion = "US" },
    MEX = { code = "MEX", shortLabel = "MEX", label = "Mexican", groupfinderRegion = "US" },
    BZL = { code = "BZL", shortLabel = "BZL", label = "Brazil", groupfinderRegion = "US" },
    ENG = { code = "ENG", shortLabel = "ENG", label = "English", groupfinderRegion = "EU" },
    GER = { code = "GER", shortLabel = "GER", label = "German", groupfinderRegion = "EU" },
    FRA = { code = "FRA", shortLabel = "FRA", label = "French", groupfinderRegion = "EU" },
    ITA = { code = "ITA", shortLabel = "ITA", label = "Italian", groupfinderRegion = "EU" },
    SPA = { code = "SPA", shortLabel = "SPA", label = "Spanish", groupfinderRegion = "EU" },
    POR = { code = "POR", shortLabel = "POR", label = "Portuguese", groupfinderRegion = "EU" },
    RUS = { code = "RUS", shortLabel = "RUS", label = "Russian", groupfinderRegion = "EU" },
    OTHER = { code = "OTHER", shortLabel = "Oth", label = "Other", groupfinderRegion = nil },
}

local REGION_FILTER_ORDER = {
    "OCE", "CHI", "LA", "MEX", "BZL",
    "ENG", "GER", "FRA", "ITA", "SPA", "POR", "RUS",
    "OTHER",
}

local US_REGION_FILTER_ORDER = { "OCE", "CHI", "LA", "MEX", "BZL", "OTHER" }
local EU_REGION_FILTER_ORDER = { "ENG", "GER", "FRA", "ITA", "SPA", "POR", "RUS", "OTHER" }

local REGION_ALIASES = {
    oce = "OCE",
    la = "LA",
    chi = "CHI",
    mex = "MEX",
    bzl = "BZL",
    br = "BZL",
    eng = "ENG",
    ger = "GER",
    fra = "FRA",
    ita = "ITA",
    spa = "SPA",
    por = "POR",
    rus = "RUS",
}

local REGION_REALMS = {
    OCE = {
        "Aman'Thul", "Barthilas", "Caelestrasz", "Dath'Remar", "Dreadmaul", "Frostmourne",
        "Gundrak", "Jubei'Thos", "Khaz'goroth", "Nagrand", "Saurfang", "Thaurissan",
    },
    LA = {
        "Aegwynn", "Akama", "Antonidas", "Anub'arak", "Arathor", "Azjol-Nerub", "Blackrock",
        "Blackwater Raiders", "Bladefist", "Bloodscalp", "Bonechewer", "Borean Tundra",
        "Boulderfist", "Bronzebeard", "Cairne", "Cenarion Circle", "Cenarius", "Chromaggus",
        "Crushridge", "Daggerspine", "Darkspear", "Darrowmere", "Draenor", "Dragonblight",
        "Dragonmaw", "Drak'Tharon", "Drak'thul", "Draka", "Drenden", "Dunemaul", "Echo Isles",
        "Eitrigg", "Eldre'Thalas", "Farstriders", "Feathermoon", "Fenris", "Firetree",
        "Frostmane", "Frostwolf", "Garithos", "Garrosh", "Gurubashi", "Hakkar", "Hydraxis",
        "Hyjal", "Khaz Modan", "Kil'jaeden", "Kilrogg", "Korgath", "Korialstrasz", "Kul Tiras",
        "Lightbringer", "Maiev", "Malorne", "Misha", "Mok'Nathal", "Moon Guard", "Mug'thol",
        "Muradin", "Nathrezim", "Nazgrel", "Ner'zhul", "Nesingwary", "Nordrassil", "Perenolde",
        "Proudmoore", "Quel'dorei", "Rexxar", "Rivendare", "Runetotem", "Scarlet Crusade",
        "Sen'jin", "Shadow Council", "Shadowsong", "Shandris", "Shu'halo", "Silver Hand",
        "Silvermoon", "Sisters of Elune", "Skywall", "Smolderthorn", "Spirestone", "Stonemaul",
        "Stormscale", "Suramar", "Terenas", "Thorium Brotherhood", "Tichondrius", "Tortheldrin",
        "Uldum", "Uther", "Vashj", "Vek'nilash", "Windrunner", "Winterhoof", "Wyrmrest Accord",
    },
    CHI = {
        "Aerie Peak", "Agamaggan", "Aggramar", "Alexstrasza", "Alleria", "Altar of Storms",
        "Alterac Mountains", "Andorhal", "Anetheron", "Anvilmar", "Archimonde", "Area 52",
        "Argent Dawn", "Arthas", "Arygos", "Auchindoun", "Azgalor", "Azshara", "Azuremyst",
        "Baelgun", "Balnazzar", "Black Dragonflight", "Blackhand", "Blackwing Lair",
        "Blade's Edge", "Bleeding Hollow", "Blood Furnace", "Bloodhoof", "Burning Blade",
        "Burning Legion", "Cho'gall", "Coilfang", "Dalaran", "Dalvengyr", "Dark Iron",
        "Dawnbringer", "Deathwing", "Demon Soul", "Dentarg", "Destromath", "Dethecus",
        "Detheroc", "Doomhammer", "Durotan", "Duskwood", "Earthen Ring", "Elune",
        "Emerald Dream", "Eonar", "Eredar", "Executus", "Exodar", "Fizzcrank", "Galakrond",
        "Garona", "Ghostlands", "Gilneas", "Gnomeregan", "Gorefiend", "Gorgonnash",
        "Greymane", "Grizzly Hills", "Gul'dan", "Haomarush", "Hellscream", "Icecrown",
        "Illidan", "Jaedenar", "Kael'thas", "Kalecgos", "Kargath", "Kel'Thuzad", "Khadgar",
        "Kirin Tor", "Laughing Skull", "Lethon", "Lightning's Blade", "Lightninghoof",
        "Llane", "Lothar", "Madoran", "Maelstrom", "Magtheridon", "Mal'Ganis", "Malfurion",
        "Malygos", "Mannoroth", "Medivh", "Moonrunner", "Nazjatar", "Norgannon", "Onyxia",
        "Ravencrest", "Ravenholdt", "Sargeras", "Scilla", "Sentinels", "Shadowmoon",
        "Shattered Halls", "Shattered Hand", "Skullcrusher", "Spinebreaker", "Staghelm",
        "Steamwheedle Cartel", "Stormrage", "Stormreaver", "Tanaris", "Terokkar",
        "The Forgotten Coast", "The Scryers", "The Underbog", "The Venture Co", "Thrall",
        "Thunderhorn", "Thunderlord", "Trollbane", "Turalyon", "Twisting Nether", "Uldaman",
        "Undermine", "Ursin", "Velen", "Warsong", "Whisperwind", "Wildhammer", "Ysera",
        "Ysondre", "Zangarmarsh", "Zul'jin", "Zuluhed",
    },
    MEX = { "Drakkari", "Quel'Thalas", "Ragnaros" },
    BZL = { "Azralon", "Gallywix", "Goldrinn", "Nemesis", "Tol Barad" },
    ENG = {
        "Aerie Peak", "Agamaggan", "Aggramar", "Ahn'Qiraj", "Al'Akir", "Alonsus", "Anachronos",
        "Arathor", "Argent Dawn", "Aszune", "Auchindoun", "Azjol-Nerub", "Azuremyst",
        "Balnazzar", "Blade's Edge", "Bladefist", "Bloodfeather", "Bloodhoof", "Bloodscalp",
        "Boulderfist", "Bronze Dragonflight", "Bronzebeard", "Burning Blade", "Burning Legion",
        "Burning Steppes", "Chamber of Aspects", "Chromaggus", "Crushridge", "Daggerspine",
        "Darkmoon Faire", "Darksorrow", "Darkspear", "Deathwing", "Defias Brotherhood",
        "Dentarg", "Doomhammer", "Draenor", "Dragonblight", "Dragonmaw", "Drak'thul",
        "Dunemaul", "Earthen Ring", "Emerald Dream", "Emeriss", "Eonar", "Executus",
        "Frostmane", "Frostwhisper", "Genjuros", "Ghostlands", "Grim Batol", "Hakkar",
        "Haomarush", "Hellfire", "Hellscream", "Jaedenar", "Karazhan", "Kazzak", "Khadgar",
        "Kilrogg", "Kor'gall", "Kul Tiras", "Laughing Skull", "Lightbringer", "Lightning's Blade",
        "Magtheridon", "Mazrigos", "Moonglade", "Nagrand", "Neptulon", "Nordrassil", "Outland",
        "Quel'Thalas", "Ragnaros", "Ravencrest", "Ravenholdt", "Runetotem", "Saurfang",
        "Scarshield Legion", "Shadowsong", "Shattered Halls", "Shattered Hand", "Silvermoon",
        "Skullcrusher", "Spinebreaker", "Sporeggar", "Steamwheedle Cartel", "Stormrage",
        "Stormreaver", "Stormscale", "Sunstrider", "Sylvanas", "Talnivarr", "Tarren Mill",
        "Terenas", "Terokkar", "The Maelstrom", "The Sha'tar", "The Venture Co", "Thunderhorn",
        "Trollbane", "Turalyon", "Twilight's Hammer", "Twisting Nether", "Vashj", "Vek'nilash",
        "Wildhammer", "Xavius", "Zenedar",
    },
    GER = {
        "Aegwynn", "Alexstrasza", "Alleria", "Aman'Thul", "Ambossar", "Anetheron", "Antonidas",
        "Anub'arak", "Area 52", "Arthas", "Arygos", "Azshara", "Baelgun", "Blackhand",
        "Blackmoore", "Blackrock", "Blutkessel", "Dalvengyr", "Das Konsortium", "Das Syndikat",
        "Der abyssische Rat", "Der Mithrilorden", "Der Rat von Dalaran", "Destromath",
        "Dethecus", "Die Aldor", "Die Arguswacht", "Die ewige Wacht", "Die Nachtwache",
        "Die Silberne Hand", "Die Todeskrallen", "Dun Morogh", "Durotan", "Echsenkessel",
        "Eredar", "Festung der Stürme", "Forscherliga", "Frostmourne", "Frostwolf", "Garrosh",
        "Gilneas", "Gorgonnash", "Gul'dan", "Kargath", "Kel'Thuzad", "Khaz'goroth", "Kil'jaeden",
        "Krag'jin", "Kult der Verdammten", "Lordaeron", "Lothar", "Madmortem", "Mal'Ganis",
        "Malfurion", "Malorne", "Malygos", "Mannoroth", "Mug'thol", "Nathrezim", "Nazjatar",
        "Nefarian", "Nera'thor", "Nethersturm", "Norgannon", "Nozdormu", "Onyxia", "Perenolde",
        "Proudmoore", "Rajaxx", "Rexxar", "Sen'jin", "Shattrath", "Taerar", "Teldrassil",
        "Terrordar", "Theradras", "Thrall", "Tichondrius", "Tirion", "Todeswache", "Ulduar",
        "Un'Goro", "Vek'lor", "Wrathbringer", "Ysera", "Zirkel des Cenarius", "Zuluhed",
    },
    FRA = {
        "Arak-arahm", "Arathi", "Archimonde", "Chants éternels", "Cho'gall", "Confrérie du Thorium",
        "Conseil des Ombres", "Culte de la Rive noire", "Dalaran", "Drek'Thar", "Eitrigg",
        "Eldre'Thalas", "Elune", "Garona", "Hyjal", "Illidan", "Kael'thas", "Khaz Modan",
        "Kirin Tor", "Krasus", "La Croisade écarlate", "Les Clairvoyants", "Les Sentinelles",
        "Marécage de Zangar", "Medivh", "Naxxramas", "Ner'zhul", "Rashgarroth", "Sargeras",
        "Sinstralis", "Suramar", "Temple noir", "Throk'Feroth", "Uldaman", "Varimathras",
        "Vol'jin", "Ysondre",
    },
    SPA = { "C'Thun", "Colinas Pardas", "Dun Modr", "Exodar", "Los Errantes", "Minahonda", "Sanguino", "Shen'dralar", "Tyrande", "Uldum", "Zul'jin" },
    POR = { "Aggra (Português)" },
    RUS = {
        "Азурегос", "Борейская тундра", "Вечная Песня", "Галакронд", "Голдринн", "Гордунни",
        "Гром", "Дракономор", "Король-лич", "Пиратская Бухта", "Подземье", "Разувий",
        "Ревущий фьорд", "Свежеватель Душ", "Седогрив", "Страж Смерти", "Термоштепсель",
        "Ткач Смерти", "Черный Шрам", "Ясеневый лес",
    },
    ITA = { "Nemesis", "Pozzo dell'Eternità" },
}

local REALM_TO_REGION = {}
local US_REALM_TO_REGION = {}
local EU_REALM_TO_REGION = {}

local function NormalizeRealmToken(text)
    local value = strlower(tostring(text or ""))
    value = value:gsub("[%s%p]", "")
    return value
end

for regionCode, realmNames in pairs(REGION_REALMS) do
    for _, realmName in ipairs(realmNames) do
        local normalizedRealm = NormalizeRealmToken(realmName)
        REALM_TO_REGION[normalizedRealm] = regionCode
        local meta = REGION_META[regionCode]
        if meta and meta.groupfinderRegion == "US" then
            US_REALM_TO_REGION[normalizedRealm] = regionCode
        elseif meta and meta.groupfinderRegion == "EU" then
            EU_REALM_TO_REGION[normalizedRealm] = regionCode
        end
    end
end

local function NormalizeGroupfinderFlagsRealm(text)
    local value = tostring(text or "")
    value = value:gsub("[%s%-]", "")
    return value
end

local FLAG_ICON_SIZE = ":9:15|t"
local FLAG_IMAGE_PATH = "|TInterface\\AddOns\\GroupfinderFlags\\flag_icons\\"
local FLAG_KEYS = {
    german = "german" .. FLAG_ICON_SIZE,
    british = "british" .. FLAG_ICON_SIZE,
    portuguese = "portuguese" .. FLAG_ICON_SIZE,
    russian = "russian" .. FLAG_ICON_SIZE,
    french = "french" .. FLAG_ICON_SIZE,
    spanish = "spanish" .. FLAG_ICON_SIZE,
    italian = "italian" .. FLAG_ICON_SIZE,
    american = "american" .. FLAG_ICON_SIZE,
    brazilian = "brazilian" .. FLAG_ICON_SIZE,
    oceanic = "oceanic" .. FLAG_ICON_SIZE,
    mexican = "mexican" .. FLAG_ICON_SIZE,
}

local function IsGroupfinderFlagsLoaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded("GroupfinderFlags")
    end
    if IsAddOnLoaded then
        return IsAddOnLoaded("GroupfinderFlags")
    end
    return false
end

local function GetGroupfinderFlagsRealmTable(regionInfo)
    if not IsGroupfinderFlagsLoaded() or type(GroupfinderFlags) ~= "table" then
        return nil
    end

    local meta = type(regionInfo) == "table" and REGION_META[regionInfo.code or ""] or nil
    if not meta then
        return nil
    end

    if meta.groupfinderRegion == "EU" then
        return GroupfinderFlags.EU_REALM_LANGUAGES
    elseif meta.groupfinderRegion == "US" then
        return GroupfinderFlags.US_REALM_LANGUAGES
    end

    return nil
end

local function GetFlagKeyForRegionInfo(regionInfo)
    if type(regionInfo) ~= "table" then
        return nil
    end

    local code = tostring(regionInfo.code or "")
    if code == "CHI" or code == "LA" then
        return "american"
    elseif code == "OCE" then
        return "oceanic"
    elseif code == "MEX" then
        return "mexican"
    elseif code == "BZL" then
        return "brazilian"
    end

    local realmName = tostring(regionInfo.realm or "")
    if realmName == "" then
        return nil
    end

    local realmTable = GetGroupfinderFlagsRealmTable(regionInfo)
    if type(realmTable) ~= "table" then
        return nil
    end

    local flagKey = realmTable[realmName] or realmTable[NormalizeGroupfinderFlagsRealm(realmName)]
    if flagKey and FLAG_KEYS[flagKey] then
        return flagKey
    end

    return nil
end

function addonTable.GetRegionSortKey(regionInfo)
    if type(regionInfo) ~= "table" then
        return "zzz_other"
    end

    if addonTable.ShouldShowRegionFlags and addonTable.ShouldShowRegionFlags() then
        local flagKey = GetFlagKeyForRegionInfo(regionInfo)
        if flagKey then
            return "flag_" .. flagKey
        end
    end

    local code = tostring(regionInfo.code or "OTHER")
    for index, regionCode in ipairs(REGION_FILTER_ORDER) do
        if code == regionCode then
            return string.format("region_%02d_%s", index, strlower(code))
        end
    end

    return "region_99_other"
end

local function GetRealmFromLeaderName(leaderName)
    local fullName = tostring(leaderName or "")
    if fullName ~= "" and Ambiguate then
        local shortName = Ambiguate(fullName, "short")
        local mailName = Ambiguate(fullName, "mail")
        if shortName and mailName and shortName ~= "" and mailName ~= "" then
            if shortName == mailName then
                if GetRealmName then
                    return GetRealmName() or ""
                end
            elseif mailName:sub(1, #shortName + 1) == shortName .. "-" then
                return mailName:sub(#shortName + 2)
            end
        end
    end

    local _, realmName = strsplit("-", fullName)
    if realmName and realmName ~= "" then
        return realmName
    end

    if GetNormalizedRealmName then
        return GetNormalizedRealmName() or ""
    end

    return ""
end

local function BuildRegionInfo(code, realmName)
    local meta = REGION_META[code] or REGION_META.OTHER
    local color = REGION_COLORS[meta.code] or REGION_COLORS.OTHER
    return {
        code = meta.code,
        shortLabel = meta.shortLabel,
        label = meta.label,
        realm = realmName,
        color = color,
    }
end

local function MapPremadeRegionsCode(regionCode)
    return REGION_ALIASES[strlower(tostring(regionCode or ""))]
end

function addonTable.ShouldShowRegions()
    return OakLFGSorterDB and OakLFGSorterDB.showRegions == true
end

function addonTable.CanShowRegionFlags()
    return IsGroupfinderFlagsLoaded() and type(GroupfinderFlags) == "table"
end

function addonTable.ShouldShowRegionFlags()
    return addonTable.ShouldShowRegions() and OakLFGSorterDB and OakLFGSorterDB.showRegionFlags == true and addonTable.CanShowRegionFlags()
end

function addonTable.GetRegionFilterOrder()
    return REGION_FILTER_ORDER
end

function addonTable.GetPlayerRegionFamily()
    local currentRegion = GetCurrentRegion and tonumber(GetCurrentRegion()) or nil
    if currentRegion == 3 then
        return "EU"
    elseif currentRegion == 1 or currentRegion == 2 or currentRegion == 4 or currentRegion == 5 then
        return "US"
    end

    local realmName = GetNormalizedRealmName and GetNormalizedRealmName() or ""
    local normalizedRealm = NormalizeRealmToken(realmName)
    if normalizedRealm ~= "" then
        if EU_REALM_TO_REGION[normalizedRealm] then
            return "EU"
        elseif US_REALM_TO_REGION[normalizedRealm] then
            return "US"
        end
    end

    return "US"
end

function addonTable.GetVisibleRegionFilterOrder()
    if addonTable.GetPlayerRegionFamily and addonTable.GetPlayerRegionFamily() == "EU" then
        return EU_REGION_FILTER_ORDER
    end

    return US_REGION_FILTER_ORDER
end

local function EnsureRegionFilterState()
    local filters = addonTable.GetCharacterRegionFilters and addonTable.GetCharacterRegionFilters() or {}

    local hasExplicitCurrentValue = false
    for _, regionCode in ipairs(REGION_FILTER_ORDER) do
        if filters[regionCode] ~= nil then
            hasExplicitCurrentValue = true
            break
        end
    end

    if not hasExplicitCurrentValue then
        local legacyNA = filters.NA
        local legacyEU = filters.EU
        local legacyLATAM = filters.LATAM
        local legacyBR = filters.BR
        local legacyOther = filters.OTHER
        local hasLegacy = legacyNA ~= nil or legacyEU ~= nil or legacyLATAM ~= nil or legacyBR ~= nil or legacyOther ~= nil

        if hasLegacy then
            filters.OCE = legacyNA ~= false
            filters.CHI = legacyNA ~= false
            filters.LA = legacyNA ~= false
            filters.MEX = legacyLATAM ~= nil and legacyLATAM ~= false or legacyNA ~= false
            filters.BZL = legacyBR ~= nil and legacyBR ~= false or legacyNA ~= false
            filters.ENG = legacyEU ~= false
            filters.GER = legacyEU ~= false
            filters.FRA = legacyEU ~= false
            filters.ITA = legacyEU ~= false
            filters.SPA = legacyEU ~= false
            filters.POR = legacyEU ~= false
            filters.RUS = legacyEU ~= false
            filters.OTHER = legacyOther ~= false
        else
            for _, regionCode in ipairs(REGION_FILTER_ORDER) do
                filters[regionCode] = true
            end
        end
    else
        for _, regionCode in ipairs(REGION_FILTER_ORDER) do
            if filters[regionCode] == nil then
                filters[regionCode] = true
            end
        end
    end

    local hasAnyEnabled = false
    for _, regionCode in ipairs(REGION_FILTER_ORDER) do
        if filters[regionCode] ~= false then
            hasAnyEnabled = true
            break
        end
    end

    if not hasAnyEnabled then
        local playerRegion = addonTable.GetPlayerRegionInfo and addonTable.GetPlayerRegionInfo() or nil
        if playerRegion and playerRegion.code and filters[playerRegion.code] ~= nil then
            filters[playerRegion.code] = true
        else
            filters[REGION_FILTER_ORDER[1]] = true
        end
    end

    filters.NA = nil
    filters.EU = nil
    filters.LATAM = nil
    filters.BR = nil
    OakLFGSorterDB.lowLatencyOnly = nil

    return filters
end

function addonTable.GetRegionFilters()
    return EnsureRegionFilterState()
end

function addonTable.IsRegionEnabled(regionCode)
    local filters = EnsureRegionFilterState()
    if not regionCode or regionCode == "" then
        return true
    end
    return filters[regionCode] ~= false
end

function addonTable.SetRegionEnabled(regionCode, isEnabled)
    if not regionCode or regionCode == "" then
        return false
    end

    local filters = EnsureRegionFilterState()
    if isEnabled then
        filters[regionCode] = true
        return true
    end

    local enabledCount = 0
    for _, code in ipairs(REGION_FILTER_ORDER) do
        if filters[code] ~= false then
            enabledCount = enabledCount + 1
        end
    end

    if enabledCount <= 1 and filters[regionCode] ~= false then
        return false
    end

    filters[regionCode] = false
    return true
end

function addonTable.GetRegionMeta(regionCode)
    return REGION_META[regionCode] or REGION_META.OTHER
end

local function GetRegionInfoForRealm(realmName, lookupToken)
    if realmName == "" then
        return nil
    end

    if lookupToken and PremadeRegions and type(PremadeRegions.GetRegion) == "function" then
        local ok, regionCode = pcall(PremadeRegions.GetRegion, lookupToken)
        if ok then
            local mappedCode = MapPremadeRegionsCode(regionCode)
            if mappedCode then
                return BuildRegionInfo(mappedCode, realmName)
            end
        end
    end

    local normalizedRealm = NormalizeRealmToken(realmName)
    local playerRegionFamily = addonTable.GetPlayerRegionFamily and addonTable.GetPlayerRegionFamily() or nil
    local mappedCode
    if playerRegionFamily == "EU" then
        mappedCode = EU_REALM_TO_REGION[normalizedRealm] or REALM_TO_REGION[normalizedRealm]
    else
        mappedCode = US_REALM_TO_REGION[normalizedRealm] or REALM_TO_REGION[normalizedRealm]
    end
    if mappedCode then
        return BuildRegionInfo(mappedCode, realmName)
    end

    return BuildRegionInfo("OTHER", realmName)
end

function addonTable.GetRegionInfoFromLeaderName(leaderName)
    local realmName = GetRealmFromLeaderName(leaderName)
    return GetRegionInfoForRealm(realmName, leaderName)
end

function addonTable.GetPlayerRegionInfo()
    local realmName = GetNormalizedRealmName and GetNormalizedRealmName() or ""
    if realmName == "" then
        return nil
    end

    local playerName = UnitName and UnitName("player") or nil
    local lookupToken = playerName and (playerName .. "-" .. realmName) or realmName
    return GetRegionInfoForRealm(realmName, lookupToken)
end

function addonTable.ResultMatchesPlayerRegion(result)
    local filters = EnsureRegionFilterState()
    local hasAnyFilteredOut = false
    for _, regionCode in ipairs(REGION_FILTER_ORDER) do
        if filters[regionCode] == false then
            hasAnyFilteredOut = true
            break
        end
    end

    if not hasAnyFilteredOut then
        return true
    end

    local resultRegion = type(result) == "table" and result.regionInfo or nil
    if not resultRegion and type(result) == "table" and addonTable.GetRegionInfoFromLeaderName then
        resultRegion = addonTable.GetRegionInfoFromLeaderName(result.leaderName or result.leaderNameRaw)
    end

    if not resultRegion then
        return addonTable.IsRegionEnabled("OTHER")
    end

    return addonTable.IsRegionEnabled(tostring(resultRegion.code or "OTHER"))
end

function addonTable.GetRegionBadgeMarkup(regionInfo)
    if not (addonTable.ShouldShowRegions() and type(regionInfo) == "table") then
        return ""
    end

    if addonTable.ShouldShowRegionFlags() then
        local flagKey = GetFlagKeyForRegionInfo(regionInfo)
        if flagKey then
            local flagMarkup = FLAG_IMAGE_PATH .. FLAG_KEYS[flagKey]
            if regionInfo.code == "LA" or regionInfo.code == "CHI" then
                local color = regionInfo.color or REGION_COLORS.OTHER
                local shortLabel = tostring(regionInfo.shortLabel or regionInfo.code or "?")
                return string.format("%s\n|cFF%02x%02x%02x%s|r", flagMarkup, color[1] * 255, color[2] * 255, color[3] * 255, shortLabel)
            end
            return flagMarkup
        end
    end

    local color = regionInfo.color or REGION_COLORS.OTHER
    local shortLabel = tostring(regionInfo.shortLabel or regionInfo.code or "?")
    return string.format("|cFF%02x%02x%02x%s|r", color[1] * 255, color[2] * 255, color[3] * 255, shortLabel)
end

function addonTable.AddRegionTooltipLine(tooltip, regionInfo)
    if not (tooltip and addonTable.ShouldShowRegions() and type(regionInfo) == "table") then
        return
    end

    local color = regionInfo.color or REGION_COLORS.OTHER
    local label = tostring(regionInfo.label or regionInfo.shortLabel or regionInfo.code or "Unknown")
    local realm = tostring(regionInfo.realm or "")
    if realm ~= "" then
        label = string.format("%s (%s)", label, realm)
    end

    tooltip:AddDoubleLine("Region:", label, 0.60, 0.85, 1.00, color[1], color[2], color[3])
end
