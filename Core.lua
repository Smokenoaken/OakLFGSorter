local addonName, addonTable = ...
local OAK_LFG = addonTable.OAK_LFG
local L = addonTable.L
local NormalizeSearchScoreTargetLabel

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
local originalPlaySound = PlaySound

local function CreateApplicantPingHandler(originalHandler)
    return function(...)
        if ShouldMuteApplicantPing() then
            return
        end

        if originalHandler then
            return originalHandler(...)
        end

        if SOUNDKIT and SOUNDKIT.UI_GROUP_FINDER_RECEIVE_APPLICATION and type(originalPlaySound) == "function" then
            originalPlaySound(SOUNDKIT.UI_GROUP_FINDER_RECEIVE_APPLICATION, "master")
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
    if not activityID and securecallfunction and C_LFGList and C_LFGList.GetActiveEntryInfo then
        activityID = securecallfunction(function()
            local secureEntryInfo = C_LFGList.GetActiveEntryInfo()
            local ids = secureEntryInfo and secureEntryInfo.activityIDs
            local firstID = type(ids) == "table" and ids[1] or nil
            return tonumber(firstID)
        end)
    end
    if activityID == 0 then
        activityID = nil
    end

    local safeEntryInfo = {
        activityID = activityID,
        name = tostring(entryInfo.name or ""),
    }

    return activityID, safeEntryInfo
end

local LISTING_CATEGORY_ID = {
    QUESTING = 1,
    DUNGEON = 2,
    RAID = 3,
    ARENA = 4,
    CUSTOM = 6,
    RATED_BATTLEGROUND = 9,
    CLASSIC_RAID = 114,
    DELVES = 121,
}

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
    local categoryID = tonumber(activityInfo.categoryID or activityInfo.groupFinderCategoryID or activityInfo.category) or 0

    if activityInfo.isMythicPlusActivity then
        return "mythic_plus"
    elseif activityInfo.isRatedPvpActivity then
        return "rated_pvp"
    elseif activityInfo.isPvpActivity then
        return "pvp"
    elseif activityInfo.isCurrentRaidActivity then
        return "raid"
    elseif categoryID == LISTING_CATEGORY_ID.CLASSIC_RAID then
        return "legacy_raid"
    elseif categoryID == LISTING_CATEGORY_ID.DELVES then
        return "delve"
    elseif categoryID == LISTING_CATEGORY_ID.QUESTING then
        return "open_world"
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
addonTable._lastSearchResultsSignature = addonTable._lastSearchResultsSignature or nil

local CATEGORY_ID = LISTING_CATEGORY_ID

local function GetPveFilterMask()
    return Enum and Enum.LFGListFilter and Enum.LFGListFilter.PvE or 0
end

local function GetCurrentExpansionFilterMask()
    return Enum and Enum.LFGListFilter and Enum.LFGListFilter.CurrentExpansion or 0
end

local function GetNotCurrentExpansionFilterMask()
    return Enum and Enum.LFGListFilter and Enum.LFGListFilter.NotCurrentExpansion or 0
end

local function GetCurrentSeasonFilterMask()
    if Enum and Enum.LFGListFilter and Enum.LFGListFilter.CurrentSeason then
        return Enum.LFGListFilter.CurrentSeason
    end

    return 0x40
end

addonTable.BrowserCategoryOptions = {
    { id = "DUNGEONS", label = L["Dungeons"], categoryID = CATEGORY_ID.DUNGEON, filters = bit.bor(GetCurrentSeasonFilterMask(), GetPveFilterMask()), mode = "mythic_plus" },
    { id = "RAIDS_MIDNIGHT", label = L["Raids - Current"], categoryID = CATEGORY_ID.RAID, filters = bit.bor(GetCurrentExpansionFilterMask(), GetPveFilterMask()), mode = "raid" },
    { id = "RAIDS_LEGACY", label = L["Raids - Legacy"], categoryID = CATEGORY_ID.CLASSIC_RAID, filters = 0, mode = "legacy_raid" },
    { id = "DELVES", label = L["Delves"], categoryID = CATEGORY_ID.DELVES, filters = 0, mode = "delve" },
    { id = "QUESTING", label = L["Questing"], categoryID = CATEGORY_ID.QUESTING, filters = 0, mode = "open_world" },
    { id = "CUSTOM", label = L["Custom"], categoryID = CATEGORY_ID.CUSTOM, filters = 0, mode = "generic" },
    { id = "__PVP_SEPARATOR__", label = L["PvP"], separator = true },
    { id = "RBG", label = L["RBG"], categoryID = CATEGORY_ID.RATED_BATTLEGROUND, filters = 0, mode = "rated_pvp" },
    { id = "ARENA", label = L["Arena"], categoryID = CATEGORY_ID.ARENA, filters = 0, mode = "pvp" },
}

function addonTable.GetBrowserCategoryConfig(categoryKey)
    local selectedKey = categoryKey
        or (addonTable.GetCharacterBrowserCategoryKey and addonTable.GetCharacterBrowserCategoryKey())
        or (OakLFGSorterDB and OakLFGSorterDB.browserCategoryKey)
        or "DUNGEONS"
    for _, option in ipairs(addonTable.BrowserCategoryOptions) do
        if option.id == selectedKey then
            local allowOverride = selectedKey ~= "RAIDS_MIDNIGHT" and selectedKey ~= "RAIDS_LEGACY"
            local overrides = addonTable.GetCharacterBrowserCategoryOverrides and addonTable.GetCharacterBrowserCategoryOverrides()
                or (OakLFGSorterDB and OakLFGSorterDB.browserCategoryOverrides)
            local override = allowOverride and type(overrides) == "table" and overrides[selectedKey]
            if type(override) == "table" then
                local merged = {}
                for key, value in pairs(option) do
                    merged[key] = value
                end
                for key, value in pairs(override) do
                    merged[key] = value
                end
                return merged
            end
            return option
        end
    end
    return addonTable.BrowserCategoryOptions[1]
end

local function GetBrowserCategoryConfigForSelection(selection)
    local categoryID = tonumber(selection and selection.categoryID)
    if not categoryID then
        return nil
    end

    for _, option in ipairs(addonTable.BrowserCategoryOptions or {}) do
        if not option.separator and tonumber(option.categoryID) == categoryID then
            return option
        end
    end

    return nil
end

function addonTable.GetCurrentListingCategoryKey()
    local listingContext = addonTable.UpdateListingContext and addonTable.UpdateListingContext() or addonTable.CurrentListingContext
    local activityInfo = listingContext and listingContext.activityInfo or nil
    local mode = listingContext and listingContext.mode or GetListingMode(activityInfo)
    local categoryID = tonumber(activityInfo and (activityInfo.categoryID or activityInfo.groupFinderCategoryID or activityInfo.category)) or 0

    if mode == "mythic_plus" or mode == "dungeon" then
        return "DUNGEONS"
    elseif mode == "raid" then
        return "RAIDS_MIDNIGHT"
    elseif mode == "legacy_raid" or categoryID == CATEGORY_ID.CLASSIC_RAID then
        return "RAIDS_LEGACY"
    elseif mode == "delve" or categoryID == CATEGORY_ID.DELVES then
        return "DELVES"
    elseif mode == "open_world" or categoryID == CATEGORY_ID.QUESTING then
        return "QUESTING"
    elseif mode == "rated_pvp" then
        return "RBG"
    elseif mode == "pvp" then
        return "ARENA"
    end

    return "CUSTOM"
end

function addonTable.GetBrowserCategoryLabel(categoryKey)
    local config = addonTable.GetBrowserCategoryConfig(categoryKey)
    return config and config.label or L["Dungeons"]
end

function addonTable.SetBrowserCategory(categoryKey)
    local config = addonTable.GetBrowserCategoryConfig(categoryKey)
    local previousKey = addonTable.CurrentSearchContext and addonTable.CurrentSearchContext.selectedCategoryKey
    local db = addonTable.GetCharacterDB and addonTable.GetCharacterDB() or OakLFGSorterCharDB
    if type(db) == "table" then
        db.browserCategoryKey = config.id
    end

    if previousKey ~= config.id then
        addonTable._availableBrowserActivitiesCache = nil
        addonTable._lastSearchScopeSignature = nil
        addonTable._lastSearchResultsSignature = nil
        if addonTable.SearchResults then
            wipe(addonTable.SearchResults)
        end
    end

    addonTable.CurrentSearchContext = addonTable.CurrentSearchContext or {}
    addonTable.CurrentSearchContext.useOakCategorySelection = true
    addonTable.CurrentSearchContext.selectedCategoryKey = config.id
    addonTable.CurrentSearchContext.selectedCategoryID = config.categoryID
    addonTable.CurrentSearchContext.categoryID = config.categoryID
    addonTable.CurrentSearchContext.mode = config.mode or "generic"
    addonTable.CurrentSearchContext.searchSelection = {
        categoryID = config.categoryID,
        filters = config.filters or 0,
        preferredFilters = config.preferredFilters or 0,
        languageFilter = config.languageFilter,
        searchCrossFactionListings = config.searchCrossFactionListings or false,
    }
end

local function SaveObservedBrowserCategorySelection(categoryKey, selection)
    if not categoryKey or type(selection) ~= "table" then
        return
    end

    if categoryKey == "RAIDS_MIDNIGHT" or categoryKey == "RAIDS_LEGACY" then
        return
    end

    local overrides = addonTable.GetCharacterBrowserCategoryOverrides and addonTable.GetCharacterBrowserCategoryOverrides() or nil
    if type(overrides) ~= "table" then
        return
    end
    overrides[categoryKey] = {
        categoryID = selection.categoryID,
        filters = selection.filters or 0,
        preferredFilters = selection.preferredFilters or 0,
        languageFilter = selection.languageFilter,
        searchCrossFactionListings = selection.searchCrossFactionListings or false,
    }
end

-- View mode: "applicant" when you are listing a group, "browser" when searching to join
local currentViewMode = "applicant"

function addonTable.GetCurrentViewMode()
    return currentViewMode
end

function addonTable.SetCurrentViewMode(mode)
    if currentViewMode == mode then return end
    currentViewMode = mode
    -- Hide the filter panel that belongs to the OTHER mode so it doesn't bleed through
    if mode == "applicant" then
        if addonTable.BrowserFilterPanel and addonTable.BrowserFilterPanel:IsShown() then
            addonTable.BrowserFilterPanel:Hide()
        end
    else
        if addonTable.FilterPanel and addonTable.FilterPanel:IsShown() then
            addonTable.FilterPanel:Hide()
        end
    end
    -- Show/hide the quick signup bar
    if addonTable.quickSignupBar then
        if mode == "browser" then
            addonTable.quickSignupBar:Show()
        else
            addonTable.quickSignupBar:Hide()
        end
    end
    -- Reflow the layout (scroll frame bottom offset, headers, filter buttons)
    if addonTable.ApplyHideNotesLayout then
        addonTable.ApplyHideNotesLayout()
    elseif addonTable.UpdateDisplay then
        addonTable.UpdateDisplay()
    end
    -- Initialise the signup bar controls when entering browser mode
    if mode == "browser" and addonTable.UpdateSearchQuickSignupControls then
        addonTable.UpdateSearchQuickSignupControls()
    end
    if addonTable.UpdateFooterActionVisibility then
        addonTable.UpdateFooterActionVisibility()
    end
    if addonTable.UpdatePartyKeysPanel then
        addonTable.UpdatePartyKeysPanel()
    end
end

-- Debounce and throttle search result events: LFG_LIST_SEARCH_RESULT_UPDATED can
-- arrive in bursts, and repainting a 100-row browser repeatedly is expensive.
local searchRefreshPending = false
local searchRefreshQueued = false
local searchLastRefreshAt = 0
local SEARCH_REFRESH_MIN_DELAY = 0.30
local SEARCH_REFRESH_MIN_INTERVAL = 1.25
local displayRefreshPending = false
local applicantRefreshPending = false
local lastBrowserFilterPanelToken = nil

local function BuildBrowserFilterPanelRefreshToken()
    local context = addonTable.CurrentSearchContext or {}
    return table.concat({
        tostring(context.selectedCategoryKey or ""),
        tostring(context.selectedCategoryID or ""),
        tostring(context.categoryID or ""),
        tostring(context.groupID or ""),
        tostring(context.mode or ""),
        tostring(math.floor((OAK_LFG and OAK_LFG.GetWidth and OAK_LFG:GetWidth()) or 0)),
    }, "|")
end

local function ScheduleDisplayRefresh(delay)
    if displayRefreshPending then
        return
    end

    displayRefreshPending = true
    C_Timer.After(delay or 0.05, function()
        displayRefreshPending = false
        if OAK_LFG:IsShown() and addonTable.UpdateDisplay then
            addonTable.UpdateDisplay()
        end
    end)
end

local function ScheduleApplicantRefresh(delay)
    if applicantRefreshPending then
        return
    end

    applicantRefreshPending = true
    C_Timer.After(delay or 0, function()
        applicantRefreshPending = false
        if not (OAK_LFG:IsShown() and C_LFGList and C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo()) then
            return
        end

        if addonTable.SetCurrentViewMode then
            addonTable.SetCurrentViewMode("applicant")
        end
        if addonTable.FetchApplicantData then
            addonTable.FetchApplicantData()
        end
        ScheduleDisplayRefresh(0)
    end)
end

local function RunScheduledSearchRefresh()
    searchRefreshPending = false

    if currentViewMode ~= "browser" or not OAK_LFG:IsShown() then
        searchRefreshQueued = false
        return
    end

    local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
    local elapsed = now - (searchLastRefreshAt or 0)
    if elapsed < SEARCH_REFRESH_MIN_INTERVAL then
        searchRefreshPending = true
        C_Timer.After(SEARCH_REFRESH_MIN_INTERVAL - elapsed, RunScheduledSearchRefresh)
        return
    end

    searchLastRefreshAt = now
    local changed = true

    -- addonTable.FetchSearchResultData is the exposed reference to the local
    -- function defined later in this file — use that to avoid a forward-reference nil error.
    if addonTable.FetchSearchResultData then
        changed = addonTable.FetchSearchResultData()
        if changed == nil then
            changed = true
        end
    end

    if changed then
        ScheduleDisplayRefresh(0)
        -- Re-render the filter panel AFTER FetchSearchResultData has updated mode and
        -- SearchResults. Skip work if the pane is hidden or a dropdown is currently open.
        local dropdownOpen = addonTable.IsBrowserDropdownOpen and addonTable.IsBrowserDropdownOpen()
        local filterPanelShown = addonTable.BrowserFilterPanel and addonTable.BrowserFilterPanel:IsShown()
        if addonTable.UpdateBrowserFilterPanel and filterPanelShown and not dropdownOpen then
            local panelToken = BuildBrowserFilterPanelRefreshToken()
            if panelToken ~= lastBrowserFilterPanelToken then
                lastBrowserFilterPanelToken = panelToken
                addonTable.UpdateBrowserFilterPanel()
            end
        end
    end

    if searchRefreshQueued then
        searchRefreshQueued = false
        searchRefreshPending = true
        C_Timer.After(SEARCH_REFRESH_MIN_DELAY, RunScheduledSearchRefresh)
    end
end

local function ScheduleSearchRefresh()
    searchRefreshQueued = true
    if searchRefreshPending then
        return
    end

    searchRefreshPending = true
    C_Timer.After(SEARCH_REFRESH_MIN_DELAY, RunScheduledSearchRefresh)
end

local initialBrowserOpenRefreshPending = false
local function QueueInitialBrowserOpenRefresh()
    if initialBrowserOpenRefreshPending then
        return
    end

    initialBrowserOpenRefreshPending = true
    C_Timer.After(0.15, function()
        initialBrowserOpenRefreshPending = false

        if currentViewMode ~= "browser"
                or not OAK_LFG:IsShown()
                or (C_LFGList and C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo()) then
            return
        end

        if addonTable.FetchSearchResultData then
            local changed = addonTable.FetchSearchResultData()
            if changed or #(addonTable.SearchResults or {}) > 0 then
                ScheduleDisplayRefresh(0)
            end
        end
    end)
end

local browserPanelOpenRefreshPending = false
function addonTable.QueueBrowserSearchRefreshFromOpen(delay)
    if browserPanelOpenRefreshPending then
        return
    end

    browserPanelOpenRefreshPending = true
    C_Timer.After(delay or 0.15, function()
        browserPanelOpenRefreshPending = false

        if currentViewMode ~= "browser"
                or not OAK_LFG:IsShown()
                or (C_LFGList and C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo()) then
            return
        end

        -- Blizzard is already driving the search-panel transition when this is
        -- queued from SearchPanel:OnShow. Fetch the resulting data after that
        -- protected stack unwinds instead of starting another search from Oak.
        addonTable.CurrentSearchContext = addonTable.CurrentSearchContext or {}
        addonTable.CurrentSearchContext.useOakCategorySelection = nil

        local changed = true
        if addonTable.FetchSearchResultData then
            changed = addonTable.FetchSearchResultData()
            if changed == nil then
                changed = true
            end
        end

        if changed then
            ScheduleDisplayRefresh(0)
        elseif addonTable.UpdateDisplay then
            addonTable.UpdateDisplay()
        end

        if addonTable.UpdateBrowserFilterPanel
                and addonTable.BrowserFilterPanel
                and addonTable.BrowserFilterPanel:IsShown()
                and not (addonTable.IsBrowserDropdownOpen and addonTable.IsBrowserDropdownOpen()) then
            addonTable.UpdateBrowserFilterPanel()
        end
    end)
end

local function NormalizeApplicationStatus(status)
    return strlower(tostring(status or "none"))
end

local function IsAppliedStatus(status)
    status = NormalizeApplicationStatus(status)
    return status == "applied" or status == "invited" or status == "inviteaccepted" or status == "pending"
end

local function IsDeclinedStatus(status)
    status = NormalizeApplicationStatus(status)
    return status:find("declined", 1, true) ~= nil or status == "timedout"
end

local function IsCancelledStatus(status)
    status = NormalizeApplicationStatus(status)
    return status:find("cancelled", 1, true) ~= nil or status:find("canceled", 1, true) ~= nil
end

addonTable.NormalizeApplicationStatus = NormalizeApplicationStatus
addonTable.IsAppliedStatus = IsAppliedStatus
addonTable.IsDeclinedStatus = IsDeclinedStatus
addonTable.IsCancelledStatus = IsCancelledStatus

local DECLINED_MEMORY_TTL_SECONDS = 15 * 60
local DECLINED_MEMORY_MAX_ENTRIES = 200

local function NormalizeDeclinedMemoryToken(value)
    value = strlower(tostring(value or ""))
    value = value:gsub("%s+", " ")
    value = value:gsub("^%s+", "")
    value = value:gsub("%s+$", "")
    return value
end

local function BuildDeclinedMemoryKey(result)
    if type(result) ~= "table" then
        return nil
    end

    local partyGUID = NormalizeDeclinedMemoryToken(result.partyGUID)
    if partyGUID ~= "" then
        return "partyGUID:" .. partyGUID
    end

    local activityID = tonumber(result.activityID) or 0
    local leaderName = NormalizeDeclinedMemoryToken(result.leaderName)

    if activityID == 0 or leaderName == "" then
        return nil
    end

    return "activityLeader:" .. tostring(activityID) .. "|" .. leaderName
end

function addonTable.GetDeclinedMemoryKey(result)
    return BuildDeclinedMemoryKey(result)
end

local function GetDeclinedMemoryNow()
    if type(time) == "function" then
        return tonumber(time()) or 0
    end
    return 0
end

local function GetDeclinedMemoryEntryTimestamp(entry)
    if type(entry) == "number" then
        return entry
    end
    if entry == true then
        return GetDeclinedMemoryNow()
    end
    if type(entry) == "table" then
        return tonumber(entry.at or entry.time or entry.ts or entry.timestamp) or 0
    end
    return 0
end

local function PruneDeclinedMemory(hidden)
    if type(hidden) ~= "table" then
        return hidden
    end

    local now = GetDeclinedMemoryNow()
    local entries = {}

    for key, value in pairs(hidden) do
        local stamp = GetDeclinedMemoryEntryTimestamp(value)
        if stamp > 0 and (now <= 0 or (now - stamp) <= DECLINED_MEMORY_TTL_SECONDS) then
            hidden[key] = stamp
            entries[#entries + 1] = { key = key, stamp = stamp }
        else
            hidden[key] = nil
        end
    end

    if #entries <= DECLINED_MEMORY_MAX_ENTRIES then
        return hidden
    end

    table.sort(entries, function(a, b)
        return a.stamp > b.stamp
    end)

    for index = DECLINED_MEMORY_MAX_ENTRIES + 1, #entries do
        hidden[entries[index].key] = nil
    end

    return hidden
end

function addonTable.IsSearchResultHiddenByDeclineMemory(result)
    local hidden = addonTable.GetHiddenDeclinedGroups and addonTable.GetHiddenDeclinedGroups() or nil
    if type(hidden) ~= "table" or type(result) ~= "table" then
        return false
    end

    PruneDeclinedMemory(hidden)

    if result.id and hidden["id:" .. tostring(result.id)] then
        return true
    end

    local memoryKey = result.declinedMemoryKey or BuildDeclinedMemoryKey(result)
    if memoryKey and hidden["key:" .. memoryKey] then
        return true
    end

    return false
end

function addonTable.RememberDeclinedSearchResult(result)
    if type(result) ~= "table" then
        return false
    end

    local hidden = addonTable.GetHiddenDeclinedGroups and addonTable.GetHiddenDeclinedGroups() or nil
    if type(hidden) ~= "table" then
        return false
    end

    local now = GetDeclinedMemoryNow()
    PruneDeclinedMemory(hidden)

    local remembered = false
    if result.id then
        hidden["id:" .. tostring(result.id)] = now
        remembered = true
    end

    local memoryKey = result.declinedMemoryKey or BuildDeclinedMemoryKey(result)
    if memoryKey and memoryKey ~= "" then
        hidden["key:" .. memoryKey] = now
        result.declinedMemoryKey = memoryKey
        remembered = true
    end

    result.hiddenByDeclineMemory = remembered or result.hiddenByDeclineMemory
    return remembered
end

function addonTable.ClearDeclinedSearchResultMemory(result)
    if type(result) ~= "table" then
        return false
    end

    local hidden = addonTable.GetHiddenDeclinedGroups and addonTable.GetHiddenDeclinedGroups() or nil
    if type(hidden) ~= "table" then
        return false
    end

    PruneDeclinedMemory(hidden)

    local changed = false
    if result.id then
        local idKey = "id:" .. tostring(result.id)
        if hidden[idKey] ~= nil then
            hidden[idKey] = nil
            changed = true
        end
    end

    local memoryKey = result.declinedMemoryKey or BuildDeclinedMemoryKey(result)
    if memoryKey and hidden["key:" .. memoryKey] ~= nil then
        hidden["key:" .. memoryKey] = nil
        changed = true
    end

    result.hiddenByDeclineMemory = nil
    return changed
end

local function GetSearchResultActivityID(resultInfo, searchResultID)
    if not resultInfo then
        return nil
    end

    local activityID = tonumber(resultInfo.activityID)
    if not activityID then
        local ids = resultInfo.activityIDs
        if type(ids) == "table" then
            activityID = tonumber(ids[1])
        end
    end
    if not activityID and searchResultID and securecallfunction and C_LFGList and C_LFGList.GetSearchResultInfo then
        activityID = securecallfunction(function(resultID)
            local secureResultInfo = C_LFGList.GetSearchResultInfo(resultID)
            local ids = secureResultInfo and secureResultInfo.activityIDs
            local firstID = type(ids) == "table" and ids[1] or nil
            return tonumber(firstID)
        end, searchResultID)
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
        local playerInfo = C_LFGList.GetSearchResultPlayerInfo and C_LFGList.GetSearchResultPlayerInfo(searchResultID, memberIndex)
        local role
        local classFile
        local playerName
        local specID
        local specName

        if type(playerInfo) == "table" then
            playerName = playerInfo.name
            classFile = playerInfo.classFilename or playerInfo.classFileName
            role = playerInfo.assignedRole
            specID = tonumber(playerInfo.specID or playerInfo.specializationID or playerInfo.specId)
            specName = playerInfo.specName or playerInfo.specializationName or playerInfo.localizedSpecName
            if type(playerInfo.lfgRoles) == "table" then
                if playerInfo.lfgRoles.tank then
                    role = "TANK"
                elseif playerInfo.lfgRoles.healer then
                    role = "HEALER"
                elseif playerInfo.lfgRoles.dps then
                    role = "DAMAGER"
                end
            end
        end

        if not classFile then
            local success, legacyRole, legacyClassFile = pcall(C_LFGList.GetSearchResultMemberInfo, searchResultID, memberIndex)
            if success then
                role = legacyRole
                classFile = legacyClassFile
            end
        end

        if classFile then
            if role ~= "TANK" and role ~= "HEALER" then
                role = "DAMAGER"
            end

            table.insert(players, {
                name = playerName,
                role = role,
                class = classFile or "UNKNOWN",
                specID = specID,
                specName = specName,
                itemLevel = tonumber(playerInfo and (playerInfo.itemLevel or playerInfo.ilvl or playerInfo.averageItemLevel or playerInfo.playerItemLevel)) or 0,
            })
        end
    end

    return players
end

addonTable.GetSearchResultPlayers = GetSearchResultPlayers

local function SearchResultPlayersReusable(previous, numMembers, roleCounts)
    if not previous or type(previous.players) ~= "table" then
        return false
    end
    if (tonumber(previous.numMembers) or 0) ~= (tonumber(numMembers) or 0) then
        return false
    end
    if (tonumber(numMembers) or 0) > 0 and #previous.players == 0 then
        return false
    end

    local previousRoles = previous.roleCounts or {}
    local currentRoles = roleCounts or {}
    return (tonumber(previousRoles.TANK) or 0) == (tonumber(currentRoles.TANK) or 0)
        and (tonumber(previousRoles.HEALER) or 0) == (tonumber(currentRoles.HEALER) or 0)
        and (tonumber(previousRoles.DAMAGER) or 0) == (tonumber(currentRoles.DAMAGER) or 0)
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

local function GetSearchResultMemberCounts(searchResultID)
    if not (C_LFGList and C_LFGList.GetSearchResultMemberCounts) then
        return {}
    end

    local success, memberCounts = pcall(C_LFGList.GetSearchResultMemberCounts, searchResultID)
    if success and type(memberCounts) == "table" then
        return memberCounts
    end

    return {}
end

local function GetSearchResultRoleCounts(searchResultID, memberCounts)
    local counts = { TANK = 0, HEALER = 0, DAMAGER = 0 }
    memberCounts = type(memberCounts) == "table" and memberCounts or GetSearchResultMemberCounts(searchResultID)
    counts.TANK = tonumber(memberCounts.TANK) or 0
    counts.HEALER = tonumber(memberCounts.HEALER) or 0
    counts.DAMAGER = tonumber(memberCounts.DAMAGER) or 0
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

local function GetApplicationStatusForResult(searchResultID, resultInfo)
    if not (C_LFGList and C_LFGList.GetApplicationInfo) then
        return NormalizeApplicationStatus(addonTable.SearchApplications[searchResultID] or "none")
    end

    resultInfo = resultInfo or (C_LFGList.GetSearchResultInfo and C_LFGList.GetSearchResultInfo(searchResultID)) or nil
    local success, appA, appB = pcall(C_LFGList.GetApplicationInfo, searchResultID)
    local status = nil
    if success then
        if type(appA) == "table" then
            status = appA.applicationStatus or appA.status or appA.pendingStatus or "none"
        elseif type(appB) == "string" then
            status = appB
        elseif type(appA) == "string" then
            status = appA
        end
    end

    status = NormalizeApplicationStatus(status or addonTable.SearchApplications[searchResultID] or "none")
    if not IsDeclinedStatus(status)
            and LFGListFrame
            and type(LFGListFrame.declines) == "table"
            and resultInfo
            and resultInfo.partyGUID
            and LFGListFrame.declines[resultInfo.partyGUID] then
        status = NormalizeApplicationStatus(LFGListFrame.declines[resultInfo.partyGUID])
    end

    return status
end

local function GetSearchResultDifficultyToken(resultInfo, activityInfo)
    local difficultyID =
        tonumber(activityInfo and activityInfo.difficultyID)
        or tonumber(resultInfo and resultInfo.difficultyID)
        or 0

    local activityText = tostring(
        (activityInfo and (
            activityInfo.fullName
            or activityInfo.shortName
            or activityInfo.name
            or activityInfo.difficultyName
        ))
        or (resultInfo and (
            resultInfo.name
            or resultInfo.activityName
        ))
        or ""
    )
    local lowered = strlower(activityText)

    if (activityInfo and activityInfo.isMythicPlusActivity)
        or difficultyID == 8
        or lowered:find("mythic+", 1, true)
        or lowered:find("mythic plus", 1, true)
        or activityText:find("쐐기", 1, true)
    then
        return "MYTHIC_PLUS"
    end

    if difficultyID == 23
        or difficultyID == 16
        or lowered:find("mythic", 1, true)
        or activityText:find("신화", 1, true)
    then
        return "MYTHIC"
    elseif difficultyID == 2
        or difficultyID == 15
        or lowered:find("heroic", 1, true)
        or activityText:find("영웅", 1, true)
    then
        return "HEROIC"
    elseif difficultyID == 1
        or difficultyID == 14
        or lowered:find("normal", 1, true)
        or activityText:find("일반", 1, true)
    then
        return "NORMAL"
    end

    return "ANY"
end

local function GetDifficultyDisplayInfo(difficultyToken)
    local labels = {
        ANY = { full = L["Any"], short = "" },
        NORMAL = { full = L["Normal"], short = L["Normal Short"] },
        HEROIC = { full = L["Heroic"], short = L["Heroic Short"] },
        MYTHIC = { full = L["Mythic"], short = L["Mythic Short"] },
        MYTHIC_PLUS = { full = L["Mythic+"], short = L["Mythic+ Short"] },
    }

    return labels[difficultyToken] or labels.ANY
end

local function GetRaidDifficultyCount(data, difficultyToken)
    if type(data) ~= "table" then
        return 0
    end

    if difficultyToken == "MYTHIC" then
        return tonumber(data.mythic) or 0
    elseif difficultyToken == "HEROIC" then
        return tonumber(data.heroic) or 0
    elseif difficultyToken == "NORMAL" then
        return tonumber(data.normal) or 0
    end

    return 0
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

local function GetCurrentSearchLanguageFilter(panel)
    -- C_LFGList.Search expects the saved language-selection table.  The native
    -- search panel uses GetLanguageSearchFilter() when it searches; its
    -- languageFilter field is not the authoritative value on every client.
    -- This matters most on localized clients, where passing nil can fall back
    -- to the local client language when an activity filter is present.
    if C_LFGList and C_LFGList.GetLanguageSearchFilter then
        local ok, languages = pcall(C_LFGList.GetLanguageSearchFilter)
        if ok and type(languages) == "table" then
            return languages
        end
    end

    if panel and type(panel.languageFilter) == "table" then
        return panel.languageFilter
    end

    return nil
end

local function GetCurrentSearchSelection()
    local panel = LFGListFrame and LFGListFrame.SearchPanel
    if not panel then
        return nil
    end

    local categoryID = panel.selectedCategory or panel.categoryID
    local filters = panel.selectedFilters or panel.filters or 0
    local preferredFilters = panel.preferredFilters or 0
    local languageFilter = GetCurrentSearchLanguageFilter(panel)
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
    local preferOakSelection = context.useOakCategorySelection == true and context.selectedCategoryKey ~= nil

    if selection and selection.categoryID and (not preferOakSelection or selection.categoryID == context.selectedCategoryID) then
        local observedConfig = GetBrowserCategoryConfigForSelection(selection)
        context.selectedCategoryID = selection.categoryID
        context.categoryID = selection.categoryID
        if observedConfig then
            context.selectedCategoryKey = observedConfig.id
            context.mode = observedConfig.mode or context.mode or "generic"
        end
        context.searchSelection = selection
    else
        local storedConfig = addonTable.GetBrowserCategoryConfig and addonTable.GetBrowserCategoryConfig(context.selectedCategoryKey)
        if storedConfig then
            local liveMatchesStoredCategory = selection and selection.categoryID and selection.categoryID == storedConfig.categoryID
            local languageFilter = selection and selection.languageFilter
                or GetCurrentSearchLanguageFilter(LFGListFrame and LFGListFrame.SearchPanel)
                or storedConfig.languageFilter
            context.useOakCategorySelection = true
            context.selectedCategoryKey = storedConfig.id
            context.selectedCategoryID = storedConfig.categoryID
            context.categoryID = storedConfig.categoryID
            context.mode = storedConfig.mode or context.mode or "generic"
            context.searchSelection = {
                categoryID = storedConfig.categoryID,
                -- When Blizzard is already on the same category, preserve its exact live
                -- search flags instead of rebuilding them from Oak defaults. Localized
                -- clients appear to depend on this matching Blizzard's own request.
                filters = (liveMatchesStoredCategory and selection.filters) or storedConfig.filters or 0,
                preferredFilters = (liveMatchesStoredCategory and selection.preferredFilters) or storedConfig.preferredFilters or 0,
                languageFilter = languageFilter,
                searchCrossFactionListings = (selection and selection.searchCrossFactionListings) or storedConfig.searchCrossFactionListings or false,
            }
        end
    end

    addonTable.CurrentSearchContext = context
    return context
end

local function FetchSearchResultData()
    addonTable._availableBrowserActivitiesCache = nil
    local liveSelection = GetCurrentSearchSelection()
    addonTable.UpdateSearchContext()
    local previousResults = {}
    local previousResultsByID = {}
    for index, result in ipairs(addonTable.SearchResults or {}) do
        previousResults[index] = result
        if result and result.id then
            previousResultsByID[result.id] = result
        end
    end
    wipe(addonTable.SearchResults)
    BuildSearchApplicationState()
    local signatureParts = {}

    local currentContext = addonTable.CurrentSearchContext or {}
    signatureParts[#signatureParts + 1] = tostring(currentContext.selectedCategoryKey or "")
    signatureParts[#signatureParts + 1] = tostring(currentContext.selectedCategoryID or "")
    signatureParts[#signatureParts + 1] = tostring(currentContext.mode or "")
    local scopeSignature = table.concat(signatureParts, "|")
    local sameSearchScope = addonTable._lastSearchScopeSignature == scopeSignature
    addonTable._lastSearchScopeSignature = scopeSignature
    local isManualBrowserRefresh = addonTable._manualBrowserRefreshInProgress == true
    local panel = LFGListFrame and LFGListFrame.SearchPanel
    local categoryLabel = panel and panel.CategoryName and panel.CategoryName.GetText and panel.CategoryName:GetText() or ""
    local loweredCategoryLabel = strlower(tostring(categoryLabel or ""))
    local blizzardLegacyActive = (liveSelection
        and liveSelection.categoryID
        and currentContext.selectedCategoryID
        and liveSelection.categoryID == currentContext.selectedCategoryID)
        or loweredCategoryLabel:find("legacy", 1, true) ~= nil

    if currentContext.selectedCategoryKey == "RAIDS_LEGACY"
        and currentContext.useOakCategorySelection == true
        and not blizzardLegacyActive then
        currentContext.activityID = nil
        currentContext.activityInfo = nil
        currentContext.mode = "legacy_raid"
        currentContext.categoryID = currentContext.selectedCategoryID
        addonTable.CurrentSearchContext = currentContext
        local nextSignature = table.concat(signatureParts, "|")
        local changed = addonTable._lastSearchResultsSignature ~= nextSignature
        addonTable._lastSearchResultsSignature = nextSignature
        return changed
    end

    if not (C_LFGList and C_LFGList.GetSearchResults) then
        local nextSignature = table.concat(signatureParts, "|")
        local changed = addonTable._lastSearchResultsSignature ~= nextSignature
        addonTable._lastSearchResultsSignature = nextSignature
        return changed
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
        local nextSignature = table.concat(signatureParts, "|")
        local changed = addonTable._lastSearchResultsSignature ~= nextSignature
        addonTable._lastSearchResultsSignature = nextSignature
        return changed
    end

    local firstContextResult = nil
    local liveResultsByID = {}
    local liveResultOrder = {}
    local browserFilters = addonTable.GetCharacterBrowserFilters and addonTable.GetCharacterBrowserFilters() or {}
    local needsUtilityData = browserFilters.partyFit == true
        or browserFilters.lustMatch == true
        or browserFilters.needsLust == true
        or browserFilters.needsBrez == true
        or browserFilters.hasLust == true
        or browserFilters.hasBrez == true
    local showSpecIcons = OakLFGSorterDB and OakLFGSorterDB.showSpecIcons == true
    for _, searchResultID in ipairs(resultIDs) do
        local resultInfo = C_LFGList.GetSearchResultInfo(searchResultID)
        if resultInfo then
            local activityID = GetSearchResultActivityID(resultInfo, searchResultID)
            local activityInfo = activityID and C_LFGList.GetActivityInfoTable(activityID) or nil

            if activityInfo then
                local listingMode = GetListingMode(activityInfo)
                local keyLevel = ParseResultKeyLevel(resultInfo, activityInfo)
                local displayName = BuildResultDisplayName(resultInfo, activityInfo, keyLevel)
                local activityFilterLabel = GetSearchResultActivityFilterLabel(activityInfo, listingMode)
                local activityFilterKey = NormalizeSearchScoreTargetLabel(activityFilterLabel or "")
                local memberCounts = GetSearchResultMemberCounts(searchResultID)
                local roleCounts = GetSearchResultRoleCounts(searchResultID, memberCounts)
                local maxPlayers = tonumber(activityInfo.maxNumPlayers or activityInfo.maxPlayers) or 0
                local numMembers = tonumber(resultInfo.numMembers) or 0
                local shouldFetchPlayers = showSpecIcons
                    or needsUtilityData
                    or listingMode == "rated_pvp"
                    or listingMode == "pvp"
                    or maxPlayers <= 5
                    or numMembers <= 5
                local previousResult = previousResultsByID[searchResultID]
                local players = {}
                if shouldFetchPlayers then
                    if SearchResultPlayersReusable(previousResult, numMembers, roleCounts) then
                        players = previousResult.players
                    else
                        players = GetSearchResultPlayers(searchResultID, numMembers)
                    end
                end
                local _, hasLust, hasBrez, highestItemLevel = SummarizeSearchResultPlayers(players)
                local playstyleValue, playstyleLabel, playstyleShortLabel = GetSearchResultPlaystyle(resultInfo, activityInfo)
                local applicationStatus = GetApplicationStatusForResult(searchResultID, resultInfo)
                if resultInfo.hasSelf and not IsAppliedStatus(applicationStatus) and not IsDeclinedStatus(applicationStatus) then
                    applicationStatus = "applied"
                end
                local ratingValue = tonumber(resultInfo.leaderOverallDungeonScore) or 0
                local mainRatingValue = 0
                local pvpRating = 0
                local pvpBracket = nil
                local raidListing = nil
                local regionInfo = addonTable.GetRegionInfoFromLeaderName and addonTable.GetRegionInfoFromLeaderName(resultInfo.leaderName) or nil

                if listingMode == "rated_pvp" or listingMode == "pvp" then
                    local pvpInfo = resultInfo.leaderPvpRatingInfo
                    if type(pvpInfo) == "table" then
                        -- TWW returns leaderPvpRatingInfo as an array; actual data is in [1]
                        local entry = pvpInfo[1] or pvpInfo
                        if type(entry) == "table" then
                            pvpRating = tonumber(entry.rating
                                or entry.pvpRating
                                or entry.currentRating
                                or entry.seasonRating
                                or entry.weeklyBest
                                or entry.value) or 0
                            pvpBracket = GetPvpBracketLabel(entry)
                        end
                    elseif type(pvpInfo) == "number" then
                        pvpRating = pvpInfo
                    end
                    ratingValue = pvpRating
                end

                if (listingMode ~= "rated_pvp" and listingMode ~= "pvp"
                    and listingMode ~= "raid" and listingMode ~= "legacy_raid")
                    and resultInfo.leaderName
                    and RaiderIO
                    and RaiderIO.GetProfile
                then
                    local charName, charRealm = strsplit("-", resultInfo.leaderName)
                    if not charRealm or charRealm == "" then
                        charRealm = GetNormalizedRealmName() or ""
                    else
                        charRealm = charRealm:gsub("%s+", "")
                    end

                    local rioProfile = RaiderIO.GetProfile(charName, charRealm)
                    local mPlus = rioProfile and rioProfile.mythicKeystoneProfile
                    if type(mPlus) == "table" then
                        mainRatingValue = math.floor(math.max(
                            tonumber(mPlus.mainCurrentScore) or 0,
                            tonumber(mPlus.warbandCurrentScore) or 0
                        ))
                    end
                end

                -- For raid mode: fetch RIO profile to compute raidProgress (used for sorting + display).
                -- For M+/dungeon (the common high-volume case): profile is NOT fetched here;
                -- it is loaded lazily at tooltip time only, avoiding per-result RIO allocations.
                local raidProgress = nil
                if listingMode == "raid" or listingMode == "legacy_raid" then
                    raidListing = GetRaidListingInfo(searchResultID, resultInfo, activityInfo)
                    if resultInfo.leaderName and RaiderIO and RaiderIO.GetProfile then
                        local charName, charRealm = strsplit("-", resultInfo.leaderName)
                        if not charRealm or charRealm == "" then
                            charRealm = GetNormalizedRealmName() or ""
                        end
                        local rioProfile = RaiderIO.GetProfile(charName, charRealm)
                        if rioProfile and addonTable.GetRaidProgressSummary then
                            raidProgress = addonTable.GetRaidProgressSummary(
                                rioProfile,
                                raidListing and raidListing.raidName or activityFilterLabel,
                                raidListing and raidListing.difficultyToken or nil
                            )
                        end
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
                    partyGUID = resultInfo.partyGUID,
                    name = resultInfo.name or "",
                    displayName = displayName,
                    comment = resultInfo.comment or "",
                    leaderName = resultInfo.leaderName or "",
                    leaderClass = leaderClass,
                    leaderRole = leaderRole,
                    numMembers = numMembers > 0 and numMembers or #players,
                    activityID = activityID,
                    activityInfo = activityInfo,
                    mode = listingMode,
                    activityName = activityInfo.fullName or activityInfo.shortName or "",
                    dungeonName = activityFilterLabel,
                    activityFilterLabel = activityFilterLabel,
                    activityFilterKey = activityFilterKey,
                    keyLevel = keyLevel,
                    rating = ratingValue,
                    mainRating = mainRatingValue,
                    pvpRating = pvpRating,
                    pvpBracket = pvpBracket,
                    raidProgress = raidProgress,  -- non-nil only for raid/legacy_raid mode
                    raidListing = raidListing,
                    playstyleValue = playstyleValue,
                    playstyleLabel = playstyleLabel,
                    playstyleShortLabel = playstyleShortLabel,
                    memberCounts = memberCounts,
                    roleCounts = roleCounts,
                    players = players,
                    hasLust = hasLust,
                    hasBrez = hasBrez,
                    highestItemLevel = highestItemLevel,
                    maxPlayers = maxPlayers,
                    difficultyID = tonumber(activityInfo.difficultyID) or 0,
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
                    regionInfo = regionInfo,
                    -- leaderProfile intentionally omitted: fetched lazily at tooltip time via leaderName
                }

                entry.declinedMemoryKey = BuildDeclinedMemoryKey(entry)
                entry.hiddenByDeclineMemory = addonTable.IsSearchResultHiddenByDeclineMemory and addonTable.IsSearchResultHiddenByDeclineMemory(entry) or false
                if entry.isDeclined and addonTable.RememberDeclinedSearchResult then
                    addonTable.RememberDeclinedSearchResult(entry)
                    entry.hiddenByDeclineMemory = true
                end

                liveResultsByID[searchResultID] = entry
                liveResultOrder[#liveResultOrder + 1] = searchResultID
                signatureParts[#signatureParts + 1] = table.concat({
                    tostring(searchResultID or ""),
                    tostring(activityID or ""),
                    tostring(listingMode or ""),
                    tostring(activityFilterKey or ""),
                    tostring(displayName or ""),
                    tostring(resultInfo.name or ""),
                    tostring(resultInfo.comment or ""),
                    tostring(resultInfo.leaderName or ""),
                    tostring(keyLevel or 0),
                    tostring(ratingValue or 0),
                    tostring(pvpBracket or ""),
                    tostring(applicationStatus or ""),
                    tostring(numMembers > 0 and numMembers or #players),
                    tostring(tonumber(resultInfo.requiredItemLevel) or 0),
                    tostring(tonumber(resultInfo.requiredDungeonScore) or 0),
                    tostring(tonumber(resultInfo.numBNetFriends) or 0),
                    tostring(tonumber(resultInfo.numCharFriends) or 0),
                    tostring(tonumber(resultInfo.numGuildMates) or 0),
                    tostring(hasLust and 1 or 0),
                    tostring(hasBrez and 1 or 0),
                    tostring(highestItemLevel or 0),
                    tostring(roleCounts and roleCounts.TANK or 0),
                    tostring(roleCounts and roleCounts.HEALER or 0),
                    tostring(roleCounts and roleCounts.DAMAGER or 0),
                }, "~")
                if not firstContextResult then
                    firstContextResult = entry
                end
            end
        end
    end

    local filters = addonTable.GetCharacterBrowserFilters and addonTable.GetCharacterBrowserFilters() or {}
    addonTable._manualBrowserRefreshInProgress = nil
    addonTable._lastBrowserFetchWasManual = isManualBrowserRefresh
    local previousCount = #previousResults
    addonTable._browserHadPreviousResults = previousCount > 0
    local liveCount = #liveResultOrder
    local missingCount = 0
    if sameSearchScope and filters.keepUnavailable ~= false and not isManualBrowserRefresh and previousCount > 0 then
        for _, previous in ipairs(previousResults) do
            local previousID = previous and previous.id
            if previousID and not liveResultsByID[previousID] then
                missingCount = missingCount + 1
            end
        end
    end
    -- Guard against transient/paged Blizzard refreshes. If a large chunk of the
    -- result set disappears at once, treat it as a fresh result page instead of
    -- marking the whole browser as delisted.
    local maxPreservedMissing = math.max(8, math.floor(previousCount * 0.10))
    local preserveMissingResults = sameSearchScope
        and filters.keepUnavailable ~= false
        and not isManualBrowserRefresh
        and previousCount > 0
        and missingCount > 0
        and missingCount <= maxPreservedMissing

    local usedLiveResults = {}
    local function PreserveMissingPreviousResult(previous, previousIndex, options)
        local previousID = previous and previous.id
        if not previousID or liveResultsByID[previousID] or usedLiveResults[previousID] then
            return false
        end

        local preserveApplied = type(options) == "table" and options.preserveApplied == true
        local isApplied = previous.isApplied == true
            or previous.hasSelf == true
            or (addonTable.IsAppliedStatus and addonTable.IsAppliedStatus(previous.applicationStatus))
        previous._oakStableIndex = previous._oakStableIndex or previousIndex
        previous.isUnavailable = true
        if preserveApplied then
            previous.isFilteredOut = true
            previous.isDelisted = nil
        else
            previous.isFilteredOut = nil
            previous.isDelisted = true
        end
        previous.applicationStatus = previous.applicationStatus or "none"
        if isApplied then
            previous.isApplied = true
            previous.hasSelf = true
            previous._oakStickyUntilRefresh = true
        end
        table.insert(addonTable.SearchResults, previous)
        usedLiveResults[previousID] = true
        return true
    end

    if preserveMissingResults then
        local passesPreservedBrowserFilters = addonTable.ResultPassesBrowserFilters
        for previousIndex, previous in ipairs(previousResults) do
            local previousID = previous and previous.id
            local live = previousID and liveResultsByID[previousID]
            if live then
                live._oakStableIndex = previous._oakStableIndex or previousIndex
                live._oakWasVisibleInBrowser = not isManualBrowserRefresh and previous._oakWasVisibleInBrowser == true
                live._oakStickyUntilRefresh = not isManualBrowserRefresh and previous._oakStickyUntilRefresh == true or nil
                if live._oakStickyUntilRefresh and live.isDeclined then
                    live._oakShowDeclinedUntilRefresh = true
                end
                live.isDelisted = nil
                live.isUnavailable = nil
                live.isFilteredOut = nil
                table.insert(addonTable.SearchResults, live)
                usedLiveResults[previousID] = true
            elseif previousID and previous and previous._oakWasVisibleInBrowser == true then
                local isApplied = previous.isApplied == true
                    or previous.hasSelf == true
                    or (addonTable.IsAppliedStatus and addonTable.IsAppliedStatus(previous.applicationStatus))
                if isApplied or not passesPreservedBrowserFilters or passesPreservedBrowserFilters(previous, { allowUnavailable = true }) then
                    PreserveMissingPreviousResult(previous, previousIndex, { preserveApplied = isApplied })
                end
            end
        end
    end

    if sameSearchScope and not isManualBrowserRefresh then
        for previousIndex, previous in ipairs(previousResults) do
            if previous and (previous.isApplied == true
                    or previous.hasSelf == true
                    or (addonTable.IsAppliedStatus and addonTable.IsAppliedStatus(previous.applicationStatus))) then
                PreserveMissingPreviousResult(previous, previousIndex, { preserveApplied = true })
            end
        end
    end

    for _, searchResultID in ipairs(liveResultOrder) do
        if not usedLiveResults[searchResultID] then
            local live = liveResultsByID[searchResultID]
            if live then
                local previous = previousResultsByID[searchResultID]
                live._oakStableIndex = (previous and previous._oakStableIndex) or (#addonTable.SearchResults + 1)
                live._oakWasVisibleInBrowser = not isManualBrowserRefresh and previous and previous._oakWasVisibleInBrowser == true
                live._oakStickyUntilRefresh = not isManualBrowserRefresh and previous and previous._oakStickyUntilRefresh == true or nil
                if live._oakStickyUntilRefresh and live.isDeclined then
                    live._oakShowDeclinedUntilRefresh = true
                end
                table.insert(addonTable.SearchResults, live)
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
        searchContext.groupID = (addonTable.ResolveActivityGroupID and addonTable.ResolveActivityGroupID(activityInfo)) or searchContext.groupID

        if searchContext.searchSelection then
            local observedKey
            if firstContextResult.mode == "legacy_raid" then
                observedKey = "RAIDS_LEGACY"
            elseif firstContextResult.mode == "raid" and (searchContext.categoryID == CATEGORY_ID.RAID) then
                observedKey = "RAIDS_MIDNIGHT"
            end
            if observedKey then
                SaveObservedBrowserCategorySelection(observedKey, searchContext.searchSelection)
            end
        end
    else
        searchContext.activityID = nil
        searchContext.activityInfo = nil
        -- Do NOT reset mode to "generic" when results are empty.
        -- Preserving the last known mode keeps the filter panel in the correct
        -- state (dungeon list visible, difficulty dropdown intact) when a search
        -- returns zero results (e.g. filtering by Heroic with no groups posted).
        -- Mode will update naturally the next time results arrive.
        searchContext.categoryID = searchContext.selectedCategoryID
        searchContext.groupID = searchContext.groupID
    end

    addonTable.CurrentSearchContext = searchContext
    local nextSignature = table.concat(signatureParts, "|")
    local changed = addonTable._lastSearchResultsSignature ~= nextSignature
    addonTable._lastSearchResultsSignature = nextSignature
    addonTable._browserLiveUpdatePending = changed
        and sameSearchScope
        and not isManualBrowserRefresh
        and previousCount > 0
        or nil
    return changed
end
addonTable.FetchSearchResultData = FetchSearchResultData

addonTable.GetCurrentSeasonFilterMask = GetCurrentSeasonFilterMask

local function ResolveActivityGroupID(activityInfo)
    if type(activityInfo) ~= "table" then
        return nil
    end

    return tonumber(activityInfo.activityGroupID or activityInfo.groupFinderActivityGroupID or activityInfo.groupID)
end
addonTable.ResolveActivityGroupID = ResolveActivityGroupID

-- Score target utilities (ported from retired Search.lua)
local function GetSearchRaidFilterLabel(activityInfo)
    local label = tostring(activityInfo and (activityInfo.fullName or activityInfo.shortName) or "")
    label = label:gsub("%s*%(.+%)", "")
    return label
end
addonTable.GetSearchRaidFilterLabel = GetSearchRaidFilterLabel

NormalizeSearchScoreTargetLabel = function(label)
    local normalized = strlower(GetSearchRaidFilterLabel({ fullName = tostring(label or "") }))
    local replacements = {
        ["ä"] = "ae", ["ö"] = "oe", ["ü"] = "ue", ["ß"] = "ss",
        ["à"] = "a", ["á"] = "a", ["â"] = "a", ["ã"] = "a", ["å"] = "a",
        ["ç"] = "c",
        ["è"] = "e", ["é"] = "e", ["ê"] = "e", ["ë"] = "e",
        ["ì"] = "i", ["í"] = "i", ["î"] = "i", ["ï"] = "i",
        ["ñ"] = "n",
        ["ò"] = "o", ["ó"] = "o", ["ô"] = "o", ["õ"] = "o",
        ["ù"] = "u", ["ú"] = "u", ["û"] = "u",
        ["ý"] = "y", ["ÿ"] = "y",
    }
    for source, target in pairs(replacements) do
        normalized = normalized:gsub(source, target)
    end
    normalized = normalized:gsub("^the%s+", "")
    normalized = normalized:gsub("^der%s+", "")
    normalized = normalized:gsub("^die%s+", "")
    normalized = normalized:gsub("^das%s+", "")
    normalized = normalized:gsub("^le%s+", "")
    normalized = normalized:gsub("^la%s+", "")
    normalized = normalized:gsub("^les%s+", "")
    normalized = normalized:gsub("^el%s+", "")
    normalized = normalized:gsub("^los%s+", "")
    normalized = normalized:gsub("^las%s+", "")
    normalized = normalized:gsub("[%(%)%[%]%-_:;,%.%!%?]", " ")
    normalized = normalized:gsub("%s+", " ")
    normalized = normalized:gsub("^%s+", ""):gsub("%s+$", "")
    return normalized
end
addonTable.NormalizeSearchScoreTargetLabel = NormalizeSearchScoreTargetLabel

addonTable.GetMythicPlusScoreTargets = function()
    if addonTable.IsRestrictedCombatInInstance and addonTable.IsRestrictedCombatInInstance() then
        if type(addonTable.LastGoodMythicPlusScoreTargets) == "table" then
            return addonTable.LastGoodMythicPlusScoreTargets
        end
        return {}
    end

    if not (C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapUIInfo and C_MythicPlus and C_MythicPlus.GetSeasonBestAffixScoreInfoForMap) then
        return {}
    end

    if C_MythicPlus.RequestMapInfo then
        pcall(C_MythicPlus.RequestMapInfo)
    end

    local function GetRatingCalcValues()
        local seasonCalcValues = {
            [11] = { baseRating=20, firstAffixLevel=2, fistAffixValue=10, secondAffixLevel=7, secondAffixValue=10, thirdAffixLevel=14, thirdAffixValue=10, thresholdLevel=10, preThresholdValue=5, postThresholdValue=7 },
            [12] = { baseRating=70, firstAffixLevel=2, fistAffixValue=10, secondAffixLevel=5, secondAffixValue=10, thirdAffixLevel=10, thirdAffixValue=10, thresholdLevel=1, preThresholdValue=7, postThresholdValue=7 },
            [13] = { baseRating=120, firstAffixLevel=2, fistAffixValue=15, secondAffixLevel=4, secondAffixValue=10, thirdAffixLevel=7, thirdAffixValue=15, fourthAffixLevel=10, fourthAffixValue=10, fifthAffixLevel=12, fifthAffixValue=15, thresholdLevel=1, preThresholdValue=15, postThresholdValue=15 },
            [14] = { baseRating=125, firstAffixLevel=4, fistAffixValue=15, secondAffixLevel=7, secondAffixValue=15, thirdAffixLevel=10, thirdAffixValue=15, fourthAffixLevel=12, fourthAffixValue=15, fifthAffixLevel=12, fifthAffixValue=0, thresholdLevel=1, preThresholdValue=15, postThresholdValue=15 },
        }
        local currentSeason = tonumber(C_MythicPlus.GetCurrentSeason and C_MythicPlus.GetCurrentSeason()) or 0
        if seasonCalcValues[currentSeason] then return seasonCalcValues[currentSeason] end
        local fallbackSeason = 0
        for s in pairs(seasonCalcValues) do if s > fallbackSeason then fallbackSeason = s end end
        return seasonCalcValues[fallbackSeason]
    end

    local seasonVars = GetRatingCalcValues()
    if not seasonVars then return {} end

    local function GetTimedRunScore(level)
        level = tonumber(level) or 0
        if level < 2 then return 0 end
        local baseRating = seasonVars.baseRating
        local firstRating = (level >= seasonVars.thresholdLevel) and (seasonVars.thresholdLevel * seasonVars.preThresholdValue) or (level * seasonVars.preThresholdValue)
        local secondRating = (level > seasonVars.thresholdLevel) and ((level - seasonVars.thresholdLevel) * seasonVars.postThresholdValue) or 0
        local affixScore = 0
        if level >= seasonVars.firstAffixLevel then affixScore = affixScore + seasonVars.fistAffixValue end
        if level >= seasonVars.secondAffixLevel then affixScore = affixScore + seasonVars.secondAffixValue end
        if level >= seasonVars.thirdAffixLevel then affixScore = affixScore + seasonVars.thirdAffixValue end
        if seasonVars.fourthAffixLevel and seasonVars.fourthAffixValue and level >= seasonVars.fourthAffixLevel then affixScore = affixScore + seasonVars.fourthAffixValue end
        if seasonVars.fifthAffixLevel and seasonVars.fifthAffixValue and level >= seasonVars.fifthAffixLevel then affixScore = affixScore + seasonVars.fifthAffixValue end
        return baseRating + firstRating + secondRating + affixScore
    end

    local function BuildEstimatedScoreGain(baseLevel, currentOverall)
        local level = tonumber(baseLevel)
        if not level or level <= 0 then return nil end
        local timedScore = GetTimedRunScore(level)
        local twoChestScore = GetTimedRunScore(math.min(30, level + 1))
        local threeChestScore = GetTimedRunScore(math.min(30, level + 2))
        return {
            timed = math.max(1, math.floor((timedScore - currentOverall) + 0.5)),
            plusTwo = math.max(1, math.floor((twoChestScore - currentOverall) + 0.5)),
            plusThree = math.max(1, math.floor((threeChestScore - currentOverall) + 0.5)),
        }
    end

    local targets = {}
    local mapIDs = C_ChallengeMode.GetMapTable() or {}
    local missingMapNames = false
    local missingMapData = #mapIDs == 0

    for _, mapID in ipairs(mapIDs) do
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        if not name or name == "" then missingMapNames = true end
        local labelKey = NormalizeSearchScoreTargetLabel(name)
        if labelKey ~= "" then
            local mapScores, bestOverallScore = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(mapID)
            local currentOverall = tonumber(bestOverallScore) or 0
            if currentOverall <= 0 and type(mapScores) == "table" then
                for _, info in ipairs(mapScores) do
                    if type(info) == "table" then currentOverall = math.max(currentOverall, tonumber(info.score) or 0) end
                end
            end
            local targetLevel
            for level = 2, 30 do
                if GetTimedRunScore(level) > currentOverall then targetLevel = level; break end
            end
            if targetLevel then
                local estimatedGain = BuildEstimatedScoreGain(targetLevel, currentOverall)
                targets[labelKey] = {
                    level = targetLevel,
                    estimatedGain = estimatedGain and estimatedGain.timed or nil,
                    estimatedGainBreakdown = estimatedGain,
                    projectedScore = GetTimedRunScore(targetLevel),
                    currentScore = currentOverall,
                }
            end
        end
    end

    if next(targets) ~= nil then
        addonTable._availableBrowserActivitiesCache = nil
        addonTable.LastGoodMythicPlusScoreTargets = targets
        addonTable.PendingScoreTargetRefresh = false
        addonTable.ScoreTargetRefreshAttempts = 0
        return targets
    end

    if (missingMapNames or missingMapData) and not addonTable.PendingScoreTargetRefresh then
        local attempts = tonumber(addonTable.ScoreTargetRefreshAttempts) or 0
        if attempts < 4 then
            addonTable.PendingScoreTargetRefresh = true
            addonTable.ScoreTargetRefreshAttempts = attempts + 1
            C_Timer.After(0.5 * addonTable.ScoreTargetRefreshAttempts, function()
                addonTable.PendingScoreTargetRefresh = false
                addonTable._availableBrowserActivitiesCache = nil
                if addonTable.UpdateBrowserFilterPanel then
                    addonTable.UpdateBrowserFilterPanel()
                end
            end)
        end
    end

    if type(addonTable.LastGoodMythicPlusScoreTargets) == "table" and next(addonTable.LastGoodMythicPlusScoreTargets) ~= nil then
        return addonTable.LastGoodMythicPlusScoreTargets
    end

    return targets
end

function addonTable.GetAvailableBrowserActivities()
    local context = addonTable.CurrentSearchContext or {}
    local mode = context.mode or "generic"
    local cacheKey = table.concat({
        tostring(mode or ""),
        tostring(context.selectedCategoryKey or ""),
        tostring(context.selectedCategoryID or ""),
        tostring(context.categoryID or ""),
        tostring(context.groupID or ""),
        tostring(addonTable._lastSearchResultsSignature or ""),
        tostring(addonTable._scoreTargetsVersion or 0),
    }, "|")
    local cached = addonTable._availableBrowserActivitiesCache
    if cached and cached.key == cacheKey and type(cached.entries) == "table" then
        return cached.entries
    end

    local activityEntries = {}
    local seen = {}
    local scoreTargets = ((mode == "mythic_plus" or mode == "dungeon") and addonTable.GetMythicPlusScoreTargets and addonTable.GetMythicPlusScoreTargets()) or {}

    -- ── M+ and dungeon mode: use C_ChallengeMode's map list as canonical source ──
    -- context.groupID is set to a specific dungeon's activity group (e.g. "Skyreach"),
    -- so calling GetAvailableActivities with it returns that dungeon's difficulty levels
    -- (Normal/Heroic/Mythic/Mythic+) rather than all season dungeons.
    -- GetLocalizedSeasonDungeonLabels() uses C_ChallengeMode.GetMapTable() which is
    -- always the correct full list of current-season M+ dungeons.
    if mode == "mythic_plus" or mode == "dungeon" then
        local seasonLabels = addonTable.GetLocalizedSeasonDungeonLabels and addonTable.GetLocalizedSeasonDungeonLabels() or {}
        local mapIDByLabel = {}
        if C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapUIInfo then
            for _, mapID in ipairs(C_ChallengeMode.GetMapTable() or {}) do
                local mapName = C_ChallengeMode.GetMapUIInfo(mapID)
                local mapKey = NormalizeSearchScoreTargetLabel(mapName)
                if mapKey and mapKey ~= "" and not mapIDByLabel[mapKey] then
                    mapIDByLabel[mapKey] = tonumber(mapID)
                end
            end
        end

        -- Build a canonical lookup: normalizedLabel → activityInfo/activityID.
        -- Prefer Blizzard's full available-activities list so dungeon filters still map
        -- correctly even when a dungeon has no visible listings in the current results.
        local resultInfoByLabel = {}
        local categoryID = addonTable.CurrentSearchContext and addonTable.CurrentSearchContext.selectedCategoryID
        if categoryID and C_LFGList and C_LFGList.GetAvailableActivities and C_LFGList.GetActivityInfoTable then
            local availableActivities = C_LFGList.GetAvailableActivities(categoryID) or {}
            for _, activityID in ipairs(availableActivities) do
                local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
                if activityInfo then
                    local aLabel = CleanActivityLabel(activityInfo.fullName or activityInfo.shortName or "")
                    local aKey = NormalizeSearchScoreTargetLabel(aLabel)
                    if aKey ~= "" then
                        -- Prefer the activity with the highest groupFinderActivityGroupID.
                        -- Legacy dungeons reused for current M+ (e.g. Magisters' Terrace) have
                        -- both old BC activities (low groupID) and current-season M+ activities
                        -- (high groupID) under the same normalized label. Blizzard's native
                        -- filter needs the current-season groupID, not the legacy one.
                        local newGroupID = tonumber(activityInfo.groupFinderActivityGroupID) or 0
                        local existing = resultInfoByLabel[aKey]
                        local existingGroupID = existing and (tonumber((existing.activityInfo or {}).groupFinderActivityGroupID) or 0) or -1
                        if not existing or newGroupID > existingGroupID then
                            resultInfoByLabel[aKey] = {
                                activityID = activityID,
                                activityInfo = activityInfo,
                            }
                        end
                    end
                end
            end
        end

        -- Fill any missing entries from current search results as a fallback.
        for _, result in ipairs(addonTable.SearchResults or {}) do
            local rLabel = result.activityFilterLabel or result.activityName or ""
            local rKey = NormalizeSearchScoreTargetLabel(rLabel)
            if rKey ~= "" and not resultInfoByLabel[rKey] then
                resultInfoByLabel[rKey] = { activityID = result.activityID, activityInfo = result.activityInfo }
            end
        end

        for _, label in ipairs(seasonLabels) do
            local filterKey = NormalizeSearchScoreTargetLabel(label)
            if filterKey ~= "" and not seen[filterKey] then
                seen[filterKey] = true
                local normalizedKey = NormalizeSearchScoreTargetLabel(label)
                local resultMatch = resultInfoByLabel[normalizedKey] or {}
                table.insert(activityEntries, {
                    activityID  = resultMatch.activityID,
                    label       = label,
                    filterKey   = filterKey,
                    activityInfo = resultMatch.activityInfo,
                    mapID       = mapIDByLabel[normalizedKey],
                    scoreTarget = scoreTargets[normalizedKey] or nil,
                })
            end
        end

        table.sort(activityEntries, function(a, b)
            return (a.label or "") < (b.label or "")
        end)

        addonTable._availableBrowserActivitiesCache = { key = cacheKey, entries = activityEntries }
        return activityEntries
    end

    if mode == "delve" then
        local configuredDelves = addonTable.SearchConfig and addonTable.SearchConfig.DefaultSeasonDelves or {}
        local resultInfoByLabel = {}

        for _, result in ipairs(addonTable.SearchResults or {}) do
            if result.mode == "delve" then
                local rawLabel = result.activityFilterLabel or result.activityName or ""
                local normalizedKey = NormalizeSearchScoreTargetLabel(rawLabel)
                if normalizedKey ~= "" and not resultInfoByLabel[normalizedKey] then
                    resultInfoByLabel[normalizedKey] = {
                        activityID = result.activityID,
                        activityInfo = result.activityInfo,
                    }
                end
            end
        end

        for _, label in ipairs(configuredDelves) do
            local filterKeyBuilder = addonTable.GetPendingNativeActivityKey
            local filterKey = filterKeyBuilder and filterKeyBuilder(label) or NormalizeSearchScoreTargetLabel(label)
            if filterKey ~= "" and not seen[filterKey] then
                seen[filterKey] = true
                local normalizedKey = NormalizeSearchScoreTargetLabel(label)
                local resultMatch = resultInfoByLabel[normalizedKey] or {}
                table.insert(activityEntries, {
                    activityID = resultMatch.activityID,
                    label = label,
                    filterKey = filterKey,
                    activityInfo = resultMatch.activityInfo,
                    scoreTarget = scoreTargets[normalizedKey] or nil,
                })
            end
        end

        addonTable._availableBrowserActivitiesCache = { key = cacheKey, entries = activityEntries }
        return activityEntries
    end

    -- ── All other modes (raid, generic): build from search results ─────────
    local isRaidContext = (mode == "raid" or mode == "legacy_raid")
    local selectedCategoryKey = addonTable.CurrentSearchContext and addonTable.CurrentSearchContext.selectedCategoryKey
    addonTable.BrowserActivityCache = addonTable.BrowserActivityCache or {}

    -- Helper: strip difficulty prefix from a raid activity label.
    -- WoW stores raid difficulties as activity shortNames, so activityFilterLabel is
    -- often "Heroic The Voidspire" or "Normal Amirdrassil". We strip the prefix to get
    -- the clean instance name used as the filter key.
    local function StripRaidDifficultyPrefix(rawLabel, diffLabel)
        if diffLabel and diffLabel ~= "" and rawLabel ~= "" then
            -- Escape any regex special chars in difficulty label
            local escaped = diffLabel:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
            local stripped = rawLabel:match("^" .. escaped .. "%s+(.+)$")
            if stripped and stripped ~= "" then return stripped end
        end
        -- Fallback: strip known English difficulty prefixes
        for _, prefix in ipairs({"Mythic ", "Heroic ", "Normal ", "LFR ", "Looking for Raid "}) do
            if rawLabel:sub(1, #prefix) == prefix then return rawLabel:sub(#prefix + 1) end
        end
        return rawLabel
    end

    local resultInfoByFilterKey = {}
    local shouldPrepopulateFullRaidList = (selectedCategoryKey == "RAIDS_LEGACY")
    if isRaidContext and shouldPrepopulateFullRaidList and C_LFGList and C_LFGList.GetAvailableActivities and C_LFGList.GetActivityInfoTable then
        local categoryID = addonTable.CurrentSearchContext and addonTable.CurrentSearchContext.selectedCategoryID
        if categoryID then
            for _, actID in ipairs(C_LFGList.GetAvailableActivities(categoryID) or {}) do
                local actInfo = C_LFGList.GetActivityInfoTable(actID)
                if actInfo then
                    local actMode = GetListingMode(actInfo)
                    if actMode == "raid" or actMode == "legacy_raid" or actMode == "open_world" then
                        local rawLabel = CleanActivityLabel(actInfo.fullName or actInfo.shortName or "")
                        local label = rawLabel
                        if actMode ~= "open_world" then
                            local inferredDiff = actInfo.shortName or ""
                            label = StripRaidDifficultyPrefix(rawLabel, inferredDiff)
                        end
                        local filterKey = NormalizeSearchScoreTargetLabel(label)
                        if label ~= "" and filterKey ~= "" and not seen[filterKey] then
                            seen[filterKey] = true
                            resultInfoByFilterKey[filterKey] = {
                                activityID = actID,
                                activityInfo = actInfo,
                            }
                            table.insert(activityEntries, {
                                activityID = actID,
                                label = label,
                                filterKey = filterKey,
                                activityInfo = actInfo,
                            })
                        end
                    end
                end
            end
        end
    end

    for _, result in ipairs(addonTable.SearchResults or {}) do
        -- For raid context: include raid/legacy_raid AND open_world (world bosses),
        -- but skip everything else (prevents M+ dungeon names from leaking in).
        local modeOk = not isRaidContext
            or result.mode == "raid"
            or result.mode == "legacy_raid"
            or result.mode == "open_world"

        if modeOk then
            local rawLabel = result.activityFilterLabel or result.activityName or ""
            local label
            if isRaidContext and result.raidListing then
                -- Strip difficulty prefix so "Heroic The Voidspire" → "The Voidspire"
                local diff = result.raidListing.difficultyLabel or ""
                label = StripRaidDifficultyPrefix(rawLabel, diff)
            else
                label = rawLabel
            end
            local filterKey = NormalizeSearchScoreTargetLabel(label)
            if label ~= "" and filterKey ~= "" and not seen[filterKey] then
                seen[filterKey] = true
                local normalizedKey = NormalizeSearchScoreTargetLabel(label)
                table.insert(activityEntries, {
                    activityID   = result.activityID,
                    label        = label,
                    filterKey    = filterKey,
                    activityInfo = result.activityInfo,
                    scoreTarget  = scoreTargets[normalizedKey] or nil,
                })
            elseif isRaidContext and resultInfoByFilterKey[filterKey] and not resultInfoByFilterKey[filterKey].activityInfo then
                resultInfoByFilterKey[filterKey] = {
                    activityID = result.activityID,
                    activityInfo = result.activityInfo,
                }
            end
        end
    end

    if isRaidContext and not shouldPrepopulateFullRaidList and C_LFGList and C_LFGList.GetAvailableActivities and C_LFGList.GetActivityInfoTable then
        local categoryID = addonTable.CurrentSearchContext and addonTable.CurrentSearchContext.selectedCategoryID
        if categoryID then
            for _, actID in ipairs(C_LFGList.GetAvailableActivities(categoryID) or {}) do
                local actInfo = C_LFGList.GetActivityInfoTable(actID)
                if actInfo and GetListingMode(actInfo) == "open_world" then
                    local rawLabel = CleanActivityLabel(actInfo.fullName or actInfo.shortName or "")
                    local filterKey = NormalizeSearchScoreTargetLabel(rawLabel)
                    if rawLabel ~= "" and filterKey ~= "" and not seen[filterKey] then
                        seen[filterKey] = true
                        table.insert(activityEntries, {
                            activityID = actID,
                            label = rawLabel,
                            filterKey = filterKey,
                            activityInfo = actInfo,
                        })
                    end
                end
            end
        end
    end

    if isRaidContext and selectedCategoryKey and selectedCategoryKey ~= "RAIDS_LEGACY" then
        local cachedEntries = addonTable.BrowserActivityCache[selectedCategoryKey] or {}
        for _, cachedEntry in ipairs(cachedEntries) do
            local filterKey = cachedEntry and cachedEntry.filterKey or nil
            if filterKey and filterKey ~= "" and not seen[filterKey] then
                seen[filterKey] = true
                table.insert(activityEntries, {
                    activityID = cachedEntry.activityID,
                    label = cachedEntry.label,
                    filterKey = filterKey,
                    activityInfo = cachedEntry.activityInfo,
                })
            end
        end
    end

    table.sort(activityEntries, function(a, b)
        return (a.label or "") < (b.label or "")
    end)

    if isRaidContext and selectedCategoryKey and selectedCategoryKey ~= "RAIDS_LEGACY" then
        local cacheEntries = {}
        for _, entry in ipairs(activityEntries) do
            cacheEntries[#cacheEntries + 1] = {
                activityID = entry.activityID,
                label = entry.label,
                filterKey = entry.filterKey,
                activityInfo = entry.activityInfo,
            }
        end
        addonTable.BrowserActivityCache[selectedCategoryKey] = cacheEntries
    end

    addonTable._availableBrowserActivitiesCache = { key = cacheKey, entries = activityEntries }
    return activityEntries
end

local function BuildSelectedActivityIDFilter()
    local filters = addonTable.GetCharacterBrowserFilters and addonTable.GetCharacterBrowserFilters() or nil
    if type(filters) ~= "table" or type(filters.selectedActivities) ~= "table" then
        return nil
    end

    local selectedActivityIDs = {}
    local selectedActivityIDSet = {}
    local selectedGroupIDs = {}
    local activities = addonTable.GetAvailableBrowserActivities and addonTable.GetAvailableBrowserActivities() or {}
    for _, entry in ipairs(activities) do
        if filters.selectedActivities[entry.filterKey] then
            local groupID = addonTable.ResolveActivityGroupID and addonTable.ResolveActivityGroupID(entry.activityInfo) or nil
            if groupID and groupID > 0 then
                selectedGroupIDs[groupID] = true
            end

            local activityID = tonumber(entry.activityID)
            if activityID and activityID > 0 then
                selectedActivityIDSet[activityID] = true
            end
        end
    end

    -- The checkbox list stores one representative activity per dungeon label, but
    -- Blizzard's Search activityIDsFilter needs concrete activity IDs. Include all
    -- available activities that belong to each selected dungeon group so the first
    -- post-login search does not depend on Blizzard's filter panel being opened.
    local context = addonTable.CurrentSearchContext or {}
    local categoryID = context.categoryID or context.selectedCategoryID
    if categoryID and C_LFGList and C_LFGList.GetAvailableActivities and C_LFGList.GetActivityInfoTable then
        for _, activityID in ipairs(C_LFGList.GetAvailableActivities(categoryID) or {}) do
            local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
            local groupID = addonTable.ResolveActivityGroupID and addonTable.ResolveActivityGroupID(activityInfo) or nil
            if (groupID and selectedGroupIDs[groupID])
                or selectedActivityIDSet[activityID]
            then
                selectedActivityIDSet[activityID] = true
            end
        end
    end

    for activityID in pairs(selectedActivityIDSet) do
        selectedActivityIDs[#selectedActivityIDs + 1] = activityID
    end

    table.sort(selectedActivityIDs)

    if #selectedActivityIDs == 0 then
        return nil
    end

    return selectedActivityIDs
end

local function HasSelectedActivityFilter()
    local filters = addonTable.GetCharacterBrowserFilters and addonTable.GetCharacterBrowserFilters() or nil
    if type(filters) ~= "table" or type(filters.selectedActivities) ~= "table" then
        return false
    end

    for _, selected in pairs(filters.selectedActivities) do
        if selected then
            return true
        end
    end

    return false
end

local function EnsureBlizzardSearchPanelForCategory(categoryID, selection)
    if UIParentLoadAddOn then
        pcall(UIParentLoadAddOn, "Blizzard_GroupFinder")
    end

    local panel = LFGListFrame and LFGListFrame.SearchPanel
    if not panel then
        return nil
    end

    local filters = (selection and selection.filters) or 0
    local preferredFilters = (selection and selection.preferredFilters) or 0

    panel.selectedCategory = categoryID
    panel.categoryID = categoryID
    panel.selectedFilters = filters
    panel.filters = filters
    panel.preferredFilters = preferredFilters
    panel.languageFilter = selection and selection.languageFilter or panel.languageFilter
    panel.searchCrossFactionListings = selection and selection.searchCrossFactionListings or panel.searchCrossFactionListings

    if type(panel.SetCategory) == "function" then
        pcall(panel.SetCategory, panel, categoryID, filters, preferredFilters)
    end
    if type(LFGListSearchPanel_SetCategory) == "function" then
        pcall(LFGListSearchPanel_SetCategory, panel, categoryID, filters, preferredFilters)
    end
    if type(panel.UpdateResultList) == "function" then
        pcall(panel.UpdateResultList, panel)
    end

    return panel
end

function addonTable.RunBrowserSearch()
    if not (C_LFGList and C_LFGList.Search) then
        return false, "Search API unavailable"
    end

    local context = addonTable.UpdateSearchContext()
    local selection = context and context.searchSelection or nil
    local categoryID = context and (context.categoryID or context.selectedCategoryID) or nil
    local categoryKey = context and context.selectedCategoryKey or nil
    local advancedFilter = nil
    local panel = LFGListFrame and LFGListFrame.SearchPanel
    local languageFilter = selection and selection.languageFilter

    if not categoryID then
        return false, "No search category selected."
    end

    if categoryKey == "RAIDS_LEGACY" then
        return false, "Legacy raid searches must be loaded through Blizzard's panel."
    end

    if categoryKey == "DUNGEONS" then
        if addonTable.SyncBrowserNativeAdvancedFilters then
            addonTable.SyncBrowserNativeAdvancedFilters()
        elseif addonTable.SyncBrowserNativeActivities then
            addonTable.SyncBrowserNativeActivities()
        end
        panel = EnsureBlizzardSearchPanelForCategory(categoryID, selection) or panel
    end

    -- Keep this in the direct-search path as well as in the context snapshot:
    -- Blizzard's saved language filter is the source of truth, even when the
    -- search panel was loaded after Oak built its context.
    local liveLanguageFilter = GetCurrentSearchLanguageFilter(panel)
    if liveLanguageFilter then
        languageFilter = liveLanguageFilter
    end

    if C_LFGList.GetAdvancedFilter then
        local ok, adv = pcall(C_LFGList.GetAdvancedFilter)
        if ok and type(adv) == "table" then
            advancedFilter = adv
        end
    end

    -- Use the native Blizzard search-panel path only after that panel is actually
    -- initialized and when there is no Oak-persisted activity filter to carry.
    -- On login/reload a hidden panel can exist but still ignore the saved dungeon
    -- activity filter, which causes Oak to receive all dungeons and post-filter.
    if panel and categoryKey == "DUNGEONS" and not HasSelectedActivityFilter() and type(LFGListSearchPanel_DoSearch) == "function" then
        local ok, err = pcall(LFGListSearchPanel_DoSearch, panel)
        if ok then
            return true
        end
        return false, tostring(err)
    end

    -- For other categories, prefer Blizzard's own search routine when Blizzard is
    -- already on the same category. This preserves internal state Oak does not own.
    if categoryKey ~= "DUNGEONS" and panel and (panel.selectedCategory or panel.categoryID) == categoryID and type(LFGListSearchPanel_DoSearch) == "function" then
        local ok, err = pcall(LFGListSearchPanel_DoSearch, panel)
        if ok then
            return true
        end
        return false, tostring(err)
    end

    local success, err = pcall(
        C_LFGList.Search,
        categoryID,
        (selection and selection.filters) or 0,
        (selection and selection.preferredFilters) or 0,
        languageFilter,
        selection and selection.searchCrossFactionListings or false,
        advancedFilter,
        (categoryKey == "DUNGEONS" and BuildSelectedActivityIDFilter()) or nil
    )

    if not success then
        return false, tostring(err)
    end

    return true
end

function addonTable.RefreshBrowserSearchFromOpen()
    if currentViewMode ~= "browser"
            or not OAK_LFG:IsShown()
            or (C_LFGList and C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo()) then
        return false
    end

    addonTable._manualBrowserRefreshInProgress = true
    local ok = addonTable.RunBrowserSearch and select(1, addonTable.RunBrowserSearch()) == true
    if ok then
        ScheduleSearchRefresh()
        C_Timer.After(0.35, function()
            if currentViewMode ~= "browser"
                    or not OAK_LFG:IsShown()
                    or (C_LFGList and C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo()) then
                return
            end
            if addonTable.FetchSearchResultData then
                addonTable.FetchSearchResultData()
            end
            if addonTable.UpdateDisplay then
                addonTable.UpdateDisplay()
            end
        end)
    else
        addonTable._manualBrowserRefreshInProgress = nil
        if addonTable.FetchSearchResultData then
            addonTable.FetchSearchResultData()
        end
        if addonTable.UpdateDisplay then
            addonTable.UpdateDisplay()
        end
    end

    return ok
end

function addonTable.OpenGroupFinderForOak()
    if UIParentLoadAddOn then
        pcall(UIParentLoadAddOn, "Blizzard_GroupFinder")
    end

    if addonTable.SetBrowserCategory then
        addonTable.SetBrowserCategory((addonTable.GetCharacterBrowserCategoryKey and addonTable.GetCharacterBrowserCategoryKey()) or "DUNGEONS")
    end
end

local function TryShowPVEFramePanel(panelName, targetFrameName)
    if type(PVEFrame_ShowFrame) == "function" then
        local ok = pcall(PVEFrame_ShowFrame, panelName, targetFrameName)
        if ok then
            return true
        end
    end

    if type(PVEFrame_ToggleFrame) == "function" then
        local ok = pcall(PVEFrame_ToggleFrame, panelName, targetFrameName)
        if ok then
            return true
        end
    end

    return false
end

local function ShowNamedFrame(frameName)
    local frame = frameName and _G[frameName]
    if not frame then
        return false
    end

    if type(ShowUIPanel) == "function" then
        local ok = pcall(ShowUIPanel, frame)
        if ok then
            return true
        end
    end

    local ok = pcall(frame.Show, frame)
    return ok and true or false
end

function addonTable.OpenBlizzardFinderPanel(panelKey)
    if UIParentLoadAddOn then
        pcall(UIParentLoadAddOn, "Blizzard_GroupFinder")
        if panelKey == "pvp" then
            pcall(UIParentLoadAddOn, "Blizzard_PVPUI")
        end
    end

    local opened = false

    if panelKey == "dungeon" then
        opened = TryShowPVEFramePanel("GroupFinderFrame", "LFDParentFrame")
        if not opened then
            opened = ShowNamedFrame("LFDParentFrame")
        end
    elseif panelKey == "raid" then
        opened = TryShowPVEFramePanel("GroupFinderFrame", "RaidFinderFrame")
        if not opened then
            opened = ShowNamedFrame("RaidFinderFrame")
        end
        if not opened then
            opened = ShowNamedFrame("RaidFinderQueueFrame")
        end
    elseif panelKey == "pvp" then
        if type(TogglePVPUI) == "function" then
            local ok = pcall(TogglePVPUI)
            if ok then
                opened = true
            end
        end
        if not opened and type(PVPUIFrame_ShowFrame) == "function" then
            local ok = pcall(PVPUIFrame_ShowFrame, "HonorFrame")
            if ok then
                opened = true
            end
        end
        if not opened then
            opened = ShowNamedFrame("PVPUIFrame")
        end
    end

    if panelKey ~= "pvp" and not opened and PVEFrame then
        if type(ShowUIPanel) == "function" then
            pcall(ShowUIPanel, PVEFrame)
        else
            pcall(PVEFrame.Show, PVEFrame)
        end
    end

    addonTable.activeEmbeddedFinderPanel = panelKey
    if addonTable.UpdateFinderTabs then
        addonTable.UpdateFinderTabs()
    end

    return opened
end

local function TryOpenPremadeGroupListingCategory(categoryKey)
    local config = addonTable.GetBrowserCategoryConfig and addonTable.GetBrowserCategoryConfig(categoryKey)
    if not config or not config.categoryID then
        return false
    end

    if UIParentLoadAddOn then
        pcall(UIParentLoadAddOn, "Blizzard_GroupFinder")
    end

    local function ShowPremadeGroupsFrame()
        if type(PVEFrame_ShowFrame) == "function" then
            if pcall(PVEFrame_ShowFrame, "GroupFinderFrame", "LFGListFrame") then
                return true
            end
            if pcall(PVEFrame_ShowFrame, "GroupFinderFrame") then
                return true
            end
        end

        if LFGListFrame then
            if type(ShowUIPanel) == "function" then
                local ok = pcall(ShowUIPanel, LFGListFrame)
                if ok then
                    return true
                end
            end
            local ok = pcall(LFGListFrame.Show, LFGListFrame)
            if ok then
                return true
            end
        end

        if PVEFrame then
            if type(ShowUIPanel) == "function" then
                pcall(ShowUIPanel, PVEFrame)
            else
                pcall(PVEFrame.Show, PVEFrame)
            end
        end

        return false
    end

    ShowPremadeGroupsFrame()

    local function ClickFrameButton(button)
        if not button then
            return false
        end
        if button.Click then
            local ok = pcall(button.Click, button)
            if ok then
                return true
            end
        end
        if button.GetScript then
            local onClick = button:GetScript("OnClick")
            if type(onClick) == "function" then
                local ok = pcall(onClick, button, "LeftButton")
                if ok then
                    return true
                end
            end
        end
        return false
    end

    local function GetButtonLabelText(button)
        if not button then
            return ""
        end

        local candidates = {
            button.Name,
            button.name,
            button.Label,
            button.label,
            button.Text,
            button.text,
            button.NameText,
            button.nameText,
        }

        for _, region in ipairs(candidates) do
            if type(region) == "table" and region.GetText then
                local text = tostring(region:GetText() or "")
                if text ~= "" then
                    return text
                end
            end
        end

        if button.GetText then
            local text = tostring(button:GetText() or "")
            if text ~= "" then
                return text
            end
        end

        return ""
    end

    local function NormalizeLabel(text)
        text = strlower(tostring(text or ""))
        text = text:gsub("%s+", " ")
        text = text:gsub("^%s+", ""):gsub("%s+$", "")
        return text
    end

    local function GetDesiredTopLevelTabLabel()
        if categoryKey == "RBG" or categoryKey == "ARENA" then
            return NormalizeLabel(PVP or "Player vs. Player"), NormalizeLabel("Player vs. Player")
        end
        return NormalizeLabel(DUNGEONS_AND_RAIDS or "Dungeons & Raids"), NormalizeLabel("Dungeons & Raids")
    end

    local function GetDesiredPremadeCategoryLabels()
        local aliases = {}
        local desired = {
            DUNGEONS = { "Dungeons" },
            RAIDS_MIDNIGHT = { "Raids - Midnight", "Raids - Current" },
            RAIDS_LEGACY = { "Raids - Legacy" },
            DELVES = { "Delves" },
            QUESTING = { "Questing" },
            CUSTOM = { "Custom" },
            RBG = { "Rated Battleground", "RBG", "Battlegrounds" },
            ARENA = { "Arena" },
        }

        for _, label in ipairs(desired[categoryKey] or { config.label }) do
            aliases[NormalizeLabel(label)] = true
        end

        return aliases
    end

    local function ClickTopLevelGroupFinderTab()
        local desiredA, desiredB = GetDesiredTopLevelTabLabel()
        for index = 1, 5 do
            local button = _G["PVEFrameTab" .. index]
            local label = NormalizeLabel(GetButtonLabelText(button))
            if label ~= "" and (label == desiredA or label == desiredB) then
                if ClickFrameButton(button) then
                    return true
                end
            end
        end
        return false
    end

    local function ClickPremadeGroupsButton()
        local premadeText = strlower(tostring(PREMADE_GROUPS or "Premade Groups"))
        local fallbackMatch = "premade"

        for index = 1, 8 do
            local button = _G["GroupFinderFrameGroupButton" .. index] or (GroupFinderFrame and GroupFinderFrame["groupButton" .. index])
            local label = strlower(GetButtonLabelText(button))
            if label ~= "" and (label == premadeText or label:find(fallbackMatch, 1, true)) then
                if ClickFrameButton(button) then
                    return true
                end
            end
        end

        if GroupFinderFrameGroupButton3 and ClickFrameButton(GroupFinderFrameGroupButton3) then
            return true
        end

        if LFGListFrame then
            if type(ShowUIPanel) == "function" then
                pcall(ShowUIPanel, LFGListFrame)
            else
                pcall(LFGListFrame.Show, LFGListFrame)
            end
            return true
        end

        return false
    end

    local function ForcePvpPremadeGroups()
        if not (categoryKey == "RBG" or categoryKey == "ARENA") then
            return false
        end

        ClickTopLevelGroupFinderTab()

        local success = ClickPremadeGroupsButton()
        if success then
            return true
        end

        local pvpFrame = GroupFinderFrame and GroupFinderFrame.GroupButton4 and GroupFinderFrame.GroupButton4:GetParent()
        if pvpFrame and pvpFrame.PremadeGroupButton then
            return ClickFrameButton(pvpFrame.PremadeGroupButton)
        end

        return false
    end

    local function ResetToCategorySelection()
        local entryCreation = LFGListFrame and LFGListFrame.EntryCreation
        if entryCreation and entryCreation:IsShown() then
            local cancelButton = entryCreation.CancelButton or entryCreation.BackButton
            if cancelButton then
                ClickFrameButton(cancelButton)
            end
        end

        local searchPanel = LFGListFrame and LFGListFrame.SearchPanel
        if searchPanel and searchPanel:IsShown() then
            local backButton = searchPanel.BackButton or searchPanel.CancelButton
            if backButton then
                ClickFrameButton(backButton)
            end
        end
    end

    ClickTopLevelGroupFinderTab()
    ResetToCategorySelection()
    if categoryKey == "RBG" or categoryKey == "ARENA" then
        ForcePvpPremadeGroups()
    else
        ClickPremadeGroupsButton()
    end

    local function applyCategorySelection(skipReset)
        ClickTopLevelGroupFinderTab()
        if not skipReset then
            ResetToCategorySelection()
        end
        if categoryKey == "RBG" or categoryKey == "ARENA" then
            ForcePvpPremadeGroups()
        end
        local categorySelection = LFGListFrame and LFGListFrame.CategorySelection
        if not categorySelection then
            return false
        end

        if categorySelection.Show and not categorySelection:IsShown() then
            pcall(categorySelection.Show, categorySelection)
        end

        -- Try mixin method form first (WoW 12.x uses LFGListCategorySelectionMixin:SelectCategory),
        -- then fall back to the legacy global function.
        if type(categorySelection.SelectCategory) == "function" then
            pcall(categorySelection.SelectCategory, categorySelection, config.categoryID, config.filters or 0)
        end
        if type(LFGListCategorySelection_SelectCategory) == "function" then
            pcall(LFGListCategorySelection_SelectCategory, categorySelection, config.categoryID, config.filters or 0)
        end
        if categorySelection.selectedCategory == nil then
            categorySelection.selectedCategory = config.categoryID
        end
        if categorySelection.selectedFilters == nil then
            categorySelection.selectedFilters = config.filters or 0
        end

        -- Trigger the StartGroupButton state update so it reflects the new selection.
        if type(categorySelection.UpdateStartButton) == "function" then
            pcall(categorySelection.UpdateStartButton, categorySelection)
        elseif type(LFGListCategorySelection_UpdateStartButton) == "function" then
            pcall(LFGListCategorySelection_UpdateStartButton, categorySelection)
        end

        local clickedCategoryButton = false
        local categoryButtons = categorySelection.CategoryButtons
        local aliases = GetDesiredPremadeCategoryLabels()
        if type(categoryButtons) == "table" then
            for _, categoryButton in pairs(categoryButtons) do
                if categoryButton then
                    local buttonLabel = NormalizeLabel(GetButtonLabelText(categoryButton))
                    if aliases[buttonLabel] then
                        clickedCategoryButton = ClickFrameButton(categoryButton) or clickedCategoryButton
                        break
                    end
                end
            end
        end

        if LFGListFrame and LFGListFrame.EntryCreation and LFGListFrame.EntryCreation:IsShown() then
            return true
        end

        local startButton = categorySelection.StartGroupButton or categorySelection.FindGroupButton or _G["LFGListFrameCategorySelectionStartGroupButton"] or _G["LFGListFrameCategorySelectionFindGroupButton"]
        -- Restore the first post-handoff behavior:
        -- • allow Blizzard-disabled buttons to be force-clicked after selection refresh
        -- • skip Legacy Raids entirely because category 114 crashes EntryCreation
        -- • only require available activities for PvP categories
        local startButtonSafe = startButton ~= nil and categoryKey ~= "RAIDS_LEGACY"
        if startButtonSafe and (categoryKey == "RBG" or categoryKey == "ARENA") then
            local ok, avail = pcall(function()
                return C_LFGList and C_LFGList.GetAvailableActivities and C_LFGList.GetAvailableActivities(config.categoryID) or {}
            end)
            startButtonSafe = ok and type(avail) == "table" and #avail > 0
        end
        if startButtonSafe and startButton.SetEnabled and startButton.IsEnabled and not startButton:IsEnabled() then
            pcall(startButton.SetEnabled, startButton, true)
        end
        if startButtonSafe and ClickFrameButton(startButton) then
            if LFGListFrame and LFGListFrame.EntryCreation and LFGListFrame.EntryCreation:IsShown() then
                return true
            end
        end

        -- Fall through to the EntryCreation direct path for all categories including raids/PvP.
        local availableActivities = C_LFGList and C_LFGList.GetAvailableActivities and C_LFGList.GetAvailableActivities(config.categoryID) or nil
        local activityID = type(availableActivities) == "table" and availableActivities[1] or nil

        local entryCreation = LFGListFrame and LFGListFrame.EntryCreation
        if entryCreation and activityID then
            -- Try mixin method forms first (WoW 12.x), then legacy globals.
            if type(entryCreation.OnCategorySelected) == "function" then
                pcall(entryCreation.OnCategorySelected, entryCreation, config.categoryID, config.filters or 0)
            elseif type(LFGListEntryCreation_OnCategorySelected) == "function" then
                pcall(LFGListEntryCreation_OnCategorySelected, entryCreation, config.categoryID, config.filters or 0)
            end

            if type(entryCreation.PopulateActivities) == "function" then
                pcall(entryCreation.PopulateActivities, entryCreation, config.categoryID, config.filters or 0)
            elseif type(LFGListEntryCreation_PopulateActivities) == "function" then
                pcall(LFGListEntryCreation_PopulateActivities, entryCreation, config.categoryID, config.filters or 0)
            end

            if type(entryCreation.Select) == "function" then
                pcall(entryCreation.Select, entryCreation, activityID)
            elseif type(LFGListEntryCreation_Select) == "function" then
                pcall(LFGListEntryCreation_Select, entryCreation, activityID)
            end

            local activityFinder = entryCreation.ActivityFinder or LFGListFrame.EntryCreationActivityFinder
            if activityFinder then
                if type(LFGListEntryCreationActivityFinder_Show) == "function" then
                    pcall(LFGListEntryCreationActivityFinder_Show, activityFinder, entryCreation)
                end
                if type(LFGListEntryCreationActivityFinder_Select) == "function" then
                    pcall(LFGListEntryCreationActivityFinder_Select, activityFinder, activityID)
                end
                if type(LFGListEntryCreationActivityFinder_Accept) == "function" then
                    pcall(LFGListEntryCreationActivityFinder_Accept, activityFinder)
                end
            end

            if entryCreation:IsShown() then
                return true
            end
        end

        return clickedCategoryButton or (activityID ~= nil)
    end

    if applyCategorySelection() then
        return true
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function() applyCategorySelection(true) end)
        C_Timer.After(0.20, function() applyCategorySelection(true) end)
        C_Timer.After(0.50, function() applyCategorySelection(true) end)
    end

    return true
end

function addonTable.OpenBlizzardListingPanel(categoryKey)
    return TryOpenPremadeGroupListingCategory(categoryKey)
end

function addonTable.OpenCurrentListingForEdit()
    if UIParentLoadAddOn then
        pcall(UIParentLoadAddOn, "Blizzard_GroupFinder")
    end

    if PVEFrame and not PVEFrame:IsShown() then
        if type(PVEFrame_ShowFrame) == "function" then
            pcall(PVEFrame_ShowFrame, "GroupFinderFrame", "PVEListFrame")
        elseif type(ShowUIPanel) == "function" then
            pcall(ShowUIPanel, PVEFrame)
        else
            pcall(PVEFrame.Show, PVEFrame)
        end
    end

    local editButton = PVEFrame and PVEFrame.ApplicationViewer and PVEFrame.ApplicationViewer.EditButton
        or LFGListFrame and LFGListFrame.ApplicationViewer and LFGListFrame.ApplicationViewer.EditButton
        or PVEFrame and PVEFrame.LFGListFrame and PVEFrame.LFGListFrame.ApplicationViewer and PVEFrame.LFGListFrame.ApplicationViewer.EditButton

    if editButton and editButton.Click then
        local ok = pcall(editButton.Click, editButton)
        if ok then
            return true
        end
    end

    local categoryKey = addonTable.GetCurrentListingCategoryKey and addonTable.GetCurrentListingCategoryKey() or nil
    if categoryKey then
        return TryOpenPremadeGroupListingCategory(categoryKey)
    end
    return false
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
                if addonTable.ClearDeclinedSearchResultMemory then
                    addonTable.ClearDeclinedSearchResultMemory(result)
                end
                result.applicationStatus = "applied"
                result.hasSelf = true
                result.isDeclined = false
                result._oakStickyUntilRefresh = true
                result._oakShowDeclinedUntilRefresh = nil
                break
            end
        end
    end
end

-- Convenience helpers so Search_Signup.lua can update the unified SearchResults table
function addonTable.MarkSearchResultApplied(searchResultID)
    addonTable.SearchApplications[searchResultID] = "applied"
    for _, result in ipairs(addonTable.SearchResults or {}) do
        if result.id == searchResultID then
            if addonTable.ClearDeclinedSearchResultMemory then
                addonTable.ClearDeclinedSearchResultMemory(result)
            end
            result.applicationStatus = "applied"
            result.hasSelf = true
            result.isDeclined = false
            result._oakStickyUntilRefresh = true
            result._oakShowDeclinedUntilRefresh = nil
            break
        end
    end
    local OAK_LFG = addonTable.OAK_LFG
    if addonTable.UpdateDisplay and OAK_LFG and OAK_LFG:IsShown() then
        addonTable.UpdateDisplay()
    end
end

function addonTable.MarkSearchResultCanceled(searchResultID)
    addonTable.SearchApplications[searchResultID] = "cancelled"
    for _, result in ipairs(addonTable.SearchResults or {}) do
        if result.id == searchResultID then
            result.applicationStatus = "cancelled"
            result.hasSelf = false
            break
        end
    end
    local OAK_LFG = addonTable.OAK_LFG
    if addonTable.UpdateDisplay and OAK_LFG and OAK_LFG:IsShown() then
        addonTable.UpdateDisplay()
    end
end

function GetPvpBracketLabel(pvpRatingInfo)
    if type(pvpRatingInfo) ~= "table" then
        return nil
    end
    -- TWW returns leaderPvpRatingInfo as an array; unwrap if needed
    if pvpRatingInfo[1] and type(pvpRatingInfo[1]) == "table" then
        pvpRatingInfo = pvpRatingInfo[1]
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

function addonTable.GetRaidProgressSummary(rioProfile, preferredRaidName, preferredDifficultyToken)
    local raidDataFound = CollectRaidProgress(rioProfile)
    if not raidDataFound then
        return nil
    end

    local preferred = preferredRaidName and strlower(preferredRaidName) or nil
    local bestSummary = nil
    local bestScore = -1

    for raidName, data in pairs(raidDataFound) do
        local selectedDifficultyToken = preferredDifficultyToken
        local selectedCount = GetRaidDifficultyCount(data, selectedDifficultyToken)
        local score

        if selectedDifficultyToken == "NORMAL" or selectedDifficultyToken == "HEROIC" or selectedDifficultyToken == "MYTHIC" then
            score = selectedCount
        else
            score = (data.mythic * 10000) + (data.heroic * 100) + data.normal
            if data.mythic > 0 then
                selectedDifficultyToken = "MYTHIC"
            elseif data.heroic > 0 then
                selectedDifficultyToken = "HEROIC"
            elseif data.normal > 0 then
                selectedDifficultyToken = "NORMAL"
            else
                selectedDifficultyToken = "ANY"
            end
            selectedCount = GetRaidDifficultyCount(data, selectedDifficultyToken)
        end
        local matchesPreferred = preferred and strlower(raidName):find(preferred, 1, true)

        if matchesPreferred then
            score = score + 1000000
        end

        if score > bestScore then
            bestScore = score

            local displayText = "--"
            local selectedDifficultyInfo = GetDifficultyDisplayInfo(selectedDifficultyToken)
            if (selectedDifficultyToken == "NORMAL" or selectedDifficultyToken == "HEROIC" or selectedDifficultyToken == "MYTHIC")
                and (selectedCount > 0 or (tonumber(data.bosses) or 0) > 0)
            then
                displayText = string.format("%s %d/%d", selectedDifficultyInfo.short, selectedCount, tonumber(data.bosses) or 0)
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
                selectedDifficultyToken = selectedDifficultyToken,
                selectedDifficultyShort = selectedDifficultyInfo.short,
                selectedCount = selectedCount,
                bossCount = tonumber(data.bosses) or 0,
            }
        end
    end

    return bestSummary
end

function addonTable.AppendMythicPlusMilestonesToTooltip(tooltip, rioProfile)
    local mPlus = rioProfile and rioProfile.mythicKeystoneProfile
    if type(tooltip) ~= "table" or type(mPlus) ~= "table" then
        return false
    end

    local milestones = mPlus.sortedMilestones
    if type(milestones) ~= "table" or #milestones == 0 then
        return false
    end

    tooltip:AddLine(" ")
    tooltip:AddLine("Raider.IO M+ Score", 1, 0.82, 0)
    for _, milestone in ipairs(milestones) do
        if type(milestone) == "table" and milestone.label and milestone.text then
            tooltip:AddDoubleLine(milestone.label, milestone.text, 1, 1, 1, 1, 1, 1)
        end
    end

    return true
end

local function FetchApplicantData()
    local listingContext = addonTable.UpdateListingContext()
    local listingMode = listingContext and listingContext.mode or "generic"
    local activityID = listingContext and listingContext.activityID or nil
    local activityInfo = listingContext and listingContext.activityInfo or nil
    local entryInfo = listingContext and listingContext.entryInfo or nil
    local preferredRaidName = activityInfo and (activityInfo.shortName or activityInfo.fullName) or nil
    local preferredRaidDifficultyToken = ((listingMode == "raid" or listingMode == "legacy_raid") and GetSearchResultDifficultyToken(entryInfo, activityInfo)) or nil

    wipe(addonTable.ApplicantGroups)
    local applicants = C_LFGList.GetApplicants()
    if not applicants then return end

    for _, applicantID in ipairs(applicants) do
        local info = C_LFGList.GetApplicantInfo(applicantID)
        
        local applicantStatus = NormalizeApplicationStatus(info and (
            info.applicationStatus
            or info.status
            or info.pendingApplicationStatus
            or info.pendingStatus
            or info.applicantStatus
            or "none"
        ) or "none")
        if info and (info.cancelled or info.canceled or info.isCancelled or info.isCanceled) then
            applicantStatus = "cancelled"
        end
        local keepCancelledApplicants = addonTable.GetCharacterBrowserFilters
            and addonTable.GetCharacterBrowserFilters().keepUnavailable ~= false
        local shouldShowApplicant = applicantStatus == "applied"
            or applicantStatus == "invited"
            or applicantStatus == "inviteaccepted"
            or (keepCancelledApplicants and IsCancelledStatus(applicantStatus))
        if info and shouldShowApplicant and info.numMembers > 0 then
            
            local group = {
                id = applicantID,
                numMembers = info.numMembers,
                comment = info.comment,
                members = {},
                applicationStatus = applicantStatus,
            }

            for i = 1, info.numMembers do
                local name, class, _, _, itemLevel, _, tank, healer, damage, _, isFriend, dungeonScore, _, _, _, specID, isLeaver = C_LFGList.GetApplicantMemberInfo(applicantID, i)
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
                    raidProgress = addonTable.GetRaidProgressSummary(rioProfile, preferredRaidName, preferredRaidDifficultyToken)
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
                    isLeaver = isLeaver,
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
            group.leadName = lead.name
            group.regionInfo = addonTable.GetRegionInfoFromLeaderName and addonTable.GetRegionInfoFromLeaderName(lead.name) or nil
            table.insert(addonTable.ApplicantGroups, group)
        end
    end
end

addonTable.FetchApplicantData = FetchApplicantData

OAK_LFG:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
OAK_LFG:RegisterEvent("LFG_LIST_APPLICANT_UPDATED")
OAK_LFG:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
OAK_LFG:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
OAK_LFG:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
OAK_LFG:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")

OAK_LFG:SetScript("OnEvent", function(self, event, ...) 
    local isShown = OAK_LFG:IsShown()

    -- Auto-Close the window when the group is filled or manually delisted
    if event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
        local searchResultID, newStatus = ...
        if searchResultID then
            local normalized = NormalizeApplicationStatus(newStatus or "none")
            local resultInfo = C_LFGList and C_LFGList.GetSearchResultInfo and C_LFGList.GetSearchResultInfo(searchResultID) or nil
            addonTable.SearchApplications[searchResultID] = normalized
            local rememberedDecline = false
            for _, result in ipairs(addonTable.SearchResults or {}) do
                if result.id == searchResultID then
                    if resultInfo then
                        result.partyGUID = resultInfo.partyGUID or result.partyGUID
                        result.leaderName = resultInfo.leaderName or result.leaderName
                        result.activityID = GetSearchResultActivityID(resultInfo, searchResultID) or result.activityID
                    end
                    local wasApplied = IsAppliedStatus(result.applicationStatus) or result.hasSelf == true
                    result.applicationStatus = normalized
                    result.hasSelf = IsAppliedStatus(normalized)
                    result.isDeclined = IsDeclinedStatus(normalized)
                    if result.isDeclined then
                        if addonTable.RememberDeclinedSearchResult then
                            rememberedDecline = addonTable.RememberDeclinedSearchResult(result) or rememberedDecline
                        end
                        result.hiddenByDeclineMemory = true
                        if wasApplied or result._oakStickyUntilRefresh then
                            result._oakStickyUntilRefresh = true
                            result._oakShowDeclinedUntilRefresh = true
                        end
                    elseif addonTable.IsAppliedStatus and addonTable.IsAppliedStatus(normalized) then
                        if addonTable.ClearDeclinedSearchResultMemory then
                            addonTable.ClearDeclinedSearchResultMemory(result)
                        end
                        result._oakStickyUntilRefresh = true
                        result._oakShowDeclinedUntilRefresh = nil
                    end
                    break
                end
            end
            if IsDeclinedStatus(normalized) and not rememberedDecline and resultInfo and addonTable.RememberDeclinedSearchResult then
                addonTable.RememberDeclinedSearchResult({
                    id = searchResultID,
                    partyGUID = resultInfo.partyGUID,
                    activityID = GetSearchResultActivityID(resultInfo, searchResultID) or 0,
                    leaderName = resultInfo.leaderName,
                })
            end
        end
        if isShown then
            ScheduleDisplayRefresh(0)
        end
        return
    elseif event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" then
        -- Auto-open when the Blizzard search panel is visible and autoOpenSearch is on.
        -- This handles category switches where SearchPanel:OnShow doesn't re-fire.
        if OakLFGSorterDB and OakLFGSorterDB.autoOpenSearch and not OAK_LFG:IsShown()
                and not addonTable.userExplicitlyClosed
                and LFGListFrame and LFGListFrame.SearchPanel and LFGListFrame.SearchPanel:IsShown() then
            addonTable.SetCurrentViewMode("browser")
            OAK_LFG:Show()  -- OnShow triggers FetchSearchResultData + UpdateDisplay
            QueueInitialBrowserOpenRefresh()
            return
        end
        if currentViewMode == "browser" and isShown then
            ScheduleSearchRefresh()
        end
        return
    elseif event == "LFG_LIST_SEARCH_RESULT_UPDATED" then
        -- Blizzard fires this once per individual result row. Debounce it, but do
        -- process it: a filled/delisted group can disappear through this event
        -- without a paired SEARCH_RESULTS_RECEIVED, and Oak needs that refresh to
        -- preserve the row until the user manually refreshes.
        if currentViewMode == "browser" and isShown then
            ScheduleSearchRefresh()
        end
        return
    elseif event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
        if C_LFGList.HasActiveEntryInfo() then
            -- Player just created a listing — switch to applicant mode
            addonTable.SetCurrentViewMode("applicant")
        else
            -- Player delisted — switch to browser mode and stay open
            addonTable.SetCurrentViewMode("browser")
            if isShown then
                FetchSearchResultData()
                ScheduleDisplayRefresh(0)
            end
            return
        end
    end

    if not isShown then
        return
    end

    if C_LFGList.HasActiveEntryInfo() then
        ScheduleApplicantRefresh(0)
        return
    else
        FetchSearchResultData()
    end

    ScheduleDisplayRefresh(0)
end)

OAK_LFG:SetScript("OnShow", function(self)
    SetupApplicantPingMuteHook()
    if C_LFGList.HasActiveEntryInfo() then
        addonTable.SetCurrentViewMode("applicant")
        ScheduleApplicantRefresh(0)
    else
        addonTable.SetCurrentViewMode("browser")
        FetchSearchResultData()
        if addonTable.UpdateFilterPaneMode then
            addonTable.UpdateFilterPaneMode()
        end
        QueueInitialBrowserOpenRefresh()
    end
    addonTable.UpdateHeaderVisuals()
    if addonTable.ApplyHideNotesLayout then
        addonTable.ApplyHideNotesLayout()
    else
        addonTable.UpdateDisplay()
    end
    
    if addonTable.CheckRIOHook then addonTable.CheckRIOHook() end
    if addonTable.AutoPosition and not (OakLFGSorterDB and (OakLFGSorterDB.frameUserPlaced or OakLFGSorterDB.framePos)) then
        addonTable.AutoPosition()
    end
    if addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(OAK_LFG)
    end
end)

local VarEventFrame = CreateFrame("Frame")
VarEventFrame:RegisterEvent("ADDON_LOADED")
VarEventFrame:RegisterEvent("PLAYER_LOGIN")
VarEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
VarEventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "ADDON_LOADED" then
        if loadedAddon == addonName then
            SetupApplicantPingMuteHook()
            if addonTable.LFGToggleBox then
                if OakLFGSorterDB.autoOpen then
                    addonTable.LFGToggleBox:SetBackdropColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1) 
                    addonTable.LFGToggleBox:SetBackdropBorderColor(0, 0, 0, 1)
                else
                    addonTable.LFGToggleBox:SetBackdropColor(0.08, 0.08, 0.10, 0.95) 
                    addonTable.LFGToggleBox:SetBackdropBorderColor(addonTable.ClassColor.r * 0.65, addonTable.ClassColor.g * 0.65, addonTable.ClassColor.b * 0.65, 1)
                end
            end
            
            local savedScale = OakLFGSorterDB.scale or 1.0
            OAK_LFG:SetScale(savedScale)
            if addonTable.ScaleSlider then
                addonTable.ScaleSlider:SetValue(savedScale)
            end
            if addonTable.ScaleEdit then
                addonTable.ScaleEdit:SetText(string.format("%.2f", savedScale))
            end

            if OakLFGSorterDB.framePos then 
                OAK_LFG:ClearAllPoints()
                local p = OakLFGSorterDB.framePos
                if #p == 4 then OAK_LFG:SetPoint(p[1], UIParent, p[2], p[3], p[4]) end
            end
            
            if OakLFGSorterDB.frameSize then 
                local savedWidth = tonumber(OakLFGSorterDB.frameSize[1]) or 660
                OakLFGSorterDB.windowWidth = savedWidth
                local minWidth = addonTable.GetTargetFrameWidth and addonTable.GetTargetFrameWidth() or 660
                local w = math.max(minWidth, savedWidth)
                local h = math.max(444, OakLFGSorterDB.frameSize[2])
                OAK_LFG:SetSize(w, h) 
            end

            if addonTable.ApplyHideNotesLayout then
                addonTable.ApplyHideNotesLayout()
            end
            if addonTable.UpdateDisplay then
                addonTable.UpdateDisplay()
            end
            
            if addonTable.SetupBlizzardLFGHook then
                addonTable.SetupBlizzardLFGHook()
            end
        elseif loadedAddon == "Blizzard_LookingForGroupUI" then
            SetupApplicantPingMuteHook()
            if addonTable.SetupBlizzardLFGHook then
                addonTable.SetupBlizzardLFGHook()
            end
        end
    elseif event == "PLAYER_LOGIN" then
        if addonTable.UpdateAuxPanelAnchors then
            addonTable.UpdateAuxPanelAnchors()
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if addonTable.FilterPanel and addonTable.FilterPanel:IsShown() and addonTable.SyncApplicantFilterPanelControls then
            addonTable.SyncApplicantFilterPanelControls()
        end
        if addonTable.BrowserFilterPanel and addonTable.BrowserFilterPanel:IsShown() and addonTable.SyncSharedLowLatencyToggles then
            addonTable.SyncSharedLowLatencyToggles()
        end
        if OAK_LFG:IsShown() and C_LFGList.HasActiveEntryInfo() then
            -- Roster changes can arrive in bursts while applicants are joining
            -- or leaving. Coalesce them with the normal display refresh queue.
            ScheduleDisplayRefresh(0)
        end
    end
end)

OAK_LFG:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self.isOakDragging = false
    if addonTable.ClampFrameToScreen then
        addonTable.ClampFrameToScreen(self, OakLFGSorterDB, "framePos")
    end
    if OakLFGSorterDB then
        OakLFGSorterDB.frameUserPlaced = true
        local left = self:GetLeft()
        local bottom = self:GetBottom()
        if left and bottom then
            OakLFGSorterDB.framePos = {
                "BOTTOMLEFT",
                "BOTTOMLEFT",
                left,
                bottom,
            }
        end
        OakLFGSorterDB.frameSize = { self:GetWidth(), self:GetHeight() }
    end
end)

if addonTable.ResizeGrip then
    addonTable.ResizeGrip:SetScript("OnMouseUp", function(self, button) 
        self._oakResizePending = false
        self._oakResizeStartX = nil
        self._oakResizeStartY = nil
        if self._oakResizeStarted then
            OAK_LFG:StopMovingOrSizing()
        end
        self._oakResizeStarted = false
        OAK_LFG.isOakResizing = false
        if addonTable.ClampFrameToScreen then
            addonTable.ClampFrameToScreen(OAK_LFG, OakLFGSorterDB, "framePos")
        end
        if OakLFGSorterDB then OakLFGSorterDB.frameSize = { OAK_LFG:GetWidth(), OAK_LFG:GetHeight() } end
        if addonTable.GetCurrentViewMode and addonTable.GetCurrentViewMode() == "browser" then
            if addonTable.RefreshBrowserResponsiveLayout then
                addonTable.RefreshBrowserResponsiveLayout()
            end
        else
            if addonTable.UpdateHeaderVisuals then
                addonTable.UpdateHeaderVisuals()
            end
            if addonTable.UpdateDisplay then
                addonTable.UpdateDisplay()
            end
        end
    end)
end

local function OakLFGSorterCommand(msg)
    if msg and msg:lower() == "reset" then
        if OakLFGSorterDB then
            OakLFGSorterDB.framePos = nil
            OakLFGSorterDB.frameUserPlaced = false
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
        if addonTable.ToggleBrowserWindow then
            addonTable.ToggleBrowserWindow()
        else
            addonTable.userExplicitlyClosed = false
            if C_LFGList.HasActiveEntryInfo() then
                if OAK_LFG:IsShown() then OAK_LFG:Hide() else OAK_LFG:Show() end
            elseif addonTable.OAK_SEARCH then
                local OAK_SEARCH = addonTable.OAK_SEARCH
                if OAK_SEARCH:IsShown() then OAK_SEARCH:Hide() else OAK_SEARCH:Show() end
            else
                if OAK_LFG:IsShown() then OAK_LFG:Hide() else OAK_LFG:Show() end
            end
        end
    end
end

SLASH_OAKLFGSORTER1 = "/oaklfg"
SLASH_OAKLFGSORTER2 = "/lfg"
SLASH_OAKLFGSORTER3 = "/sorter"
SLASH_OAKLFGSORTER4 = "/sorterclassic"
SlashCmdList["OAKLFGSORTER"] = OakLFGSorterCommand

function OakLFGSorter_ToggleBrowserWindow()
    if addonTable and addonTable.ToggleBrowserWindow then
        addonTable.ToggleBrowserWindow()
    elseif addonTable and addonTable.OpenOakBrowser then
        addonTable.OpenOakBrowser()
    elseif addonTable and addonTable.OAK_LFG then
        addonTable.userExplicitlyClosed = false
        addonTable.OAK_LFG:Show()
    end
end

SLASH_SORTERPVPDEBUG1 = "/sorterpvpdebug"
SlashCmdList["SORTERPVPDEBUG"] = function()
    local results = addonTable.SearchResults
    if not results or #results == 0 then
        print("|cffff9900OAK PVP Debug:|r No search results cached.")
        return
    end
    local found = false
    for _, r in ipairs(results) do
        if r.mode == "pvp" or r.mode == "rated_pvp" then
            found = true
            print("|cffff9900OAK PVP Debug:|r result.id=" .. tostring(r.id) .. " mode=" .. tostring(r.mode))
            -- Re-fetch fresh info
            local info = C_LFGList.GetSearchResultInfo and C_LFGList.GetSearchResultInfo(r.id)
            if not info then
                print("  GetSearchResultInfo returned nil")
            else
                local pvpInfo = info.leaderPvpRatingInfo
                if pvpInfo == nil then
                    print("  leaderPvpRatingInfo = nil")
                else
                    print("  leaderPvpRatingInfo type = " .. type(pvpInfo))
                    if type(pvpInfo) == "table" then
                        for k, v in pairs(pvpInfo) do
                            print("    [" .. tostring(k) .. "] = " .. tostring(v))
                            if type(v) == "table" then
                                for k2, v2 in pairs(v) do
                                    print("      [" .. tostring(k2) .. "] = " .. tostring(v2))
                                end
                            end
                        end
                    else
                        print("  leaderPvpRatingInfo = " .. tostring(pvpInfo))
                    end
                end
            end
            break
        end
    end
    if not found then
        print("|cffff9900OAK PVP Debug:|r No PVP results found in cache.")
    end
end

