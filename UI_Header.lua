local addonName, addonTable = ...

local OAK_LFG = CreateFrame("Frame", "OakensoulLFGSorterFrame", UIParent, "BackdropTemplate")
addonTable.OAK_LFG = OAK_LFG 
OAK_LFG:SetSize(660, 444) 
OAK_LFG:SetPoint("CENTER")
OAK_LFG:SetMovable(true)
OAK_LFG:SetResizable(true)
OAK_LFG:SetResizeBounds(660, 444, 660, 800) 
OAK_LFG:EnableMouse(true)
OAK_LFG:RegisterForDrag("LeftButton")
OAK_LFG:SetScript("OnDragStart", OAK_LFG.StartMoving)
OAK_LFG:SetFrameStrata("DIALOG")
OAK_LFG:Hide()

_G["OakensoulLFGSorterFrame"] = OAK_LFG
tinsert(UISpecialFrames, "OakensoulLFGSorterFrame")

OAK_LFG:SetBackdrop({
    bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX,
    tile = false, edgeSize = 1, 
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
})
OAK_LFG:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
OAK_LFG:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)

local titleHeader = CreateFrame("Frame", nil, OAK_LFG)
addonTable.TitleHeader = titleHeader
titleHeader:SetPoint("TOPLEFT", OAK_LFG, "TOPLEFT", 1, -1) 
titleHeader:SetPoint("TOPRIGHT", OAK_LFG, "TOPRIGHT", -1, -1) 
titleHeader:SetHeight(30)
local thBg = titleHeader:CreateTexture(nil, "BACKGROUND")
thBg:SetAllPoints()
thBg:SetColorTexture(unpack(addonTable.OAK_COLOR_PANE))

OAK_LFG.title = titleHeader:CreateFontString(nil, "OVERLAY", "OakLFG_FontLarge")
OAK_LFG.title:SetPoint("LEFT", titleHeader, "LEFT", 15, 0)
OAK_LFG.title:SetText(addonTable.ApplyClassColor("OAK", addonTable.PlayerClass) .. " LFG Sorter")
addonTable.FullTitleText = addonTable.ApplyClassColor("OAK", addonTable.PlayerClass) .. " LFG Sorter"
addonTable.CompactTitleText = addonTable.ApplyClassColor("OAK", addonTable.PlayerClass) .. " LFG"

-- Scale UI Elements
local scaleSlider = CreateFrame("Slider", "OakLFGScaleSlider", titleHeader, "BackdropTemplate")
scaleSlider:SetSize(80, 10)
scaleSlider:SetPoint("LEFT", OAK_LFG.title, "RIGHT", 45, 0)
scaleSlider:SetMinMaxValues(0.5, 1.5)
scaleSlider:SetValueStep(0.05)
scaleSlider:SetObeyStepOnDrag(true)
scaleSlider:SetOrientation("HORIZONTAL")
scaleSlider:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
scaleSlider:SetBackdropColor(0.05, 0.05, 0.05, 1)
scaleSlider:SetBackdropBorderColor(0, 0, 0, 1)

local thumb = scaleSlider:CreateTexture(nil, "ARTWORK")
thumb:SetTexture(addonTable.FLAT_TEX)
thumb:SetVertexColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
thumb:SetSize(10, 14)
scaleSlider:SetThumbTexture(thumb)

local scaleLabel = scaleSlider:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
scaleLabel:SetPoint("RIGHT", scaleSlider, "LEFT", -8, 0)
scaleLabel:SetText("Scale")

local scaleEdit = CreateFrame("EditBox", nil, titleHeader, "BackdropTemplate")
scaleEdit:SetSize(35, 18)
scaleEdit:SetPoint("LEFT", scaleSlider, "RIGHT", 10, 0)
scaleEdit:SetAutoFocus(false)
scaleEdit:SetFontObject("OakLFG_FontRegular")
scaleEdit:SetJustifyH("CENTER")
scaleEdit:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
scaleEdit:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
scaleEdit:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))

local scaleReset = addonTable.CreateFlatButton(titleHeader, "Reset", 45)
scaleReset:SetPoint("LEFT", scaleEdit, "RIGHT", 5, 0)
scaleReset:SetScript("OnEnter", function(self) 
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Reset Position & Scale", 1, 1, 1)
    GameTooltip:Show()
end)
scaleReset:SetScript("OnLeave", function(self) 
    self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)

scaleSlider:SetScript("OnMouseDown", function(self) self.isDragging = true end)

scaleSlider:SetScript("OnMouseUp", function(self) 
    self.isDragging = false
    local rounded = math.floor(self:GetValue() * 100 + 0.5) / 100
    OAK_LFG:SetScale(rounded)
    if OakLFGSorterDB then OakLFGSorterDB.scale = rounded end
end)

scaleSlider:SetScript("OnValueChanged", function(self, value)
    local rounded = math.floor(value * 100 + 0.5) / 100
    scaleEdit:SetText(string.format("%.2f", rounded))
    
    if not self.isDragging then
        OAK_LFG:SetScale(rounded)
        if OakLFGSorterDB then OakLFGSorterDB.scale = rounded end
    end
end)

scaleEdit:SetScript("OnEnterPressed", function(self)
    local val = tonumber(self:GetText())
    if val then
        val = math.max(0.5, math.min(1.5, val))
        scaleSlider:SetValue(val)
    end
    self:ClearFocus()
end)

function addonTable.AutoPosition()
    if not addonTable.OAK_LFG then return end
    if OakLFGSorterDB and OakLFGSorterDB.framePos then
        if addonTable.AnchorRIOPanelToOak then
            addonTable.AnchorRIOPanelToOak(addonTable.OAK_LFG)
        end
        return
    end 

    if PVEFrame and PVEFrame:IsShown() then
        addonTable.OAK_LFG:ClearAllPoints()
        addonTable.OAK_LFG:SetPoint("TOPLEFT", PVEFrame, "TOPRIGHT", 2, 0)
        if addonTable.AnchorRIOPanelToOak then
            addonTable.AnchorRIOPanelToOak(addonTable.OAK_LFG)
        end
    elseif not addonTable.OAK_LFG:GetPoint() then
        addonTable.OAK_LFG:ClearAllPoints()
        addonTable.OAK_LFG:SetPoint("CENTER")
    end
end

function addonTable.AnchorRIOPanelToOak(ownerFrame)
    if not (ownerFrame and RaiderIO_ProfileTooltip and RaiderIO_ProfileTooltip:IsShown()) then
        return
    end

    local anchorTarget = ownerFrame
    if ownerFrame == addonTable.OAK_LFG then
        if addonTable.BrowserFilterPanel and addonTable.BrowserFilterPanel:IsShown() then
            anchorTarget = addonTable.BrowserFilterPanel
        elseif addonTable.FilterPanel and addonTable.FilterPanel:IsShown() then
            anchorTarget = addonTable.FilterPanel
        elseif addonTable.SupportersPanel and addonTable.SupportersPanel:IsShown() then
            anchorTarget = addonTable.SupportersPanel
        end
    elseif ownerFrame == addonTable.OAK_SEARCH then
        if addonTable.SearchFilterPanel and addonTable.SearchFilterPanel:IsShown() then
            anchorTarget = addonTable.SearchFilterPanel
        elseif addonTable.SearchSupportersPanel and addonTable.SearchSupportersPanel:IsShown() then
            anchorTarget = addonTable.SearchSupportersPanel
        end
    end

    RaiderIO_ProfileTooltip:ClearAllPoints()
    RaiderIO_ProfileTooltip:SetPoint("TOPLEFT", anchorTarget, "TOPRIGHT", 2, 0)
end

function addonTable.RefreshRIOAnchor()
    if addonTable.OAK_SEARCH and addonTable.OAK_SEARCH:IsShown() then
        addonTable.AnchorRIOPanelToOak(addonTable.OAK_SEARCH)
    elseif addonTable.OAK_LFG and addonTable.OAK_LFG:IsShown() then
        addonTable.AnchorRIOPanelToOak(addonTable.OAK_LFG)
    elseif RaiderIO_ProfileTooltip and RaiderIO_ProfileTooltip:IsShown() then
        local fallback = nil
        if LFGListFrame and LFGListFrame:IsShown() then
            fallback = LFGListFrame
        elseif PVEFrame and PVEFrame:IsShown() then
            fallback = PVEFrame
        end
        if fallback then
            RaiderIO_ProfileTooltip:ClearAllPoints()
            RaiderIO_ProfileTooltip:SetPoint("TOPLEFT", fallback, "TOPRIGHT", 2, 0)
        end
    end
end

local rioHooked = false
function addonTable.CheckRIOHook()
    if not rioHooked and RaiderIO_ProfileTooltip then
        rioHooked = true
        RaiderIO_ProfileTooltip:HookScript("OnHide", function()
            if addonTable.OAK_LFG:IsShown() then addonTable.AutoPosition() end
        end)
        RaiderIO_ProfileTooltip:HookScript("OnShow", function()
            addonTable.RefreshRIOAnchor()
        end)
    end
end

OAK_LFG:HookScript("OnShow", function()
    addonTable.RefreshRIOAnchor()
end)

OAK_LFG:HookScript("OnHide", function()
    addonTable.RefreshRIOAnchor()
end)

scaleReset:SetScript("OnClick", function()
    scaleSlider:SetValue(1.0)
    if OakLFGSorterDB then OakLFGSorterDB.framePos = nil end 
    addonTable.AutoPosition() 
end)

addonTable.ScaleSlider = scaleSlider
addonTable.ScaleEdit = scaleEdit
addonTable.ScaleLabel = scaleLabel
addonTable.ScaleReset = scaleReset

local closeBtn = CreateFrame("Button", nil, titleHeader)
closeBtn:SetSize(30, 30)
closeBtn:SetPoint("RIGHT", titleHeader, "RIGHT", 0, 0)
local clBg = closeBtn:CreateTexture(nil, "BACKGROUND")
clBg:SetAllPoints()
clBg:SetColorTexture(0, 0, 0, 0)
closeBtn.text = closeBtn:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
closeBtn.text:SetPoint("CENTER")
closeBtn.text:SetText("X")
closeBtn:SetScript("OnClick", function() OAK_LFG:Hide() end)
closeBtn:SetScript("OnEnter", function() clBg:SetColorTexture(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 0.5) end)
closeBtn:SetScript("OnLeave", function() clBg:SetColorTexture(0, 0, 0, 0) end)
addonTable.CloseButton = closeBtn

local VersionText = titleHeader:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
addonTable.VersionText = VersionText
VersionText:SetPoint("RIGHT", closeBtn, "LEFT", -5, 0)
VersionText:SetText("|cff888888v1.6.7|r")
VersionText:Hide()

local resizeGrip = CreateFrame("Button", nil, OAK_LFG, "PanelResizeButtonTemplate")
addonTable.ResizeGrip = resizeGrip
resizeGrip:SetPoint("BOTTOMRIGHT", OAK_LFG, "BOTTOMRIGHT", -2, 2)
resizeGrip:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then OAK_LFG:StartSizing("BOTTOMRIGHT") end
end)

StaticPopupDialogs["OAK_LFG_URL_COPY"] = {
    text = "Press Ctrl+C to copy the link",
    hasEditBox = 1,
    button1 = OKAY,
    OnShow = function(self, data)
        local editBox = _G[self:GetName().."EditBox"] or self.editBox
        if editBox then
            editBox:SetText(data or self.data or "")
            editBox:HighlightText()
            editBox:SetFocus()
        end
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

OAK_LFG:HookScript("OnHide", function()
    GameTooltip:Hide()
end)
