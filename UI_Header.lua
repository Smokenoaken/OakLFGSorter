local addonName, addonTable = ...
local L = addonTable.L

local OAK_LFG = CreateFrame("Frame", "OakensoulLFGSorterFrame", UIParent, "BackdropTemplate")
addonTable.OAK_LFG = OAK_LFG 
OAK_LFG:SetSize(660, 444) 
OAK_LFG:SetPoint("CENTER")
OAK_LFG:SetMovable(true)
OAK_LFG:SetResizable(true)
OAK_LFG:SetResizeBounds(660, 444, 660, 800) 
OAK_LFG:EnableMouse(true)
OAK_LFG:RegisterForDrag("LeftButton")
OAK_LFG:SetScript("OnDragStart", function(self)
    OakLFGSorterDB = OakLFGSorterDB or {}
    OakLFGSorterDB.frameUserPlaced = true
    self.isOakDragging = true
    self:StartMoving()
end)
OAK_LFG:SetFrameStrata("DIALOG")
-- Avoid Blizzard's live drag clamp, which makes the frame feel "bouncy"
-- near screen edges. We clamp only after drag/resize completes.
OAK_LFG:SetClampedToScreen(false)
OAK_LFG:Hide()

_G["OakensoulLFGSorterFrame"] = OAK_LFG
tinsert(UISpecialFrames, "OakensoulLFGSorterFrame")

local combatCloseFrame = CreateFrame("Frame")
combatCloseFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatCloseFrame:SetScript("OnEvent", function(_, event)
    if event ~= "PLAYER_REGEN_DISABLED" then
        return
    end

    if addonTable.OAK_SEARCH and addonTable.OAK_SEARCH:IsShown() then
        addonTable.OAK_SEARCH:Hide()
    end
    if OAK_LFG:IsShown() then
        OAK_LFG:Hide()
    end
end)

OAK_LFG:SetBackdrop({
    bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX,
    tile = false, edgeSize = 1, 
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
})
if addonTable.ApplyBackdropStyle then
    addonTable.ApplyBackdropStyle(OAK_LFG, "panel")
end
OAK_LFG:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
OAK_LFG:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)

local titleHeader = CreateFrame("Frame", nil, OAK_LFG)
addonTable.TitleHeader = titleHeader
local function ApplyHeaderInsets()
    local pad = addonTable.GetThemeFramePadding and addonTable.GetThemeFramePadding() or 0
    titleHeader:ClearAllPoints()
    titleHeader:SetPoint("TOPLEFT", OAK_LFG, "TOPLEFT", 1 + pad, -1 - pad)
    titleHeader:SetPoint("TOPRIGHT", OAK_LFG, "TOPRIGHT", -1 - pad, -1 - pad)
end
ApplyHeaderInsets()
titleHeader:SetHeight(30)
local thBg = titleHeader:CreateTexture(nil, "BACKGROUND")
thBg:SetAllPoints()
thBg:SetColorTexture(unpack(addonTable.OAK_COLOR_TITLEBAR or addonTable.OAK_COLOR_PANE))

OAK_LFG.title = titleHeader:CreateFontString(nil, "OVERLAY", "OakLFG_FontLarge")
OAK_LFG.title:SetPoint("LEFT", titleHeader, "LEFT", 15, 0)
OAK_LFG.title:SetText("OAK " .. L["LFG Sorter"])
addonTable.FullTitleText = "OAK " .. L["LFG Sorter"]
addonTable.CompactTitleText = "OAK " .. L["LFG"]

-- Scale UI Elements
local scaleSlider = CreateFrame("Slider", "OakLFGScaleSlider", titleHeader, "BackdropTemplate")
scaleSlider:SetSize(80, 10)
scaleSlider:SetPoint("LEFT", OAK_LFG.title, "RIGHT", 45, 0)
scaleSlider:SetMinMaxValues(0.5, 1.5)
scaleSlider:SetValueStep(0.05)
scaleSlider:SetObeyStepOnDrag(true)
scaleSlider:SetOrientation("HORIZONTAL")
scaleSlider:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
if addonTable.ApplyBackdropStyle then
    addonTable.ApplyBackdropStyle(scaleSlider, "inset")
end
scaleSlider:SetBackdropColor(unpack(addonTable.OAK_COLOR_SLIDER_TRACK or {0.05, 0.05, 0.05, 1}))
scaleSlider:SetBackdropBorderColor(0, 0, 0, 1)

local thumb = scaleSlider:CreateTexture(nil, "ARTWORK")
thumb:SetTexture(addonTable.FLAT_TEX)
thumb:SetVertexColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
thumb:SetSize(10, 14)
scaleSlider:SetThumbTexture(thumb)

local scaleLabel = scaleSlider:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
scaleLabel:SetPoint("RIGHT", scaleSlider, "LEFT", -8, 0)
scaleLabel:SetText(L["Scale"])

local scaleEdit = CreateFrame("EditBox", nil, titleHeader, "BackdropTemplate")
scaleEdit:SetSize(35, 18)
scaleEdit:SetPoint("LEFT", scaleSlider, "RIGHT", 10, 0)
scaleEdit:SetAutoFocus(false)
scaleEdit:SetFontObject("OakLFG_FontRegular")
scaleEdit:SetJustifyH("CENTER")
scaleEdit:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
if addonTable.ApplyBackdropStyle then
    addonTable.ApplyBackdropStyle(scaleEdit, "inset")
end
scaleEdit:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
scaleEdit:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))

local scaleReset = addonTable.CreateFlatButton(titleHeader, L["Reset"], 45)
scaleReset:SetPoint("LEFT", scaleEdit, "RIGHT", 5, 0)
scaleReset:SetAutoWidth(45, 120, 20)
scaleReset:SetScript("OnEnter", function(self) 
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L["Reset Position & Scale"], 1, 1, 1)
    GameTooltip:Show()
end)
scaleReset:SetScript("OnLeave", function(self) 
    self:SetBackdropBorderColor(0, 0, 0, 1)
    GameTooltip:Hide()
end)

local function CaptureFrameAnchor()
    local point, relativeTo, relativePoint, xOfs, yOfs = OAK_LFG:GetPoint(1)
    if not point then
        return "CENTER", UIParent, "CENTER", 0, 0
    end
    return point, relativeTo or UIParent, relativePoint or point, xOfs or 0, yOfs or 0
end

local function ApplyScalePreservingTopLeft(scale, fixedPoint, fixedRelativeTo, fixedRelativePoint, fixedX, fixedY)
    scale = tonumber(scale) or 1
    local point, relativeTo, relativePoint, xOfs, yOfs = fixedPoint, fixedRelativeTo, fixedRelativePoint, fixedX, fixedY
    if not point then
        point, relativeTo, relativePoint, xOfs, yOfs = CaptureFrameAnchor()
    end
    OAK_LFG:SetScale(scale)
    if point then
        OAK_LFG:ClearAllPoints()
        OAK_LFG:SetPoint(point, relativeTo or UIParent, relativePoint or point, xOfs or 0, yOfs or 0)
        if OakLFGSorterDB then
            OakLFGSorterDB.framePos = { point, relativePoint or point, xOfs or 0, yOfs or 0 }
        end
    end
end
addonTable.ApplyScalePreservingTopLeft = ApplyScalePreservingTopLeft

scaleSlider:SetScript("OnMouseDown", function(self)
    self.isDragging = true
    self.anchorPoint, self.anchorRelativeTo, self.anchorRelativePoint, self.anchorX, self.anchorY = CaptureFrameAnchor()
end)

scaleSlider:SetScript("OnMouseUp", function(self) 
    self.isDragging = false
    local rounded = math.floor(self:GetValue() * 100 + 0.5) / 100
    ApplyScalePreservingTopLeft(rounded, self.anchorPoint, self.anchorRelativeTo, self.anchorRelativePoint, self.anchorX, self.anchorY)
    if OakLFGSorterDB then OakLFGSorterDB.scale = rounded end
    self.anchorPoint = nil
    self.anchorRelativeTo = nil
    self.anchorRelativePoint = nil
    self.anchorX = nil
    self.anchorY = nil
end)

scaleSlider:SetScript("OnValueChanged", function(self, value)
    local rounded = math.floor(value * 100 + 0.5) / 100
    scaleEdit:SetText(string.format("%.2f", rounded))
end)

scaleEdit:SetScript("OnEnterPressed", function(self)
    local val = tonumber(self:GetText())
    if val then
        val = math.max(0.5, math.min(1.5, val))
        scaleSlider:SetValue(val)
        ApplyScalePreservingTopLeft(val)
        if OakLFGSorterDB then OakLFGSorterDB.scale = val end
    end
    self:ClearFocus()
end)

function addonTable.AutoPosition()
    if not addonTable.OAK_LFG then return end
    if OakLFGSorterDB and OakLFGSorterDB.framePos then
        addonTable.OAK_LFG:ClearAllPoints()
        local p = OakLFGSorterDB.framePos
        if #p == 4 then
            addonTable.OAK_LFG:SetPoint(p[1], UIParent, p[2], p[3], p[4])
        end
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

    local rioAnchor = _G["RaiderIO_ProfileTooltipAnchor"]
    if rioAnchor then
        if rioAnchor:GetParent() ~= UIParent then
            rioAnchor:SetParent(UIParent)
        end
        rioAnchor:SetFrameStrata("TOOLTIP")
        rioAnchor:SetToplevel(true)
    end

    local anchorTarget = ownerFrame
    if ownerFrame == addonTable.OAK_LFG then
        if addonTable.MythicPlusPanel and addonTable.MythicPlusPanel:IsShown() then
            anchorTarget = addonTable.MythicPlusPanel
        elseif addonTable.BrowserFilterPanel and addonTable.BrowserFilterPanel:IsShown() then
            anchorTarget = addonTable.BrowserFilterPanel
        elseif addonTable.FilterPanel and addonTable.FilterPanel:IsShown() then
            anchorTarget = addonTable.FilterPanel
        elseif addonTable.OptionsPanel and addonTable.OptionsPanel:IsShown() then
            anchorTarget = addonTable.OptionsPanel
        elseif addonTable.SupportersPanel and addonTable.SupportersPanel:IsShown() then
            anchorTarget = addonTable.SupportersPanel
        end
    elseif ownerFrame == addonTable.OAK_SEARCH then
        if addonTable.SearchFilterPanel and addonTable.SearchFilterPanel:IsShown() then
            anchorTarget = addonTable.SearchFilterPanel
        elseif addonTable.SearchOptionsPanel and addonTable.SearchOptionsPanel:IsShown() then
            anchorTarget = addonTable.SearchOptionsPanel
        elseif addonTable.SearchSupportersPanel and addonTable.SearchSupportersPanel:IsShown() then
            anchorTarget = addonTable.SearchSupportersPanel
        end
    end

    local targetFrameLevel = math.max(anchorTarget:GetFrameLevel() or 0, ownerFrame:GetFrameLevel() or 0) + 80
    if rioAnchor then
        rioAnchor:SetFrameLevel(targetFrameLevel)
        rioAnchor:ClearAllPoints()
        rioAnchor:SetPoint("TOPLEFT", anchorTarget, "TOPRIGHT", 2, 0)
        rioAnchor:Show()
        rioAnchor:Raise()
    end
    RaiderIO_ProfileTooltip:SetParent(UIParent)
    RaiderIO_ProfileTooltip:SetFrameStrata("TOOLTIP")
    RaiderIO_ProfileTooltip:SetToplevel(true)
    RaiderIO_ProfileTooltip:SetFrameLevel(targetFrameLevel)
    RaiderIO_ProfileTooltip:ClearAllPoints()
    if rioAnchor then
        RaiderIO_ProfileTooltip:SetPoint("TOPLEFT", rioAnchor, "TOPRIGHT", 0, 0)
    else
        RaiderIO_ProfileTooltip:SetPoint("TOPLEFT", anchorTarget, "TOPRIGHT", 2, 0)
    end
    RaiderIO_ProfileTooltip:Raise()
end

function addonTable.ClampFrameToScreen(frame, dbTable, positionKey)
    if not (frame and frame.GetLeft and frame.GetBottom and frame.GetRight and frame.GetTop and UIParent) then
        return
    end

    local left = frame:GetLeft()
    local right = frame:GetRight()
    local bottom = frame:GetBottom()
    local top = frame:GetTop()
    local parentWidth = UIParent:GetWidth() or 0
    local parentHeight = UIParent:GetHeight() or 0

    if not (left and right and bottom and top and parentWidth > 0 and parentHeight > 0) then
        return
    end

    local offsetX = 0
    local offsetY = 0

    if left < 0 then
        offsetX = -left
    elseif right > parentWidth then
        offsetX = parentWidth - right
    end

    if bottom < 0 then
        offsetY = -bottom
    elseif top > parentHeight then
        offsetY = parentHeight - top
    end

    if offsetX == 0 and offsetY == 0 then
        return
    end

    local newLeft = left + offsetX
    local newBottom = bottom + offsetY
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", newLeft, newBottom)

    if dbTable and positionKey then
        dbTable[positionKey] = { "BOTTOMLEFT", "BOTTOMLEFT", newLeft, newBottom }
    end
end

function addonTable.RefreshRIOAnchor()
    if addonTable.OAK_LFG and addonTable.OAK_LFG:IsShown() and RaiderIO_ProfileTooltip and RaiderIO_ProfileTooltip._oakPinned and not RaiderIO_ProfileTooltip:IsShown() then
        local pinnedName = RaiderIO_ProfileTooltip._oakPinnedName
        local pinnedRealm = RaiderIO_ProfileTooltip._oakPinnedRealm
        local pinnedPreset = RaiderIO_ProfileTooltip._oakPinnedPreset or 16056
        if RaiderIO and RaiderIO.ShowProfile and pinnedName and pinnedName ~= "" then
            local ok, shown = pcall(RaiderIO.ShowProfile, RaiderIO_ProfileTooltip, pinnedName, pinnedRealm, pinnedPreset)
            if ok and shown then
                -- continue into normal anchor logic below
            end
        end
    end
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
            RaiderIO_ProfileTooltip:SetFrameStrata("TOOLTIP")
            RaiderIO_ProfileTooltip:SetToplevel(true)
            RaiderIO_ProfileTooltip:SetFrameLevel((fallback:GetFrameLevel() or 0) + 80)
            RaiderIO_ProfileTooltip:ClearAllPoints()
            RaiderIO_ProfileTooltip:SetPoint("TOPLEFT", fallback, "TOPRIGHT", 2, 0)
            RaiderIO_ProfileTooltip:Raise()
        end
    end
end

function addonTable.TryShowRaiderIOProfileTooltip(tooltip, name, realm)
    if not (tooltip and RaiderIO and RaiderIO.ShowProfile and IsShiftKeyDown and IsShiftKeyDown()) then
        return false
    end

    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.LoadAddOn and not C_AddOns.IsAddOnLoaded("Blizzard_GroupFinder") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_GroupFinder")
        if addonTable.CheckRIOHook then
            addonTable.CheckRIOHook()
        end
    end

    local fullName = tostring(name or "")
    local charName = fullName
    local charRealm = realm

    if fullName ~= "" and (not charRealm or charRealm == "") then
        local splitName, splitRealm = strsplit("-", fullName, 2)
        if splitName and splitName ~= "" then
            charName = splitName
            charRealm = splitRealm
        end
    end

    if not charName or charName == "" then
        return false
    end

    local RIO_PROFILE_PRESET = 16056
    local ok, shown = pcall(RaiderIO.ShowProfile, tooltip, charName, charRealm, RIO_PROFILE_PRESET)
    if ok and shown then
        if RaiderIO_ProfileTooltip then
            RaiderIO_ProfileTooltip._oakPinned = true
            RaiderIO_ProfileTooltip._oakPinnedName = charName
            RaiderIO_ProfileTooltip._oakPinnedRealm = charRealm
            RaiderIO_ProfileTooltip._oakPinnedPreset = RIO_PROFILE_PRESET
        end
        addonTable.RefreshRIOAnchor()
        return true
    end

    return false
end

local rioHooked = false
function addonTable.CheckRIOHook()
    if not rioHooked and RaiderIO_ProfileTooltip then
        rioHooked = true
        RaiderIO_ProfileTooltip:HookScript("OnHide", function()
            if addonTable.OAK_LFG:IsShown() and RaiderIO_ProfileTooltip._oakPinned and C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    if addonTable.OAK_LFG:IsShown() and RaiderIO_ProfileTooltip and not RaiderIO_ProfileTooltip:IsShown() and RaiderIO_ProfileTooltip._oakPinned then
                        local pinnedName = RaiderIO_ProfileTooltip._oakPinnedName
                        local pinnedRealm = RaiderIO_ProfileTooltip._oakPinnedRealm
                        local pinnedPreset = RaiderIO_ProfileTooltip._oakPinnedPreset or 16056
                        local ok, shown = false, false
                        if RaiderIO and RaiderIO.ShowProfile and pinnedName and pinnedName ~= "" then
                            ok, shown = pcall(RaiderIO.ShowProfile, RaiderIO_ProfileTooltip, pinnedName, pinnedRealm, pinnedPreset)
                        end
                        if ok and shown and addonTable.RefreshRIOAnchor then
                            addonTable.RefreshRIOAnchor()
                        end
                    end
                end)
            elseif addonTable.OAK_LFG:IsShown() and addonTable.RefreshRIOAnchor then
                addonTable.RefreshRIOAnchor()
            end
        end)
        RaiderIO_ProfileTooltip:HookScript("OnShow", function()
            addonTable.RefreshRIOAnchor()
        end)
        if PVEFrame and PVEFrame.HookScript then
            PVEFrame:HookScript("OnHide", function()
                if addonTable.OAK_LFG:IsShown() and RaiderIO_ProfileTooltip and RaiderIO_ProfileTooltip._oakPinned and C_Timer and C_Timer.After then
                    C_Timer.After(0, function()
                        if addonTable.OAK_LFG:IsShown() and RaiderIO_ProfileTooltip and RaiderIO_ProfileTooltip._oakPinned then
                            local pinnedName = RaiderIO_ProfileTooltip._oakPinnedName
                            local pinnedRealm = RaiderIO_ProfileTooltip._oakPinnedRealm
                            local pinnedPreset = RaiderIO_ProfileTooltip._oakPinnedPreset or 16056
                            local ok, shown = false, false
                            if RaiderIO and RaiderIO.ShowProfile and pinnedName and pinnedName ~= "" then
                                ok, shown = pcall(RaiderIO.ShowProfile, RaiderIO_ProfileTooltip, pinnedName, pinnedRealm, pinnedPreset)
                            end
                            if ok and shown and addonTable.RefreshRIOAnchor then
                                addonTable.RefreshRIOAnchor()
                            end
                        end
                    end)
                end
            end)
        end
    end
end

OAK_LFG:HookScript("OnShow", function()
    addonTable.RefreshRIOAnchor()
end)

OAK_LFG:HookScript("OnHide", function()
    if RaiderIO_ProfileTooltip then
        RaiderIO_ProfileTooltip._oakPinned = false
        RaiderIO_ProfileTooltip._oakPinnedName = nil
        RaiderIO_ProfileTooltip._oakPinnedRealm = nil
        RaiderIO_ProfileTooltip._oakPinnedPreset = nil
    end
    addonTable.RefreshRIOAnchor()
end)

OAK_LFG:HookScript("OnSizeChanged", function(self)
    if self:IsShown() and not self.isOakDragging and not self.isOakResizing and addonTable.ClampFrameToScreen then
        addonTable.ClampFrameToScreen(self, OakLFGSorterDB, "framePos")
    end
end)

scaleReset:SetScript("OnClick", function()
    ApplyScalePreservingTopLeft(1.0)
    scaleSlider:SetValue(1.0)
    scaleEdit:SetText(string.format("%.2f", 1.0))
    if OakLFGSorterDB then
        OakLFGSorterDB.scale = 1.0
        OakLFGSorterDB.framePos = nil
        OakLFGSorterDB.frameUserPlaced = false
    end
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
closeBtn:SetScript("OnClick", function()
    OAK_LFG:Hide()  -- OnHide hook sets userExplicitlyClosed when not a system hide
end)
closeBtn:SetScript("OnEnter", function() clBg:SetColorTexture(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 0.5) end)
closeBtn:SetScript("OnLeave", function() clBg:SetColorTexture(0, 0, 0, 0) end)
addonTable.CloseButton = closeBtn

local VersionText = titleHeader:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
addonTable.VersionText = VersionText
VersionText:SetPoint("RIGHT", closeBtn, "LEFT", -5, 0)
VersionText:SetText("|cff888888v3.0.6|r")
VersionText:Hide()

addonTable.RegisterThemeRefresh("ui_header_theme", function()
    if addonTable.ApplyBackdropStyle then
        addonTable.ApplyBackdropStyle(OAK_LFG, "panel")
        addonTable.ApplyBackdropStyle(scaleSlider, "inset")
        addonTable.ApplyBackdropStyle(scaleEdit, "inset")
    end
    ApplyHeaderInsets()
    OAK_LFG:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
    OAK_LFG:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    thBg:SetColorTexture(unpack(addonTable.OAK_COLOR_TITLEBAR or addonTable.OAK_COLOR_PANE))
    scaleSlider:SetBackdropColor(unpack(addonTable.OAK_COLOR_SLIDER_TRACK or {0.05, 0.05, 0.05, 1}))
    scaleEdit:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
    OAK_LFG.title:SetTextColor(unpack(addonTable.OAK_COLOR_TITLE_TINT or {1, 1, 1, 1}))
    thumb:SetVertexColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
end)

local resizeGrip = CreateFrame("Button", nil, OAK_LFG, "PanelResizeButtonTemplate")
addonTable.ResizeGrip = resizeGrip
resizeGrip:SetPoint("BOTTOMRIGHT", OAK_LFG, "BOTTOMRIGHT", -2, 2)
resizeGrip:SetScript("OnUpdate", function(self)
    if not self._oakResizePending then
        return
    end

    local cursorX, cursorY = GetCursorPosition()
    local startX = self._oakResizeStartX or cursorX
    local startY = self._oakResizeStartY or cursorY
    if math.abs(cursorX - startX) < 4 and math.abs(cursorY - startY) < 4 then
        return
    end

    self._oakResizePending = false
    self._oakResizeStarted = true
    OAK_LFG.isOakResizing = true
    OAK_LFG:StartSizing("BOTTOMRIGHT")
end)
resizeGrip:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        self._oakResizeStartX, self._oakResizeStartY = GetCursorPosition()
        self._oakResizePending = true
        self._oakResizeStarted = false
    end
end)

StaticPopupDialogs["OAK_LFG_URL_COPY"] = {
    text = L["Press Ctrl+C to copy the link"],
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
    -- If the browser wasn't hidden by a system call (SearchPanel:OnShow),
    -- the user closed it intentionally (X button or Escape) ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â suppress auto-reopen.
    if not addonTable.systemHidingBrowser then
        addonTable.userExplicitlyClosed = true
    end
end)
