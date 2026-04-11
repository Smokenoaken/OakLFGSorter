local addonName, addonTable = ...

local OAK_LFG = addonTable.OAK_LFG
if not OAK_LFG then
    return
end

local function GetTeleportSpellID(mapID)
    if _G.QUI_DungeonData and _G.QUI_DungeonData.GetTeleportSpellID then
        return _G.QUI_DungeonData.GetTeleportSpellID(mapID)
    end
    return nil
end

local VAULT_TYPE_RAID = Enum and Enum.WeeklyRewardChestThresholdType and Enum.WeeklyRewardChestThresholdType.Raid
local VAULT_TYPE_ACTIVITIES = Enum and Enum.WeeklyRewardChestThresholdType and Enum.WeeklyRewardChestThresholdType.Activities
local VAULT_TYPE_WORLD = Enum and Enum.WeeklyRewardChestThresholdType and Enum.WeeklyRewardChestThresholdType.World

local TYPE_LABELS = {}
local TYPE_ORDER = {}

if VAULT_TYPE_RAID then
    TYPE_LABELS[VAULT_TYPE_RAID] = WEEKLY_REWARDS_CATEGORY_RAID or RAIDS
    TYPE_ORDER[#TYPE_ORDER + 1] = VAULT_TYPE_RAID
end
if VAULT_TYPE_ACTIVITIES then
    TYPE_LABELS[VAULT_TYPE_ACTIVITIES] = WEEKLY_REWARDS_CATEGORY_DUNGEON or WEEKLY_REWARDS_CATEGORY_DUNGEONS or DUNGEONS
    TYPE_ORDER[#TYPE_ORDER + 1] = VAULT_TYPE_ACTIVITIES
end
if VAULT_TYPE_WORLD then
    TYPE_LABELS[VAULT_TYPE_WORLD] = WEEKLY_REWARDS_CATEGORY_WORLD or WORLD
    TYPE_ORDER[#TYPE_ORDER + 1] = VAULT_TYPE_WORLD
end

local function OpenWeeklyRewardsUI()
    if C_AddOns and C_AddOns.IsAddOnLoaded and not C_AddOns.IsAddOnLoaded("Blizzard_WeeklyRewards") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_WeeklyRewards")
    end

    if WeeklyRewardsFrame and WeeklyRewardsFrame.Show then
        if WeeklyRewardsFrame:IsShown() then
            pcall(WeeklyRewardsFrame.Show, WeeklyRewardsFrame)
        elseif type(ShowUIPanel) == "function" then
            pcall(ShowUIPanel, WeeklyRewardsFrame)
        else
            pcall(WeeklyRewardsFrame.Show, WeeklyRewardsFrame)
        end
    elseif type(WeeklyRewards_ShowUI) == "function" then
        pcall(WeeklyRewards_ShowUI)
    end
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end
    local ok, a, b, c, d = pcall(func, ...)
    if not ok then
        return nil
    end
    return a, b, c, d
end

local function GetScoreColor(score)
    if RaiderIO and RaiderIO.GetScoreColor then
        local r, g, b = RaiderIO.GetScoreColor(score)
        if r and g and b then
            return r, g, b
        end
    end
    if C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor then
        local color = C_ChallengeMode.GetDungeonScoreRarityColor(score or 0)
        if color then
            return color.r or 1, color.g or 1, color.b or 1
        end
    end
    return 1, 1, 1
end

local function GetCurrentScore()
    local summary = SafeCall(C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary, "player")
    local score = tonumber(summary and summary.currentSeasonScore) or 0
    return math.floor(score + 0.5)
end

local function GetOwnedKeyText()
    local level = SafeCall(C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel)
    local mapID = SafeCall(C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID)
    if not level or level <= 0 then
        return "No key"
    end
    local mapName = mapID and SafeCall(C_ChallengeMode and C_ChallengeMode.GetMapUIInfo, mapID)
    if mapName and mapName ~= "" then
        return string.format("+%d %s", level, mapName)
    end
    return string.format("+%d", level)
end

local function GetCurrentAffixData()
    local affixes = SafeCall(C_MythicPlus and C_MythicPlus.GetCurrentAffixes) or {}
    local results = {}
    if type(affixes) ~= "table" then
        return results
    end
    for _, affix in ipairs(affixes) do
        local affixID = tonumber(type(affix) == "table" and affix.id or affix)
        if affixID then
            local name, description = SafeCall(C_ChallengeMode and C_ChallengeMode.GetAffixInfo, affixID)
            local icon = SafeCall(C_ChallengeMode and C_ChallengeMode.GetAffixInfo, affixID)
            local _, _, affixTexture = nil, nil, nil
            if C_ChallengeMode and C_ChallengeMode.GetAffixInfo then
                local a, b, c = C_ChallengeMode.GetAffixInfo(affixID)
                name, description, affixTexture = a, b, c
            end
            table.insert(results, {
                id = affixID,
                name = name or ("Affix " .. affixID),
                description = description or "",
                texture = affixTexture,
            })
        end
    end
    return results
end

local function FormatDuration(seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then
        return "--:--"
    end
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", mins, secs)
end

local function ExtractBestMapData(mapScores, bestOverallScore)
    local bestLevel = 0
    local bestDuration = nil
    local bestOvertime = false
    if type(mapScores) == "table" then
        for _, info in ipairs(mapScores) do
            if type(info) == "table" then
                local level = tonumber(info.level or info.bestRunLevel or info.challengeLevel or info.keystoneLevel) or 0
                if level > bestLevel then
                    bestLevel = level
                    bestDuration = tonumber(info.durationSec or info.duration or info.bestRunDurationSec or info.time or info.mapScoreDurationSec)
                    bestOvertime = info.completedInTime == false or info.overTime == true or info.isOvertime == true
                end
            end
        end
    end
    return {
        level = bestLevel,
        duration = bestDuration,
        score = tonumber(bestOverallScore) or 0,
        overtime = bestOvertime,
    }
end

local function GetDungeonRows()
    local rows = {}
    local mapIDs = SafeCall(C_ChallengeMode and C_ChallengeMode.GetMapTable) or {}
    if type(mapIDs) ~= "table" then
        return rows
    end
    for _, mapID in ipairs(mapIDs) do
        local name = SafeCall(C_ChallengeMode and C_ChallengeMode.GetMapUIInfo, mapID)
        if name and name ~= "" then
            local mapScores, bestOverallScore = SafeCall(C_MythicPlus and C_MythicPlus.GetSeasonBestAffixScoreInfoForMap, mapID)
            local data = ExtractBestMapData(mapScores, bestOverallScore)
            table.insert(rows, {
                name = name,
                mapID = mapID,
                level = data.level,
                duration = data.duration,
                score = math.floor((data.score or 0) + 0.5),
                overtime = data.overtime,
            })
        end
    end
    table.sort(rows, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
    return rows
end

local function GetVaultRows()
    local entries = {}
    local activities = SafeCall(C_WeeklyRewards and C_WeeklyRewards.GetActivities)
    if type(activities) ~= "table" then
        return entries
    end

    local byType = {}
    for _, activity in ipairs(activities) do
        if type(activity) == "table" then
            local typeId = activity.type
            if typeId then
                byType[typeId] = byType[typeId] or {}
                table.insert(byType[typeId], activity)
            end
        end
    end

    local function IsActivityUnlocked(activity)
        local progress = activity and activity.progress or 0
        local threshold = activity and activity.threshold or 0
        return threshold > 0 and progress >= threshold
    end

    local function GetActivityByIndex(activityList, index)
        for _, activity in ipairs(activityList or {}) do
            if activity.index == index then
                return activity
            end
        end
    end

    local function FormatSlotValue(typeId, activity)
        if not IsActivityUnlocked(activity) then
            local progress = activity and activity.progress or 0
            local threshold = activity and activity.threshold or 0
            if threshold > 0 then
                return string.format("%d/%d", progress, threshold)
            end
            return "-"
        end

        if typeId == VAULT_TYPE_RAID then
            local diffName = activity and activity.level and DifficultyUtil and DifficultyUtil.GetDifficultyName and DifficultyUtil.GetDifficultyName(activity.level)
            return diffName or "-"
        end

        if typeId == VAULT_TYPE_ACTIVITIES then
            if activity and activity.level ~= nil then
                return string.format(WEEKLY_REWARDS_MYTHIC or "M+%d", activity.level)
            end
            return WEEKLY_REWARDS_HEROIC or "Heroic"
        end

        if typeId == VAULT_TYPE_WORLD then
            if activity and activity.level and activity.level > 0 then
                return string.format(GREAT_VAULT_WORLD_TIER or "Tier %d", activity.level)
            end
        end

        return "-"
    end

    local function BuildSlotSummary(typeId, activityList)
        local values = {}
        for index = 1, 3 do
            values[index] = FormatSlotValue(typeId, GetActivityByIndex(activityList, index))
        end
        return table.concat(values, " | ")
    end

    for _, typeId in ipairs(TYPE_ORDER) do
        if typeId then
            local activityList = byType[typeId] or {}
            table.sort(activityList, function(a, b)
                return (a.index or 0) < (b.index or 0)
            end)
            table.insert(entries, {
                label = TYPE_LABELS[typeId] or "",
                summary = BuildSlotSummary(typeId, activityList),
            })
        end
    end

    return entries
end

local panel = CreateFrame("Frame", nil, OAK_LFG, "BackdropTemplate")
panel:SetSize(246, 408)
addonTable.ApplyBackdropStyle(panel, "panel")
panel:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
panel:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
panel:Hide()
addonTable.MythicPlusPanel = panel

local header = panel:CreateTexture(nil, "BACKGROUND")
header:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -1)
header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -1)
header:SetHeight(42)
header:SetColorTexture(unpack(addonTable.OAK_COLOR_TITLEBAR or addonTable.OAK_COLOR_PANE))

local divider = panel:CreateTexture(nil, "BACKGROUND")
divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -1)
divider:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -1)
divider:SetHeight(1)
divider:SetColorTexture(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 0.35)

local title = panel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
title:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -8)
title:SetText("Mythic+ Overview")

local subtitle = panel:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
subtitle:SetTextColor(0.85, 0.78, 0.58)
subtitle:SetText("Season snapshot")

local vaultButton = addonTable.CreateFlatButton(panel, "Vault", 48)
vaultButton:SetAutoWidth(40, 54, 10)
vaultButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
vaultButton:SetScript("OnClick", function()
    OpenWeeklyRewardsUI()
end)
vaultButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Open Great Vault", 1, 1, 1)
    GameTooltip:AddLine("Open Blizzard's Great Vault window.", 1, 1, 1, true)
    GameTooltip:Show()
end)
vaultButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local scoreLabel = panel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
scoreLabel:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 10, -10)
scoreLabel:SetText("Score")

local scoreValue = panel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
scoreValue:SetPoint("LEFT", scoreLabel, "RIGHT", 8, 0)

local keyLabel = panel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
keyLabel:SetPoint("TOPLEFT", scoreLabel, "BOTTOMLEFT", 0, -6)
keyLabel:SetText("Your Key")

local keyValue = panel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
keyValue:SetPoint("LEFT", keyLabel, "RIGHT", 8, 0)
keyValue:SetWidth(132)
keyValue:SetJustifyH("LEFT")

local affixHeader = panel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
affixHeader:SetPoint("TOPLEFT", keyLabel, "BOTTOMLEFT", 0, -8)
affixHeader:SetText("This Week")

local affixButtons = {}
for i = 1, 4 do
    local button = CreateFrame("Button", nil, panel, "BackdropTemplate")
    button:SetSize(26, 26)
    if i == 1 then
        button:SetPoint("TOPLEFT", affixHeader, "BOTTOMLEFT", 0, -4)
    else
        button:SetPoint("LEFT", affixButtons[i - 1], "RIGHT", 6, 0)
    end
    button:SetBackdrop({ bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1 })
    button:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
    button:SetBackdropBorderColor(0, 0, 0, 1)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button:SetScript("OnEnter", function(self)
        if not self.affixName then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.affixName, 1, 1, 1)
        if self.affixDesc and self.affixDesc ~= "" then
            GameTooltip:AddLine(self.affixDesc, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    affixButtons[i] = button
end

local bestHeader = panel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
bestHeader:SetPoint("TOPLEFT", affixButtons[1], "BOTTOMLEFT", 0, -12)
bestHeader:SetText("Season Best")

local colDungeon = panel:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
colDungeon:SetPoint("LEFT", bestHeader, "LEFT", 0, 0)
colDungeon:SetText("")
local colKey = panel:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
colKey:SetWidth(28)
colKey:SetJustifyH("CENTER")
colKey:ClearAllPoints()
colKey:SetPoint("LEFT", bestHeader, "LEFT", 126, 0)
colKey:SetText("Key")
local colTime = panel:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
colTime:ClearAllPoints()
colTime:SetPoint("LEFT", bestHeader, "LEFT", 156, 0)
colTime:SetWidth(44)
colTime:SetJustifyH("CENTER")
colTime:SetText("Time")
local colScore = panel:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
colScore:ClearAllPoints()
colScore:SetPoint("LEFT", bestHeader, "LEFT", 204, 0)
colScore:SetWidth(22)
colScore:SetJustifyH("CENTER")
colScore:SetText("Score")

local dungeonRows = {}
for i = 1, 8 do
    local row = CreateFrame("Button", nil, panel, "SecureActionButtonTemplate")
    row:SetSize(226, 15)
    row:RegisterForClicks("AnyUp", "AnyDown")
    if i == 1 then
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -160)
    else
        row:SetPoint("TOPLEFT", dungeonRows[i - 1], "BOTTOMLEFT", 0, -1)
    end
    row.name = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
    row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.name:SetWidth(128)
    row.name:SetJustifyH("LEFT")
    row.level = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
    row.level:SetPoint("LEFT", row, "LEFT", 126, 0)
    row.level:SetWidth(28)
    row.level:SetJustifyH("CENTER")
    row.time = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
    row.time:SetPoint("LEFT", row, "LEFT", 156, 0)
    row.time:SetWidth(44)
    row.time:SetJustifyH("CENTER")
    row.score = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
    row.score:SetPoint("LEFT", row, "LEFT", 204, 0)
    row.score:SetWidth(22)
    row.score:SetJustifyH("CENTER")
    row:SetScript("OnEnter", function(self)
        if self.spellID and IsSpellKnown(self.spellID) then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.mapName or "Dungeon", 1, 1, 1)
            GameTooltip:AddLine("Click to teleport", 0.5, 1, 0.5)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    dungeonRows[i] = row
end

local vaultHeader = panel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
vaultHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -300)
vaultHeader:SetText("Great Vault")

local vaultRows = {}
for i = 1, 3 do
    local button = CreateFrame("Button", nil, panel, "BackdropTemplate")
    button:SetSize(226, 20)
    if i == 1 then
        button:SetPoint("TOPLEFT", vaultHeader, "BOTTOMLEFT", 0, -3)
    else
        button:SetPoint("TOPLEFT", vaultRows[i - 1], "BOTTOMLEFT", 0, 0)
    end
    button:SetBackdrop({ bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1 })
    button:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
    button:SetBackdropBorderColor(0, 0, 0, 1)
    button.label = button:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
    button.label:SetPoint("LEFT", button, "LEFT", 8, 0)
    button.label:SetWidth(68)
    button.label:SetJustifyH("LEFT")
    button.value = button:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
    button.value:SetPoint("RIGHT", button, "RIGHT", -8, 0)
    button.value:SetWidth(164)
    button.value:SetJustifyH("RIGHT")
    button:SetScript("OnClick", function()
        OpenWeeklyRewardsUI()
    end)
    button:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Open Great Vault", 1, 1, 1)
        GameTooltip:AddLine("Click to open Blizzard's Great Vault panel.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0, 0, 0, 1)
        GameTooltip:Hide()
    end)
    vaultRows[i] = button
end

local function GetAnchorTarget()
    return OAK_LFG
end

local function PositionPanel()
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", GetAnchorTarget(), "TOPRIGHT", 2, 0)
end

function addonTable.HideMythicPlusPanel()
    panel:Hide()
end

local function RefreshMythicPlusPanel()
    local score = GetCurrentScore()
    local sr, sg, sb = GetScoreColor(score)
    scoreValue:SetText(score > 0 and tostring(score) or "--")
    scoreValue:SetTextColor(sr, sg, sb)
    keyValue:SetText(GetOwnedKeyText())

    local affixes = GetCurrentAffixData()
    for i, button in ipairs(affixButtons) do
        local affix = affixes[i]
        if affix then
            button.affixName = affix.name
            button.affixDesc = affix.description
            button.icon:SetTexture(affix.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            button:Show()
        else
            button.affixName = nil
            button.affixDesc = nil
            button.icon:SetTexture(nil)
            button:Hide()
        end
    end

    local bestRows = GetDungeonRows()
    for i, row in ipairs(dungeonRows) do
        local data = bestRows[i]
        if data then
            local r, g, b = GetScoreColor(data.score)
            row.name:SetText(data.name or "")
            row.mapName = data.name
            row.spellID = data.mapID and GetTeleportSpellID(data.mapID) or nil
            if row.spellID and IsSpellKnown(row.spellID) then
                local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(row.spellID) or GetSpellInfo(row.spellID)
                row:SetAttribute("type", "spell")
                row:SetAttribute("spell", spellName or row.spellID)
                row.name:SetTextColor(0.55, 1, 0.55)
            else
                row:SetAttribute("type", nil)
                row:SetAttribute("spell", nil)
                row.name:SetTextColor(0.95, 0.95, 0.95)
            end
            row.level:SetText(data.level > 0 and ("+" .. data.level) or "--")
            row.level:SetTextColor(0.95, 0.82, 0.40)
            local timeText = FormatDuration(data.duration)
            if data.overtime then
                timeText = timeText .. " (OT)"
            end
            row.time:SetText(timeText)
            row.time:SetTextColor(0.82, 0.82, 0.82)
            row.score:SetText(data.score > 0 and tostring(data.score) or "--")
            row.score:SetTextColor(r, g, b)
            row:Show()
        else
            row.mapName = nil
            row.spellID = nil
            row:SetAttribute("type", nil)
            row:SetAttribute("spell", nil)
            row:Hide()
        end
    end

    vaultHeader:Show()
    local vaultData = GetVaultRows()
    for i, button in ipairs(vaultRows) do
        local data = vaultData[i]
        if data then
            button.label:SetText(data.label or "")
            button.value:SetText(data.summary or "-")
            button:Show()
        else
            button:Hide()
        end
    end
end

function addonTable.ToggleMythicPlusPanel()
    if panel:IsShown() then
        panel:Hide()
        if addonTable.UpdatePartyKeysPanel then
            addonTable.UpdatePartyKeysPanel()
        end
        return
    end
    if addonTable.SupportersPanel then addonTable.SupportersPanel:Hide() end
    if addonTable.OptionsPanel then addonTable.OptionsPanel:Hide() end
    if addonTable.BrowserFilterPanel then addonTable.BrowserFilterPanel:Hide() end
    if addonTable.FilterPanel then addonTable.FilterPanel:Hide() end
    PositionPanel()
    RefreshMythicPlusPanel()
    panel:Show()
    if addonTable.UpdatePartyKeysPanel then
        addonTable.UpdatePartyKeysPanel()
    end
    if addonTable.RefreshRIOAnchor then
        addonTable.RefreshRIOAnchor()
    end
end

addonTable.RegisterThemeRefresh("mythic_plus_panel_theme", function()
    addonTable.ApplyBackdropStyle(panel, "panel")
    local alpha = addonTable.GetWindowOpacity and addonTable.GetWindowOpacity() or (addonTable.OAK_COLOR_BG and addonTable.OAK_COLOR_BG[4]) or 0.85
    panel:SetBackdropColor(addonTable.OAK_COLOR_BG[1], addonTable.OAK_COLOR_BG[2], addonTable.OAK_COLOR_BG[3], alpha)
    panel:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    header:Show()
    header:SetColorTexture(unpack(addonTable.OAK_COLOR_TITLEBAR or addonTable.OAK_COLOR_PANE))
    divider:SetColorTexture(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 0.35)
end)
