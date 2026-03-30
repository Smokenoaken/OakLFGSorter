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

    local activityID = entryInfo.activityID
    if (not activityID or activityID == 0) and type(entryInfo.activityIDs) == "table" then
        activityID = entryInfo.activityIDs[1]
    end

    return activityID, entryInfo
end

local function GetListingMode(activityInfo)
    if not activityInfo then
        return "generic"
    end

    local fullName = strlower(activityInfo.fullName or "")
    local shortName = strlower(activityInfo.shortName or "")
    local activityText = fullName .. " " .. shortName

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
    elseif activityText:find("delve", 1, true) then
        return "delve"
    elseif activityText:find("world", 1, true) or activityText:find("outdoor", 1, true) then
        return "open_world"
    end

    return "generic"
end

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

local function GetPvpBracketLabel(pvpRatingInfo)
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
                local role = "DAMAGER"
                if tank then role = "TANK" elseif healer then role = "HEALER" end

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

OAK_LFG:SetScript("OnEvent", function(self, event, ...) 
    -- Auto-Close the window when the group is filled or manually delisted
    if event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
        if not C_LFGList.HasActiveEntryInfo() then
            OAK_LFG:Hide()
            return
        end
    end

    FetchApplicantData()
    if OAK_LFG:IsShown() then addonTable.UpdateDisplay() end 
end)

OAK_LFG:SetScript("OnShow", function(self) 
    SetupApplicantPingMuteHook()
    FetchApplicantData()
    addonTable.UpdateHeaderVisuals()
    if addonTable.ApplyHideNotesLayout then
        addonTable.ApplyHideNotesLayout()
    else
        addonTable.UpdateDisplay()
    end
    
    if addonTable.CheckRIOHook then addonTable.CheckRIOHook() end
    if addonTable.AutoPosition then addonTable.AutoPosition() end
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
                OAK_LFG:SetSize(w, OakLFGSorterDB.frameSize[2]) 
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
        end
        if addonTable.ScaleSlider then addonTable.ScaleSlider:SetValue(1.0) end
        if addonTable.AutoPosition then addonTable.AutoPosition() end
        OAK_LFG:Show()
        print("|cFF00FF00Oak LFG Sorter:|r Window position and scale reset.")
    else
        if OAK_LFG:IsShown() then OAK_LFG:Hide() else OAK_LFG:Show() end
    end
end
