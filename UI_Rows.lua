local addonName, addonTable = ...
local OAK_LFG = addonTable.OAK_LFG

addonTable.ApplicantGroups = {}
addonTable.CurrentSortBy = "ilvl"
addonTable.CurrentIsAscending = false
local ROW_HEIGHT = 22 
local FULL_FRAME_WIDTH = 660
local COLLAPSED_FRAME_WIDTH = 460
local BASE_HEADER_TOP_OFFSET = -43
local BASE_SCROLL_TOP_OFFSET = -70
local APPLICANT_CONTEXT_BAR_HEIGHT = 24
local HEADER_TOP_OFFSET = BASE_HEADER_TOP_OFFSET
local SCROLL_TOP_OFFSET = BASE_SCROLL_TOP_OFFSET
local roleWeights = { ["TANK"] = 1, ["HEALER"] = 2, ["DAMAGER"] = 3 }
local GetBrowserApplicationPriority
local MODE_CONFIGS = {
    mythic_plus = { ratingLabel = "M+ Rating", keyLabel = "Key" },
    rated_pvp = { ratingLabel = "PVP Rating", keyLabel = "Type" },
    pvp = { ratingLabel = "PVP Rating", keyLabel = "Type" },
    raid = { ratingLabel = "Raid", keyLabel = "Prog" },
    legacy_raid = { ratingLabel = "Raid", keyLabel = "Prog" },
    delve = { ratingLabel = "M+ Rating", keyLabel = "Key" },
    open_world = { ratingLabel = "M+ Rating", keyLabel = "Key" },
    generic = { ratingLabel = "M+ Rating", keyLabel = "Key" },
}

local function GetListingMode()
    if addonTable.GetCurrentViewMode and addonTable.GetCurrentViewMode() == "browser" then
        return (addonTable.CurrentSearchContext and addonTable.CurrentSearchContext.mode) or "generic"
    end

    return (addonTable.CurrentListingContext and addonTable.CurrentListingContext.mode) or "generic"
end

local function GetModeConfig()
    return MODE_CONFIGS[GetListingMode()] or MODE_CONFIGS.generic
end

local function GetHeaderTooltipData(sortKey)
    local isBrowser = addonTable.GetCurrentViewMode and addonTable.GetCurrentViewMode() == "browser"
    local listingMode = GetListingMode()

    if sortKey == "role" then
        if isBrowser then
            return "Dungeon", "Sort by dungeon, raid, or activity name."
        end
        return "Role", "Sort by the applicant's primary role."
    elseif sortKey == "class" then
        if isBrowser then
            return "Title", "Sort by the listing title."
        end
        return "Class", "Sort by the applicant's class."
    elseif sortKey == "spec" then
        if isBrowser then
            if listingMode == "raid" or listingMode == "legacy_raid" then
                return "Comp", "Sort by the listing composition summary."
            end
            return "Style", "Sort by the listing playstyle."
        end
        return "Spec", "Sort by the applicant's specialization."
    elseif sortKey == "ilvl" then
        if isBrowser then
            return "Setup", "Sort by the current party setup shown on the listing."
        end
        return "iLvl", "Sort by item level."
    elseif sortKey == "rating" then
        local modeConfig = GetModeConfig()
        if listingMode == "raid" or listingMode == "legacy_raid" then
            return modeConfig.ratingLabel, isBrowser and "Sort by raid difficulty or raid metric for the listing." or "Sort by raid progress for the applicant."
        elseif listingMode == "rated_pvp" or listingMode == "pvp" then
            return modeConfig.ratingLabel, "Sort by PVP rating."
        end
        return modeConfig.ratingLabel, "Sort by Mythic+ rating."
    elseif sortKey == "key" then
        local modeConfig = GetModeConfig()
        if listingMode == "raid" or listingMode == "legacy_raid" then
            return modeConfig.keyLabel, isBrowser and "Sort by raid progress or bosses defeated on the listing." or "Sort by the applicant's raid progress."
        elseif listingMode == "rated_pvp" or listingMode == "pvp" then
            return modeConfig.keyLabel, "Sort by bracket type."
        end
        return modeConfig.keyLabel, "Sort by best key level or key-related metric."
    end

    return nil, nil
end

local function UsesSecondaryMetricColumn()
    local listingMode = GetListingMode()
    return not (listingMode == "rated_pvp" or listingMode == "pvp")
end

local function IsBrowserMode()
    return addonTable.GetCurrentViewMode and addonTable.GetCurrentViewMode() == "browser"
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

local applicantContextBar = CreateFrame("Frame", nil, OAK_LFG, "BackdropTemplate")
applicantContextBar:SetPoint("TOPLEFT", OAK_LFG, "TOPLEFT", 1, -31)
applicantContextBar:SetPoint("TOPRIGHT", OAK_LFG, "TOPRIGHT", -1, -31)
applicantContextBar:SetHeight(APPLICANT_CONTEXT_BAR_HEIGHT)
applicantContextBar:SetBackdrop({ bgFile = addonTable.FLAT_TEX })
applicantContextBar:SetBackdropColor(0.08, 0.08, 0.1, 0.75)
applicantContextBar:Hide()

local applicantListingTitle = applicantContextBar:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
applicantListingTitle:SetPoint("TOPLEFT", applicantContextBar, "TOPLEFT", 12, -2)
applicantListingTitle:SetPoint("TOPRIGHT", applicantContextBar, "TOPRIGHT", -12, -2)
applicantListingTitle:SetJustifyH("LEFT")
applicantListingTitle:SetJustifyV("TOP")
applicantListingTitle:SetWordWrap(false)

local applicantListingActivity = applicantContextBar:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
applicantListingActivity:SetPoint("BOTTOMLEFT", applicantContextBar, "BOTTOMLEFT", 12, 3)
applicantListingActivity:SetPoint("BOTTOMRIGHT", applicantContextBar, "BOTTOMRIGHT", -12, 3)
applicantListingActivity:SetJustifyH("LEFT")
applicantListingActivity:SetJustifyV("BOTTOM")
applicantListingActivity:SetTextColor(0.75, 0.75, 0.75)
applicantListingActivity:SetWordWrap(false)

local function UpdateApplicantContextLayout()
    local contextVisible = applicantContextBar:IsShown()
    HEADER_TOP_OFFSET = contextVisible and (BASE_HEADER_TOP_OFFSET - APPLICANT_CONTEXT_BAR_HEIGHT) or BASE_HEADER_TOP_OFFSET
    SCROLL_TOP_OFFSET = contextVisible and (BASE_SCROLL_TOP_OFFSET - APPLICANT_CONTEXT_BAR_HEIGHT) or BASE_SCROLL_TOP_OFFSET

    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", OAK_LFG, "TOPLEFT", 10, SCROLL_TOP_OFFSET)
    scrollFrame:SetPoint("BOTTOMRIGHT", OAK_LFG, "BOTTOMRIGHT", -25, 35)
end

local function UpdateApplicantContextBar()
    local isApplicantMode = not IsBrowserMode()
    local listingContext = addonTable.UpdateListingContext and addonTable.UpdateListingContext() or addonTable.CurrentListingContext
    local entryInfo = listingContext and listingContext.entryInfo or nil
    local activityInfo = listingContext and listingContext.activityInfo or nil

    local titleText = tostring((entryInfo and entryInfo.name) or "")
    local activityText = tostring((activityInfo and (activityInfo.fullName or activityInfo.shortName)) or "")

    local shouldShow = isApplicantMode and (titleText ~= "" or activityText ~= "")
    if shouldShow then
        applicantListingTitle:SetText(titleText ~= "" and titleText or "Current Listing")
        applicantListingActivity:SetText(activityText)
        applicantContextBar:Show()
    else
        applicantContextBar:Hide()
    end

    UpdateApplicantContextLayout()
end

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

local suppBtn = addonTable.CreateFlatButton(footer, "Supporters & Links", 150)
suppBtn:SetPoint("LEFT", brezText, "RIGHT", 20, 0)
suppBtn:SetScript("OnClick", function()
    if addonTable.SupportersPanel:IsShown() then
        addonTable.SupportersPanel:Hide()
    else
        if addonTable.FilterPanel then addonTable.FilterPanel:Hide() end
        if addonTable.BrowserFilterPanel then addonTable.BrowserFilterPanel:Hide() end
        if addonTable.OptionsPanel then addonTable.OptionsPanel:Hide() end
        addonTable.SupportersPanel:Show()
    end
    if addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(addonTable.OAK_LFG)
    end
end)

local optionsBtn = addonTable.CreateCogButton(footer, 22)
optionsBtn:SetPoint("LEFT", suppBtn, "RIGHT", 6, 0)
optionsBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Options", 1, 1, 1)
    GameTooltip:AddLine("Open shared Oak display options.", 1, 1, 1, true)
    GameTooltip:Show()
end)
optionsBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)
optionsBtn:SetScript("OnClick", function()
    if addonTable.ToggleOptionsPanel then
        addonTable.ToggleOptionsPanel()
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
    local isBrowser = IsBrowserMode()

    if isBrowser then
        if sortBy == "role" then valA, valB = grpA.dungeonName or grpA.activityFilterLabel or grpA.activityName or "", grpB.dungeonName or grpB.activityFilterLabel or grpB.activityName or ""
        elseif sortBy == "class" then valA, valB = grpA.displayName or grpA.name or "", grpB.displayName or grpB.name or ""
        elseif sortBy == "spec" then valA, valB = grpA.playstyleShortLabel or "", grpB.playstyleShortLabel or ""
        elseif sortBy == "ilvl" then
            local aCounts = grpA.roleCounts or {}
            local bCounts = grpB.roleCounts or {}
            valA = ((aCounts.TANK or 0) * 100) + ((aCounts.HEALER or 0) * 10) + (aCounts.DAMAGER or 0)
            valB = ((bCounts.TANK or 0) * 100) + ((bCounts.HEALER or 0) * 10) + (bCounts.DAMAGER or 0)
        elseif sortBy == "rating" then
            if listingMode == "raid" or listingMode == "legacy_raid" then
                valA = (grpA.raidProgress and grpA.raidProgress.sortValue) or 0
                valB = (grpB.raidProgress and grpB.raidProgress.sortValue) or 0
            else
                valA, valB = grpA.rating or 0, grpB.rating or 0
            end
        elseif sortBy == "key" then
            if listingMode == "raid" or listingMode == "legacy_raid" then
                valA = (grpA.raidListing and grpA.raidListing.bossesKilled) or 0
                valB = (grpB.raidListing and grpB.raidListing.bossesKilled) or 0
            else
                valA, valB = grpA.keyLevel or 0, grpB.keyLevel or 0
            end
        elseif sortBy == "note" then valA, valB = grpA.comment or "", grpB.comment or "" end
    else
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
    end

    if isBrowser then
        local priorityA, priorityB = GetBrowserApplicationPriority(grpA), GetBrowserApplicationPriority(grpB)
        if priorityA ~= priorityB then
            return priorityA > priorityB
        end
        if valA ~= valB then
            if isAscending then return valA < valB else return valA > valB end
        end
        if grpA.rating ~= grpB.rating then
            if isAscending then return grpA.rating < grpB.rating else return grpA.rating > grpB.rating end
        end
        if isAscending then return grpA.id < grpB.id else return grpA.id > grpB.id end
    end

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

-- Master Column Coordinates
local C_ROLE   = { x = 10,  w = 35,  align = "CENTER" }
local C_CLASS  = { x = 45,  w = 110, align = "LEFT" }
local C_SPEC   = { x = 155, w = 45,  align = "LEFT" }
local C_ILVL   = { x = 200, w = 40,  align = "CENTER" }
local C_RATING = { x = 240, w = 90,  align = "CENTER" }
local C_KEY    = { x = 330, w = 40,  align = "CENTER" }
local C_NOTE   = { x = 370, w = 200, align = "LEFT" }
local B_DUNGEON = { x = 10,  w = 130, align = "LEFT" }
local B_TITLE   = { x = 140, w = 170, align = "LEFT" }
local B_STYLE   = { x = 310, w = 64,  align = "LEFT" }
local B_SETUP   = { x = 374, w = 58,  align = "CENTER" }
local B_RATING  = { x = 432, w = 78,  align = "CENTER" }
local B_KEY     = { x = 510, w = 44,  align = "CENTER" }
local B_NOTE    = { x = 554, w = 76,  align = "LEFT" }
local ROW_X_OFFSET = 10
local REGION_TAG_WIDTH = 42

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
local BR_DUNGEON = RowColumn(B_DUNGEON)
local BR_SETUP   = RowColumn(B_SETUP)
local BR_TITLE   = RowColumn(B_TITLE)
local BR_STYLE  = RowColumn(B_STYLE)
local BR_RATING = RowColumn(B_RATING)
local BR_KEY    = RowColumn(B_KEY)
local BR_NOTE   = RowColumn(B_NOTE)

local headers = {}
local keyHeader
function addonTable.UpdateHeaderVisuals()
    local modeConfig = GetModeConfig()
    local showSecondaryMetric = UsesSecondaryMetricColumn()
    local isBrowser = IsBrowserMode()
    local browserColumns = {
        role = B_DUNGEON,
        class = B_TITLE,
        spec = B_STYLE,
        ilvl = B_SETUP,
        rating = B_RATING,
        key = B_KEY,
    }
    local defaultColumns = {
        role = C_ROLE,
        class = C_CLASS,
        spec = C_SPEC,
        ilvl = C_ILVL,
        rating = C_RATING,
        key = C_KEY,
    }

    for _, header in ipairs(headers) do
        local column = (isBrowser and browserColumns[header.sortKey]) or defaultColumns[header.sortKey]
        if column then
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", OAK_LFG, "TOPLEFT", column.x, HEADER_TOP_OFFSET)
            header:SetSize(column.w, 22)
            local leftPadding = (column.align == "LEFT") and 6 or 2
            local rightPadding = (column.align == "LEFT") and 12 or 2
            header.text:ClearAllPoints()
            header.text:SetPoint("LEFT", header, "LEFT", leftPadding, 0)
            header.text:SetPoint("RIGHT", header, "RIGHT", -rightPadding, 0)
            header.text:SetJustifyH(column.align == "LEFT" and "LEFT" or "CENTER")
        end

        if header.sortKey == "key" then
            if showSecondaryMetric then
                header:Show()
            else
                header:Hide()
            end
        else
            header:Show()
        end

        if header.sortKey == "rating" then
            header.text:SetText(modeConfig.ratingLabel)
        elseif header.sortKey == "key" then
            header.text:SetText(modeConfig.keyLabel)
        elseif isBrowser and header.sortKey == "role" then
            header.text:SetText("Dungeon")
        elseif isBrowser and header.sortKey == "class" then
            header.text:SetText("Title")
        elseif isBrowser and header.sortKey == "spec" then
            header.text:SetText("Style")
        elseif isBrowser and header.sortKey == "ilvl" then
            header.text:SetText("Setup")
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
    btn:EnableMouse(true)
    btn:SetFrameLevel(OAK_LFG:GetFrameLevel() + 10)
    
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
    btn:SetScript("OnEnter", function(self)
        local title, description = GetHeaderTooltipData(self.sortKey)
        if title and description then
            self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(title, 1, 1, 1)
            GameTooltip:AddLine(description, 1, 1, 1, true)
            GameTooltip:AddLine("Click to sort. Click again to reverse the order.", 0.75, 0.75, 0.75, true)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
        GameTooltip:Hide()
    end)
    table.insert(headers, btn)
    if sortKey == "key" then
        keyHeader = btn
    end
    return btn
end

local function GetCurrentNoteColumn()
    if IsBrowserMode() then
        return B_NOTE
    end

    if UsesSecondaryMetricColumn() then
        return C_NOTE
    end

    return { x = C_KEY.x, w = C_KEY.w + C_NOTE.w, align = "LEFT" }
end

local function GetCurrentRowNoteColumn()
    return RowColumn(GetCurrentNoteColumn())
end

GetBrowserApplicationPriority = function(result)
    if addonTable.IsAppliedStatus and addonTable.IsAppliedStatus(result.applicationStatus) then
        return 3
    end
    if addonTable.IsDeclinedStatus and addonTable.IsDeclinedStatus(result.applicationStatus) then
        return 1
    end
    return 2
end

local function GetBrowserSetupSummary(result)
    local expectedRoles = { "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER" }
    local sortedPlayers = {}
    local roleOrder = { TANK = 1, HEALER = 2, DAMAGER = 3 }

    for _, player in ipairs(result.players or {}) do
        table.insert(sortedPlayers, player)
    end

    table.sort(sortedPlayers, function(a, b)
        return (roleOrder[a.role] or 99) < (roleOrder[b.role] or 99)
    end)

    local usedPlayers = {}
    local setup = {}
    for index, expectedRole in ipairs(expectedRoles) do
        local filled = false
        local className = nil

        for playerIndex, player in ipairs(sortedPlayers) do
            if not usedPlayers[playerIndex] and player.role == expectedRole then
                filled = true
                className = player.class
                usedPlayers[playerIndex] = true
                break
            end
        end

        setup[index] = {
            role = expectedRole,
            filled = filled,
            class = className,
        }
    end

    return setup
end

local function GetBrowserRowColor(result, isAltColor)
    if addonTable.IsAppliedStatus and addonTable.IsAppliedStatus(result.applicationStatus) then
        return 0.12, 0.32, 0.16, 0.55
    end
    if addonTable.IsDeclinedStatus and addonTable.IsDeclinedStatus(result.applicationStatus) then
        return 0.34, 0.10, 0.10, 0.55
    end
    if (result.numBNetFriends or 0) > 0 or (result.numCharFriends or 0) > 0 then
        return 0.12, 0.22, 0.36, 0.50
    end

    local color = isAltColor and addonTable.ROW_COLOR_B or addonTable.ROW_COLOR_A
    return unpack(color)
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
    local toggleWidth = (OakLFGSorterDB and OakLFGSorterDB.hideNotes) and 75 or noteColumn.w
    local xOffset = noteColumn.x

    notesToggleBtn:ClearAllPoints()
    notesToggleBtn:SetPoint("TOPLEFT", OAK_LFG, "TOPLEFT", xOffset, HEADER_TOP_OFFSET)
    notesToggleBtn:SetWidth(toggleWidth)
end

local function UpdateNotesToggleVisual()
    notesToggleBtn:SetBackdropColor(unpack(addonTable.OAK_COLOR_PANE))
    notesToggleBtn:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    notesToggleBtn.text:SetText((OakLFGSorterDB and OakLFGSorterDB.hideNotes) and "Notes" or "Hide Notes")
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
    OAK_LFG:SetResizeBounds(targetWidth, 444, targetWidth, 800)
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

    if addonTable.ClampFrameToScreen then
        addonTable.ClampFrameToScreen(OAK_LFG, OakLFGSorterDB, "framePos")
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

local function ConfigureTextColumnWithTrailingTag(fontString, tagFontString, row, column, padding, tagMarkup)
    padding = padding or 0
    fontString:ClearAllPoints()
    fontString:SetPoint("LEFT", row, "LEFT", column.x + padding, 0)

    if tagFontString and tagMarkup and tagMarkup ~= "" then
        tagFontString:ClearAllPoints()
        tagFontString:SetPoint("RIGHT", row, "LEFT", column.x + column.w - 4, 0)
        tagFontString:SetWidth(REGION_TAG_WIDTH)
        tagFontString:SetJustifyH("RIGHT")
        tagFontString:SetText(tagMarkup)
        tagFontString:Show()
        fontString:SetPoint("RIGHT", tagFontString, "LEFT", -4, 0)
    else
        if tagFontString then
            tagFontString:SetText("")
            tagFontString:Hide()
        end
        fontString:SetPoint("RIGHT", row, "LEFT", column.x + column.w - padding, 0)
    end

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
        return (member.raidProgress and member.raidProgress.raidName) or "--"
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

local function GetRaidProgressFraction(progress)
    if type(progress) ~= "table" then
        return "--"
    end

    local text = tostring(progress.longText or progress.displayText or "")
    local fraction = text:match("(%d+/%d+)")
    if fraction and fraction ~= "" then
        return fraction
    end

    return "--"
end

local function GetMemberSecondaryDisplay(member)
    local listingMode = GetListingMode()

    if listingMode == "rated_pvp" or listingMode == "pvp" then
        return member.pvpBracket or "--"
    elseif listingMode == "raid" or listingMode == "legacy_raid" then
        return GetRaidProgressFraction(member.raidProgress)
    end

    return member.highestKey > 0 and "+" .. member.highestKey or "--"
end

local function GetBrowserRatingDisplay(result)
    local listingMode = GetListingMode()

    if listingMode == "raid" or listingMode == "legacy_raid" then
        return (result.raidProgress and result.raidProgress.displayText) or "--"
    end

    local ratingNum = math.floor(result.rating or 0)
    if ratingNum <= 0 then
        return "--"
    end

    local cR, cG, cB = GetPreferredScoreColor(ratingNum, 1, 1, 1)
    return string.format("|cFF%02x%02x%02x%d|r", cR * 255, cG * 255, cB * 255, ratingNum)
end

local function GetColoredRaidDifficultyLabel(label)
    local text = tostring(label or "")
    local lowered = strlower(text)
    if lowered == "normal" then
        return "|cff0070dd" .. text .. "|r"
    elseif lowered == "heroic" then
        return "|cffa335ee" .. text .. "|r"
    elseif lowered == "mythic" then
        return "|cffff8000" .. text .. "|r"
    end
    return text
end

local function GetRaidBrowserTitle(result)
    local title = result.displayName ~= "" and result.displayName or (result.activityName ~= "" and result.activityName or "--")
    local difficultyLabel = result.raidListing and result.raidListing.difficultyLabel or nil
    if not difficultyLabel or difficultyLabel == "" then
        return title
    end

    local loweredTitle = strlower(title or "")
    if loweredTitle:find(strlower(difficultyLabel), 1, true) then
        return title
    end

    return string.format("%s: %s", GetColoredRaidDifficultyLabel(difficultyLabel), title)
end

local function GetBrowserSecondaryDisplay(result)
    local listingMode = GetListingMode()

    if listingMode == "rated_pvp" or listingMode == "pvp" then
        return result.pvpBracket or "--"
    elseif listingMode == "raid" or listingMode == "legacy_raid" then
        return (result.raidListing and result.raidListing.progressText) or "--"
    end

    return (result.keyLevel and result.keyLevel > 0) and ("+" .. result.keyLevel) or "--"
end

local function ConfigureBrowserRowLayout(row)
    local regionMarkup = addonTable.GetRegionBadgeMarkup and addonTable.GetRegionBadgeMarkup(row.regionInfo) or ""
    ConfigureTextColumnWithTrailingTag(row.dungeonText, row.regionText, row, BR_DUNGEON, 5, regionMarkup)
    ConfigureTextColumn(row.nameText, row, BR_TITLE, 5)
    ConfigureTextColumn(row.specText, row, BR_STYLE, 4)
    ConfigureTextColumn(row.ratingText, row, BR_RATING)
    ConfigureTextColumn(row.keyText, row, BR_KEY)
    ConfigureTextColumn(row.noteText, row, BR_NOTE, 5)
end

local function ConfigureApplicantRowLayout(row)
    local regionMarkup = addonTable.GetRegionBadgeMarkup and addonTable.GetRegionBadgeMarkup(row.regionInfo) or ""
    ConfigureTextColumnWithTrailingTag(row.nameText, row.regionText, row, R_CLASS, 5, regionMarkup)
    ConfigureTextColumn(row.specText, row, R_SPEC, 5)
    ConfigureTextColumn(row.ilvlText, row, R_ILVL)
    ConfigureTextColumn(row.ratingText, row, R_RATING)
    ConfigureTextColumn(row.keyText, row, R_KEY)
    ConfigureTextColumn(row.noteText, row, GetCurrentRowNoteColumn(), 5)
end

local function SetBrowserCompSlot(slotFrame, role, className, filled)
    local coords = addonTable.RoleTexCoords[role]
    if coords then
        slotFrame.icon:SetTexCoord(unpack(coords))
    end

    if filled then
        local classColor = RAID_CLASS_COLORS[string.upper(className or "")] or addonTable.ClassColor
        slotFrame:SetBackdropColor(classColor.r, classColor.g, classColor.b, 0.95)
        slotFrame.icon:SetDesaturated(false)
        slotFrame.icon:SetAlpha(1)
    else
        slotFrame:SetBackdropColor(0.10, 0.10, 0.12, 0.95)
        slotFrame.icon:SetDesaturated(true)
        slotFrame.icon:SetAlpha(0.45)
    end
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

        if self.searchResultID and self.searchResult then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
            GameTooltip:ClearLines()
            self._oakShiftTooltipState = IsShiftKeyDown and IsShiftKeyDown() or false
            self:SetScript("OnUpdate", function(widget)
                local shiftDown = IsShiftKeyDown and IsShiftKeyDown() or false
                if widget._oakShiftTooltipState ~= shiftDown then
                    widget._oakShiftTooltipState = shiftDown
                    local onEnter = widget:GetScript("OnEnter")
                    if onEnter then
                        onEnter(widget)
                    end
                end
            end)

            local result = self.searchResult
            local listingMode = GetListingMode()

            if addonTable.TryShowRaiderIOProfileTooltip and addonTable.TryShowRaiderIOProfileTooltip(GameTooltip, result.leaderName, result.leaderRealm) then
                return
            end

            local regionBadge = addonTable.GetRegionBadgeMarkup and addonTable.GetRegionBadgeMarkup(result.regionInfo) or ""
            local titleText = result.displayName ~= "" and result.displayName or (result.activityName ~= "" and result.activityName or "Group Listing")
            GameTooltip:AddLine((regionBadge ~= "" and (regionBadge .. " " .. titleText)) or titleText, 1, 1, 1)
            if result.leaderName and result.leaderName ~= "" then
                GameTooltip:AddDoubleLine("Leader:", addonTable.ApplyClassColor(result.leaderName, result.leaderClass), 1, 1, 1, 1, 1, 1)
            end
            if result.activityName and result.activityName ~= "" then
                GameTooltip:AddDoubleLine("Activity:", result.activityName, 1, 1, 1, 1, 1, 1)
            end
            if addonTable.AddRegionTooltipLine then
                addonTable.AddRegionTooltipLine(GameTooltip, result.regionInfo)
            end
            if (result.numBNetFriends or 0) > 0 or (result.numCharFriends or 0) > 0 then
                GameTooltip:AddDoubleLine("Friends:", string.format("%d BNet / %d WoW", result.numBNetFriends or 0, result.numCharFriends or 0), 0.6, 0.85, 1, 0.6, 0.85, 1)
            end

            GameTooltip:AddDoubleLine("Members:", tostring(result.numMembers or 0), 1, 1, 1, 1, 1, 1)
            GameTooltip:AddDoubleLine("Comp:", string.format("%d/%d/%d", result.roleCounts.TANK or 0, result.roleCounts.HEALER or 0, result.roleCounts.DAMAGER or 0), 1, 1, 1, 1, 1, 1)

            if listingMode == "rated_pvp" or listingMode == "pvp" then
                GameTooltip:AddDoubleLine("PVP Rating:", (result.pvpRating and result.pvpRating > 0) and result.pvpRating or "--", 1, 1, 1, 1, 1, 1)
                if result.pvpBracket then
                    GameTooltip:AddDoubleLine("Bracket:", result.pvpBracket, 1, 1, 1, 1, 1, 1)
                end
            elseif listingMode == "raid" or listingMode == "legacy_raid" then
                GameTooltip:AddDoubleLine("Progress:", (result.raidProgress and result.raidProgress.longText) or "--", 1, 1, 1, 1, 1, 1)
                if result.raidListing then
                    GameTooltip:AddDoubleLine("Listing Difficulty:", result.raidListing.difficultyLabel or "--", 1, 1, 1, 1, 1, 1)
                    GameTooltip:AddDoubleLine("Bosses Defeated:", result.raidListing.progressText or "--", 1, 1, 1, 1, 1, 1)
                end
            else
                GameTooltip:AddDoubleLine("M+ Rating:", (result.rating and result.rating > 0) and result.rating or "--", 1, 1, 1, 1, 1, 1)
                if result.keyLevel and result.keyLevel > 0 then
                    GameTooltip:AddDoubleLine("Parsed Key:", "+" .. result.keyLevel, 1, 1, 1, 1, 1, 1)
                end
            end

            if result.playstyleLabel and result.playstyleLabel ~= "" and result.playstyleLabel ~= "Any" then
                GameTooltip:AddDoubleLine("Playstyle:", result.playstyleLabel, 1, 1, 1, 1, 1, 1)
            end

            if result.requiredItemLevel and result.requiredItemLevel > 0 then
                GameTooltip:AddDoubleLine("Req iLvl:", tostring(result.requiredItemLevel), 1, 1, 1, 1, 1, 1)
            end
            if result.requiredDungeonScore and result.requiredDungeonScore > 0 then
                GameTooltip:AddDoubleLine("Req Rating:", tostring(result.requiredDungeonScore), 1, 1, 1, 1, 1, 1)
            end

            if result.comment and result.comment ~= "" then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Listing Note:", 1, 0.8, 0)
                GameTooltip:AddLine(result.comment, 0.85, 0.85, 0.85, true)
            end

            GameTooltip:Show()
        elseif self.applicantID and self.memberIdx then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
            GameTooltip:ClearLines()

            local name, class, localizedClass, level, itemLevel, honorLevel, tank, healer, damage, assignedRole, relationship, dungeonScore = C_LFGList.GetApplicantMemberInfo(self.applicantID, self.memberIdx)
            self._oakShiftTooltipState = IsShiftKeyDown and IsShiftKeyDown() or false
            self:SetScript("OnUpdate", function(widget)
                local shiftDown = IsShiftKeyDown and IsShiftKeyDown() or false
                if widget._oakShiftTooltipState ~= shiftDown then
                    widget._oakShiftTooltipState = shiftDown
                    local onEnter = widget:GetScript("OnEnter")
                    if onEnter then
                        onEnter(widget)
                    end
                end
            end)

            if addonTable.TryShowRaiderIOProfileTooltip and addonTable.TryShowRaiderIOProfileTooltip(GameTooltip, name) then
                return
            end
            
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
                    local activityID = entryInfo and tonumber(entryInfo.activityID)
                    if activityID == 0 then
                        activityID = nil
                    end
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

                    if self.rioProfile and addonTable.AppendMythicPlusMilestonesToTooltip then
                        addonTable.AppendMythicPlusMilestonesToTooltip(GameTooltip, self.rioProfile)
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
        self._oakShiftTooltipState = nil
        self:SetScript("OnUpdate", nil)
        GameTooltip:Hide()
    end)

    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnDoubleClick", function(self)
        if self.searchResultID then
            if addonTable.ApplyToSearchResult then
                addonTable.ApplyToSearchResult(self.searchResultID)
            end
        elseif self.groupID then 
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
    row.regionText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
    row.regionText:SetJustifyH("RIGHT")
    row.regionText:Hide()
    row.dungeonText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
    row.specText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    row.ilvlText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    row.ratingText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    row.keyText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    row.noteText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    row.noteText:SetTextColor(0.7, 0.7, 0.7) 
    if OakLFGSorterDB and OakLFGSorterDB.hideNotes then
        row.noteText:Hide()
    end

    row.compSlots = {}
    local compRoles = { "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER" }
    for index, role in ipairs(compRoles) do
        local slot = CreateFrame("Frame", nil, row, "BackdropTemplate")
        slot:SetSize(12, 12)
        slot:SetPoint("LEFT", row, "LEFT", BR_SETUP.x + ((index - 1) * 11) + 2, 0)
        slot:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
        slot:SetBackdropBorderColor(0, 0, 0, 1)
        slot.icon = slot:CreateTexture(nil, "OVERLAY")
        slot.icon:SetPoint("CENTER")
        slot.icon:SetSize(10, 10)
        slot.icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        row.compSlots[index] = slot
    end

    ConfigureApplicantRowLayout(row)

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
    local isBrowser = IsBrowserMode()

    if not showSecondaryMetric and addonTable.CurrentSortBy == "key" then
        addonTable.CurrentSortBy = "rating"
        addonTable.CurrentIsAscending = false
    end

    for _, row in ipairs(rows) do
        if row.keyText then
            if showSecondaryMetric then row.keyText:Show() else row.keyText:Hide() end
        end
        if row.noteText then
            if isBrowser then
                ConfigureBrowserRowLayout(row)
            else
                ConfigureApplicantRowLayout(row)
            end
        end
        if row.noteText then
            if hideNotes then row.noteText:Hide() else row.noteText:Show() end
        end
        if row.dungeonText then
            if isBrowser then row.dungeonText:Show() else row.dungeonText:Hide() end
        end
        if row.roleIcon then
            if isBrowser then row.roleIcon:Hide() else row.roleIcon:Show() end
        end
        if row.ilvlText then
            if isBrowser then row.ilvlText:Hide() else row.ilvlText:Show() end
        end
        if row.compSlots then
            for _, slot in pairs(row.compSlots) do
                if isBrowser then slot:Show() else slot:Hide() end
            end
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
    if addonTable.UpdateTopBarActions then
        addonTable.UpdateTopBarActions()
    end
    UpdateApplicantContextBar()
    addonTable.UpdateHeaderVisuals()
    UpdateNotesToggleLayout()

    for _, row in ipairs(rows) do row:Hide() end

    local isBrowser = IsBrowserMode()
    local displayIndex = 1
    local isAltColor = false
    local showSecondaryMetric = UsesSecondaryMetricColumn()

    if isBrowser then
        local activeResults = {}
        for _, result in ipairs(addonTable.SearchResults or {}) do
            if not addonTable.ResultPassesBrowserFilters or addonTable.ResultPassesBrowserFilters(result) then
                table.insert(activeResults, result)
            end
        end

        table.sort(activeResults, function(a, b)
            return SortGroups(a, b, addonTable.CurrentSortBy, addonTable.CurrentIsAscending)
        end)

        for _, result in ipairs(activeResults) do
            if not rows[displayIndex] then rows[displayIndex] = CreateRow(displayIndex) end
            local row = rows[displayIndex]

            row.searchResultID = result.id
            row.searchResult = result
            row.groupID = nil
            row.applicantID = nil
            row.memberIdx = nil
            row.fullComment = result.comment
            row.rioProfile = result.leaderProfile
            row.memberRating = result.rating
            row.memberPvpRating = result.pvpRating
            row.memberPvpBracket = result.pvpBracket
            row.memberRaidProgress = result.raidProgress
            row.regionInfo = result.regionInfo

            row.bg:SetColorTexture(GetBrowserRowColor(result, isAltColor))

            ConfigureBrowserRowLayout(row)
            row.dungeonText:Show()
            row.roleIcon:Hide()
            row.ilvlText:Hide()
            for _, slot in pairs(row.compSlots) do
                slot:Show()
            end

            local setupSummary = GetBrowserSetupSummary(result)
            for index, slotInfo in ipairs(setupSummary) do
                SetBrowserCompSlot(row.compSlots[index], slotInfo.role, slotInfo.class, slotInfo.filled)
            end

            if GetListingMode() == "raid" or GetListingMode() == "legacy_raid" then
                row.nameText:SetText(GetRaidBrowserTitle(result))
            else
                row.nameText:SetText(result.displayName ~= "" and result.displayName or (result.activityName ~= "" and result.activityName or "--"))
            end
            row.specText:SetText(result.playstyleShortLabel or "--")
            row.ratingText:SetText(GetBrowserRatingDisplay(result))
            row.keyText:SetText(GetBrowserSecondaryDisplay(result))
            if showSecondaryMetric then row.keyText:Show() else row.keyText:Hide() end

            row.noteText:SetText(result.comment or "")
            row.dungeonText:SetText(result.dungeonName ~= "" and result.dungeonName or "--")

            row.statusText:Hide()
            row.declineBtn:Hide()
            row.inviteBtn:Show()
            if addonTable.IsAppliedStatus and addonTable.IsAppliedStatus(result.applicationStatus) then
                row.inviteBtn:SetNormalTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
                row.inviteBtn:SetScript("OnClick", function()
                    C_LFGList.CancelApplication(result.id)
                end)
                row.inviteBtn:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Cancel", 1, 0.2, 0.2)
                    GameTooltip:Show()
                end)
                row.inviteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            else
                row.inviteBtn:SetNormalTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
                row.inviteBtn:SetScript("OnClick", function()
                    if addonTable.ApplyToSearchResult then
                        addonTable.ApplyToSearchResult(result.id)
                    end
                    addonTable.UpdateDisplay()
                end)
                row.inviteBtn:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Apply", 0.2, 1, 0.2)
                    GameTooltip:Show()
                end)
                row.inviteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end

            row:Show()
            displayIndex = displayIndex + 1
            isAltColor = not isAltColor
        end
    else
        local activeGroups = {}
        for _, group in ipairs(addonTable.ApplicantGroups) do
            if addonTable.GroupPassesFilters(group) then
                table.insert(activeGroups, group)
            end
        end

        table.sort(activeGroups, function(a, b)
            return SortGroups(a, b, addonTable.CurrentSortBy, addonTable.CurrentIsAscending)
        end)

        for _, group in ipairs(activeGroups) do
            local isMulti = group.numMembers > 1
            local bgColor = isAltColor and addonTable.ROW_COLOR_B or addonTable.ROW_COLOR_A

            for i, member in ipairs(group.members) do
                if not rows[displayIndex] then rows[displayIndex] = CreateRow(displayIndex) end
            local row = rows[displayIndex]

                row.searchResultID = nil
                row.searchResult = nil
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
                row.regionInfo = addonTable.GetRegionInfoFromLeaderName and addonTable.GetRegionInfoFromLeaderName(member.name) or nil

                row.bg:SetColorTexture(unpack(bgColor))
                ConfigureApplicantRowLayout(row)
                row.dungeonText:Hide()
                row.roleIcon:Show()
                row.ilvlText:Show()
                for _, slot in pairs(row.compSlots) do
                    slot:Hide()
                end

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

                row.nameText:SetText(formattedName)
                row.ilvlText:SetText(member.ilvl)
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
                    row.inviteBtn:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText("Invite", 0.2, 1, 0.2)
                        GameTooltip:Show()
                    end)
                    row.inviteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    row.declineBtn:SetScript("OnClick", function()
                        C_LFGList.DeclineApplicant(group.id)
                    end)
                    row.declineBtn:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText("Decline", 1, 0.2, 0.2)
                        GameTooltip:Show()
                    end)
                    row.declineBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    row.inviteBtn:Show()
                    row.declineBtn:Show()
                else
                    row.noteText:SetText("")
                    row.inviteBtn:Hide()
                    row.declineBtn:Hide()
                    row.statusText:Hide()
                end

                row:Show()
                displayIndex = displayIndex + 1
            end

            isAltColor = not isAltColor
        end
    end

    scrollChild:SetHeight(math.max(1, (displayIndex - 1) * ROW_HEIGHT))
end
