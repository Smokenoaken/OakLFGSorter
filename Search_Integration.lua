local addonName, addonTable = ...

local OAK_LFG = addonTable.OAK_LFG
if not OAK_LFG then
    return
end

local FLAT_TEX = "Interface\\Buttons\\WHITE8X8"
local OAK_ICON = "Interface\\AddOns\\OakLFGSorter\\Media\\icon.png"
local _, playerClass = UnitClass("player")
local classColor = RAID_CLASS_COLORS[playerClass] or { r = 1, g = 1, b = 1 }
local pendingSearchPanelAutoOpen = false

local function QueueSearchPanelAutoOpen()
    if pendingSearchPanelAutoOpen then
        return
    end

    pendingSearchPanelAutoOpen = true
    if not (OakLFGSorterDB and OakLFGSorterDB.autoOpenSearch) then
        pendingSearchPanelAutoOpen = false
        return
    end
    if not (LFGListFrame and LFGListFrame.SearchPanel and LFGListFrame.SearchPanel:IsShown()) then
        pendingSearchPanelAutoOpen = false
        return
    end
    if addonTable.SetCurrentViewMode then
        addonTable.SetCurrentViewMode("browser")
    end
    OAK_LFG:Show()
    if addonTable.RefreshBrowserSearchFromOpen then
        addonTable.RefreshBrowserSearchFromOpen()
    end
    pendingSearchPanelAutoOpen = false
end

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:SetScript("OnEvent", function(_, _, loadedAddon)
    if loadedAddon ~= addonName and loadedAddon ~= "Blizzard_LookingForGroupUI" then
        return
    end

    -- Wire quick-signup popup hooks
    if addonTable.EnsureSearchSignupHooks then
        addonTable.EnsureSearchSignupHooks()
    end

    -- Add Oak auto-open toggle on the Blizzard Search panel.
    if LFGListFrame and LFGListFrame.SearchPanel and not LFGListFrame.SearchPanel.OakSearchToggleHooked then
        local searchPanel = LFGListFrame.SearchPanel
        local toggleBox = CreateFrame("Button", nil, LFGListFrame, "BackdropTemplate")
        toggleBox:SetSize(22, 22)
        toggleBox:SetBackdrop({ bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1 })
        toggleBox:RegisterForClicks("LeftButtonUp")
        local function PositionSearchToggle()
            toggleBox:ClearAllPoints()
            if UsePGFButton then
                toggleBox:SetPoint("RIGHT", UsePGFButton, "LEFT", -6, -1)
            elseif searchPanel.RefreshButton then
                toggleBox:SetPoint("RIGHT", searchPanel.RefreshButton, "LEFT", -6, -1)
            else
                toggleBox:SetPoint("TOPRIGHT", LFGListFrame, "TOPRIGHT", -34, -4)
            end
        end
        PositionSearchToggle()
        toggleBox:SetFrameLevel((LFGListFrame:GetFrameLevel() or 1) + 20)
        toggleBox:Hide()

        local tint = toggleBox:CreateTexture(nil, "BACKGROUND")
        tint:SetTexture(FLAT_TEX)
        tint:SetPoint("TOPLEFT", 1, -1)
        tint:SetPoint("BOTTOMRIGHT", -1, 1)

        local icon = toggleBox:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("CENTER")
        icon:SetTexture(OAK_ICON)

        toggleBox:SetHighlightTexture(FLAT_TEX, "ADD")
        local highlight = toggleBox:GetHighlightTexture()
        if highlight then
            highlight:SetVertexColor(1, 1, 1, 0.15)
        end

        OakLFGSorterDB = OakLFGSorterDB or {}
        if OakLFGSorterDB.autoOpenSearch == nil then
            OakLFGSorterDB.autoOpenSearch = true
        end

        local function UpdateState()
            if OakLFGSorterDB.autoOpenSearch then
                toggleBox:SetBackdropColor(classColor.r * 0.28, classColor.g * 0.28, classColor.b * 0.28, 0.95)
                toggleBox:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
                tint:SetVertexColor(classColor.r, classColor.g, classColor.b, 0.25)
                icon:SetDesaturated(false)
                icon:SetAlpha(1)
            else
                toggleBox:SetBackdropColor(0.08, 0.08, 0.10, 0.95)
                toggleBox:SetBackdropBorderColor(0, 0, 0, 1)
                tint:SetVertexColor(classColor.r, classColor.g, classColor.b, 0.12)
                icon:SetDesaturated(true)
                icon:SetAlpha(0.35)
            end
        end

        local function UpdateVisibility()
            PositionSearchToggle()
            if searchPanel and searchPanel:IsShown() then
                toggleBox:Show()
            else
                toggleBox:Hide()
            end
        end

        UpdateState()
        toggleBox:SetScript("OnClick", function()
            OakLFGSorterDB.autoOpenSearch = not OakLFGSorterDB.autoOpenSearch
            UpdateState()
            if OakLFGSorterDB.autoOpenSearch then
                if addonTable.SetCurrentViewMode then addonTable.SetCurrentViewMode("browser") end
                OAK_LFG:Show()
                if addonTable.RefreshBrowserSearchFromOpen then
                    addonTable.RefreshBrowserSearchFromOpen()
                end
            else
                OAK_LFG:Hide()
            end
        end)

        toggleBox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Auto-Open Sorter", 1, 1, 1)
            GameTooltip:AddLine("Automatically open Oak when Blizzard's group browser opens.", 1, 1, 1, true)
            GameTooltip:Show()
        end)

        toggleBox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -- When the Blizzard search panel opens, show OAK_LFG in browser mode
        LFGListFrame.SearchPanel:HookScript("OnShow", function()
            UpdateVisibility()
            if OakLFGSorterDB.autoOpenSearch then
                QueueSearchPanelAutoOpen()
            else
                OAK_LFG:Hide()
            end
        end)
        LFGListFrame.SearchPanel:HookScript("OnHide", UpdateVisibility)
        UpdateVisibility()

        LFGListFrame.SearchPanel.OakSearchToggleHooked = true
    end
end)
