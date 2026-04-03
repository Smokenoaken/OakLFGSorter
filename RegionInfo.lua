local addonName, addonTable = ...

local REGION_COLORS = {
    NA = { 0.72, 0.84, 1.00 },
    OCE = { 0.40, 0.92, 1.00 },
    LATAM = { 1.00, 0.82, 0.36 },
    BR = { 0.40, 1.00, 0.55 },
    EU = { 0.78, 0.78, 1.00 },
    OTHER = { 0.82, 0.82, 0.82 },
}

local REGION_META = {
    NA = { code = "NA", shortLabel = "NA", label = "North America" },
    OCE = { code = "OCE", shortLabel = "OCE", label = "Oceanic" },
    LATAM = { code = "LATAM", shortLabel = "LATAM", label = "Latin America" },
    BR = { code = "BR", shortLabel = "BR", label = "Brazil" },
    EU = { code = "EU", shortLabel = "EU", label = "Europe" },
    OTHER = { code = "OTHER", shortLabel = "OTHER", label = "Other" },
}

local OCE_REALMS = {
    ["amanthul"] = true,
    ["barthilas"] = true,
    ["caelestrasz"] = true,
    ["dathremar"] = true,
    ["frostmourne"] = true,
    ["gundrak"] = true,
    ["jubeithos"] = true,
    ["khazgoroth"] = true,
    ["nagrand"] = true,
    ["saurfang"] = true,
    ["thaurissan"] = true,
}

local LATAM_REALMS = {
    ["drakkari"] = true,
    ["quelthalas"] = true,
    ["ragnaros"] = true,
}

local BRAZIL_REALMS = {
    ["azralon"] = true,
    ["gallywix"] = true,
    ["goldrinn"] = true,
    ["nemesis"] = true,
    ["tolbarad"] = true,
}

local function NormalizeRealmToken(text)
    local value = strlower(tostring(text or ""))
    value = value:gsub("%s+", "")
    value = value:gsub("[^%w]", "")
    return value
end

local function GetRealmFromLeaderName(leaderName)
    local _, realmName = strsplit("-", tostring(leaderName or ""))
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
    local code = strlower(tostring(regionCode or ""))
    if code == "" then
        return nil
    end

    if code == "oce" then
        return "OCE"
    elseif code == "mex" then
        return "LATAM"
    elseif code == "bzl" or code == "br" then
        return "BR"
    elseif code == "chi" or code == "la" or code == "use" or code == "usc" or code == "usm" or code == "usp" then
        return "NA"
    elseif code == "eng" or code == "ger" or code == "fra" or code == "ita" or code == "spa" or code == "por" or code == "rus" then
        return "EU"
    end

    return "OTHER"
end

function addonTable.ShouldShowRegions()
    return OakLFGSorterDB and OakLFGSorterDB.showRegions == true
end

function addonTable.GetRegionInfoFromLeaderName(leaderName)
    local realmName = GetRealmFromLeaderName(leaderName)
    if realmName == "" then
        return nil
    end

    if PremadeRegions and type(PremadeRegions.GetRegion) == "function" then
        local ok, regionCode = pcall(PremadeRegions.GetRegion, leaderName)
        if ok then
            local mappedCode = MapPremadeRegionsCode(regionCode)
            if mappedCode then
                return BuildRegionInfo(mappedCode, realmName)
            end
        end
    end

    local normalizedRealm = NormalizeRealmToken(realmName)
    if OCE_REALMS[normalizedRealm] then
        return BuildRegionInfo("OCE", realmName)
    elseif BRAZIL_REALMS[normalizedRealm] then
        return BuildRegionInfo("BR", realmName)
    elseif LATAM_REALMS[normalizedRealm] then
        return BuildRegionInfo("LATAM", realmName)
    end

    return BuildRegionInfo("NA", realmName)
end

function addonTable.GetRegionBadgeMarkup(regionInfo)
    if not (addonTable.ShouldShowRegions() and type(regionInfo) == "table") then
        return ""
    end

    local color = regionInfo.color or REGION_COLORS.OTHER
    local shortLabel = tostring(regionInfo.shortLabel or regionInfo.code or "?")
    return string.format("|cFF%02x%02x%02x[%s]|r", color[1] * 255, color[2] * 255, color[3] * 255, shortLabel)
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
