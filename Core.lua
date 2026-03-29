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

local function FetchApplicantData()
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
                    memberIdx = i 
                }
                table.insert(group.members, member)
            end
            local lead = group.members[1]
            group.leadClass = lead.class; group.leadRole = lead.role; group.leadSpec = lead.specID; group.leadIlvl = lead.ilvl; group.leadRating = lead.rating; group.leadKey = lead.highestKey
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
    addonTable.UpdateDisplay()
    
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
                local w = math.max(660, OakLFGSorterDB.frameSize[1])
                OAK_LFG:SetSize(w, OakLFGSorterDB.frameSize[2]) 
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
