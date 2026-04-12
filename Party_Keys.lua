local addonName, addonTable = ...

local OAK_LFG = addonTable.OAK_LFG
if not OAK_LFG then
    return
end

local openRaidLib = LibStub and LibStub:GetLibrary("LibOpenRaid-1.0", true)
local function GetOpenRaidLib()
    if not openRaidLib and LibStub then
        openRaidLib = LibStub:GetLibrary("LibOpenRaid-1.0", true)
    end
    return openRaidLib
end
local PARTY_KEY_ROWS = 5
local ROW_HEIGHT = 14
local PANEL_WIDTH = 164
local PANEL_PADDING = 3
local TITLE_HEIGHT = 10

local RIO_DUNGEON_ABBREVIATIONS = {
    ["seat of the triumvirate"] = "SEAT",
    ["skyreach"] = "SR",
    ["algeth'ar academy"] = "AA",
    ["magisters' terrace"] = "MT",
    ["maisara caverns"] = "MC",
    ["windrunner spire"] = "WS",
    ["nexus-point xenas"] = "NPX",
    ["pit of saron"] = "POS",
}

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

local function GetDungeonLabel(mapID)
    local name = mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(mapID)
    if not name then
        return "???"
    end
    local normalized = tostring(name):lower()
    if RIO_DUNGEON_ABBREVIATIONS[normalized] then
        return RIO_DUNGEON_ABBREVIATIONS[normalized]
    end
    if _G.QUI_DungeonData and _G.QUI_DungeonData.GetShortName then
        local shortName = _G.QUI_DungeonData.GetShortName(mapID)
        if shortName and shortName ~= "" then
            return shortName
        end
    end
    return name:sub(1, 4):upper()
end

local function GetKeyColor(level)
    if _G.QUI_DungeonData and _G.QUI_DungeonData.GetKeyColor then
        return _G.QUI_DungeonData.GetKeyColor(level)
    end
    if not level or level <= 0 then return 0.7, 0.7, 0.7 end
    if level >= 12 then return 1, 0.5, 0 end
    if level >= 10 then return 0.64, 0.21, 0.93 end
    if level >= 7 then return 0, 0.44, 0.87 end
    if level >= 5 then return 0.12, 0.75, 0.26 end
    return 1, 1, 1
end

local partyKeysPanel = CreateFrame("Frame", nil, OAK_LFG, "BackdropTemplate")
partyKeysPanel:SetSize(PANEL_WIDTH, TITLE_HEIGHT + PANEL_PADDING * 2)
partyKeysPanel:SetPoint("TOPLEFT", OAK_LFG, "BOTTOMLEFT", 10, -2)
partyKeysPanel:SetFrameStrata("DIALOG")
partyKeysPanel:SetFrameLevel((OAK_LFG:GetFrameLevel() or 0) + 5)
addonTable.ApplyBackdropStyle(partyKeysPanel, "panel")
partyKeysPanel:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
partyKeysPanel:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
partyKeysPanel:Hide()
addonTable.PartyKeysPanel = partyKeysPanel

local title = partyKeysPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
title:SetPoint("TOPLEFT", partyKeysPanel, "TOPLEFT", PANEL_PADDING, -2)
title:SetText("Party Keys")

local rows = {}

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, partyKeysPanel)
    row:SetSize(PANEL_WIDTH - PANEL_PADDING * 2, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", partyKeysPanel, "TOPLEFT", PANEL_PADDING, -(TITLE_HEIGHT + 2 + ((index - 1) * ROW_HEIGHT)))

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(12, 12)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.dungeonButton = CreateFrame("Button", nil, row, "SecureActionButtonTemplate")
    row.dungeonButton:SetPoint("LEFT", row, "LEFT", 14, 0)
    row.dungeonButton:SetSize(54, 12)
    row.dungeonButton:RegisterForClicks("AnyUp", "AnyDown")

    row.dungeonText = row.dungeonButton:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
    row.dungeonText:SetPoint("LEFT", row.dungeonButton, "LEFT", 0, 0)
    row.dungeonText:SetJustifyH("LEFT")

    row.level = row.dungeonButton:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
    row.level:SetPoint("LEFT", row.dungeonText, "RIGHT", 2, 0)
    row.level:SetJustifyH("LEFT")

    row.player = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
    row.player:SetPoint("LEFT", row.dungeonButton, "RIGHT", 4, 0)
    row.player:SetWidth(60)
    row.player:SetJustifyH("LEFT")

    row.score = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
    row.score:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.score:SetJustifyH("RIGHT")

    row.dungeonButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if self.tooltipDungeon then
            GameTooltip:SetText(self.tooltipDungeon, 1, 1, 1)
        end
        if self.spellID and IsTeleportKnown(self.spellID) then
            GameTooltip:AddLine("Click to teleport", 0.5, 1, 0.5)
        elseif self.spellID then
            GameTooltip:AddLine("Teleport spell not learned yet", 1, 0.35, 0.35)
        end
        GameTooltip:Show()
    end)
    row.dungeonButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    row:Hide()
    rows[index] = row
    return row
end

for i = 1, PARTY_KEY_ROWS do
    CreateRow(i)
end

local function ShouldShowPartyKeys()
    if not GetOpenRaidLib() then
        return false
    end
    if not (OakLFGSorterDB and OakLFGSorterDB.showPartyKeys == true) then
        return false
    end
    if not (OAK_LFG and OAK_LFG:IsShown()) then
        return false
    end
    local context = addonTable.UpdateListingContext and addonTable.UpdateListingContext()
    local hasActiveEntry = C_LFGList and C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo()
    if hasActiveEntry then
        local mode = context and context.mode or nil
        return mode == "mythic_plus" or mode == "dungeon"
    end
    local searchContext = addonTable.CurrentSearchContext or {}
    local searchMode = searchContext.mode
    local categoryKey = searchContext.selectedCategoryKey or (OakLFGSorterDB and OakLFGSorterDB.browserCategoryKey)
    return searchMode == "mythic_plus" or searchMode == "dungeon" or categoryKey == "DUNGEONS"
end

local function GetPlayerScore(unit)
    local score = 0
    local color = { r = 1, g = 1, b = 1 }
    if C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        local ok, ratingInfo = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit)
        if ok and ratingInfo and ratingInfo.currentSeasonScore and ratingInfo.currentSeasonScore > 0 then
            score = math.floor(ratingInfo.currentSeasonScore)
            if C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor then
                local rarity = C_ChallengeMode.GetDungeonScoreRarityColor(score)
                if rarity then
                    color = { r = rarity.r, g = rarity.g, b = rarity.b }
                end
            end
        end
    end
    return score, color
end

local function HideRows()
    for _, row in ipairs(rows) do
        row:Hide()
        row.dungeonButton:SetAttribute("type", nil)
        row.dungeonButton:SetAttribute("spell", nil)
        row.dungeonButton.spellID = nil
        row.dungeonButton.tooltipDungeon = nil
    end
end

local function UpdatePartyKeysPanel()
    if not ShouldShowPartyKeys() then
        HideRows()
        partyKeysPanel:Hide()
        return
    end

    local lib = GetOpenRaidLib()
    if not lib then
        HideRows()
        partyKeysPanel:Hide()
        return
    end

    local allKeystones = lib.GetAllKeystonesInfo and lib.GetAllKeystonesInfo() or {}
    local display = {}

    local playerKey = lib.GetKeystoneInfo and lib.GetKeystoneInfo("player")
    if playerKey and playerKey.level and playerKey.level > 0 then
        table.insert(display, { unit = "player", info = playerKey, fullName = UnitName("player") or "player" })
    end

    if not IsInRaid() then
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                local unitName, realm = UnitName(unit)
                if unitName then
                    local fullName = realm and realm ~= "" and (unitName .. "-" .. realm) or unitName
                    local info = allKeystones[fullName] or allKeystones[unitName]
                    if info and info.level and info.level > 0 then
                        table.insert(display, { unit = unit, info = info, fullName = fullName })
                    end
                end
            end
        end
    end

    HideRows()

    local visible = 0
    for index, entry in ipairs(display) do
        local row = rows[index]
        if not row then
            break
        end

        local info = entry.info
        local challengeMapID = tonumber(info.challengeMapID) or tonumber(info.mythicPlusMapID)
        local instanceMapID = tonumber(info.mapID)
        local mapInfo = challengeMapID and addonTable.GetChallengeMapInfo and addonTable.GetChallengeMapInfo(challengeMapID) or nil
        local dungeonName = mapInfo and mapInfo.name or (challengeMapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(challengeMapID)) or nil
        local spellID = GetTeleportSpellID(instanceMapID or (mapInfo and mapInfo.instanceMapID) or challengeMapID)
        local _, classToken = UnitClass(entry.unit)
        local classColor = RAID_CLASS_COLORS[classToken or ""] or NORMAL_FONT_COLOR
        local shortName = GetDungeonLabel(challengeMapID or instanceMapID)
        local icon = mapInfo and mapInfo.iconTexture or (challengeMapID and select(4, C_ChallengeMode.GetMapUIInfo(challengeMapID))) or nil
        local kr, kg, kb = GetKeyColor(info.level)
        local score, scoreColor = GetPlayerScore(entry.unit)
        local nameOnly = tostring(entry.fullName or ""):match("([^%-]+)") or tostring(entry.fullName or "")

        row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.level:SetText("+" .. tostring(info.level))
        row.level:SetTextColor(kr, kg, kb)
        row.dungeonText:SetText(shortName)
        row.dungeonText:SetTextColor(1, 1, 1, 1)
        row.player:SetText(nameOnly)
        row.player:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
        if score > 0 then
            row.score:SetText(score)
            row.score:SetTextColor(scoreColor.r, scoreColor.g, scoreColor.b, 1)
        else
            row.score:SetText("")
        end

        row.dungeonButton.tooltipDungeon = dungeonName
        row.dungeonButton.spellID = spellID
        if spellID and IsTeleportKnown(spellID) then
            local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or GetSpellInfo(spellID)
            row.dungeonButton:SetAttribute("type", "spell")
            row.dungeonButton:SetAttribute("spell", spellName or spellID)
            row.dungeonText:SetTextColor(0.55, 1, 0.55, 1)
        else
            row.dungeonButton:SetAttribute("type", nil)
            row.dungeonButton:SetAttribute("spell", nil)
        end

        row:Show()
        visible = visible + 1
    end

    if visible == 0 then
        partyKeysPanel:Hide()
        return
    end

    local height = TITLE_HEIGHT + (PANEL_PADDING * 2) + (visible * ROW_HEIGHT) + 2
    partyKeysPanel:SetHeight(height)
    partyKeysPanel:Show()
end

addonTable.UpdatePartyKeysPanel = UpdatePartyKeysPanel

addonTable.RegisterThemeRefresh("party_keys_theme", function()
    addonTable.ApplyBackdropStyle(partyKeysPanel, "panel")
    partyKeysPanel:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
    partyKeysPanel:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    title:SetTextColor(unpack(addonTable.OAK_COLOR_TITLE_TINT or { 1, 1, 1, 1 }))
    UpdatePartyKeysPanel()
end)

OAK_LFG:HookScript("OnShow", function()
    C_Timer.After(0.1, UpdatePartyKeysPanel)
    C_Timer.After(1.0, UpdatePartyKeysPanel)
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
eventFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function()
    C_Timer.After(0.1, UpdatePartyKeysPanel)
end)
