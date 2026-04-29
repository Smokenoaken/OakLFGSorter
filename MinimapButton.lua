local addonName, addonTable = ...

local minimapButton
local combatQueueFrame
local pendingOpenAfterCombat = false
local pendingOpenNoticeShown = false

local function IsGroupFinderInteractionBlocked()
    return InCombatLockdown and InCombatLockdown()
end

local function NotifyQueuedOpen()
    if pendingOpenNoticeShown then
        return
    end
    pendingOpenNoticeShown = true
    print("|cFF00FF00Oak LFG Sorter:|r Cannot open during combat. Oak will open when combat ends.")
end

local function QueueOpenAfterCombat()
    pendingOpenAfterCombat = true
    if combatQueueFrame then
        combatQueueFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
    NotifyQueuedOpen()
end

local function ShowOakFrameSafely()
    local oakFrame = addonTable.OAK_LFG
    if not oakFrame then
        return false
    end

    if oakFrame:IsShown() then
        pendingOpenAfterCombat = false
        return true
    end

    if IsGroupFinderInteractionBlocked() then
        QueueOpenAfterCombat()
        return false
    end

    pendingOpenAfterCombat = false
    pendingOpenNoticeShown = false
    oakFrame:Show()
    return true
end

local function EnsureDB()
    OakLFGSorterDB = OakLFGSorterDB or {}
    if OakLFGSorterDB.hideMinimapButton == nil then
        OakLFGSorterDB.hideMinimapButton = false
    end
    if type(OakLFGSorterDB.minimapButton) ~= "table" then
        OakLFGSorterDB.minimapButton = {}
    end
    if OakLFGSorterDB.minimapButton.angle == nil then
        OakLFGSorterDB.minimapButton.angle = 220
    end
    return OakLFGSorterDB
end

local function UpdateMinimapButtonPosition()
    if not minimapButton or not Minimap then
        return
    end

    local db = EnsureDB()
    local angle = math.rad(tonumber(db.minimapButton.angle) or 220)
    local radius = ((Minimap:GetWidth() or 140) * 0.5) + 2
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius

    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function OpenOakBrowser()
    EnsureDB()
    if IsGroupFinderInteractionBlocked() then
        if addonTable.OAK_LFG then
            addonTable.userExplicitlyClosed = false
            if addonTable.SetCurrentViewMode then
                if C_LFGList and C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo() then
                    addonTable.SetCurrentViewMode("applicant")
                end
            end
            QueueOpenAfterCombat()
        end
        return
    end
    if addonTable.OpenGroupFinderForOak then
        addonTable.OpenGroupFinderForOak()
    end
    addonTable.userExplicitlyClosed = false
    if addonTable.SetCurrentViewMode then
        addonTable.SetCurrentViewMode("browser")
    end
    if addonTable.RunBrowserSearch then
        addonTable.RunBrowserSearch()
    end
    ShowOakFrameSafely()
end
addonTable.OpenOakBrowser = OpenOakBrowser

local function ToggleOakBrowser()
    local oakFrame = addonTable.OAK_LFG
    local searchFrame = addonTable.OAK_SEARCH

    if (oakFrame and oakFrame:IsShown()) or (searchFrame and searchFrame:IsShown()) then
        addonTable.userExplicitlyClosed = true
        if searchFrame and searchFrame:IsShown() then
            searchFrame:Hide()
        end
        if oakFrame and oakFrame:IsShown() then
            oakFrame:Hide()
        end
        return
    end

    addonTable.userExplicitlyClosed = false
    OpenOakBrowser()
end
addonTable.ToggleBrowserWindow = ToggleOakBrowser

local function OpenOakOptions()
    if IsGroupFinderInteractionBlocked() then
        if addonTable.OAK_LFG and addonTable.OAK_LFG:IsShown() then
            print("|cFF00FF00Oak LFG Sorter:|r Options cannot open during combat.")
        else
            addonTable.userExplicitlyClosed = false
            QueueOpenAfterCombat()
        end
        return
    end

    if not (addonTable.OAK_LFG and addonTable.OAK_LFG:IsShown()) then
        OpenOakBrowser()
    end

    if addonTable.ToggleOptionsPanel then
        if not (addonTable.OptionsPanel and addonTable.OptionsPanel:IsShown()) then
            addonTable.ToggleOptionsPanel()
        elseif addonTable.RefreshOptionsPanel then
            addonTable.RefreshOptionsPanel()
        end
    end
end
addonTable.OpenOakOptions = OpenOakOptions

function addonTable.UpdateMinimapButtonVisibility()
    if not minimapButton then
        return
    end

    local db = EnsureDB()
    if db.hideMinimapButton then
        minimapButton:Hide()
    else
        UpdateMinimapButtonPosition()
        minimapButton:Show()
    end
end

local function UpdateDragPosition()
    if not minimapButton or not Minimap then
        return
    end

    local centerX, centerY = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    cursorX = cursorX / scale
    cursorY = cursorY / scale

    local atan2 = math.atan2 or math.atan
    local angle = math.deg(atan2(cursorY - centerY, cursorX - centerX))
    EnsureDB().minimapButton.angle = angle
    UpdateMinimapButtonPosition()
end

local function CreateMinimapButton()
    if minimapButton or not Minimap then
        return
    end

    local button = CreateFrame("Button", "SorterClassicMinimapButton", Minimap)
    minimapButton = button
    addonTable.MinimapButton = button

    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local ring = button:CreateTexture(nil, "BACKGROUND")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetSize(54, 54)
    ring:SetPoint("TOPLEFT")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexture("Interface\\AddOns\\OakLFGSorter\\Media\\icon.png")
    button.icon = icon

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetSize(52, 52)
    highlight:SetPoint("CENTER", button, "CENTER", 0, 1)

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            OpenOakOptions()
        else
            if addonTable.OAK_LFG and addonTable.OAK_LFG:IsShown() then
                addonTable.userExplicitlyClosed = true
                if addonTable.OAK_SEARCH and addonTable.OAK_SEARCH:IsShown() then
                    addonTable.OAK_SEARCH:Hide()
                end
                addonTable.OAK_LFG:Hide()
            else
                OpenOakBrowser()
            end
        end
    end)

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", UpdateDragPosition)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        UpdateDragPosition()
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("OAK LFG Sorter", 1, 1, 1)
        GameTooltip:AddLine("Left-click to open Oak's browser.", 1, 1, 1, true)
        GameTooltip:AddLine("Right-click to open Oak's options.", 1, 1, 1, true)
        GameTooltip:AddLine("Drag to move this button around the minimap.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdateMinimapButtonPosition()
    addonTable.UpdateMinimapButtonVisibility()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    EnsureDB()
    CreateMinimapButton()
end)

combatQueueFrame = CreateFrame("Frame")
combatQueueFrame:SetScript("OnEvent", function(self, event)
    if event ~= "PLAYER_REGEN_ENABLED" then
        return
    end

    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if not pendingOpenAfterCombat then
        return
    end

    pendingOpenAfterCombat = false
    pendingOpenNoticeShown = false
    if addonTable.userExplicitlyClosed then
        return
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if IsGroupFinderInteractionBlocked() then
                QueueOpenAfterCombat()
                return
            end
            if addonTable.userExplicitlyClosed then
                return
            end
            if addonTable.OpenOakBrowser then
                addonTable.OpenOakBrowser()
            else
                ShowOakFrameSafely()
            end
        end)
        return
    end

    if addonTable.OpenOakBrowser then
        addonTable.OpenOakBrowser()
    else
        ShowOakFrameSafely()
    end
end)
