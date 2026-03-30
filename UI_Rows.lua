local addonName, addonTable = ...
local OAK_LFG = addonTable.OAK_LFG

addonTable.ApplicantGroups = {}
addonTable.CurrentSortBy = "ilvl"
addonTable.CurrentIsAscending = false
local ROW_HEIGHT = 22 
local FULL_FRAME_WIDTH = 660
local COLLAPSED_FRAME_WIDTH = 460
local HEADER_TOP_OFFSET = -43
local SCROLL_TOP_OFFSET = -70
local roleWeights = { ["TANK"] = 1, ["HEALER"] = 2, ["DAMAGER"] = 3 }
local MODE_CONFIGS = {
    mythic_plus = { ratingLabel = "M+ Rating", keyLabel = "Key" },
    rated_pvp = { ratingLabel = "PVP Rating", keyLabel = "Type" },
    pvp = { ratingLabel = "PVP Rating", keyLabel = "Type" },
    raid = { ratingLabel = "Progress", keyLabel = "Raid" },
    legacy_raid = { ratingLabel = "Progress", keyLabel = "Raid" },
    delve = { ratingLabel = "M+ Rating", keyLabel = "Key" },
    open_world = { ratingLabel = "M+ Rating", keyLabel = "Key" },
    generic = { ratingLabel = "M+ Rating", keyLabel = "Key" },
}

local function GetListingMode()
    return (addonTable.CurrentListingContext and addonTable.CurrentListingContext.mode) or "generic"
end

local function GetModeConfig()
    return MODE_CONFIGS[GetListingMode()] or MODE_CONFIGS.generic
end

local function UsesSecondaryMetricColumn()
    local listingMode = GetListingMode()
    return not (listingMode == "rated_pvp" or listingMode == "pvp" or listingMode == "raid" or listingMode == "legacy_raid")
end

local scrollFrame = CreateFrame("ScrollFrame", "OakLFGScrollFrame", OAK_LFG, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", OAK_LFG, "TOPLEFT", 10, SCROLL_TOP_OFFSET)
scrollFrame:SetPoint("BOTTOMRIGHT", OAK_LFG, "BOTTOMRIGHT", -25, 35) 

local scrollBar = _G[scrollFrame:GetName() .. "ScrollBar"]
if scrollBar then
    local upBtn = _G[scrollFrame:GetName() .. "ScrollBarScrollUpButton"]
    local downBtn = _G[scrollFrame:GetName() .. "ScrollBarScrollDownButton"]
    if upBtn then upBtn:Hide(); upBtn:SetSize(0.1, 0.1) end
    if downBtn then downBtn:Hide(); downBtn:SetSize(0.1, 0.1) end

    local topTex = _G[scrollFrame:GetName() .. "ScrollBarTop"]
    local bottomTex = _G[scrollFrame:GetName() .. "ScrollBarBottom"]
    local midTex = _G[scrollFrame:GetName() .. "ScrollBarMiddle"]
    if topTex then topTex:Hide() end
    if bottomTex then bottomTex:Hide() end
    if midTex then midTex:Hide() end
    
    local thumb = scrollBar:GetThumbTexture()
    if thumb then
        thumb:SetTexture(addonTable.FLAT_TEX)
        thumb:SetVertexColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1) 
        thumb:SetSize(8, 60)
    end
    scrollBar:SetWidth(8)
end

local scrollChild = CreateFrame("Frame")
scrollChild:SetSize(scrollFrame:GetWidth(), 1)
scrollFrame:SetScrollChild(scrollChild)

local function GetTargetFrameWidth()
    if OakLFGSorterDB and OakLFGSorterDB.hideNotes then
        return COLLAPSED_FRAME_WIDTH
    end
    return FULL_FRAME_WIDTH
end
addonTable.GetTargetFrameWidth = GetTargetFrameWidth

OAK_LFG:SetScript("OnSizeChanged", function(self, width, height)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    local targetWidth = GetTargetFrameWidth()
    if math.abs(width - targetWidth) > 0.5 then
        self:SetWidth(targetWidth)
    end
end)

local footer = CreateFrame("Frame", nil, OAK_LFG)
footer:SetPoint("BOTTOMLEFT", OAK_LFG, "BOTTOMLEFT", 10, 10)
footer:SetPoint("BOTTOMRIGHT", OAK_LFG, "BOTTOMRIGHT", -10, 10)
footer:SetHeight(20)
addonTable.Footer = footer

local lustText = footer:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
lustText:SetPoint("LEFT", footer, "LEFT", 10, 0)
local brezText = footer:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
brezText:SetPoint("LEFT", lustText, "RIGHT", 20, 0)

local suppBtn = addonTable.CreateFlatButton(footer, "Supporters and Social Links", 190)
suppBtn:SetPoint("LEFT", brezText, "RIGHT", 20, 0)
suppBtn:SetScript("OnClick", function()
    if addonTable.SupportersPanel:IsShown() then
        addonTable.SupportersPanel:Hide()
    else
        addonTable.FilterPanel:Hide()
        addonTable.SupportersPanel:Show()
    end
end)

local footerVersionText = footer:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
footerVersionText:SetPoint("RIGHT", footer, "RIGHT", -4, 0)
footerVersionText:SetText(addonTable.VersionText and addonTable.VersionText:GetText() or "")

function addonTable.UpdateGroupBuffs()
    local hasLust, hasBrez = false, false
    local function CheckClass(c)
        if not c then return end
        c = string.upper(c)
        if c == "MAGE" or c == "SHAMAN" or c == "HUNTER" or c == "EVOKER" then hasLust = true end
        if c == "DEATHKNIGHT" or c == "DRUID" or c == "WARLOCK" or c == "PALADIN" then hasBrez = true end
    end
    
    CheckClass(addonTable.PlayerClass)
    
    local numGroup = GetNumGroupMembers()
    for i = 1, numGroup do
        local unit = IsInRaid() and "raid"..i or "party"..i
        if not UnitIsUnit(unit, "player") then
            local _, uClass = UnitClass(unit)
            CheckClass(uClass)
        end
    end
    if hasLust then lustText:SetText("|cFF55FF55|TInterface\\Icons\\spell_nature_bloodlust:16|t Lust Covered|r")
    else lustText:SetText("|cFFFF5555|TInterface\\Icons\\spell_nature_bloodlust:16|t Need Lust|r") end
    if hasBrez then brezText:SetText("|cFF55FF55|TInterface\\Icons\\spell_holy_resurrection:16|t B-Rez Covered|r")
    else brezText:SetText("|cFFFF5555|TInterface\\Icons\\spell_holy_resurrection:16|t Need B-Rez|r") end
end

local function SortGroups(grpA, grpB, sortBy, isAscending)
    local valA, valB
    local listingMode = GetListingMode()

    if sortBy == "role" then valA, valB = roleWeights[grpA.leadRole] or 99, roleWeights[grpB.leadRole] or 99
    elseif sortBy == "class" then valA, valB = grpA.leadClass, grpB.leadClass
    elseif sortBy == "spec" then 
        valA = addonTable.SpecShortNames[grpA.leadSpec] or tostring(grpA.leadSpec or "")
        valB = addonTable.SpecShortNames[grpB.leadSpec] or tostring(grpB.leadSpec or "")
    elseif sortBy == "ilvl" then valA, valB = grpA.leadIlvl, grpB.leadIlvl
    elseif sortBy == "rating" then
        if listingMode == "rated_pvp" or listingMode == "pvp" then
            valA, valB = grpA.leadPvpRating or 0, grpB.leadPvpRating or 0
        elseif listingMode == "raid" or listingMode == "legacy_raid" then
            valA = (grpA.leadRaidProgress and grpA.leadRaidProgress.sortValue) or 0
            valB = (grpB.leadRaidProgress and grpB.leadRaidProgress.sortValue) or 0
        else
            valA, valB = grpA.leadRating, grpB.leadRating
        end
    elseif sortBy == "key" then
        if listingMode == "rated_pvp" or listingMode == "pvp" then
            valA, valB = grpA.leadPvpBracket or "", grpB.leadPvpBracket or ""
        elseif listingMode == "raid" or listingMode == "legacy_raid" then
            valA = (grpA.leadRaidProgress and grpA.leadRaidProgress.raidName) or ""
            valB = (grpB.leadRaidProgress and grpB.leadRaidProgress.raidName) or ""
        else
            valA, valB = grpA.leadKey, grpB.leadKey
        end
    elseif sortBy == "note" then valA, valB = grpA.comment or "", grpB.comment or "" end
    
    if valA ~= valB then
        if isAscending then return valA < valB else return valA > valB end
    end
    if grpA.leadIlvl ~= grpB.leadIlvl then 
        if isAscending then return grpA.leadIlvl < grpB.leadIlvl else return grpA.leadIlvl > grpB.leadIlvl end
    end
    if grpA.leadRating ~= grpB.leadRating then 
        if isAscending then return grpA.leadRating < grpB.leadRating else return grpA.leadRating > grpB.leadRating end
    end
    if isAscending then return grpA.id < grpB.id else return grpA.id > grpB.id end
end

local headers = {}
local keyHeader
function addonTable.UpdateHeaderVisuals()
    local modeConfig = GetModeConfig()
    local showSecondaryMetric = UsesSecondaryMetricColumn()

    for _, header in ipairs(headers) do
        if header.sortKey == "key" then
            if showSecondaryMetric then
                header:Show()
            else
                header:Hide()
            end
        end

        if header.sortKey == "rating" then
            header.text:SetText(modeConfig.ratingLabel)
        elseif header.sortKey == "key" then
            header.text:SetText(modeConfig.keyLabel)
        else
            header.text:SetText(header.baseText)
        end

        if addonTable.CurrentSortBy == header.sortKey then
            header.arrow:SetTexture(addonTable.CurrentIsAscending and "Interface\\BUTTONS\\Arrow-Up-Up" or "Interface\\BUTTONS\\Arrow-Down-Up")
            header.arrow:Show()
        else
            header.arrow:Hide()
        end
    end
end

local function CreateHeader(label, sortKey, column)
    local btn = CreateFrame("Button", nil, OAK_LFG, "BackdropTemplate")
    btn:SetSize(column.w, 22)
    btn:SetPoint("TOPLEFT", OAK_LFG, "TOPLEFT", column.x, HEADER_TOP_OFFSET)
    btn:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
    btn:SetBackdropColor(unpack(addonTable.OAK_COLOR_PANE))
    btn:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    
    btn.baseText = label; btn.sortKey = sortKey
    btn.text = btn:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    local leftPadding = (column.align == "LEFT") and 6 or 2
    local rightPadding = (column.align == "LEFT") and 12 or 2
    btn.text:SetPoint("LEFT", btn, "LEFT", leftPadding, 0)
    btn.text:SetPoint("RIGHT", btn, "RIGHT", -rightPadding, 0)
    if column.align == "LEFT" then
        btn.text:SetJustifyH("LEFT")
    else
        btn.text:SetJustifyH("CENTER")
    end
    btn.text:SetText(label)
    btn.text:SetWordWrap(false)

    btn.arrow = btn:CreateTexture(nil, "OVERLAY")
    btn.arrow:SetSize(10, 10)
    btn.arrow:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
    btn.arrow:Hide()
    
    btn:SetScript("OnClick", function()
        if addonTable.CurrentSortBy == sortKey then addonTable.CurrentIsAscending = not addonTable.CurrentIsAscending
        else addonTable.CurrentSortBy = sortKey; addonTable.CurrentIsAscending = false end
        addonTable.UpdateHeaderVisuals(); addonTable.UpdateDisplay()
    end)
    table.insert(headers, btn)
    if sortKey == "key" then
        keyHeader = btn
    end
    return btn
end

-- Master Column Coordinates
local C_ROLE   = { x = 10,  w = 35,  align = "CENTER" }
local C_CLASS  = { x = 45,  w = 110, align = "LEFT" }
local C_SPEC   = { x = 155, w = 45,  align = "LEFT" }
local C_ILVL   = { x = 200, w = 40,  align = "CENTER" }
local C_RATING = { x = 240, w = 90,  align = "CENTER" }
local C_KEY    = { x = 330, w = 40,  align = "CENTER" }
local C_NOTE   = { x = 370, w = 200, align = "LEFT" }
local ROW_X_OFFSET = 10

local function RowColumn(column)
    return { x = column.x - ROW_X_OFFSET, w = column.w, align = column.align }
end

local R_ROLE   = RowColumn(C_ROLE)
local R_CLASS  = RowColumn(C_CLASS)
local R_SPEC   = RowColumn(C_SPEC)
local R_ILVL   = RowColumn(C_ILVL)
local R_RATING = RowColumn(C_RATING)
local R_KEY    = RowColumn(C_KEY)
local R_NOTE   = RowColumn(C_NOTE)

local function GetCurrentNoteColumn()
    if UsesSecondaryMetricColumn() then
        return C_NOTE
    end

    return { x = C_KEY.x, w = C_KEY.w + C_NOTE.w, align = "LEFT" }
end

local function GetCurrentRowNoteColumn()
    return RowColumn(GetCurrentNoteColumn())
end

CreateHeader("Role", "role", C_ROLE)
CreateHeader("Class", "class", C_CLASS) 
CreateHeader("Spec", "spec", C_SPEC)
CreateHeader("iLvl", "ilvl", C_ILVL)
CreateHeader("Rating", "rating", C_RATING)
CreateHeader("Key", "key", C_KEY)

local notesToggleBtn = addonTable.CreateFlatButton(OAK_LFG, "Notes", C_NOTE.w)
notesToggleBtn:SetSize(C_NOTE.w, 22)

local function UpdateNotesToggleLayout()
    local noteColumn = GetCurrentNoteColumn()
    notesToggleBtn:ClearAllPoints()
    notesToggleBtn:SetPoint("TOPLEFT", OAK_LFG, "TOPLEFT", noteColumn.x, HEADER_TOP_OFFSET)
    if OakLFGSorterDB and OakLFGSorterDB.hideNotes then
        notesToggleBtn:SetWidth(75)
    else
        notesToggleBtn:SetWidth(noteColumn.w)
    end
end

local function UpdateNotesToggleVisual()
    notesToggleBtn:SetBackdropColor(unpack(addonTable.OAK_COLOR_PANE))
    notesToggleBtn:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
end

notesToggleBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if OakLFGSorterDB and OakLFGSorterDB.hideNotes then
        GameTooltip:SetText("Show Notes", 1, 1, 1)
        GameTooltip:AddLine("Expand the Note column and restore the full sorter width.", 1, 1, 1, true)
    else
        GameTooltip:SetText("Hide Notes", 1, 1, 1)
        GameTooltip:AddLine("Collapse the Note column and shrink the sorter window.", 1, 1, 1, true)
    end
    GameTooltip:Show()
end)
notesToggleBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)

local rows = {}

local function SetFrameWidthPreservingLeft(targetWidth, preserveLeftEdge)
    OAK_LFG:SetResizeBounds(targetWidth, 420, targetWidth, 800)
    if preserveLeftEdge then
        local oldLeft = OAK_LFG:GetLeft()
        local oldBottom = OAK_LFG:GetBottom()

        OAK_LFG:SetWidth(targetWidth)
        if oldLeft and oldBottom then
            OAK_LFG:ClearAllPoints()
            OAK_LFG:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", oldLeft, oldBottom)
            if OakLFGSorterDB then
                OakLFGSorterDB.framePos = { "BOTTOMLEFT", "BOTTOMLEFT", oldLeft, oldBottom }
            end
        end
    elseif math.abs(OAK_LFG:GetWidth() - targetWidth) > 0.5 then
        OAK_LFG:SetWidth(targetWidth)
    end
end

local function ConfigureTextColumn(fontString, row, column, padding)
    padding = padding or 0
    fontString:ClearAllPoints()
    fontString:SetPoint("LEFT", row, "LEFT", column.x + padding, 0)
    fontString:SetPoint("RIGHT", row, "LEFT", column.x + column.w - padding, 0)
    if column.align == "LEFT" then
        fontString:SetJustifyH("LEFT")
    else
        fontString:SetJustifyH("CENTER")
    end
    fontString:SetWordWrap(false)
end

local function GetPreferredScoreColor(score, defaultR, defaultG, defaultB)
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

local function GetMemberRatingDisplay(member)
    local listingMode = GetListingMode()

    if listingMode == "rated_pvp" or listingMode == "pvp" then
        local pvpRating = math.floor(member.pvpRating or 0)
        return pvpRating > 0 and tostring(pvpRating) or "--"
    elseif listingMode == "raid" or listingMode == "legacy_raid" then
        return (member.raidProgress and member.raidProgress.displayText) or "--"
    end

    local ratingNum = math.floor(member.rating or 0)
    local ratingStr = (ratingNum > 0 and tostring(ratingNum)) or "--"

    if ratingNum > 0 then
        local cR, cG, cB = GetPreferredScoreColor(ratingNum, 1, 1, 1)
        ratingStr = string.format("|cFF%02x%02x%02x%s|r", cR * 255, cG * 255, cB * 255, ratingStr)
    end

    if member.mainScore and member.mainScore > ratingNum then
        local mcR, mcG, mcB = GetPreferredScoreColor(member.mainScore, 0.5, 0.5, 0.5)
        local mainStr = string.format("|cFF%02x%02x%02x[%d]|r", mcR * 255, mcG * 255, mcB * 255, math.floor(member.mainScore))
        if ratingNum == 0 then
            ratingStr = mainStr
        else
            ratingStr = ratingStr .. " " .. mainStr
        end
    end

    return ratingStr
end

local function GetMemberSecondaryDisplay(member)
    local listingMode = GetListingMode()

    if listingMode == "rated_pvp" or listingMode == "pvp" then
        return member.pvpBracket or "--"
    elseif listingMode == "raid" or listingMode == "legacy_raid" then
        return (member.raidProgress and member.raidProgress.raidName) or "--"
    end

    return member.highestKey > 0 and "+" .. member.highestKey or "--"
end

local function CreateRow(index)
    local row = CreateFrame("Button", nil, scrollChild)
    row:SetHeight(ROW_HEIGHT)
    
    if index == 1 then 
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
        row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
    else 
        row:SetPoint("TOPLEFT", rows[index-1], "BOTTOMLEFT", 0, 0) 
        row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
    end

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()

    row.hoverBg = row:CreateTexture(nil, "ARTWORK")
    row.hoverBg:SetAllPoints()
    row.hoverBg:SetColorTexture(1, 1, 1, 0.1)
    row.hoverBg:Hide()

    row:SetScript("OnEnter", function(self) 
        self.hoverBg:Show() 
        
        if self.applicantID and self.memberIdx then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
            GameTooltip:ClearLines()

            local name, class, localizedClass, level, itemLevel, honorLevel, tank, healer, damage, assignedRole, relationship, dungeonScore = C_LFGList.GetApplicantMemberInfo(self.applicantID, self.memberIdx)
            
            if name then
                GameTooltip:AddLine(addonTable.ApplyClassColor(name, class or ""), 1, 1, 1)
                GameTooltip:AddLine(string.format("%s - Item Level: %d", localizedClass or "", math.floor(itemLevel or 0)), 1, 1, 1)
                GameTooltip:AddLine(" ")

                local listingMode = GetListingMode()
                if listingMode == "rated_pvp" or listingMode == "pvp" then
                    GameTooltip:AddLine("PvP Profile", 0.2, 1, 0.2)
                    GameTooltip:AddDoubleLine("Rating:", (self.memberPvpRating and self.memberPvpRating > 0) and self.memberPvpRating or "--", 1, 1, 1, 1, 1, 1)
                    if self.memberPvpBracket then
                        GameTooltip:AddDoubleLine("Bracket:", self.memberPvpBracket, 1, 1, 1, 1, 1, 1)
                    end
                elseif listingMode == "raid" or listingMode == "legacy_raid" then
                    GameTooltip:AddLine("Raid Profile", 1, 0.8, 0)
                    if self.memberRaidProgress then
                        GameTooltip:AddDoubleLine(self.memberRaidProgress.raidName .. ":", self.memberRaidProgress.longText or self.memberRaidProgress.displayText, 1, 1, 1, 1, 1, 1)
                    else
                        GameTooltip:AddDoubleLine("Progress:", "--", 1, 1, 1, 1, 1, 1)
                    end
                else
                    GameTooltip:AddLine("Mythic+ Profile", 0.2, 1, 0.2)

                    local score = math.floor(self.memberRating or 0)
                    local cR, cG, cB = GetPreferredScoreColor(score, 1, 1, 1)

                    GameTooltip:AddDoubleLine("Overall Rating:", score > 0 and score or "--", 1, 1, 1, cR, cG, cB)

                    if self.rioProfile and type(self.rioProfile.mythicKeystoneProfile) == "table" then
                        local mPlus = self.rioProfile.mythicKeystoneProfile
                        local mainScore = math.floor(mPlus.mainCurrentScore or 0)
                        if mainScore > score then
                            local mcR, mcG, mcB = GetPreferredScoreColor(mainScore, 0.5, 0.5, 0.5)
                            GameTooltip:AddDoubleLine("Main Rating:", mainScore, 0.5, 0.5, 0.5, mcR, mcG, mcB)
                        end
                    end

                    local entryInfo = C_LFGList.GetActiveEntryInfo()
                    local activityID = entryInfo and (entryInfo.activityID or (entryInfo.activityIDs and type(entryInfo.activityIDs) == "table" and entryInfo.activityIDs[1]))
                    if activityID then
                        local success, bestForDungeon = pcall(C_LFGList.GetApplicantDungeonScoreForListing, self.applicantID, self.memberIdx, activityID)
                        if success and type(bestForDungeon) == "table" and type(bestForDungeon.bestRunLevel) == "number" and bestForDungeon.bestRunLevel > 0 then
                            GameTooltip:AddDoubleLine("Best for " .. (bestForDungeon.mapName or "Listing") .. ":", "+" .. bestForDungeon.bestRunLevel, 1, 1, 1, 1, 1, 1)
                        end
                    end

                    local successBest, bestOverall = pcall(C_LFGList.GetApplicantBestDungeonScore, self.applicantID, self.memberIdx)
                    if successBest and type(bestOverall) == "table" and type(bestOverall.bestRunLevel) == "number" and bestOverall.bestRunLevel > 0 then
                        GameTooltip:AddDoubleLine("Best Run:", "+" .. bestOverall.bestRunLevel .. " (" .. (bestOverall.mapName or "Unknown") .. ")", 1, 1, 1, 1, 1, 1)
                    end

                    if self.rioProfile and type(self.rioProfile.mythicKeystoneProfile) == "table" and type(self.rioProfile.mythicKeystoneProfile.sortedDungeons) == "table" then
                        local dungeons = self.rioProfile.mythicKeystoneProfile.sortedDungeons
                        if #dungeons > 0 then
                            local hasRun = false
                            for i = 1, math.min(3, #dungeons) do
                                local d = dungeons[i]
                                if type(d) == "table" and type(d.level) == "number" and d.level > 0 then
                                    if not hasRun then
                                        GameTooltip:AddLine(" ")
                                        GameTooltip:AddLine("Top R.IO Runs:", 0.8, 0.8, 0.8)
                                        hasRun = true
                                    end
                                    local pluses = (type(d.numUpgrades) == "number" and d.numUpgrades > 0) and string.rep("+", d.numUpgrades) or ""
                                    local dName = (type(d.dungeon) == "table" and d.dungeon.shortName) or "Unknown"
                                    GameTooltip:AddDoubleLine(dName, "+" .. d.level .. pluses, 1, 1, 1, 0.2, 1, 0.2)
                                end
                            end
                        end
                    end
                end

                if self.rioProfile and listingMode ~= "raid" and listingMode ~= "legacy_raid" then
                    local raidDataFound = {}
                    local function MineRaidData(t, depth)
                        if depth > 8 or type(t) ~= "table" then return end
                        if t.difficulty and t.progressCount and t.raid and type(t.raid) == "table" and t.raid.shortName then
                            local rname = t.raid.shortName
                            local diff = tonumber(t.difficulty) or t.difficulty
                            local count = tonumber(t.progressCount) or 0
                            local bosses = tonumber(t.raid.bossCount) or 9
                            if not raidDataFound[rname] then raidDataFound[rname] = {n=0, h=0, m=0, bosses=bosses} end
                            if diff == 1 or diff == "Normal" or diff == "N" then raidDataFound[rname].n = math.max(raidDataFound[rname].n, count) end
                            if diff == 2 or diff == "Heroic" or diff == "H" then raidDataFound[rname].h = math.max(raidDataFound[rname].h, count) end
                            if diff == 3 or diff == "Mythic" or diff == "M" then raidDataFound[rname].m = math.max(raidDataFound[rname].m, count) end
                            return
                        end
                        local name = t.shortName or t.raid_name or t.name or (t.raid and type(t.raid) == "table" and t.raid.shortName)
                        if name and (t.normal or t.heroic or t.mythic or t.normal_bosses_killed) then
                            local rname = tostring(name)
                            local n = t.normal or t.normal_bosses_killed or t.Normal or t.n or 0
                            local h = t.heroic or t.heroic_bosses_killed or t.Heroic or t.h or 0
                            local m = t.mythic or t.mythic_bosses_killed or t.Mythic or t.m or 0
                            local bosses = t.bossCount or t.boss_count or t.total_bosses or t.bosses or 9
                            if not raidDataFound[rname] then raidDataFound[rname] = {n=0, h=0, m=0, bosses=tonumber(bosses) or 9} end
                            raidDataFound[rname].n = math.max(raidDataFound[rname].n, tonumber(n) or 0)
                            raidDataFound[rname].h = math.max(raidDataFound[rname].h, tonumber(h) or 0)
                            raidDataFound[rname].m = math.max(raidDataFound[rname].m, tonumber(m) or 0)
                            return
                        end
                        for k, v in pairs(t) do
                            if type(v) == "table" then MineRaidData(v, depth + 1) end
                        end
                    end
                    MineRaidData(self.rioProfile, 1)
                    
                    local addedRaidHeader = false
                    for rname, data in pairs(raidDataFound) do
                        local rightText = ""
                        if data.n > 0 then rightText = rightText .. "|cff1eff00N|r " .. data.n .. "/" .. data.bosses .. " " end
                        if data.h > 0 then rightText = rightText .. "|cff0070ddH|r " .. data.h .. "/" .. data.bosses .. " " end
                        if data.m > 0 then rightText = rightText .. "|cffa335eeM|r " .. data.m .. "/" .. data.bosses .. " " end
                        
                        rightText = rightText:match("^(.-)%s*$")
                        if rightText ~= "" then
                            if not addedRaidHeader then
                                GameTooltip:AddLine(" ")
                                GameTooltip:AddLine("Raider.IO Raid Progress", 1, 0.8, 0)
                                addedRaidHeader = true
                            end
                            GameTooltip:AddDoubleLine(rname, rightText, 1, 1, 1, 1, 1, 1)
                        end
                    end
                end
            else
                GameTooltip:SetText("Applicant", 1, 1, 1)
            end

            if self.fullComment and self.fullComment ~= "" then
                if GameTooltip:NumLines() > 0 then GameTooltip:AddLine(" ") end
                GameTooltip:AddLine("Applicant Note:", 1, 0.8, 0)
                GameTooltip:AddLine(self.fullComment, 0.85, 0.85, 0.85, true) 
            end
            
            GameTooltip:Show()
        end
    end)
    
    row:SetScript("OnLeave", function(self) 
        self.hoverBg:Hide() 
        GameTooltip:Hide()
    end)

    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnDoubleClick", function(self)
        if self.groupID then 
            C_LFGList.InviteApplicant(self.groupID)
            if self.inviteBtn then 
                self.inviteBtn:Hide()
                self.declineBtn:Hide()
                self.statusText:SetText("Invited")
                self.statusText:Show()
            end 
        end
    end)

    row.roleIcon = row:CreateTexture(nil, "OVERLAY")
    row.roleIcon:SetSize(16, 16)
    row.roleIcon:SetPoint("CENTER", row, "LEFT", R_ROLE.x + (R_ROLE.w / 2), 0)
    row.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")

    row.nameText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    ConfigureTextColumn(row.nameText, row, R_CLASS, 5)

    row.specText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    ConfigureTextColumn(row.specText, row, R_SPEC, 5)

    row.ilvlText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    ConfigureTextColumn(row.ilvlText, row, R_ILVL)

    row.ratingText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    ConfigureTextColumn(row.ratingText, row, R_RATING)

    row.keyText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    ConfigureTextColumn(row.keyText, row, R_KEY)
    
    row.noteText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    ConfigureTextColumn(row.noteText, row, GetCurrentRowNoteColumn(), 5)
    row.noteText:SetTextColor(0.7, 0.7, 0.7) 
    if OakLFGSorterDB and OakLFGSorterDB.hideNotes then
        row.noteText:Hide()
    end

    row.declineBtn = CreateFrame("Button", nil, row)
    row.declineBtn:SetSize(20, 20)
    row.declineBtn:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    row.declineBtn:SetNormalTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
    row.declineBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
    row.declineBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Decline", 1, 0.2, 0.2)
        GameTooltip:Show()
    end)
    row.declineBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    row.inviteBtn = CreateFrame("Button", nil, row)
    row.inviteBtn:SetSize(20, 20)
    row.inviteBtn:SetPoint("RIGHT", row.declineBtn, "LEFT", -10, 0)
    row.inviteBtn:SetNormalTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
    row.inviteBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
    row.inviteBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Invite", 0.2, 1, 0.2)
        GameTooltip:Show()
    end)
    row.inviteBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    row.statusText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    row.statusText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    row.statusText:SetTextColor(0.2, 1, 0.2)
    row.statusText:Hide()

    return row
end

function addonTable.ApplyHideNotesLayout(preserveLeftEdge)
    local hideNotes = OakLFGSorterDB and OakLFGSorterDB.hideNotes
    local targetWidth = GetTargetFrameWidth()
    local showSecondaryMetric = UsesSecondaryMetricColumn()
    local rowNoteColumn = GetCurrentRowNoteColumn()

    if not showSecondaryMetric and addonTable.CurrentSortBy == "key" then
        addonTable.CurrentSortBy = "rating"
        addonTable.CurrentIsAscending = false
    end

    for _, row in ipairs(rows) do
        if row.keyText then
            if showSecondaryMetric then row.keyText:Show() else row.keyText:Hide() end
        end
        if row.noteText then
            ConfigureTextColumn(row.noteText, row, rowNoteColumn, 5)
        end
        if row.noteText then
            if hideNotes then row.noteText:Hide() else row.noteText:Show() end
        end
    end

    SetFrameWidthPreservingLeft(targetWidth, preserveLeftEdge)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    UpdateNotesToggleLayout()
    UpdateNotesToggleVisual()

    if addonTable.UpdateTopBarLayout then
        addonTable.UpdateTopBarLayout()
    end

    if addonTable.UpdateDisplay then
        addonTable.UpdateDisplay()
    end
end

notesToggleBtn:SetScript("OnClick", function()
    OakLFGSorterDB.hideNotes = not OakLFGSorterDB.hideNotes
    addonTable.ApplyHideNotesLayout(true)
end)

UpdateNotesToggleLayout()
UpdateNotesToggleVisual()
addonTable.ApplyHideNotesLayout()

function addonTable.UpdateDisplay()
    addonTable.UpdateGroupBuffs()
    addonTable.UpdateHeaderVisuals()

    local activeGroups = {}
    for _, group in ipairs(addonTable.ApplicantGroups) do
        if addonTable.GroupPassesFilters(group) then
            table.insert(activeGroups, group)
        end
    end

    table.sort(activeGroups, function(a, b) 
        return SortGroups(a, b, addonTable.CurrentSortBy, addonTable.CurrentIsAscending) 
    end)

    for _, row in ipairs(rows) do row:Hide() end

    local displayIndex = 1
    local isAltColor = false 

    for _, group in ipairs(activeGroups) do
        local isMulti = group.numMembers > 1
        local bgColor = isAltColor and addonTable.ROW_COLOR_B or addonTable.ROW_COLOR_A
        local showSecondaryMetric = UsesSecondaryMetricColumn()

        for i, member in ipairs(group.members) do
            if not rows[displayIndex] then rows[displayIndex] = CreateRow(displayIndex) end
            local row = rows[displayIndex]
            
            row.groupID = group.id
            row.applicantID = group.id
            row.memberIdx = member.memberIdx
            row.memberName = member.name
            row.fullComment = group.comment 
            row.rioProfile = member.rioProfile 
            row.memberRating = member.rating
            row.memberPvpRating = member.pvpRating
            row.memberPvpBracket = member.pvpBracket
            row.memberRaidProgress = member.raidProgress

            row.bg:SetColorTexture(unpack(bgColor))

            local coords = addonTable.RoleTexCoords[member.role]
            if coords then
                row.roleIcon:SetTexCoord(unpack(coords))
                row.roleIcon:Show()
            else
                row.roleIcon:Hide()
            end
            
            local specAbbr = addonTable.SpecShortNames and addonTable.SpecShortNames[member.specID] or ""
            row.specText:SetText(addonTable.ApplyClassColor(specAbbr, member.class))
            
            local formattedName = addonTable.ApplyClassColor(member.name, member.class)
            
            if member.isFriend then
                formattedName = "|TInterface\\ChatFrame\\UI-ChatIcon-Battlenet:14|t " .. formattedName
            end
            
            if isMulti then
                formattedName = (i == 1) and " " .. formattedName or "   * " .. formattedName 
            end
            
            row.nameText:SetText(formattedName); row.ilvlText:SetText(member.ilvl)

            row.ratingText:SetText(GetMemberRatingDisplay(member))
            row.keyText:SetText(GetMemberSecondaryDisplay(member))
            if showSecondaryMetric then row.keyText:Show() else row.keyText:Hide() end

            if i == 1 then
                row.noteText:SetText(group.comment or "")
                
                row.statusText:Hide()
                row.inviteBtn:SetScript("OnClick", function() 
                    C_LFGList.InviteApplicant(group.id)
                    row.inviteBtn:Hide()
                    row.declineBtn:Hide()
                    row.statusText:SetText("Invited")
                    row.statusText:Show()
                end)
                row.declineBtn:SetScript("OnClick", function() 
                    C_LFGList.DeclineApplicant(group.id)
                end)
                row.inviteBtn:Show(); row.declineBtn:Show()
            else 
                row.noteText:SetText("")
                row.inviteBtn:Hide(); row.declineBtn:Hide() 
                row.statusText:Hide()
            end

            row:Show()
            displayIndex = displayIndex + 1
        end
        isAltColor = not isAltColor
    end

    scrollChild:SetHeight(math.max(1, (displayIndex - 1) * ROW_HEIGHT))
end
