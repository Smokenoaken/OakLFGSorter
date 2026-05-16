local addonName, addonTable = ...
local L = addonTable.L

-- Unified browser: the quick signup bar now lives inside OAK_LFG
local OAK_LFG = addonTable and addonTable.OAK_LFG
if not OAK_LFG then
    return
end

OakLFGSorterDB = OakLFGSorterDB or {}
if OakLFGSorterDB.searchQuickSignup == nil then OakLFGSorterDB.searchQuickSignup = false end
if OakLFGSorterDB.searchPersistSignupNote == nil then OakLFGSorterDB.searchPersistSignupNote = false end

local function GetSearchSignupCharacterDB()
    local db = addonTable.GetCharacterDB and addonTable.GetCharacterDB() or OakLFGSorterCharDB or {}
    db.searchSignup = db.searchSignup or {}
    return db.searchSignup
end

local function IsQuickSignupEnabled()
    local charDB = GetSearchSignupCharacterDB()
    if charDB.quickSignupEnabled == nil then
        charDB.quickSignupEnabled = OakLFGSorterDB.searchQuickSignup == true
    end
    return charDB.quickSignupEnabled == true
end

local function SetQuickSignupEnabled(isEnabled)
    local enabled = isEnabled == true
    local charDB = GetSearchSignupCharacterDB()
    charDB.quickSignupEnabled = enabled
    OakLFGSorterDB.searchQuickSignup = enabled
end

local function IsPersistSignupNoteEnabled()
    local charDB = GetSearchSignupCharacterDB()
    if charDB.persistSignupNote == nil then
        charDB.persistSignupNote = OakLFGSorterDB.searchPersistSignupNote == true
    end
    return charDB.persistSignupNote == true
end

local function SetPersistSignupNoteEnabled(isEnabled)
    local enabled = isEnabled == true
    local charDB = GetSearchSignupCharacterDB()
    charDB.persistSignupNote = enabled
    OakLFGSorterDB.searchPersistSignupNote = enabled
end

local function NormalizeSignupNoteText(noteText)
    local value = tostring(noteText or "")
    local normalized = value:gsub("\r\n", " "):gsub("[\r\n]+", " "):gsub("%s+", " ")
    normalized = normalized:gsub("^%s+", ""):gsub("%s+$", "")
    return normalized
end

local function GetSavedSignupNoteText()
    return NormalizeSignupNoteText(GetSearchSignupCharacterDB().signupNoteText or "")
end

local function SetSavedSignupNoteText(noteText)
    GetSearchSignupCharacterDB().signupNoteText = NormalizeSignupNoteText(noteText)
end

local function SaveBlockedSignupNoteText(noteText)
    local value = tostring(noteText or "")
    if value == "" then
        return
    end
    GetSearchSignupCharacterDB().blockedSignupNoteText = value
end

local function NotifySignupNoteBlocked()
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff9CD6DEOak|r cleared your signup note for this application because Blizzard disabled the Sign Up button while note text was present.")
    end
end

local function GetAccentColor()
    return addonTable.ClassColor or addonTable.PlayerClassColor or { r = 1, g = 1, b = 1 }
end

local function GetPaneColor()
    return addonTable.OAK_COLOR_PANE or {0.137, 0.141, 0.172, 1}
end

local function GetQuickSignupBarColor()
    return addonTable.OAK_COLOR_QUICKSIGNUP or {0.08, 0.08, 0.10, 0.75}
end

local function GetToggleOffColor()
    return addonTable.OAK_COLOR_TOGGLE_OFF or {0.08, 0.08, 0.10, 0.95}
end

local quickSignupBar

local function GetThemeLayoutPad()
    if addonTable.GetThemeFramePadding then
        return addonTable.GetThemeFramePadding() or 0
    end
    return 0
end

local function ApplyQuickSignupBarInsets()
    if not quickSignupBar then
        return
    end
    local pad = GetThemeLayoutPad()
    quickSignupBar:ClearAllPoints()
    quickSignupBar:SetPoint("BOTTOMLEFT", OAK_LFG, "BOTTOMLEFT", 8 + pad, 33)
    quickSignupBar:SetPoint("BOTTOMRIGHT", OAK_LFG, "BOTTOMRIGHT", -30 - pad, 33)
end

local quickSignupState = {
    pending = false,
    autofillDialog = false,
    roleButtons = {},
    roleOrder = { "TANK", "HEALER", "DAMAGER" },
    persistPatchActive = false,
    queueButtonsHooked = false,
    originalDialogShow = nil,
    suppressNoteFallback = false,
    noteFallbackWarnedForDialog = false,
    applicationTimes = {},
}
local EnsureQueueRoleSelectorHooks
local GetSignupNoteEditBox
local RestoreSavedSignupNote

local function TrySetSignupNoteText(editBox, noteText)
    if not (editBox and type(editBox.SetText) == "function") then
        return false
    end

    quickSignupState.suppressNoteFallback = true
    local ok = pcall(editBox.SetText, editBox, noteText or "")
    quickSignupState.suppressNoteFallback = false
    return ok == true
end

local SIGNUP_COOLDOWN_DURATION = 1.5  -- Blizzard server-side throttle estimate (seconds)
local lastDirectSignupTime = 0
local cooldownTimerRunning = false

local function ConfirmSearchResultApplied(searchResultID, onConfirmed)
    if not searchResultID then
        return
    end

    local function checkApplied()
        if not (C_LFGList and C_LFGList.GetApplicationInfo) then
            return false
        end

        local ok, appA, appB = pcall(C_LFGList.GetApplicationInfo, searchResultID)
        if not ok then
            return false
        end

        local status
        if type(appA) == "table" then
            status = appA.applicationStatus or appA.status or appA.pendingStatus
        elseif type(appB) == "string" then
            status = appB
        elseif type(appA) == "string" then
            status = appA
        end

        if addonTable.NormalizeApplicationStatus then
            status = addonTable.NormalizeApplicationStatus(status or "none")
        else
            status = tostring(status or "none")
        end

        if addonTable.IsAppliedStatus and addonTable.IsAppliedStatus(status) then
            quickSignupState.applicationTimes[searchResultID] = quickSignupState.applicationTimes[searchResultID] or GetTime()
            if onConfirmed then
                onConfirmed()
            end
            return true
        end

        return false
    end

    if checkApplied() then
        return
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.1, function()
            if checkApplied() then
                return
            end
            C_Timer.After(0.35, checkApplied)
        end)
    end
end

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

local CopyQuickSignupRoles

local function GetSavedQuickSignupRoles()
    local charDB = GetSearchSignupCharacterDB()
    if type(charDB.quickSignupRoles) ~= "table" then
        if type(OakLFGSorterDB.searchQuickSignupRoles) == "table" then
            charDB.quickSignupRoles = CopyQuickSignupRoles(OakLFGSorterDB.searchQuickSignupRoles)
        else
            charDB.quickSignupRoles = GetDefaultQuickSignupRoles()
        end
    end

    local availableRoles = GetPlayerQuickSignupCapabilities()
    local roles = charDB.quickSignupRoles
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

function CopyQuickSignupRoles(roleSource)
    local roles = {}
    for _, roleKey in ipairs(quickSignupState.roleOrder) do
        roles[roleKey] = roleSource and roleSource[roleKey] == true or false
    end
    return roles
end

local function GetQueueRoleButton(roleKey, framePrefix)
    local suffixByRole = {
        TANK = "Tank",
        HEALER = "Healer",
        DAMAGER = "DPS",
    }

    local suffix = suffixByRole[roleKey]
    if not suffix or not framePrefix then
        return nil
    end

    return _G[framePrefix .. "RoleButton" .. suffix]
end

local function GetAllQueueRoleButtons()
    local buttons = {}
    for _, framePrefix in ipairs({ "LFDQueueFrame", "RaidFinderQueueFrame" }) do
        for _, roleKey in ipairs(quickSignupState.roleOrder) do
            local button = GetQueueRoleButton(roleKey, framePrefix)
            if button then
                buttons[#buttons + 1] = button
            end
        end
    end
    return buttons
end

local function ReadQueueRolesFromAPI()
    if type(GetLFGRoles) ~= "function" then
        return nil
    end

    local ok, a, b, c, d = pcall(GetLFGRoles)
    if not ok then
        return nil
    end

    if type(d) == "boolean" then
        return {
            TANK = b == true,
            HEALER = c == true,
            DAMAGER = d == true,
        }
    end

    if type(a) == "boolean" or type(b) == "boolean" or type(c) == "boolean" then
        return {
            TANK = a == true,
            HEALER = b == true,
            DAMAGER = c == true,
        }
    end

    return nil
end

local function ReadQueueRolesFromButtons()
    local roles = {
        TANK = false,
        HEALER = false,
        DAMAGER = false,
    }
    local foundAny = false

    for _, framePrefix in ipairs({ "LFDQueueFrame", "RaidFinderQueueFrame" }) do
        for _, roleKey in ipairs(quickSignupState.roleOrder) do
            local button = GetQueueRoleButton(roleKey, framePrefix)
            local toggleButton = button and (button.checkButton or button.CheckButton or button)
            if toggleButton and toggleButton.GetChecked then
                local ok, isChecked = pcall(toggleButton.GetChecked, toggleButton)
                if ok then
                    roles[roleKey] = roles[roleKey] or isChecked == true
                    foundAny = true
                end
            end
        end
    end

    if not foundAny then
        return nil
    end

    return roles
end

local function ReadCurrentQueueRoles()
    return ReadQueueRolesFromAPI() or ReadQueueRolesFromButtons()
end

local function WriteQueueRolesWithAPI(roleSettings)
    if type(SetLFGRoles) ~= "function" then
        return false
    end

    local ok = pcall(SetLFGRoles, roleSettings.TANK == true, roleSettings.HEALER == true, roleSettings.DAMAGER == true)
    return ok == true
end

local function SetQueueRoleButtonState(button, shouldEnable)
    if not button then
        return
    end

    local toggleButton = button.checkButton or button.CheckButton or button
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

local function WriteQueueRolesToButtons(roleSettings)
    local foundAny = false
    for _, framePrefix in ipairs({ "LFDQueueFrame", "RaidFinderQueueFrame" }) do
        for _, roleKey in ipairs(quickSignupState.roleOrder) do
            local button = GetQueueRoleButton(roleKey, framePrefix)
            if button then
                SetQueueRoleButtonState(button, roleSettings[roleKey] == true)
                foundAny = true
            end
        end
    end
    return foundAny
end

local function SyncQueueRoleSelectorsFromOakRoles()
    local roleSettings = CopyQuickSignupRoles(GetSavedQuickSignupRoles())
    local availableRoles = GetPlayerQuickSignupCapabilities()

    for _, roleKey in ipairs(quickSignupState.roleOrder) do
        if not availableRoles[roleKey] then
            roleSettings[roleKey] = false
        end
    end

    local hasEnabledRole = false
    for _, roleKey in ipairs(quickSignupState.roleOrder) do
        if roleSettings[roleKey] then
            hasEnabledRole = true
            break
        end
    end

    if not hasEnabledRole then
        roleSettings = CopyQuickSignupRoles(GetDefaultQuickSignupRoles())
    end

    local wroteViaAPI = WriteQueueRolesWithAPI(roleSettings)
    local wroteViaButtons = WriteQueueRolesToButtons(roleSettings)
    return wroteViaAPI or wroteViaButtons
end

local function SyncOakRolesFromQueueSelectors()
    local queueRoles = ReadCurrentQueueRoles()
    if not queueRoles then
        return false
    end

    local availableRoles = GetPlayerQuickSignupCapabilities()
    local normalized = {
        TANK = availableRoles.TANK == true and queueRoles.TANK == true or false,
        HEALER = availableRoles.HEALER == true and queueRoles.HEALER == true or false,
        DAMAGER = availableRoles.DAMAGER == true and queueRoles.DAMAGER == true or false,
    }

    local hasEnabledRole = false
    for _, roleKey in ipairs(quickSignupState.roleOrder) do
        if normalized[roleKey] then
            hasEnabledRole = true
            break
        end
    end

    if not hasEnabledRole then
        normalized = CopyQuickSignupRoles(GetDefaultQuickSignupRoles())
    end

    local savedRoles = GetSavedQuickSignupRoles()
    local changed = false
    for _, roleKey in ipairs(quickSignupState.roleOrder) do
        local shouldEnable = normalized[roleKey] == true
        if savedRoles[roleKey] ~= shouldEnable then
            savedRoles[roleKey] = shouldEnable
            changed = true
        end
    end

    return changed
end

local function ApplyQuickSignupDirect(searchResultID)
    if not (C_LFGList and C_LFGList.ApplyToGroup and searchResultID) then
        return false
    end

    local roleSettings = GetSavedQuickSignupRoles()
    local availableRoles = GetPlayerQuickSignupCapabilities()

    local tank = availableRoles.TANK == true and roleSettings.TANK == true
    local healer = availableRoles.HEALER == true and roleSettings.HEALER == true
    local damage = availableRoles.DAMAGER == true and roleSettings.DAMAGER == true

    if not tank and not healer and not damage then
        local defaults = GetDefaultQuickSignupRoles()
        tank = availableRoles.TANK == true and defaults.TANK == true
        healer = availableRoles.HEALER == true and defaults.HEALER == true
        damage = availableRoles.DAMAGER == true and defaults.DAMAGER == true
    end

    local ok = pcall(C_LFGList.ApplyToGroup, searchResultID, tank, healer, damage)
    if not ok then
        return false
    end
    quickSignupState.applicationTimes[searchResultID] = quickSignupState.applicationTimes[searchResultID] or GetTime()

    ConfirmSearchResultApplied(searchResultID, function()
        if addonTable.MarkSearchResultApplied then
            addonTable.MarkSearchResultApplied(searchResultID)
        end
    end)

    if addonTable.UpdateDisplay and addonTable.OAK_LFG and addonTable.OAK_LFG:IsShown() then
        addonTable.UpdateDisplay()
    end

    if addonTable.StartSignupCooldown then
        addonTable.StartSignupCooldown()
    end

    return true
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

    local targetLevel = math.max(1, (OAK_LFG:GetFrameLevel() or 0) + 20)
    frame:SetFrameLevel(targetLevel)
    frame:Raise()
end

local function RaiseSignupDialogAboveOak(dialog)
    RaiseFrameAboveOak(dialog)
end

local function RaiseApplicationViewerAboveOak()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if LFGListFrame and LFGListFrame.ApplicationViewer and LFGListFrame.ApplicationViewer:IsShown() then
                RaiseFrameAboveOak(LFGListFrame.ApplicationViewer)
            end
        end)
    elseif LFGListFrame and LFGListFrame.ApplicationViewer then
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
    local function applyRoles()
        if not dialog:IsShown() or dialog.resultID ~= expectedResultID then
            return
        end
        ApplySavedQuickSignupRoles(dialog)
        if onApplied then
            onApplied(dialog, expectedResultID)
        end
    end

    -- Try immediately, then retry after short delays in case the dialog
    -- finishes initializing its SignUpButton a frame or two after OnShow fires.
    applyRoles()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, applyRoles)
        C_Timer.After(0.2,  applyRoles)
        C_Timer.After(0.5,  applyRoles)
    end
end

local function ApplySavedRolesToVisibleDialog()
    if not (LFGListApplicationDialog and LFGListApplicationDialog:IsShown()) then
        return
    end

    if not quickSignupState.autofillDialog then
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

    if IsPersistSignupNoteEnabled() then
        if quickSignupState.persistPatchActive then
            return
        end

        LFGListApplicationDialog_Show = function(self, resultID)
            if resultID then
                local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)
                self.resultID = resultID
                self.activityID = searchResultInfo and ((searchResultInfo.activityIDs and searchResultInfo.activityIDs[1]) or 0) or 0
            end

            if LFGListApplicationDialog_UpdateRoles then
                LFGListApplicationDialog_UpdateRoles(self)
            end
            StaticPopupSpecial_Show(self)
        end

        quickSignupState.persistPatchActive = true
        return
    end

    RestoreOriginalSignupDialogShow()
end

GetSignupNoteEditBox = function()
    local descriptionFrame = _G.LFGListApplicationDialogDescription
    local editBox = descriptionFrame and descriptionFrame.EditBox or nil
    if editBox and type(editBox.GetText) == "function" and type(editBox.SetText) == "function" then
        return editBox
    end
    return nil
end

RestoreSavedSignupNote = function(editBox)
    return
end

local function SaveSignupNoteFromEditBox(editBox)
    editBox = editBox or GetSignupNoteEditBox()
    if not editBox then
        return
    end

    SetSavedSignupNoteText(editBox:GetText())
end

local function EvaluateSignupNoteFallback(editBox, expectedText)
    if quickSignupState.suppressNoteFallback then
        return
    end

    if not IsPersistSignupNoteEnabled() then
        return
    end

    if not (LFGListApplicationDialog and LFGListApplicationDialog:IsShown()) then
        return
    end

    if not (editBox and editBox:IsShown()) then
        return
    end

    local currentText = NormalizeSignupNoteText(editBox:GetText())
    if currentText == "" or currentText ~= tostring(expectedText or "") then
        return
    end

    local signUpButton = LFGListApplicationDialog.SignUpButton
    if signUpButton and signUpButton:IsEnabled() then
        return
    end

    SaveBlockedSignupNoteText(currentText)
    TrySetSignupNoteText(editBox, "")

    if not quickSignupState.noteFallbackWarnedForDialog then
        quickSignupState.noteFallbackWarnedForDialog = true
        NotifySignupNoteBlocked()
    end
end

local function HookSignupNoteFallback()
    local editBox = GetSignupNoteEditBox()
    if not editBox or editBox.OakSignupNoteFallbackHooked then
        return
    end

    editBox:HookScript("OnTextChanged", function(self)
        if quickSignupState.suppressNoteFallback then
            return
        end

        local rawText = tostring(self:GetText() or "")
        local noteText = NormalizeSignupNoteText(rawText)
        SetSavedSignupNoteText(noteText)

        if noteText == "" then
            return
        end

        if C_Timer and C_Timer.After then
            C_Timer.After(0.15, function()
                EvaluateSignupNoteFallback(self, noteText)
            end)
        else
            EvaluateSignupNoteFallback(self, noteText)
        end
    end)

    editBox.OakSignupNoteFallbackHooked = true
end

local function CreateQuickSignupToggle(parent)
    local box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    box:SetSize(14, 14)

    function box:SetState(isActive)
        self:SetChecked(isActive == true)
    end

    return box
end

local function CreateQuickSignupRoleButton(parent, roleKey, tooltipText)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn.roleKey = roleKey
    btn:SetSize(18, 18)
    btn:SetBackdrop({
        bgFile = addonTable.FLAT_TEX or "Interface\\Buttons\\WHITE8X8",
        edgeFile = addonTable.FLAT_TEX or "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    btn:SetBackdropBorderColor(0, 0, 0, 1)

    btn.icon = btn:CreateTexture(nil, "OVERLAY")
    btn.icon:SetSize(14, 14)
    btn.icon:SetPoint("CENTER")
    btn.icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
    if ROLE_TEX_COORDS[roleKey] then
        btn.icon:SetTexCoord(unpack(ROLE_TEX_COORDS[roleKey]))
    end

    function btn:SetState(isActive, isAvailable)
        local classColor = GetAccentColor()
        isActive = isActive == true
        isAvailable = isAvailable ~= false

        if not isAvailable then
            self:SetBackdropColor(0.06, 0.06, 0.07, 0.95)
            self:SetBackdropBorderColor(0.12, 0.12, 0.13, 1)
            self.icon:SetVertexColor(0.35, 0.35, 0.35, 1)
            self.icon:SetDesaturated(true)
            self.icon:SetAlpha(0.38)
        elseif isActive then
            self:SetBackdropColor(classColor.r, classColor.g, classColor.b, 0.95)
            self:SetBackdropBorderColor(0, 0, 0, 1)
            self.icon:SetVertexColor(1, 1, 1, 1)
            self.icon:SetDesaturated(false)
            self.icon:SetAlpha(1)
        else
            self:SetBackdropColor(unpack(GetPaneColor()))
            self:SetBackdropBorderColor(classColor.r * 0.55, classColor.g * 0.55, classColor.b * 0.55, 0.85)
            self.icon:SetVertexColor(1, 1, 1, 1)
            self.icon:SetDesaturated(true)
            self.icon:SetAlpha(0.5)
        end
    end

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(tooltipText, 1, 1, 1)
        GameTooltip:AddLine("These buttons control the roles Oak uses for Quick Sign Up, the roles Oak preselects in the Blizzard popup, and your Dungeon Finder / Raid Finder role selectors.", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return btn
end

addonTable.RegisterThemeRefresh("search_signup_theme", function()
    ApplyQuickSignupBarInsets()
    if addonTable.UpdateSearchQuickSignupControls then
        addonTable.UpdateSearchQuickSignupControls()
    end
end)

-- Bar sits above OAK_LFG's footer row; shown only in browser mode
quickSignupBar = CreateFrame("Frame", nil, OAK_LFG, "BackdropTemplate")
quickSignupBar:SetHeight(24)
quickSignupBar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
quickSignupBar:SetBackdropColor(0.05, 0.05, 0.05, 0.75)
quickSignupBar:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
ApplyQuickSignupBarInsets()
quickSignupBar:SetFrameStrata("DIALOG")
quickSignupBar:SetFrameLevel(OAK_LFG:GetFrameLevel() + 20)
quickSignupBar:Hide()  -- shown by SetCurrentViewMode("browser")
addonTable.quickSignupBar = quickSignupBar
if addonTable.GetCurrentViewMode and addonTable.GetCurrentViewMode() == "browser" then
    quickSignupBar:Show()
end

local quickSignupToggleBox = CreateQuickSignupToggle(quickSignupBar)
quickSignupToggleBox:SetPoint("LEFT", quickSignupBar, "LEFT", 10, 0)

local quickSignupToggleLabel = quickSignupBar:CreateFontString(nil, "OVERLAY", "SorterClassic_FontSmall")
quickSignupToggleLabel:SetPoint("LEFT", quickSignupToggleBox, "RIGHT", 6, 0)
quickSignupToggleLabel:SetText(L["Quick Sign Up"])
quickSignupToggleLabel:SetTextColor(1, 1, 1)

local quickSignupRolesLabel = quickSignupBar:CreateFontString(nil, "OVERLAY", "SorterClassic_FontSmall")
quickSignupRolesLabel:SetPoint("LEFT", quickSignupToggleLabel, "RIGHT", 10, 0)
quickSignupRolesLabel:SetText(L["Roles"])
quickSignupRolesLabel:SetTextColor(0.85, 0.85, 0.85)

quickSignupState.roleButtons.TANK = CreateQuickSignupRoleButton(quickSignupBar, "TANK", "Use Tank for Quick Sign Up and preselect Tank in the Blizzard popup")
quickSignupState.roleButtons.HEALER = CreateQuickSignupRoleButton(quickSignupBar, "HEALER", "Use Healer for Quick Sign Up and preselect Healer in the Blizzard popup")
quickSignupState.roleButtons.DAMAGER = CreateQuickSignupRoleButton(quickSignupBar, "DAMAGER", "Use Damage for Quick Sign Up and preselect Damage in the Blizzard popup")

local signupLimitNote = quickSignupBar:CreateFontString(nil, "OVERLAY", "SorterClassic_FontSmall")
signupLimitNote:SetFontObject("SorterClassic_FontRegular")
signupLimitNote:SetText("Applied to 0/5 Groups")
signupLimitNote:SetTextColor(0.85, 0.85, 0.85)
signupLimitNote:SetJustifyH("LEFT")
signupLimitNote:SetWordWrap(false)
signupLimitNote:SetScale(1.0)

local cooldownLabel = quickSignupBar:CreateFontString(nil, "OVERLAY", "SorterClassic_FontSmall")
cooldownLabel:SetTextColor(1, 0.6, 0.1, 1)
cooldownLabel:SetJustifyH("LEFT")
cooldownLabel:SetWordWrap(false)
cooldownLabel:SetScale(0.9)
cooldownLabel:Hide()

local cancelOldestBtn = CreateFrame("Button", nil, quickSignupBar, "UIPanelButtonTemplate")
cancelOldestBtn:SetSize(72, 15)
local cancelOldestLabel = cancelOldestBtn:CreateFontString(nil, "OVERLAY", "SorterClassic_FontSmall")
cancelOldestLabel:SetPoint("CENTER")
cancelOldestLabel:SetText("Cancel Oldest")
cancelOldestLabel:SetTextColor(1, 0.82, 0)
local persistNoteToggleLabel = quickSignupBar:CreateFontString(nil, "OVERLAY", "SorterClassic_FontSmall")
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
    EnsureQueueRoleSelectorHooks()

    if addonTable.GetCurrentViewMode and addonTable.GetCurrentViewMode() == "browser" then
        quickSignupBar:Show()
    end

    local roleSettings = GetSavedQuickSignupRoles()
    local availableRoles = GetPlayerQuickSignupCapabilities()

    quickSignupToggleBox:SetState(IsQuickSignupEnabled())
    persistNoteToggleBox:SetState(IsPersistSignupNoteEnabled())

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
        button:SetState(roleSettings[roleKey] == true, isAvailable)
        if isAvailable then
            button:Enable()
        else
            button:Disable()
        end
    end

    -- cancelOldestBtn sits just left of the Persist Note toggle
    cancelOldestBtn:ClearAllPoints()
    cancelOldestBtn:SetPoint("RIGHT", persistNoteToggleBox, "LEFT", -20, 0)

    UpdatePersistentNotePatch()

    -- UpdateSignupLimitDisplay handles signupLimitNote + cooldownLabel anchors, text, and cancelOldestBtn visibility
    if addonTable.UpdateSignupLimitDisplay then
        addonTable.UpdateSignupLimitDisplay()
    end
end

local function UpdateSignupCooldownDisplay()
    local elapsed = GetTime() - lastDirectSignupTime
    local remaining = SIGNUP_COOLDOWN_DURATION - elapsed
    if remaining > 0 then
        cooldownLabel:SetText(string.format("Server cooldown: %.1fs", remaining))
        signupLimitNote:Hide()
        cooldownLabel:Show()
        C_Timer.After(0.1, UpdateSignupCooldownDisplay)
    else
        cooldownLabel:Hide()
        cooldownTimerRunning = false
        -- Let UpdateSignupLimitDisplay restore the correct note state (may be max-groups message)
        if addonTable.UpdateSignupLimitDisplay then
            addonTable.UpdateSignupLimitDisplay()
        else
            signupLimitNote:Show()
        end
    end
end

function addonTable.StartSignupCooldown()
    lastDirectSignupTime = GetTime()
    if not cooldownTimerRunning then
        cooldownTimerRunning = true
        C_Timer.After(0, UpdateSignupCooldownDisplay)
    end
    -- Refresh the max-groups indicator so Cancel Oldest appears if we just hit the cap
    C_Timer.After(0.1, function()
        if addonTable.UpdateSignupLimitDisplay then
            addonTable.UpdateSignupLimitDisplay()
        end
    end)
end

local function FindAndCancelOldestApplication()
    if not (C_LFGList and C_LFGList.GetApplications and C_LFGList.GetApplicationInfo) then return end
    local results = C_LFGList.GetApplications()
    if type(results) ~= "table" then return end

    local oldestStartedAt = math.huge
    local oldestDuration = math.huge
    local oldestResultID = nil
    for _, resultID in ipairs(results) do
        local appA, appB, _, appDuration = C_LFGList.GetApplicationInfo(resultID)
        local appStatus = type(appA) == "table" and (appA.applicationStatus or appA.status or appA.pendingStatus) or appB or appA
        appStatus = addonTable.NormalizeApplicationStatus and addonTable.NormalizeApplicationStatus(appStatus or "none") or tostring(appStatus or "none")
        if addonTable.IsAppliedStatus and addonTable.IsAppliedStatus(appStatus) then
            local startedAt = quickSignupState.applicationTimes[resultID]
            local dur = tonumber(appDuration) or 0
            if startedAt and startedAt < oldestStartedAt then
                oldestStartedAt = startedAt
                oldestResultID = resultID
            elseif not startedAt and oldestStartedAt == math.huge and dur < oldestDuration then
                oldestDuration = dur
                oldestResultID = resultID
            end
        end
    end
    if oldestResultID then
        C_LFGList.CancelApplication(oldestResultID)
        quickSignupState.applicationTimes[oldestResultID] = nil
        if addonTable.MarkSearchResultCanceled then
            addonTable.MarkSearchResultCanceled(oldestResultID)
        end
    end
end

cancelOldestBtn:SetScript("OnClick", function()
    FindAndCancelOldestApplication()
    C_Timer.After(0.25, function()
        if addonTable.UpdateSignupLimitDisplay then
            addonTable.UpdateSignupLimitDisplay()
        end
    end)
end)
cancelOldestBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Cancel Oldest Application", 1, 0.5, 0.5)
    GameTooltip:AddLine("Cancels your oldest pending group application to free up a signup slot.", 0.9, 0.9, 0.9, true)
    GameTooltip:Show()
end)
cancelOldestBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

function addonTable.UpdateSignupLimitDisplay()
    if not (C_LFGList and C_LFGList.GetNumApplications) then return end
    local _, numActive = C_LFGList.GetNumApplications()
    local maxApps = MAX_LFG_LIST_APPLICATIONS or 5
    local atMax = numActive and numActive >= maxApps

    -- cancelOldestBtn is always visible; labels anchor against it
    cancelOldestBtn:Show()

    local leftAnchor = quickSignupState.roleButtons.DAMAGER
    signupLimitNote:ClearAllPoints()
    signupLimitNote:SetPoint("LEFT", leftAnchor, "RIGHT", 10, 0)
    signupLimitNote:SetPoint("RIGHT", cancelOldestBtn, "LEFT", -6, 0)

    cooldownLabel:ClearAllPoints()
    cooldownLabel:SetPoint("LEFT", leftAnchor, "RIGHT", 10, 0)
    cooldownLabel:SetPoint("RIGHT", cancelOldestBtn, "LEFT", -6, 0)

    if atMax then
        if not cooldownTimerRunning then   -- don't overwrite cooldown label text when it's active
            signupLimitNote:SetText(string.format("Applied to %d/%d Groups", tonumber(numActive) or maxApps, maxApps))
            signupLimitNote:SetTextColor(1, 0.35, 0.35)
            signupLimitNote:Show()
        end
    else
        signupLimitNote:SetText(string.format("Applied to %d/%d Groups", tonumber(numActive) or 0, maxApps))
        signupLimitNote:SetTextColor(0.85, 0.85, 0.85)
        if not cooldownTimerRunning then
            signupLimitNote:Show()
        end
    end
end

-- Refresh limit display whenever an application status changes (accepted, declined, cancelled)
local signupStatusEventFrame = CreateFrame("Frame")
signupStatusEventFrame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
signupStatusEventFrame:SetScript("OnEvent", function(_, _, searchResultID, status)
    if searchResultID then
        local normalized = addonTable.NormalizeApplicationStatus and addonTable.NormalizeApplicationStatus(status or "none") or tostring(status or "none")
        if addonTable.IsAppliedStatus and addonTable.IsAppliedStatus(normalized) then
            quickSignupState.applicationTimes[searchResultID] = quickSignupState.applicationTimes[searchResultID] or GetTime()
        else
            quickSignupState.applicationTimes[searchResultID] = nil
        end
    end
    C_Timer.After(0.3, function()
        if addonTable.UpdateSignupLimitDisplay then
            addonTable.UpdateSignupLimitDisplay()
        end
        if addonTable.UpdateDisplay and addonTable.OAK_LFG and addonTable.OAK_LFG:IsShown() then
            addonTable.UpdateDisplay()
        end
    end)
end)

local function TryPanelSignup(panel, searchResultID)
    if not (panel and searchResultID) then
        return false
    end

    if panel.selectedResult ~= searchResultID then
        LFGListSearchPanel_SelectResult(panel, searchResultID)
    end

    if panel.SignUpButton and panel.SignUpButton:IsEnabled() then
        LFGListSearchPanel_SignUp(panel)
        if addonTable.MarkSearchResultApplied then
            addonTable.MarkSearchResultApplied(searchResultID)
        end
        return true
    end

    return false
end

local function FallbackShowSignupDialog(searchResultID)
    if type(LFGListApplicationDialog_Show) == "function" and LFGListApplicationDialog then
        local ok = pcall(LFGListApplicationDialog_Show, LFGListApplicationDialog, searchResultID)
        if ok then return true end
    end

    return false
end

local function HandleQueueRoleSelectorChanged()
    local changed = SyncOakRolesFromQueueSelectors()
    if changed then
        addonTable.UpdateSearchQuickSignupControls()
        ApplySavedRolesToVisibleDialog()
    end
end

local function HookQueueRoleSelector(button)
    if not button or button.OakQuickSignupRoleSyncHooked then
        return
    end

    button:HookScript("OnClick", HandleQueueRoleSelectorChanged)
    button.OakQuickSignupRoleSyncHooked = true
end

EnsureQueueRoleSelectorHooks = function()
    for _, button in ipairs(GetAllQueueRoleButtons()) do
        HookQueueRoleSelector(button)
    end

    if LFDQueueFrame and not LFDQueueFrame.OakQuickSignupRoleSyncHooked then
        LFDQueueFrame:HookScript("OnShow", function()
            HandleQueueRoleSelectorChanged()
        end)
        LFDQueueFrame.OakQuickSignupRoleSyncHooked = true
    end

    if RaidFinderQueueFrame and not RaidFinderQueueFrame.OakQuickSignupRoleSyncHooked then
        RaidFinderQueueFrame:HookScript("OnShow", function()
            HandleQueueRoleSelectorChanged()
        end)
        RaidFinderQueueFrame.OakQuickSignupRoleSyncHooked = true
    end
end

quickSignupToggleBox:SetScript("OnClick", function(self)
    SetQuickSignupEnabled(not IsQuickSignupEnabled())
    self:SetState(IsQuickSignupEnabled())
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
    SetPersistSignupNoteEnabled(not IsPersistSignupNoteEnabled())
    self:SetState(IsPersistSignupNoteEnabled())
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
        SyncQueueRoleSelectorsFromOakRoles()
    end)
end

function addonTable.EnsureSearchSignupHooks()
    UpdatePersistentNotePatch()
    EnsureQueueRoleSelectorHooks()
    HookSignupNoteFallback()

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
        quickSignupState.noteFallbackWarnedForDialog = false
        HookSignupNoteFallback()
        local shouldQuickSignup = quickSignupState.pending
        local hasClicked = false
        if shouldQuickSignup then
            QueueApplySavedQuickSignupRoles(self, function(dialog, expectedResultID)
                if not hasClicked and shouldQuickSignup
                        and dialog.SignUpButton and dialog.SignUpButton:IsEnabled()
                        and dialog.resultID == expectedResultID then
                    hasClicked = true
                    quickSignupState.applicationTimes[expectedResultID] = quickSignupState.applicationTimes[expectedResultID] or GetTime()
                    dialog.SignUpButton:Click()
                    if addonTable.StartSignupCooldown then
                        addonTable.StartSignupCooldown()
                    end
                end
            end)
        else
            ApplySavedQuickSignupRoles(self)
        end
        quickSignupState.pending = false
    end)

    LFGListApplicationDialog:HookScript("OnHide", function()
        SaveSignupNoteFromEditBox(GetSignupNoteEditBox())
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
    local panel = LFGListFrame.SearchPanel
    local shouldQuickSignup = IsQuickSignupEnabled() and not IsShiftKeyDown() or false
    quickSignupState.pending = shouldQuickSignup

    if shouldQuickSignup and ApplyQuickSignupDirect(searchResultID) then
        quickSignupState.pending = false
        return
    end

    if FallbackShowSignupDialog(searchResultID) then
        quickSignupState.pending = false
        return
    end

    if LFGListSearchPanelUtil_CanSelectResult and not LFGListSearchPanelUtil_CanSelectResult(searchResultID) then
        return
    end

    if TryPanelSignup(panel, searchResultID) then
        return
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if TryPanelSignup(panel, searchResultID) then
                return
            end

            C_Timer.After(0.05, function()
                if TryPanelSignup(panel, searchResultID) then
                    return
                end

                if panel and panel.SignUpButton and panel.SignUpButton:IsEnabled() then
                    LFGListSearchPanel_SignUp(panel)
                    if addonTable.MarkSearchResultApplied then
                        addonTable.MarkSearchResultApplied(searchResultID)
                    end
                    return
                end
            end)
        end)
    else
        FallbackShowSignupDialog(searchResultID)
    end
end

addonTable.UpdateSearchQuickSignupControls()
