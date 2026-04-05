local addonName, addonTable = ...
local L = addonTable.L

local OAK_SEARCH = addonTable and addonTable.OAK_SEARCH
if not OAK_SEARCH then
    return
end

OakLFGSorterDB = OakLFGSorterDB or {}
if OakLFGSorterDB.searchQuickSignup == nil then OakLFGSorterDB.searchQuickSignup = false end
if OakLFGSorterDB.searchPersistSignupNote == nil then OakLFGSorterDB.searchPersistSignupNote = false end

local FLAT_TEX = "Interface\\Buttons\\WHITE8X8"
local OAK_COLOR_BG = {0.106, 0.106, 0.129, 0.85}
local OAK_COLOR_PANE = {0.137, 0.141, 0.172, 1}
local OAK_COLOR_BORDER = {0, 0, 0, 1}

local _, playerClass = UnitClass("player")
local classColor = RAID_CLASS_COLORS[playerClass] or { r = 1, g = 1, b = 1 }

local quickSignupState = {
    pending = false,
    roleButtons = {},
    roleOrder = { "TANK", "HEALER", "DAMAGER" },
    persistPatchActive = false,
    originalDialogShow = nil,
}

local SEARCH_ROLE_CAPABILITIES = {
    DEATHKNIGHT = { TANK = true, DAMAGER = true },
    DEMONHUNTER = { TANK = true, DAMAGER = true },
    DRUID = { TANK = true, HEALER = true, DAMAGER = true },
    EVOKER = { HEALER = true, DAMAGER = true },
    HUNTER = { DAMAGER = true },
    MAGE = { DAMAGER = true },
    MONK = { TANK = true, HEALER = true, DAMAGER = true },
    PALADIN = { TANK = true, HEALER = true, DAMAGER = true },
    PRIEST = { HEALER = true, DAMAGER = true },
    ROGUE = { DAMAGER = true },
    SHAMAN = { HEALER = true, DAMAGER = true },
    WARLOCK = { DAMAGER = true },
    WARRIOR = { TANK = true, DAMAGER = true },
}

local ROLE_TEX_COORDS = {
    TANK = { 0, 19/64, 22/64, 41/64 },
    HEALER = { 20/64, 39/64, 1/64, 20/64 },
    DAMAGER = { 20/64, 39/64, 22/64, 41/64 },
}

local function GetPlayerQuickSignupCapabilities()
    local _, classToken = UnitClass("player")
    return SEARCH_ROLE_CAPABILITIES[classToken or ""] or { DAMAGER = true }
end

local function GetPreferredPlayerRole()
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player") or nil
    if role and role ~= "NONE" and role ~= "" then
        return role
    end

    if GetSpecialization and GetSpecializationInfo and GetSpecializationRoleByID then
        local specIndex = GetSpecialization()
        if specIndex then
            local specID = GetSpecializationInfo(specIndex)
            local specRole = specID and GetSpecializationRoleByID(specID)
            if specRole and specRole ~= "NONE" then
                return specRole
            end
        end
    end

    return "DAMAGER"
end

local function GetDefaultQuickSignupRoles()
    local availableRoles = GetPlayerQuickSignupCapabilities()
    local roles = {
        TANK = false,
        HEALER = false,
        DAMAGER = false,
    }

    local preferredRole = GetPreferredPlayerRole()
    if availableRoles[preferredRole] then
        roles[preferredRole] = true
    elseif availableRoles.DAMAGER then
        roles.DAMAGER = true
    elseif availableRoles.TANK then
        roles.TANK = true
    elseif availableRoles.HEALER then
        roles.HEALER = true
    end

    return roles
end

local function GetSavedQuickSignupRoles()
    if type(OakLFGSorterDB.searchQuickSignupRoles) ~= "table" then
        OakLFGSorterDB.searchQuickSignupRoles = GetDefaultQuickSignupRoles()
    end

    local availableRoles = GetPlayerQuickSignupCapabilities()
    local roles = OakLFGSorterDB.searchQuickSignupRoles
    local hasAnyAvailableRole = false

    for _, roleKey in ipairs(quickSignupState.roleOrder) do
        if not availableRoles[roleKey] then
            roles[roleKey] = false
        elseif roles[roleKey] then
            hasAnyAvailableRole = true
        end
    end

    if not hasAnyAvailableRole then
        local defaults = GetDefaultQuickSignupRoles()
        for roleKey, isEnabled in pairs(defaults) do
            roles[roleKey] = isEnabled
        end
    end

    return roles
end

local function GetSignupDialogRoleButton(dialog, roleKey)
    local fieldNameByRole = {
        TANK = "TankButton",
        HEALER = "HealerButton",
        DAMAGER = "DamagerButton",
    }

    local fieldName = fieldNameByRole[roleKey]
    if not fieldName then
        return nil
    end

    return (dialog and dialog[fieldName]) or _G["LFGListApplicationDialog" .. fieldName]
end

local function SetSignupDialogRoleState(button, shouldEnable)
    if not button then
        return
    end

    local toggleButton = button.CheckButton or button.checkButton or button
    local isChecked = false
    if toggleButton.GetChecked then
        local ok, value = pcall(toggleButton.GetChecked, toggleButton)
        isChecked = ok and value and true or false
    end

    if isChecked ~= shouldEnable and toggleButton.Click then
        pcall(toggleButton.Click, toggleButton)
    elseif toggleButton.SetChecked then
        pcall(toggleButton.SetChecked, toggleButton, shouldEnable)
    end
end

local function RaiseFrameAboveOak(frame)
    if not frame then
        return
    end

    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)

    local targetLevel = math.max(1, OAK_SEARCH:GetFrameLevel() + 20)
    if addonTable and addonTable.OAK_LFG and addonTable.OAK_LFG.GetFrameLevel then
        targetLevel = math.max(targetLevel, addonTable.OAK_LFG:GetFrameLevel() + 20)
    end

    frame:SetFrameLevel(targetLevel)
    frame:Raise()
end

local function RaiseSignupDialogAboveOak(dialog)
    RaiseFrameAboveOak(dialog)
end

local function RaiseApplicationViewerAboveOak()
    if LFGListFrame and LFGListFrame.ApplicationViewer then
        RaiseFrameAboveOak(LFGListFrame.ApplicationViewer)
    end
end

local function RaiseInviteDialogAboveOak()
    if LFGListInviteDialog then
        RaiseFrameAboveOak(LFGListInviteDialog)
    end
end

local function ApplySavedQuickSignupRoles(dialog)
    if not dialog then
        return
    end

    local roleSettings = GetSavedQuickSignupRoles()
    local availableRoles = GetPlayerQuickSignupCapabilities()

    for _, roleKey in ipairs(quickSignupState.roleOrder) do
        local roleButton = GetSignupDialogRoleButton(dialog, roleKey)
        local shouldEnable = availableRoles[roleKey] == true and roleSettings[roleKey] == true
        SetSignupDialogRoleState(roleButton, shouldEnable)
    end

    if LFGListApplicationDialog_UpdateRoles then
        pcall(LFGListApplicationDialog_UpdateRoles, dialog)
    end
end

local function QueueApplySavedQuickSignupRoles(dialog, onApplied)
    if not dialog then
        return
    end

    local expectedResultID = dialog.resultID
    local function applyRoles(shouldRunCallback)
        if not dialog:IsShown() or dialog.resultID ~= expectedResultID then
            return
        end

        ApplySavedQuickSignupRoles(dialog)
        if shouldRunCallback and onApplied then
            onApplied(dialog, expectedResultID)
        end
    end

    applyRoles(true)
end

local function ApplySavedRolesToVisibleDialog()
    if not (LFGListApplicationDialog and LFGListApplicationDialog:IsShown()) then
        return
    end

    QueueApplySavedQuickSignupRoles(LFGListApplicationDialog)
end

local function RestoreOriginalSignupDialogShow()
    if quickSignupState.persistPatchActive and quickSignupState.originalDialogShow then
        LFGListApplicationDialog_Show = quickSignupState.originalDialogShow
        quickSignupState.persistPatchActive = false
    end
end

local function UpdatePersistentNotePatch()
    if type(LFGListApplicationDialog_Show) ~= "function" then
        return
    end

    if not quickSignupState.originalDialogShow then
        quickSignupState.originalDialogShow = LFGListApplicationDialog_Show
    end

    if OakLFGSorterDB.searchPersistSignupNote then
        if quickSignupState.persistPatchActive then
            return
        end

        LFGListApplicationDialog_Show = function(self, resultID)
            if resultID then
                local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)
                self.resultID = resultID
                self.activityID = searchResultInfo and searchResultInfo.activityID or 0
            end

            LFGListApplicationDialog_UpdateRoles(self)
            StaticPopupSpecial_Show(self)
        end

        quickSignupState.persistPatchActive = true
        return
    end

    RestoreOriginalSignupDialogShow()
end

local function CreateQuickSignupToggle(parent)
    local box = CreateFrame("Button", nil, parent, "BackdropTemplate")
    box:SetSize(14, 14)
    box:SetBackdrop({ bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1 })

    function box:SetState(isActive)
        if isActive then
            self:SetBackdropColor(classColor.r, classColor.g, classColor.b, 1)
            self:SetBackdropBorderColor(0, 0, 0, 1)
        else
            self:SetBackdropColor(0.08, 0.08, 0.10, 0.95)
            self:SetBackdropBorderColor(classColor.r * 0.65, classColor.g * 0.65, classColor.b * 0.65, 1)
        end
    end

    return box
end

local function CreateQuickSignupRoleButton(parent, roleKey, tooltipText)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn.roleKey = roleKey
    btn:SetSize(18, 18)
    btn:SetBackdrop({ bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1 })
    btn:SetBackdropBorderColor(unpack(OAK_COLOR_BORDER))

    btn.icon = btn:CreateTexture(nil, "OVERLAY")
    btn.icon:SetSize(14, 14)
    btn.icon:SetPoint("CENTER")
    btn.icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
    if ROLE_TEX_COORDS[roleKey] then
        btn.icon:SetTexCoord(unpack(ROLE_TEX_COORDS[roleKey]))
    end

    function btn:SetState(isActive)
        if isActive then
            self:SetBackdropColor(classColor.r, classColor.g, classColor.b, 1)
            self.icon:SetVertexColor(1, 1, 1, 1)
            self.icon:SetAlpha(1)
        else
            self:SetBackdropColor(unpack(OAK_COLOR_PANE))
            self.icon:SetVertexColor(1, 1, 1, 1)
            self.icon:SetAlpha(0.95)
        end
    end

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(tooltipText, 1, 1, 1)
        GameTooltip:AddLine("These buttons control the roles Oak uses for Quick Sign Up and the roles Oak preselects in the normal Blizzard popup.", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return btn
end

local quickSignupBar = CreateFrame("Frame", nil, OAK_SEARCH, "BackdropTemplate")
quickSignupBar:SetPoint("TOPLEFT", OAK_SEARCH, "TOPLEFT", 1, -31)
quickSignupBar:SetPoint("TOPRIGHT", OAK_SEARCH, "TOPRIGHT", -1, -31)
quickSignupBar:SetHeight(24)
quickSignupBar:SetBackdrop({ bgFile = FLAT_TEX })
quickSignupBar:SetBackdropColor(0.08, 0.08, 0.1, 0.75)

local quickSignupToggleBox = CreateQuickSignupToggle(quickSignupBar)
quickSignupToggleBox:SetPoint("LEFT", quickSignupBar, "LEFT", 10, 0)

local quickSignupToggleLabel = quickSignupBar:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
quickSignupToggleLabel:SetPoint("LEFT", quickSignupToggleBox, "RIGHT", 6, 0)
quickSignupToggleLabel:SetText(L["Quick Sign Up"])
quickSignupToggleLabel:SetTextColor(1, 1, 1)

local quickSignupRolesLabel = quickSignupBar:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
quickSignupRolesLabel:SetPoint("LEFT", quickSignupToggleLabel, "RIGHT", 10, 0)
quickSignupRolesLabel:SetText(L["Roles"])
quickSignupRolesLabel:SetTextColor(0.85, 0.85, 0.85)

quickSignupState.roleButtons.TANK = CreateQuickSignupRoleButton(quickSignupBar, "TANK", "Use Tank for Quick Sign Up and preselect Tank in the Blizzard popup")
quickSignupState.roleButtons.HEALER = CreateQuickSignupRoleButton(quickSignupBar, "HEALER", "Use Healer for Quick Sign Up and preselect Healer in the Blizzard popup")
quickSignupState.roleButtons.DAMAGER = CreateQuickSignupRoleButton(quickSignupBar, "DAMAGER", "Use Damage for Quick Sign Up and preselect Damage in the Blizzard popup")

local persistNoteToggleLabel = quickSignupBar:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
persistNoteToggleLabel:SetPoint("RIGHT", quickSignupBar, "RIGHT", -12, 0)
persistNoteToggleLabel:SetText(L["Persist Note"])
persistNoteToggleLabel:SetTextColor(0.85, 0.85, 0.85)

local persistNoteToggleBox = CreateQuickSignupToggle(quickSignupBar)
persistNoteToggleBox:SetPoint("RIGHT", persistNoteToggleLabel, "LEFT", -6, 0)

local persistNoteTooltipRegion = CreateFrame("Frame", nil, quickSignupBar)
persistNoteTooltipRegion:SetPoint("TOPLEFT", persistNoteToggleBox, "TOPRIGHT", 0, 2)
persistNoteTooltipRegion:SetPoint("BOTTOMRIGHT", persistNoteToggleLabel, "BOTTOMRIGHT", 2, -2)
persistNoteTooltipRegion:EnableMouse(true)

local function ShowPersistNoteTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L["Persist Note"], 1, 1, 1)
    GameTooltip:AddLine("Oak can preserve Blizzard's last sign-up note between applications.", 1, 1, 1, true)
    GameTooltip:AddLine("To set or change that note, open the normal Blizzard sign-up popup, type your note there, and sign up once.", 0.9, 0.9, 0.9, true)
    GameTooltip:AddLine("Tip: disable Quick Sign Up or hold Shift while clicking Apply to open the popup.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end

persistNoteToggleBox:SetScript("OnEnter", ShowPersistNoteTooltip)
persistNoteTooltipRegion:SetScript("OnEnter", ShowPersistNoteTooltip)
persistNoteToggleBox:SetScript("OnLeave", function() GameTooltip:Hide() end)
persistNoteTooltipRegion:SetScript("OnLeave", function() GameTooltip:Hide() end)

function addonTable.UpdateSearchQuickSignupControls()
    local roleSettings = GetSavedQuickSignupRoles()
    local availableRoles = GetPlayerQuickSignupCapabilities()

    quickSignupToggleBox:SetState(OakLFGSorterDB.searchQuickSignup == true)
    persistNoteToggleBox:SetState(OakLFGSorterDB.searchPersistSignupNote == true)

    for index, roleKey in ipairs(quickSignupState.roleOrder) do
        local button = quickSignupState.roleButtons[roleKey]
        local isAvailable = availableRoles[roleKey] == true
        button:ClearAllPoints()
        if index == 1 then
            button:SetPoint("LEFT", quickSignupRolesLabel, "RIGHT", 6, 0)
        else
            button:SetPoint("LEFT", quickSignupState.roleButtons[quickSignupState.roleOrder[index - 1]], "RIGHT", 6, 0)
        end

        button:Show()
        button:SetState(isAvailable and roleSettings[roleKey] == true)
        button.icon:SetDesaturated(not isAvailable)
        button.icon:SetAlpha(isAvailable and 1 or 0.28)
        if isAvailable then
            button:Enable()
        else
            button:Disable()
            button:SetBackdropColor(0.08, 0.08, 0.1, 0.9)
        end
    end

    UpdatePersistentNotePatch()
end

quickSignupToggleBox:SetScript("OnClick", function(self)
    OakLFGSorterDB.searchQuickSignup = not OakLFGSorterDB.searchQuickSignup
    self:SetState(OakLFGSorterDB.searchQuickSignup)
    addonTable.UpdateSearchQuickSignupControls()
end)
quickSignupToggleBox:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L["Quick Sign Up"], 1, 1, 1)
    GameTooltip:AddLine("When enabled, clicking Apply will immediately sign up using the roles shown in this bar.", 1, 1, 1, true)
    GameTooltip:AddLine("Hold Shift while clicking Apply to open the normal Blizzard popup instead.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
quickSignupToggleBox:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

persistNoteToggleBox:SetScript("OnClick", function(self)
    OakLFGSorterDB.searchPersistSignupNote = not OakLFGSorterDB.searchPersistSignupNote
    self:SetState(OakLFGSorterDB.searchPersistSignupNote)
    UpdatePersistentNotePatch()
end)

for _, roleKey in ipairs(quickSignupState.roleOrder) do
    local button = quickSignupState.roleButtons[roleKey]
    button:SetScript("OnClick", function(self)
        local availableRoles = GetPlayerQuickSignupCapabilities()
        if not availableRoles[self.roleKey] then
            return
        end

        local roleSettings = GetSavedQuickSignupRoles()
        local enabledCount = 0
        for checkRole, isAvailable in pairs(availableRoles) do
            if isAvailable and roleSettings[checkRole] then
                enabledCount = enabledCount + 1
            end
        end

        if roleSettings[self.roleKey] and enabledCount <= 1 then
            return
        end

        roleSettings[self.roleKey] = not roleSettings[self.roleKey]
        addonTable.UpdateSearchQuickSignupControls()
        ApplySavedRolesToVisibleDialog()
    end)
end

function addonTable.EnsureSearchSignupHooks()
    UpdatePersistentNotePatch()

    if not LFGListApplicationDialog or LFGListApplicationDialog.OakQuickSignupHooked then
        if LFGListFrame and LFGListFrame.ApplicationViewer and not LFGListFrame.ApplicationViewer.OakRaiseAboveHooked then
            LFGListFrame.ApplicationViewer:HookScript("OnShow", function()
                RaiseApplicationViewerAboveOak()
            end)
            LFGListFrame.ApplicationViewer.OakRaiseAboveHooked = true
        end
        if LFGListInviteDialog and not LFGListInviteDialog.OakRaiseAboveHooked then
            LFGListInviteDialog:HookScript("OnShow", function()
                RaiseInviteDialogAboveOak()
            end)
            LFGListInviteDialog.OakRaiseAboveHooked = true
        end
        return
    end

    LFGListApplicationDialog:HookScript("OnShow", function(self)
        RaiseSignupDialogAboveOak(self)
        local shouldQuickSignup = quickSignupState.pending
        QueueApplySavedQuickSignupRoles(self, function(dialog, expectedResultID)
            if shouldQuickSignup and dialog.SignUpButton and dialog.SignUpButton:IsEnabled() and dialog.resultID == expectedResultID then
                dialog.SignUpButton:Click()
            end
        end)
        quickSignupState.pending = false
    end)

    LFGListApplicationDialog.OakQuickSignupHooked = true

    if LFGListFrame and LFGListFrame.ApplicationViewer and not LFGListFrame.ApplicationViewer.OakRaiseAboveHooked then
        LFGListFrame.ApplicationViewer:HookScript("OnShow", function()
            RaiseApplicationViewerAboveOak()
        end)
        LFGListFrame.ApplicationViewer.OakRaiseAboveHooked = true
    end
    if LFGListInviteDialog and not LFGListInviteDialog.OakRaiseAboveHooked then
        LFGListInviteDialog:HookScript("OnShow", function()
            RaiseInviteDialogAboveOak()
        end)
        LFGListInviteDialog.OakRaiseAboveHooked = true
    end
end

function addonTable.BeginSearchSignup(searchResultID)
    if not (searchResultID and LFGListFrame and LFGListFrame.SearchPanel) then
        return
    end

    addonTable.EnsureSearchSignupHooks()
    quickSignupState.pending = OakLFGSorterDB.searchQuickSignup and not IsShiftKeyDown() or false

    LFGListSearchPanel_SelectResult(LFGListFrame.SearchPanel, searchResultID)
    LFGListSearchPanel_SignUp(LFGListFrame.SearchPanel)
end

addonTable.UpdateSearchQuickSignupControls()
