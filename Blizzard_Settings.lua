local addonName, addonTable = ...
local L = addonTable.L

local PANEL_NAME = "OAK LFG Sorter"

local settingsFrame = CreateFrame("Frame", "OakLFGSorterBlizzardSettingsPanel")
settingsFrame.name = PANEL_NAME
addonTable.BlizzardSettingsPanel = settingsFrame

local scrollFrame = CreateFrame("ScrollFrame", nil, settingsFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 4, -4)
scrollFrame:SetPoint("BOTTOMRIGHT", settingsFrame, "BOTTOMRIGHT", -24, 4)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(660, 980)
scrollFrame:SetScrollChild(content)

local refreshers = {}
local refreshing = false
local y = -18

local function AddRefresher(callback)
    refreshers[#refreshers + 1] = callback
end

local function RefreshSettingsPanel()
    if refreshing then
        return
    end

    refreshing = true
    for _, callback in ipairs(refreshers) do
        pcall(callback)
    end
    refreshing = false
end

addonTable.RefreshBlizzardSettingsPanel = RefreshSettingsPanel

local function RefreshBothOptionsSurfaces()
    if addonTable.RefreshOptionsPanel then
        addonTable.RefreshOptionsPanel()
    end
    RefreshSettingsPanel()
end

local function ShowTooltip(owner, title, description)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title or "", 1, 1, 1)
    if description and description ~= "" then
        GameTooltip:AddLine(description, 0.9, 0.9, 0.9, true)
    end
    GameTooltip:Show()
end

local function AddSection(title)
    y = y - 18
    local label = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    label:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    label:SetText(title)
    y = y - 30
    return label
end

local function AddCheckbox(labelText, tooltipText, getter, setter, enabledGetter)
    local check = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    check:SetSize(24, 24)

    local label = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    label:SetText(labelText)

    local hitArea = CreateFrame("Button", nil, content)
    hitArea:SetPoint("TOPLEFT", check, "TOPLEFT", 0, 0)
    hitArea:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", 6, 0)
    hitArea:SetScript("OnClick", function()
        if check:IsEnabled() then
            check:Click()
        end
    end)

    local function OnEnter(self)
        ShowTooltip(self, labelText, tooltipText)
    end
    check:SetScript("OnEnter", OnEnter)
    hitArea:SetScript("OnEnter", OnEnter)
    check:SetScript("OnLeave", GameTooltip_Hide)
    hitArea:SetScript("OnLeave", GameTooltip_Hide)

    check:SetScript("OnClick", function(self)
        if refreshing then
            return
        end
        setter(self:GetChecked() == true)
        RefreshBothOptionsSurfaces()
    end)

    AddRefresher(function()
        local enabled = not enabledGetter or enabledGetter() == true
        check:SetEnabled(enabled)
        check:SetChecked(getter() == true)
        label:SetTextColor(enabled and 1 or 0.5, enabled and 1 or 0.5, enabled and 1 or 0.5)
        hitArea:EnableMouse(enabled)
    end)

    y = y - 28
    return check
end

local function AddDropdown(labelText, tooltipText, labelProvider, optionProvider, onSelect, enabledGetter)
    local label = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", content, "TOPLEFT", 24, y)
    label:SetText(labelText)

    local button = addonTable.CreateSimpleDropdown(
        content,
        280,
        labelProvider,
        optionProvider,
        function(id, option)
            onSelect(id, option)
            RefreshBothOptionsSurfaces()
        end
    )
    button:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
    button:SetScript("OnEnter", function(self)
        ShowTooltip(self, labelText, tooltipText)
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    AddRefresher(function()
        local enabled = not enabledGetter or enabledGetter() == true
        button:SetEnabled(enabled)
        button:SetAlpha(enabled and 1 or 0.5)
        label:SetTextColor(enabled and 1 or 0.5, enabled and 1 or 0.5, enabled and 1 or 0.5)
        if button.RefreshSelection then
            button:RefreshSelection()
        end
    end)

    y = y - 62
    return button
end

local function AddSlider(labelText, tooltipText, minimum, maximum, step, getter, setter, formatter)
    local label = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", content, "TOPLEFT", 24, y)
    label:SetText(labelText)

    local valueLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    valueLabel:SetPoint("LEFT", label, "RIGHT", 12, 0)

    local slider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -10)
    slider:SetSize(280, 16)
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetOrientation("HORIZONTAL")

    local low = slider.Low
    local high = slider.High
    local text = slider.Text
    if low then low:Hide() end
    if high then high:Hide() end
    if text then text:Hide() end

    slider:SetScript("OnEnter", function(self)
        ShowTooltip(self, labelText, tooltipText)
    end)
    slider:SetScript("OnLeave", GameTooltip_Hide)
    slider:SetScript("OnValueChanged", function(_, value)
        local formatted = formatter and formatter(value) or tostring(value)
        valueLabel:SetText(formatted)
        if not refreshing then
            setter(value)
        end
    end)

    AddRefresher(function()
        slider:SetValue(getter())
    end)

    y = y - 60
    return slider
end

local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
title:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y)
title:SetText(L["OAK LFG Sorter"])

local description = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
description:SetWidth(610)
description:SetJustifyH("LEFT")
description:SetText("These settings mirror Oak's in-window cog panel. Changes made here or in Oak update the same saved settings.")

local openButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
openButton:SetSize(180, 24)
openButton:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -12)
openButton:SetText(L["Open Oak Options"])
openButton:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel:IsShown() then
        HideUIPanel(SettingsPanel)
    elseif InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
        HideUIPanel(InterfaceOptionsFrame)
    end

    C_Timer.After(0, function()
        if addonTable.OpenOakOptions then
            addonTable.OpenOakOptions()
        elseif addonTable.OpenOakBrowser then
            addonTable.OpenOakBrowser()
            if addonTable.ToggleOptionsPanel and not (addonTable.OptionsPanel and addonTable.OptionsPanel:IsShown()) then
                addonTable.ToggleOptionsPanel()
            end
        end
    end)
end)

y = y - 104
AddSection("General")

AddCheckbox(
    L["Show Regions"],
    "Show Oak's region tags in applicant and browser rows.",
    function() return OakLFGSorterDB.showRegions == true end,
    function(value) addonTable.SetShowRegions(value) end
)

AddCheckbox(
    L["Show Flags Instead of Tags"],
    "Use GroupfinderFlags country-style flags instead of Oak's text tags.",
    function() return OakLFGSorterDB.showRegionFlags == true end,
    function(value) addonTable.SetShowRegionFlags(value) end,
    function()
        return OakLFGSorterDB.showRegions == true
            and addonTable.CanShowRegionFlags
            and addonTable.CanShowRegionFlags()
    end
)

AddCheckbox(
    L["Show Spec Icons"],
    L["Show specialization icons instead of abbreviated names in the applicant list."],
    function() return OakLFGSorterDB.showSpecIcons == true end,
    function(value) addonTable.SetShowSpecIcons(value) end
)

AddCheckbox(
    L["Show Minimap Button"],
    L["Show Oak's minimap button for quick access to the browser and options."],
    function() return OakLFGSorterDB.hideMinimapButton ~= true end,
    function(value) addonTable.SetShowMinimapButton(value) end
)

AddCheckbox(
    L["Show Party Keys"],
    L["Show the Party Keys panel while browsing dungeons or listing groups."],
    function() return OakLFGSorterDB.showPartyKeys == true end,
    function(value) addonTable.SetShowPartyKeys(value) end
)

AddCheckbox(
    L["Tooltip on Cursor"],
    L["When enabled, browser row tooltips follow the mouse cursor. When disabled, they anchor to the right of Oak's rightmost visible panel."],
    function() return OakLFGSorterDB.attachBrowserTooltipToCursor == true end,
    function(value) addonTable.SetBrowserTooltipOnCursor(value) end
)

AddCheckbox(
    L["Keep Delisted/Cancelled/Filtered"],
    L["Keeps visible browser rows stable during live updates when they become delisted, cancelled, full, or filtered. Manual Refresh loads a fresh list."],
    function()
        local filters = addonTable.GetCharacterBrowserFilters and addonTable.GetCharacterBrowserFilters() or {}
        return filters.keepUnavailable ~= false
    end,
    function(value) addonTable.SetKeepUnavailableResults(value) end
)

AddDropdown(
    L["M+ Panel Side"],
    L["Choose whether the Mythic+ panel opens to the left or right of Oak."],
    function() return OakLFGSorterDB.mythicPlusPanelSide == "LEFT" and L["Left of Oak"] or L["Right of Oak"] end,
    function()
        return {
            { id = "RIGHT", label = L["Right of Oak"] },
            { id = "LEFT", label = L["Left of Oak"] },
        }
    end,
    function(id) addonTable.SetMythicPlusPanelSide(id) end
)

AddSection("Appearance")

AddDropdown(
    L["Theme"],
    "Switch between Oak's Classic and Modern themes. Changing this setting reloads the UI.",
    function() return addonTable.GetThemeModeLabel() end,
    function() return addonTable.ThemeModes end,
    function(id) addonTable.SetThemeMode(id) end
)

AddDropdown(
    L["Modern Style"],
    "Choose the Modern theme's frame and panel style.",
    function() return addonTable.GetThemeStyleLabel() end,
    function() return addonTable.ThemeStyles end,
    function(id) addonTable.SetThemeStyle(id) end,
    function() return addonTable.IsModernTheme and addonTable.IsModernTheme() end
)

AddDropdown(
    L["Modern Accent"],
    "Choose the accent color used by the Modern theme.",
    function() return addonTable.GetThemePresetLabel() end,
    function() return addonTable.ThemePresets end,
    function(id) addonTable.SetThemePreset(id) end,
    function() return addonTable.IsModernTheme and addonTable.IsModernTheme() end
)

local customAccentButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
customAccentButton:SetSize(180, 24)
customAccentButton:SetPoint("TOPLEFT", content, "TOPLEFT", 24, y)
customAccentButton:SetText(L["Custom Accent"])
customAccentButton:SetScript("OnClick", function()
    if addonTable.OpenThemeColorPicker then
        addonTable.OpenThemeColorPicker()
    end
end)
customAccentButton:SetScript("OnEnter", function(self)
    ShowTooltip(self, L["Custom Accent"], L["Choose a custom accent color for the Modern theme."])
end)
customAccentButton:SetScript("OnLeave", GameTooltip_Hide)
AddRefresher(function()
    local enabled = addonTable.IsModernTheme and addonTable.IsModernTheme()
    customAccentButton:SetEnabled(enabled)
    customAccentButton:SetAlpha(enabled and 1 or 0.5)
end)
y = y - 42

local fontLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
fontLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 24, y)
fontLabel:SetText(L["Addon Font"])
local fontButton = addonTable.CreateFontDropdown(content, 280)
fontButton:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -6)
AddRefresher(function()
    if fontButton.RefreshSelection then
        fontButton:RefreshSelection()
    end
end)
y = y - 62

AddSlider(
    L["Font Size"],
    L["Adjust the base Oak font size used throughout the addon."],
    10, 18, 1,
    function() return addonTable.GetFontSize and addonTable.GetFontSize() or 12 end,
    function(value)
        if addonTable.SetFontSize then addonTable.SetFontSize(math.floor(value + 0.5)) end
    end,
    function(value) return tostring(math.floor(value + 0.5)) end
)

AddSlider(
    L["Window Opacity"],
    L["Adjust the background opacity used by Oak's windows and side panels."],
    0.35, 1.0, 0.05,
    function() return addonTable.GetWindowOpacity and addonTable.GetWindowOpacity() or 0.85 end,
    function(value)
        if addonTable.SetWindowOpacity then
            addonTable.SetWindowOpacity(math.floor(value * 100 + 0.5) / 100)
        end
    end,
    function(value) return string.format("%d%%", math.floor(value * 100 + 0.5)) end
)

AddDropdown(
    L["Frame Strata"],
    L["Controls how high Oak sits relative to other UI windows. Lower strata lets other frames appear above it."],
    function()
        local current = addonTable.GetFrameStrata and addonTable.GetFrameStrata() or "DIALOG"
        for _, option in ipairs(addonTable.GetFrameStrataOptions and addonTable.GetFrameStrataOptions() or {}) do
            if option.id == current then return option.label end
        end
        return current
    end,
    function() return addonTable.GetFrameStrataOptions and addonTable.GetFrameStrataOptions() or {} end,
    function(id)
        if addonTable.SetFrameStrataPreference then addonTable.SetFrameStrataPreference(id) end
    end
)

AddSlider(
    L["Scale"],
    "Adjust Oak's window scale while preserving its on-screen position.",
    0.5, 1.5, 0.05,
    function() return tonumber(OakLFGSorterDB.scale) or 1.0 end,
    function(value)
        if addonTable.SetScalePreference then addonTable.SetScalePreference(value) end
    end,
    function(value) return string.format("%.2f", value) end
)

local resetButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
resetButton:SetSize(180, 24)
resetButton:SetPoint("TOPLEFT", content, "TOPLEFT", 24, y)
resetButton:SetText(L["Reset Position & Scale"])
resetButton:SetScript("OnClick", function()
    if addonTable.SetScalePreference then addonTable.SetScalePreference(1.0) end
    OakLFGSorterDB.framePos = nil
    OakLFGSorterDB.frameUserPlaced = false
    if addonTable.AutoPosition then addonTable.AutoPosition() end
    RefreshBothOptionsSurfaces()
end)
y = y - 44

AddSection(L["Browser Keybind"])

local bindingValue = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
bindingValue:SetPoint("TOPLEFT", content, "TOPLEFT", 24, y)
bindingValue:SetWidth(400)
bindingValue:SetJustifyH("LEFT")

local setBindingButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
setBindingButton:SetSize(130, 24)
setBindingButton:SetPoint("TOPLEFT", bindingValue, "BOTTOMLEFT", 0, -8)
setBindingButton:SetText(L["Set Key"])

local clearBindingButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
clearBindingButton:SetSize(90, 24)
clearBindingButton:SetPoint("LEFT", setBindingButton, "RIGHT", 8, 0)
clearBindingButton:SetText(L["Clear"])

local bindingCaptureActive = false
local function StopBindingCapture()
    bindingCaptureActive = false
    settingsFrame:EnableKeyboard(false)
    settingsFrame:SetPropagateKeyboardInput(true)
    setBindingButton:SetText(L["Set Key"])
    RefreshSettingsPanel()
end

setBindingButton:SetScript("OnClick", function()
    if InCombatLockdown and InCombatLockdown() then
        bindingValue:SetText(L["Cannot change bindings in combat."])
        return
    end
    bindingCaptureActive = true
    settingsFrame:EnableKeyboard(true)
    settingsFrame:SetPropagateKeyboardInput(false)
    setBindingButton:SetText(L["Press Key..."])
    bindingValue:SetText(L["Press a key combination. Esc cancels. Backspace clears."])
end)

clearBindingButton:SetScript("OnClick", function()
    if addonTable.SetOakBrowserBinding then
        addonTable.SetOakBrowserBinding(nil)
    end
    StopBindingCapture()
end)

settingsFrame:SetPropagateKeyboardInput(true)
settingsFrame:SetScript("OnKeyDown", function(_, key)
    if not bindingCaptureActive then
        return
    end
    if key == "ESCAPE" then
        StopBindingCapture()
        return
    end
    if key == "BACKSPACE" then
        if addonTable.SetOakBrowserBinding then addonTable.SetOakBrowserBinding(nil) end
        StopBindingCapture()
        return
    end

    local binding = addonTable.BuildOakBrowserBinding and addonTable.BuildOakBrowserBinding(key)
    if not binding then
        bindingValue:SetText(L["Choose a non-modifier key."])
        return
    end
    if addonTable.SetOakBrowserBinding then addonTable.SetOakBrowserBinding(binding) end
    StopBindingCapture()
end)

AddRefresher(function()
    if not bindingCaptureActive then
        local bindingText = addonTable.FormatOakBindingText and addonTable.FormatOakBindingText() or "Not bound."
        bindingValue:SetText("Current binding: " .. bindingText)
        setBindingButton:SetText(L["Set Key"])
    end
end)

y = y - 82
AddSection("Signup Note")

AddCheckbox(
    L["Keep Note This Session"],
    L["Keeps Blizzard's sign-up note when switching between groups until you reload or log out."],
    function()
        return addonTable.GetPersistSignupNoteEnabled and addonTable.GetPersistSignupNoteEnabled() or false
    end,
    function(value)
        if addonTable.SetPersistSignupNoteEnabled then addonTable.SetPersistSignupNoteEnabled(value) end
    end
)

local noteWarning = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
noteWarning:SetPoint("TOPLEFT", content, "TOPLEFT", 24, y)
noteWarning:SetWidth(600)
noteWarning:SetJustifyH("LEFT")
noteWarning:SetTextColor(1, 0.82, 0)
noteWarning:SetText("Blizzard marks the signup-note field as secure and prevents addons from restoring text after /reload or logout. This option can only retain the note while the current UI session remains loaded.")
y = y - 58

content:SetHeight(math.max(980, math.abs(y) + 30))

settingsFrame:HookScript("OnShow", RefreshSettingsPanel)
settingsFrame:HookScript("OnHide", function()
    bindingCaptureActive = false
    settingsFrame:EnableKeyboard(false)
    settingsFrame:SetPropagateKeyboardInput(true)
    setBindingButton:SetText(L["Set Key"])
end)

local settingsCategoryRegistered = false
local function RegisterSettingsCategory()
    if settingsCategoryRegistered then
        return true
    end

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(settingsFrame, PANEL_NAME)
        Settings.RegisterAddOnCategory(category)
        addonTable.BlizzardSettingsCategory = category
        settingsCategoryRegistered = true
        return true
    end

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(settingsFrame)
        settingsCategoryRegistered = true
        return true
    end

    return false
end

if not RegisterSettingsCategory() then
    local registerFrame = CreateFrame("Frame")
    registerFrame:RegisterEvent("PLAYER_LOGIN")
    registerFrame:RegisterEvent("ADDON_LOADED")
    registerFrame:SetScript("OnEvent", function(self, event, loadedAddon)
        if event == "ADDON_LOADED" and loadedAddon ~= "Blizzard_Settings" then
            return
        end
        if RegisterSettingsCategory() then
            self:UnregisterAllEvents()
        end
    end)
end

RefreshSettingsPanel()
