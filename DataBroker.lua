local _, addonTable = ...

local ldbObject

local function CreateDataBrokerObject()
    if ldbObject or not (LibStub and addonTable and addonTable.ClickMinimapButton) then
        return
    end

    local LDB = LibStub("LibDataBroker-1.1", true)
    if not LDB then
        return
    end

    ldbObject = LDB:NewDataObject("OakLFGSorter", {
        type = "launcher",
        text = "OakLFGSorter",
        label = "OakLFGSorter",
        icon = "Interface\\AddOns\\OakLFGSorter\\Media\\icon.png",
        OnClick = addonTable.ClickMinimapButton,
    })

    function ldbObject:OnTooltipShow()
        self:AddLine("Oakensoul LFG Sorter", 1, 1, 1)
        self:AddLine("Left-click to open Oak's browser.", 1, 1, 1)
        self:AddLine("Right-click to open Oak's options.", 1, 1, 1)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    CreateDataBrokerObject()
end)
