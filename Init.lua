local addonName, addonTable = ...

-- Global Database
OakLFGSorterDB = OakLFGSorterDB or {}
if OakLFGSorterDB.autoOpen == nil then OakLFGSorterDB.autoOpen = false end
if OakLFGSorterDB.scale == nil then OakLFGSorterDB.scale = 1.0 end
if OakLFGSorterDB.muteApplicantPing == nil then OakLFGSorterDB.muteApplicantPing = true end
if OakLFGSorterDB.hideNotes == nil then OakLFGSorterDB.hideNotes = false end

-- Font Registration
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local fontPath = "Interface\\AddOns\\OakLFGSorter\\media\\OakFont.ttf"

if LSM then LSM:Register("font", "OakUI Font", fontPath) end

addonTable.Fonts = {
    Regular = CreateFont("OakLFG_FontRegular"),
    Large = CreateFont("OakLFG_FontLarge"),
    Small = CreateFont("OakLFG_FontSmall")
}

addonTable.Fonts.Regular:SetFont(fontPath, 12, "")
addonTable.Fonts.Regular:SetShadowColor(0, 0, 0, 1)
addonTable.Fonts.Regular:SetShadowOffset(1, -1)

addonTable.Fonts.Large:SetFont(fontPath, 14, "")
addonTable.Fonts.Large:SetShadowColor(0, 0, 0, 1)
addonTable.Fonts.Large:SetShadowOffset(1, -1)

addonTable.Fonts.Small:SetFont(fontPath, 10, "")
addonTable.Fonts.Small:SetShadowColor(0, 0, 0, 1)
addonTable.Fonts.Small:SetShadowOffset(1, -1)

-- Colors & Styling
local _, playerClass = UnitClass("player")
addonTable.ClassColor = RAID_CLASS_COLORS[playerClass] or {r = 1, g = 1, b = 1}
addonTable.PlayerClass = playerClass

addonTable.FLAT_TEX = "Interface\\Buttons\\WHITE8X8"
addonTable.OAK_COLOR_BG = {0.106, 0.106, 0.129, 0.85} 
addonTable.OAK_COLOR_PANE = {0.137, 0.141, 0.172, 1}
addonTable.OAK_COLOR_BORDER = {0, 0, 0, 1}
addonTable.ROW_COLOR_A = {0.2, 0.22, 0.28, 0.4} 
addonTable.ROW_COLOR_B = {0, 0, 0, 0} 

addonTable.RoleTexCoords = {
    ["TANK"] = {0, 19/64, 22/64, 41/64},
    ["HEALER"] = {20/64, 39/64, 1/64, 20/64},
    ["DAMAGER"] = {20/64, 39/64, 22/64, 41/64}
}

addonTable.ValidClasses = {
    "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER",
    "MAGE", "MONK", "PALADIN", "PRIEST", "ROGUE",
    "SHAMAN", "WARLOCK", "WARRIOR"
}

-- Custom Spec Abbreviations
addonTable.SpecShortNames = {
    -- Death Knight
    [250] = "BDK", [251] = "FDK", [252] = "Unh",
    -- Demon Hunter
    [577] = "Hav", [581] = "Veng", [1480] = "Devo",
    -- Druid
    [102] = "Bal", [103] = "Fer", [104] = "Guard", [105] = "Resto",
    -- Evoker
    [1467] = "Dev", [1468] = "Pres", [1473] = "Aug",
    -- Hunter
    [253] = "BM", [254] = "MM", [255] = "Surv",
    -- Mage
    [62] = "Arc", [63] = "Fire", [64] = "Frost",
    -- Monk
    [268] = "Brew", [269] = "WW", [270] = "MW",
    -- Paladin
    [65] = "Holy", [66] = "Prot", [70] = "Ret",
    -- Priest
    [256] = "Disc", [257] = "Holy", [258] = "Shad",
    -- Rogue
    [259] = "Assa", [260] = "Out", [261] = "Sub",
    -- Shaman
    [262] = "Ele", [263] = "Enh", [264] = "Resto",
    -- Warlock
    [265] = "Aff", [266] = "Demo", [267] = "Destro",
    -- Warrior
    [71] = "Arms", [72] = "Fury", [73] = "Prot"
}

function addonTable.ApplyClassColor(text, classStr)
    local c = RAID_CLASS_COLORS[string.upper(classStr or "")]
    if c then return string.format("|cFF%02x%02x%02x%s|r", c.r*255, c.g*255, c.b*255, text) end
    return "|cFFFFFFFF" .. (text or "") .. "|r"
end

function addonTable.CreateFlatButton(parent, label, width)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, 22)
    btn:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
    btn:SetBackdropColor(unpack(addonTable.OAK_COLOR_PANE)) 
    btn:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    
    btn.text = btn:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(label)
    
    btn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER)) end)
    return btn
end
