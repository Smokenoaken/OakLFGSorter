local addonName, addonTable = ...
local OAK_LFG = addonTable.OAK_LFG

local function ShouldMuteApplicantPing()
    if not OakLFGSorterDB or not OakLFGSorterDB.muteApplicantPing then
        return false
    end

    if not OAK_LFG or not OAK_LFG:IsShown() then
        return false
    end

    return not (PVEFrame and PVEFrame:IsShown())
end

local applicantPingWrapped = false
local originalApplicantPingOnPlay = nil
local originalApplicantPingOnLoop = nil

local function CreateApplicantPingHandler(originalHandler)
    return function(...)
        if ShouldMuteApplicantPing() then
            return
        end

        if originalHandler then
            return originalHandler(...)
        end

        if SOUNDKIT and SOUNDKIT.UI_GROUP_FINDER_RECEIVE_APPLICATION then
            PlaySound(SOUNDKIT.UI_GROUP_FINDER_RECEIVE_APPLICATION, "master")
        end
    end
end

local function SetupApplicantPingMuteHook()
    if applicantPingWrapped or not QueueStatusButton or not QueueStatusButton.EyeHighlightAnim then
        return
    end

    applicantPingWrapped = true
    originalApplicantPingOnPlay = QueueStatusButton.EyeHighlightAnim:GetScript("OnPlay")
    originalApplicantPingOnLoop = QueueStatusButton.EyeHighlightAnim:GetScript("OnLoop")

    QueueStatusButton.EyeHighlightAnim:SetScript("OnPlay", CreateApplicantPingHandler(originalApplicantPingOnPlay))
    QueueStatusButton.EyeHighlightAnim:SetScript("OnLoop", CreateApplicantPingHandler(originalApplicantPingOnLoop))
end

local function GetActiveListingActivityID()
    local entryInfo = C_LFGList.GetActiveEntryInfo()
    if not entryInfo then
        return nil, nil
    end

    local activityID = tonumber(entryInfo.activityID)
    if not activityID and securecallfunction then
        activityID = securecallfunction(function(info)
            local ids = info and info.activityIDs
            local firstID = type(ids) == "table" and ids[1] or nil
            return tonumber(firstID)
        end, entryInfo)
    end
    if activityID == 0 then
        activityID = nil
    end

    return activityID, entryInfo
end

local function GetListingMode(activityInfo)
    if not activityInfo then
        return "generic"
    end

    local delveLookup = {
        ["atal'aman"] = true,
        ["collegiate calamity"] = true,
        ["parhelion plaza"] = true,
        ["shadowguard point"] = true,
        ["sunkiller sanctum"] = true,
        ["the darkway"] = true,
        ["the grudge pit"] = true,
        ["the gulf of memory"] = true,
        ["the shadow enclave"] = true,
        ["torment's rise"] = true,
        ["twilight crypts"] = true,
    }
    local fullName = strlower(activityInfo.fullName or "")
    local shortName = strlower(activityInfo.shortName or "")
    local cleanFullName = strlower(tostring(activityInfo.fullName or ""):gsub("%s*%(.+%)", ""))
    local cleanShortName = strlower(tostring(activityInfo.shortName or ""):gsub("%s*%(.+%)", ""))
    local activityText = fullName .. " " .. shortName
    local maxPlayers = tonumber(activityInfo.maxNumPlayers or activityInfo.maxPlayers) or 0

    if activityInfo.isMythicPlusActivity then
        return "mythic_plus"
    elseif activityInfo.isRatedPvpActivity then
        return "rated_pvp"
    elseif activityInfo.isPvpActivity then
        return "pvp"
    elseif activityInfo.isCurrentRaidActivity then
        return "raid"
    elseif activityText:find("legacy", 1, true) and activityText:find("raid", 1, true) then
        return "legacy_raid"
    elseif activityText:find("delve", 1, true) or delveLookup[cleanFullName] or delveLookup[cleanShortName] then
        return "delve"
    elseif activityText:find("world", 1, true) or activityText:find("outdoor", 1, true) then
        return "open_world"
    elseif maxPlayers > 0 and maxPlayers <= 5 then
        if activityText:find("mythic", 1, true) or activityText:find("heroic", 1, true) or activityText:find("normal", 1, true) then
            return "dungeon"
        end
    end

    return "generic"
end

local GetPvpBracketLabel

function addonTable.UpdateListingContext()
    local activityID, entryInfo = GetActiveListingActivityID()
    local activityInfo = activityID and C_LFGList.GetActivityInfoTable(activityID) or nil

    addonTable.CurrentListingContext = {
        activityID = activityID,
        entryInfo = entryInfo,
        activityInfo = activityInfo,
        mode = GetListingMode(activityInfo),
    }

    return addonTable.CurrentListingContext
end

addonTable.SearchResults = addonTable.SearchResults or {}
addonTable.CurrentSearchContext = addonTable.CurrentSearchContext or { mode = "generic" }
addonTable.SearchApplications = addonTable.SearchApplications or {}

local function NormalizeApplicationStatus(status)
    return strlower(tostring(status or "none"))
end

local function IsAppliedStatus(status)
    status = NormalizeApplicationStatus(status)
    return status == "applied" or status == "invited" or status == "inviteaccepted" or status == "pending"
end

local function IsDeclinedStatus(status)
    status = NormalizeApplicationStatus(status)
    return status:find("declined", 1, true) ~= nil or status:find("cancelled", 1, true) ~= nil or status:find("failed", 1, true) ~= nil or status == "none" and false
end

addonTable.NormalizeApplicationStatus = NormalizeApplicationStatus
addonTable.IsAppliedStatus = IsAppliedStatus
addonTable.IsDeclinedStatus = IsDeclinedStatus

local function GetSearchResultActivityID(resultInfo)
    if not resultInfo then
        return nil
    end

    local activityID = tonumber(resultInfo.activityID)
    if not activityID and securecallfunction then
        activityID = securecallfunction(function(info)
            local ids = info and info.activityIDs
            local firstID = type(ids) == "table" and ids[1] or nil
            return tonumber(firstID)
        end, resultInfo)
    end
    if activityID == 0 then
        activityID = nil
    end

    return activityID
end

local function ParseResultKeyLevel(resultInfo, activityInfo)
    local combined = table.concat({
        tostring(resultInfo and resultInfo.name or ""),
        tostring(resultInfo and resultInfo.comment or ""),
        tostring(activityInfo and activityInfo.shortName or ""),
        tostring(activityInfo and activityInfo.fullName or ""),
    }, " ")
    local lowerText = strlower(combined)

    local plusLevel = lowerText:match("%+(%d%d?)")
    if plusLevel then
        return tonumber(plusLevel) or 0
    end

    local leadingLevel = lowerText:match("^%s*%+?(%d%d?)%s")
    if leadingLevel then
        return tonumber(leadingLevel) or 0
    end

    return 0
end

local function BuildResultDisplayName(resultInfo, activityInfo, keyLevel)
    local rawName = tostring(resultInfo and resultInfo.name or "")
    rawName = rawName:gsub("^%s+", ""):gsub("%s+$", "")

    local activityLabel = ""
    if activityInfo then
        activityLabel = activityInfo.fullName or activityInfo.shortName or ""
    end

    if rawName == "" then
        if keyLevel > 0 and activityLabel ~= "" then
            return string.format("+%d %s", keyLevel, activityLabel)
        end
        return activityLabel ~= "" and activityLabel or "--"
    end

    local digitsOnly = rawName:match("^%+?(%d%d?)$")
    if digitsOnly then
        if activityLabel ~= "" then
            return string.format("+%s %s", digitsOnly, activityLabel)
        end
        return "+" .. digitsOnly
    end

    return rawName
end

local function CleanActivityLabel(label)
    label = tostring(label or "")
    label = label:gsub("%s*%b()", "")
    label = label:gsub("^%s+", ""):gsub("%s+$", "")
    return label
end

local function GetSearchResultActivityFilterLabel(activityInfo, listingMode)
    if not activityInfo then
        return ""
    end

    if listingMode == "mythic_plus" or listingMode == "delve" or listingMode == "generic" then
        return CleanActivityLabel(activityInfo.fullName or activityInfo.shortName or "")
    end

    if listingMode == "raid" or listingMode == "legacy_raid" then
        return CleanActivityLabel(activityInfo.fullName or activityInfo.shortName or "")
    end

    return CleanActivityLabel(activityInfo.fullName or activityInfo.shortName or "")
end

local function GetSearchResultPlayers(searchResultID, numMembers)
    local players = {}

    for memberIndex = 1, numMembers or 0 do
        local success, role, classFile = pcall(C_LFGList.GetSearchResultMemberInfo, searchResultID, memberIndex)
        if success and classFile then
            if role ~= "TANK" and role ~= "HEALER" then
                role = "DAMAGER"
            end

            table.insert(players, {
                role = role,
                class = classFile or "UNKNOWN",
            })
        end
    end

    return players
end

local function NormalizeApplicantRole(tank, healer, specID)
    if tank then
        return "TANK"
    end
    if healer then
        return "HEALER"
    end
    if specID and GetSpecializationRoleByID then
        local specRole = GetSpecializationRoleByID(specID)
        if specRole == "TANK" or specRole == "HEALER" then
            return specRole
        end
    end
    return "DAMAGER"
end

local function GetSearchResultRoleCounts(searchResultID)
    local counts = { TANK = 0, HEALER = 0, DAMAGER = 0 }
    if not (C_LFGList and C_LFGList.GetSearchResultMemberCounts) then
        return counts
    end

    local success, memberCounts = pcall(C_LFGList.GetSearchResultMemberCounts, searchResultID)
    if success and type(memberCounts) == "table" then
        counts.TANK = tonumber(memberCounts.TANK) or 0
        counts.HEALER = tonumber(memberCounts.HEALER) or 0
        counts.DAMAGER = tonumber(memberCounts.DAMAGER) or 0
    end

    return counts
end

local function BuildSearchApplicationState()
    wipe(addonTable.SearchApplications)
    if not (C_LFGList and C_LFGList.GetApplications and C_LFGList.GetApplicationInfo) then
        return
    end

    local applicationIDs = C_LFGList.GetApplications()
    if type(applicationIDs) ~= "table" then
        return
    end

    for _, searchResultID in ipairs(applicationIDs) do
        local success, appA, appB = pcall(C_LFGList.GetApplicationInfo, searchResultID)
        if success then
            if type(appA) == "table" then
                addonTable.SearchApplications[searchResultID] = NormalizeApplicationStatus(appA.applicationStatus or appA.status or appA.pendingStatus or "none")
            elseif type(appB) == "string" then
                addonTable.SearchApplications[searchResultID] = NormalizeApplicationStatus(appB)
            elseif type(appA) == "string" then
                addonTable.SearchApplications[searchResultID] = NormalizeApplicationStatus(appA)
            end
        end
    end
end

local function SummarizeSearchResultPlayers(players)
    local counts = { TANK = 0, HEALER = 0, DAMAGER = 0 }
    local hasLust = false
    local hasBrez = false
    local highestItemLevel = 0

    for _, player in ipairs(players) do
        counts[player.role] = (counts[player.role] or 0) + 1
        if addonTable.ClassProvidesLust(player.class) then
            hasLust = true
        end
        if addonTable.ClassProvidesBrez(player.class) then
            hasBrez = true
        end
        highestItemLevel = math.max(highestItemLevel, player.itemLevel or 0)
    end

    return counts, hasLust, hasBrez, highestItemLevel
end

local function GetApplicationStatusForResult(searchResultID)
    if not (C_LFGList and C_LFGList.GetApplicationInfo) then
        return NormalizeApplicationStatus(addonTable.SearchApplications[searchResultID] or "none")
    end

    local success, appA, appB = pcall(C_LFGList.GetApplicationInfo, searchResultID)
    if success then
        if type(appA) == "table" then
            return NormalizeApplicationStatus(appA.applicationStatus or appA.status or appA.pendingStatus or "none")
        elseif type(appB) == "string" then
            return NormalizeApplicationStatus(appB)
        elseif type(appA) == "string" then
            return NormalizeApplicationStatus(appA)
        end
    end

    return NormalizeApplicationStatus(addonTable.SearchApplications[searchResultID] or "none")
end

local function GetSearchResultDifficultyToken(resultInfo, activityInfo)
    if activityInfo and activityInfo.isMythicPlusActivity then
        return "MYTHIC_PLUS"
    end

    local source = strlower(table.concat({
        tostring(resultInfo and resultInfo.name or ""),
        tostring(activityInfo and activityInfo.fullName or ""),
        tostring(activityInfo and activityInfo.shortName or ""),
    }, " "))

    if source:find("mythic%+", 1) or source:find("mythic keystone", 1, true) then
        return "MYTHIC_PLUS"
    elseif source:find("mythic", 1, true) then
        return "MYTHIC"
    elseif source:find("heroic", 1, true) then
        return "HEROIC"
    elseif source:find("normal", 1, true) then
        return "NORMAL"
    end

    return "ANY"
end

local function GetDifficultyDisplayInfo(difficultyToken)
    local labels = {
        NORMAL = { full = "Normal", short = "N" },
        HEROIC = { full = "Heroic", short = "H" },
        MYTHIC = { full = "Mythic", short = "M" },
        MYTHIC_PLUS = { full = "Mythic+", short = "M+" },
    }

    return labels[difficultyToken] or { full = "Any", short = "" }
end

local function BuildEncounterNameData(encounterInfo)
    local defeatedBosses = {}
    local defeatedBossList = {}
    local count = 0

    if type(encounterInfo) ~= "table" then
        return defeatedBosses, defeatedBossList, count
    end

    for _, encounterEntry in pairs(encounterInfo) do
        local bossName = encounterEntry
        if type(encounterEntry) == "table" then
            bossName = encounterEntry.name or encounterEntry.bossName or encounterEntry.encounterName
        end

        if type(bossName) == "string" and bossName ~= "" and not defeatedBosses[bossName] then
            defeatedBosses[bossName] = true
            table.insert(defeatedBossList, bossName)
            count = count + 1
        end
    end

    return defeatedBosses, defeatedBossList, count
end

local function ParseRaidProgressText(...)
    local sources = { ... }
    for _, source in ipairs(sources) do
        local text = tostring(source or "")
        if text ~= "" then
            local killed, total = text:match("(%d+)%s*/%s*(%d+)")
            if not killed then
                killed, total = text:match("(%d+)%s*[Oo][Ff]%s*(%d+)")
            end
            if killed and total then
                return tonumber(killed) or 0, tonumber(total) or 0
            end
        end
    end

    return 0, 0
end

local KNOWN_RAID_BOSS_COUNTS = {
    ["march on quel'danas"] = 9,
    ["the dreamrift"] = 9,
    ["the voidspire"] = 9,
}

local function GetKnownRaidBossCount(raidName)
    local key = strlower(tostring(raidName or ""))
    return KNOWN_RAID_BOSS_COUNTS[key] or 0
end

local function GetRaidListingInfo(searchResultID, resultInfo, activityInfo)
    if not activityInfo then
        return nil
    end

    local difficultyToken = GetSearchResultDifficultyToken(resultInfo, activityInfo)
    local difficultyInfo = GetDifficultyDisplayInfo(difficultyToken)
    local raidName = CleanActivityLabel(activityInfo.shortName or activityInfo.fullName or "")
    local encounterInfo = C_LFGList.GetSearchResultEncounterInfo and C_LFGList.GetSearchResultEncounterInfo(searchResultID) or nil
    local defeatedBossNames, defeatedBossList, defeatedCount = BuildEncounterNameData(encounterInfo)
    local parsedKilled, parsedTotal = ParseRaidProgressText(
        activityInfo.fullName,
        activityInfo.shortName,
        resultInfo and resultInfo.name,
        resultInfo and resultInfo.comment
    )

    local bossesKilled = math.max(defeatedCount or 0, parsedKilled or 0)
    local bossCount = math.max(parsedTotal or 0, GetKnownRaidBossCount(raidName))
    local progressText = "--"

    if bossCount > 0 then
        progressText = string.format("%d/%d", bossesKilled, bossCount)
    elseif bossesKilled > 0 then
        progressText = tostring(bossesKilled)
    end

    return {
        raidName = raidName,
        raidNameKey = strlower(raidName),
        difficultyToken = difficultyToken,
        difficultyLabel = difficultyInfo.full,
        difficultyShort = difficultyInfo.short,
        bossesKilled = bossesKilled,
        bossCount = bossCount,
        progressText = progressText,
        defeatedBossNames = defeatedBossNames,
        defeatedBossList = defeatedBossList,
    }
end

addonTable.GetRaidListingInfo = GetRaidListingInfo

local function ParseResultPlaystyleText(resultInfo)
    local haystack = strlower((resultInfo and resultInfo.name or "") .. " " .. (resultInfo and resultInfo.comment or ""))
    if haystack:find("carry", 1, true) or haystack:find("boost", 1, true) then
        return "Carry"
    elseif haystack:find("learn", 1, true) then
        return "Learn"
    elseif haystack:find("relax", 1, true) or haystack:find("chill", 1, true) then
        return "Relax"
    elseif haystack:find("comp", 1, true) or haystack:find("push", 1, true) then
        return "Comp"
    end

    return nil
end

local function GetSearchResultPlaystyle(resultInfo, activityInfo)
    local playstyleValue = tonumber(resultInfo and resultInfo.generalPlaystyle) or 0
    local label = "Any"

    if playstyleValue > 0 and C_LFGList and C_LFGList.GetPlaystyleString then
        local success, playstyleString = pcall(C_LFGList.GetPlaystyleString, nil, playstyleValue, activityInfo)
        if success and type(playstyleString) == "string" and playstyleString ~= "" then
            label = playstyleString
        end
    end

    local shortLabel = ParseResultPlaystyleText(resultInfo)
    if not shortLabel then
        local lowered = strlower(label or "")
        if lowered:find("learn", 1, true) then
            shortLabel = "Learn"
        elseif lowered:find("relax", 1, true) or lowered:find("casual", 1, true) then
            shortLabel = "Relax"
        elseif lowered:find("hardcore", 1, true) or lowered:find("competitive", 1, true) then
            shortLabel = "Comp"
        elseif lowered:find("carry", 1, true) then
            shortLabel = "Carry"
        else
            shortLabel = "Any"
        end
    end

    return playstyleValue, label, shortLabel
end

local function GetCurrentSearchSelection()
    local panel = LFGListFrame and LFGListFrame.SearchPanel
    if not panel then
        return nil
    end

    local categoryID = panel.selectedCategory or panel.categoryID
    local filters = panel.selectedFilters or panel.filters or 0
    local preferredFilters = panel.preferredFilters or 0
    local languageFilter = panel.languageFilter
    local crossFaction = panel.searchCrossFactionListings

    return {
        categoryID = categoryID,
        filters = filters,
        preferredFilters = preferredFilters,
        languageFilter = languageFilter,
        searchCrossFactionListings = crossFaction,
    }
end

function addonTable.UpdateSearchContext()
    local context = addonTable.CurrentSearchContext or {}
    local selection = GetCurrentSearchSelection()

    if selection and selection.categoryID then
        context.selectedCategoryID = selection.categoryID
        context.searchSelection = selection
    end

    addonTable.CurrentSearchContext = context
    return context
end

local function FetchSearchResultData()
    addonTable.UpdateSearchContext()
    wipe(addonTable.SearchResults)
    BuildSearchApplicationState()

    if not (C_LFGList and C_LFGList.GetSearchResults) then
        return
    end

    local firstReturn, secondReturn = C_LFGList.GetSearchResults()
    local resultIDs = nil
    if type(firstReturn) == "table" then
        resultIDs = firstReturn
    elseif type(secondReturn) == "table" then
        resultIDs = secondReturn
    end
    if type(resultIDs) ~= "table" then
        addonTable.CurrentSearchContext = addonTable.CurrentSearchContext or { mode = "generic" }
        return
    end

    local firstContextResult = nil

    for _, searchResultID in ipairs(resultIDs) do
        local resultInfo = C_LFGList.GetSearchResultInfo(searchResultID)
        if resultInfo and not resultInfo.isDelisted then
            local activityID = GetSearchResultActivityID(resultInfo)
            local activityInfo = activityID and C_LFGList.GetActivityInfoTable(activityID) or nil

            if activityInfo then
                local listingMode = GetListingMode(activityInfo)
                local keyLevel = ParseResultKeyLevel(resultInfo, activityInfo)
                local displayName = BuildResultDisplayName(resultInfo, activityInfo, keyLevel)
                local activityFilterLabel = GetSearchResultActivityFilterLabel(activityInfo, listingMode)
                local activityFilterKey = strlower(activityFilterLabel or "")
                local players = GetSearchResultPlayers(searchResultID, resultInfo.numMembers or 0)
                local roleCounts = GetSearchResultRoleCounts(searchResultID)
                local _, hasLust, hasBrez, highestItemLevel = SummarizeSearchResultPlayers(players)
                local playstyleValue, playstyleLabel, playstyleShortLabel = GetSearchResultPlaystyle(resultInfo, activityInfo)
                local applicationStatus = GetApplicationStatusForResult(searchResultID)
                local ratingValue = tonumber(resultInfo.leaderOverallDungeonScore) or 0
                local pvpRating = 0
                local pvpBracket = nil
                local raidListing = nil
                local rioProfile = nil
                local raidProgress = nil

                if (listingMode == "rated_pvp" or listingMode == "pvp") and type(resultInfo.leaderPvpRatingInfo) == "table" then
                    pvpRating = tonumber(resultInfo.leaderPvpRatingInfo.rating) or 0
                    pvpBracket = GetPvpBracketLabel(resultInfo.leaderPvpRatingInfo)
                    ratingValue = pvpRating
                end

                if resultInfo.leaderName and RaiderIO and RaiderIO.GetProfile then
                    local charName, charRealm = strsplit("-", resultInfo.leaderName)
                    if not charRealm or charRealm == "" then
                        charRealm = GetNormalizedRealmName() or ""
                    end
                    rioProfile = RaiderIO.GetProfile(charName, charRealm)
                end

                if listingMode == "raid" or listingMode == "legacy_raid" then
                    raidListing = GetRaidListingInfo(searchResultID, resultInfo, activityInfo)
                    if rioProfile and addonTable.GetRaidProgressSummary then
                        raidProgress = addonTable.GetRaidProgressSummary(rioProfile, raidListing and raidListing.raidName or activityFilterLabel)
                    end
                end

                local leaderClass = "UNKNOWN"
                local leaderRole = "DAMAGER"
                if players[1] then
                    leaderClass = players[1].class or leaderClass
                    leaderRole = players[1].role or leaderRole
                end

                local entry = {
                    id = searchResultID,
                    name = resultInfo.name or "",
                    titleStr = resultInfo.name or "",
                    displayName = displayName,
                    comment = resultInfo.comment or "",
                    commentStr = resultInfo.comment or "",
                    leaderName = resultInfo.leaderName or "",
                    leaderNameRaw = resultInfo.leaderName or "",
                    leaderClass = leaderClass,
                    leaderRole = leaderRole,
                    numMembers = tonumber(resultInfo.numMembers) or #players,
                    members = tonumber(resultInfo.numMembers) or #players,
                    activityID = activityID,
                    activityInfo = activityInfo,
                    mode = listingMode,
                    activityName = activityInfo.fullName or activityInfo.shortName or "",
                    dungeonName = activityFilterLabel,
                    dungeon = activityFilterLabel,
                    activityFilterLabel = activityFilterLabel,
                    activityFilterKey = activityFilterKey,
                    keyLevel = keyLevel,
                    rating = ratingValue,
                    pvpRating = pvpRating,
                    pvpBracket = pvpBracket,
                    raidProgress = raidProgress,
                    raidListing = raidListing,
                    playstyleValue = playstyleValue,
                    playstyleLabel = playstyleLabel,
                    playstyleShortLabel = playstyleShortLabel,
                    roleCounts = roleCounts,
                    tanks = roleCounts.TANK or 0,
                    heals = roleCounts.HEALER or 0,
                    dps = roleCounts.DAMAGER or 0,
                    players = players,
                    memberDetails = players,
                    hasLust = hasLust,
                    hasBrez = hasBrez,
                    highestItemLevel = highestItemLevel,
                    difficultyID = tonumber(activityInfo.difficultyID) or 0,
                    difficulty = tonumber(activityInfo.difficultyID) or 0,
                    isMythicPlus = activityInfo.isMythicPlusActivity or false,
                    difficultyToken = GetSearchResultDifficultyToken(resultInfo, activityInfo),
                    requiredItemLevel = tonumber(resultInfo.requiredItemLevel) or 0,
                    requiredDungeonScore = tonumber(resultInfo.requiredDungeonScore) or 0,
                    hasSelf = resultInfo.hasSelf or IsAppliedStatus(applicationStatus),
                    isApplied = IsAppliedStatus(applicationStatus),
                    isDeclined = IsDeclinedStatus(applicationStatus),
                    isFriend = ((tonumber(resultInfo.numBNetFriends) or 0) > 0) or ((tonumber(resultInfo.numCharFriends) or 0) > 0) or ((tonumber(resultInfo.numGuildMates) or 0) > 0),
                    age = tonumber(resultInfo.age) or 0,
                    numBNetFriends = tonumber(resultInfo.numBNetFriends) or 0,
                    numCharFriends = tonumber(resultInfo.numCharFriends) or 0,
                    numGuildMates = tonumber(resultInfo.numGuildMates) or 0,
                    applicationStatus = applicationStatus,
                    leaderProfile = rioProfile,
                }

                table.insert(addonTable.SearchResults, entry)
                if not firstContextResult then
                    firstContextResult = entry
                end
            end
        end
    end

    local searchContext = addonTable.CurrentSearchContext or {}
    if firstContextResult then
        local activityInfo = firstContextResult.activityInfo
        searchContext.activityID = firstContextResult.activityID
        searchContext.activityInfo = activityInfo
        searchContext.mode = firstContextResult.mode or "generic"
        searchContext.categoryID = activityInfo and activityInfo.categoryID or searchContext.selectedCategoryID
        searchContext.groupID = activityInfo and (activityInfo.groupFinderActivityGroupID or activityInfo.groupID) or searchContext.groupID
    else
        searchContext.activityID = nil
        searchContext.activityInfo = nil
        searchContext.mode = "generic"
        searchContext.categoryID = searchContext.selectedCategoryID
        searchContext.groupID = searchContext.groupID
    end

    addonTable.CurrentSearchContext = searchContext
end
addonTable.FetchSearchResultData = FetchSearchResultData

local function GetCurrentSeasonFilterMask()
    if Enum and Enum.LFGListFilter and Enum.LFGListFilter.CurrentSeason then
        return Enum.LFGListFilter.CurrentSeason
    end

    return 0x40
end

function addonTable.GetAvailableBrowserActivities()
    local activityEntries = {}
    local seen = {}

    for _, result in ipairs(addonTable.SearchResults or {}) do
        local label = result.activityFilterLabel or result.activityName or ""
        local filterKey = result.activityFilterKey or strlower(label)
        if label ~= "" and filterKey ~= "" and not seen[filterKey] then
            seen[filterKey] = true
            table.insert(activityEntries, {
                activityID = result.activityID,
                label = label,
                filterKey = filterKey,
                activityInfo = result.activityInfo,
            })
        end
    end

    if #activityEntries == 0 then
        local context = addonTable.UpdateSearchContext()
        local categoryID = context and (context.categoryID or context.selectedCategoryID) or nil
        local groupID = context and context.groupID or nil
        if categoryID and groupID and C_LFGList and C_LFGList.GetAvailableActivities then
            local success, activityIDs = pcall(C_LFGList.GetAvailableActivities, categoryID, groupID, GetCurrentSeasonFilterMask())
            if success and type(activityIDs) == "table" then
                for _, activityID in ipairs(activityIDs) do
                    local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
                    local label = CleanActivityLabel(activityInfo and (activityInfo.shortName or activityInfo.fullName) or "")
                    local filterKey = strlower(label or "")
                    if label ~= "" and filterKey ~= "" and not seen[filterKey] then
                        seen[filterKey] = true
                        table.insert(activityEntries, {
                            activityID = activityID,
                            label = label,
                            filterKey = filterKey,
                            activityInfo = activityInfo,
                        })
                    end
                end
            end
        end
    end

    table.sort(activityEntries, function(a, b)
        return (a.label or "") < (b.label or "")
    end)

    return activityEntries
end

local function BuildSelectedActivityIDFilter()
    return nil
end

function addonTable.RunBrowserSearch()
    if not (C_LFGList and C_LFGList.Search) then
        return false, "Search API unavailable"
    end

    local context = addonTable.UpdateSearchContext()
    local selection = context and context.searchSelection or nil
    local categoryID = context and (context.categoryID or context.selectedCategoryID) or nil

    if not categoryID then
        return false, "Open Blizzard's Premade Groups page and pick a category first."
    end

    local success, err = pcall(
        C_LFGList.Search,
        categoryID,
        (selection and selection.filters) or 0,
        (selection and selection.preferredFilters) or 0,
        selection and selection.languageFilter or nil,
        selection and selection.searchCrossFactionListings or false
    )

    if not success then
        return false, tostring(err)
    end

    return true
end

function addonTable.ApplyToSearchResult(searchResultID)
    if addonTable.BeginSearchSignup then
        addonTable.BeginSearchSignup(searchResultID)
        return
    end

    if not (C_LFGList and C_LFGList.ApplyToGroup and searchResultID) then
        return
    end

    local role = "DAMAGER"
    if UnitGroupRolesAssigned then
        local assignedRole = UnitGroupRolesAssigned("player")
        if assignedRole and assignedRole ~= "NONE" then
            role = assignedRole
        end
    end

    if role == "DAMAGER" and GetSpecialization then
        local specIndex = GetSpecialization()
        if specIndex then
            local specID = GetSpecializationInfo(specIndex)
            local specRole = specID and GetSpecializationRoleByID(specID)
            if specRole and specRole ~= "NONE" then
                role = specRole
            end
        end
    end

    local tank = role == "TANK"
    local healer = role == "HEALER"
    local damage = not tank and not healer

    local success = pcall(C_LFGList.ApplyToGroup, searchResultID, tank, healer, damage)
    if success then
        addonTable.SearchApplications[searchResultID] = "applied"
        for _, result in ipairs(addonTable.SearchResults or {}) do
            if result.id == searchResultID then
                result.applicationStatus = "applied"
                result.hasSelf = true
                break
            end
        end
    end
end

function GetPvpBracketLabel(pvpRatingInfo)
    if type(pvpRatingInfo) ~= "table" then
        return nil
    end

    local activityName = strlower(pvpRatingInfo.activityName or "")
    if activityName:find("2v2", 1, true) or activityName:find("2v", 1, true) then
        return "2v2"
    elseif activityName:find("3v3", 1, true) or activityName:find("3v", 1, true) then
        return "3v3"
    elseif activityName:find("shuffle", 1, true) or activityName:find("solo", 1, true) then
        return "Solo"
    elseif activityName:find("blitz", 1, true) then
        return "Blitz"
    elseif activityName:find("battleground", 1, true) then
        return "RBG"
    elseif activityName:find("skirm", 1, true) then
        return "Skirm"
    elseif type(pvpRatingInfo.bracket) == "number" then
        return tostring(pvpRatingInfo.bracket)
    end

    return nil
end

local function CollectRaidProgress(rioProfile)
    if type(rioProfile) ~= "table" then
        return nil
    end

    local raidDataFound = {}

    local function MineRaidData(t, depth)
        if depth > 8 or type(t) ~= "table" then return end

        if t.difficulty and t.progressCount and t.raid and type(t.raid) == "table" and t.raid.shortName then
            local raidName = t.raid.shortName
            local diff = tonumber(t.difficulty) or t.difficulty
            local count = tonumber(t.progressCount) or 0
            local bosses = tonumber(t.raid.bossCount) or 9

            if not raidDataFound[raidName] then
                raidDataFound[raidName] = { normal = 0, heroic = 0, mythic = 0, bosses = bosses, raidName = raidName }
            end

            if diff == 1 or diff == "Normal" or diff == "N" then
                raidDataFound[raidName].normal = math.max(raidDataFound[raidName].normal, count)
            elseif diff == 2 or diff == "Heroic" or diff == "H" then
                raidDataFound[raidName].heroic = math.max(raidDataFound[raidName].heroic, count)
            elseif diff == 3 or diff == "Mythic" or diff == "M" then
                raidDataFound[raidName].mythic = math.max(raidDataFound[raidName].mythic, count)
            end
            return
        end

        local name = t.shortName or t.raid_name or t.name or (t.raid and type(t.raid) == "table" and t.raid.shortName)
        if name and (t.normal or t.heroic or t.mythic or t.normal_bosses_killed) then
            local raidName = tostring(name)
            local bosses = tonumber(t.bossCount or t.boss_count or t.total_bosses or t.bosses) or 9

            if not raidDataFound[raidName] then
                raidDataFound[raidName] = { normal = 0, heroic = 0, mythic = 0, bosses = bosses, raidName = raidName }
            end

            raidDataFound[raidName].normal = math.max(raidDataFound[raidName].normal, tonumber(t.normal or t.normal_bosses_killed or t.Normal or t.n) or 0)
            raidDataFound[raidName].heroic = math.max(raidDataFound[raidName].heroic, tonumber(t.heroic or t.heroic_bosses_killed or t.Heroic or t.h) or 0)
            raidDataFound[raidName].mythic = math.max(raidDataFound[raidName].mythic, tonumber(t.mythic or t.mythic_bosses_killed or t.Mythic or t.m) or 0)
            return
        end

        for _, value in pairs(t) do
            if type(value) == "table" then
                MineRaidData(value, depth + 1)
            end
        end
    end

    MineRaidData(rioProfile, 1)
    return raidDataFound
end

function addonTable.GetRaidProgressSummary(rioProfile, preferredRaidName)
    local raidDataFound = CollectRaidProgress(rioProfile)
    if not raidDataFound then
        return nil
    end

    local preferred = preferredRaidName and strlower(preferredRaidName) or nil
    local bestSummary = nil
    local bestScore = -1

    for raidName, data in pairs(raidDataFound) do
        local score = (data.mythic * 10000) + (data.heroic * 100) + data.normal
        local matchesPreferred = preferred and strlower(raidName):find(preferred, 1, true)

        if matchesPreferred then
            score = score + 1000000
        end

        if score > bestScore then
            bestScore = score

            local displayText = "--"
            if data.mythic > 0 then
                displayText = string.format("M %d/%d", data.mythic, data.bosses)
            elseif data.heroic > 0 then
                displayText = string.format("H %d/%d", data.heroic, data.bosses)
            elseif data.normal > 0 then
                displayText = string.format("N %d/%d", data.normal, data.bosses)
            end

            local longParts = {}
            if data.normal > 0 then table.insert(longParts, string.format("N %d/%d", data.normal, data.bosses)) end
            if data.heroic > 0 then table.insert(longParts, string.format("H %d/%d", data.heroic, data.bosses)) end
            if data.mythic > 0 then table.insert(longParts, string.format("M %d/%d", data.mythic, data.bosses)) end

            bestSummary = {
                raidName = raidName,
                displayText = displayText,
                longText = (#longParts > 0) and table.concat(longParts, "  ") or "--",
                sortValue = score,
            }
        end
    end

    return bestSummary
end

local function FetchApplicantData()
    local listingContext = addonTable.UpdateListingContext()
    local listingMode = listingContext and listingContext.mode or "generic"
    local activityID = listingContext and listingContext.activityID or nil
    local activityInfo = listingContext and listingContext.activityInfo or nil
    local preferredRaidName = activityInfo and (activityInfo.shortName or activityInfo.fullName) or nil

    wipe(addonTable.ApplicantGroups)
    local applicants = C_LFGList.GetApplicants()
    if not applicants then return end

    for _, applicantID in ipairs(applicants) do
        local info = C_LFGList.GetApplicantInfo(applicantID)
        
        if info and info.applicationStatus == "applied" and info.numMembers > 0 then
            
            local group = { id = applicantID, numMembers = info.numMembers, comment = info.comment, members = {} }

            for i = 1, info.numMembers do
                local name, class, _, _, itemLevel, _, tank, healer, damage, _, isFriend, dungeonScore, _, _, _, specID = C_LFGList.GetApplicantMemberInfo(applicantID, i)
                local role = NormalizeApplicantRole(tank, healer, specID)

                local bestKey, mainScore = 0, 0
                local rioCurrentScore = 0
                local rioProfile = nil
                local pvpRating = 0
                local pvpBracket = nil
                local raidProgress = nil
                
                local success, bestScoreInfo = pcall(C_LFGList.GetApplicantBestDungeonScore, applicantID, i)
                if success and type(bestScoreInfo) == "table" and type(bestScoreInfo.bestRunLevel) == "number" then
                    bestKey = bestScoreInfo.bestRunLevel
                end

                if RaiderIO and RaiderIO.GetProfile and name then
                    local charName, charRealm = strsplit("-", name)
                    if not charRealm or charRealm == "" then
                        charRealm = GetNormalizedRealmName() or ""
                    else
                        charRealm = charRealm:gsub("%s+", "") 
                    end
                    
                    rioProfile = RaiderIO.GetProfile(charName, charRealm)
                    
                    if rioProfile then
                        if type(rioProfile.mythicKeystoneProfile) == "table" then
                            rioCurrentScore = rioProfile.mythicKeystoneProfile.currentScore or 0
                            mainScore = rioProfile.mythicKeystoneProfile.mainCurrentScore or 0
                            
                            if type(rioProfile.mythicKeystoneProfile.sortedDungeons) == "table" and #rioProfile.mythicKeystoneProfile.sortedDungeons > 0 then
                                local topRun = rioProfile.mythicKeystoneProfile.sortedDungeons[1]
                                if type(topRun) == "table" and type(topRun.level) == "number" and topRun.level > 0 and topRun.level > bestKey then
                                    bestKey = topRun.level
                                end
                            end
                        end
                    end
                end

                if activityID and (listingMode == "rated_pvp" or listingMode == "pvp") then
                    local successPvp, pvpRatingInfo = pcall(C_LFGList.GetApplicantPvpRatingInfoForListing, applicantID, i, activityID)
                    if successPvp and type(pvpRatingInfo) == "table" then
                        pvpRating = tonumber(pvpRatingInfo.rating) or 0
                        pvpBracket = GetPvpBracketLabel(pvpRatingInfo)
                    end
                end

                if (listingMode == "raid" or listingMode == "legacy_raid") and rioProfile then
                    raidProgress = addonTable.GetRaidProgressSummary(rioProfile, preferredRaidName)
                end

                local finalRating = dungeonScore
                if (type(finalRating) ~= "number" or finalRating == 0) and rioCurrentScore > 0 then
                    finalRating = rioCurrentScore
                end

                local member = { 
                    name = name or "Unknown", 
                    class = class or "UNKNOWN", 
                    specID = specID,
                    role = role, 
                    ilvl = math.floor(itemLevel or 0), 
                    rating = finalRating, 
                    mainScore = mainScore, 
                    highestKey = bestKey,
                    rioProfile = rioProfile, 
                    isFriend = isFriend,
                    pvpRating = pvpRating,
                    pvpBracket = pvpBracket,
                    raidProgress = raidProgress,
                    memberIdx = i 
                }
                table.insert(group.members, member)
            end
            local lead = group.members[1]
            group.leadClass = lead.class
            group.leadRole = lead.role
            group.leadSpec = lead.specID
            group.leadIlvl = lead.ilvl
            group.leadRating = lead.rating
            group.leadKey = lead.highestKey
            group.leadPvpRating = lead.pvpRating
            group.leadPvpBracket = lead.pvpBracket
            group.leadRaidProgress = lead.raidProgress
            table.insert(addonTable.ApplicantGroups, group)
        end
    end
end

OAK_LFG:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
OAK_LFG:RegisterEvent("LFG_LIST_APPLICANT_UPDATED")
OAK_LFG:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
OAK_LFG:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
OAK_LFG:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
OAK_LFG:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")

OAK_LFG:SetScript("OnEvent", function(self, event, ...) 
    -- Auto-Close the window when the group is filled or manually delisted
    if event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
        local searchResultID, newStatus = ...
        if searchResultID then
            local normalized = NormalizeApplicationStatus(newStatus or "none")
            addonTable.SearchApplications[searchResultID] = normalized
            for _, result in ipairs(addonTable.SearchResults or {}) do
                if result.id == searchResultID then
                    result.applicationStatus = normalized
                    result.hasSelf = IsAppliedStatus(normalized)
                    break
                end
            end
        end
        if OAK_LFG:IsShown() then addonTable.UpdateDisplay() end
        return
    elseif event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" or event == "LFG_LIST_SEARCH_RESULT_UPDATED" then
        return
    elseif event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
        if not C_LFGList.HasActiveEntryInfo() then
            FetchSearchResultData()
            if OAK_LFG:IsShown() then addonTable.UpdateDisplay() end
            return
        end
    end

    if C_LFGList.HasActiveEntryInfo() then
        FetchApplicantData()
    else
        FetchSearchResultData()
    end

    if OAK_LFG:IsShown() then addonTable.UpdateDisplay() end 
end)

OAK_LFG:SetScript("OnShow", function(self) 
    SetupApplicantPingMuteHook()
    if C_LFGList.HasActiveEntryInfo() then
        FetchApplicantData()
    else
        FetchSearchResultData()
        if addonTable.UpdateFilterPaneMode then
            addonTable.UpdateFilterPaneMode()
        end
    end
    addonTable.UpdateHeaderVisuals()
    if addonTable.ApplyHideNotesLayout then
        addonTable.ApplyHideNotesLayout()
    else
        addonTable.UpdateDisplay()
    end
    
    if addonTable.CheckRIOHook then addonTable.CheckRIOHook() end
    if addonTable.AutoPosition then addonTable.AutoPosition() end
    if addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(OAK_LFG)
    end
end)

if PVEFrame then
    hooksecurefunc(PVEFrame, "SetPoint", function()
        if OAK_LFG:IsShown() and addonTable.AutoPosition then addonTable.AutoPosition() end
    end)
end

local VarEventFrame = CreateFrame("Frame")
VarEventFrame:RegisterEvent("ADDON_LOADED")
VarEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
VarEventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "ADDON_LOADED" then
        if loadedAddon == addonName then
            SetupApplicantPingMuteHook()
            if addonTable.LFGToggleBox then
                if OakLFGSorterDB.autoOpen then
                    addonTable.LFGToggleBox:SetBackdropColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1) 
                else
                    addonTable.LFGToggleBox:SetBackdropColor(0.106, 0.106, 0.129, 1) 
                end
            end
            
            local savedScale = OakLFGSorterDB.scale or 1.0
            addonTable.ScaleSlider:SetValue(savedScale)
            addonTable.ScaleEdit:SetText(string.format("%.2f", savedScale))
            OAK_LFG:SetScale(savedScale)

            if OakLFGSorterDB.framePos then 
                OAK_LFG:ClearAllPoints()
                local p = OakLFGSorterDB.framePos
                if #p == 4 then OAK_LFG:SetPoint(p[1], UIParent, p[2], p[3], p[4]) end
            end
            
            if OakLFGSorterDB.frameSize then 
                local minWidth = addonTable.GetTargetFrameWidth and addonTable.GetTargetFrameWidth() or 660
                local w = math.max(minWidth, OakLFGSorterDB.frameSize[1])
                local h = math.max(444, OakLFGSorterDB.frameSize[2])
                OAK_LFG:SetSize(w, h) 
            end

            if addonTable.ApplyHideNotesLayout then
                addonTable.ApplyHideNotesLayout()
            end
            
            addonTable.SetupBlizzardLFGHook()
        elseif loadedAddon == "Blizzard_LookingForGroupUI" then
            SetupApplicantPingMuteHook()
            addonTable.SetupBlizzardLFGHook()
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if OAK_LFG:IsShown() then 
            -- Check if the joining player triggered a group fill/delist
            if not C_LFGList.HasActiveEntryInfo() then
                OAK_LFG:Hide()
            else
                addonTable.UpdateDisplay() 
            end
        end
    end
end)

OAK_LFG:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if OakLFGSorterDB then
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        OakLFGSorterDB.framePos = { point, relativePoint, xOfs, yOfs }
        OakLFGSorterDB.frameSize = { self:GetWidth(), self:GetHeight() }
    end
end)

addonTable.ResizeGrip:SetScript("OnMouseUp", function(self, button) 
    OAK_LFG:StopMovingOrSizing() 
    if OakLFGSorterDB then OakLFGSorterDB.frameSize = { OAK_LFG:GetWidth(), OAK_LFG:GetHeight() } end
end)

SLASH_OAKLFG1 = "/oaklfg"
SlashCmdList["OAKLFG"] = function(msg)
    if msg and msg:lower() == "reset" then
        if OakLFGSorterDB then
            OakLFGSorterDB.framePos = nil
            OakLFGSorterDB.scale = 1.0
            OakLFGSorterDB.hideNotes = false
        end
        if addonTable.ScaleSlider then addonTable.ScaleSlider:SetValue(1.0) end
        if addonTable.AutoPosition then addonTable.AutoPosition() end
        if addonTable.ResetSearchWindow then
            addonTable.ResetSearchWindow()
        end
        if addonTable.ApplyHideNotesLayout then
            addonTable.ApplyHideNotesLayout()
        end

        if C_LFGList.HasActiveEntryInfo() then
            OAK_LFG:Show()
        elseif addonTable.OAK_SEARCH then
            addonTable.OAK_SEARCH:Show()
        else
            OAK_LFG:Show()
        end

        print("|cFF00FF00Oak LFG Sorter:|r Applicant and search window position, scale, and note settings reset.")
    else
        if OAK_LFG:IsShown() then OAK_LFG:Hide() else OAK_LFG:Show() end
    end
end
