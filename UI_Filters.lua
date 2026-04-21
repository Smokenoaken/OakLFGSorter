local addonName, addonTable = ...
local L = addonTable.L
local OAK_LFG = addonTable.OAK_LFG

addonTable.ClassFilters = addonTable.GetApplicantClassFilters and addonTable.GetApplicantClassFilters() or {}
addonTable.RoleFilters = addonTable.GetApplicantRoleFilters and addonTable.GetApplicantRoleFilters() or { ["TANK"] = true, ["HEALER"] = true, ["DAMAGER"] = true }
for _, class in ipairs(addonTable.ValidClasses) do
    if addonTable.ClassFilters[class] == nil then
        addonTable.ClassFilters[class] = true
    end
end
for _, role in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
    if addonTable.RoleFilters[role] == nil then
        addonTable.RoleFilters[role] = true
    end
end
local classToggleBoxes = {} 
local quickFilterButtons = {}
local browserFilterButtons = {}
local browserActivityButtons = {}
local BrowserFilterState
local SyncVisibleBrowserActivityButtonStates
local browserMinRatingBox
local BROWSER_FILTER_VERSION = 8
local GetPartyRoleSupply
local ROLE_REMAINING_KEYS = {
    TANK = "TANK_REMAINING",
    HEALER = "HEALER_REMAINING",
    DAMAGER = "DAMAGER_REMAINING",
}
addonTable.UtilityRoleOptions = addonTable.UtilityRoleOptions or {
    LUST = { HEALER = true, DAMAGER = true },
    BREZ = { TANK = true, HEALER = true, DAMAGER = true },
}
local applicantRegionToggleBox
local applicantRegionToggleLabel
local browserRegionToggleBox
local browserRegionToggleLabel
local regionFilterButtons = {}
local regionFilterLabels = {}
local optionsStyleButton
local optionsStyleList
local optionsThemeButton
local optionsThemeList
local optionsThemeColorButton
local categoryDropdownButton
local categoryDropdownList

local function GetBrowserMode()
    local mode = addonTable.CurrentSearchContext and addonTable.CurrentSearchContext.mode
    if not mode or mode == "generic" then
        -- Context hasn't been resolved yet (e.g. first open before results load).
        -- Try to infer mode from the first available search result.
        local first = addonTable.SearchResults and addonTable.SearchResults[1]
        if first and first.mode and first.mode ~= "generic" then
            mode = first.mode
        end
    end
    return mode or "generic"
end

local function BrowserModeUsesDifficulty(mode)
    return mode == "mythic_plus" or mode == "dungeon" or mode == "raid"
end

local function BrowserModeUsesKeyRange(mode)
    return mode == "mythic_plus"
end

local function BrowserModeUsesActivityFilter(mode)
    return mode == "mythic_plus" or mode == "dungeon" or mode == "raid" or mode == "delve"
end

local function SetQuickFilterButtonState(button, isActive)
    if not button then return end

    if isActive then
        button:SetBackdropColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    else
        button:SetBackdropColor(unpack(addonTable.OAK_COLOR_PANE))
    end
    button:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
end

local function GroupMatchesRoleFilters(group)
    local effectiveRoleFilters = addonTable.RoleFilters
    if OakLFGSorterDB and OakLFGSorterDB.autoHideFilledRoles then
        local partyRoles, _ = GetPartyRoleSupply()
        local targets = { TANK = 1, HEALER = 1, DAMAGER = 3 }
        local entryInfo = C_LFGList and C_LFGList.GetActiveEntryInfo and C_LFGList.GetActiveEntryInfo()
        local activityID = entryInfo and tonumber(entryInfo.activityID)
        if activityID == 0 then
            activityID = nil
        end
        local activityInfo = activityID and C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(activityID)
        local maxPlayers = tonumber(activityInfo and activityInfo.maxPlayers) or 5

        if maxPlayers > 5 then
            targets.TANK = math.max(1, math.min(2, math.ceil(maxPlayers / 10)))
            targets.HEALER = math.max(2, math.floor(maxPlayers / 5))
            targets.DAMAGER = math.max(1, maxPlayers - targets.TANK - targets.HEALER)
        end

        effectiveRoleFilters = {
            TANK = addonTable.RoleFilters.TANK and (partyRoles.TANK or 0) < (targets.TANK or 0),
            HEALER = addonTable.RoleFilters.HEALER and (partyRoles.HEALER or 0) < (targets.HEALER or 0),
            DAMAGER = addonTable.RoleFilters.DAMAGER and (partyRoles.DAMAGER or 0) < (targets.DAMAGER or 0),
        }
    end

    if not group.members then return false end
    for _, member in ipairs(group.members) do
        if member.role and effectiveRoleFilters[member.role] then
            return true
        end
    end
    return false
end

function addonTable.GroupPassesFilters(group)
    local isValidClass = true
    if group.leadClass and group.leadClass ~= "UNKNOWN" and addonTable.ClassFilters[group.leadClass] == false then
        isValidClass = false
    end

    if not isValidClass or not GroupMatchesRoleFilters(group) then
        return false
    end

    if addonTable.ResultMatchesPlayerRegion then
        local regionResult = group
        if type(regionResult) ~= "table" then
            return false
        end

        if not regionResult.regionInfo then
            local leadMember = type(group.members) == "table" and group.members[1] or nil
            if leadMember and addonTable.GetRegionInfoFromLeaderName then
                regionResult = {
                    leaderName = leadMember.name,
                    regionInfo = addonTable.GetRegionInfoFromLeaderName(leadMember.name),
                }
            end
        end

        if not addonTable.ResultMatchesPlayerRegion(regionResult) then
            return false
        end
    end

    return true
end

local function GetPlayerRoleFromUnit(unit)
    local assignedRole = UnitGroupRolesAssigned(unit)
    if assignedRole and assignedRole ~= "NONE" then
        return assignedRole
    end

    local specIndex = (unit == "player" and GetSpecialization) and GetSpecialization()
    if unit == "player" and specIndex then
        local specID = GetSpecializationInfo(specIndex)
        local role = specID and GetSpecializationRoleByID(specID)
        if role then
            return role
        end
    end

    return "DAMAGER"
end

GetPartyRoleSupply = function()
    local counts = { TANK = 0, HEALER = 0, DAMAGER = 0 }
    local total = 1
    local playerRole = GetPlayerRoleFromUnit("player")

    counts[playerRole] = counts[playerRole] + 1

    if IsInGroup() then
        total = GetNumGroupMembers()
        for i = 1, total do
            local unit = IsInRaid() and ("raid" .. i) or ("party" .. i)
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                local role = GetPlayerRoleFromUnit(unit)
                counts[role] = (counts[role] or 0) + 1
            end
        end
    end

    return counts, total
end

function addonTable.GetPartyUtilityCoverage()
    local hasLust = false
    local hasBrez = false
    local seenUnits = {}

    local function scanUnit(unit)
        if not unit or seenUnits[unit] or not UnitExists(unit) then
            return
        end
        seenUnits[unit] = true

        local _, classToken = UnitClass(unit)
        if addonTable.ClassProvidesLust and addonTable.ClassProvidesLust(classToken) then
            hasLust = true
        end
        if addonTable.ClassProvidesBrez and addonTable.ClassProvidesBrez(classToken) then
            hasBrez = true
        end
    end

    scanUnit("player")

    if IsInGroup() then
        local total = GetNumGroupMembers()
        for i = 1, total do
            local unit = IsInRaid() and ("raid" .. i) or ("party" .. i)
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                scanUnit(unit)
            end
        end
    end

    return hasLust, hasBrez
end

local function ResultMatchesSelectedActivities(result, filters, runtime)
    if not BrowserModeUsesActivityFilter(result.mode or GetBrowserMode()) then
        return true
    end

    if type(filters.selectedActivities) ~= "table" then
        return true
    end

    local hasAnySelection = runtime and runtime.hasAnySelectedActivities
    if hasAnySelection == nil then
        hasAnySelection = false
        for _, isSelected in pairs(filters.selectedActivities) do
            if isSelected then
                hasAnySelection = true
                break
            end
        end
    end

    if not hasAnySelection then
        return true
    end

    -- For raid/world-boss results the filterKey is the activity label with the difficulty
    -- prefix stripped (e.g. "Heroic The Voidspire" → "the voidspire").
    local normalizeLabel = addonTable.NormalizeSearchScoreTargetLabel
    local function IsSelectedActivityKey(filterKey)
        if type(filterKey) ~= "string" or filterKey == "" then
            return false
        end
        if filters.selectedActivities[filterKey] == true then
            return true
        end
        local normalizedKey = normalizeLabel and normalizeLabel(filterKey) or nil
        if normalizedKey and normalizedKey ~= filterKey and filters.selectedActivities[normalizedKey] == true then
            return true
        end
        return false
    end

    local isRaidResult = (result.mode == "raid" or result.mode == "legacy_raid" or result.mode == "open_world")
    if isRaidResult and result.raidListing then
        local rawLabel = result.activityFilterLabel or result.activityName or ""
        local diff = result.raidListing.difficultyLabel or ""
        local label = rawLabel
        if diff ~= "" and rawLabel ~= "" then
            local escaped = diff:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
            local stripped = rawLabel:match("^" .. escaped .. "%s+(.+)$")
            if stripped and stripped ~= "" then label = stripped end
        else
            for _, prefix in ipairs({"Mythic ", "Heroic ", "Normal ", "LFR "}) do
                if rawLabel:sub(1, #prefix) == prefix then label = rawLabel:sub(#prefix + 1); break end
            end
        end
        local filterKey = strlower(label)
        return filterKey ~= "" and IsSelectedActivityKey(filterKey)
    end
    return IsSelectedActivityKey(result.activityFilterKey)
end

local function ResultMatchesDifficulty(result, difficulty)
    if not BrowserModeUsesDifficulty(result.mode or GetBrowserMode()) then
        return true
    end

    if difficulty == "ANY" then
        return true
    end

    if difficulty == "MYTHIC_PLUS" then
        return result.isMythicPlus == true or result.difficultyToken == "MYTHIC_PLUS"
    elseif difficulty == "MYTHIC" then
        return result.difficultyID == 23 or result.difficultyID == 16 or result.difficultyToken == "MYTHIC"
    elseif difficulty == "HEROIC" then
        return result.difficultyID == 2 or result.difficultyID == 15 or result.difficultyToken == "HEROIC"
    elseif difficulty == "NORMAL" then
        return result.difficultyID == 1 or result.difficultyID == 14 or result.difficultyToken == "NORMAL"
    end

    return true
end

local function ResultMatchesKeyRange(result, filters)
    if not BrowserModeUsesKeyRange(result.mode or GetBrowserMode()) then
        return true
    end

    local minKey = tonumber(filters.keyMin)
    local maxKey = tonumber(filters.keyMax)
    local keyLevel = tonumber(result.keyLevel) or 0

    if minKey and keyLevel < minKey then
        return false
    end
    if maxKey and keyLevel > maxKey then
        return false
    end

    return true
end

local function GetSavedRaidDifficultyToken(difficultyID, difficultyName)
    local lowered = strlower(tostring(difficultyName or ""))
    if difficultyID == 16 or lowered:find("mythic", 1, true) then
        return "MYTHIC"
    elseif difficultyID == 15 or lowered:find("heroic", 1, true) then
        return "HEROIC"
    elseif difficultyID == 14 or lowered:find("normal", 1, true) then
        return "NORMAL"
    end

    return nil
end

local function NormalizeInstanceKey(name)
    local text = strlower(tostring(name or ""))
    text = text:gsub("%s*%b()", "")
    text = text:gsub("[^%w%s]", "")
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text
end

local function BuildSavedRaidLockoutMap()
    local lockouts = {}
    local total = GetNumSavedInstances and GetNumSavedInstances() or 0

    for index = 1, total do
        local instanceName, _, _, difficultyID, locked, extended, _, isRaid, _, difficultyName, numEncounters, encounterProgress = GetSavedInstanceInfo(index)
        if isRaid and (locked or extended) then
            local difficultyToken = GetSavedRaidDifficultyToken(difficultyID, difficultyName)
            local instanceKey = NormalizeInstanceKey(instanceName)
            if difficultyToken and instanceKey ~= "" then
                local defeatedBossNames = {}
                for bossIndex = 1, tonumber(numEncounters) or 0 do
                    local bossName, _, isKilled = GetSavedInstanceEncounterInfo(index, bossIndex)
                    if isKilled and bossName then
                        defeatedBossNames[bossName] = true
                    end
                end

                lockouts[instanceKey] = lockouts[instanceKey] or {}
                lockouts[instanceKey][difficultyToken] = {
                    bossesKilled = tonumber(encounterProgress) or 0,
                    bossCount = tonumber(numEncounters) or 0,
                    defeatedBossNames = defeatedBossNames,
                }
            end
        end
    end

    return lockouts
end

-- Parses expressions like "1-2", "<3", ">1", ">=2", "<=5", "4" against a numeric value.
local function ParseNumericRangeFilter(filterStr, value)
    if not filterStr or filterStr == "" then return true end
    filterStr = filterStr:match("^%s*(.-)%s*$")
    if filterStr == "" then return true end
    local v = tonumber(value) or 0
    local lo, hi = filterStr:match("^(%d+)%-(%d+)$")
    if lo then return v >= tonumber(lo) and v <= tonumber(hi) end
    local lte = filterStr:match("^<=(%d+)$")
    if lte then return v <= tonumber(lte) end
    local lt  = filterStr:match("^<(%d+)$")
    if lt  then return v < tonumber(lt) end
    local gte = filterStr:match("^>=(%d+)$")
    if gte then return v >= tonumber(gte) end
    local gt  = filterStr:match("^>(%d+)$")
    if gt  then return v > tonumber(gt) end
    local exact = tonumber(filterStr)
    if exact then return v == exact end
    return true
end

local function ResultMatchesRaidBossCount(result, filters)
    local listingMode = result.mode or GetBrowserMode()
    if listingMode ~= "raid" and listingMode ~= "legacy_raid" then return true end
    local bossesKilled = tonumber(result.raidListing and result.raidListing.bossesKilled) or 0
    return ParseNumericRangeFilter(filters.raidBossKills or "", bossesKilled)
end

local function ResultMatchesRaidRoleCounts(result, filters)
    local listingMode = result.mode or GetBrowserMode()
    if listingMode ~= "raid" and listingMode ~= "legacy_raid" then return true end
    local rc = result.roleCounts or {}
    if not ParseNumericRangeFilter(filters.raidTanks   or "", tonumber(rc.TANK)    or 0) then return false end
    if not ParseNumericRangeFilter(filters.raidHealers or "", tonumber(rc.HEALER)  or 0) then return false end
    if not ParseNumericRangeFilter(filters.raidDps     or "", tonumber(rc.DAMAGER) or 0) then return false end
    return true
end

local function ResultMatchesRaidLockout(result, filters)
    if not filters.matchMyRaidLockout then
        return true
    end

    local listingMode = result.mode or GetBrowserMode()
    if listingMode ~= "raid" and listingMode ~= "legacy_raid" then
        return true
    end

    local raidListing = result.raidListing
    if not raidListing then
        return false
    end

    -- raidListing.raidName = activityInfo.shortName which WoW sets to the difficulty tag.
    -- Strip difficulty prefix from activityFilterLabel to get the actual instance name.
    local rawLabel = result.activityFilterLabel or result.dungeonName or ""
    local diff = raidListing.difficultyLabel or ""
    local strippedLabel = rawLabel
    if diff ~= "" and rawLabel ~= "" then
        local escaped = diff:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
        local s = rawLabel:match("^" .. escaped .. "%s+(.+)$")
        if s and s ~= "" then strippedLabel = s end
    end
    local instanceKey = NormalizeInstanceKey(strippedLabel)
    local difficultyToken = raidListing.difficultyToken
    if instanceKey == "" or not difficultyToken then
        return false
    end

    local lockouts = BuildSavedRaidLockoutMap()
    local myLockout = lockouts[instanceKey] and lockouts[instanceKey][difficultyToken]
    if not myLockout then
        return (tonumber(raidListing.bossesKilled) or 0) == 0
    end

    local listingBosses = raidListing.defeatedBossNames or {}
    local myBosses = myLockout.defeatedBossNames or {}
    local hasNamedBosses = next(listingBosses) ~= nil and next(myBosses) ~= nil
    if hasNamedBosses then
        for bossName, _ in pairs(listingBosses) do
            if not myBosses[bossName] then
                return false
            end
        end
        for bossName, _ in pairs(myBosses) do
            if not listingBosses[bossName] then
                return false
            end
        end
        return true
    end

    local bossesKilled = tonumber(raidListing.bossesKilled) or 0
    return bossesKilled == (tonumber(myLockout.bossesKilled) or 0)
end

addonTable.ResultMatchesRaidLockout = ResultMatchesRaidLockout

local function ResultMatchesRoleNeeds(result, filters)
    if filters.hasTank and (result.roleCounts.TANK or 0) == 0 then
        return false
    end
    if filters.hasHealer and (result.roleCounts.HEALER or 0) == 0 then
        return false
    end

    local maxPlayers = tonumber(result.maxPlayers)
    if not maxPlayers or maxPlayers <= 0 then
        maxPlayers = result.activityInfo and tonumber(result.activityInfo.maxNumPlayers or result.activityInfo.maxPlayers) or 0
    end
    if maxPlayers <= 0 then
        return true
    end

    if maxPlayers == 5 then
        if filters.needsTank and (result.roleCounts.TANK or 0) >= 1 then
            return false
        end
        if filters.needsHealer and (result.roleCounts.HEALER or 0) >= 1 then
            return false
        end
        if filters.needsDPS and (result.roleCounts.DAMAGER or 0) >= 3 then
            return false
        end
    else
        if filters.needsTank and (result.roleCounts.TANK or 0) > 0 then
            return false
        end
        if filters.needsHealer and (result.roleCounts.HEALER or 0) > 0 and result.numMembers >= maxPlayers then
            return false
        end
        if filters.needsDPS and result.numMembers >= maxPlayers then
            return false
        end
    end

    return true
end

local function GetResultRemainingRoleCount(result, role)
    local memberCounts = result.memberCounts
    if type(memberCounts) == "table" then
        local remainingKey = ROLE_REMAINING_KEYS[role]
        local remaining = remainingKey and tonumber(memberCounts[remainingKey])
        if remaining ~= nil then
            return remaining
        end
    end

    return nil
end

local function ResultMatchesPartyFit(result, runtime)
    local partyRoles = runtime and runtime.partyRoles
    local partySize = runtime and runtime.partySize
    if not partyRoles or not partySize then
        partyRoles, partySize = GetPartyRoleSupply()
    end
    local maxPlayers = tonumber(result.maxPlayers)
    if not maxPlayers or maxPlayers <= 0 then
        maxPlayers = result.activityInfo and tonumber(result.activityInfo.maxNumPlayers or result.activityInfo.maxPlayers) or 0
    end
    if maxPlayers > 0 and result.numMembers + partySize > maxPlayers then
        return false
    end

    local hasRemainingData = false
    for role, amount in pairs(partyRoles) do
        if amount > 0 then
            local remaining = GetResultRemainingRoleCount(result, role)
            if remaining ~= nil then
                hasRemainingData = true
                if remaining < amount then
                    return false
                end
            end
        end
    end

    if hasRemainingData then
        return true
    end

    if maxPlayers == 5 then
        local targets = { TANK = 1, HEALER = 1, DAMAGER = 3 }
        for role, amount in pairs(partyRoles) do
            local openSpots = math.max(0, (targets[role] or 0) - (result.roleCounts[role] or 0))
            if amount > openSpots then
                return false
            end
        end
    end

    return true
end

local function ResultMatchesMinimumRating(result)
    local minRating = nil
    if addonTable._browserRuntimeFilters then
        minRating = addonTable._browserRuntimeFilters.minRating
    end
    if minRating == nil then
        minRating = browserMinRatingBox and tonumber(browserMinRatingBox:GetText() or "")
        if not minRating or minRating <= 0 then
            local ok, adv = pcall(C_LFGList.GetAdvancedFilter)
            if ok and type(adv) == "table" then
                minRating = tonumber(adv.minimumRating)
            end
        end
    end

    if not minRating or minRating <= 0 then
        return true
    end

    local mode = result.mode or "generic"
    local ratingValue
    if mode == "rated_pvp" or mode == "pvp" then
        ratingValue = tonumber(result.pvpRating) or tonumber(result.rating) or 0
    else
        ratingValue = tonumber(result.rating) or 0
    end

    return ratingValue >= minRating
end

function addonTable.ResultPassesBrowserFilters(result)
    -- Hide groups that are completely full (no open slots)
    local maxP = result.maxPlayers or 0
    if maxP > 0 and (result.numMembers or 0) >= maxP then
        return false
    end

    local runtime = addonTable._browserRuntimeFilters
    local filters = (runtime and runtime.filters) or BrowserFilterState()
    if filters.hideDeclined and string.find(result.applicationStatus or "", "declined", 1, true) then
        return false
    end
    if addonTable.ResultMatchesPlayerRegion and not addonTable.ResultMatchesPlayerRegion(result) then
        return false
    end

    if not ResultMatchesSelectedActivities(result, filters, runtime) then
        return false
    end
    if filters.bountifulOnly and result.mode == "delve" then
        local lookup = addonTable.GetCurrentBountifulDelveLookup and addonTable.GetCurrentBountifulDelveLookup() or nil
        if type(lookup) == "table" and next(lookup) ~= nil then
            local delveLabel = result.activityFilterLabel or result.dungeonName or result.activityName
            if not (addonTable.IsCurrentBountifulDelve and addonTable.IsCurrentBountifulDelve(delveLabel)) then
                return false
            end
        end
    end
    if not ResultMatchesDifficulty(result, filters.difficulty) then
        return false
    end
    if not ResultMatchesKeyRange(result, filters) then
        return false
    end
    if not ResultMatchesRoleNeeds(result, filters) then
        return false
    end
    if not ResultMatchesMinimumRating(result) then
        return false
    end
    local filterPlaystyle = filters.playstyle
    if filterPlaystyle and filterPlaystyle ~= "ANY" then
        -- generalPlaystyle is async (like PVP rating) — re-fetch fresh rather than using cached value.
        -- Values: 1=Learning, 2=Relaxed, 3=Competitive, 4=Carry
        local freshInfo = C_LFGList.GetSearchResultInfo and C_LFGList.GetSearchResultInfo(result.id)
        local rawPS = freshInfo and tonumber(freshInfo.generalPlaystyle) or 0
        local playstyleMatch = false
        if filterPlaystyle == "COMPETITIVE" and rawPS == 3 then playstyleMatch = true
        elseif filterPlaystyle == "RELAXED"  and rawPS == 2 then playstyleMatch = true
        elseif filterPlaystyle == "LEARNING" and rawPS == 1 then playstyleMatch = true
        elseif filterPlaystyle == "CARRY"    and rawPS == 4 then playstyleMatch = true
        end
        if not playstyleMatch then return false end
    end
    if filters.partyFit and not ResultMatchesPartyFit(result, runtime) then
        return false
    end
    if filters.needsLust and not addonTable.ResultCanStillSolveMissingUtility(result, runtime, "LUST") then
        return false
    end
    if filters.needsBrez and not addonTable.ResultCanStillSolveMissingUtility(result, runtime, "BREZ") then
        return false
    end
    if filters.hasLust and not addonTable.ResultWillHaveUtilityAfterParty(result, runtime, "LUST") then
        return false
    end
    if filters.hasBrez and not addonTable.ResultWillHaveUtilityAfterParty(result, runtime, "BREZ") then
        return false
    end
    if not ResultMatchesRaidBossCount(result, filters) then return false end
    if not ResultMatchesRaidRoleCounts(result, filters) then return false end
    if not ResultMatchesRaidLockout(result, filters) then return false end

    return true
end

function addonTable.ResultHasOpenUtilityPathAfterParty(result, runtime, utilityType)
    local partyRoles = runtime and runtime.partyRoles
    local partySize = runtime and runtime.partySize
    if not partyRoles or not partySize then
        partyRoles, partySize = GetPartyRoleSupply()
    end

    local maxPlayers = tonumber(result.maxPlayers)
    if not maxPlayers or maxPlayers <= 0 then
        maxPlayers = result.activityInfo and tonumber(result.activityInfo.maxNumPlayers or result.activityInfo.maxPlayers) or 0
    end

    local memberTotal = tonumber(result.numMembers) or 0
    if maxPlayers > 0 and memberTotal + partySize >= maxPlayers then
        return false
    end

    local utilityRoles = addonTable.UtilityRoleOptions and addonTable.UtilityRoleOptions[utilityType]
    if not utilityRoles then
        return false
    end

    if type(result.memberCounts) == "table" then
        local hadRemainingData = false
        for role in pairs(utilityRoles) do
            local remaining = GetResultRemainingRoleCount(result, role)
            if remaining ~= nil then
                hadRemainingData = true
                if (remaining - (partyRoles[role] or 0)) > 0 then
                    return true
                end
            end
        end

        if hadRemainingData then
            return false
        end
    end

    if maxPlayers == 5 then
        local targets = { TANK = 1, HEALER = 1, DAMAGER = 3 }
        local roleCounts = result.roleCounts or {}
        for role in pairs(utilityRoles) do
            local openAfterParty = math.max(0, (targets[role] or 0) - (roleCounts[role] or 0) - (partyRoles[role] or 0))
            if openAfterParty > 0 then
                return true
            end
        end
        return false
    end

    return maxPlayers <= 0 or (memberTotal + partySize) < maxPlayers
end

function addonTable.ResultWillHaveUtilityAfterParty(result, runtime, utilityType)
    if type(result) ~= "table" then
        return false
    end

    if addonTable.DoesResultFitCurrentParty and not addonTable.DoesResultFitCurrentParty(result) then
        return false
    end

    if utilityType == "LUST" and result.hasLust then
        return true
    end
    if utilityType == "BREZ" and result.hasBrez then
        return true
    end

    local partyHasLust = runtime and runtime.partyHasLust
    local partyHasBrez = runtime and runtime.partyHasBrez
    if partyHasLust == nil or partyHasBrez == nil then
        partyHasLust, partyHasBrez = addonTable.GetPartyUtilityCoverage()
    end

    if utilityType == "LUST" then
        return partyHasLust == true
    end

    return partyHasBrez == true
end

function addonTable.ResultCanStillSolveMissingUtility(result, runtime, utilityType)
    if type(result) ~= "table" then
        return false
    end

    if utilityType == "LUST" and result.hasLust then
        return false
    end
    if utilityType == "BREZ" and result.hasBrez then
        return false
    end

    if addonTable.DoesResultFitCurrentParty and not addonTable.DoesResultFitCurrentParty(result) then
        return false
    end

    local partyHasLust = runtime and runtime.partyHasLust
    local partyHasBrez = runtime and runtime.partyHasBrez
    if partyHasLust == nil or partyHasBrez == nil then
        partyHasLust, partyHasBrez = addonTable.GetPartyUtilityCoverage()
    end

    if utilityType == "LUST" and partyHasLust then
        return true
    end
    if utilityType == "BREZ" and partyHasBrez then
        return true
    end

    return addonTable.ResultHasOpenUtilityPathAfterParty(result, runtime, utilityType)
end

local SyncBrowserSelectedActivitiesFromNative

function addonTable.BuildBrowserRuntimeFilters()
    local filters = BrowserFilterState()
    local runtime = {
        filters = filters,
        hasAnySelectedActivities = false,
        minRating = nil,
        partyRoles = nil,
        partySize = nil,
        partyHasLust = nil,
        partyHasBrez = nil,
    }

    if type(filters.selectedActivities) == "table" then
        for _, isSelected in pairs(filters.selectedActivities) do
            if isSelected then
                runtime.hasAnySelectedActivities = true
                break
            end
        end
    end

    runtime.minRating = browserMinRatingBox and tonumber(browserMinRatingBox:GetText() or "")
    if not runtime.minRating or runtime.minRating <= 0 then
        local ok, adv = pcall(C_LFGList.GetAdvancedFilter)
        if ok and type(adv) == "table" then
            runtime.minRating = tonumber(adv.minimumRating)
        end
    end

    if filters.partyFit then
        runtime.partyRoles, runtime.partySize = GetPartyRoleSupply()
    end

    if filters.partyFit or filters.needsLust or filters.needsBrez or filters.hasLust or filters.hasBrez then
        if not runtime.partyRoles or not runtime.partySize then
            runtime.partyRoles, runtime.partySize = GetPartyRoleSupply()
        end
        runtime.partyHasLust, runtime.partyHasBrez = addonTable.GetPartyUtilityCoverage()
    end

    return runtime
end

local function MatchesExactClassFilter(filterMap)
    for _, class in ipairs(addonTable.ValidClasses) do
        local expected = filterMap[class] or false
        if addonTable.ClassFilters[class] ~= expected then
            return false
        end
    end
    return true
end

local function AreAllClassesEnabled()
    for _, class in ipairs(addonTable.ValidClasses) do
        if not addonTable.ClassFilters[class] then
            return false
        end
    end
    return true
end

local function AreNoClassesEnabled()
    for _, class in ipairs(addonTable.ValidClasses) do
        if addonTable.ClassFilters[class] then
            return false
        end
    end
    return true
end

local classData = {
    lust = {MAGE=true, SHAMAN=true, HUNTER=true, EVOKER=true},
    brez = {DEATHKNIGHT=true, DRUID=true, WARLOCK=true, PALADIN=true},
    plate = {WARRIOR=true, PALADIN=true, DEATHKNIGHT=true},
    mail = {HUNTER=true, SHAMAN=true, EVOKER=true},
    leather = {ROGUE=true, DRUID=true, MONK=true, DEMONHUNTER=true},
    cloth = {MAGE=true, PRIEST=true, WARLOCK=true}
}

local function UpdateQuickFilterButtons()
    SetQuickFilterButtonState(quickFilterButtons.all, AreAllClassesEnabled())
    SetQuickFilterButtonState(quickFilterButtons.none, AreNoClassesEnabled())
    SetQuickFilterButtonState(quickFilterButtons.lust, MatchesExactClassFilter(classData.lust))
    SetQuickFilterButtonState(quickFilterButtons.brez, MatchesExactClassFilter(classData.brez))
    SetQuickFilterButtonState(quickFilterButtons.plate, MatchesExactClassFilter(classData.plate))
    SetQuickFilterButtonState(quickFilterButtons.mail, MatchesExactClassFilter(classData.mail))
    SetQuickFilterButtonState(quickFilterButtons.leather, MatchesExactClassFilter(classData.leather))
    SetQuickFilterButtonState(quickFilterButtons.cloth, MatchesExactClassFilter(classData.cloth))
end

local function SyncClassFilterBoxes()
    for class, box in pairs(classToggleBoxes) do
        box:SetState(addonTable.ClassFilters[class])
    end
end

local function RefreshFilters()
    UpdateQuickFilterButtons()
    if addonTable.UpdateDisplay then addonTable.UpdateDisplay() end
end

local function RefreshBrowserFilters()
    if addonTable.UpdateDisplay then
        addonTable.UpdateDisplay()
    end
end

local function SyncBrowserNativeRoleFilters()
    if not (C_LFGList and C_LFGList.GetAdvancedFilter and C_LFGList.SaveAdvancedFilter) then
        return
    end

    local filters = BrowserFilterState()
    local success, advancedFilter = pcall(C_LFGList.GetAdvancedFilter)
    if not success or type(advancedFilter) ~= "table" then
        advancedFilter = {}
    end

    -- Role need filters (server-side)
    advancedFilter.needsTank   = filters.needsTank and true or nil
    advancedFilter.needsHealer = filters.needsHealer and true or nil
    advancedFilter.needsDamage = filters.needsDPS and true or nil
    -- Has-role filters (server-side)
    advancedFilter.hasTank   = filters.hasTank and true or nil
    advancedFilter.hasHealer = filters.hasHealer and true or nil
    -- "No [player class]" filter (server-side)
    advancedFilter.needsMyClass = filters.needsMyClass and true or nil
    -- Min rating (server-side)
    local minR = tonumber(filters.minRating)
    advancedFilter.minimumRating = (minR and minR > 0) and minR or nil

    pcall(C_LFGList.SaveAdvancedFilter, advancedFilter)
end

-- Also push selected activities to Blizzard's native filter
local function SyncBrowserNativeDifficulty()
    if not (C_LFGList and C_LFGList.SaveAdvancedFilter) then return end
    -- Use GetBrowserMode() which falls back to SearchResults[1].mode, ensuring we
    -- always get the real mode even when CurrentSearchContext is still "generic".
    local mode = GetBrowserMode()
    if mode ~= "mythic_plus" and mode ~= "dungeon" then return end

    local filters = BrowserFilterState()
    local diff = filters.difficulty or "ANY"

    local ok, adv = pcall(C_LFGList.GetAdvancedFilter)
    if not ok or type(adv) ~= "table" then adv = {} end

    -- Both dungeon and mythic_plus share the same difficulty options (ANY/NORMAL/HEROIC/MYTHIC/MYTHIC_PLUS).
    -- Always write exactly what the user selected — never override based on detected mode,
    -- because isMythicPlusActivity=true on current-season dungeons causes mode detection to
    -- return "mythic_plus" even during a plain Normal/Heroic/Mythic dungeon search.
    adv.difficultyNormal     = (diff == "NORMAL")      and true or nil
    adv.difficultyHeroic     = (diff == "HEROIC")      and true or nil
    adv.difficultyMythic     = (diff == "MYTHIC")      and true or nil
    adv.difficultyMythicPlus = (diff == "MYTHIC_PLUS") and true or nil

    pcall(C_LFGList.SaveAdvancedFilter, adv)
    -- Difficulty filter is server-side; the user must click Refresh to apply it.
    -- Do NOT call LFGListSearchPanel_DoSearch here — Search() is a protected
    -- function and can only be invoked from a hardware-event (user click) context.
end

local function SyncBrowserNativePlaystyle()
    if not (C_LFGList and C_LFGList.GetAdvancedFilter and C_LFGList.SaveAdvancedFilter) then return end
    local mode = GetBrowserMode()
    if mode ~= "mythic_plus" and mode ~= "dungeon" then return end

    local filters = BrowserFilterState()
    local ps = filters.playstyle or "ANY"

    local ok, adv = pcall(C_LFGList.GetAdvancedFilter)
    if not ok or type(adv) ~= "table" then adv = {} end

    if ps == "ANY" then
        adv.generalPlaystyle1 = nil
        adv.generalPlaystyle2 = nil
        adv.generalPlaystyle3 = nil
        adv.generalPlaystyle4 = nil
    else
        adv.generalPlaystyle1 = (ps == "LEARNING")     and true or false
        adv.generalPlaystyle2 = (ps == "RELAXED")      and true or false
        adv.generalPlaystyle3 = (ps == "COMPETITIVE")  and true or false
        adv.generalPlaystyle4 = (ps == "CARRY")        and true or false
    end

    pcall(C_LFGList.SaveAdvancedFilter, adv)
end

SyncBrowserSelectedActivitiesFromNative = function()
    local filters = BrowserFilterState()
    if type(filters.selectedActivities) ~= "table" then
        filters.selectedActivities = {}
    end
    if next(filters.selectedActivities) ~= nil then
        return
    end

    if not (C_LFGList and C_LFGList.GetAdvancedFilter) then
        return
    end

    local ok, adv = pcall(C_LFGList.GetAdvancedFilter)
    if not ok or type(adv) ~= "table" then
        return
    end

    local selectedIDs = {}
    if type(adv.activities) == "table" then
        for _, id in ipairs(adv.activities) do
            local numericID = tonumber(id)
            if numericID and numericID > 0 then
                selectedIDs[numericID] = true
            end
        end
    end

    if next(selectedIDs) == nil then
        return
    end

    local activities = addonTable.GetAvailableBrowserActivities and addonTable.GetAvailableBrowserActivities() or {}
    local resolved = {}
    local matchedAny = false
    for _, entry in ipairs(activities) do
        local groupID = addonTable.ResolveActivityGroupID and addonTable.ResolveActivityGroupID(entry.activityInfo) or nil
        local activityID = tonumber(entry.activityID)
        if (groupID and selectedIDs[groupID]) or (activityID and selectedIDs[activityID]) then
            resolved[entry.filterKey] = true
            matchedAny = true
        end
    end

    if not matchedAny then
        return
    end

    for key in pairs(filters.selectedActivities) do
        filters.selectedActivities[key] = nil
    end
    for key in pairs(resolved) do
        filters.selectedActivities[key] = true
    end
end

local function SyncBrowserNativeActivities()
    if not (C_LFGList and C_LFGList.SaveAdvancedFilter) then return end
    local filters = BrowserFilterState()
    local success, advancedFilter = pcall(C_LFGList.GetAdvancedFilter)
    if not success or type(advancedFilter) ~= "table" then advancedFilter = {} end

    local groupIDs = {}
    local activities = addonTable.GetAvailableBrowserActivities and addonTable.GetAvailableBrowserActivities() or {}
    for _, entry in ipairs(activities) do
        if filters.selectedActivities[entry.filterKey] then
            local gid = addonTable.ResolveActivityGroupID and addonTable.ResolveActivityGroupID(entry.activityInfo) or nil
            if gid and gid > 0 then
                table.insert(groupIDs, gid)
            else
                local activityID = tonumber(entry.activityID)
                if activityID and activityID > 0 then
                    table.insert(groupIDs, activityID)
                end
            end
        end
    end
    advancedFilter.activities = groupIDs
    pcall(C_LFGList.SaveAdvancedFilter, advancedFilter)
end

local function SetAllClassFilters(isEnabled)
    for class, _ in pairs(addonTable.ClassFilters) do
        addonTable.ClassFilters[class] = isEnabled
    end
    SyncClassFilterBoxes()
    RefreshFilters()
end

local function CreateOakToggleBox(parent, sortKey, globalFiltersTable)
    local box = CreateFrame("Button", nil, parent, "BackdropTemplate")
    box:SetSize(16, 16) 
    box:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
    
    function box:SetState(isActive)
        if isActive then
            self:SetBackdropColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1) 
            self:SetBackdropBorderColor(0, 0, 0, 1) 
        else
            self:SetBackdropColor(0.08, 0.08, 0.10, 0.95) 
            self:SetBackdropBorderColor(addonTable.ClassColor.r * 0.65, addonTable.ClassColor.g * 0.65, addonTable.ClassColor.b * 0.65, 1) 
        end
    end
    
    box:SetState(globalFiltersTable[sortKey])

    box:SetScript("OnClick", function(self)
        globalFiltersTable[sortKey] = not globalFiltersTable[sortKey]
        self:SetState(globalFiltersTable[sortKey])
        RefreshFilters()
    end)

    return box
end

local function ApplySharedRegionToggleVisual(box, label, isActive)
    if not box then
        return
    end

    if isActive then
        box:SetBackdropColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
        box:SetBackdropBorderColor(0, 0, 0, 1)
        if label then label:SetTextColor(1, 1, 1) end
    else
        box:SetBackdropColor(unpack(addonTable.OAK_COLOR_TOGGLE_OFF or addonTable.OAK_COLOR_PANE))
        box:SetBackdropBorderColor(addonTable.ClassColor.r * 0.65, addonTable.ClassColor.g * 0.65, addonTable.ClassColor.b * 0.65, 1)
        if label then label:SetTextColor(0.84, 0.84, 0.84) end
    end
end

local function SyncSharedRegionToggleBoxes()
    local isActive = OakLFGSorterDB and OakLFGSorterDB.showRegions == true
    ApplySharedRegionToggleVisual(applicantRegionToggleBox, applicantRegionToggleLabel, isActive)
    ApplySharedRegionToggleVisual(browserRegionToggleBox, browserRegionToggleLabel, isActive)
    if addonTable.RefreshOptionsPanel then
        addonTable.RefreshOptionsPanel()
    end
    if addonTable.SyncSearchRegionToggle then
        addonTable.SyncSearchRegionToggle()
    end
    if addonTable.RefreshSearchOptionsPanel then
        addonTable.RefreshSearchOptionsPanel()
    end
end

addonTable.SyncSharedRegionToggles = SyncSharedRegionToggleBoxes

local function ShowRegionToggleTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText("Regions", 1, 1, 1)
    GameTooltip:AddLine("Show visible region tags in Oak rows and region details in tooltips. Region is derived from the leader realm, similar to Premade Regions.", 1, 1, 1, true)
    GameTooltip:Show()
end

function addonTable.ShowRegionFlagsToggleTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText("Region Flags", 1, 1, 1)
    if addonTable.CanShowRegionFlags and addonTable.CanShowRegionFlags() then
        GameTooltip:AddLine("Show country-style flags instead of Oak's region tags. This uses realm lookup data provided by GroupfinderFlags when that addon is installed and enabled.", 1, 1, 1, true)
    else
        GameTooltip:AddLine("Requires the GroupfinderFlags addon to be installed and enabled. Oak will continue showing region tags without it.", 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function ShowLowLatencyToggleTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText("Region Filters", 1, 1, 1)
    GameTooltip:AddLine("Choose exactly which regions Oak should show in both the listing browser and the find browser.", 1, 1, 1, true)
    GameTooltip:Show()
end

local function ToggleSharedRegionSetting()
    OakLFGSorterDB.showRegions = not (OakLFGSorterDB and OakLFGSorterDB.showRegions == true)
    SyncSharedRegionToggleBoxes()
    if addonTable.OAK_SEARCH and addonTable.OAK_SEARCH.UpdateDisplay then
        addonTable.OAK_SEARCH:UpdateDisplay()
    end
    if addonTable.UpdateDisplay then
        addonTable.UpdateDisplay()
    end
end

local function SyncSharedLowLatencySetting()
    if addonTable.RefreshOptionsPanel then
        addonTable.RefreshOptionsPanel()
    end
    if addonTable.RefreshSearchOptionsPanel then
        addonTable.RefreshSearchOptionsPanel()
    end
    if addonTable.OAK_SEARCH and addonTable.OAK_SEARCH.UpdateDisplay then
        addonTable.OAK_SEARCH:UpdateDisplay()
    end
    if addonTable.UpdateDisplay then
        addonTable.UpdateDisplay()
    end
end

addonTable.SyncSharedLowLatencyToggles = SyncSharedLowLatencySetting

local function ToggleSharedRegionFilter(regionCode)
    if not (addonTable.SetRegionEnabled and addonTable.IsRegionEnabled) then
        return
    end

    addonTable.SetRegionEnabled(regionCode, not addonTable.IsRegionEnabled(regionCode))
    SyncSharedLowLatencySetting()
end

local toggleFiltersBtn = addonTable.CreateFlatButton(addonTable.TitleHeader, L["Filters"], 60)
toggleFiltersBtn:SetPoint("RIGHT", addonTable.CloseButton, "LEFT", -10, 0)
toggleFiltersBtn:SetAutoWidth(60, 130, 22)
toggleFiltersBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Filters", 1, 1, 1)
    GameTooltip:AddLine("Open Oak's filter panel for the current view.", 1, 1, 1, true)
    GameTooltip:Show()
end)
toggleFiltersBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)

local refreshBtn = addonTable.CreateFlatButton(addonTable.TitleHeader, L["Refresh"], 60)
refreshBtn:SetPoint("RIGHT", toggleFiltersBtn, "LEFT", -5, 0)
refreshBtn:SetAutoWidth(60, 130, 22)
refreshBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Refresh", 1, 1, 1)
    GameTooltip:AddLine("Refresh Oak's current browser results or applicant list.", 1, 1, 1, true)
    GameTooltip:Show()
end)
refreshBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)

local delistBtn = addonTable.CreateFlatButton(addonTable.TitleHeader, L["Delist"], 60)
delistBtn:SetPoint("RIGHT", refreshBtn, "LEFT", -5, 0)
delistBtn:SetAutoWidth(60, 130, 22)
delistBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Delist", 1, 1, 1)
    GameTooltip:AddLine("Remove your current group listing from Blizzard's finder.", 1, 1, 1, true)
    GameTooltip:Show()
end)
delistBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)

local editListingBtn = addonTable.CreateFlatButton(addonTable.TitleHeader, L["Edit"], 50)
editListingBtn:SetPoint("RIGHT", delistBtn, "LEFT", -5, 0)
editListingBtn:SetAutoWidth(50, 120, 22)
editListingBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Edit Listing", 1, 1, 1)
    GameTooltip:AddLine("Open Blizzard's edit listing screen for your active group.", 1, 1, 1, true)
    GameTooltip:Show()
end)
editListingBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)

local function ResetNativeBrowserAdvancedFilters()
    if not (C_LFGList and C_LFGList.SaveAdvancedFilter) then
        return
    end

    local ok, adv = pcall(C_LFGList.GetAdvancedFilter)
    if not ok or type(adv) ~= "table" then
        adv = {}
    end

    adv.needsTank = nil
    adv.needsHealer = nil
    adv.needsDamage = nil
    adv.needsMyClass = nil
    adv.hasTank = nil
    adv.hasHealer = nil
    adv.minimumRating = nil
    adv.maximumRating = nil
    adv.activities = {}
    adv.difficultyNormal = nil
    adv.difficultyHeroic = nil
    adv.difficultyMythic = nil
    adv.difficultyMythicPlus = nil
    adv.generalPlaystyle1 = nil
    adv.generalPlaystyle2 = nil
    adv.generalPlaystyle3 = nil
    adv.generalPlaystyle4 = nil

    pcall(C_LFGList.SaveAdvancedFilter, adv)
end

local function ResetOakBrowserCategoryFilters()
    local filters = BrowserFilterState()
    if not filters then
        return
    end

    filters.difficulty = "ANY"
    filters.playstyle = "ANY"
    filters.keyMin = ""
    filters.keyMax = ""
    filters.partyFit = false
    filters.needsLust = false
    filters.needsBrez = false
    filters.hideDeclined = false
    filters.selectedActivities = {}
    filters.raidBossesMin = "ANY"
    filters.matchMyRaidLockout = false
    filters.raidBossKills = ""
    filters.raidTanks = ""
    filters.raidHealers = ""
    filters.raidDps = ""

    if browserMinRatingBox then
        browserMinRatingBox:SetText("")
    end
    for _, key in ipairs({"raidBossKills", "raidTanks", "raidHealers", "raidDps"}) do
        if raidRangeRows and raidRangeRows[key] and raidRangeRows[key].box then
            raidRangeRows[key].box:SetText("")
        end
    end
end

function addonTable.ToggleSharedRegionFlagsSetting()
    if not (addonTable.CanShowRegionFlags and addonTable.CanShowRegionFlags()) then
        OakLFGSorterDB.showRegionFlags = false
    else
        OakLFGSorterDB.showRegionFlags = not (OakLFGSorterDB and OakLFGSorterDB.showRegionFlags == true)
    end

    if addonTable.RefreshOptionsPanel then
        addonTable.RefreshOptionsPanel()
    end
    if addonTable.RefreshSearchOptionsPanel then
        addonTable.RefreshSearchOptionsPanel()
    end
    if addonTable.OAK_SEARCH and addonTable.OAK_SEARCH.UpdateDisplay then
        addonTable.OAK_SEARCH:UpdateDisplay()
    end
    if addonTable.UpdateDisplay then
        addonTable.UpdateDisplay()
    end
end

categoryDropdownButton, categoryDropdownList = addonTable.CreateSimpleDropdown(
    addonTable.TitleHeader,
    120,
    function()
        return addonTable.GetBrowserCategoryLabel and addonTable.GetBrowserCategoryLabel() or "Dungeons"
    end,
    function()
        return addonTable.BrowserCategoryOptions or {}
    end,
    function(id, option)
        if option and not option.separator and addonTable.SetBrowserCategory then
            ResetOakBrowserCategoryFilters()
            ResetNativeBrowserAdvancedFilters()
            addonTable.SetBrowserCategory(id)
            if addonTable.GetCurrentViewMode and addonTable.GetCurrentViewMode() == "browser" then
                if addonTable.RefreshSearchOptionsPanel then
                    addonTable.RefreshSearchOptionsPanel()
                end
                if addonTable.UpdateBrowserFilterPanel then
                    addonTable.UpdateBrowserFilterPanel()
                end
                if addonTable.RunBrowserSearch and id ~= "RAIDS_LEGACY" then
                    addonTable.RunBrowserSearch()
                elseif id == "RAIDS_LEGACY" and addonTable.SearchResults then
                    wipe(addonTable.SearchResults)
                    if addonTable.UpdateDisplay then
                        addonTable.UpdateDisplay()
                    end
                end
                if id ~= "RAIDS_LEGACY" and addonTable.FetchSearchResultData then
                    C_Timer.After(0.2, function()
                        addonTable.FetchSearchResultData()
                        if addonTable.UpdateDisplay then addonTable.UpdateDisplay() end
                        if addonTable.UpdateBrowserFilterPanel then addonTable.UpdateBrowserFilterPanel() end
                    end)
                end
            end
            if categoryDropdownButton and categoryDropdownButton.RefreshSelection then
                categoryDropdownButton:RefreshSelection()
            end
        end
    end
)
if categoryDropdownButton and categoryDropdownButton.SetAutoWidth then
    categoryDropdownButton:SetAutoWidth(120, 180, 24)
end
categoryDropdownButton:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L["Search Category"], 1, 1, 1)
    GameTooltip:AddLine(L["Choose which Group Finder category Oak searches without opening Blizzard's premade-group panel."], 1, 1, 1, true)
    GameTooltip:Show()
end)
categoryDropdownButton:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)

function addonTable.UpdateTopBarActions()
    if addonTable.GetCurrentViewMode and addonTable.GetCurrentViewMode() == "browser" then
        delistBtn:Hide()
        editListingBtn:Hide()
        if categoryDropdownButton then
            categoryDropdownButton:Show()
        end

        refreshBtn:SetLabel(L["Refresh"])
        refreshBtn:SetScript("OnClick", function()
            local ok = false
            if addonTable.RunBrowserSearch then
                ok = select(1, addonTable.RunBrowserSearch()) == true
            end
            if not ok and addonTable.FetchSearchResultData then
                addonTable.FetchSearchResultData()
                if addonTable.UpdateDisplay then addonTable.UpdateDisplay() end
            end
        end)
    else
        delistBtn:Show()
        editListingBtn:Show()
        if categoryDropdownButton then
            categoryDropdownButton:Hide()
        end

        editListingBtn:SetLabel(L["Edit"])
        editListingBtn:SetScript("OnClick", function()
            if addonTable.OpenCurrentListingForEdit then
                addonTable.OpenCurrentListingForEdit()
            end
        end)

        delistBtn:SetLabel(L["Delist"])
        delistBtn:SetScript("OnClick", function()
            C_LFGList.RemoveListing()
        end)

        refreshBtn:SetLabel(L["Refresh"])
        refreshBtn:SetScript("OnClick", function()
            C_LFGList.RefreshApplicants()
        end)
    end
end

function addonTable.UpdateTopBarLayout()
    local hideNotes = OakLFGSorterDB and OakLFGSorterDB.hideNotes
    local title = addonTable.OAK_LFG and addonTable.OAK_LFG.title
    local scaleSlider = addonTable.ScaleSlider
    local scaleEdit = addonTable.ScaleEdit
    local scaleLabel = addonTable.ScaleLabel
    local scaleReset = addonTable.ScaleReset
    local closeBtn = addonTable.CloseButton

    if not (title and scaleSlider and scaleEdit and scaleLabel and scaleReset and closeBtn) then
        return
    end

    if addonTable.VersionText then
        addonTable.VersionText:Hide()
    end

    toggleFiltersBtn:ClearAllPoints()
    refreshBtn:ClearAllPoints()
    delistBtn:ClearAllPoints()
    editListingBtn:ClearAllPoints()
    if categoryDropdownButton then
        categoryDropdownButton:ClearAllPoints()
    end
    scaleSlider:ClearAllPoints()
    scaleEdit:ClearAllPoints()
    scaleReset:ClearAllPoints()

    if hideNotes then
        title:SetText(addonTable.CompactTitleText or ("OAK " .. L["LFG"]))
        scaleLabel:Hide()
        scaleEdit:Hide()
        scaleReset:Show()

        scaleSlider:SetWidth(60)
        scaleSlider:SetPoint("LEFT", title, "RIGHT", 12, 0)
        scaleReset:SetLabel("R")
        scaleReset:SetWidth(20)
        scaleReset:SetPoint("LEFT", scaleSlider, "RIGHT", 3, 0)

        toggleFiltersBtn:SetWidth(54)
        refreshBtn:SetWidth(58)
        delistBtn:SetWidth(54)
        editListingBtn:SetWidth(48)
        if categoryDropdownButton then
            categoryDropdownButton:SetWidth(92)
        end

        toggleFiltersBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
        refreshBtn:SetPoint("RIGHT", toggleFiltersBtn, "LEFT", -4, 0)
        if categoryDropdownButton then
            categoryDropdownButton:SetPoint("RIGHT", refreshBtn, "LEFT", -4, 0)
        end
        if addonTable.GetCurrentViewMode and addonTable.GetCurrentViewMode() ~= "browser" then
            delistBtn:SetPoint("RIGHT", refreshBtn, "LEFT", -4, 0)
            editListingBtn:SetPoint("RIGHT", delistBtn, "LEFT", -4, 0)
        elseif categoryDropdownButton then
            categoryDropdownButton:Show()
        end
    else
        title:SetText(addonTable.FullTitleText or ("OAK " .. L["LFG Sorter"]))
        scaleLabel:Show()
        scaleEdit:Show()
        scaleReset:Show()

        scaleSlider:SetWidth(80)
        scaleSlider:SetPoint("LEFT", title, "RIGHT", 45, 0)
        scaleEdit:SetPoint("LEFT", scaleSlider, "RIGHT", 10, 0)
        scaleReset:SetLabel(L["Reset"])
        scaleReset:SetPoint("LEFT", scaleEdit, "RIGHT", 5, 0)

        if toggleFiltersBtn.RefreshAutoWidth then toggleFiltersBtn:RefreshAutoWidth() else toggleFiltersBtn:SetWidth(60) end
        if refreshBtn.RefreshAutoWidth then refreshBtn:RefreshAutoWidth() else refreshBtn:SetWidth(60) end
        if delistBtn.RefreshAutoWidth then delistBtn:RefreshAutoWidth() else delistBtn:SetWidth(60) end
        if editListingBtn.RefreshAutoWidth then editListingBtn:RefreshAutoWidth() else editListingBtn:SetWidth(50) end
        if categoryDropdownButton then
            if categoryDropdownButton.RefreshAutoWidth then
                categoryDropdownButton:RefreshAutoWidth()
            else
                categoryDropdownButton:SetWidth(120)
            end
        end

        toggleFiltersBtn:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
        refreshBtn:SetPoint("RIGHT", toggleFiltersBtn, "LEFT", -5, 0)
        if categoryDropdownButton then
            categoryDropdownButton:SetPoint("RIGHT", refreshBtn, "LEFT", -5, 0)
        end
        if addonTable.GetCurrentViewMode and addonTable.GetCurrentViewMode() ~= "browser" then
            delistBtn:SetPoint("RIGHT", refreshBtn, "LEFT", -5, 0)
            editListingBtn:SetPoint("RIGHT", delistBtn, "LEFT", -5, 0)
        elseif categoryDropdownButton then
            categoryDropdownButton:Show()
        end
    end

    if categoryDropdownButton and categoryDropdownButton.RefreshSelection then
        categoryDropdownButton:RefreshSelection()
    end

    if addonTable.UpdateTopBarActions then
        addonTable.UpdateTopBarActions()
    end
end

local filterPanel = CreateFrame("Frame", nil, OAK_LFG, "BackdropTemplate")
addonTable.FilterPanel = filterPanel
filterPanel:SetSize(190, 444) 
filterPanel:SetPoint("TOPLEFT", OAK_LFG, "TOPRIGHT", -2, 0)
filterPanel:Hide()
filterPanel:SetFrameLevel(OAK_LFG:GetFrameLevel() - 1) 
filterPanel:SetBackdrop({
    bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, tile = false, edgeSize = 1, 
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
})
if addonTable.ApplyBackdropStyle then
    addonTable.ApplyBackdropStyle(filterPanel, "panel")
end

filterPanel:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
filterPanel:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
filterPanel:HookScript("OnShow", function()
    if addonTable.UpdateAuxPanelAnchors then
        addonTable.UpdateAuxPanelAnchors()
    end
    if addonTable.RefreshRIOAnchor then
        addonTable.RefreshRIOAnchor()
    elseif addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(addonTable.OAK_LFG)
    end
end)
filterPanel:HookScript("OnHide", function()
    if addonTable.RefreshRIOAnchor then
        addonTable.RefreshRIOAnchor()
    elseif addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(addonTable.OAK_LFG)
    end
end)

addonTable.FilterTitle = filterPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontLarge")
addonTable.FilterTitle:SetPoint("TOP", filterPanel, "TOP", 0, -10)
addonTable.FilterTitle:SetText(L["Filters"])
do
    local accent = addonTable.GetThemeAccentColor and addonTable.GetThemeAccentColor(addonTable.GetThemePreset and addonTable.GetThemePreset() or nil) or addonTable.ClassColor
    addonTable.FilterTitle:SetTextColor(accent.r, accent.g, accent.b)
end

local yOffset = -35
local rolesToFilter = { {"TANK", L["Tank"]}, {"HEALER", L["Healer"]}, {"DAMAGER", "DPS"} }

for _, rData in ipairs(rolesToFilter) do
    local rKey, rLabel = rData[1], rData[2]
    local box = CreateOakToggleBox(filterPanel, rKey, addonTable.RoleFilters)
    box:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, yOffset)
    local text = filterPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    text:SetPoint("LEFT", box, "RIGHT", 8, 0)
    text:SetText(rLabel)
    yOffset = yOffset - 22
end

addonTable.FilterQuickDivider = filterPanel:CreateTexture(nil, "ARTWORK")
do
    local accent = addonTable.GetThemeAccentColor and addonTable.GetThemeAccentColor(addonTable.GetThemePreset and addonTable.GetThemePreset() or nil) or addonTable.ClassColor
    addonTable.FilterQuickDivider:SetColorTexture(accent.r, accent.g, accent.b, 0.5)
end
addonTable.FilterQuickDivider:SetSize(160, 1)
addonTable.FilterQuickDivider:SetPoint("TOP", filterPanel, "TOP", 0, yOffset - 3)
yOffset = yOffset - 12

local function ApplyQuickFilter(filterMap)
    for class, _ in pairs(addonTable.ClassFilters) do 
        addonTable.ClassFilters[class] = filterMap[class] or false 
    end
    SyncClassFilterBoxes()
    RefreshFilters()
end

local btnWidth = 75
local btnAll = addonTable.CreateFlatButton(filterPanel, L["All"], btnWidth)
quickFilterButtons.all = btnAll
btnAll:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, yOffset)
btnAll:SetScript("OnClick", function()
    SetAllClassFilters(true)
end)

local btnNone = addonTable.CreateFlatButton(filterPanel, L["None"], btnWidth)
quickFilterButtons.none = btnNone
btnNone:SetPoint("LEFT", btnAll, "RIGHT", 10, 0)
btnNone:SetScript("OnClick", function()
    SetAllClassFilters(false)
end)
yOffset = yOffset - 25

local btnLust = addonTable.CreateFlatButton(filterPanel, "Lust", btnWidth)
quickFilterButtons.lust = btnLust
btnLust:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, yOffset)
btnLust:SetScript("OnClick", function() ApplyQuickFilter(classData.lust) end)

local btnBrez = addonTable.CreateFlatButton(filterPanel, "B-Rez", btnWidth)
quickFilterButtons.brez = btnBrez
btnBrez:SetPoint("LEFT", btnLust, "RIGHT", 10, 0)
btnBrez:SetScript("OnClick", function() ApplyQuickFilter(classData.brez) end)
yOffset = yOffset - 25

local btnPlate = addonTable.CreateFlatButton(filterPanel, "Plate", btnWidth)
quickFilterButtons.plate = btnPlate
btnPlate:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, yOffset)
btnPlate:SetScript("OnClick", function() ApplyQuickFilter(classData.plate) end)

local btnMail = addonTable.CreateFlatButton(filterPanel, "Mail", btnWidth)
quickFilterButtons.mail = btnMail
btnMail:SetPoint("LEFT", btnPlate, "RIGHT", 10, 0)
btnMail:SetScript("OnClick", function() ApplyQuickFilter(classData.mail) end)
yOffset = yOffset - 25

local btnLeather = addonTable.CreateFlatButton(filterPanel, "Leather", btnWidth)
quickFilterButtons.leather = btnLeather
btnLeather:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, yOffset)
btnLeather:SetScript("OnClick", function() ApplyQuickFilter(classData.leather) end)

local btnCloth = addonTable.CreateFlatButton(filterPanel, "Cloth", btnWidth)
quickFilterButtons.cloth = btnCloth
btnCloth:SetPoint("LEFT", btnLeather, "RIGHT", 10, 0)
btnCloth:SetScript("OnClick", function() ApplyQuickFilter(classData.cloth) end)
yOffset = yOffset - 20

addonTable.UpdateQuickFilterButtons = UpdateQuickFilterButtons
UpdateQuickFilterButtons()

addonTable.FilterClassDivider = filterPanel:CreateTexture(nil, "ARTWORK")
addonTable.FilterClassDivider:SetColorTexture(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 0.5)
addonTable.FilterClassDivider:SetSize(160, 1)
addonTable.FilterClassDivider:SetPoint("TOP", filterPanel, "TOP", 0, yOffset - 5)
yOffset = yOffset - 16

local classXOffset = 15
local classYOffset = yOffset

for i, class in ipairs(addonTable.ValidClasses) do
    local box = CreateOakToggleBox(filterPanel, class, addonTable.ClassFilters)
    box:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", classXOffset, classYOffset)
    classToggleBoxes[class] = box 
    
    local text = filterPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    text:SetPoint("LEFT", box, "RIGHT", 5, 0)
    local displayClass = class:sub(1,1) .. class:sub(2):lower()
    
    if displayClass == "Deathknight" then displayClass = "DK"
    elseif displayClass == "Demonhunter" then displayClass = "DH" end
    
    text:SetText(addonTable.ApplyClassColor(displayClass, class))
    
    if i % 2 == 0 then
        classXOffset = 15
        classYOffset = classYOffset - 20
    else
        classXOffset = 100
    end
end

addonTable.FilterBottomDivider = filterPanel:CreateTexture(nil, "ARTWORK")
addonTable.FilterBottomDivider:SetColorTexture(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 0.35)
addonTable.FilterBottomDivider:SetSize(160, 1)
addonTable.FilterBottomDivider:SetPoint("BOTTOM", filterPanel, "BOTTOM", 0, 82)

-- Decline Filtered Button
local btnDecline = addonTable.CreateFlatButton(filterPanel, "Decline Filtered", 160)
btnDecline:SetPoint("BOTTOM", filterPanel, "BOTTOM", 0, 54)
btnDecline:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(1, 0.2, 0.2, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Decline Hidden Applicants", 1, 0.2, 0.2)
    GameTooltip:AddLine("Permanently declines applicants currently hidden by your active filters.", 1, 1, 1, true)
    GameTooltip:AddLine("|cFFFFFF00Note:|r Due to Blizzard restrictions, you must click this button once for EVERY applicant you wish to decline. Keep clicking until the list is clear!", 1, 1, 1, true)
    GameTooltip:Show()
end)
btnDecline:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)

btnDecline:SetScript("OnClick", function()
    if not addonTable.ApplicantGroups then return end
    for _, group in ipairs(addonTable.ApplicantGroups) do
        if not addonTable.GroupPassesFilters(group) then
            C_LFGList.DeclineApplicant(group.id)
            return
        end
    end
end)

local autoHideRolesBox = CreateOakToggleBox(filterPanel, "autoHideFilledRoles", OakLFGSorterDB)
autoHideRolesBox:SetPoint("BOTTOMLEFT", filterPanel, "BOTTOMLEFT", 15, 30)

local autoHideRolesText = filterPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
autoHideRolesText:SetPoint("LEFT", autoHideRolesBox, "RIGHT", 8, 0)
autoHideRolesText:SetText("Auto-Hide Filled Roles")

autoHideRolesBox:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Auto-Hide Filled Roles", 1, 1, 1)
    GameTooltip:AddLine("When your current group has already filled a role target, applicants for that role will be filtered out automatically.", 1, 1, 1, true)
    GameTooltip:Show()
end)
autoHideRolesBox:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)
autoHideRolesBox:SetScript("OnClick", function(self)
    OakLFGSorterDB.autoHideFilledRoles = not OakLFGSorterDB.autoHideFilledRoles
    self:SetState(OakLFGSorterDB.autoHideFilledRoles)
    RefreshFilters()
end)

local mutePingBox = CreateOakToggleBox(filterPanel, "muteApplicantPing", OakLFGSorterDB)
mutePingBox:SetPoint("BOTTOMLEFT", filterPanel, "BOTTOMLEFT", 15, 10)

local mutePingText = filterPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
mutePingText:SetPoint("LEFT", mutePingBox, "RIGHT", 8, 0)
mutePingText:SetText("Mute Ping")

mutePingBox:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Mute Ping", 1, 1, 1)
    GameTooltip:AddLine("Suppress the Blizzard new-applicant alert sound while Oak LFG Sorter is open and the Blizzard Group Finder window is closed.", 1, 1, 1, true)
    GameTooltip:Show()
end)
mutePingBox:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)
mutePingBox:SetScript("OnClick", function(self)
    OakLFGSorterDB.muteApplicantPing = not OakLFGSorterDB.muteApplicantPing
    self:SetState(OakLFGSorterDB.muteApplicantPing)
    RefreshFilters()
end)

local browserFilterPanel = CreateFrame("Frame", nil, OAK_LFG, "BackdropTemplate")
addonTable.BrowserFilterPanel = browserFilterPanel
browserFilterPanel:SetSize(210, 520)
browserFilterPanel:SetPoint("TOPLEFT", OAK_LFG, "TOPRIGHT", 0, 0)
browserFilterPanel:Hide()
browserFilterPanel:SetFrameLevel(OAK_LFG:GetFrameLevel() - 1)
browserFilterPanel:SetBackdrop({
    bgFile = addonTable.FLAT_TEX,
    edgeFile = addonTable.FLAT_TEX,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
if addonTable.ApplyBackdropStyle then
    addonTable.ApplyBackdropStyle(browserFilterPanel, "panel")
end
browserFilterPanel:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
browserFilterPanel:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
browserFilterPanel:HookScript("OnShow", function()
    if addonTable.UpdateAuxPanelAnchors then
        addonTable.UpdateAuxPanelAnchors()
    end
    -- Populate/refresh the panel contents every time it becomes visible.
    -- This is the single authoritative place that calls UpdateBrowserFilterPanel on open
    -- so the panel is always fully laid out regardless of what triggered the Show.
    if addonTable.UpdateBrowserFilterPanel then
        addonTable.UpdateBrowserFilterPanel()
    end
    if addonTable.RefreshRIOAnchor then
        addonTable.RefreshRIOAnchor()
    elseif addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(addonTable.OAK_LFG)
    end
end)
browserFilterPanel:HookScript("OnHide", function()
    if addonTable.RefreshRIOAnchor then
        addonTable.RefreshRIOAnchor()
    elseif addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(addonTable.OAK_LFG)
    end
end)

addonTable.BrowserFilterTitle = browserFilterPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontLarge")
addonTable.BrowserFilterTitle:SetPoint("TOP", browserFilterPanel, "TOP", 0, -10)
addonTable.BrowserFilterTitle:SetText(L["Search Filters"])
do
    local accent = addonTable.GetThemeAccentColor and addonTable.GetThemeAccentColor(addonTable.GetThemePreset and addonTable.GetThemePreset() or nil) or addonTable.ClassColor
    addonTable.BrowserFilterTitle:SetTextColor(accent.r, accent.g, accent.b)
end

local browserContent = CreateFrame("Frame", nil, browserFilterPanel)
browserContent:SetPoint("TOPLEFT", browserFilterPanel, "TOPLEFT", 14, -32)
browserContent:SetPoint("TOPRIGHT", browserFilterPanel, "TOPRIGHT", -14, -32)
browserContent:SetHeight(396)

local activeBrowserDropdowns = {}

local function HideAllBrowserDropdowns(exceptFrame)
    for _, dropdown in ipairs(activeBrowserDropdowns) do
        if dropdown ~= exceptFrame and dropdown.listFrame then
            dropdown.listFrame:Hide()
        end
    end
end

-- Returns true if any browser dropdown list is currently visible.
-- Used to suppress panel rebuilds (which would close the open dropdown).
local function IsBrowserDropdownOpen()
    for _, dropdown in ipairs(activeBrowserDropdowns) do
        if dropdown.listFrame and dropdown.listFrame:IsShown() then
            return true
        end
    end
    return false
end
addonTable.IsBrowserDropdownOpen = IsBrowserDropdownOpen

function addonTable.MeasureBrowserTextWidth(text, fontObject)
    if not addonTable._browserFilterMeasureText then
        addonTable._browserFilterMeasureText = UIParent:CreateFontString(nil, "ARTWORK", "OakLFG_FontRegular")
        addonTable._browserFilterMeasureText:Hide()
    end

    addonTable._browserFilterMeasureText:SetFontObject(fontObject or _G["OakLFG_FontRegular"])
    addonTable._browserFilterMeasureText:SetText(text or "")
    return math.ceil(addonTable._browserFilterMeasureText:GetUnboundedStringWidth() or 0)
end

function BrowserFilterState()
    local characterFilters = addonTable.GetCharacterBrowserFilters and addonTable.GetCharacterBrowserFilters() or {}
    if characterFilters.version ~= BROWSER_FILTER_VERSION then
        characterFilters = {
            version = BROWSER_FILTER_VERSION,
            difficulty = "ANY",
            playstyle = "ANY",
            keyMin = "",
            keyMax = "",
            hasTank = false,
            needsTank = false,
            hasHealer = false,
            needsHealer = false,
            needsDPS = false,
            needsMyClass = false,
            minRating = "",
            partyFit = false,
            needsLust = false,
            needsBrez = false,
            hasLust = false,
            hasBrez = false,
            hideDeclined = false,
            raidBossesMin = "ANY",
            matchMyRaidLockout = false,
            bountifulOnly = false,
            selectedActivities = {},
        }
    end
    -- Ensure new fields exist for upgrades
    local f = characterFilters
    if f.needsMyClass == nil then f.needsMyClass = false end
    if f.minRating == nil then f.minRating = "" end
    if f.raidBossKills == nil then f.raidBossKills = "" end
    if f.raidTanks     == nil then f.raidTanks     = "" end
    if f.raidHealers   == nil then f.raidHealers   = "" end
    if f.raidDps       == nil then f.raidDps       = "" end
    if f.bountifulOnly == nil then f.bountifulOnly = false end
    if f.hasLust       == nil then f.hasLust       = false end
    if f.hasBrez       == nil then f.hasBrez       = false end
    local filters = characterFilters
    filters.version = BROWSER_FILTER_VERSION

    local validDifficulty = {
        ANY = true, NORMAL = true, HEROIC = true, MYTHIC = true, MYTHIC_PLUS = true,
    }
    if not validDifficulty[filters.difficulty] then
        filters.difficulty = "ANY"
    end

    local validPlaystyle = {
        ANY = true, COMPETITIVE = true, RELAXED = true, LEARNING = true, CARRY = true,
    }
    if not validPlaystyle[filters.playstyle] then
        filters.playstyle = "ANY"
    end

    if filters.raidBossesMin == nil then
        filters.raidBossesMin = "ANY"
    else
        filters.raidBossesMin = tostring(filters.raidBossesMin)
    end

    if type(filters.selectedActivities) ~= "table" then
        filters.selectedActivities = {}
    else
        local normalized = {}
        for key, value in pairs(filters.selectedActivities) do
            if type(key) == "string" and value then
                normalized[key] = true
            end
        end
        filters.selectedActivities = normalized
    end
    if addonTable.GetCharacterDB then
        addonTable.GetCharacterDB().browserFilters = filters
    end
    return filters
end

local function CreateBrowserToggleBox(parent, key)
    local box = CreateFrame("Button", nil, parent, "BackdropTemplate")
    box:SetSize(16, 16)
    box:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})

    function box:SetState(isActive)
        if isActive then
            self:SetBackdropColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
        else
            self:SetBackdropColor(0.08, 0.08, 0.10, 0.95)
        end
        if isActive then
            self:SetBackdropBorderColor(0, 0, 0, 1)
        else
            self:SetBackdropBorderColor(addonTable.ClassColor.r * 0.65, addonTable.ClassColor.g * 0.65, addonTable.ClassColor.b * 0.65, 1)
        end
    end

    box:SetScript("OnClick", function(self)
        local filters = BrowserFilterState()
        filters[key] = not filters[key]
        self:SetState(filters[key])
        -- Sync all role/class/rating-related keys to Blizzard native filter
        local nativeKeys = { needsTank=1, needsHealer=1, needsDPS=1, hasTank=1, hasHealer=1, needsMyClass=1 }
        if nativeKeys[key] then
            SyncBrowserNativeRoleFilters()
        end
        RefreshBrowserFilters()
    end)

    browserFilterButtons[key] = box
    box:SetState(BrowserFilterState()[key])
    return box
end

local function CreateBrowserDropdown(parent, width, getOptions, filterKey, anyLabel)
    local button = addonTable.CreateFlatButton(parent, "", width)
    button.dropdownWidth = width
    button.getOptions = getOptions
    button.filterKey = filterKey
    button.anyLabel = anyLabel
    table.insert(activeBrowserDropdowns, button)

    local listFrame = CreateFrame("Frame", nil, browserFilterPanel, "BackdropTemplate")
    listFrame:SetWidth(width)
    listFrame:SetBackdrop({
        bgFile = addonTable.FLAT_TEX,
        edgeFile = addonTable.FLAT_TEX,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    listFrame:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
    listFrame:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    listFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    listFrame:SetFrameLevel(browserFilterPanel:GetFrameLevel() + 20)
    listFrame:SetClampedToScreen(true)
    listFrame:Hide()
    button.listFrame = listFrame
    button.optionButtons = {}

    local function UpdateText()
        local filters = BrowserFilterState()
        local selectedValue = filters[filterKey]
        local selectedLabel = anyLabel
        for _, option in ipairs(getOptions()) do
            if option.value == selectedValue then
                selectedLabel = option.label
                break
            end
        end
        button.text:SetText(selectedLabel)
    end

    local function RefreshOptions()
        local currentWidth = button.dropdownWidth or width
        local options = button.getOptions()
        listFrame:SetHeight((#options * 22) + 2)
        listFrame:SetWidth(currentWidth)

        for _, optionButton in ipairs(button.optionButtons) do
            optionButton:Hide()
        end

        for index, option in ipairs(options) do
            local optionButton = button.optionButtons[index]
            if not optionButton then
                optionButton = CreateFrame("Button", nil, listFrame)
                optionButton.bg = optionButton:CreateTexture(nil, "BACKGROUND")
                optionButton.bg:SetAllPoints()
                optionButton.hover = optionButton:CreateTexture(nil, "HIGHLIGHT")
                optionButton.hover:SetAllPoints()
                optionButton.hover:SetColorTexture(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 0.3)
                optionButton.text = optionButton:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
                optionButton.text:SetPoint("LEFT", optionButton, "LEFT", 8, 0)
                optionButton.text:SetPoint("RIGHT", optionButton, "RIGHT", -8, 0)
                optionButton.text:SetJustifyH("LEFT")
                button.optionButtons[index] = optionButton
            end

            optionButton:ClearAllPoints()
            optionButton:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 1, -((index - 1) * 22) - 1)
            optionButton:SetSize(currentWidth - 2, 22)
            optionButton.bg:SetColorTexture(unpack(addonTable.OAK_COLOR_BG))
            optionButton.text:SetText(option.label)
            optionButton:SetScript("OnClick", function()
                local filters = BrowserFilterState()
                filters[button.filterKey] = option.value
                UpdateText()
                listFrame:Hide()
                -- Sync to Blizzard's native advanced filter when relevant dropdowns change.
                if button.filterKey == "difficulty" then
                    SyncBrowserNativeDifficulty()
                elseif button.filterKey == "playstyle" then
                    SyncBrowserNativePlaystyle()
                    -- Auto-refresh so results update immediately without needing a manual Refresh click.
                    if addonTable.RunBrowserSearch then
                        addonTable.RunBrowserSearch()
                    end
                    if addonTable.FetchSearchResultData then
                        C_Timer.After(0.15, function()
                            addonTable.FetchSearchResultData()
                            if addonTable.UpdateDisplay then addonTable.UpdateDisplay() end
                        end)
                    end
                end
                RefreshBrowserFilters()
            end)
            optionButton:Show()
        end
    end

    button:SetScript("OnClick", function(self)
        RefreshOptions()
        if listFrame:IsShown() then
            listFrame:Hide()
        else
            HideAllBrowserDropdowns(self)
            listFrame:ClearAllPoints()
            listFrame:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -1)
            listFrame:Show()
        end
    end)
    button:SetScript("OnHide", function()
        listFrame:Hide()
    end)

    button.UpdateText = UpdateText
    function button:SetDropdownWidth(newWidth)
        local resolvedWidth = math.max(120, math.floor(tonumber(newWidth) or width))
        self.dropdownWidth = resolvedWidth
        self:SetWidth(resolvedWidth)
        if self.listFrame then
            self.listFrame:SetWidth(resolvedWidth)
        end
    end
    return button
end

local function CreateBrowserNumberBox(parent, filterKey, width)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box:SetFontObject("OakLFG_FontRegular")
    box:SetJustifyH("CENTER")
    box:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
    box:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
    box:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    box:SetNumeric(true)

    local function Commit()
        local filters = BrowserFilterState()
        filters[filterKey] = box:GetText() or ""
        RefreshBrowserFilters()
    end

    box:SetScript("OnEnterPressed", function(self)
        Commit()
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", Commit)
    return box
end

local function CreateBrowserRangeBox(parent, filterKey, width)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box:SetFontObject("OakLFG_FontRegular")
    box:SetJustifyH("CENTER")
    box:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
    box:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
    box:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    -- No SetNumeric — allows range expressions like "<3", "1-5", ">2"

    local function Commit()
        local filters = BrowserFilterState()
        filters[filterKey] = box:GetText() or ""
        RefreshBrowserFilters()
    end

    box:SetScript("OnEnterPressed", function(self) Commit(); self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", Commit)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return box
end

local function GetBrowserDifficultyOptions()
    local mode = GetBrowserMode()
    if mode == "mythic_plus" or mode == "dungeon" then
        return {
            { value = "ANY", label = L["Any Difficulty"] },
            { value = "NORMAL", label = L["Normal"] },
            { value = "HEROIC", label = L["Heroic"] },
            { value = "MYTHIC", label = L["Mythic"] },
            { value = "MYTHIC_PLUS", label = L["Mythic+"] },
        }
    elseif mode == "raid" then
        return {
            { value = "ANY", label = L["Any Difficulty"] },
            { value = "NORMAL", label = L["Normal"] },
            { value = "HEROIC", label = L["Heroic"] },
            { value = "MYTHIC", label = L["Mythic"] },
        }
    end

    return {
        { value = "ANY", label = L["Any Difficulty"] },
    }
end

local function GetRaidBossOptions()
    local highestBossCount = 8
    for _, result in ipairs(addonTable.SearchResults or {}) do
        if result.mode == "raid" or result.mode == "legacy_raid" then
            highestBossCount = math.max(highestBossCount, tonumber(result.raidListing and result.raidListing.bossCount) or 0)
        end
    end

    local options = {
        { value = "ANY", label = "Any Boss Kills" },
        { value = "0", label = "Fresh (0 Kills)" },
    }

    for kills = 1, math.max(1, highestBossCount) do
        table.insert(options, {
            value = tostring(kills),
            label = string.format("%d+ Boss%s", kills, kills == 1 and "" or "es"),
        })
    end

    return options
end

-- Returns "No DKs", "No Pallies", etc. based on the player's own class.
local function GetNeedsMyClassLabel()
    local _, playerClass = UnitClass("player")
    local labels = {
        DEATHKNIGHT = "No DKs",
        DEMONHUNTER = "No DHs",
        DRUID       = "No Druids",
        EVOKER      = "No Evokers",
        HUNTER      = "No Hunters",
        MAGE        = "No Mages",
        MONK        = "No Monks",
        PALADIN     = "No Pallies",
        PRIEST      = "No Priests",
        ROGUE       = "No Rogues",
        SHAMAN      = "No Shammies",
        WARLOCK     = "No Locks",
        WARRIOR     = "No Warriors",
    }
    return labels[playerClass] or "No [class]"
end
addonTable.GetNeedsMyClassLabel = GetNeedsMyClassLabel

-- Returns a hint string for the search query box based on the current search mode.
local function GetSearchQueryLabel(mode)
    if mode == "mythic_plus" or mode == "dungeon" then
        -- Dungeon and M+ share the same filter panel layout
        return "Examples: 10-11, <10, <12"
    elseif mode == "raid" or mode == "legacy_raid" then
        return "Search raid groups..."
    end
    return ""
end
addonTable.GetSearchQueryLabel = GetSearchQueryLabel

local playstyleDropdown = CreateBrowserDropdown(browserContent, 188, function()
    return {
        { value = "ANY", label = "Any Playstyle" },
        { value = "COMPETITIVE", label = "Competitive" },
        { value = "RELAXED", label = "Relaxed" },
        { value = "LEARNING", label = "Learning" },
        { value = "CARRY", label = "Carry Offered" },
    }
end, "playstyle", "Any Playstyle")

local difficultyDropdown = CreateBrowserDropdown(browserContent, 188, GetBrowserDifficultyOptions, "difficulty", L["Any Difficulty"])
local raidBossesDropdown = CreateBrowserDropdown(browserContent, 188, GetRaidBossOptions, "raidBossesMin", "Any Boss Kills")

-- Raid range filter rows (Boss Kills, Tanks, Healers, DPS)
local raidRangeRows = {}
local function CreateRaidRangeRow(filterKey, labelText)
    local label = browserContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    label:SetText(labelText)
    do
        local accent = addonTable.GetThemeAccentColor and addonTable.GetThemeAccentColor(addonTable.GetThemePreset and addonTable.GetThemePreset() or nil) or addonTable.ClassColor
        label:SetTextColor(accent.r, accent.g, accent.b)
    end
    label:Hide()

    local box = CreateBrowserRangeBox(browserContent, filterKey, 60)
    box:Hide()
    box:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(labelText, 1, 1, 1)
        GameTooltip:AddLine("Enter a number or range expression, then press Enter.", 1, 1, 1, true)
        GameTooltip:AddLine("Examples:  3  |  1-4  |  <3  |  >=2  |  >0", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    box:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local resetBtn = addonTable.CreateFlatButton(browserContent, "R", 20)
    resetBtn.text:SetFontObject("OakLFG_FontSmall")
    resetBtn:Hide()
    resetBtn:SetScript("OnClick", function()
        local filters = BrowserFilterState()
        filters[filterKey] = ""
        box:SetText("")
        RefreshBrowserFilters()
    end)

    raidRangeRows[filterKey] = { label = label, box = box, resetBtn = resetBtn }
    return raidRangeRows[filterKey]
end

CreateRaidRangeRow("raidBossKills", "Boss Kills")
CreateRaidRangeRow("raidTanks",    "Tanks")
CreateRaidRangeRow("raidHealers",  "Healers")
CreateRaidRangeRow("raidDps",      "DPS")

local keyRangeLabel = browserContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
keyRangeLabel:SetText(L["Key Range"])
keyRangeLabel:SetTextColor(1, 1, 1)
local keyMinBox = CreateBrowserNumberBox(browserContent, "keyMin", 48)
local keyRangeTo = browserContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
keyRangeTo:SetText("to")
local keyMaxBox = CreateBrowserNumberBox(browserContent, "keyMax", 48)
-- Role + utility toggle boxes (matching old Search.lua layout: Need/Has columns)
local browserToggleKeys = {
    { key = "needsTank",   label = "Need Tank",    column = 1 },
    { key = "hasTank",     label = "Has Tank",     column = 2 },
    { key = "needsHealer", label = "Need Healer",  column = 1 },
    { key = "hasHealer",   label = "Has Healer",   column = 2 },
    { key = "needsDPS",    label = "Need Damage",  column = 1 },
    -- column 2 of needsDPS row = "No [class]" handled separately below
    { key = "partyFit",    label = "Party Fit",    column = 1 },
    { key = "hasLust",     label = "Has Lust",     column = 2 },
    { key = "needsBrez",   label = "Need BRez",    column = 1 },
    { key = "hasBrez",     label = "Has BRez",     column = 2 },
    { key = "needsLust",   label = "Need Lust",    column = 1 },
    { key = "hideDeclined",label = "Hide Declined",column = 2 },
    { key = "matchMyRaidLockout", label = "Match My Lockout", column = 1, span = 2, raidOnly = true },
}
local browserToggleTooltips = {
    needsLust = {
        title = "Need Lust",
        body = "Shows groups that do not currently have Lust, but are still reasonable for your current party to join.",
        detail = "If your current party already brings Lust, those groups still pass. If your party does not bring Lust, Oak only keeps groups that still have room for a Lust-capable class after your party joins.",
    },
    hasLust = {
        title = "Has Lust",
        body = "Shows groups that will have Lust once your current party joins.",
        detail = "A group passes if it already has Lust or your current party brings Lust and the party can actually fit into the group.",
    },
    needsBrez = {
        title = "Need BRez",
        body = "Shows groups that do not currently have a battle resurrection, but are still reasonable for your current party to join.",
        detail = "If your current party already brings BRez, those groups still pass. If your party does not bring BRez, Oak only keeps groups that still have room for a BRez-capable class after your party joins.",
    },
    hasBrez = {
        title = "Has BRez",
        body = "Shows groups that will have a battle resurrection once your current party joins.",
        detail = "A group passes if it already has BRez or your current party brings BRez and the party can actually fit into the group.",
    },
}

local browserToggleRows = {}
for _, toggleInfo in ipairs(browserToggleKeys) do
    local box = CreateBrowserToggleBox(browserContent, toggleInfo.key)
    local text = browserContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    browserToggleRows[toggleInfo.key] = { box = box, text = text, label = toggleInfo.label }
    text:SetPoint("LEFT", box, "RIGHT", 6, 0)
    text:SetText(toggleInfo.label)

    local tooltipInfo = browserToggleTooltips[toggleInfo.key]
    if tooltipInfo then
        local function ShowBrowserToggleTooltip(self)
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
            end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltipInfo.title, 1, 1, 1)
            GameTooltip:AddLine(tooltipInfo.body, 1, 1, 1, true)
            if tooltipInfo.detail and tooltipInfo.detail ~= "" then
                GameTooltip:AddLine(tooltipInfo.detail, 0.85, 0.85, 0.85, true)
            end
            GameTooltip:Show()
        end

        local function HideBrowserToggleTooltip(self)
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(addonTable.ClassColor.r * 0.65, addonTable.ClassColor.g * 0.65, addonTable.ClassColor.b * 0.65, 1)
            end
            GameTooltip:Hide()
        end

        box:SetScript("OnEnter", ShowBrowserToggleTooltip)
        box:SetScript("OnLeave", HideBrowserToggleTooltip)
        text:SetScript("OnEnter", function() ShowBrowserToggleTooltip(box) end)
        text:SetScript("OnLeave", function() HideBrowserToggleTooltip(box) end)
    end
end

-- Override OnClick for the 5 native-backed role toggles so they write directly to
-- C_LFGList.SaveAdvancedFilter — the same pattern v2.0.12 used in Search.lua.
-- This avoids the BrowserFilterState intermediary and keeps Blizzard's filter as the
-- single source of truth for these keys.
local function MakeNativeAdvToggle(advKey)
    return function(self)
        local ok, adv = pcall(C_LFGList.GetAdvancedFilter)
        if not ok or type(adv) ~= "table" then adv = {} end
        adv[advKey] = not (adv[advKey] == true) and true or nil
        self:SetState(adv[advKey] == true)
        pcall(C_LFGList.SaveAdvancedFilter, adv)
        RefreshBrowserFilters()
    end
end
browserToggleRows["needsTank"].box:SetScript("OnClick",   MakeNativeAdvToggle("needsTank"))
browserToggleRows["hasTank"].box:SetScript("OnClick",     MakeNativeAdvToggle("hasTank"))
browserToggleRows["needsHealer"].box:SetScript("OnClick", MakeNativeAdvToggle("needsHealer"))
browserToggleRows["hasHealer"].box:SetScript("OnClick",   MakeNativeAdvToggle("hasHealer"))
browserToggleRows["needsDPS"].box:SetScript("OnClick",    MakeNativeAdvToggle("needsDamage"))  -- Blizzard uses "needsDamage"
browserToggleRows["matchMyRaidLockout"].box:SetScript("OnClick", function(self)
    local filters = BrowserFilterState()
    if GetBrowserMode() == "delve" then
        filters.bountifulOnly = not filters.bountifulOnly
        self:SetState(filters.bountifulOnly == true)
    else
        filters.matchMyRaidLockout = not filters.matchMyRaidLockout
        self:SetState(filters.matchMyRaidLockout == true)
    end
    RefreshBrowserFilters()
end)

-- "No [player class]" toggle — column 2 of the Need Damage row
local browserNoClassBox = CreateBrowserToggleBox(browserContent, "needsMyClass")
local browserNoClassText = browserContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
browserNoClassText:SetPoint("LEFT", browserNoClassBox, "RIGHT", 6, 0)
browserNoClassBox:SetScript("OnClick", MakeNativeAdvToggle("needsMyClass"))

-- Min Rating input
local browserMinRatingLabel = browserContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
browserMinRatingLabel:SetText(L["Min Rating"])
do
    local accent = addonTable.GetThemeAccentColor and addonTable.GetThemeAccentColor(addonTable.GetThemePreset and addonTable.GetThemePreset() or nil) or addonTable.ClassColor
    browserMinRatingLabel:SetTextColor(accent.r, accent.g, accent.b)
end

browserMinRatingBox = CreateFrame("EditBox", nil, browserContent, "BackdropTemplate")
browserMinRatingBox:SetSize(60, 20)
browserMinRatingBox:SetAutoFocus(false)
browserMinRatingBox:SetFontObject("OakLFG_FontRegular")
browserMinRatingBox:SetJustifyH("CENTER")
browserMinRatingBox:SetBackdrop({ bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1 })
browserMinRatingBox:SetBackdropColor(unpack(addonTable.OAK_COLOR_PANE))
browserMinRatingBox:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
local function CommitMinRating()
    -- Write directly to Blizzard's native advanced filter (no taint)
    local ok, adv = pcall(C_LFGList.GetAdvancedFilter)
    if not ok or type(adv) ~= "table" then adv = {} end
    local text = browserMinRatingBox:GetText() or ""
    local minR = tonumber(text)
    adv.minimumRating = (minR and minR > 0) and minR or nil
    pcall(C_LFGList.SaveAdvancedFilter, adv)
    RefreshBrowserFilters()
end
browserMinRatingBox:SetScript("OnEnterPressed", function(self) CommitMinRating(); self:ClearFocus() end)
browserMinRatingBox:SetScript("OnEditFocusLost", CommitMinRating)
browserMinRatingBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

-- "Select Filters then Click Refresh" instruction label (shown above the hint)
local browserQueryLabel = browserContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
browserQueryLabel:SetTextColor(0.70, 0.70, 0.70)
browserQueryLabel:SetText(L["Select Filters then Click Refresh"])
browserQueryLabel:Hide()

-- Search query hint text
local browserQueryHint = browserContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
browserQueryHint:SetTextColor(0.60, 0.60, 0.60)
browserQueryHint:SetJustifyH("LEFT")
browserQueryHint:SetWordWrap(true)

-- Container frame for the native Blizzard SearchBox.
-- We reparent LFGListFrame.SearchPanel.SearchBox into this frame when the panel
-- is shown, and restore it when the panel is hidden.  This is the same taint-free
-- approach used by the retired Search.lua (v2.0.12).
local browserQueryBoxFrame = CreateFrame("Frame", nil, browserContent, "BackdropTemplate")
browserQueryBoxFrame:SetHeight(20)
browserQueryBoxFrame:SetBackdrop({ bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1 })
browserQueryBoxFrame:SetBackdropColor(unpack(addonTable.OAK_COLOR_PANE))
browserQueryBoxFrame:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))

local browserNativeSearchOriginalState    = nil
local browserNativeAutoCompleteOriginalState = nil

local function AttachBrowserNativeSearchBox()
    local searchBox = LFGListFrame and LFGListFrame.SearchPanel and LFGListFrame.SearchPanel.SearchBox
    if not (searchBox and browserQueryBoxFrame) then return end
    if not browserFilterPanel:IsShown() then return end
    if browserNativeSearchOriginalState then return end  -- already attached

    local point, relativeTo, relativePoint, xOfs, yOfs = searchBox:GetPoint(1)
    browserNativeSearchOriginalState = {
        parent        = searchBox:GetParent(),
        point         = point,
        relativeTo    = relativeTo,
        relativePoint = relativePoint,
        xOfs          = xOfs,
        yOfs          = yOfs,
        width         = searchBox:GetWidth(),
        height        = searchBox:GetHeight(),
        frameStrata   = searchBox:GetFrameStrata(),
        frameLevel    = searchBox:GetFrameLevel(),
        onEnterPressed = searchBox:GetScript("OnEnterPressed"),
        onEscapePressed = searchBox:GetScript("OnEscapePressed"),
    }

    -- Reparent the autocomplete dropdown too
    if LFGListFrame.SearchPanel.AutoCompleteFrame then
        local acf = LFGListFrame.SearchPanel.AutoCompleteFrame
        local p, rt, rp, x, y2 = acf:GetPoint(1)
        browserNativeAutoCompleteOriginalState = {
            parent = acf:GetParent(), point = p, relativeTo = rt,
            relativePoint = rp, xOfs = x, yOfs = y2,
            frameStrata = acf:GetFrameStrata(), frameLevel = acf:GetFrameLevel(),
        }
        acf:SetParent(browserFilterPanel)
        acf:ClearAllPoints()
        acf:SetPoint("TOPLEFT", browserQueryBoxFrame, "BOTTOMLEFT", 0, -2)
        acf:SetFrameStrata("TOOLTIP")
        acf:SetFrameLevel(browserFilterPanel:GetFrameLevel() + 30)
    end

    searchBox:ClearAllPoints()
    searchBox:SetParent(browserQueryBoxFrame)
    searchBox:SetPoint("TOPLEFT",     browserQueryBoxFrame, "TOPLEFT",     2, -2)
    searchBox:SetPoint("BOTTOMRIGHT", browserQueryBoxFrame, "BOTTOMRIGHT", -2,  2)
    searchBox:SetFrameStrata("DIALOG")
    searchBox:SetFrameLevel(browserQueryBoxFrame:GetFrameLevel() + 5)
    -- Blizzard's OnTextChanged calls LFGListSearchPanel_UpdateAutoComplete(self:GetParent())
    -- which expects parent.SearchBox to exist.  Set it so autocomplete doesn't error.
    browserQueryBoxFrame.SearchBox = searchBox
    if LFGListFrame.SearchPanel.AutoCompleteFrame then
        browserQueryBoxFrame.AutoCompleteFrame = LFGListFrame.SearchPanel.AutoCompleteFrame
    end
    searchBox:SetScript("OnEnterPressed", function(self)
        if addonTable.RunBrowserSearch then
            addonTable.RunBrowserSearch()
        end
        if addonTable.FetchSearchResultData then
            C_Timer.After(0.15, function()
                addonTable.FetchSearchResultData()
                if addonTable.UpdateDisplay then addonTable.UpdateDisplay() end
            end)
        end
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    searchBox:Show()
end

local function RestoreBrowserNativeSearchBox()
    if not browserNativeSearchOriginalState then return end
    local searchBox = LFGListFrame and LFGListFrame.SearchPanel and LFGListFrame.SearchPanel.SearchBox
    if not searchBox then browserNativeSearchOriginalState = nil; return end

    -- Restore autocomplete frame
    if browserNativeAutoCompleteOriginalState and LFGListFrame.SearchPanel.AutoCompleteFrame then
        local acf = LFGListFrame.SearchPanel.AutoCompleteFrame
        acf:SetParent(browserNativeAutoCompleteOriginalState.parent)
        acf:ClearAllPoints()
        if browserNativeAutoCompleteOriginalState.point and browserNativeAutoCompleteOriginalState.relativeTo then
            acf:SetPoint(
                browserNativeAutoCompleteOriginalState.point,
                browserNativeAutoCompleteOriginalState.relativeTo,
                browserNativeAutoCompleteOriginalState.relativePoint,
                browserNativeAutoCompleteOriginalState.xOfs,
                browserNativeAutoCompleteOriginalState.yOfs)
        end
        if browserNativeAutoCompleteOriginalState.frameStrata then acf:SetFrameStrata(browserNativeAutoCompleteOriginalState.frameStrata) end
        if browserNativeAutoCompleteOriginalState.frameLevel then acf:SetFrameLevel(browserNativeAutoCompleteOriginalState.frameLevel) end
        browserNativeAutoCompleteOriginalState = nil
    end

    searchBox:ClearAllPoints()
    if browserNativeSearchOriginalState.parent then
        searchBox:SetParent(browserNativeSearchOriginalState.parent)
    end
    if browserNativeSearchOriginalState.point and browserNativeSearchOriginalState.relativeTo then
        searchBox:SetPoint(
            browserNativeSearchOriginalState.point,
            browserNativeSearchOriginalState.relativeTo,
            browserNativeSearchOriginalState.relativePoint,
            browserNativeSearchOriginalState.xOfs,
            browserNativeSearchOriginalState.yOfs)
    end
    if browserNativeSearchOriginalState.width and browserNativeSearchOriginalState.height then
        searchBox:SetSize(browserNativeSearchOriginalState.width, browserNativeSearchOriginalState.height)
    end
    if browserNativeSearchOriginalState.frameStrata then searchBox:SetFrameStrata(browserNativeSearchOriginalState.frameStrata) end
    if browserNativeSearchOriginalState.frameLevel  then searchBox:SetFrameLevel(browserNativeSearchOriginalState.frameLevel) end
    if browserNativeSearchOriginalState.onEnterPressed  then searchBox:SetScript("OnEnterPressed",  browserNativeSearchOriginalState.onEnterPressed) end
    if browserNativeSearchOriginalState.onEscapePressed then searchBox:SetScript("OnEscapePressed", browserNativeSearchOriginalState.onEscapePressed) end
    -- Clear the SearchBox/AutoCompleteFrame references we set on the host frame
    browserQueryBoxFrame.SearchBox = nil
    browserQueryBoxFrame.AutoCompleteFrame = nil
    searchBox:Show()
    browserNativeSearchOriginalState = nil
end

-- Hook filter panel hide to restore the search box to Blizzard's panel
browserFilterPanel:HookScript("OnHide", function() RestoreBrowserNativeSearchBox() end)

local function ApplyBrowserQueryAndRefresh()
    if addonTable.RunBrowserSearch then
        addonTable.RunBrowserSearch()
    end
    if addonTable.FetchSearchResultData then
        C_Timer.After(0.15, function()
            addonTable.FetchSearchResultData()
            if addonTable.UpdateDisplay then addonTable.UpdateDisplay() end
        end)
    end
end

-- Refresh and Reset buttons (2-column layout inside filter panel)
local BFP_BTN_W = 88
local browserInRefreshBtn = addonTable.CreateFlatButton(browserContent, L["Refresh"], BFP_BTN_W)
browserInRefreshBtn:SetAutoWidth(BFP_BTN_W, 130, 22)
browserInRefreshBtn:SetScript("OnClick", ApplyBrowserQueryAndRefresh)

local browserResetBtn = addonTable.CreateFlatButton(browserContent, L["Reset"], BFP_BTN_W)
browserResetBtn:SetAutoWidth(BFP_BTN_W, 130, 22)
browserResetBtn:SetScript("OnClick", function()
    -- Reset client-side only filter state
    local filters = BrowserFilterState()
    filters.difficulty = "ANY"
    filters.playstyle  = "ANY"
    filters.keyMin = ""; filters.keyMax = ""
    filters.partyFit = false; filters.needsLust = false
    filters.needsBrez = false; filters.hasLust = false
    filters.hasBrez = false; filters.hideDeclined = false
    filters.raidBossesMin = "ANY"; filters.matchMyRaidLockout = false; filters.bountifulOnly = false
    filters.raidBossKills = ""; filters.raidTanks = ""
    filters.raidHealers = ""; filters.raidDps = ""
    filters.selectedActivities = {}
    -- Clear raid range input boxes
    for _, key in ipairs({"raidBossKills", "raidTanks", "raidHealers", "raidDps"}) do
        if raidRangeRows[key] then raidRangeRows[key].box:SetText("") end
    end
    -- Wipe ALL Blizzard native advanced filter fields (role, rating, activities)
    if C_LFGList and C_LFGList.SaveAdvancedFilter then
        local ok, adv = pcall(C_LFGList.GetAdvancedFilter)
        if not ok or type(adv) ~= "table" then adv = {} end
        adv.needsTank = nil; adv.needsHealer = nil; adv.needsDamage = nil
        adv.needsMyClass = nil; adv.hasTank = nil; adv.hasHealer = nil
        adv.minimumRating = nil; adv.maximumRating = nil; adv.activities = {}
        adv.difficultyNormal = nil; adv.difficultyHeroic = nil
        adv.difficultyMythic = nil; adv.difficultyMythicPlus = nil
        pcall(C_LFGList.SaveAdvancedFilter, adv)
    end
    -- NOTE: We deliberately do NOT clear the native SearchBox text here.
    -- The native SearchBox is owned by Blizzard; calling SetText on it causes taint.
    -- The user can clear it themselves, or it will be reset on the next search context change.
    RefreshBrowserFilters()
    if addonTable.RunBrowserSearch then
        addonTable.RunBrowserSearch()
    end
end)

-- Activity Select All / None buttons
local activitySelectAllBtn = addonTable.CreateFlatButton(browserContent, "A", 18)
activitySelectAllBtn.text:SetFontObject("OakLFG_FontSmall")
activitySelectAllBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L["Select All"], 1, 1, 1)
    GameTooltip:AddLine(L["Select every activity in this list."], 1, 1, 1, true)
    GameTooltip:Show()
end)
activitySelectAllBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)
activitySelectAllBtn:SetScript("OnClick", function()
    local filters = BrowserFilterState()
    local activities = addonTable.GetAvailableBrowserActivities and addonTable.GetAvailableBrowserActivities() or {}
    for _, entry in ipairs(activities) do
        filters.selectedActivities[entry.filterKey] = true
    end
    SyncVisibleBrowserActivityButtonStates()
    SyncBrowserNativeActivities()
    RefreshBrowserFilters()
end)

local activitySelectNoneBtn = addonTable.CreateFlatButton(browserContent, "N", 18)
activitySelectNoneBtn.text:SetFontObject("OakLFG_FontSmall")
activitySelectNoneBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L["Select None"], 1, 1, 1)
    GameTooltip:AddLine(L["Clear every activity in this list."], 1, 1, 1, true)
    GameTooltip:Show()
end)
activitySelectNoneBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)
activitySelectNoneBtn:SetScript("OnClick", function()
    local filters = BrowserFilterState()
    for k in pairs(filters.selectedActivities) do
        filters.selectedActivities[k] = nil
    end
    SyncVisibleBrowserActivityButtonStates()
    SyncBrowserNativeActivities()
    RefreshBrowserFilters()
end)

local activitySelectBountifulBtn = addonTable.CreateFlatButton(browserContent, "B", 18)
activitySelectBountifulBtn.text:SetFontObject("OakLFG_FontSmall")
activitySelectBountifulBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L["Select Bountiful"], 1, 1, 1)
    GameTooltip:AddLine(L["Select only the delves that are currently bountiful."], 1, 1, 1, true)
    GameTooltip:Show()
end)
activitySelectBountifulBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)
activitySelectBountifulBtn:SetScript("OnClick", function()
    local filters = BrowserFilterState()
    local activities = addonTable.GetAvailableBrowserActivities and addonTable.GetAvailableBrowserActivities() or {}
    for k in pairs(filters.selectedActivities) do
        filters.selectedActivities[k] = nil
    end
    for _, entry in ipairs(activities) do
        if addonTable.IsCurrentBountifulDelve and addonTable.IsCurrentBountifulDelve(entry.label) then
            filters.selectedActivities[entry.filterKey] = true
        end
    end
    SyncVisibleBrowserActivityButtonStates()
    SyncBrowserNativeActivities()
    RefreshBrowserFilters()
end)

local activityDivider = browserContent:CreateTexture(nil, "ARTWORK")
activityDivider:SetTexture(addonTable.FLAT_TEX)
activityDivider:SetVertexColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 0.7)

local activityHeader = browserContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
activityHeader:SetText(L["Filter Activities"])
activityHeader:SetTextColor(1, 1, 1)

local playerMythicRatingText = browserContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
playerMythicRatingText:SetTextColor(0.75, 0.82, 0.98)
playerMythicRatingText:SetJustifyH("LEFT")
playerMythicRatingText:Hide()

-- "Gives Score" column header (shown right of dungeon names for M+ mode)
local givesScoreHeader = browserContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
givesScoreHeader:SetText(L["Gives Score"])
givesScoreHeader:SetTextColor(0.40, 1.00, 0.55)
givesScoreHeader:SetJustifyH("RIGHT")
givesScoreHeader:Hide()

local givesScoreHeaderHitbox = CreateFrame("Button", nil, browserContent)
givesScoreHeaderHitbox:SetSize(72, 16)
givesScoreHeaderHitbox:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(L["Gives Score"], 1, 1, 1)
    GameTooltip:AddLine(L["Shows the lowest timed key level that should increase your score for that dungeon, plus the estimated score gain."], 1, 1, 1, true)
    GameTooltip:Show()
end)
givesScoreHeaderHitbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
givesScoreHeaderHitbox:Hide()

local function GetBrowserActivitySectionTitle()
    local mode = GetBrowserMode()
    if mode == "raid" then
        return L["Filter Raids"]
    elseif mode == "delve" then
        return L["Filter Delves"]
    elseif mode == "mythic_plus" or mode == "dungeon" then
        return L["Filter Dungeons"]
    end

    return nil
end

local function GetPlayerMythicPlusRatingValue()
    if C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, "player")
        if ok and type(summary) == "table" then
            local score = tonumber(summary.currentSeasonScore)
            if score and score > 0 then
                return math.floor(score + 0.5)
            end
        end
    end

    if RaiderIO and RaiderIO.GetProfile then
        local playerName = UnitName and UnitName("player")
        local playerRealm = GetNormalizedRealmName and GetNormalizedRealmName()
        if playerName and playerRealm then
            local ok, profile = pcall(RaiderIO.GetProfile, playerName, playerRealm)
            local score = ok and profile and profile.mythicKeystoneProfile and profile.mythicKeystoneProfile.currentScore
            score = tonumber(score)
            if score and score > 0 then
                return math.floor(score + 0.5)
            end
        end
    end

    return nil
end

local function GetPreferredPlayerScoreColor(score, defaultR, defaultG, defaultB)
    if RaiderIO and RaiderIO.GetScoreColor then
        local r, g, b = RaiderIO.GetScoreColor(score)
        if r and g and b then
            return r, g, b
        end
    end

    if C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor then
        local color = C_ChallengeMode.GetDungeonScoreRarityColor(score)
        if color then
            return color.r, color.g, color.b
        end
    end

    return defaultR, defaultG, defaultB
end

local function UpdatePlayerMythicPlusRatingText(mode, anchorY)
    if mode ~= "mythic_plus" and mode ~= "dungeon" then
        playerMythicRatingText:Hide()
        return anchorY
    end

    local score = GetPlayerMythicPlusRatingValue()
    playerMythicRatingText:ClearAllPoints()
    playerMythicRatingText:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, anchorY)
    if score and score > 0 then
        local r, g, b = GetPreferredPlayerScoreColor(score, 0.75, 0.82, 0.98)
        local coloredScore = string.format("|cFF%02x%02x%02x%d|r", r * 255, g * 255, b * 255, score)
        playerMythicRatingText:SetText(string.format("%s %s", L["Your M+ Rating:"], coloredScore))
    else
        playerMythicRatingText:SetText(L["Your M+ Rating: --"])
    end
    playerMythicRatingText:Show()
    return anchorY - 18
end

local function UpdateBrowserActivityButtons(startY)
    local filters = BrowserFilterState()
    SyncBrowserSelectedActivitiesFromNative()
    local activities = addonTable.GetAvailableBrowserActivities and addonTable.GetAvailableBrowserActivities() or {}
    local validKeys = {}
    local mode = GetBrowserMode()
    local showScoreColumn = (mode == "mythic_plus" or mode == "dungeon")

    for _, entry in ipairs(activities) do
        validKeys[entry.filterKey] = true
    end
    for selectedKey, _ in pairs(filters.selectedActivities) do
        if not validKeys[selectedKey] then
            filters.selectedActivities[selectedKey] = nil
        end
    end

    for _, button in ipairs(browserActivityButtons) do
        button:Hide()
        -- button.text is a child of browserContent, NOT of button, so we must
        -- hide it explicitly — hiding the checkbox frame does not cascade to it.
        if button.text then button.text:Hide() end
        if button.scoreText then button.scoreText:Hide() end
        if button.scoreHitbox then button.scoreHitbox:Hide() end
    end

    -- givesScoreHeader is now positioned inline with the section header row
    -- (handled by UpdateBrowserFilterPanel), not here.

    local y = startY
    for index, entry in ipairs(activities) do
        local button = browserActivityButtons[index]
        if not button then
            button = CreateBrowserToggleBox(browserContent, "")
            button.text = browserContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
            button.text:SetJustifyH("LEFT")
            button.teleportButton = CreateFrame("Button", nil, browserContent, "SecureActionButtonTemplate")
            button.teleportButton:RegisterForClicks("AnyUp", "AnyDown")
            button.scoreText = browserContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
            button.scoreText:SetWidth(60)
            button.scoreText:SetJustifyH("RIGHT")
            button.scoreHitbox = CreateFrame("Button", nil, browserContent)
            button.scoreHitbox:SetSize(64, 16)
            button.scoreHitbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
            browserActivityButtons[index] = button
        end

        -- Resize label depending on whether score column is shown
        button.text:ClearAllPoints()
        button.text:SetPoint("LEFT", button, "RIGHT", 6, 0)
        if showScoreColumn then
            button.text:SetPoint("RIGHT", browserContent, "RIGHT", -68, 0)
        else
            button.text:SetPoint("RIGHT", browserContent, "RIGHT", -4, 0)
        end

        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y)
        button.activityID = entry.activityID
        button.filterKey = entry.filterKey
        button.mapID = entry.mapID
        button.text:SetText(entry.label)
        if mode == "delve" and addonTable.IsCurrentBountifulDelve and addonTable.IsCurrentBountifulDelve(entry.label) then
            button.text:SetTextColor(1.0, 0.82, 0.20)
        else
            button.text:SetTextColor(1, 1, 1)
        end
        button:SetState(filters.selectedActivities[entry.filterKey] == true)
        button:SetScript("OnClick", function(self)
            filters.selectedActivities[self.filterKey] = not filters.selectedActivities[self.filterKey]
            self:SetState(filters.selectedActivities[self.filterKey] == true)
            SyncBrowserNativeActivities()
            RefreshBrowserFilters()
        end)
        button.text:Show()
        button:Show()

        if showScoreColumn and entry.mapID then
            local spellID = addonTable.GetDungeonTeleportSpellID and addonTable.GetDungeonTeleportSpellID(entry.mapID) or nil
            button.teleportButton:ClearAllPoints()
            button.teleportButton:SetPoint("TOPLEFT", button, "TOPLEFT", 22, 0)
            button.teleportButton:SetSize(132, 16)
            button.teleportButton:Show()
            if not (InCombatLockdown and InCombatLockdown()) then
                if spellID and IsSpellKnown and IsSpellKnown(spellID) then
                    button.teleportButton:SetAttribute("type", "spell")
                    button.teleportButton:SetAttribute("spell", spellID)
                else
                    button.teleportButton:SetAttribute("type", nil)
                    button.teleportButton:SetAttribute("spell", nil)
                end
            end
            button.teleportButton:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetText(entry.label or "", 1, 1, 1)
                if spellID and IsSpellKnown and IsSpellKnown(spellID) then
                    GameTooltip:AddLine("Click to teleport", 0.5, 1, 0.5)
                elseif spellID then
                    GameTooltip:AddLine("Teleport spell not learned yet", 1, 0.35, 0.35)
                end
                GameTooltip:Show()
            end)
            button.teleportButton:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        else
            button.teleportButton:Hide()
            if not (InCombatLockdown and InCombatLockdown()) then
                button.teleportButton:SetAttribute("type", nil)
                button.teleportButton:SetAttribute("spell", nil)
            end
            button.teleportButton:SetScript("OnEnter", nil)
            button.teleportButton:SetScript("OnLeave", nil)
        end

        -- Score column
        if showScoreColumn and entry.scoreTarget then
            local targetLevel = tonumber(entry.scoreTarget.level)
            local estimatedGain = tonumber(entry.scoreTarget.estimatedGain)
            local scoreData = entry.scoreTarget
            button.scoreText:ClearAllPoints()
            button.scoreText:SetPoint("RIGHT", browserContent, "RIGHT", -2, 0)
            button.scoreText:SetPoint("TOP", button, "TOP", 0, 0)
            if targetLevel and targetLevel > 0 then
                if estimatedGain and estimatedGain > 0 then
                    button.scoreText:SetText(string.format("|cff66ff8a+%d|r |cff9dffb8(%d)|r", targetLevel, estimatedGain))
                else
                    button.scoreText:SetText(string.format("|cff66ff8a+%d|r", targetLevel))
                end
            else
                button.scoreText:SetText("")
            end
            button.scoreText:Show()

            button.scoreHitbox:ClearAllPoints()
            button.scoreHitbox:SetPoint("RIGHT", browserContent, "RIGHT", -2, 0)
            button.scoreHitbox:SetPoint("TOP", button, "TOP", 0, 0)
            button.scoreHitbox.entryData = entry
            button.scoreHitbox:SetScript("OnEnter", function(self)
                local data = self.entryData
                if not data or not data.scoreTarget then return end
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetText(data.label or "Gives Score", 1, 1, 1)
                local tLevel = tonumber(data.scoreTarget.level)
                local eGain = tonumber(data.scoreTarget.estimatedGain)
                local breakdown = data.scoreTarget.estimatedGainBreakdown
                if tLevel and tLevel > 0 then
                    if eGain and eGain > 0 then
                        GameTooltip:AddLine(string.format("A timed +%d should increase your score by about %d points for this dungeon.", tLevel, eGain), 0.40, 1.00, 0.55, true)
                    else
                        GameTooltip:AddLine(string.format("A timed +%d should increase your score for this dungeon.", tLevel), 0.40, 1.00, 0.55, true)
                    end
                    if type(breakdown) == "table" then
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine(string.format("+%d timed: %d  ++%d: %d  +++%d: %d", tLevel, tonumber(breakdown.timed) or 0, tLevel, tonumber(breakdown.plusTwo) or 0, tLevel, tonumber(breakdown.plusThree) or 0), 0.75, 1.00, 0.80, true)
                    end
                else
                    GameTooltip:AddLine("Oak could not determine a score-gain target for this dungeon yet.", 1, 1, 1, true)
                end
                GameTooltip:Show()
            end)
            button.scoreHitbox:Show()
        else
            button.scoreText:SetText("")
            button.scoreText:Hide()
            button.scoreHitbox:Hide()
        end

        y = y - 16
    end

    return y
end

SyncVisibleBrowserActivityButtonStates = function()
    local filters = BrowserFilterState()
    for _, button in ipairs(browserActivityButtons) do
        if button and button.filterKey then
            button:SetState(filters.selectedActivities[button.filterKey] == true)
        end
    end
end

function addonTable.UpdateBrowserFilterPanel()
    local filters = BrowserFilterState()
    local mode = GetBrowserMode()
    local showDifficulty = BrowserModeUsesDifficulty(mode)
    local showActivityFilters = BrowserModeUsesActivityFilter(mode)
    local isRaidMode = (mode == "raid") or (mode == "legacy_raid")
    local isDelveMode = (mode == "delve")
    local accent = addonTable.GetThemeAccentColor and addonTable.GetThemeAccentColor(addonTable.GetThemePreset and addonTable.GetThemePreset() or nil) or addonTable.ClassColor

    if addonTable.BrowserFilterTitle then
        addonTable.BrowserFilterTitle:SetTextColor(accent.r, accent.g, accent.b)
    end
    browserMinRatingLabel:SetTextColor(accent.r, accent.g, accent.b)
    for _, key in ipairs({"raidBossKills", "raidTanks", "raidHealers", "raidDps"}) do
        local row = raidRangeRows[key]
        if row and row.label then
            row.label:SetTextColor(accent.r, accent.g, accent.b)
        end
    end

    -- Validate difficulty for current mode
    local validDifficulty = {}
    for _, option in ipairs(GetBrowserDifficultyOptions()) do
        validDifficulty[option.value] = true
    end
    if not validDifficulty[filters.difficulty] then
        filters.difficulty = "ANY"
    end

    playstyleDropdown:Hide()
    -- Only close dropdowns during a full panel rebuild if none is currently open.
    -- Calling HideAllBrowserDropdowns while the user is mid-selection would
    -- dismiss the list frame and make the difficulty/activity dropdown unusable.
    if not IsBrowserDropdownOpen() then
        HideAllBrowserDropdowns()
    end
    -- Key range inputs are never shown (Blizzard SearchBox handles queries)
    keyRangeLabel:Hide(); keyMinBox:Hide(); keyRangeTo:Hide(); keyMaxBox:Hide()

    -- Layout constants
    local panelPadding = 14
    local contentInset = panelPadding * 2
    local leftLabelWidth = 0
    local rightLabelWidth = 0
    local hintText = GetSearchQueryLabel(mode)

    local function MeasureLeftLabel(text)
        leftLabelWidth = math.max(leftLabelWidth, addonTable.MeasureBrowserTextWidth(text, _G["OakLFG_FontRegular"]))
    end

    local function MeasureRightLabel(text)
        rightLabelWidth = math.max(rightLabelWidth, addonTable.MeasureBrowserTextWidth(text, _G["OakLFG_FontRegular"]))
    end

    if isRaidMode then
        for _, key in ipairs({"raidBossKills", "raidTanks", "raidHealers", "raidDps"}) do
            local row = raidRangeRows[key]
            if row and row.label then
                MeasureLeftLabel(row.label:GetText() or "")
            end
        end
        MeasureLeftLabel(browserToggleRows["partyFit"].label)
        MeasureRightLabel(browserToggleRows["needsLust"].label)
        MeasureLeftLabel(browserToggleRows["needsBrez"].label)
        MeasureRightLabel(browserToggleRows["matchMyRaidLockout"].label)
    else
        MeasureLeftLabel(browserToggleRows["needsTank"].label)
        MeasureRightLabel(browserToggleRows["hasTank"].label)
        MeasureLeftLabel(browserToggleRows["needsHealer"].label)
        MeasureRightLabel(browserToggleRows["hasHealer"].label)
        MeasureLeftLabel(browserToggleRows["needsDPS"].label)
        MeasureRightLabel(GetNeedsMyClassLabel())
        MeasureLeftLabel(browserMinRatingLabel:GetText() or "")
        MeasureLeftLabel(browserToggleRows["partyFit"].label)
        MeasureRightLabel(browserToggleRows["hideDeclined"].label)
        MeasureLeftLabel(browserToggleRows["needsBrez"].label)
        MeasureRightLabel(browserToggleRows["hasBrez"].label)
        MeasureLeftLabel(browserToggleRows["needsLust"].label)
        MeasureRightLabel(browserToggleRows["hasLust"].label)
        if isDelveMode then
            MeasureLeftLabel(browserToggleRows["hideDeclined"].label)
            MeasureRightLabel(L["Bountiful Only"])
        end
    end

    browserInRefreshBtn:RefreshAutoWidth()
    browserResetBtn:RefreshAutoWidth()
    local BTN_W = math.max(browserInRefreshBtn:GetWidth() or 88, browserResetBtn:GetWidth() or 88)
    local BTN_GAP = 6    -- gap between the two buttons
    local ROW_H   = 22   -- standard toggle row height
    local COL2_X  = math.max(96, leftLabelWidth + 30)
    local dropdownWidth = math.max(
        188,
        addonTable.MeasureBrowserTextWidth(L["Any Difficulty"], _G["OakLFG_FontRegular"]) + 44,
        addonTable.MeasureBrowserTextWidth("Any Playstyle", _G["OakLFG_FontRegular"]) + 44,
        addonTable.MeasureBrowserTextWidth("Any Boss Kills", _G["OakLFG_FontRegular"]) + 44
    )
    local desiredContentWidth = math.max(
        dropdownWidth,
        (BTN_W * 2) + BTN_GAP,
        COL2_X + 16 + 6 + rightLabelWidth,
        addonTable.MeasureBrowserTextWidth(browserQueryLabel:GetText() or "", _G["OakLFG_FontSmall"]),
        addonTable.MeasureBrowserTextWidth(hintText or "", _G["OakLFG_FontSmall"])
    )

    browserFilterPanel:SetWidth(math.max(210, desiredContentWidth + contentInset))
    local contentWidth = math.max(182, browserFilterPanel:GetWidth() - contentInset)
    difficultyDropdown:SetDropdownWidth(contentWidth)
    playstyleDropdown:SetDropdownWidth(contentWidth)
    raidBossesDropdown:SetDropdownWidth(contentWidth)
    browserQueryLabel:SetWidth(contentWidth)
    browserQueryHint:SetWidth(contentWidth)

    local y = 0  -- tracks next available top (goes negative)

    if isRaidMode then
        -- ═══════════════════════════════════════════════════════════════════════
        -- RAID MODE LAYOUT
        -- Shows: Difficulty, Boss Kills/Tanks/Healers/DPS range inputs, search
        --        box, Refresh/Reset, Party Fit, Need Lust, Need BRez, Match My
        --        Lockout, and the Filter Raids activity checklist.
        -- Hides: all M+-specific controls (role toggles, Min Rating, playstyle).
        -- ═══════════════════════════════════════════════════════════════════════

        -- Hide M+-specific widgets that must not appear in raid mode
        raidBossesDropdown:Hide()
        browserToggleRows["needsTank"].box:Hide();   browserToggleRows["needsTank"].text:Hide()
        browserToggleRows["hasTank"].box:Hide();     browserToggleRows["hasTank"].text:Hide()
        browserToggleRows["needsHealer"].box:Hide(); browserToggleRows["needsHealer"].text:Hide()
        browserToggleRows["hasHealer"].box:Hide();   browserToggleRows["hasHealer"].text:Hide()
        browserToggleRows["needsDPS"].box:Hide();    browserToggleRows["needsDPS"].text:Hide()
        browserToggleRows["hasBrez"].box:Hide();     browserToggleRows["hasBrez"].text:Hide()
        browserToggleRows["hasLust"].box:Hide();     browserToggleRows["hasLust"].text:Hide()
        browserNoClassBox:Hide(); browserNoClassText:Hide()
        browserMinRatingLabel:Hide(); browserMinRatingBox:Hide()
        browserToggleRows["hideDeclined"].box:Hide(); browserToggleRows["hideDeclined"].text:Hide()

        -- ── 1. Difficulty dropdown (full width) ──────────────────────────────
        if showDifficulty then
            difficultyDropdown:ClearAllPoints()
            difficultyDropdown:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y)
            difficultyDropdown.UpdateText()
            difficultyDropdown:Show()
            y = y - 28
        else
            difficultyDropdown:Hide()
        end

        -- ── 2. Range filter rows ─────────────────────────────────────────────
        --  Layout: Label(left) | 60px box at COL2_X | 20px R button
        local RANGE_BOX_X = COL2_X
        local RESET_BTN_X = RANGE_BOX_X + 64
        for _, key in ipairs({"raidBossKills", "raidTanks", "raidHealers", "raidDps"}) do
            local row = raidRangeRows[key]
            row.label:ClearAllPoints()
            row.label:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y - 2)
            row.label:Show()

            row.box:ClearAllPoints()
            row.box:SetPoint("TOPLEFT", browserContent, "TOPLEFT", RANGE_BOX_X, y)
            if not row.box:HasFocus() then
                row.box:SetText(filters[key] or "")
            end
            row.box:Show()

            row.resetBtn:ClearAllPoints()
            row.resetBtn:SetPoint("TOPLEFT", browserContent, "TOPLEFT", RESET_BTN_X, y)
            row.resetBtn:Show()

            y = y - ROW_H
        end

        -- ── 3. Search query hint + box ───────────────────────────────────────
        local hintText = GetSearchQueryLabel(mode)
        if hintText ~= "" then
            browserQueryLabel:ClearAllPoints()
            browserQueryLabel:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y)
            browserQueryLabel:Show()
            y = y - 14

            browserQueryHint:ClearAllPoints()
            browserQueryHint:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y)
            browserQueryHint:SetText(hintText)
            browserQueryHint:Show()
            y = y - 14
        else
            browserQueryLabel:Hide()
            browserQueryHint:Hide()
        end

        browserQueryBoxFrame:ClearAllPoints()
        browserQueryBoxFrame:SetPoint("TOPLEFT",  browserContent, "TOPLEFT",  0, y)
        browserQueryBoxFrame:SetPoint("TOPRIGHT", browserContent, "TOPRIGHT", 0, y)
        browserQueryBoxFrame:Show()
        AttachBrowserNativeSearchBox()
        y = y - 26

        -- ── 4. Refresh | Reset buttons ───────────────────────────────────────
        browserInRefreshBtn:ClearAllPoints()
        browserInRefreshBtn:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y)
        browserInRefreshBtn:SetWidth(BTN_W)
        browserInRefreshBtn:Show()

        browserResetBtn:ClearAllPoints()
        browserResetBtn:SetPoint("TOPLEFT", browserContent, "TOPLEFT", BTN_W + BTN_GAP, y)
        browserResetBtn:SetWidth(BTN_W)
        browserResetBtn:Show()
        y = y - 28

        -- ── 5. Party Fit | Need Lust ─────────────────────────────────────────
        do
            local r1 = browserToggleRows["partyFit"]
            local r2 = browserToggleRows["needsLust"]
            r1.box:ClearAllPoints(); r1.box:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y)
            r1.box:SetState(filters.partyFit == true); r1.text:SetText(r1.label); r1.box:Show(); r1.text:Show()

            r2.box:ClearAllPoints(); r2.box:SetPoint("TOPLEFT", browserContent, "TOPLEFT", COL2_X, y)
            r2.box:SetState(filters.needsLust == true); r2.text:SetText(r2.label); r2.box:Show(); r2.text:Show()
            y = y - ROW_H
        end

        -- ── 6. Need BRez | Match My Lockout ─────────────────────────────────
        do
            local r1 = browserToggleRows["needsBrez"]
            local r2 = browserToggleRows["matchMyRaidLockout"]
            r1.box:ClearAllPoints(); r1.box:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y)
            r1.box:SetState(filters.needsBrez == true); r1.text:SetText(r1.label); r1.box:Show(); r1.text:Show()

            r2.box:ClearAllPoints(); r2.box:SetPoint("TOPLEFT", browserContent, "TOPLEFT", COL2_X, y)
            r2.box:SetState(filters.matchMyRaidLockout == true); r2.text:SetText(r2.label); r2.box:Show(); r2.text:Show()
            y = y - ROW_H
        end

        -- ── 7. Activity section (Filter Raids) ───────────────────────────────
        if showActivityFilters then
            activityDivider:ClearAllPoints()
            activityDivider:SetPoint("TOPLEFT",  browserContent, "TOPLEFT",  0, y - 4)
            activityDivider:SetPoint("TOPRIGHT", browserContent, "TOPRIGHT", 0, y - 4)
            activityDivider:SetHeight(1)
            activityDivider:Show()

            activityHeader:ClearAllPoints()
            activityHeader:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y - 16)
            activityHeader:SetText(GetBrowserActivitySectionTitle() or L["Filter Raids"])
            activityHeader:Show()

            activitySelectAllBtn:ClearAllPoints()
            activitySelectAllBtn:SetPoint("LEFT", activityHeader, "RIGHT", 6, 0)
            activitySelectAllBtn:Show()

            activitySelectNoneBtn:ClearAllPoints()
            activitySelectNoneBtn:SetPoint("LEFT", activitySelectAllBtn, "RIGHT", 3, 0)
            activitySelectNoneBtn:Show()
            activitySelectBountifulBtn:Hide()

            -- No "Gives Score" column in raid mode
            givesScoreHeader:Hide()
            givesScoreHeaderHitbox:Hide()

            local endY = UpdateBrowserActivityButtons(y - 34)
            endY = UpdatePlayerMythicPlusRatingText(mode, endY - 2)
            local contentH = math.max(1, math.abs(endY) + 20)
            browserContent:SetHeight(contentH)
            browserFilterPanel:SetHeight(32 + contentH + 8)
        else
            activityDivider:Hide()
            activityHeader:Hide()
            playerMythicRatingText:Hide()
            activitySelectAllBtn:Hide()
            activitySelectNoneBtn:Hide()
            activitySelectBountifulBtn:Hide()
            givesScoreHeader:Hide()
            givesScoreHeaderHitbox:Hide()
            for _, button in ipairs(browserActivityButtons) do
                button:Hide()
                if button.text then button.text:Hide() end  -- text is child of browserContent, not button
                if button.scoreText then button.scoreText:Hide() end
                if button.scoreHitbox then button.scoreHitbox:Hide() end
            end
            local contentH = math.max(1, math.abs(y) + 20)
            browserContent:SetHeight(contentH)
            browserFilterPanel:SetHeight(32 + contentH + 8)
        end

    else
        -- ═══════════════════════════════════════════════════════════════════════
        -- NON-RAID MODE LAYOUT (M+, Dungeon, Delve, etc.)
        -- ═══════════════════════════════════════════════════════════════════════

        -- Hide all raid-specific widgets
        raidBossesDropdown:Hide()
        for _, key in ipairs({"raidBossKills", "raidTanks", "raidHealers", "raidDps"}) do
            local row = raidRangeRows[key]
            row.label:Hide(); row.box:Hide(); row.resetBtn:Hide()
        end
        browserToggleRows["matchMyRaidLockout"].box:Hide()
        browserToggleRows["matchMyRaidLockout"].text:Hide()

        -- ── 1. Difficulty dropdown ────────────────────────────────────────────
        if showDifficulty then
            difficultyDropdown:ClearAllPoints()
            difficultyDropdown:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y)
            difficultyDropdown.UpdateText()
            difficultyDropdown:Show()
            y = y - 28
        else
            difficultyDropdown:Hide()
        end

        -- ── 1b. Playstyle dropdown (M+ / dungeon only) ───────────────────────
        if mode == "mythic_plus" or mode == "dungeon" then
            playstyleDropdown:ClearAllPoints()
            playstyleDropdown:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y)
            playstyleDropdown.UpdateText()
            playstyleDropdown:Show()
            y = y - 28
        end

        -- ── 2. "Select Filters then Click Refresh" label + search query hint ─
        local hintText = GetSearchQueryLabel(mode)
        if hintText ~= "" then
            browserQueryLabel:ClearAllPoints()
            browserQueryLabel:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y)
            browserQueryLabel:Show()
            y = y - 14

            browserQueryHint:ClearAllPoints()
            browserQueryHint:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y)
            browserQueryHint:SetText(hintText)
            browserQueryHint:Show()
            y = y - 14
        else
            browserQueryLabel:Hide()
            browserQueryHint:Hide()
        end

        -- ── 3. Search query box ───────────────────────────────────────────────
        browserQueryBoxFrame:ClearAllPoints()
        browserQueryBoxFrame:SetPoint("TOPLEFT",  browserContent, "TOPLEFT",  0, y)
        browserQueryBoxFrame:SetPoint("TOPRIGHT", browserContent, "TOPRIGHT", 0, y)
        browserQueryBoxFrame:Show()
        AttachBrowserNativeSearchBox()
        y = y - 26

        -- ── 4. Refresh | Reset buttons ────────────────────────────────────────
        browserInRefreshBtn:ClearAllPoints()
        browserInRefreshBtn:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y)
        browserInRefreshBtn:SetWidth(BTN_W)
        browserInRefreshBtn:Show()

        browserResetBtn:ClearAllPoints()
        browserResetBtn:SetPoint("TOPLEFT", browserContent, "TOPLEFT", BTN_W + BTN_GAP, y)
        browserResetBtn:SetWidth(BTN_W)
        browserResetBtn:Show()
        y = y - 28

        -- Read the current native Blizzard advanced filter for native-backed toggles.
        local advOk, adv = pcall(C_LFGList.GetAdvancedFilter)
        if not advOk or type(adv) ~= "table" then adv = {} end

        -- ── 5. Toggle rows (2-column layout) ──────────────────────────────────
        -- Row 1: Need Tank | Has Tank
        do
            local r1 = browserToggleRows["needsTank"]
            local r2 = browserToggleRows["hasTank"]
            r1.box:ClearAllPoints(); r1.box:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y)
            r1.box:SetState(adv.needsTank == true); r1.text:SetText(r1.label); r1.box:Show(); r1.text:Show()

            r2.box:ClearAllPoints(); r2.box:SetPoint("TOPLEFT", browserContent, "TOPLEFT", COL2_X, y)
            r2.box:SetState(adv.hasTank == true); r2.text:SetText(r2.label); r2.box:Show(); r2.text:Show()
            y = y - ROW_H
        end

        -- Row 2: Need Healer | Has Healer
        do
            local r1 = browserToggleRows["needsHealer"]
            local r2 = browserToggleRows["hasHealer"]
            r1.box:ClearAllPoints(); r1.box:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y)
            r1.box:SetState(adv.needsHealer == true); r1.text:SetText(r1.label); r1.box:Show(); r1.text:Show()

            r2.box:ClearAllPoints(); r2.box:SetPoint("TOPLEFT", browserContent, "TOPLEFT", COL2_X, y)
            r2.box:SetState(adv.hasHealer == true); r2.text:SetText(r2.label); r2.box:Show(); r2.text:Show()
            y = y - ROW_H
        end

        -- Row 3: Need Damage | No [Class]
        do
            local r1 = browserToggleRows["needsDPS"]
            r1.box:ClearAllPoints(); r1.box:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y)
            r1.box:SetState(adv.needsDamage == true); r1.text:SetText(r1.label); r1.box:Show(); r1.text:Show()

            browserNoClassBox:ClearAllPoints()
            browserNoClassBox:SetPoint("TOPLEFT", browserContent, "TOPLEFT", COL2_X, y)
            browserNoClassBox:SetState(adv.needsMyClass == true)
            browserNoClassText:SetText(GetNeedsMyClassLabel())
            browserNoClassBox:Show(); browserNoClassText:Show()
            y = y - ROW_H
        end

        -- Row 4: Min Rating (label left | input right)
        do
            browserMinRatingLabel:ClearAllPoints()
            browserMinRatingLabel:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y - 2)
            browserMinRatingLabel:Show()

            browserMinRatingBox:ClearAllPoints()
            browserMinRatingBox:SetPoint("TOPLEFT", browserContent, "TOPLEFT", COL2_X, y - 2)
            if not browserMinRatingBox:HasFocus() then
                local minR = tonumber(adv.minimumRating)
                browserMinRatingBox:SetText(minR and tostring(math.floor(minR)) or "")
            end
            browserMinRatingBox:Show()
            y = y - ROW_H
        end

        -- Row 5: Party Fit | Hide Declined
        do
            local r1 = browserToggleRows["partyFit"]
            local r2 = browserToggleRows["hideDeclined"]
            r1.box:ClearAllPoints(); r1.box:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y)
            r1.box:SetState(filters.partyFit == true); r1.text:SetText(r1.label); r1.box:Show(); r1.text:Show()

            if isDelveMode then
                r2.box:Hide()
                r2.text:Hide()
            else
                r2.box:ClearAllPoints(); r2.box:SetPoint("TOPLEFT", browserContent, "TOPLEFT", COL2_X, y)
                r2.box:SetState(filters.hideDeclined == true); r2.text:SetText(r2.label); r2.box:Show(); r2.text:Show()
            end
            y = y - ROW_H
        end

        -- Row 6: Need BRez | Has BRez
        do
            local r1 = browserToggleRows["needsBrez"]
            local r2 = browserToggleRows["hasBrez"]
            r1.box:ClearAllPoints(); r1.box:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y)
            r1.box:SetState(filters.needsBrez == true); r1.text:SetText(r1.label); r1.box:Show(); r1.text:Show()

            r2.box:ClearAllPoints(); r2.box:SetPoint("TOPLEFT", browserContent, "TOPLEFT", COL2_X, y)
            r2.box:SetState(filters.hasBrez == true); r2.text:SetText(r2.label); r2.box:Show(); r2.text:Show()
            y = y - ROW_H
        end

        -- Row 7: Need Lust | Has Lust
        do
            local r1 = browserToggleRows["needsLust"]
            local r2 = browserToggleRows["hasLust"]
            r1.box:ClearAllPoints(); r1.box:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y)
            r1.box:SetState(filters.needsLust == true); r1.text:SetText(r1.label); r1.box:Show(); r1.text:Show()

            r2.box:ClearAllPoints(); r2.box:SetPoint("TOPLEFT", browserContent, "TOPLEFT", COL2_X, y)
            r2.box:SetState(filters.hasLust == true); r2.text:SetText(r2.label); r2.box:Show(); r2.text:Show()
            y = y - ROW_H
        end

        if isDelveMode then
            local r1 = browserToggleRows["hideDeclined"]
            local r2 = browserToggleRows["matchMyRaidLockout"]
            r1.box:ClearAllPoints(); r1.box:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y)
            r1.box:SetState(filters.hideDeclined == true); r1.text:SetText(r1.label); r1.box:Show(); r1.text:Show()

            r2.box:ClearAllPoints(); r2.box:SetPoint("TOPLEFT", browserContent, "TOPLEFT", COL2_X, y)
            r2.box:SetState(filters.bountifulOnly == true); r2.text:SetText(L["Bountiful Only"]); r2.box:Show(); r2.text:Show()
            y = y - ROW_H
        else
            browserToggleRows["matchMyRaidLockout"].box:Hide()
            browserToggleRows["matchMyRaidLockout"].text:Hide()
        end

        -- ── 6. Activity section ───────────────────────────────────────────────
        if showActivityFilters then
            activityDivider:ClearAllPoints()
            activityDivider:SetPoint("TOPLEFT",  browserContent, "TOPLEFT",  0, y - 4)
            activityDivider:SetPoint("TOPRIGHT", browserContent, "TOPRIGHT", 0, y - 4)
            activityDivider:SetHeight(1)
            activityDivider:Show()

            activityHeader:ClearAllPoints()
            activityHeader:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y - 16)
            activityHeader:SetText(GetBrowserActivitySectionTitle() or L["Filter Activities"])
            activityHeader:Show()

            activitySelectAllBtn:ClearAllPoints()
            activitySelectAllBtn:SetPoint("LEFT", activityHeader, "RIGHT", 6, 0)
            activitySelectAllBtn:Show()

            activitySelectNoneBtn:ClearAllPoints()
            activitySelectNoneBtn:SetPoint("LEFT", activitySelectAllBtn, "RIGHT", 3, 0)
            activitySelectNoneBtn:Show()

            if isDelveMode then
                activitySelectBountifulBtn:ClearAllPoints()
                activitySelectBountifulBtn:SetPoint("LEFT", activitySelectNoneBtn, "RIGHT", 3, 0)
                activitySelectBountifulBtn:Show()
            else
                activitySelectBountifulBtn:Hide()
            end

            -- "Gives Score" header: pinned to the right edge (M+ / dungeon only)
            if mode == "mythic_plus" or mode == "dungeon" then
                givesScoreHeader:ClearAllPoints()
                givesScoreHeader:SetPoint("TOPRIGHT", browserContent, "TOPRIGHT", 0, y - 16)
                givesScoreHeader:Show()
                givesScoreHeaderHitbox:ClearAllPoints()
                givesScoreHeaderHitbox:SetPoint("TOPRIGHT", browserContent, "TOPRIGHT", 0, y - 16)
                givesScoreHeaderHitbox:Show()
            else
                givesScoreHeader:Hide()
                givesScoreHeaderHitbox:Hide()
            end

            local endY = UpdateBrowserActivityButtons(y - 34)
            endY = UpdatePlayerMythicPlusRatingText(mode, endY - 2)
            local contentH = math.max(1, math.abs(endY) + 20)
            browserContent:SetHeight(contentH)
            browserFilterPanel:SetHeight(32 + contentH + 8)
        else
            activityDivider:Hide()
            activityHeader:Hide()
            playerMythicRatingText:Hide()
            activitySelectAllBtn:Hide()
            activitySelectNoneBtn:Hide()
            activitySelectBountifulBtn:Hide()
            givesScoreHeader:Hide()
            givesScoreHeaderHitbox:Hide()
            for _, button in ipairs(browserActivityButtons) do
                button:Hide()
                if button.text then button.text:Hide() end  -- text is child of browserContent, not button
                if button.scoreText then button.scoreText:Hide() end
                if button.scoreHitbox then button.scoreHitbox:Hide() end
            end
            local contentH = math.max(1, math.abs(y) + 20)
            browserContent:SetHeight(contentH)
            browserFilterPanel:SetHeight(32 + contentH + 8)
        end
    end
end

local bountifulWatcher = CreateFrame("Frame")
bountifulWatcher:RegisterEvent("AREA_POIS_UPDATED")
local bountifulRefreshPending = false
bountifulWatcher:SetScript("OnEvent", function()
    local filterPanelNeedsDelve = browserFilterPanel and browserFilterPanel:IsShown() and GetBrowserMode() == "delve"
    local browserNeedsDelve = addonTable.OAK_LFG
        and addonTable.OAK_LFG:IsShown()
        and addonTable.GetCurrentViewMode
        and addonTable.GetCurrentViewMode() == "browser"
        and GetBrowserMode() == "delve"

    if not filterPanelNeedsDelve and not browserNeedsDelve then
        return
    end

    if bountifulRefreshPending then
        return
    end
    bountifulRefreshPending = true

    C_Timer.After(0.2, function()
        bountifulRefreshPending = false

        local changed = false
        if addonTable.RefreshCurrentBountifulDelves then
            changed = addonTable.RefreshCurrentBountifulDelves()
        end
        if not changed then
            return
        end

        if addonTable.UpdateBrowserFilterPanel and browserFilterPanel and browserFilterPanel:IsShown() and GetBrowserMode() == "delve" then
            addonTable.UpdateBrowserFilterPanel()
        end
        if addonTable.UpdateDisplay and addonTable.OAK_LFG and addonTable.OAK_LFG:IsShown() and addonTable.GetCurrentViewMode and addonTable.GetCurrentViewMode() == "browser" and GetBrowserMode() == "delve" then
            addonTable.UpdateDisplay()
        end
    end)
end)

function addonTable.UpdateFilterPaneMode()
    local isBrowser = addonTable.GetCurrentViewMode and addonTable.GetCurrentViewMode() == "browser"
    if isBrowser then
        -- Hide the applicant filter panel; do NOT auto-show the browser filter panel.
        -- The user controls browser filter visibility via the Filters button.
        -- Content refresh is driven by the browserFilterPanel OnShow hook and the
        -- LFG_LIST_SEARCH_RESULTS_RECEIVED event hook below.
        filterPanel:Hide()
    else
        HideAllBrowserDropdowns()
        RestoreBrowserNativeSearchBox()
        browserFilterPanel:Hide()
    end
end

-- Filter panel re-layout after search results arrive is handled by
-- ScheduleSearchRefresh in Core.lua (called after FetchSearchResultData),
-- which ensures GetBrowserMode() returns the correct updated value.
-- A direct OnEvent hook here would fire before FetchSearchResultData runs
-- and would see stale mode/results.

function addonTable.BuildSidePanels()
-- Supporters Flyout Panel
local supportersPanel = CreateFrame("Frame", nil, OAK_LFG, "BackdropTemplate")
addonTable.SupportersPanel = supportersPanel
supportersPanel:SetSize(270, 390) 
supportersPanel:SetPoint("TOPLEFT", OAK_LFG, "TOPRIGHT", -2, 0)
supportersPanel:Hide()
supportersPanel:SetFrameLevel(OAK_LFG:GetFrameLevel() - 1) 
supportersPanel:SetBackdrop({
    bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, tile = false, edgeSize = 1, 
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
})
if addonTable.ApplyBackdropStyle then
    addonTable.ApplyBackdropStyle(supportersPanel, "panel")
end
supportersPanel:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
supportersPanel:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
supportersPanel:HookScript("OnShow", function()
    if addonTable.UpdateAuxPanelAnchors then
        addonTable.UpdateAuxPanelAnchors()
    end
    if addonTable.RefreshRIOAnchor then
        addonTable.RefreshRIOAnchor()
    elseif addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(addonTable.OAK_LFG)
    end
end)
supportersPanel:HookScript("OnHide", function()
    if addonTable.RefreshRIOAnchor then
        addonTable.RefreshRIOAnchor()
    elseif addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(addonTable.OAK_LFG)
    end
end)

local optionsPanel = CreateFrame("Frame", nil, OAK_LFG, "BackdropTemplate")
addonTable.OptionsPanel = optionsPanel
optionsPanel:SetSize(205, 640)
optionsPanel:SetPoint("TOPLEFT", OAK_LFG, "TOPRIGHT", -2, 0)
optionsPanel:Hide()
optionsPanel:SetFrameLevel(OAK_LFG:GetFrameLevel() - 1)
optionsPanel:SetBackdrop({
    bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, tile = false, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
})
if addonTable.ApplyBackdropStyle then
    addonTable.ApplyBackdropStyle(optionsPanel, "panel")
end
optionsPanel:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
optionsPanel:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
optionsPanel:HookScript("OnShow", function()
    if addonTable.UpdateAuxPanelAnchors then
        addonTable.UpdateAuxPanelAnchors()
    end
    if addonTable.RefreshRIOAnchor then
        addonTable.RefreshRIOAnchor()
    elseif addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(addonTable.OAK_LFG)
    end
end)
optionsPanel:HookScript("OnHide", function()
    if addonTable.RefreshRIOAnchor then
        addonTable.RefreshRIOAnchor()
    elseif addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(addonTable.OAK_LFG)
    end
end)

local optionsTitle = optionsPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontLarge")
optionsTitle:SetPoint("TOP", optionsPanel, "TOP", 0, -10)
optionsTitle:SetText(L["Options"])
optionsTitle:SetTextColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b)

local optionsRegionBox = CreateFrame("Button", nil, optionsPanel, "BackdropTemplate")
optionsRegionBox:SetSize(16, 16)
optionsRegionBox:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
optionsRegionBox:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, -42)
local optionsRegionLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
optionsRegionLabel:SetPoint("LEFT", optionsRegionBox, "RIGHT", 8, 0)
optionsRegionLabel:SetText(L["Show Regions"])
optionsRegionBox:SetScript("OnClick", ToggleSharedRegionSetting)
optionsRegionBox:SetScript("OnEnter", function(self)
    ApplySharedRegionToggleVisual(self, optionsRegionLabel, OakLFGSorterDB.showRegions == true)
    ShowRegionToggleTooltip(self)
end)
optionsRegionBox:SetScript("OnLeave", function()
    ApplySharedRegionToggleVisual(optionsRegionBox, optionsRegionLabel, OakLFGSorterDB.showRegions == true)
    GameTooltip:Hide()
end)

addonTable.OptionsRegionFlagsBox = CreateFrame("Button", nil, optionsPanel, "BackdropTemplate")
addonTable.OptionsRegionFlagsBox:SetSize(16, 16)
addonTable.OptionsRegionFlagsBox:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
addonTable.OptionsRegionFlagsBox:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 33, -64)
addonTable.OptionsRegionFlagsLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
addonTable.OptionsRegionFlagsLabel:SetPoint("LEFT", addonTable.OptionsRegionFlagsBox, "RIGHT", 8, 0)
addonTable.OptionsRegionFlagsLabel:SetText("Show Flags Instead of Tags")
addonTable.OptionsRegionFlagsBox:Hide()
addonTable.OptionsRegionFlagsLabel:Hide()

local optionsSpecBox = CreateFrame("Button", nil, optionsPanel, "BackdropTemplate")
optionsSpecBox:SetSize(16, 16)
optionsSpecBox:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
optionsSpecBox:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, -86)
local optionsSpecLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
optionsSpecLabel:SetPoint("LEFT", optionsSpecBox, "RIGHT", 8, 0)
optionsSpecLabel:SetText(L["Show Spec Icons"])

local optionsMinimapBox = CreateFrame("Button", nil, optionsPanel, "BackdropTemplate")
optionsMinimapBox:SetSize(16, 16)
optionsMinimapBox:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
optionsMinimapBox:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, -108)
local optionsMinimapLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
optionsMinimapLabel:SetPoint("LEFT", optionsMinimapBox, "RIGHT", 8, 0)
optionsMinimapLabel:SetText(L["Show Minimap Button"])

local optionsPartyKeysBox = CreateFrame("Button", nil, optionsPanel, "BackdropTemplate")
optionsPartyKeysBox:SetSize(16, 16)
optionsPartyKeysBox:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
optionsPartyKeysBox:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, -130)
local optionsPartyKeysLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
optionsPartyKeysLabel:SetPoint("LEFT", optionsPartyKeysBox, "RIGHT", 8, 0)
optionsPartyKeysLabel:SetText("Show Party Keys")

do
    local BROWSER_BINDING_COMMAND = "OAKLFGSORTER_TOGGLEBROWSER"
    local browserBindingCaptureActive = false
    local optionsKeybindLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    optionsKeybindLabel:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, -154)
    optionsKeybindLabel:SetText("Browser Keybind")

    local optionsKeybindValue = optionsPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
    optionsKeybindValue:SetPoint("TOPLEFT", optionsKeybindLabel, "BOTTOMLEFT", 0, -4)
    optionsKeybindValue:SetWidth(175)
    optionsKeybindValue:SetJustifyH("LEFT")
    optionsKeybindValue:SetJustifyV("TOP")
    optionsKeybindValue:SetTextColor(0.84, 0.84, 0.84)
    addonTable.OptionsKeybindValue = optionsKeybindValue

    local function FormatOakBindingText()
        local key1, key2 = GetBindingKey and GetBindingKey(BROWSER_BINDING_COMMAND)
        local formatted = {}

        local function FormatSingleBinding(binding)
            if not binding or binding == "" then
                return nil
            end

            local normalized = tostring(binding):upper()
            local tokens = {}
            for token in normalized:gmatch("[^-]+") do
                tokens[#tokens + 1] = token
            end

            if #tokens == 0 then
                return nil
            end

            local parts = {}
            for i = 1, #tokens - 1 do
                local token = tokens[i]
                if token == "C" or token == "CTRL" or token == "CONTROL" then
                    parts[#parts + 1] = "CTRL"
                elseif token == "A" or token == "ALT" then
                    parts[#parts + 1] = "ALT"
                elseif token == "S" or token == "SHIFT" then
                    parts[#parts + 1] = "SHIFT"
                end
            end

            local keyToken = tokens[#tokens]
            local keyText = (GetBindingText and GetBindingText(keyToken, "KEY_")) or keyToken
            if keyText and keyText ~= "" then
                parts[#parts + 1] = keyText
            end

            return table.concat(parts, " + ")
        end

        if key1 then
            formatted[#formatted + 1] = FormatSingleBinding(key1)
        end
        if key2 then
            formatted[#formatted + 1] = FormatSingleBinding(key2)
        end

        if #formatted == 0 then
            return "Not bound."
        end

        return table.concat(formatted, ", ")
    end

    local function StopBrowserBindingCapture()
        browserBindingCaptureActive = false
        optionsPanel:EnableKeyboard(false)
        optionsPanel:SetPropagateKeyboardInput(true)
    end

    local function SaveBrowserBinding(bindingKey)
        if InCombatLockdown and InCombatLockdown() then
            optionsKeybindValue:SetText("Cannot change bindings in combat.")
            StopBrowserBindingCapture()
            return
        end

        local old1, old2 = GetBindingKey(BROWSER_BINDING_COMMAND)
        if old1 then SetBinding(old1, nil) end
        if old2 then SetBinding(old2, nil) end
        if bindingKey and bindingKey ~= "" then
            SetBinding(bindingKey, BROWSER_BINDING_COMMAND)
        end

        SaveBindings(GetCurrentBindingSet())
        StopBrowserBindingCapture()
        if addonTable.RefreshOptionsPanel then
            addonTable.RefreshOptionsPanel()
        end
    end

    local function BuildCapturedBinding(key)
        if not key or key == "" then
            return nil
        end

        if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then
            return nil
        end

        local prefix = ""
        if IsControlKeyDown and IsControlKeyDown() and key ~= "LCTRL" and key ~= "RCTRL" then
            prefix = prefix .. "CTRL-"
        end
        if IsAltKeyDown and IsAltKeyDown() and key ~= "LALT" and key ~= "RALT" then
            prefix = prefix .. "ALT-"
        end
        if IsShiftKeyDown and IsShiftKeyDown() and key ~= "LSHIFT" and key ~= "RSHIFT" then
            prefix = prefix .. "SHIFT-"
        end

        return prefix .. key
    end

    local optionsSetBindButton = addonTable.CreateFlatButton(optionsPanel, "Set Key", 84)
    optionsSetBindButton:SetPoint("TOPLEFT", optionsKeybindValue, "BOTTOMLEFT", 0, -6)
    optionsSetBindButton:SetScript("OnClick", function()
        if InCombatLockdown and InCombatLockdown() then
            optionsKeybindValue:SetText("Cannot change bindings in combat.")
            return
        end

        browserBindingCaptureActive = true
        optionsPanel:EnableKeyboard(true)
        optionsPanel:SetPropagateKeyboardInput(false)
        optionsKeybindValue:SetText("Press a key combination. Esc cancels. Backspace clears.")
        if optionsSetBindButton.text then
            optionsSetBindButton.text:SetText("Press Key...")
        end
    end)
    optionsSetBindButton:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
        if not browserBindingCaptureActive then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText("Set Key", 1, 1, 1)
            GameTooltip:AddLine("Assign or replace Oak's browser toggle binding.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    optionsSetBindButton:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0, 0, 0, 1)
        GameTooltip:Hide()
    end)

    local optionsClearBindButton = addonTable.CreateFlatButton(optionsPanel, "Clear", 70)
    optionsClearBindButton:SetPoint("LEFT", optionsSetBindButton, "RIGHT", 6, 0)
    optionsClearBindButton:SetScript("OnClick", function()
        SaveBrowserBinding(nil)
    end)

    optionsPanel:SetPropagateKeyboardInput(true)
    optionsPanel:SetScript("OnKeyDown", function(_, key)
        if not browserBindingCaptureActive then
            return
        end

        if key == "ESCAPE" then
            StopBrowserBindingCapture()
            if addonTable.RefreshOptionsPanel then
                addonTable.RefreshOptionsPanel()
            end
            return
        end

        if key == "BACKSPACE" then
            SaveBrowserBinding(nil)
            return
        end

        local bindingKey = BuildCapturedBinding(key)
        if not bindingKey then
            optionsKeybindValue:SetText("Choose a non-modifier key.")
            return
        end

        SaveBrowserBinding(bindingKey)
    end)

    addonTable.FormatOakBindingText = FormatOakBindingText
    addonTable.IsBrowserBindingCaptureActive = function()
        return browserBindingCaptureActive
    end
    addonTable.OptionsSetBindButton = optionsSetBindButton
end

optionsPanel:HookScript("OnHide", function()
    optionsPanel:EnableKeyboard(false)
    optionsPanel:SetPropagateKeyboardInput(true)
end)

local function ApplySpecToggleVisual(button, label, isActive)
    if isActive then
        button:SetBackdropColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
        button:SetBackdropBorderColor(0, 0, 0, 1)
        label:SetTextColor(1, 1, 1)
    else
        button:SetBackdropColor(unpack(addonTable.OAK_COLOR_TOGGLE_OFF or addonTable.OAK_COLOR_PANE))
        button:SetBackdropBorderColor(addonTable.ClassColor.r * 0.65, addonTable.ClassColor.g * 0.65, addonTable.ClassColor.b * 0.65, 1)
        label:SetTextColor(0.84, 0.84, 0.84)
    end
end

local function ApplyMinimapToggleVisual(button, label, isActive)
    if isActive then
        button:SetBackdropColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
        button:SetBackdropBorderColor(0, 0, 0, 1)
        label:SetTextColor(1, 1, 1)
    else
        button:SetBackdropColor(unpack(addonTable.OAK_COLOR_TOGGLE_OFF or addonTable.OAK_COLOR_PANE))
        button:SetBackdropBorderColor(addonTable.ClassColor.r * 0.65, addonTable.ClassColor.g * 0.65, addonTable.ClassColor.b * 0.65, 1)
        label:SetTextColor(0.84, 0.84, 0.84)
    end
end

optionsSpecBox:SetScript("OnClick", function()
    OakLFGSorterDB.showSpecIcons = not OakLFGSorterDB.showSpecIcons
    if addonTable.UpdateDisplay then addonTable.UpdateDisplay() end
    if addonTable.OAK_SEARCH and addonTable.OAK_SEARCH.UpdateDisplay then addonTable.OAK_SEARCH:UpdateDisplay() end
    if addonTable.RefreshOptionsPanel then addonTable.RefreshOptionsPanel() end
    if addonTable.RefreshSearchOptionsPanel then addonTable.RefreshSearchOptionsPanel() end
end)
optionsSpecBox:SetScript("OnEnter", function(self)
    ApplySpecToggleVisual(self, optionsSpecLabel, OakLFGSorterDB.showSpecIcons == true)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(L["Show Spec Icons"], 1, 1, 1)
    GameTooltip:AddLine("Show specialization icons instead of abbreviated names in the applicant list.", 1, 1, 1, true)
    GameTooltip:Show()
end)
optionsSpecBox:SetScript("OnLeave", function()
    ApplySpecToggleVisual(optionsSpecBox, optionsSpecLabel, OakLFGSorterDB.showSpecIcons == true)
    GameTooltip:Hide()
end)

addonTable.OptionsRegionFlagsBox:SetScript("OnClick", addonTable.ToggleSharedRegionFlagsSetting)
addonTable.OptionsRegionFlagsBox:SetScript("OnEnter", function(self)
    local isActive = OakLFGSorterDB.showRegions == true and OakLFGSorterDB.showRegionFlags == true and addonTable.CanShowRegionFlags and addonTable.CanShowRegionFlags()
    ApplySharedRegionToggleVisual(self, addonTable.OptionsRegionFlagsLabel, isActive)
    addonTable.ShowRegionFlagsToggleTooltip(self)
end)
addonTable.OptionsRegionFlagsBox:SetScript("OnLeave", function()
    local isActive = OakLFGSorterDB.showRegions == true and OakLFGSorterDB.showRegionFlags == true and addonTable.CanShowRegionFlags and addonTable.CanShowRegionFlags()
    ApplySharedRegionToggleVisual(addonTable.OptionsRegionFlagsBox, addonTable.OptionsRegionFlagsLabel, isActive)
    GameTooltip:Hide()
end)

optionsMinimapBox:SetScript("OnClick", function()
    OakLFGSorterDB.hideMinimapButton = not OakLFGSorterDB.hideMinimapButton
    if addonTable.UpdateMinimapButtonVisibility then
        addonTable.UpdateMinimapButtonVisibility()
    end
    if addonTable.RefreshOptionsPanel then addonTable.RefreshOptionsPanel() end
end)
optionsMinimapBox:SetScript("OnEnter", function(self)
    ApplyMinimapToggleVisual(self, optionsMinimapLabel, not (OakLFGSorterDB and OakLFGSorterDB.hideMinimapButton == true))
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(L["Show Minimap Button"], 1, 1, 1)
    GameTooltip:AddLine("Show Oak's minimap button for quick access to the browser and options.", 1, 1, 1, true)
    GameTooltip:Show()
end)
optionsMinimapBox:SetScript("OnLeave", function()
    ApplyMinimapToggleVisual(optionsMinimapBox, optionsMinimapLabel, not (OakLFGSorterDB and OakLFGSorterDB.hideMinimapButton == true))
    GameTooltip:Hide()
end)

optionsPartyKeysBox:SetScript("OnClick", function()
    OakLFGSorterDB.showPartyKeys = not (OakLFGSorterDB.showPartyKeys == true)
    if addonTable.UpdatePartyKeysPanel then addonTable.UpdatePartyKeysPanel() end
    if addonTable.RefreshOptionsPanel then addonTable.RefreshOptionsPanel() end
end)
optionsPartyKeysBox:SetScript("OnEnter", function(self)
    ApplyMinimapToggleVisual(self, optionsPartyKeysLabel, OakLFGSorterDB.showPartyKeys == true)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Show Party Keys", 1, 1, 1)
    GameTooltip:AddLine("Show the Party Keys panel while browsing dungeons or listing groups.", 1, 1, 1, true)
    GameTooltip:Show()
end)
optionsPartyKeysBox:SetScript("OnLeave", function()
    ApplyMinimapToggleVisual(optionsPartyKeysBox, optionsPartyKeysLabel, OakLFGSorterDB.showPartyKeys == true)
    GameTooltip:Hide()
end)

local optionsStyleLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
optionsStyleLabel:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, -190)
optionsStyleLabel:SetText("Style")
optionsStyleButton, optionsStyleList = addonTable.CreateThemeStyleDropdown(optionsPanel, 170)
optionsStyleButton:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, -208)

local optionsThemeLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
optionsThemeLabel:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, -262)
optionsThemeLabel:SetText("Accent")
optionsThemeButton, optionsThemeList = addonTable.CreateThemeDropdown(optionsPanel, 112)
optionsThemeButton:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, -280)

optionsThemeColorButton = addonTable.CreateFlatButton(optionsPanel, "Color", 52)
optionsThemeColorButton:SetPoint("LEFT", optionsThemeButton, "RIGHT", 6, 0)
optionsThemeColorButton.swatch = optionsThemeColorButton:CreateTexture(nil, "ARTWORK")
optionsThemeColorButton.swatch:SetSize(12, 12)
optionsThemeColorButton.swatch:SetPoint("LEFT", optionsThemeColorButton, "LEFT", 6, 0)
optionsThemeColorButton.text:ClearAllPoints()
optionsThemeColorButton.text:SetPoint("LEFT", optionsThemeColorButton.swatch, "RIGHT", 5, 0)
optionsThemeColorButton.text:SetPoint("RIGHT", optionsThemeColorButton, "RIGHT", -4, 0)
optionsThemeColorButton.text:SetJustifyH("LEFT")
optionsThemeColorButton:SetScript("OnClick", function()
    if addonTable.OpenThemeColorPicker then
        addonTable.OpenThemeColorPicker()
    end
end)
optionsThemeColorButton:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Custom Theme Color", 1, 1, 1)
    GameTooltip:AddLine("Open a color picker and switch Oak's accent to a custom color.", 1, 1, 1, true)
    GameTooltip:Show()
end)
optionsThemeColorButton:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)

local optionsRegionFilterLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
optionsRegionFilterLabel:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, -290)
optionsRegionFilterLabel:SetText("Filter Regions")

local function CreateRegionFilterOption(parent, regionCode, xOffset, yOffset)
    local box = CreateFrame("Button", nil, parent, "BackdropTemplate")
    box:SetSize(16, 16)
    box:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)

    local meta = addonTable.GetRegionMeta and addonTable.GetRegionMeta(regionCode) or { shortLabel = regionCode, label = regionCode }
    local label = parent:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    label:SetPoint("LEFT", box, "RIGHT", 6, 0)
    label:SetText(meta.shortLabel or regionCode)

    box:SetScript("OnClick", function()
        ToggleSharedRegionFilter(regionCode)
    end)
    box:SetScript("OnEnter", function(self)
        ApplySharedRegionToggleVisual(self, label, addonTable.IsRegionEnabled and addonTable.IsRegionEnabled(regionCode))
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(meta.label or regionCode, 1, 1, 1)
        GameTooltip:AddLine("Toggle whether Oak shows listings from this region.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    box:SetScript("OnLeave", function()
        ApplySharedRegionToggleVisual(box, label, addonTable.IsRegionEnabled and addonTable.IsRegionEnabled(regionCode))
        GameTooltip:Hide()
    end)

    regionFilterButtons[regionCode] = box
    regionFilterLabels[regionCode] = label
end

do
    local regionOrder = addonTable.GetVisibleRegionFilterOrder and addonTable.GetVisibleRegionFilterOrder()
        or addonTable.GetRegionFilterOrder and addonTable.GetRegionFilterOrder()
        or {}
    for index, regionCode in ipairs(regionOrder) do
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        local xOffset = column == 0 and 15 or 105
        local yOffset = -310 - (row * 22)
        CreateRegionFilterOption(optionsPanel, regionCode, xOffset, yOffset)
    end
end
local optionsFontLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
optionsFontLabel:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, -470)
optionsFontLabel:SetText(L["Addon Font"])
local optionsFontButton, optionsFontList = addonTable.CreateFontDropdown(optionsPanel, 170)
optionsFontButton:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, -488)

local optionsFontSizeLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
optionsFontSizeLabel:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, -520)
optionsFontSizeLabel:SetText(L["Font Size"])
local optionsFontSizeValue = optionsPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
optionsFontSizeValue:SetPoint("RIGHT", optionsPanel, "TOPRIGHT", -15, -520)

local optionsFontSizeSlider = CreateFrame("Slider", nil, optionsPanel, "BackdropTemplate")
optionsFontSizeSlider:SetSize(170, 10)
optionsFontSizeSlider:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, -538)
optionsFontSizeSlider:SetMinMaxValues(10, 18)
optionsFontSizeSlider:SetValueStep(1)
optionsFontSizeSlider:SetObeyStepOnDrag(true)
optionsFontSizeSlider:SetOrientation("HORIZONTAL")
optionsFontSizeSlider:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
if addonTable.ApplyBackdropStyle then
    addonTable.ApplyBackdropStyle(optionsFontSizeSlider, "inset")
end
optionsFontSizeSlider:SetBackdropColor(unpack(addonTable.OAK_COLOR_SLIDER_TRACK or {0.05, 0.05, 0.05, 1}))
optionsFontSizeSlider:SetBackdropBorderColor(0, 0, 0, 1)
local optionsFontSizeThumb = optionsFontSizeSlider:CreateTexture(nil, "ARTWORK")
optionsFontSizeThumb:SetTexture(addonTable.FLAT_TEX)
do
    local accent = addonTable.GetThemeAccentColor and addonTable.GetThemeAccentColor(addonTable.GetThemePreset and addonTable.GetThemePreset() or nil) or addonTable.ClassColor
    optionsFontSizeThumb:SetVertexColor(accent.r, accent.g, accent.b, 1)
end
optionsFontSizeThumb:SetSize(10, 14)
optionsFontSizeSlider:SetThumbTexture(optionsFontSizeThumb)
if optionsFontSizeSlider.GetThumbTexture then
    local thumbTex = optionsFontSizeSlider:GetThumbTexture()
    if thumbTex then
        local accent = addonTable.GetThemeAccentColor and addonTable.GetThemeAccentColor(addonTable.GetThemePreset and addonTable.GetThemePreset() or nil) or addonTable.ClassColor
        thumbTex:SetVertexColor(accent.r, accent.g, accent.b, 1)
    end
end
optionsFontSizeSlider:SetScript("OnValueChanged", function(self, value)
    local rounded = math.floor((value or 12) + 0.5)
    optionsFontSizeValue:SetText(tostring(rounded))
    if addonTable.SetFontSize then
        addonTable.SetFontSize(rounded)
        addonTable.RefreshRegisteredFontDropdowns()
    end
end)
optionsFontSizeSlider:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Font Size", 1, 1, 1)
    GameTooltip:AddLine("Adjust the base Oak font size used throughout the addon.", 1, 1, 1, true)
    GameTooltip:Show()
end)
optionsFontSizeSlider:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
optionsFontSizeSlider:SetValue(addonTable.GetFontSize and addonTable.GetFontSize() or 12)

local optionsOpacityLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
optionsOpacityLabel:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, -570)
optionsOpacityLabel:SetText("Window Opacity")
local optionsOpacityValue = optionsPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
optionsOpacityValue:SetPoint("RIGHT", optionsPanel, "TOPRIGHT", -15, -570)

local optionsOpacitySlider = CreateFrame("Slider", nil, optionsPanel, "BackdropTemplate")
optionsOpacitySlider:SetSize(170, 10)
optionsOpacitySlider:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, -588)
optionsOpacitySlider:SetMinMaxValues(0.35, 1.0)
optionsOpacitySlider:SetValueStep(0.05)
optionsOpacitySlider:SetObeyStepOnDrag(true)
optionsOpacitySlider:SetOrientation("HORIZONTAL")
optionsOpacitySlider:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
if addonTable.ApplyBackdropStyle then
    addonTable.ApplyBackdropStyle(optionsOpacitySlider, "inset")
end
optionsOpacitySlider:SetBackdropColor(unpack(addonTable.OAK_COLOR_SLIDER_TRACK or {0.05, 0.05, 0.05, 1}))
optionsOpacitySlider:SetBackdropBorderColor(0, 0, 0, 1)
local optionsOpacityThumb = optionsOpacitySlider:CreateTexture(nil, "ARTWORK")
optionsOpacityThumb:SetTexture(addonTable.FLAT_TEX)
do
    local accent = addonTable.GetThemeAccentColor and addonTable.GetThemeAccentColor(addonTable.GetThemePreset and addonTable.GetThemePreset() or nil) or addonTable.ClassColor
    optionsOpacityThumb:SetVertexColor(accent.r, accent.g, accent.b, 1)
end
optionsOpacityThumb:SetSize(10, 14)
optionsOpacitySlider:SetThumbTexture(optionsOpacityThumb)
if optionsOpacitySlider.GetThumbTexture then
    local thumbTex = optionsOpacitySlider:GetThumbTexture()
    if thumbTex then
        local accent = addonTable.GetThemeAccentColor and addonTable.GetThemeAccentColor(addonTable.GetThemePreset and addonTable.GetThemePreset() or nil) or addonTable.ClassColor
        thumbTex:SetVertexColor(accent.r, accent.g, accent.b, 1)
    end
end
optionsOpacitySlider:SetScript("OnValueChanged", function(self, value)
    local rounded = math.floor(value * 100 + 0.5) / 100
    optionsOpacityValue:SetText(string.format("%d%%", rounded * 100))
    if addonTable.SetWindowOpacity then
        addonTable.SetWindowOpacity(rounded)
    end
end)
optionsOpacitySlider:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Window Opacity", 1, 1, 1)
    GameTooltip:AddLine("Adjust the background opacity used by Oak's windows and side panels.", 1, 1, 1, true)
    GameTooltip:Show()
end)
optionsOpacitySlider:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
optionsOpacitySlider:SetValue(addonTable.GetWindowOpacity and addonTable.GetWindowOpacity() or 0.85)

function addonTable.UpdateOptionsRegionLayout()
    local regionOrder = addonTable.GetVisibleRegionFilterOrder and addonTable.GetVisibleRegionFilterOrder()
        or addonTable.GetRegionFilterOrder and addonTable.GetRegionFilterOrder()
        or {}
    local regionRows = math.max(1, math.ceil(#regionOrder / 2))
    local regionStartY = -310
    local rowSpacing = 22
    local regionBottomY = regionStartY - ((regionRows - 1) * rowSpacing)

    for index, regionCode in ipairs(regionOrder) do
        local box = regionFilterButtons[regionCode]
        local label = regionFilterLabels[regionCode]
        if box and label then
            local column = (index - 1) % 2
            local row = math.floor((index - 1) / 2)
            local xOffset = column == 0 and 15 or 105
            local yOffset = regionStartY - (row * rowSpacing)
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", xOffset, yOffset)
            label:ClearAllPoints()
            label:SetPoint("LEFT", box, "RIGHT", 6, 0)
            box:Show()
            label:Show()
        end
    end

    for regionCode, box in pairs(regionFilterButtons) do
        local isVisible = false
        for _, visibleCode in ipairs(regionOrder) do
            if visibleCode == regionCode then
                isVisible = true
                break
            end
        end
        local label = regionFilterLabels[regionCode]
        if not isVisible then
            box:Hide()
            if label then
                label:Hide()
            end
        end
    end

    local fontTop = regionBottomY - 28
    optionsFontLabel:ClearAllPoints()
    optionsFontLabel:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, fontTop)
    optionsFontButton:ClearAllPoints()
    optionsFontButton:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, fontTop - 18)

    local fontSizeTop = fontTop - 50
    optionsFontSizeLabel:ClearAllPoints()
    optionsFontSizeLabel:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, fontSizeTop)
    optionsFontSizeValue:ClearAllPoints()
    optionsFontSizeValue:SetPoint("RIGHT", optionsPanel, "TOPRIGHT", -15, fontSizeTop)
    optionsFontSizeSlider:ClearAllPoints()
    optionsFontSizeSlider:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, fontSizeTop - 18)

    local opacityTop = fontSizeTop - 50
    optionsOpacityLabel:ClearAllPoints()
    optionsOpacityLabel:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, opacityTop)
    optionsOpacityValue:ClearAllPoints()
    optionsOpacityValue:SetPoint("RIGHT", optionsPanel, "TOPRIGHT", -15, opacityTop)
    optionsOpacitySlider:ClearAllPoints()
    optionsOpacitySlider:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 15, opacityTop - 18)

    local panelHeight = math.max(540, math.abs(opacityTop - 18) + 70)
    optionsPanel:SetHeight(panelHeight)
end

local function RefreshOptionsPanel()
    addonTable.UpdateOptionsRegionLayout()
    ApplySharedRegionToggleVisual(optionsRegionBox, optionsRegionLabel, OakLFGSorterDB.showRegions == true)
    do
        local canShowFlags = addonTable.CanShowRegionFlags and addonTable.CanShowRegionFlags()
        local showFlagsToggle = OakLFGSorterDB.showRegions == true and canShowFlags
        local isFlagsActive = showFlagsToggle and OakLFGSorterDB.showRegionFlags == true
        ApplySharedRegionToggleVisual(addonTable.OptionsRegionFlagsBox, addonTable.OptionsRegionFlagsLabel, isFlagsActive)
        if showFlagsToggle then
            addonTable.OptionsRegionFlagsBox:Show()
            addonTable.OptionsRegionFlagsLabel:Show()
            addonTable.OptionsRegionFlagsLabel:SetAlpha(1)
        else
            addonTable.OptionsRegionFlagsBox:Hide()
            addonTable.OptionsRegionFlagsLabel:Hide()
            if not canShowFlags then
                OakLFGSorterDB.showRegionFlags = false
            end
        end
    end
    ApplySpecToggleVisual(optionsSpecBox, optionsSpecLabel, OakLFGSorterDB.showSpecIcons == true)
    ApplyMinimapToggleVisual(optionsMinimapBox, optionsMinimapLabel, not (OakLFGSorterDB and OakLFGSorterDB.hideMinimapButton == true))
    ApplyMinimapToggleVisual(optionsPartyKeysBox, optionsPartyKeysLabel, OakLFGSorterDB.showPartyKeys == true)
    if addonTable.OptionsKeybindValue and not (addonTable.IsBrowserBindingCaptureActive and addonTable.IsBrowserBindingCaptureActive()) then
        local bindingText = addonTable.FormatOakBindingText and addonTable.FormatOakBindingText() or "Not bound."
        addonTable.OptionsKeybindValue:SetText(bindingText)
        if addonTable.OptionsSetBindButton and addonTable.OptionsSetBindButton.text then
            addonTable.OptionsSetBindButton.text:SetText(bindingText)
        end
    end

    if optionsStyleButton and optionsStyleButton.RefreshSelection then
        optionsStyleButton:RefreshSelection()
    end
    if optionsThemeButton and optionsThemeButton.RefreshSelection then
        optionsThemeButton:RefreshSelection()
    end
    if optionsThemeColorButton and optionsThemeColorButton.swatch and addonTable.GetThemeAccentColor then
        local color = addonTable.GetThemeAccentColor(addonTable.GetThemePreset and addonTable.GetThemePreset() or nil)
        optionsThemeColorButton.swatch:SetColorTexture(color.r, color.g, color.b, 1)
    end
    for _, regionCode in ipairs(addonTable.GetVisibleRegionFilterOrder and addonTable.GetVisibleRegionFilterOrder()
        or addonTable.GetRegionFilterOrder and addonTable.GetRegionFilterOrder()
        or {}) do
        ApplySharedRegionToggleVisual(regionFilterButtons[regionCode], regionFilterLabels[regionCode], addonTable.IsRegionEnabled and addonTable.IsRegionEnabled(regionCode))
    end
    if optionsFontButton and optionsFontButton.RefreshSelection then
        optionsFontButton:RefreshSelection()
    end
    if addonTable.GetFontSize then
        optionsFontSizeSlider:SetValue(addonTable.GetFontSize())
    end
    if addonTable.GetWindowOpacity then
        optionsOpacitySlider:SetValue(addonTable.GetWindowOpacity())
    end
    do
        local accent = addonTable.GetThemeAccentColor and addonTable.GetThemeAccentColor(addonTable.GetThemePreset and addonTable.GetThemePreset() or nil) or addonTable.ClassColor
        optionsFontSizeThumb:SetVertexColor(accent.r, accent.g, accent.b, 1)
        optionsOpacityThumb:SetVertexColor(accent.r, accent.g, accent.b, 1)
        if optionsFontSizeSlider.GetThumbTexture then
            local thumbTex = optionsFontSizeSlider:GetThumbTexture()
            if thumbTex then
                thumbTex:SetVertexColor(accent.r, accent.g, accent.b, 1)
            end
        end
        if optionsOpacitySlider.GetThumbTexture then
            local thumbTex = optionsOpacitySlider:GetThumbTexture()
            if thumbTex then
                thumbTex:SetVertexColor(accent.r, accent.g, accent.b, 1)
            end
        end
    end
end

addonTable.RefreshOptionsPanel = RefreshOptionsPanel

addonTable.OptionsBindingsEventFrame = CreateFrame("Frame")
addonTable.OptionsBindingsEventFrame:RegisterEvent("UPDATE_BINDINGS")
addonTable.OptionsBindingsEventFrame:SetScript("OnEvent", function()
    if addonTable.RefreshOptionsPanel then
        addonTable.RefreshOptionsPanel()
    end
end)

addonTable.RegisterThemeRefresh("ui_filters_theme", function()
    if addonTable.ApplyBackdropStyle then
        addonTable.ApplyBackdropStyle(filterPanel, "panel")
        addonTable.ApplyBackdropStyle(browserFilterPanel, "panel")
        addonTable.ApplyBackdropStyle(supportersPanel, "panel")
        addonTable.ApplyBackdropStyle(optionsPanel, "panel")
        if addonTable.SupportersFontPickerList then
            addonTable.ApplyBackdropStyle(addonTable.SupportersFontPickerList, "panel")
        end
    end
    filterPanel:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    browserFilterPanel:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    supportersPanel:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    optionsPanel:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    if addonTable.SupportersFontPickerList then
        addonTable.SupportersFontPickerList:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    end
    if addonTable.FilterClassDivider then
        addonTable.FilterClassDivider:SetColorTexture(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 0.5)
    end
    if addonTable.FilterBottomDivider then
        addonTable.FilterBottomDivider:SetColorTexture(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 0.35)
    end
    local accent = addonTable.GetThemeAccentColor and addonTable.GetThemeAccentColor(addonTable.GetThemePreset and addonTable.GetThemePreset() or nil) or addonTable.ClassColor
    optionsTitle:SetTextColor(accent.r, accent.g, accent.b)
    if addonTable.SupportersTitle then
        addonTable.SupportersTitle:SetTextColor(accent.r, accent.g, accent.b)
    end
    optionsFontSizeThumb:SetVertexColor(accent.r, accent.g, accent.b, 1)
    optionsOpacityThumb:SetVertexColor(accent.r, accent.g, accent.b, 1)
    if addonTable.ApplyBackdropStyle then
        addonTable.ApplyBackdropStyle(optionsFontSizeSlider, "inset")
        addonTable.ApplyBackdropStyle(optionsOpacitySlider, "inset")
    end
    optionsFontSizeSlider:SetBackdropColor(unpack(addonTable.OAK_COLOR_SLIDER_TRACK or {0.05, 0.05, 0.05, 1}))
    optionsOpacitySlider:SetBackdropColor(unpack(addonTable.OAK_COLOR_SLIDER_TRACK or {0.05, 0.05, 0.05, 1}))
    optionsFontSizeSlider:SetBackdropBorderColor(accent.r, accent.g, accent.b, 1)
    optionsOpacitySlider:SetBackdropBorderColor(accent.r, accent.g, accent.b, 1)
    if optionsFontSizeSlider.GetThumbTexture then
        local thumbTex = optionsFontSizeSlider:GetThumbTexture()
        if thumbTex then
            thumbTex:SetVertexColor(accent.r, accent.g, accent.b, 1)
        end
    end
    if optionsOpacitySlider.GetThumbTexture then
        local thumbTex = optionsOpacitySlider:GetThumbTexture()
        if thumbTex then
            thumbTex:SetVertexColor(accent.r, accent.g, accent.b, 1)
        end
    end
    if optionsThemeColorButton and optionsThemeColorButton.swatch and addonTable.GetThemeAccentColor then
        local color = addonTable.GetThemeAccentColor(addonTable.GetThemePreset and addonTable.GetThemePreset() or nil)
        optionsThemeColorButton.swatch:SetColorTexture(color.r, color.g, color.b, 1)
    end
    if addonTable.FilterTitle then
        addonTable.FilterTitle:SetTextColor(accent.r, accent.g, accent.b)
    end
    if addonTable.BrowserFilterTitle then
        addonTable.BrowserFilterTitle:SetTextColor(accent.r, accent.g, accent.b)
    end
    browserMinRatingLabel:SetTextColor(accent.r, accent.g, accent.b)
    for _, row in pairs(raidRangeRows) do
        if row and row.label then
            row.label:SetTextColor(accent.r, accent.g, accent.b)
        end
    end
    if addonTable.FilterQuickDivider then
        addonTable.FilterQuickDivider:SetColorTexture(accent.r, accent.g, accent.b, 0.5)
    end
    RefreshOptionsPanel()
end)

function addonTable.ToggleOptionsPanel()
    if optionsPanel:IsShown() then
        optionsPanel:Hide()
    else
        if addonTable.FilterPanel then addonTable.FilterPanel:Hide() end
        if addonTable.BrowserFilterPanel then addonTable.BrowserFilterPanel:Hide() end
        if addonTable.SupportersPanel then addonTable.SupportersPanel:Hide() end
        HideAllBrowserDropdowns()
        RefreshOptionsPanel()
        optionsPanel:Show()
    end
    if addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(addonTable.OAK_LFG)
    end
end

local function OpenOakOptionsFromBlizzard()
    if SettingsPanel and SettingsPanel:IsShown() then
        HideUIPanel(SettingsPanel)
    elseif InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
        HideUIPanel(InterfaceOptionsFrame)
    end

    if addonTable.OpenOakOptions then
        addonTable.OpenOakOptions()
    elseif addonTable.OpenOakBrowser then
        addonTable.OpenOakBrowser()
        if addonTable.ToggleOptionsPanel and not (addonTable.OptionsPanel and addonTable.OptionsPanel:IsShown()) then
            addonTable.ToggleOptionsPanel()
        end
    end
end

do
    local settingsFrame = CreateFrame("Frame", "OakLFGSorterBlizzardOptionsPanel")
    settingsFrame.name = "OAK LFG Sorter"

    local title = settingsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("OAK LFG Sorter")

    local description = settingsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetText("Open Oak's in-window options panel.")

    local openButton = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
    openButton:SetSize(180, 24)
    openButton:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -14)
    openButton:SetText("Open Oak Options")
    openButton:SetScript("OnClick", OpenOakOptionsFromBlizzard)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(settingsFrame, settingsFrame.name, settingsFrame.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(settingsFrame)
    end
end

if addonTable.ApplyWindowOpacity then
    addonTable.ApplyWindowOpacity()
end

do
local suppTitle = supportersPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontLarge")
addonTable.SupportersTitle = suppTitle
suppTitle:SetPoint("TOP", supportersPanel, "TOP", 0, -10)
suppTitle:SetText("")
suppTitle:SetTextColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b)

local fontPickerLabel = supportersPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
fontPickerLabel:SetPoint("TOPLEFT", supportersPanel, "TOPLEFT", 15, -330)
fontPickerLabel:SetText("Addon Font")
fontPickerLabel:SetTextColor(1, 1, 1)
fontPickerLabel:Hide()

local suppScroll = CreateFrame("ScrollFrame", "OakLFGSupportersScroll", supportersPanel, "UIPanelScrollFrameTemplate")
suppScroll:SetPoint("TOPLEFT", supportersPanel, "TOPLEFT", 10, -12)
suppScroll:SetPoint("BOTTOMRIGHT", supportersPanel, "BOTTOMRIGHT", -25, 118) 

local suppScrollBar = _G[suppScroll:GetName() .. "ScrollBar"]
if suppScrollBar then
    local upBtn = _G[suppScroll:GetName() .. "ScrollBarScrollUpButton"]
    local downBtn = _G[suppScroll:GetName() .. "ScrollBarScrollDownButton"]
    if upBtn then upBtn:Hide(); upBtn:SetSize(0.1, 0.1) end
    if downBtn then downBtn:Hide(); downBtn:SetSize(0.1, 0.1) end

    local topTex = _G[suppScroll:GetName() .. "ScrollBarTop"]
    local bottomTex = _G[suppScroll:GetName() .. "ScrollBarBottom"]
    local midTex = _G[suppScroll:GetName() .. "ScrollBarMiddle"]
    if topTex then topTex:Hide() end
    if bottomTex then bottomTex:Hide() end
    if midTex then midTex:Hide() end
    
    local thumb = suppScrollBar:GetThumbTexture()
    if thumb then
        thumb:SetTexture(addonTable.FLAT_TEX)
        thumb:SetVertexColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1) 
        thumb:SetSize(8, 60)
    end
    suppScrollBar:SetWidth(8)
end

local suppScrollChild = CreateFrame("Frame")
suppScrollChild:SetSize(suppScroll:GetWidth(), 1)
suppScroll:SetScrollChild(suppScrollChild)

local supporterNames = addonTable.Patreons or {}
local topSupporters = {}
local generalSupporters = {}

for _, name in ipairs(supporterNames) do
    if name == "Mandos" then
        topSupporters[#topSupporters + 1] = name
    else
        generalSupporters[#generalSupporters + 1] = name
    end
end

local topSectionLabel = suppScrollChild:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
topSectionLabel:SetPoint("TOP", suppScrollChild, "TOP", 0, 0)
topSectionLabel:SetText("Top Supporters")
topSectionLabel:SetTextColor(0.96, 0.82, 0.36)

local function CreateRainbowSupporterLine(parent, text, xOffset, yOffset)
    local colors = {
        { 0.96, 0.82, 0.36 },
        { 0.53, 0.67, 0.99 },
        { 0.73, 0.56, 0.97 },
        { 0.49, 0.83, 1.00 },
        { 0.93, 0.41, 0.71 },
        { 0.76, 0.93, 0.45 },
    }
    local previous
    for index = 1, #text do
        local letter = text:sub(index, index)
        local fs = parent:CreateFontString(nil, "OVERLAY", "OakLFG_FontLarge")
        if previous then
            fs:SetPoint("LEFT", previous, "RIGHT", 0, 0)
        else
            fs:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
        end
        fs:SetText(letter)
        local color = colors[((index - 1) % #colors) + 1]
        fs:SetTextColor(color[1], color[2], color[3])
        previous = fs
    end
end

local topYOffset = -18
for _, name in ipairs(topSupporters) do
    CreateRainbowSupporterLine(suppScrollChild, name, 6, topYOffset)
    topYOffset = topYOffset - 22
end

local divider = suppScrollChild:CreateTexture(nil, "ARTWORK")
divider:SetColorTexture(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 0.35)
divider:SetSize(218, 1)
divider:SetPoint("TOPLEFT", suppScrollChild, "TOPLEFT", 6, topYOffset)

local supportersLabel = suppScrollChild:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
supportersLabel:SetPoint("TOP", divider, "BOTTOM", 0, -10)
supportersLabel:SetText("Supporters")
supportersLabel:SetTextColor(0.84, 0.84, 0.84)

local listStartY = topYOffset - 24
local supporterCount = #generalSupporters
local supporterRows = math.max(1, math.ceil(supporterCount / 2))
local columnWidth = 112
local rowHeight = 18

for index, name in ipairs(generalSupporters) do
    local pt = suppScrollChild:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    local column = math.floor((index - 1) / supporterRows)
    local row = (index - 1) % supporterRows
    pt:SetPoint("TOPLEFT", suppScrollChild, "TOPLEFT", 6 + (column * columnWidth), listStartY - (row * rowHeight))
    pt:SetWidth(columnWidth - 6)
    pt:SetJustifyH("LEFT")
    pt:SetText(name)
    pt:SetTextColor(0.8, 0.8, 0.8)
end
suppScrollChild:SetHeight(math.max(1, math.abs(listStartY) + (supporterRows * rowHeight) + 4))

local socialY = -236
if addonTable.Socials then
    for _, social in ipairs(addonTable.Socials) do
        local btn = addonTable.CreateFlatButton(supportersPanel, social.name, 170)
        btn:SetPoint("TOP", supportersPanel, "TOP", 0, socialY)
        btn:SetScript("OnClick", function()
            StaticPopup_Show("OAK_LFG_URL_COPY", "", "", social.url)
        end)
        socialY = socialY - 25
    end
end

local fontPickerButton = addonTable.CreateFlatButton(supportersPanel, addonTable.GetActiveFontName and addonTable.GetActiveFontName() or "OakUI Font", 170)
fontPickerButton:SetPoint("TOP", supportersPanel, "TOP", 0, -300)
fontPickerButton:Hide()

local fontPickerList = CreateFrame("Frame", nil, supportersPanel, "BackdropTemplate")
addonTable.SupportersFontPickerList = fontPickerList
fontPickerList:SetWidth(170)
fontPickerList:SetBackdrop({
    bgFile = addonTable.FLAT_TEX,
    edgeFile = addonTable.FLAT_TEX,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
fontPickerList:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
fontPickerList:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
fontPickerList:SetFrameStrata("FULLSCREEN_DIALOG")
fontPickerList:SetFrameLevel(supportersPanel:GetFrameLevel() + 20)
fontPickerList:Hide()

local fontPickerButtons = {}
local function RefreshFontPickerOptions()
    local fontNames = addonTable.GetAvailableFontNames and addonTable.GetAvailableFontNames() or { "OakUI Font" }
    fontPickerList:SetHeight((math.min(#fontNames, 8) * 22) + 2)
    for _, button in ipairs(fontPickerButtons) do
        button:Hide()
    end

    for index, fontName in ipairs(fontNames) do
        local optionButton = fontPickerButtons[index]
        if not optionButton then
            optionButton = CreateFrame("Button", nil, fontPickerList, "BackdropTemplate")
            optionButton.bg = optionButton:CreateTexture(nil, "BACKGROUND")
            optionButton.bg:SetAllPoints()
            optionButton.text = optionButton:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
            optionButton.text:SetPoint("LEFT", optionButton, "LEFT", 8, 0)
            optionButton.text:SetPoint("RIGHT", optionButton, "RIGHT", -8, 0)
            optionButton.text:SetJustifyH("LEFT")
            fontPickerButtons[index] = optionButton
        end

        optionButton:ClearAllPoints()
        optionButton:SetPoint("TOPLEFT", fontPickerList, "TOPLEFT", 1, -((index - 1) * 22) - 1)
        optionButton:SetSize(158, 22)
        optionButton.bg:SetColorTexture(unpack(addonTable.OAK_COLOR_BG))
        optionButton.text:SetText(fontName)
        optionButton:SetScript("OnClick", function()
            if addonTable.SetActiveFont then
                addonTable.SetActiveFont(fontName)
            end
            fontPickerButton.text:SetText(fontName)
            fontPickerList:Hide()
        end)
        optionButton:Show()
    end
end

fontPickerButton:SetScript("OnClick", function(self)
    RefreshFontPickerOptions()
    if fontPickerList:IsShown() then
        fontPickerList:Hide()
    else
        fontPickerList:ClearAllPoints()
        fontPickerList:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -1)
        fontPickerList:Show()
    end
end)
fontPickerButton:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Addon Font", 1, 1, 1)
    GameTooltip:AddLine("Choose which SharedMedia font Oak uses for its custom text.", 1, 1, 1, true)
    GameTooltip:Show()
end)
fontPickerButton:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)
end
end

toggleFiltersBtn:SetScript("OnClick", function()
    local isBrowser = addonTable.GetCurrentViewMode and addonTable.GetCurrentViewMode() == "browser"
    local activePanel = isBrowser and browserFilterPanel or filterPanel
    local inactivePanel = isBrowser and filterPanel or browserFilterPanel

    if activePanel:IsShown() then
        activePanel:Hide()
        HideAllBrowserDropdowns()
    else
        if addonTable.UpdateFilterPaneMode then
            addonTable.UpdateFilterPaneMode()
        end
        if addonTable.SupportersPanel then addonTable.SupportersPanel:Hide() end
        if addonTable.OptionsPanel then addonTable.OptionsPanel:Hide() end
        inactivePanel:Hide()
        activePanel:Show()
    end
    if addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(addonTable.OAK_LFG)
    end
end)

SyncSharedRegionToggleBoxes()

local lfgToggleBox
function addonTable.SetupBlizzardLFGHook()
    if LFGListFrame and LFGListFrame.ApplicationViewer then
        if not lfgToggleBox then
            lfgToggleBox = CreateFrame("Button", nil, LFGListFrame.ApplicationViewer, "BackdropTemplate")
            addonTable.LFGToggleBox = lfgToggleBox
            lfgToggleBox:SetSize(16, 16)
            lfgToggleBox:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
            lfgToggleBox:SetBackdropBorderColor(0, 0, 0, 1)
            
            if LFGListFrame.ApplicationViewer.NameColumnHeader then
                lfgToggleBox:SetPoint("BOTTOMLEFT", LFGListFrame.ApplicationViewer.NameColumnHeader, "TOPLEFT", 15, 15)
            else
                lfgToggleBox:SetPoint("TOPLEFT", LFGListFrame.ApplicationViewer, "TOPLEFT", 25, 5)
            end
            
            local text = LFGListFrame.ApplicationViewer:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
            text:SetPoint("LEFT", lfgToggleBox, "RIGHT", 8, 0)
            text:SetText(L["Auto-Open Sorter"])
            
            lfgToggleBox:SetScript("OnClick", function(self)
                OakLFGSorterDB.autoOpen = not OakLFGSorterDB.autoOpen
                if OakLFGSorterDB.autoOpen then
                    self:SetBackdropColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1) 
                    self:SetBackdropBorderColor(0, 0, 0, 1)
                    OAK_LFG:Show()
                else
                    self:SetBackdropColor(0.08, 0.08, 0.10, 0.95) 
                    self:SetBackdropBorderColor(addonTable.ClassColor.r * 0.65, addonTable.ClassColor.g * 0.65, addonTable.ClassColor.b * 0.65, 1)
                    OAK_LFG:Hide()
                end
            end)
            
            if OakLFGSorterDB.autoOpen then
                lfgToggleBox:SetBackdropColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
                lfgToggleBox:SetBackdropBorderColor(0, 0, 0, 1)
            else
                lfgToggleBox:SetBackdropColor(0.08, 0.08, 0.10, 0.95)
                lfgToggleBox:SetBackdropBorderColor(addonTable.ClassColor.r * 0.65, addonTable.ClassColor.g * 0.65, addonTable.ClassColor.b * 0.65, 1)
            end

            LFGListFrame.ApplicationViewer:HookScript("OnShow", function()
                if OakLFGSorterDB and OakLFGSorterDB.autoOpen then OAK_LFG:Show() end
            end)
        end
    end

    if LFGListFrame and LFGListFrame.SearchPanel and not addonTable.SearchPanelHooked then
        addonTable.SearchPanelHooked = true
        LFGListFrame.SearchPanel:HookScript("OnShow", function()
            if OakLFGSorterDB and OakLFGSorterDB.autoOpen and not addonTable.userExplicitlyClosed then
                OAK_LFG:Show()
            end
        end)
        LFGListFrame.SearchPanel:HookScript("OnHide", function()
            -- Preserve the user's explicit close preference; do not force-reset it here.
        end)
    end
end

addonTable.UpdateTopBarLayout()
addonTable.UpdateTopBarActions()
