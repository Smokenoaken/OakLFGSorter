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

addonTable.SearchConfig.DelveLabelLookup = addonTable.SearchConfig.DelveLabelLookup or {}
wipe(addonTable.SearchConfig.DelveLabelLookup)
for _, delveName in ipairs(addonTable.SearchConfig.DefaultSeasonDelves) do
    addonTable.SearchConfig.DelveLabelLookup[strlower(delveName)] = true
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

