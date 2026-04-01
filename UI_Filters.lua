local addonName, addonTable = ...
local OAK_LFG = addonTable.OAK_LFG

addonTable.ClassFilters = {}
for _, class in ipairs(addonTable.ValidClasses) do addonTable.ClassFilters[class] = true end
addonTable.RoleFilters = { ["TANK"] = true, ["HEALER"] = true, ["DAMAGER"] = true }
local classToggleBoxes = {} 
local quickFilterButtons = {}
local browserFilterButtons = {}
local browserActivityButtons = {}
local BrowserFilterState
local BROWSER_FILTER_VERSION = 4
local GetPartyRoleSupply

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
        local activityID = entryInfo and (entryInfo.activityID or (type(entryInfo.activityIDs) == "table" and entryInfo.activityIDs[1]))
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

    return isValidClass and GroupMatchesRoleFilters(group)
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

local function ResultMatchesSelectedActivities(result, filters)
    if type(filters.selectedActivities) ~= "table" then
        return true
    end

    local hasAnySelection = false
    for _, isSelected in pairs(filters.selectedActivities) do
        if isSelected then
            hasAnySelection = true
            break
        end
    end

    if not hasAnySelection then
        return true
    end

    return result.activityFilterKey and filters.selectedActivities[result.activityFilterKey] == true
end

local function ResultMatchesDifficulty(result, difficulty)
    if difficulty == "ANY" then
        return true
    end

    if difficulty == "MYTHIC_PLUS" then
        return result.isMythicPlus == true or result.difficultyToken == "MYTHIC_PLUS"
    elseif difficulty == "MYTHIC" then
        return result.difficultyID == 23 or result.difficultyToken == "MYTHIC"
    elseif difficulty == "HEROIC" then
        return result.difficultyID == 2 or result.difficultyToken == "HEROIC"
    elseif difficulty == "NORMAL" then
        return result.difficultyID == 1 or result.difficultyToken == "NORMAL"
    end

    return true
end

local function ResultMatchesPlaystyle(result, playstyle)
    if playstyle == "ANY" then
        return true
    end

    local short = strupper(result.playstyleShortLabel or "")
    if playstyle == "LEARNING" and short == "LEARN" then
        return true
    elseif playstyle == "RELAXED" and short == "RELAX" then
        return true
    elseif playstyle == "COMPETITIVE" and short == "COMP" then
        return true
    elseif playstyle == "CARRY" and short == "CARRY" then
        return true
    end

    local playstyleValue = tonumber(result.playstyleValue) or 0
    if playstyle == "LEARNING" then
        return playstyleValue == 1
    elseif playstyle == "RELAXED" then
        return playstyleValue == 2
    elseif playstyle == "COMPETITIVE" then
        return playstyleValue == 3 or playstyleValue == 4
    elseif playstyle == "CARRY" then
        local carryText = strlower((result.name or "") .. " " .. (result.comment or ""))
        return carryText:find("carry", 1, true) or carryText:find("boost", 1, true)
    end

    return true
end

local function ResultMatchesKeyRange(result, filters)
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

local function ResultMatchesRoleNeeds(result, filters)
    if filters.hasTank and (result.roleCounts.TANK or 0) == 0 then
        return false
    end
    if filters.hasHealer and (result.roleCounts.HEALER or 0) == 0 then
        return false
    end

    local maxPlayers = result.activityInfo and tonumber(result.activityInfo.maxPlayers) or 0
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

local function ResultMatchesPartyFit(result)
    local partyRoles, partySize = GetPartyRoleSupply()
    local maxPlayers = result.activityInfo and tonumber(result.activityInfo.maxPlayers) or 0
    if maxPlayers > 0 and result.numMembers + partySize > maxPlayers then
        return false
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

function addonTable.ResultPassesBrowserFilters(result)
    local filters = BrowserFilterState()
    if filters.hideDeclined and string.find(result.applicationStatus or "", "declined", 1, true) then
        return false
    end

    return true
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
    if addonTable.UpdateBrowserFilterPanel then
        addonTable.UpdateBrowserFilterPanel()
    end
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

    advancedFilter.roleTank = filters.needsTank or false
    advancedFilter.roleHealer = filters.needsHealer or false
    advancedFilter.roleDamage = filters.needsDPS or false

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
            self:SetBackdropColor(0.106, 0.106, 0.129, 1) 
            self:SetBackdropBorderColor(0, 0, 0, 1) 
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

local toggleFiltersBtn = addonTable.CreateFlatButton(addonTable.TitleHeader, "Filters", 60)
toggleFiltersBtn:SetPoint("RIGHT", addonTable.CloseButton, "LEFT", -10, 0)

local refreshBtn = addonTable.CreateFlatButton(addonTable.TitleHeader, "Refresh", 60)
refreshBtn:SetPoint("RIGHT", toggleFiltersBtn, "LEFT", -5, 0)

local delistBtn = addonTable.CreateFlatButton(addonTable.TitleHeader, "Delist", 60)
delistBtn:SetPoint("RIGHT", refreshBtn, "LEFT", -5, 0)

function addonTable.UpdateTopBarActions()
    if addonTable.GetCurrentViewMode and addonTable.GetCurrentViewMode() == "browser" then
        delistBtn:Hide()

        refreshBtn.text:SetText("Refresh")
        refreshBtn:SetScript("OnClick", function()
            if addonTable.FetchSearchResultData then
                addonTable.FetchSearchResultData()
            end
            if addonTable.UpdateDisplay then
                addonTable.UpdateDisplay()
            end
        end)
    else
        delistBtn:Show()
        delistBtn.text:SetText("Delist")
        delistBtn:SetScript("OnClick", function()
            C_LFGList.RemoveListing()
        end)

        refreshBtn.text:SetText("Refresh")
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
    scaleSlider:ClearAllPoints()
    scaleEdit:ClearAllPoints()
    scaleReset:ClearAllPoints()

    if hideNotes then
        title:SetText(addonTable.CompactTitleText or "OAK LFG")
        scaleLabel:Hide()
        scaleEdit:Hide()
        scaleReset:Show()

        scaleSlider:SetWidth(60)
        scaleSlider:SetPoint("LEFT", title, "RIGHT", 12, 0)
        scaleReset:SetWidth(20)
        scaleReset.text:SetText("R")
        scaleReset:SetPoint("LEFT", scaleSlider, "RIGHT", 3, 0)

        toggleFiltersBtn:SetWidth(54)
        refreshBtn:SetWidth(58)
        delistBtn:SetWidth(54)

        toggleFiltersBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
        refreshBtn:SetPoint("RIGHT", toggleFiltersBtn, "LEFT", -4, 0)
        if addonTable.GetCurrentViewMode and addonTable.GetCurrentViewMode() ~= "browser" then
            delistBtn:SetPoint("RIGHT", refreshBtn, "LEFT", -4, 0)
        end
    else
        title:SetText(addonTable.FullTitleText or "OAK LFG Sorter")
        scaleLabel:Show()
        scaleEdit:Show()
        scaleReset:Show()

        scaleSlider:SetWidth(80)
        scaleSlider:SetPoint("LEFT", title, "RIGHT", 45, 0)
        scaleEdit:SetPoint("LEFT", scaleSlider, "RIGHT", 10, 0)
        scaleReset:SetWidth(45)
        scaleReset.text:SetText("Reset")
        scaleReset:SetPoint("LEFT", scaleEdit, "RIGHT", 5, 0)

        toggleFiltersBtn:SetWidth(60)
        refreshBtn:SetWidth(60)
        delistBtn:SetWidth(60)

        toggleFiltersBtn:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
        refreshBtn:SetPoint("RIGHT", toggleFiltersBtn, "LEFT", -5, 0)
        if addonTable.GetCurrentViewMode and addonTable.GetCurrentViewMode() ~= "browser" then
            delistBtn:SetPoint("RIGHT", refreshBtn, "LEFT", -5, 0)
        end
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
filterPanel:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
filterPanel:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)

local filterTitle = filterPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontLarge")
filterTitle:SetPoint("TOP", filterPanel, "TOP", 0, -10)
filterTitle:SetText("Filters")
filterTitle:SetTextColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b)

local yOffset = -35
local rolesToFilter = { {"TANK", "Tank"}, {"HEALER", "Healer"}, {"DAMAGER", "DPS"} }

for _, rData in ipairs(rolesToFilter) do
    local rKey, rLabel = rData[1], rData[2]
    local box = CreateOakToggleBox(filterPanel, rKey, addonTable.RoleFilters)
    box:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, yOffset)
    local text = filterPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    text:SetPoint("LEFT", box, "RIGHT", 8, 0)
    text:SetText(rLabel)
    yOffset = yOffset - 22
end

local div1 = filterPanel:CreateTexture(nil, "ARTWORK")
div1:SetColorTexture(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 0.5)
div1:SetSize(160, 1)
div1:SetPoint("TOP", filterPanel, "TOP", 0, yOffset - 3)
yOffset = yOffset - 12

local function ApplyQuickFilter(filterMap)
    for class, _ in pairs(addonTable.ClassFilters) do 
        addonTable.ClassFilters[class] = filterMap[class] or false 
    end
    SyncClassFilterBoxes()
    RefreshFilters()
end

local btnWidth = 75
local btnAll = addonTable.CreateFlatButton(filterPanel, "All", btnWidth)
quickFilterButtons.all = btnAll
btnAll:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, yOffset)
btnAll:SetScript("OnClick", function()
    SetAllClassFilters(true)
end)

local btnNone = addonTable.CreateFlatButton(filterPanel, "None", btnWidth)
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

local div2 = filterPanel:CreateTexture(nil, "ARTWORK")
div2:SetColorTexture(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 0.5)
div2:SetSize(160, 1)
div2:SetPoint("TOP", filterPanel, "TOP", 0, yOffset - 5)
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

local bottomDivider = filterPanel:CreateTexture(nil, "ARTWORK")
bottomDivider:SetColorTexture(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 0.35)
bottomDivider:SetSize(160, 1)
bottomDivider:SetPoint("BOTTOM", filterPanel, "BOTTOM", 0, 82)

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
browserFilterPanel:SetSize(210, 452)
browserFilterPanel:SetPoint("TOPLEFT", OAK_LFG, "TOPRIGHT", -2, 0)
browserFilterPanel:Hide()
browserFilterPanel:SetFrameLevel(OAK_LFG:GetFrameLevel() - 1)
browserFilterPanel:SetBackdrop({
    bgFile = addonTable.FLAT_TEX,
    edgeFile = addonTable.FLAT_TEX,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
browserFilterPanel:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
browserFilterPanel:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)

local browserTitle = browserFilterPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontLarge")
browserTitle:SetPoint("TOP", browserFilterPanel, "TOP", 0, -10)
browserTitle:SetText("Search Filters")
browserTitle:SetTextColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b)

local browserContent = CreateFrame("Frame", nil, browserFilterPanel)
browserContent:SetPoint("TOPLEFT", browserFilterPanel, "TOPLEFT", 14, -42)
browserContent:SetPoint("TOPRIGHT", browserFilterPanel, "TOPRIGHT", -14, -42)
browserContent:SetHeight(396)

local activeBrowserDropdowns = {}

local function HideAllBrowserDropdowns(exceptFrame)
    for _, dropdown in ipairs(activeBrowserDropdowns) do
        if dropdown ~= exceptFrame and dropdown.listFrame then
            dropdown.listFrame:Hide()
        end
    end
end

function BrowserFilterState()
    OakLFGSorterDB.browserFilters = OakLFGSorterDB.browserFilters or {}
    if OakLFGSorterDB.browserFilters.version ~= BROWSER_FILTER_VERSION then
        OakLFGSorterDB.browserFilters = {
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
            partyFit = false,
            needsLust = false,
            needsBrez = false,
            hideDeclined = false,
            selectedActivities = {},
        }
    end
    local filters = OakLFGSorterDB.browserFilters
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

    if type(OakLFGSorterDB.browserFilters.selectedActivities) ~= "table" then
        OakLFGSorterDB.browserFilters.selectedActivities = {}
    else
        local normalized = {}
        for key, value in pairs(OakLFGSorterDB.browserFilters.selectedActivities) do
            if type(key) == "string" and value then
                normalized[key] = true
            end
        end
        OakLFGSorterDB.browserFilters.selectedActivities = normalized
    end
    return OakLFGSorterDB.browserFilters
end

local function CreateBrowserToggleBox(parent, key)
    local box = CreateFrame("Button", nil, parent, "BackdropTemplate")
    box:SetSize(16, 16)
    box:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})

    function box:SetState(isActive)
        if isActive then
            self:SetBackdropColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
        else
            self:SetBackdropColor(0.106, 0.106, 0.129, 1)
        end
        self:SetBackdropBorderColor(0, 0, 0, 1)
    end

    box:SetScript("OnClick", function(self)
        local filters = BrowserFilterState()
        filters[key] = not filters[key]
        self:SetState(filters[key])
        if key == "needsTank" or key == "needsHealer" or key == "needsDPS" then
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
        local options = button.getOptions()
        listFrame:SetHeight((#options * 22) + 2)

        for _, optionButton in ipairs(button.optionButtons) do
            optionButton:Hide()
        end

        for index, option in ipairs(options) do
            local optionButton = button.optionButtons[index]
            if not optionButton then
                optionButton = CreateFrame("Button", nil, listFrame, "BackdropTemplate")
                optionButton:SetBackdrop({ bgFile = addonTable.FLAT_TEX })
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
            optionButton:SetSize(width - 2, 22)
            optionButton.bg:SetColorTexture(unpack(addonTable.OAK_COLOR_BG))
            optionButton.text:SetText(option.label)
            optionButton:SetScript("OnClick", function()
                local filters = BrowserFilterState()
                filters[button.filterKey] = option.value
                UpdateText()
                listFrame:Hide()
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

local function GetBrowserDifficultyOptions()
    local mode = (addonTable.CurrentSearchContext and addonTable.CurrentSearchContext.mode) or "generic"
    if mode == "raid" or mode == "legacy_raid" then
        return {
            { value = "ANY", label = "Any Difficulty" },
            { value = "NORMAL", label = "Normal" },
            { value = "HEROIC", label = "Heroic" },
            { value = "MYTHIC", label = "Mythic" },
        }
    elseif mode == "rated_pvp" or mode == "pvp" then
        return {
            { value = "ANY", label = "Any Difficulty" },
        }
    end

    return {
        { value = "ANY", label = "Any Difficulty" },
        { value = "MYTHIC_PLUS", label = "Mythic+" },
        { value = "MYTHIC", label = "Mythic" },
        { value = "HEROIC", label = "Heroic" },
        { value = "NORMAL", label = "Normal" },
    }
end

local playstyleDropdown = CreateBrowserDropdown(browserContent, 188, function()
    return {
        { value = "ANY", label = "Any Playstyle" },
        { value = "COMPETITIVE", label = "Competitive" },
        { value = "RELAXED", label = "Relaxed" },
        { value = "LEARNING", label = "Learning" },
        { value = "CARRY", label = "Carry Offered" },
    }
end, "playstyle", "Any Playstyle")

local difficultyDropdown = CreateBrowserDropdown(browserContent, 188, GetBrowserDifficultyOptions, "difficulty", "Any Difficulty")
local keyRangeLabel = browserContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
keyRangeLabel:SetText("Key Range")
keyRangeLabel:SetTextColor(1, 1, 1)
local keyMinBox = CreateBrowserNumberBox(browserContent, "keyMin", 48)
local keyRangeTo = browserContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
keyRangeTo:SetText("to")
local keyMaxBox = CreateBrowserNumberBox(browserContent, "keyMax", 48)
local browserToggleKeys = {
    { key = "hasTank", label = "Has Tank", column = 1 },
    { key = "needsTank", label = "Need Tank", column = 2 },
    { key = "hasHealer", label = "Has Heal", column = 1 },
    { key = "needsHealer", label = "Need Heal", column = 2 },
    { key = "needsDPS", label = "Need DPS", column = 1 },
    { key = "partyFit", label = "Party Fit", column = 2 },
    { key = "needsLust", label = "Need Lust", column = 1 },
    { key = "needsBrez", label = "Need BRez", column = 2 },
    { key = "hideDeclined", label = "Hide Declined", column = 1, span = 2 },
}

local browserToggleRows = {}
for _, toggleInfo in ipairs(browserToggleKeys) do
    local box = CreateBrowserToggleBox(browserContent, toggleInfo.key)
    local text = browserContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    browserToggleRows[toggleInfo.key] = { box = box, text = text, label = toggleInfo.label }
    text:SetPoint("LEFT", box, "RIGHT", 8, 0)
    text:SetText(toggleInfo.label)
end

local activityDivider = browserContent:CreateTexture(nil, "ARTWORK")
activityDivider:SetTexture(addonTable.FLAT_TEX)
activityDivider:SetVertexColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 0.7)

local activityHeader = browserContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
activityHeader:SetText("Filter Activities")
activityHeader:SetTextColor(1, 1, 1)

local function GetBrowserActivitySectionTitle()
    local mode = (addonTable.CurrentSearchContext and addonTable.CurrentSearchContext.mode) or "generic"
    if mode == "raid" or mode == "legacy_raid" then
        return "Filter Raids"
    elseif mode == "pvp" or mode == "rated_pvp" then
        return "Filter Brackets"
    elseif mode == "mythic_plus" or mode == "generic" or mode == "delve" then
        return "Filter Dungeons"
    end

    return "Filter Activities"
end

local function UpdateBrowserActivityButtons(startY)
    local filters = BrowserFilterState()
    local activities = addonTable.GetAvailableBrowserActivities and addonTable.GetAvailableBrowserActivities() or {}
    local validKeys = {}

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
    end

    local y = startY
    for index, entry in ipairs(activities) do
        local button = browserActivityButtons[index]
        if not button then
            button = CreateBrowserToggleBox(browserContent, "")
            button.text = browserContent:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
            button.text:SetPoint("LEFT", button, "RIGHT", 8, 0)
            button.text:SetPoint("RIGHT", browserContent, "RIGHT", -4, 0)
            button.text:SetJustifyH("LEFT")
            browserActivityButtons[index] = button
        end

        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, y)
        button.activityID = entry.activityID
        button.filterKey = entry.filterKey
        button.text:SetText(entry.label)
        button:SetState(filters.selectedActivities[entry.filterKey] == true)
        button:SetScript("OnClick", function(self)
            filters.selectedActivities[self.filterKey] = not filters.selectedActivities[self.filterKey]
            self:SetState(filters.selectedActivities[self.filterKey] == true)
            RefreshBrowserFilters()
        end)
        button.text:Show()
        button:Show()
        y = y - 22
    end

    return y
end

function addonTable.UpdateBrowserFilterPanel()
    local filters = BrowserFilterState()
    difficultyDropdown:ClearAllPoints()
    difficultyDropdown:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, 0)
    difficultyDropdown.UpdateText()

    playstyleDropdown:Hide()
    HideAllBrowserDropdowns()

    keyRangeLabel:ClearAllPoints()
    keyRangeLabel:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, -34)
    keyMinBox:ClearAllPoints()
    keyMinBox:SetPoint("TOPLEFT", keyRangeLabel, "BOTTOMLEFT", 0, -4)
    keyMinBox:SetText(filters.keyMin or "")

    keyRangeTo:ClearAllPoints()
    keyRangeTo:SetPoint("LEFT", keyMinBox, "RIGHT", 6, 0)
    keyMaxBox:ClearAllPoints()
    keyMaxBox:SetPoint("LEFT", keyRangeTo, "RIGHT", 6, 0)
    keyMaxBox:SetText(filters.keyMax or "")

    local leftColumnX = 0
    local rightColumnX = 108
    local toggleY = -70
    local rowHeight = 20
    for _, toggleInfo in ipairs(browserToggleKeys) do
        local row = browserToggleRows[toggleInfo.key]
        row.box:ClearAllPoints()
        row.text:ClearAllPoints()
        local x = toggleInfo.column == 2 and rightColumnX or leftColumnX
        row.box:SetPoint("TOPLEFT", browserContent, "TOPLEFT", x, toggleY)
        row.box:SetState(filters[toggleInfo.key] == true)
        row.text:SetText(row.label)
        row.text:SetPoint("LEFT", row.box, "RIGHT", 8, 0)

        if toggleInfo.span == 2 then
            toggleY = toggleY - rowHeight
        elseif toggleInfo.column == 2 then
            toggleY = toggleY - rowHeight
        end
    end

    activityDivider:ClearAllPoints()
    activityDivider:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, toggleY - 4)
    activityDivider:SetPoint("TOPRIGHT", browserContent, "TOPRIGHT", 0, toggleY - 4)
    activityDivider:SetHeight(1)

    activityHeader:ClearAllPoints()
    activityHeader:SetText(GetBrowserActivitySectionTitle())
    activityHeader:SetPoint("TOPLEFT", browserContent, "TOPLEFT", 0, toggleY - 16)

    local endY = UpdateBrowserActivityButtons(toggleY - 34)
    browserContent:SetHeight(math.max(1, math.abs(endY) + 20))
end

function addonTable.UpdateFilterPaneMode()
    local isBrowser = addonTable.GetCurrentViewMode and addonTable.GetCurrentViewMode() == "browser"
    if isBrowser then
        filterPanel:Hide()
        browserFilterPanel:Show()
        addonTable.UpdateBrowserFilterPanel()
    else
        HideAllBrowserDropdowns()
        browserFilterPanel:Hide()
    end
end

-- Supporters Flyout Panel
local supportersPanel = CreateFrame("Frame", nil, OAK_LFG, "BackdropTemplate")
addonTable.SupportersPanel = supportersPanel
supportersPanel:SetSize(190, 410) 
supportersPanel:SetPoint("TOPLEFT", OAK_LFG, "TOPRIGHT", -2, 0)
supportersPanel:Hide()
supportersPanel:SetFrameLevel(OAK_LFG:GetFrameLevel() - 1) 
supportersPanel:SetBackdrop({
    bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, tile = false, edgeSize = 1, 
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
})
supportersPanel:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
supportersPanel:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)

local suppTitle = supportersPanel:CreateFontString(nil, "OVERLAY", "OakLFG_FontLarge")
suppTitle:SetPoint("TOP", supportersPanel, "TOP", 0, -10)
suppTitle:SetText("Supporters")
suppTitle:SetTextColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b)

local suppScroll = CreateFrame("ScrollFrame", "OakLFGSupportersScroll", supportersPanel, "UIPanelScrollFrameTemplate")
suppScroll:SetPoint("TOPLEFT", supportersPanel, "TOPLEFT", 10, -35)
suppScroll:SetPoint("BOTTOMRIGHT", supportersPanel, "BOTTOMRIGHT", -25, 160) 

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

local syOffset = 0
if addonTable.Patreons then
    for _, name in ipairs(addonTable.Patreons) do
        local pt = suppScrollChild:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
        pt:SetPoint("TOPLEFT", suppScrollChild, "TOPLEFT", 5, syOffset)
        pt:SetText(name)
        pt:SetTextColor(0.8, 0.8, 0.8)
        syOffset = syOffset - 18
    end
end
suppScrollChild:SetHeight(math.max(1, math.abs(syOffset)))

local socialY = -275
if addonTable.Socials then
    for _, social in ipairs(addonTable.Socials) do
        local btn = addonTable.CreateFlatButton(supportersPanel, social.name, 160)
        btn:SetPoint("TOP", supportersPanel, "TOP", 0, socialY)
        btn:SetScript("OnClick", function()
            StaticPopup_Show("OAK_LFG_URL_COPY", "", "", social.url)
        end)
        socialY = socialY - 25
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
        supportersPanel:Hide()
        inactivePanel:Hide()
        activePanel:Show()
    end
    if addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(addonTable.OAK_LFG)
    end
end)

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
            text:SetText("Auto-Open Sorter")
            
            lfgToggleBox:SetScript("OnClick", function(self)
                OakLFGSorterDB.autoOpen = not OakLFGSorterDB.autoOpen
                if OakLFGSorterDB.autoOpen then
                    self:SetBackdropColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1) 
                    OAK_LFG:Show()
                else
                    self:SetBackdropColor(0.106, 0.106, 0.129, 1) 
                    OAK_LFG:Hide()
                end
            end)
            
            if OakLFGSorterDB.autoOpen then
                lfgToggleBox:SetBackdropColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
            else
                lfgToggleBox:SetBackdropColor(0.106, 0.106, 0.129, 1)
            end

            LFGListFrame.ApplicationViewer:HookScript("OnShow", function()
                if OakLFGSorterDB and OakLFGSorterDB.autoOpen then OAK_LFG:Show() end
            end)
        end
    end

    if LFGListFrame and LFGListFrame.SearchPanel and not addonTable.SearchPanelHooked then
        addonTable.SearchPanelHooked = true
        LFGListFrame.SearchPanel:HookScript("OnShow", function()
            if not C_LFGList.HasActiveEntryInfo() then
                OAK_LFG:Hide()
            end
        end)
    end
end

addonTable.UpdateTopBarLayout()
addonTable.UpdateTopBarActions()
