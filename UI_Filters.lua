local addonName, addonTable = ...
local OAK_LFG = addonTable.OAK_LFG

addonTable.ClassFilters = {}
for _, class in ipairs(addonTable.ValidClasses) do addonTable.ClassFilters[class] = true end
addonTable.RoleFilters = { ["TANK"] = true, ["HEALER"] = true, ["DAMAGER"] = true }
local classToggleBoxes = {} 

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
        if addonTable.UpdateDisplay then addonTable.UpdateDisplay() end
    end)
    
    return box
end

local toggleFiltersBtn = addonTable.CreateFlatButton(addonTable.TitleHeader, "Filters", 60)
toggleFiltersBtn:SetPoint("RIGHT", addonTable.VersionText, "LEFT", -10, 0)

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

local filterPanel = CreateFrame("Frame", nil, OAK_LFG, "BackdropTemplate")
addonTable.FilterPanel = filterPanel
filterPanel:SetSize(190, 420) 
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
    for class, box in pairs(classToggleBoxes) do 
        box:SetState(addonTable.ClassFilters[class]) 
    end
    if addonTable.UpdateDisplay then addonTable.UpdateDisplay() end
end

local classData = {
    lust = {MAGE=true, SHAMAN=true, HUNTER=true, EVOKER=true},
    brez = {DEATHKNIGHT=true, DRUID=true, WARLOCK=true, PALADIN=true},
    plate = {WARRIOR=true, PALADIN=true, DEATHKNIGHT=true},
    mail = {HUNTER=true, SHAMAN=true, EVOKER=true},
    leather = {ROGUE=true, DRUID=true, MONK=true, DEMONHUNTER=true},
    cloth = {MAGE=true, PRIEST=true, WARLOCK=true}
}

local btnWidth = 75
local btnAll = addonTable.CreateFlatButton(filterPanel, "All", btnWidth)
btnAll:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, yOffset)
btnAll:SetScript("OnClick", function()
    for class, _ in pairs(addonTable.ClassFilters) do addonTable.ClassFilters[class] = true end
    for class, box in pairs(classToggleBoxes) do box:SetState(true) end
    if addonTable.UpdateDisplay then addonTable.UpdateDisplay() end
end)

local btnNone = addonTable.CreateFlatButton(filterPanel, "None", btnWidth)
btnNone:SetPoint("LEFT", btnAll, "RIGHT", 10, 0)
btnNone:SetScript("OnClick", function()
    for class, _ in pairs(addonTable.ClassFilters) do addonTable.ClassFilters[class] = false end
    for class, box in pairs(classToggleBoxes) do box:SetState(false) end
    if addonTable.UpdateDisplay then addonTable.UpdateDisplay() end
end)
yOffset = yOffset - 25

local btnLust = addonTable.CreateFlatButton(filterPanel, "Lust", btnWidth)
btnLust:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, yOffset)
btnLust:SetScript("OnClick", function() ApplyQuickFilter(classData.lust) end)

local btnBrez = addonTable.CreateFlatButton(filterPanel, "B-Rez", btnWidth)
btnBrez:SetPoint("LEFT", btnLust, "RIGHT", 10, 0)
btnBrez:SetScript("OnClick", function() ApplyQuickFilter(classData.brez) end)
yOffset = yOffset - 25

local btnPlate = addonTable.CreateFlatButton(filterPanel, "Plate", btnWidth)
btnPlate:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, yOffset)
btnPlate:SetScript("OnClick", function() ApplyQuickFilter(classData.plate) end)

local btnMail = addonTable.CreateFlatButton(filterPanel, "Mail", btnWidth)
btnMail:SetPoint("LEFT", btnPlate, "RIGHT", 10, 0)
btnMail:SetScript("OnClick", function() ApplyQuickFilter(classData.mail) end)
yOffset = yOffset - 25

local btnLeather = addonTable.CreateFlatButton(filterPanel, "Leather", btnWidth)
btnLeather:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 15, yOffset)
btnLeather:SetScript("OnClick", function() ApplyQuickFilter(classData.leather) end)

local btnCloth = addonTable.CreateFlatButton(filterPanel, "Cloth", btnWidth)
btnCloth:SetPoint("LEFT", btnLeather, "RIGHT", 10, 0)
btnCloth:SetScript("OnClick", function() ApplyQuickFilter(classData.cloth) end)
yOffset = yOffset - 20

local div2 = filterPanel:CreateTexture(nil, "ARTWORK")
div2:SetColorTexture(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 0.5)
div2:SetSize(160, 1)
div2:SetPoint("TOP", filterPanel, "TOP", 0, yOffset - 5)
yOffset = yOffset - 12

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

-- Decline Filtered Button
local btnDecline = addonTable.CreateFlatButton(filterPanel, "Decline Filtered", 160)
btnDecline:SetPoint("BOTTOM", filterPanel, "BOTTOM", 0, 15)
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
        local isValidClass = true
        if group.leadClass and group.leadClass ~= "UNKNOWN" and addonTable.ClassFilters[group.leadClass] == false then
            isValidClass = false
        end
        local isValidRole = true
        if group.leadRole and addonTable.RoleFilters[group.leadRole] == false then
            isValidRole = false
        end

        if not (isValidClass and isValidRole) then
            C_LFGList.DeclineApplicant(group.id)
            return
        end
    end
end)

-- Supporters Flyout Panel
local supportersPanel = CreateFrame("Frame", nil, OAK_LFG, "BackdropTemplate")
addonTable.SupportersPanel = supportersPanel
supportersPanel:SetSize(190, 420) 
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