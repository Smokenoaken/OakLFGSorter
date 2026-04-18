local _, addonTable = ...
local ldbInst

local function CreateLDB()
    local LDBLib = LibStub and LibStub("LibDataBroker-1.1", true)
    if not LDBLib then
        return
    end
    if ldbInst then
        return
    end

    ldbInst = LDBLib:NewDataObject("OakLFGSorter", {
        type = "launcher",
        text = "OakLFGSorter",
        label = "OakLFGSorter",
        icon = "Interface\\AddOns\\OakLFGSorter\\Media\\icon.png",
        OnClick = addonTable.ClickMinimapButton,
    })

    function ldbInst:OnTooltipShow()
        self:AddLine("Oakensoul LFG Sorter", 1, 1, 1)
        self:AddLine("Left-click to open Oak's browser.", 1, 1, 1)
        self:AddLine("Right-click to open Oak's options.", 1, 1, 1)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    CreateLDB()
end)
