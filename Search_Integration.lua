local addonName, addonTable = ...

local OAK_LFG = addonTable.OAK_LFG
if not OAK_LFG then
    return
end

local FLAT_TEX = "Interface\\Buttons\\WHITE8X8"
local _, playerClass = UnitClass("player")
local classColor = RAID_CLASS_COLORS[playerClass] or { r = 1, g = 1, b = 1 }

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

    -- Add "Auto-Open Sorter" toggle on the Blizzard Search panel
    if LFGListFrame and LFGListFrame.SearchPanel and not LFGListFrame.SearchPanel.OakSearchToggleHooked then
        local toggleHolder = CreateFrame("Frame", nil, LFGListFrame.SearchPanel)
        toggleHolder:SetSize(170, 18)
        toggleHolder:SetPoint("TOP", LFGListFrame.SearchPanel, "TOP", 0, -32)

        local toggleBox = CreateFrame("Button", nil, toggleHolder, "BackdropTemplate")
        toggleBox:SetSize(16, 16)
        toggleBox:SetPoint("LEFT", toggleHolder, "LEFT", 0, 0)
        toggleBox:SetBackdrop({ bgFile = FLAT_TEX, edgeFile = FLAT_TEX, edgeSize = 1 })

        local label = toggleHolder:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
        label:SetPoint("LEFT", toggleBox, "RIGHT", 8, 0)
        label:SetText("Auto-Open Sorter")

        OakLFGSorterDB = OakLFGSorterDB or {}
        if OakLFGSorterDB.autoOpenSearch == nil then
            OakLFGSorterDB.autoOpenSearch = true
        end

        local function UpdateState()
            if OakLFGSorterDB.autoOpenSearch then
                toggleBox:SetBackdropColor(classColor.r, classColor.g, classColor.b, 1)
                toggleBox:SetBackdropBorderColor(0, 0, 0, 1)
            else
                toggleBox:SetBackdropColor(0.08, 0.08, 0.10, 0.95)
                toggleBox:SetBackdropBorderColor(classColor.r * 0.65, classColor.g * 0.65, classColor.b * 0.65, 1)
            end
        end

        UpdateState()
        toggleBox:SetScript("OnClick", function()
            OakLFGSorterDB.autoOpenSearch = not OakLFGSorterDB.autoOpenSearch
            UpdateState()
            if OakLFGSorterDB.autoOpenSearch then
                if addonTable.SetCurrentViewMode then addonTable.SetCurrentViewMode("browser") end
                OAK_LFG:Show()
            else
                OAK_LFG:Hide()
            end
        end)

        -- When the Blizzard search panel opens, show OAK_LFG in browser mode
        LFGListFrame.SearchPanel:HookScript("OnShow", function()
            if OakLFGSorterDB.autoOpenSearch then
                if addonTable.SetCurrentViewMode then addonTable.SetCurrentViewMode("browser") end
                OAK_LFG:Show()
            else
                OAK_LFG:Hide()
            end
        end)

        LFGListFrame.SearchPanel.OakSearchToggleHooked = true
    end
end)
