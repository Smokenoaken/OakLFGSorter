local addonName, addonTable = ...
local OAK_LFG = addonTable.OAK_LFG

addonTable.ClassFilters = {}
for _, class in ipairs(addonTable.ValidClasses) do addonTable.ClassFilters[class] = true end
addonTable.RoleFilters = { ["TANK"] = true, ["HEALER"] = true, ["DAMAGER"] = true }
local classToggleBoxes = {} 
local quickFilterButtons = {}

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
    if not group.members then return false end
    for _, member in ipairs(group.members) do
        if member.role and addonTable.RoleFilters[member.role] then
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
refreshBtn:SetScript("OnClick", function()
    C_LFGList.RefreshApplicants()
end)

local delistBtn = addonTable.CreateFlatButton(addonTable.TitleHeader, "Delist", 60)
delistBtn:SetPoint("RIGHT", refreshBtn, "LEFT", -5, 0)
delistBtn:SetScript("OnClick", function()
    C_LFGList.RemoveListing()
end)

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
        delistBtn:SetPoint("RIGHT", refreshBtn, "LEFT", -4, 0)
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
        delistBtn:SetPoint("RIGHT", refreshBtn, "LEFT", -5, 0)
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
bottomDivider:SetPoint("BOTTOM", filterPanel, "BOTTOM", 0, 70)

-- Decline Filtered Button
local btnDecline = addonTable.CreateFlatButton(filterPanel, "Decline Filtered", 160)
btnDecline:SetPoint("BOTTOM", filterPanel, "BOTTOM", 0, 48)
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

local mutePingBox = CreateOakToggleBox(filterPanel, "muteApplicantPing", OakLFGSorterDB)
mutePingBox:SetPoint("TOPLEFT", btnDecline, "BOTTOMLEFT", 0, -8)

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
    if filterPanel:IsShown() then
        filterPanel:Hide()
    else
        supportersPanel:Hide()
        filterPanel:Show()
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
end

addonTable.UpdateTopBarLayout()
