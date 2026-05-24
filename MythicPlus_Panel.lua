local addonName, addonTable = ...

local OAK_LFG = addonTable.OAK_LFG
if not OAK_LFG then
    return
end

local function GetTeleportSpellID(mapID)
    return addonTable.GetDungeonTeleportSpellID and addonTable.GetDungeonTeleportSpellID(mapID) or nil
end

local function IsTeleportKnown(spellID)
    if not spellID then
        return false
    end
    if IsSpellKnownOrOverridesKnown then
        return IsSpellKnownOrOverridesKnown(spellID)
    end
    return IsSpellKnown and IsSpellKnown(spellID) or false
end

local function IsRestrictedCombatInInstance()
    return addonTable.IsRestrictedCombatInInstance and addonTable.IsRestrictedCombatInInstance()
end

local function AddRestrictedTooltip(actionName)
    if addonTable.AddRestrictedCombatTooltipLine then
        addonTable.AddRestrictedCombatTooltipLine(GameTooltip, actionName)
    end
end

local function SetProtectedSpellAction(button, spell)
    if IsRestrictedCombatInInstance() then
        if addonTable.TryClearProtectedSpellAction then
            addonTable.TryClearProtectedSpellAction(button)
        end
        return false
    end
    if addonTable.TrySetProtectedSpellAction then
        return addonTable.TrySetProtectedSpellAction(button, spell)
    end
    return false
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
panel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 24,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
panel:SetBackdropColor(0.90, 0.90, 0.90, 1)
panel:SetBackdropBorderColor(1, 1, 1, 1)
panel:Hide()
addonTable.MythicPlusPanel = panel

local header = panel:CreateTexture(nil, "BORDER")
header:SetTexture("Interface\\Buttons\\WHITE8X8")
header:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
header:SetHeight(24)
header:SetVertexColor(0.18, 0.18, 0.18, 0.96)

local divider = panel:CreateTexture(nil, "BORDER")
divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
divider:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -2)
divider:SetHeight(1)
divider:SetColorTexture(0.52, 0.44, 0.22, 0.45)

local innerShade = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
innerShade:SetTexture("Interface\\Buttons\\WHITE8X8")
innerShade:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -36)
innerShade:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 10)
innerShade:SetVertexColor(0.28, 0.25, 0.21, 0.82)

local title = panel:CreateFontString(nil, "OVERLAY", "SorterClassic_FontRegular")
title:SetPoint("CENTER", header, "CENTER", 0, 0)
title:SetText("Mythic+ Overview")

local subtitle = panel:CreateFontString(nil, "OVERLAY", "SorterClassic_FontSmall")
subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
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

local scoreLabel = panel:CreateFontString(nil, "OVERLAY", "SorterClassic_FontRegular")
scoreLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -42)
scoreLabel:SetText("Score")

local scoreValue = panel:CreateFontString(nil, "OVERLAY", "SorterClassic_FontRegular")
scoreValue:SetPoint("LEFT", scoreLabel, "RIGHT", 8, 0)

local keyLabel = panel:CreateFontString(nil, "OVERLAY", "SorterClassic_FontRegular")
keyLabel:SetPoint("TOPLEFT", scoreLabel, "BOTTOMLEFT", 0, -6)
keyLabel:SetText("Your Key")

local keyValue = panel:CreateFontString(nil, "OVERLAY", "SorterClassic_FontRegular")
keyValue:SetPoint("LEFT", keyLabel, "RIGHT", 8, 0)
keyValue:SetWidth(132)
keyValue:SetJustifyH("LEFT")

local keyTeleportButton = CreateFrame("Button", nil, panel, "InsecureActionButtonTemplate")
keyTeleportButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 68, -57)
keyTeleportButton:SetSize(132, 18)
keyTeleportButton:RegisterForClicks("AnyUp", "AnyDown")
keyTeleportButton:SetFrameLevel(panel:GetFrameLevel() + 5)
keyTeleportButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Your Key", 1, 1, 1)
    if self.mapName and self.keyLevel and self.keyLevel > 0 then
        GameTooltip:AddLine(string.format("+%d %s", self.keyLevel, self.mapName), 1, 1, 1, true)
    elseif self.keyText and self.keyText ~= "" then
        GameTooltip:AddLine(self.keyText, 1, 1, 1, true)
    end
    if IsRestrictedCombatInInstance() then
        AddRestrictedTooltip("Your key teleport")
    elseif self.spellID and IsTeleportKnown(self.spellID) then
        GameTooltip:AddLine("Click to teleport", 0.5, 1, 0.5)
    elseif self.spellID then
        GameTooltip:AddLine("Teleport spell not learned yet", 1, 0.35, 0.35)
    end
    GameTooltip:Show()
end)
keyTeleportButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local affixHeader = panel:CreateFontString(nil, "OVERLAY", "SorterClassic_FontRegular")
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
    button:SetBackdropColor(0.16, 0.16, 0.16, 0.95)
    button:SetBackdropBorderColor(0.34, 0.34, 0.34, 1)
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

local bestHeader = panel:CreateFontString(nil, "OVERLAY", "SorterClassic_FontRegular")
bestHeader:SetPoint("TOPLEFT", affixButtons[1], "BOTTOMLEFT", 0, -12)
bestHeader:SetText("Season Best")

local colDungeon = panel:CreateFontString(nil, "OVERLAY", "SorterClassic_FontSmall")
colDungeon:SetPoint("LEFT", bestHeader, "LEFT", 0, 0)
colDungeon:SetText("")
local colKey = panel:CreateFontString(nil, "OVERLAY", "SorterClassic_FontSmall")
colKey:SetWidth(28)
colKey:SetJustifyH("CENTER")
colKey:ClearAllPoints()
colKey:SetPoint("LEFT", bestHeader, "LEFT", 126, 0)
colKey:SetText("Key")
local colTime = panel:CreateFontString(nil, "OVERLAY", "SorterClassic_FontSmall")
colTime:ClearAllPoints()
colTime:SetPoint("LEFT", bestHeader, "LEFT", 156, 0)
colTime:SetWidth(44)
colTime:SetJustifyH("CENTER")
colTime:SetText("Time")
local colScore = panel:CreateFontString(nil, "OVERLAY", "SorterClassic_FontSmall")
colScore:ClearAllPoints()
colScore:SetPoint("LEFT", bestHeader, "LEFT", 204, 0)
colScore:SetWidth(22)
colScore:SetJustifyH("CENTER")
colScore:SetText("Score")

local dungeonRows = {}
for i = 1, 8 do
    local row = CreateFrame("Button", nil, panel, "InsecureActionButtonTemplate")
    row:SetSize(226, 15)
    row:RegisterForClicks("AnyUp", "AnyDown")
    if i == 1 then
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -160)
    else
        row:SetPoint("TOPLEFT", dungeonRows[i - 1], "BOTTOMLEFT", 0, -1)
    end
    row.name = row:CreateFontString(nil, "OVERLAY", "SorterClassic_FontSmall")
    row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.name:SetWidth(128)
    row.name:SetJustifyH("LEFT")
    row.level = row:CreateFontString(nil, "OVERLAY", "SorterClassic_FontSmall")
    row.level:SetPoint("LEFT", row, "LEFT", 126, 0)
    row.level:SetWidth(28)
    row.level:SetJustifyH("CENTER")
    row.time = row:CreateFontString(nil, "OVERLAY", "SorterClassic_FontSmall")
    row.time:SetPoint("LEFT", row, "LEFT", 156, 0)
    row.time:SetWidth(44)
    row.time:SetJustifyH("CENTER")
    row.score = row:CreateFontString(nil, "OVERLAY", "SorterClassic_FontSmall")
    row.score:SetPoint("LEFT", row, "LEFT", 204, 0)
    row.score:SetWidth(22)
    row.score:SetJustifyH("CENTER")
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.mapName or "Dungeon", 1, 1, 1)
        if IsRestrictedCombatInInstance() then
            AddRestrictedTooltip("Dungeon teleports")
        elseif self.spellID and IsTeleportKnown(self.spellID) then
            GameTooltip:AddLine("Click to teleport", 0.5, 1, 0.5)
        elseif self.spellID then
            GameTooltip:AddLine("Teleport spell not learned yet", 1, 0.35, 0.35)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    dungeonRows[i] = row
end

local vaultHeader = panel:CreateFontString(nil, "OVERLAY", "SorterClassic_FontRegular")
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
    button:SetBackdropColor(0.16, 0.16, 0.16, 0.95)
    button:SetBackdropBorderColor(0.34, 0.34, 0.34, 1)
    button.label = button:CreateFontString(nil, "OVERLAY", "SorterClassic_FontSmall")
    button.label:SetPoint("LEFT", button, "LEFT", 8, 0)
    button.label:SetWidth(68)
    button.label:SetJustifyH("LEFT")
    button.value = button:CreateFontString(nil, "OVERLAY", "SorterClassic_FontSmall")
    button.value:SetPoint("RIGHT", button, "RIGHT", -8, 0)
    button.value:SetWidth(164)
    button.value:SetJustifyH("RIGHT")
    button:SetScript("OnClick", function()
        if IsRestrictedCombatInInstance() then
            return
        end
        OpenWeeklyRewardsUI()
    end)
    button:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.58, 0.48, 0.20, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Open Great Vault", 1, 1, 1)
        if IsRestrictedCombatInInstance() then
            AddRestrictedTooltip("The Great Vault panel")
        else
            GameTooltip:AddLine("Click to open Blizzard's Great Vault panel.", 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.34, 0.34, 0.34, 1)
        GameTooltip:Hide()
    end)
    vaultRows[i] = button
end

local function GetAnchorTarget()
    return OAK_LFG
end

local function PositionPanel()
    panel:ClearAllPoints()
    if OakLFGSorterDB and OakLFGSorterDB.mythicPlusPanelSide == "LEFT" then
        panel:SetPoint("TOPRIGHT", GetAnchorTarget(), "TOPLEFT", -2, 0)
    else
        panel:SetPoint("TOPLEFT", GetAnchorTarget(), "TOPRIGHT", 2, 0)
    end
    if addonTable.UpdateAuxPanelAnchors then
        addonTable.UpdateAuxPanelAnchors()
    end
end
addonTable.PositionMythicPlusPanel = PositionPanel

function addonTable.HideMythicPlusPanel()
    panel:Hide()
    if addonTable.UpdateAuxPanelAnchors then
        addonTable.UpdateAuxPanelAnchors()
    end
end

local function RefreshMythicPlusPanel()
    local score = GetCurrentScore()
    local sr, sg, sb = GetScoreColor(score)
    scoreValue:SetText(score > 0 and tostring(score) or "--")
    scoreValue:SetTextColor(sr, sg, sb)

    local ownedKeyLevel = SafeCall(C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel)
    local ownedChallengeMapID = SafeCall(C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID)
    local ownedMapInfo = ownedChallengeMapID and addonTable.GetChallengeMapInfo and addonTable.GetChallengeMapInfo(ownedChallengeMapID) or nil
    local ownedMapName = ownedMapInfo and ownedMapInfo.name or (ownedChallengeMapID and SafeCall(C_ChallengeMode and C_ChallengeMode.GetMapUIInfo, ownedChallengeMapID))
    local ownedSpellID = GetTeleportSpellID(ownedMapInfo and ownedMapInfo.instanceMapID or ownedChallengeMapID)

    keyValue:SetText(GetOwnedKeyText())
    keyTeleportButton.keyLevel = tonumber(ownedKeyLevel) or 0
    keyTeleportButton.mapName = ownedMapName
    keyTeleportButton.keyText = keyValue:GetText()
    keyTeleportButton.spellID = ownedSpellID
    if ownedSpellID and IsTeleportKnown(ownedSpellID) then
        local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(ownedSpellID) or GetSpellInfo(ownedSpellID)
        SetProtectedSpellAction(keyTeleportButton, spellName or ownedSpellID)
        keyValue:SetTextColor(0.55, 1, 0.55)
    else
        SetProtectedSpellAction(keyTeleportButton, nil)
        keyValue:SetTextColor(1, 1, 1)
    end

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
            local mapInfo = data.mapID and addonTable.GetChallengeMapInfo and addonTable.GetChallengeMapInfo(data.mapID) or nil
            row.spellID = GetTeleportSpellID(mapInfo and mapInfo.instanceMapID or data.mapID)
            if row.spellID and IsTeleportKnown(row.spellID) then
                local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(row.spellID) or GetSpellInfo(row.spellID)
                SetProtectedSpellAction(row, spellName or row.spellID)
                row.name:SetTextColor(0.55, 1, 0.55)
            else
                SetProtectedSpellAction(row, nil)
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
            SetProtectedSpellAction(row, nil)
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

local mythicPlusRefreshPending = false
local mythicPlusRefreshAfterCombat = false

local function IsCombatLocked()
    return InCombatLockdown and InCombatLockdown()
end

local function RunMythicPlusRefresh()
    mythicPlusRefreshPending = false

    if not panel:IsShown() then
        return
    end

    if IsCombatLocked() then
        mythicPlusRefreshAfterCombat = true
        return
    end

    mythicPlusRefreshAfterCombat = false
    RefreshMythicPlusPanel()
end

local function ScheduleMythicPlusRefresh(delay)
    if not panel:IsShown() then
        return
    end

    if IsCombatLocked() then
        mythicPlusRefreshAfterCombat = true
        return
    end

    if mythicPlusRefreshPending then
        return
    end

    mythicPlusRefreshPending = true
    C_Timer.After(delay or 0.1, RunMythicPlusRefresh)
end

local function ScheduleFollowupMythicPlusRefresh(delay)
    C_Timer.After(delay or 0.1, function()
        if panel:IsShown() then
            addonTable.RefreshMythicPlusPanel()
        end
    end)
end

addonTable.RefreshMythicPlusPanel = function(immediate)
    if immediate then
        if not panel:IsShown() then
            return
        end
        if IsCombatLocked() then
            mythicPlusRefreshAfterCombat = true
            return
        end
        mythicPlusRefreshPending = false
        mythicPlusRefreshAfterCombat = false
        RefreshMythicPlusPanel()
        return
    end

    ScheduleMythicPlusRefresh(0.05)
end

function addonTable.ShowMythicPlusPanel()
    if IsRestrictedCombatInInstance() then
        return
    end
    if OakLFGSorterDB then
        OakLFGSorterDB.mythicPlusPanelOpen = true
    end
    if panel:IsShown() then
        PositionPanel()
        addonTable.RefreshMythicPlusPanel(true)
        return
    end
    PositionPanel()
    panel:Show()
    addonTable.RefreshMythicPlusPanel(true)
end

function addonTable.ToggleMythicPlusPanel()
    if IsRestrictedCombatInInstance() then
        if UIErrorsFrame and addonTable.GetRestrictedCombatTooltipText then
            UIErrorsFrame:AddMessage(addonTable.GetRestrictedCombatTooltipText("The Mythic+ panel"), 1, 0.35, 0.35)
        end
        return
    end
    if panel:IsShown() then
        if OakLFGSorterDB then
            OakLFGSorterDB.mythicPlusPanelOpen = false
        end
        panel:Hide()
        if addonTable.UpdateAuxPanelAnchors then
            addonTable.UpdateAuxPanelAnchors()
        end
        if addonTable.UpdatePartyKeysPanel then
            addonTable.UpdatePartyKeysPanel()
        end
        return
    end
    addonTable.ShowMythicPlusPanel()
    if addonTable.UpdateAuxPanelAnchors then
        addonTable.UpdateAuxPanelAnchors()
    end
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
    if addonTable.IsModernTheme and addonTable.IsModernTheme() then
        local bg = addonTable.OAK_COLOR_BG or {0.073, 0.082, 0.094, 0.98}
        panel:SetBackdropColor(bg[1], bg[2], bg[3], alpha)
    else
        panel:SetBackdropColor(0.90, 0.90, 0.90, alpha)
    end
    local panelBorder = (addonTable.IsModernTheme and addonTable.IsModernTheme() and addonTable.OAK_COLOR_BORDER) or {1, 1, 1, 1}
    panel:SetBackdropBorderColor(unpack(panelBorder))
    header:Show()
    header:SetVertexColor(unpack(addonTable.OAK_COLOR_PANEL_TITLE_BG or {0.18, 0.18, 0.18, 0.96}))
    divider:SetColorTexture(unpack(addonTable.OAK_COLOR_PANEL_TRIM or {0.52, 0.44, 0.22, 0.45}))
    innerShade:SetVertexColor(unpack(addonTable.OAK_COLOR_PANEL_INNER or {0.28, 0.25, 0.21, 0.82}))
end)

panel:HookScript("OnShow", function()
    PositionPanel()
    ScheduleMythicPlusRefresh(0.05)
    ScheduleFollowupMythicPlusRefresh(0.75)
end)

OAK_LFG:HookScript("OnShow", function()
    if OakLFGSorterDB and OakLFGSorterDB.mythicPlusPanelOpen and addonTable.ShowMythicPlusPanel then
        addonTable.ShowMythicPlusPanel()
    end
end)

OAK_LFG:HookScript("OnHide", function()
    if panel:IsShown() then
        panel:Hide()
    end
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
eventFrame:RegisterEvent("WEEKLY_REWARDS_ITEM_CHANGED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        if IsRestrictedCombatInInstance() then
            SetProtectedSpellAction(keyTeleportButton, nil)
            for _, row in ipairs(dungeonRows) do
                SetProtectedSpellAction(row, nil)
            end
            if panel:IsShown() then
                pcall(panel.Hide, panel)
                if addonTable.UpdateAuxPanelAnchors then
                    addonTable.UpdateAuxPanelAnchors()
                end
            end
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if OakLFGSorterDB and OakLFGSorterDB.mythicPlusPanelOpen
                and OAK_LFG and OAK_LFG:IsShown()
                and not panel:IsShown() then
            addonTable.ShowMythicPlusPanel()
        end
        if mythicPlusRefreshAfterCombat then
            ScheduleMythicPlusRefresh(0.1)
        end
        return
    end

    ScheduleMythicPlusRefresh(0.1)
    if event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_MAPS_UPDATE" then
        ScheduleFollowupMythicPlusRefresh(1.0)
        ScheduleFollowupMythicPlusRefresh(2.0)
    end
end)
