local addonName, addonTable = ...
local L = addonTable.L
local OAK_LFG = addonTable.OAK_LFG

addonTable.ApplicantGroups = {}
addonTable.CurrentSortBy = "ilvl"
addonTable.CurrentIsAscending = false
local ROW_HEIGHT = 22 
local FULL_FRAME_WIDTH = 660
local COLLAPSED_FRAME_WIDTH = 460
local BROWSER_COLLAPSED_WIDTH = 535
local BROWSER_DEFAULT_WIDTH = 660
local MAX_FRAME_WIDTH = 1100
local BASE_HEADER_TOP_OFFSET = -43
local BASE_SCROLL_TOP_OFFSET = -70
local APPLICANT_CONTEXT_BAR_HEIGHT = 24
local HEADER_TOP_OFFSET = BASE_HEADER_TOP_OFFSET
local SCROLL_TOP_OFFSET = BASE_SCROLL_TOP_OFFSET
local roleWeights = { ["TANK"] = 1, ["HEALER"] = 2, ["DAMAGER"] = 3 }
local GetBrowserApplicationPriority
local IsRaidBrowserMode  -- forward declaration (defined below IsBrowserMode)
local IsPvpBrowserMode
local RefreshBrowserResponsiveLayout
local MODE_CONFIGS = {
    mythic_plus = { ratingLabel = "M+ Rating", keyLabel = "Key" },
    rated_pvp = { ratingLabel = "PVP Rating", keyLabel = "Type" },
    pvp = { ratingLabel = "PVP Rating", keyLabel = "Type" },
    raid = { ratingLabel = "Raid", keyLabel = "Prog" },
    legacy_raid = { ratingLabel = "Raid", keyLabel = "Prog" },
    delve = { ratingLabel = "M+ Rating", keyLabel = "Key" },
    open_world = { ratingLabel = "M+ Rating", keyLabel = "Key" },
    generic = { ratingLabel = "M+ Rating", keyLabel = "Key" },
}

local function GetListingMode()
    if addonTable.GetCurrentViewMode and addonTable.GetCurrentViewMode() == "browser" then
        local ctx = addonTable.CurrentSearchContext
        local selectedCategoryKey = ctx and ctx.selectedCategoryKey
        if selectedCategoryKey == "RAIDS_LEGACY" then
            return "legacy_raid"
        elseif selectedCategoryKey == "RAIDS_MIDNIGHT" then
            return "raid"
        end
        return (ctx and ctx.mode) or "generic"
    end

    return (addonTable.CurrentListingContext and addonTable.CurrentListingContext.mode) or "generic"
end

local function GetModeConfig()
    return MODE_CONFIGS[GetListingMode()] or MODE_CONFIGS.generic
end

local function IsRatedBattlegroundResult(result)
    if type(result) ~= "table" then
        return false
    end

    if result.mode ~= "pvp" and result.mode ~= "rated_pvp" then
        return false
    end

    local bracket = strlower(tostring(result.pvpBracket or ""))
    if bracket == "rbg" then
        return true
    end

    local activityText = strlower(table.concat({
        tostring(result.activityName or ""),
        tostring(result.dungeonName or ""),
    }, " "))

    return activityText:find("rated battleground", 1, true) ~= nil
        or activityText:find("battleground", 1, true) ~= nil
        or activityText:find("rbg", 1, true) ~= nil
        or (tonumber(result.maxPlayers) or 0) > 3
end

local function IsRatedBattlegroundBrowserMode()
    if not IsPvpBrowserMode() then
        return false
    end

    local firstResult = addonTable.SearchResults and addonTable.SearchResults[1]
    if IsRatedBattlegroundResult(firstResult) then
        return true
    end

    local ctxInfo = addonTable.CurrentSearchContext and addonTable.CurrentSearchContext.activityInfo
    local activityText = strlower(table.concat({
        tostring(ctxInfo and ctxInfo.fullName or ""),
        tostring(ctxInfo and ctxInfo.shortName or ""),
    }, " "))

    return activityText:find("rated battleground", 1, true) ~= nil
        or activityText:find("battleground", 1, true) ~= nil
        or activityText:find("rbg", 1, true) ~= nil
end

local function GetHeaderTooltipData(sortKey)
    local isBrowser = addonTable.GetCurrentViewMode and addonTable.GetCurrentViewMode() == "browser"
    local listingMode = GetListingMode()

    if sortKey == "role" then
        if isBrowser then
            if IsRaidBrowserMode() then
                return "Raid", "Sort by raid instance name."
            elseif listingMode == "pvp" or listingMode == "rated_pvp" then
                if IsRatedBattlegroundBrowserMode() then
                    return "Activity", "Sort by PvP activity type."
                end
                return "Arena", "Sort by arena bracket (2v2 / 3v3)."
            elseif listingMode == "delve" then
                return "Delve", "Sort by delve name."
            elseif listingMode == "generic" then
                local ctxInfo = addonTable.CurrentSearchContext and addonTable.CurrentSearchContext.activityInfo
                local firstResult = addonTable.SearchResults and addonTable.SearchResults[1]
                local hint = strlower(
                    (ctxInfo and (ctxInfo.fullName or ctxInfo.shortName or ""))
                    or (firstResult and (firstResult.activityName or firstResult.dungeonName or ""))
                    or ""
                )
                if hint:find("custom", 1, true) then
                    return "Activity", "Sort by activity type."
                end
                return "Zone", "Sort by zone name."
            end
            return "Dungeon", "Sort by dungeon or activity name."
        end
        return "Role", "Sort by the applicant's primary role."
    elseif sortKey == "class" then
        if isBrowser then
            return "Title", "Sort by the listing title."
        end
        return "Class", "Sort by the applicant's class."
    elseif sortKey == "spec" then
        if isBrowser then
            if IsRaidBrowserMode() then
                return "Difficulty", "Sort by raid difficulty."
            end
            return nil, nil  -- hidden in non-raid browser
        end
        return "Spec", "Sort by the applicant's specialization."
    elseif sortKey == "ilvl" then
        if isBrowser then
            return "Comp", "Sort by the current party composition of the listing."
        end
        return "iLvl", "Sort by item level."
    elseif sortKey == "rating" then
        local modeConfig = GetModeConfig()
        if listingMode == "raid" or listingMode == "legacy_raid" then
            if isBrowser then
                return "Kills", "Sort by boss kills. Shows how many raid bosses the group leader has defeated in this lockout (e.g. 4/8)."
            end
            return modeConfig.ratingLabel, "Sort by raid progress for the applicant."
        elseif listingMode == "rated_pvp" or listingMode == "pvp" then
            return modeConfig.ratingLabel, "Sort by PVP rating."
        end
        return modeConfig.ratingLabel, "Sort by Mythic+ rating."
    elseif sortKey == "key" then
        if isBrowser then
            return "Age", "Sort by how long ago this listing was posted. Older listings may have already filled."
        end
        local modeConfig = GetModeConfig()
        if listingMode == "raid" or listingMode == "legacy_raid" then
            return modeConfig.keyLabel, "Sort by the applicant's raid progress."
        elseif listingMode == "rated_pvp" or listingMode == "pvp" then
            return modeConfig.keyLabel, "Sort by bracket type."
        end
        return modeConfig.keyLabel, "Sort by best key level or key-related metric."
    elseif sortKey == "region" then
        if addonTable.ShouldShowRegionFlags and addonTable.ShouldShowRegionFlags() then
            return "Region", "Sort by the displayed flag derived from the leader's or applicant's realm."
        end
        return "Region", "Sort by the displayed region derived from the leader's or applicant's realm."
    end

    return nil, nil
end

local function UsesSecondaryMetricColumn()
    local listingMode = GetListingMode()
    return not (listingMode == "rated_pvp" or listingMode == "pvp")
end

local function IsBrowserMode()
    return addonTable.GetCurrentViewMode and addonTable.GetCurrentViewMode() == "browser"
end

local function IsCustomCategoryBrowserMode()
    if not IsBrowserMode() then
        return false
    end

    local ctx = addonTable.CurrentSearchContext
    return ctx and ctx.selectedCategoryKey == "CUSTOM"
end

IsRaidBrowserMode = function()
    if not IsBrowserMode() then return false end
    local m = (addonTable.CurrentSearchContext and addonTable.CurrentSearchContext.mode) or "generic"
    return m == "raid" or m == "legacy_raid"
end

IsPvpBrowserMode = function()
    if not IsBrowserMode() then return false end
    if IsCustomCategoryBrowserMode() then return false end
    local m = GetListingMode()
    return m == "pvp" or m == "rated_pvp"
end

local scrollFrame = CreateFrame("ScrollFrame", "OakLFGScrollFrame", OAK_LFG, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", OAK_LFG, "TOPLEFT", 10, SCROLL_TOP_OFFSET)
scrollFrame:SetPoint("BOTTOMRIGHT", OAK_LFG, "BOTTOMRIGHT", -25, 35) 

local scrollBar = _G[scrollFrame:GetName() .. "ScrollBar"]
if scrollBar then
    local upBtn = _G[scrollFrame:GetName() .. "ScrollBarScrollUpButton"]
    local downBtn = _G[scrollFrame:GetName() .. "ScrollBarScrollDownButton"]
    if upBtn then upBtn:Hide(); upBtn:SetSize(0.1, 0.1) end
    if downBtn then downBtn:Hide(); downBtn:SetSize(0.1, 0.1) end

    local topTex = _G[scrollFrame:GetName() .. "ScrollBarTop"]
    local bottomTex = _G[scrollFrame:GetName() .. "ScrollBarBottom"]
    local midTex = _G[scrollFrame:GetName() .. "ScrollBarMiddle"]
    if topTex then topTex:Hide() end
    if bottomTex then bottomTex:Hide() end
    if midTex then midTex:Hide() end
    
    local thumb = scrollBar:GetThumbTexture()
    if thumb then
        thumb:SetTexture(addonTable.FLAT_TEX)
        thumb:SetVertexColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1) 
        thumb:SetSize(8, 60)
    end
    scrollBar:SetWidth(8)
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPRIGHT", OAK_LFG, "TOPRIGHT", -12, SCROLL_TOP_OFFSET - 1)
    scrollBar:SetPoint("BOTTOMRIGHT", OAK_LFG, "BOTTOMRIGHT", -12, 35)
end

local scrollChild = CreateFrame("Frame")
scrollChild:SetSize(scrollFrame:GetWidth(), 1)
scrollFrame:SetScrollChild(scrollChild)

local emptyStateText = scrollChild:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
emptyStateText:SetPoint("TOP", scrollChild, "TOP", 0, -80)
emptyStateText:SetWidth(420)
emptyStateText:SetJustifyH("CENTER")
emptyStateText:SetJustifyV("TOP")
emptyStateText:SetTextColor(0.78, 0.78, 0.78)
emptyStateText:Hide()

-- Browser mode: sticky panel that floats above the scroll area, holding applied (pending) groups
local stickyPanel = CreateFrame("Frame", nil, OAK_LFG, "BackdropTemplate")
stickyPanel:SetBackdrop({ bgFile = addonTable.FLAT_TEX })
stickyPanel:SetBackdropColor(unpack(addonTable.OAK_COLOR_STICKY or {0.05, 0.10, 0.05, 0.95}))
stickyPanel:SetFrameLevel(OAK_LFG:GetFrameLevel() + 5)
stickyPanel:Hide()
local stickyRows = {}
-- Separator line drawn below the sticky panel
local stickySeparatorLine = CreateFrame("Frame", nil, OAK_LFG)
stickySeparatorLine:SetHeight(2)
stickySeparatorLine:SetFrameLevel(OAK_LFG:GetFrameLevel() + 6)
local _ssLineTex = stickySeparatorLine:CreateTexture(nil, "OVERLAY")
_ssLineTex:SetAllPoints(stickySeparatorLine)
_ssLineTex:SetColorTexture(addonTable.ClassColor.r * (addonTable.OAK_COLOR_STICKY_ACCENT and addonTable.OAK_COLOR_STICKY_ACCENT[1] or 0.9), addonTable.ClassColor.g * (addonTable.OAK_COLOR_STICKY_ACCENT and addonTable.OAK_COLOR_STICKY_ACCENT[2] or 0.9), addonTable.ClassColor.b * (addonTable.OAK_COLOR_STICKY_ACCENT and addonTable.OAK_COLOR_STICKY_ACCENT[3] or 0.9), addonTable.OAK_COLOR_STICKY_ACCENT and addonTable.OAK_COLOR_STICKY_ACCENT[4] or 1.0)
stickySeparatorLine:Hide()
local stickyPanelHeight = 0

-- (kept for safety, no longer shown in browser mode since applied rows move to sticky panel)
local browserAppliedSeparator = CreateFrame("Frame", nil, scrollChild)
browserAppliedSeparator:SetHeight(3)
browserAppliedSeparator:SetFrameLevel(scrollChild:GetFrameLevel() + 20)
local _bsepTex = browserAppliedSeparator:CreateTexture(nil, "OVERLAY")
_bsepTex:SetAllPoints(browserAppliedSeparator)
_bsepTex:SetColorTexture(addonTable.ClassColor.r * (addonTable.OAK_COLOR_STICKY_ACCENT_SOFT and addonTable.OAK_COLOR_STICKY_ACCENT_SOFT[1] or 0.7), addonTable.ClassColor.g * (addonTable.OAK_COLOR_STICKY_ACCENT_SOFT and addonTable.OAK_COLOR_STICKY_ACCENT_SOFT[2] or 0.7), addonTable.ClassColor.b * (addonTable.OAK_COLOR_STICKY_ACCENT_SOFT and addonTable.OAK_COLOR_STICKY_ACCENT_SOFT[3] or 0.7), addonTable.OAK_COLOR_STICKY_ACCENT_SOFT and addonTable.OAK_COLOR_STICKY_ACCENT_SOFT[4] or 0.9)
browserAppliedSeparator:Hide()

local applicantContextBar = CreateFrame("Frame", nil, OAK_LFG, "BackdropTemplate")
applicantContextBar:SetPoint("TOPLEFT", OAK_LFG, "TOPLEFT", 1, -31)
applicantContextBar:SetPoint("TOPRIGHT", OAK_LFG, "TOPRIGHT", -1, -31)
applicantContextBar:SetHeight(APPLICANT_CONTEXT_BAR_HEIGHT)
applicantContextBar:SetBackdrop({ bgFile = addonTable.FLAT_TEX })
applicantContextBar:SetBackdropColor(unpack(addonTable.OAK_COLOR_CONTEXT or {0.08, 0.08, 0.10, 0.75}))
applicantContextBar:Hide()

local applicantListingTitle = applicantContextBar:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
applicantListingTitle:SetPoint("TOPLEFT", applicantContextBar, "TOPLEFT", 12, -2)
applicantListingTitle:SetPoint("TOPRIGHT", applicantContextBar, "TOPRIGHT", -12, -2)
applicantListingTitle:SetJustifyH("LEFT")
applicantListingTitle:SetJustifyV("TOP")
applicantListingTitle:SetWordWrap(false)

local applicantListingActivity = applicantContextBar:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
applicantListingActivity:SetPoint("BOTTOMLEFT", applicantContextBar, "BOTTOMLEFT", 12, 3)
applicantListingActivity:SetPoint("BOTTOMRIGHT", applicantContextBar, "BOTTOMRIGHT", -12, 3)
applicantListingActivity:SetJustifyH("LEFT")
applicantListingActivity:SetJustifyV("BOTTOM")
applicantListingActivity:SetTextColor(0.75, 0.75, 0.75)
applicantListingActivity:SetWordWrap(false)

local SCROLL_BOTTOM_APPLICANT = 35
local SCROLL_BOTTOM_BROWSER   = 60  -- extra room for the quick signup bar above the footer

local function GetThemeLayoutPad()
    return addonTable.GetThemeFramePadding and addonTable.GetThemeFramePadding() or 0
end

local function ApplyApplicantContextInsets()
    local pad = GetThemeLayoutPad()
    applicantContextBar:ClearAllPoints()
    applicantContextBar:SetPoint("TOPLEFT", OAK_LFG, "TOPLEFT", 1 + pad, -31 - pad)
    applicantContextBar:SetPoint("TOPRIGHT", OAK_LFG, "TOPRIGHT", -1 - pad, -31 - pad)
end
ApplyApplicantContextInsets()

local function UpdateApplicantContextLayout()
    local contextVisible = applicantContextBar:IsShown()
    local pad = GetThemeLayoutPad()
    HEADER_TOP_OFFSET = (contextVisible and (BASE_HEADER_TOP_OFFSET - APPLICANT_CONTEXT_BAR_HEIGHT) or BASE_HEADER_TOP_OFFSET) - pad
    SCROLL_TOP_OFFSET = (contextVisible and (BASE_SCROLL_TOP_OFFSET - APPLICANT_CONTEXT_BAR_HEIGHT) or BASE_SCROLL_TOP_OFFSET) - pad

    local isBrowser = addonTable.GetCurrentViewMode and addonTable.GetCurrentViewMode() == "browser"
    local bottomOffset = (isBrowser and SCROLL_BOTTOM_BROWSER or SCROLL_BOTTOM_APPLICANT) + pad

    -- Sticky panel: shown above scroll area when there are applied groups in browser mode
    local hasStickyRows = isBrowser and stickyPanelHeight > 0
    if hasStickyRows then
        stickyPanel:ClearAllPoints()
        stickyPanel:SetPoint("TOPLEFT", OAK_LFG, "TOPLEFT", 10 + pad, SCROLL_TOP_OFFSET)
        stickyPanel:SetPoint("RIGHT", OAK_LFG, "RIGHT", -25 - pad, 0)
        stickyPanel:SetHeight(stickyPanelHeight)
        stickyPanel:Show()
        stickySeparatorLine:ClearAllPoints()
        stickySeparatorLine:SetPoint("TOPLEFT", OAK_LFG, "TOPLEFT", 10 + pad, SCROLL_TOP_OFFSET - stickyPanelHeight)
        stickySeparatorLine:SetPoint("RIGHT", OAK_LFG, "RIGHT", -25 - pad, 0)
        stickySeparatorLine:Show()
    else
        stickyPanel:Hide()
        stickySeparatorLine:Hide()
    end

    -- Push scroll area down past the sticky panel (+ 2px for the separator line)
    local stickyOffset = hasStickyRows and (stickyPanelHeight + 2) or 0
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", OAK_LFG, "TOPLEFT", 10 + pad, SCROLL_TOP_OFFSET - stickyOffset)
    scrollFrame:SetPoint("BOTTOMRIGHT", OAK_LFG, "BOTTOMRIGHT", -25 - pad, bottomOffset)
end

local function UpdateApplicantContextBar()
    local isApplicantMode = not IsBrowserMode()
    local listingContext = addonTable.UpdateListingContext and addonTable.UpdateListingContext() or addonTable.CurrentListingContext
    local entryInfo = listingContext and listingContext.entryInfo or nil
    local activityInfo = listingContext and listingContext.activityInfo or nil

    local titleText = tostring((entryInfo and entryInfo.name) or "")
    local activityText = tostring((activityInfo and (activityInfo.fullName or activityInfo.shortName)) or "")

    local shouldShow = isApplicantMode and (titleText ~= "" or activityText ~= "")
    if shouldShow then
        applicantListingTitle:SetText(titleText ~= "" and titleText or "Current Listing")
        applicantListingActivity:SetText(activityText)
        applicantContextBar:Show()
    else
        applicantContextBar:Hide()
    end

    UpdateApplicantContextLayout()
end

local function GetTargetFrameWidth()
    local savedWidth = OakLFGSorterDB and tonumber(OakLFGSorterDB.windowWidth)
    if IsBrowserMode() then
        local minWidth = (OakLFGSorterDB and OakLFGSorterDB.hideNotes) and BROWSER_COLLAPSED_WIDTH or FULL_FRAME_WIDTH
        if savedWidth and savedWidth > minWidth then
            return math.min(MAX_FRAME_WIDTH, savedWidth)
        end
        return math.max(minWidth, BROWSER_DEFAULT_WIDTH)
    end

    if savedWidth and savedWidth > 0 then
        local minWidth = (OakLFGSorterDB and OakLFGSorterDB.hideNotes) and COLLAPSED_FRAME_WIDTH or FULL_FRAME_WIDTH
        return math.max(minWidth, math.min(MAX_FRAME_WIDTH, savedWidth))
    end

    if OakLFGSorterDB and OakLFGSorterDB.hideNotes then
        return math.max(COLLAPSED_FRAME_WIDTH, BROWSER_DEFAULT_WIDTH)
    end
    return FULL_FRAME_WIDTH
end
addonTable.GetTargetFrameWidth = GetTargetFrameWidth

OAK_LFG:SetScript("OnSizeChanged", function(self, width, height)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    local targetWidth = GetTargetFrameWidth()
    if not IsBrowserMode() and math.abs(width - targetWidth) > 0.5 then
        self:SetWidth(targetWidth)
        return
    end

    if IsBrowserMode() then
        if OakLFGSorterDB then
            OakLFGSorterDB.windowWidth = math.floor((width or 0) + 0.5)
        end
        RefreshBrowserResponsiveLayout()
    end
end)

do
local footer = CreateFrame("Frame", nil, OAK_LFG)
footer:SetHeight(20)
addonTable.Footer = footer
local function ApplyFooterInsets()
    local pad = GetThemeLayoutPad()
    footer:ClearAllPoints()
    local bottomPad = 10
    if pad > 0 then
        bottomPad = 6
    end
    footer:SetPoint("BOTTOMLEFT", OAK_LFG, "BOTTOMLEFT", 10 + pad, bottomPad)
    footer:SetPoint("BOTTOMRIGHT", OAK_LFG, "BOTTOMRIGHT", -10 - pad, bottomPad)
end
ApplyFooterInsets()

local function GetFooterButtonYOffset()
    if GetThemeLayoutPad() > 0 then
        return 2
    end
    return 0
end

local lustText = footer:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
lustText:SetPoint("LEFT", footer, "LEFT", 0, 0)
local brezText = footer:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
brezText:SetPoint("LEFT", lustText, "RIGHT", 10, 0)

-- Browser mode: "Showing X of Y groups" replaces lust/brez indicators
local groupCountText = footer:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
groupCountText:SetPoint("LEFT", footer, "LEFT", 2, 0)
groupCountText:SetTextColor(0.75, 0.75, 0.75)
groupCountText:Hide()
addonTable.groupCountText = groupCountText

local lfgBtn = addonTable.CreateFlatButton(footer, "LFG", 40)
lfgBtn.isBrowserFooterControl = true
lfgBtn:SetAutoWidth(32, 50, 10)
lfgBtn:SetScript("OnClick", function()
    if addonTable.OpenBlizzardFinderPanel then
        addonTable.OpenBlizzardFinderPanel("dungeon")
    end
end)
lfgBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Open Blizzard Dungeon Finder", 1, 1, 1)
    GameTooltip:Show()
end)
lfgBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(0, 0, 0, 1)
    GameTooltip:Hide()
end)

local lfrBtn = addonTable.CreateFlatButton(footer, "LFR", 40)
lfrBtn.isBrowserFooterControl = true
lfrBtn:SetAutoWidth(32, 50, 10)
lfrBtn:SetScript("OnClick", function()
    if addonTable.OpenBlizzardFinderPanel then
        addonTable.OpenBlizzardFinderPanel("raid")
    end
end)
lfrBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Open Blizzard Raid Finder", 1, 1, 1)
    GameTooltip:Show()
end)
lfrBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(0, 0, 0, 1)
    GameTooltip:Hide()
end)

local suppBtn = addonTable.CreateFlatButton(footer, L["Supporters & Links"], 150)
suppBtn:SetAutoWidth(110, 156, 10)
suppBtn:SetPoint("CENTER", footer, "CENTER", 18, GetFooterButtonYOffset())
lfrBtn:SetPoint("RIGHT", suppBtn, "LEFT", -2, 0)
lfgBtn:SetPoint("RIGHT", lfrBtn, "LEFT", -2, 0)
suppBtn:SetScript("OnClick", function()
    if addonTable.SupportersPanel:IsShown() then
        addonTable.SupportersPanel:Hide()
    else
        if addonTable.FilterPanel then addonTable.FilterPanel:Hide() end
        if addonTable.BrowserFilterPanel then addonTable.BrowserFilterPanel:Hide() end
        if addonTable.OptionsPanel then addonTable.OptionsPanel:Hide() end
        addonTable.SupportersPanel:Show()
    end
    if addonTable.AnchorRIOPanelToOak then
        addonTable.AnchorRIOPanelToOak(addonTable.OAK_LFG)
    end
end)

local optionsBtn = addonTable.CreateCogButton(footer, 22)
optionsBtn:SetPoint("LEFT", suppBtn, "RIGHT", 3, 0)
optionsBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Options", 1, 1, 1)
    GameTooltip:AddLine("Open shared Oak display options.", 1, 1, 1, true)
    GameTooltip:Show()
end)
optionsBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(0, 0, 0, 1)
    GameTooltip:Hide()
end)
optionsBtn:SetScript("OnClick", function()
    if addonTable.ToggleOptionsPanel then
        addonTable.ToggleOptionsPanel()
    end
end)

local listBtn = addonTable.CreateFlatButton(footer, "List", 42)
listBtn.isBrowserFooterControl = true
listBtn:SetAutoWidth(34, 50, 10)
listBtn:SetPoint("LEFT", optionsBtn, "RIGHT", 3, 0)
listBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Open Blizzard Listing Panel", 1, 1, 1)
    GameTooltip:AddLine("Choose a listing category and open Blizzard's native listing flow for that category.", 1, 1, 1, true)
    GameTooltip:Show()
end)
listBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(0, 0, 0, 1)
    GameTooltip:Hide()
end)

local pvpBtn = addonTable.CreateFlatButton(footer, "PVP", 42)
pvpBtn.isBrowserFooterControl = true
pvpBtn:SetAutoWidth(34, 50, 10)
pvpBtn:SetPoint("LEFT", listBtn, "RIGHT", 2, 0)
pvpBtn:SetScript("OnClick", function()
    if addonTable.OpenBlizzardFinderPanel then
        addonTable.OpenBlizzardFinderPanel("pvp")
    end
end)
pvpBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Open Blizzard PVP Panel", 1, 1, 1)
    GameTooltip:AddLine("Open Blizzard's native Player vs. Player panel.", 1, 1, 1, true)
    GameTooltip:Show()
end)
pvpBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(0, 0, 0, 1)
    GameTooltip:Hide()
end)

local listDropdown = CreateFrame("Frame", nil, footer, "BackdropTemplate")
addonTable.ApplyBackdropStyle(listDropdown, "panel")
listDropdown:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
listDropdown:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
listDropdown:SetFrameStrata("FULLSCREEN_DIALOG")
listDropdown:SetClampedToScreen(true)
listDropdown:Hide()

local listDropdownButtons = {}
local listDropdownOrder = {
    "DUNGEONS",
    "RAIDS_MIDNIGHT",
    "RAIDS_LEGACY",
    "DELVES",
    "QUESTING",
    "CUSTOM",
}

local function GetListingDropdownOptions()
    local options = {}
    for _, id in ipairs(listDropdownOrder) do
        local config = addonTable.GetBrowserCategoryConfig and addonTable.GetBrowserCategoryConfig(id)
        if config and not config.separator then
            table.insert(options, config)
        end
    end
    return options
end

local function RefreshListingDropdown()
    local options = GetListingDropdownOptions()
    local width = 150
    local rowHeight = 22
    listDropdown:SetSize(width + 2, (#options * rowHeight) + 2)

    for _, button in ipairs(listDropdownButtons) do
        button:Hide()
    end

    for index, option in ipairs(options) do
        local button = listDropdownButtons[index]
        if not button then
            button = CreateFrame("Button", nil, listDropdown, "BackdropTemplate")
            button.bg = button:CreateTexture(nil, "BACKGROUND")
            button.bg:SetAllPoints()
            button.text = button:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
            button.text:SetPoint("LEFT", button, "LEFT", 8, 0)
            button.text:SetPoint("RIGHT", button, "RIGHT", -8, 0)
            button.text:SetJustifyH("LEFT")
            listDropdownButtons[index] = button
        end

        button.optionID = option.id
        button:SetPoint("TOPLEFT", listDropdown, "TOPLEFT", 1, -1 - ((index - 1) * rowHeight))
        button:SetSize(width, rowHeight)
        button.bg:SetColorTexture(unpack(addonTable.OAK_COLOR_BG))
        button.text:SetText(option.label)
        button.text:SetTextColor(1, 1, 1, 1)
        button:SetScript("OnEnter", function(self)
            self.bg:SetColorTexture(unpack(addonTable.OAK_COLOR_DROPDOWN_HOVER))
        end)
        button:SetScript("OnLeave", function(self)
            self.bg:SetColorTexture(unpack(addonTable.OAK_COLOR_BG))
        end)
        button:SetScript("OnClick", function(self)
            listDropdown:Hide()
            if addonTable.OpenBlizzardListingPanel then
                addonTable.OpenBlizzardListingPanel(self.optionID)
            end
        end)
        button:Show()
    end
end

listBtn:SetScript("OnClick", function(self)
    RefreshListingDropdown()
    if listDropdown:IsShown() then
        listDropdown:Hide()
        return
    end

    listDropdown:ClearAllPoints()
    listDropdown:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 2)
    listDropdown:Show()
end)

addonTable.RegisterThemeRefresh("listing_dropdown_theme", function()
    listDropdown:SetBackdropColor(unpack(addonTable.OAK_COLOR_BG))
    listDropdown:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    if listDropdown:IsShown() then
        RefreshListingDropdown()
    end
end)

local footerVersionText = footer:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
footerVersionText:SetPoint("RIGHT", footer, "RIGHT", -2, 0)
footerVersionText:SetText(addonTable.VersionText and addonTable.VersionText:GetText() or "")

local mythicPanelBtn = addonTable.CreateFlatButton(footer, "M+", 40)
mythicPanelBtn:SetAutoWidth(28, 42, 8)
mythicPanelBtn:SetPoint("RIGHT", suppBtn, "LEFT", -2, 0)
lfrBtn:ClearAllPoints()
lfrBtn:SetPoint("RIGHT", mythicPanelBtn, "LEFT", -2, 0)
lfgBtn:ClearAllPoints()
lfgBtn:SetPoint("RIGHT", lfrBtn, "LEFT", -2, 0)
mythicPanelBtn:SetScript("OnClick", function()
    if addonTable.ToggleMythicPlusPanel then
        addonTable.ToggleMythicPlusPanel()
    end
end)
mythicPanelBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Mythic+ Overview", 1, 1, 1)
    GameTooltip:AddLine("Open your condensed Mythic+ score, dungeon, affix, and vault panel.", 1, 1, 1, true)
    GameTooltip:Show()
end)
mythicPanelBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(0, 0, 0, 1)
    GameTooltip:Hide()
end)

local function RefreshFooterButtonWidths()
    if lfgBtn.RefreshAutoWidth then lfgBtn:RefreshAutoWidth() end
    if lfrBtn.RefreshAutoWidth then lfrBtn:RefreshAutoWidth() end
    if suppBtn.RefreshAutoWidth then suppBtn:RefreshAutoWidth() end
    if listBtn.RefreshAutoWidth then listBtn:RefreshAutoWidth() end
    if pvpBtn.RefreshAutoWidth then pvpBtn:RefreshAutoWidth() end
    if mythicPanelBtn.RefreshAutoWidth then mythicPanelBtn:RefreshAutoWidth() end
end
addonTable.RefreshFooterButtonWidths = RefreshFooterButtonWidths

local function UpdateFooterActionVisibility()
    local isBrowser = IsBrowserMode()
    local hasActiveListing = C_LFGList and C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo()
    if isBrowser then
        lfgBtn:Show()
        lfrBtn:Show()
        mythicPanelBtn:Show()
        listBtn:Show()
        pvpBtn:Show()
    else
        lfgBtn:Hide()
        lfrBtn:Hide()
        mythicPanelBtn:Show()
        listBtn:Hide()
        pvpBtn:Hide()
        if listDropdown then
            listDropdown:Hide()
        end
    end
end
addonTable.UpdateFooterActionVisibility = UpdateFooterActionVisibility
UpdateFooterActionVisibility()
RefreshFooterButtonWidths()

function addonTable.UpdateGroupBuffs()
    local isBrowser = IsBrowserMode()
    UpdateFooterActionVisibility()

    if isBrowser then
        -- Browser mode: show group count, hide lust/brez indicators
        lustText:Hide()
        brezText:Hide()
        groupCountText:Show()
        return
    end

    -- Applicant mode: show lust/brez indicators, hide group count
    groupCountText:Hide()
    lustText:Show()
    brezText:Show()

    local hasLust, hasBrez = false, false
    local function CheckClass(c)
        if not c then return end
        c = string.upper(c)
        if c == "MAGE" or c == "SHAMAN" or c == "HUNTER" or c == "EVOKER" then hasLust = true end
        if c == "DEATHKNIGHT" or c == "DRUID" or c == "WARLOCK" or c == "PALADIN" then hasBrez = true end
    end

    CheckClass(addonTable.PlayerClass)

    local numGroup = GetNumGroupMembers()
    for i = 1, numGroup do
        local unit = IsInRaid() and "raid"..i or "party"..i
        if not UnitIsUnit(unit, "player") then
            local _, uClass = UnitClass(unit)
            CheckClass(uClass)
        end
    end
    if hasLust then lustText:SetText("|cFF55FF55|TInterface\\Icons\\spell_nature_bloodlust:13|t Lust Covered|r")
    else lustText:SetText("|cFFFF5555|TInterface\\Icons\\spell_nature_bloodlust:13|t Need Lust|r") end
    if hasBrez then brezText:SetText("|cFF55FF55|TInterface\\Icons\\spell_holy_resurrection:13|t B-Rez Covered|r")
    else brezText:SetText("|cFFFF5555|TInterface\\Icons\\spell_holy_resurrection:13|t Need B-Rez|r") end
end
end

local function SortGroups(grpA, grpB, sortBy, isAscending)
    local valA, valB
    local listingMode = GetListingMode()
    local isBrowser = IsBrowserMode()

    if isBrowser then
        if sortBy == "role" then valA, valB = grpA.dungeonName or grpA.activityFilterLabel or grpA.activityName or "", grpB.dungeonName or grpB.activityFilterLabel or grpB.activityName or ""
        elseif sortBy == "region" then
            valA = addonTable.GetRegionSortKey and addonTable.GetRegionSortKey(grpA.regionInfo) or "zzz_other"
            valB = addonTable.GetRegionSortKey and addonTable.GetRegionSortKey(grpB.regionInfo) or "zzz_other"
        elseif sortBy == "class" then valA, valB = grpA.displayName or grpA.name or "", grpB.displayName or grpB.name or ""
        elseif sortBy == "spec" then valA, valB = grpA.playstyleShortLabel or "", grpB.playstyleShortLabel or ""
        elseif sortBy == "ilvl" then
            local aCounts = grpA.roleCounts or {}
            local bCounts = grpB.roleCounts or {}
            valA = ((aCounts.TANK or 0) * 100) + ((aCounts.HEALER or 0) * 10) + (aCounts.DAMAGER or 0)
            valB = ((bCounts.TANK or 0) * 100) + ((bCounts.HEALER or 0) * 10) + (bCounts.DAMAGER or 0)
        elseif sortBy == "rating" then
            if listingMode == "raid" or listingMode == "legacy_raid" then
                -- Sort by actual boss kills shown in the Kills column
                valA = tonumber(grpA.raidListing and grpA.raidListing.bossesKilled) or 0
                valB = tonumber(grpB.raidListing and grpB.raidListing.bossesKilled) or 0
            else
                valA, valB = grpA.rating or 0, grpB.rating or 0
            end
        elseif sortBy == "key" then
            -- In browser mode "key" header is repurposed as "Age"
            valA, valB = grpA.age or 0, grpB.age or 0
        elseif sortBy == "note" then valA, valB = grpA.comment or "", grpB.comment or "" end
    else
        if sortBy == "role" then valA, valB = roleWeights[grpA.leadRole] or 99, roleWeights[grpB.leadRole] or 99
        elseif sortBy == "region" then
            valA = addonTable.GetRegionSortKey and addonTable.GetRegionSortKey(grpA.regionInfo) or "zzz_other"
            valB = addonTable.GetRegionSortKey and addonTable.GetRegionSortKey(grpB.regionInfo) or "zzz_other"
        elseif sortBy == "class" then valA, valB = grpA.leadClass, grpB.leadClass
        elseif sortBy == "spec" then 
            valA = addonTable.SpecShortNames[grpA.leadSpec] or tostring(grpA.leadSpec or "")
            valB = addonTable.SpecShortNames[grpB.leadSpec] or tostring(grpB.leadSpec or "")
        elseif sortBy == "ilvl" then valA, valB = grpA.leadIlvl, grpB.leadIlvl
        elseif sortBy == "rating" then
            if listingMode == "rated_pvp" or listingMode == "pvp" then
                valA, valB = grpA.leadPvpRating or 0, grpB.leadPvpRating or 0
            elseif listingMode == "raid" or listingMode == "legacy_raid" then
                valA = (grpA.leadRaidProgress and grpA.leadRaidProgress.sortValue) or 0
                valB = (grpB.leadRaidProgress and grpB.leadRaidProgress.sortValue) or 0
            else
                valA, valB = grpA.leadRating, grpB.leadRating
            end
        elseif sortBy == "key" then
            if listingMode == "rated_pvp" or listingMode == "pvp" then
                valA, valB = grpA.leadPvpBracket or "", grpB.leadPvpBracket or ""
            elseif listingMode == "raid" or listingMode == "legacy_raid" then
                valA = (grpA.leadRaidProgress and grpA.leadRaidProgress.raidName) or ""
                valB = (grpB.leadRaidProgress and grpB.leadRaidProgress.raidName) or ""
            else
                valA, valB = grpA.leadKey, grpB.leadKey
            end
        elseif sortBy == "note" then valA, valB = grpA.comment or "", grpB.comment or "" end
    end

    if isBrowser then
        local priorityA, priorityB = GetBrowserApplicationPriority(grpA), GetBrowserApplicationPriority(grpB)
        if priorityA ~= priorityB then
            return priorityA > priorityB
        end
        if valA ~= valB then
            if isAscending then return valA < valB else return valA > valB end
        end
        if grpA.rating ~= grpB.rating then
            if isAscending then return grpA.rating < grpB.rating else return grpA.rating > grpB.rating end
        end
        if isAscending then return grpA.id < grpB.id else return grpA.id > grpB.id end
    end

    if valA ~= valB then
        if isAscending then return valA < valB else return valA > valB end
    end
    if grpA.leadIlvl ~= grpB.leadIlvl then 
        if isAscending then return grpA.leadIlvl < grpB.leadIlvl else return grpA.leadIlvl > grpB.leadIlvl end
    end
    if grpA.leadRating ~= grpB.leadRating then 
        if isAscending then return grpA.leadRating < grpB.leadRating else return grpA.leadRating > grpB.leadRating end
    end
    if isAscending then return grpA.id < grpB.id else return grpA.id > grpB.id end
end

-- Master Column Coordinates
local C_ROLE   = { x = 10,  w = 35,  align = "CENTER" }
local C_CLASS  = { x = 45,  w = 132, align = "LEFT" }
local C_SPEC   = { x = 177, w = 38,  align = "CENTER" }
local C_ILVL   = { x = 215, w = 40,  align = "CENTER" }
local C_RATING = { x = 255, w = 74,  align = "CENTER" }
local C_KEY    = { x = 329, w = 40,  align = "CENTER" }
local C_NOTE   = { x = 369, w = 201, align = "LEFT" }
local B_DUNGEON = { x = 10,  w = 145, align = "LEFT" }    -- [10,  155]
local B_DUNGEON_REGION_SPLIT = { x = 10,  w = 121, align = "LEFT" }
local B_COMP    = { x = 155, w = 103, align = "CENTER" }   -- [155, 258]  comp slot icons
local B_TITLE   = { x = 258, w = 102, align = "LEFT" }     -- [258, 360]  listing title
local B_RATING  = { x = 360, w = 70,  align = "CENTER" }   -- [360, 430]
local B_AGE     = { x = 430, w = 45,  align = "CENTER" }   -- [430, 475]
local B_NOTE    = { x = 475, w = 130, align = "LEFT" }     -- [475, 605]
-- PVP browser column constants (Arena 2v2/3v3): Arena | Comp | Title | PVP Rating | Age | Notes
local B_PVP_ARENA  = { x = 10,  w = 88,  align = "LEFT"   }  -- [10,  98]  "2v2" / "3v3" + region tag
local B_PVP_ARENA_REGION_SPLIT  = { x = 10,  w = 64,  align = "LEFT"   }
local B_PVP_COMP   = { x = 98,  w = 72,  align = "CENTER" }  -- [98,  170] max 3 spec slots
local B_PVP_TITLE  = { x = 170, w = 120, align = "LEFT"   }  -- [170, 290] listing title
local B_PVP_RATING = { x = 290, w = 80,  align = "CENTER" }  -- [290, 370]
local B_PVP_AGE    = { x = 370, w = 45,  align = "CENTER" }  -- [370, 415]
local B_PVP_NOTE   = { x = 415, w = 190, align = "LEFT"   }  -- [415, 605]
local B_RBG_ACTIVITY = { x = 10,  w = 88,  align = "LEFT"   }
local B_RBG_ACTIVITY_REGION_SPLIT = { x = 10,  w = 64,  align = "LEFT"   }
local B_RBG_COMP     = { x = 98,  w = 96,  align = "CENTER" }
local B_RBG_TITLE    = { x = 194, w = 96,  align = "LEFT"   }
local B_RBG_RATING   = { x = 290, w = 80,  align = "CENTER" }
local B_RBG_AGE      = { x = 370, w = 45,  align = "CENTER" }
local B_RBG_NOTE     = { x = 415, w = 190, align = "LEFT"   }
local ROW_X_OFFSET = 10
local REGION_TAG_WIDTH = 24
local REGION_COLUMNS = {
    applicant = { x = 149, w = 28, align = "CENTER" },
    browser = { x = 131, w = REGION_TAG_WIDTH, align = "CENTER" },
    pvp = { x = 74, w = REGION_TAG_WIDTH, align = "CENTER" },
    rbg = { x = 74, w = REGION_TAG_WIDTH, align = "CENTER" },
    raid = { x = 106, w = REGION_TAG_WIDTH, align = "CENTER" },
}

local function RowColumn(column)
    return { x = column.x - ROW_X_OFFSET, w = column.w, align = column.align }
end

local R_ROLE   = RowColumn(C_ROLE)
local R_CLASS  = RowColumn(C_CLASS)
local R_SPEC   = RowColumn(C_SPEC)
local R_ILVL   = RowColumn(C_ILVL)
local R_RATING = RowColumn(C_RATING)
local R_KEY    = RowColumn(C_KEY)
local R_NOTE   = RowColumn(C_NOTE)
local BR_DUNGEON = RowColumn(B_DUNGEON)
local BR_COMP    = RowColumn(B_COMP)
local BR_TITLE   = RowColumn(B_TITLE)
local BR_RATING  = RowColumn(B_RATING)
local BR_AGE     = RowColumn(B_AGE)
local BR_NOTE    = RowColumn(B_NOTE)
local BR_PVP_ARENA  = RowColumn(B_PVP_ARENA)
local BR_PVP_COMP   = RowColumn(B_PVP_COMP)
local BR_PVP_TITLE  = RowColumn(B_PVP_TITLE)
local BR_PVP_RATING = RowColumn(B_PVP_RATING)
local BR_PVP_AGE    = RowColumn(B_PVP_AGE)
local BR_PVP_NOTE   = RowColumn(B_PVP_NOTE)
local BR_RBG_ACTIVITY = RowColumn(B_RBG_ACTIVITY)
local BR_RBG_COMP     = RowColumn(B_RBG_COMP)
local BR_RBG_TITLE    = RowColumn(B_RBG_TITLE)
local BR_RBG_RATING   = RowColumn(B_RBG_RATING)
local BR_RBG_AGE      = RowColumn(B_RBG_AGE)
local BR_RBG_NOTE     = RowColumn(B_RBG_NOTE)

-- Raid browser column constants: Raid | Difficulty | Comp | Title | Kills | Age | Notes
local B_RAID_NAME  = { x = 10,  w = 120, align = "LEFT"   }  -- [10,  130]
local B_RAID_NAME_REGION_SPLIT  = { x = 10,  w = 96, align = "LEFT"   }
local B_RAID_DIFF  = { x = 130, w = 65,  align = "CENTER" }  -- [130, 195]
local B_RAID_COMP  = { x = 195, w = 103, align = "CENTER" }  -- [195, 298]
local B_RAID_TITLE = { x = 298, w = 107, align = "LEFT"   }  -- [298, 405]
local B_RAID_KILLS = { x = 405, w = 50,  align = "CENTER" }  -- [405, 455]
local B_RAID_AGE   = { x = 455, w = 45,  align = "CENTER" }  -- [455, 500]
local B_RAID_NOTE  = { x = 500, w = 105, align = "LEFT"   }  -- [500, 605]
local B_RAID_TITLE_COLLAPSED = { x = 298, w = 95, align = "LEFT"   }  -- [298, 393]
local B_RAID_KILLS_COLLAPSED = { x = 393, w = 42, align = "CENTER" }  -- [393, 435]
local B_RAID_AGE_COLLAPSED   = { x = 435, w = 34, align = "CENTER" }  -- [435, 469]
local B_RAID_NOTE_COLLAPSED  = { x = 469, w = 31, align = "LEFT"   }  -- [469, 500]
local BR_RAID_NAME  = RowColumn(B_RAID_NAME)
local BR_RAID_DIFF  = RowColumn(B_RAID_DIFF)
local BR_RAID_COMP  = RowColumn(B_RAID_COMP)
local BR_RAID_TITLE = RowColumn(B_RAID_TITLE)
local BR_RAID_KILLS = RowColumn(B_RAID_KILLS)
local BR_RAID_AGE   = RowColumn(B_RAID_AGE)
local BR_RAID_NOTE  = RowColumn(B_RAID_NOTE)
local BR_RAID_TITLE_COLLAPSED = RowColumn(B_RAID_TITLE_COLLAPSED)
local BR_RAID_KILLS_COLLAPSED = RowColumn(B_RAID_KILLS_COLLAPSED)
local BR_RAID_AGE_COLLAPSED   = RowColumn(B_RAID_AGE_COLLAPSED)
local BR_RAID_NOTE_COLLAPSED  = RowColumn(B_RAID_NOTE_COLLAPSED)

local function CopyColumn(column)
    return { x = column.x, w = column.w, align = column.align }
end

local function GetBrowserWidthDelta()
    if not IsBrowserMode() then
        return 0
    end

    local minWidth = (OakLFGSorterDB and OakLFGSorterDB.hideNotes) and BROWSER_COLLAPSED_WIDTH or FULL_FRAME_WIDTH
    local currentWidth = tonumber(OAK_LFG and OAK_LFG:GetWidth()) or minWidth
    return math.max(0, math.floor(currentWidth - minWidth + 0.5))
end

local function MeasureDungeonColumnWidth()
    if not IsBrowserMode() or not addonTable.MeasureBrowserTextWidth then
        return B_DUNGEON.w
    end

    local widest = B_DUNGEON.w
    local fontObject = _G["OakLFG_FontSmall"]
    local labels = {}

    for _, entry in ipairs(addonTable.GetAvailableBrowserActivities and addonTable.GetAvailableBrowserActivities() or {}) do
        local label = tostring(entry and entry.label or "")
        if label ~= "" then
            labels[label] = true
        end
    end

    for _, result in ipairs(addonTable.SearchResults or {}) do
        local label = tostring(result and (result.dungeonName or result.activityFilterLabel or result.activityName) or "")
        if label ~= "" then
            labels[label] = true
        end
    end

    for label in pairs(labels) do
        widest = math.max(widest, addonTable.MeasureBrowserTextWidth(label, fontObject) + 14)
    end

    if addonTable.ShouldShowRegions and addonTable.ShouldShowRegions() then
        widest = widest + REGION_TAG_WIDTH + 6
    end

    return math.min(260, widest)
end

local function GetExpandedBrowserColumns()
    local extra = GetBrowserWidthDelta()
    local cols = {
        dungeon = CopyColumn(B_DUNGEON),
        dungeonRegionSplit = CopyColumn(B_DUNGEON_REGION_SPLIT),
        comp = CopyColumn(B_COMP),
        title = CopyColumn(B_TITLE),
        rating = CopyColumn(B_RATING),
        age = CopyColumn(B_AGE),
        note = CopyColumn(B_NOTE),
        pvpArena = CopyColumn(B_PVP_ARENA),
        pvpArenaRegionSplit = CopyColumn(B_PVP_ARENA_REGION_SPLIT),
        pvpComp = CopyColumn(B_PVP_COMP),
        pvpTitle = CopyColumn(B_PVP_TITLE),
        pvpRating = CopyColumn(B_PVP_RATING),
        pvpAge = CopyColumn(B_PVP_AGE),
        pvpNote = CopyColumn(B_PVP_NOTE),
        rbgActivity = CopyColumn(B_RBG_ACTIVITY),
        rbgActivityRegionSplit = CopyColumn(B_RBG_ACTIVITY_REGION_SPLIT),
        rbgComp = CopyColumn(B_RBG_COMP),
        rbgTitle = CopyColumn(B_RBG_TITLE),
        rbgRating = CopyColumn(B_RBG_RATING),
        rbgAge = CopyColumn(B_RBG_AGE),
        rbgNote = CopyColumn(B_RBG_NOTE),
        raidName = CopyColumn(B_RAID_NAME),
        raidNameRegionSplit = CopyColumn(B_RAID_NAME_REGION_SPLIT),
        raidDiff = CopyColumn(B_RAID_DIFF),
        raidComp = CopyColumn(B_RAID_COMP),
        raidTitle = CopyColumn(B_RAID_TITLE),
        raidKills = CopyColumn(B_RAID_KILLS),
        raidAge = CopyColumn(B_RAID_AGE),
        raidNote = CopyColumn(B_RAID_NOTE),
        raidTitleCollapsed = CopyColumn(B_RAID_TITLE_COLLAPSED),
        raidKillsCollapsed = CopyColumn(B_RAID_KILLS_COLLAPSED),
        raidAgeCollapsed = CopyColumn(B_RAID_AGE_COLLAPSED),
        raidNoteCollapsed = CopyColumn(B_RAID_NOTE_COLLAPSED),
    }

    if extra <= 0 then
        return cols
    end

    local dungeonGrow = 0
    local desiredDungeonWidth = MeasureDungeonColumnWidth()
    if desiredDungeonWidth > cols.dungeon.w then
        dungeonGrow = math.min(extra, desiredDungeonWidth - cols.dungeon.w)
        cols.dungeon.w = cols.dungeon.w + dungeonGrow
        cols.dungeonRegionSplit.w = cols.dungeonRegionSplit.w + dungeonGrow
        cols.comp.x = cols.comp.x + dungeonGrow
        cols.title.x = cols.title.x + dungeonGrow
        cols.rating.x = cols.rating.x + dungeonGrow
        cols.age.x = cols.age.x + dungeonGrow
        cols.note.x = cols.note.x + dungeonGrow

        cols.pvpArena.w = cols.pvpArena.w + dungeonGrow
        cols.pvpArenaRegionSplit.w = cols.pvpArenaRegionSplit.w + dungeonGrow
        cols.pvpComp.x = cols.pvpComp.x + dungeonGrow
        cols.pvpTitle.x = cols.pvpTitle.x + dungeonGrow
        cols.pvpRating.x = cols.pvpRating.x + dungeonGrow
        cols.pvpAge.x = cols.pvpAge.x + dungeonGrow
        cols.pvpNote.x = cols.pvpNote.x + dungeonGrow

        cols.rbgActivity.w = cols.rbgActivity.w + dungeonGrow
        cols.rbgActivityRegionSplit.w = cols.rbgActivityRegionSplit.w + dungeonGrow
        cols.rbgComp.x = cols.rbgComp.x + dungeonGrow
        cols.rbgTitle.x = cols.rbgTitle.x + dungeonGrow
        cols.rbgRating.x = cols.rbgRating.x + dungeonGrow
        cols.rbgAge.x = cols.rbgAge.x + dungeonGrow
        cols.rbgNote.x = cols.rbgNote.x + dungeonGrow

        cols.raidName.w = cols.raidName.w + dungeonGrow
        cols.raidNameRegionSplit.w = cols.raidNameRegionSplit.w + dungeonGrow
        cols.raidDiff.x = cols.raidDiff.x + dungeonGrow
        cols.raidComp.x = cols.raidComp.x + dungeonGrow
        cols.raidTitle.x = cols.raidTitle.x + dungeonGrow
        cols.raidKills.x = cols.raidKills.x + dungeonGrow
        cols.raidAge.x = cols.raidAge.x + dungeonGrow
        cols.raidNote.x = cols.raidNote.x + dungeonGrow
        cols.raidTitleCollapsed.x = cols.raidTitleCollapsed.x + dungeonGrow
        cols.raidKillsCollapsed.x = cols.raidKillsCollapsed.x + dungeonGrow
        cols.raidAgeCollapsed.x = cols.raidAgeCollapsed.x + dungeonGrow
        cols.raidNoteCollapsed.x = cols.raidNoteCollapsed.x + dungeonGrow
    end

    extra = extra - dungeonGrow

    local function apply(baseTitle, titleShare)
        local titleGrow = math.floor(extra * titleShare + 0.5)
        local noteGrow = extra - titleGrow
        local afterTitleX = baseTitle.x + baseTitle.w + titleGrow
        return titleGrow, noteGrow, afterTitleX
    end

    do
        local titleGrow, noteGrow, afterTitleX = apply(B_TITLE, (OakLFGSorterDB and OakLFGSorterDB.hideNotes) and 1.0 or 0.4)
        cols.title.w = cols.title.w + titleGrow
        cols.rating.x = afterTitleX
        cols.age.x = cols.rating.x + cols.rating.w
        cols.note.x = cols.age.x + cols.age.w
        if not (OakLFGSorterDB and OakLFGSorterDB.hideNotes) then
            cols.note.w = cols.note.w + noteGrow
        end
    end

    do
        local titleGrow, noteGrow, afterTitleX = apply(B_PVP_TITLE, (OakLFGSorterDB and OakLFGSorterDB.hideNotes) and 1.0 or 0.45)
        cols.pvpTitle.w = cols.pvpTitle.w + titleGrow
        cols.pvpRating.x = afterTitleX
        cols.pvpAge.x = cols.pvpRating.x + cols.pvpRating.w
        cols.pvpNote.x = cols.pvpAge.x + cols.pvpAge.w
        if not (OakLFGSorterDB and OakLFGSorterDB.hideNotes) then
            cols.pvpNote.w = cols.pvpNote.w + noteGrow
        end
    end

    do
        local titleGrow, noteGrow, afterTitleX = apply(B_RBG_TITLE, (OakLFGSorterDB and OakLFGSorterDB.hideNotes) and 1.0 or 0.45)
        cols.rbgTitle.w = cols.rbgTitle.w + titleGrow
        cols.rbgRating.x = afterTitleX
        cols.rbgAge.x = cols.rbgRating.x + cols.rbgRating.w
        cols.rbgNote.x = cols.rbgAge.x + cols.rbgAge.w
        if not (OakLFGSorterDB and OakLFGSorterDB.hideNotes) then
            cols.rbgNote.w = cols.rbgNote.w + noteGrow
        end
    end

    do
        local titleGrow, noteGrow, afterTitleX = apply(B_RAID_TITLE, (OakLFGSorterDB and OakLFGSorterDB.hideNotes) and 1.0 or 0.45)
        cols.raidTitle.w = cols.raidTitle.w + titleGrow
        cols.raidKills.x = afterTitleX
        cols.raidAge.x = cols.raidKills.x + cols.raidKills.w
        cols.raidNote.x = cols.raidAge.x + cols.raidAge.w
        if not (OakLFGSorterDB and OakLFGSorterDB.hideNotes) then
            cols.raidNote.w = cols.raidNote.w + noteGrow
        end
    end

    do
        local titleGrow, noteGrow, afterTitleX = apply(B_RAID_TITLE_COLLAPSED, 1.0)
        cols.raidTitleCollapsed.w = cols.raidTitleCollapsed.w + titleGrow
        cols.raidKillsCollapsed.x = afterTitleX
        cols.raidAgeCollapsed.x = cols.raidKillsCollapsed.x + cols.raidKillsCollapsed.w
        cols.raidNoteCollapsed.x = cols.raidAgeCollapsed.x + cols.raidAgeCollapsed.w
        if not (OakLFGSorterDB and OakLFGSorterDB.hideNotes) then
            cols.raidNoteCollapsed.w = cols.raidNoteCollapsed.w + noteGrow
        end
    end

    return cols
end

local function GetCurrentBrowserColumns()
    return GetExpandedBrowserColumns()
end

-- File-scope comp slot sizing (also used in CreateRow and RepositionCompSlots)
local COMP_SLOT_SIZE    = 18
local COMP_SLOT_ICON    = 13
local COMP_SLOT_SPACING = 20
local COMP_TOTAL_SPAN   = (5 - 1) * COMP_SLOT_SPACING + COMP_SLOT_SIZE  -- 98px
-- PVP comp slots are slightly larger so spec icons are legible (3 slots max)
local COMP_SLOT_SIZE_PVP    = 22
local COMP_SLOT_ICON_PVP    = 17
local COMP_SLOT_SPACING_PVP = 26

-- Spec name → specID lookup built from all known TWW spec IDs.
-- Used as fallback when GetSearchResultPlayerInfo returns specName but not specID.
-- Some localized spec names are shared across classes (for example Frost),
-- so keep both a class-aware lookup and a unique-name fallback.
local KNOWN_SPEC_IDS = {
    62, 63, 64,            -- Mage: Arcane, Fire, Frost
    65, 66, 70,            -- Paladin: Holy, Protection, Retribution
    71, 72, 73,            -- Warrior: Arms, Fury, Protection
    102, 103, 104, 105,    -- Druid: Balance, Feral, Guardian, Restoration
    250, 251, 252,         -- Death Knight: Blood, Frost, Unholy
    253, 254, 255,         -- Hunter: Beast Mastery, Marksmanship, Survival
    256, 257, 258,         -- Priest: Discipline, Holy, Shadow
    259, 260, 261,         -- Rogue: Assassination, Outlaw, Subtlety
    262, 263, 264,         -- Shaman: Elemental, Enhancement, Restoration
    265, 266, 267,         -- Warlock: Affliction, Demonology, Destruction
    268, 269, 270,         -- Monk: Brewmaster, Windwalker, Mistweaver
    577, 581, 1480,        -- Demon Hunter: Havoc, Vengeance, Devourer
    1467, 1468, 1473,      -- Evoker: Devastation, Preservation, Augmentation
}
local specNameToID = {}
local specNameClassToID = {}
if GetSpecializationInfoByID then
    for _, id in ipairs(KNOWN_SPEC_IDS) do
        local _, specName, _, _, _, classFile = GetSpecializationInfoByID(id)
        if specName and specName ~= "" then
            local specKey = strlower(specName)
            local classKey = classFile and strlower(classFile)
            if classKey and classKey ~= "" then
                specNameClassToID[specKey .. ":" .. classKey] = id
            end
            if specNameToID[specKey] == nil then
                specNameToID[specKey] = id
            elseif specNameToID[specKey] ~= id then
                specNameToID[specKey] = false
            end
        end
    end
end

local function ResolveSpecID(specID, specName, className)
    if specID and specID > 0 then
        return specID
    end
    if not specName or specName == "" then
        return nil
    end

    local specKey = strlower(specName)
    if className and className ~= "" then
        local classKey = strlower(className)
        local classResolved = specNameClassToID[specKey .. ":" .. classKey]
        if classResolved then
            return classResolved
        end
    end

    local resolved = specNameToID[specKey]
    if resolved and resolved ~= false then
        return resolved
    end

    return nil
end

local headers = {}
local keyHeader
function addonTable.UpdateHeaderVisuals()
    local modeConfig = GetModeConfig()
    local showSecondaryMetric = UsesSecondaryMetricColumn()
    local isBrowser = IsBrowserMode()
    local isRaidBrowser = IsRaidBrowserMode()
    local isPvpBrowser = IsPvpBrowserMode()
    local isRbgBrowser = IsRatedBattlegroundBrowserMode()
    local showRegions = addonTable.ShouldShowRegions and addonTable.ShouldShowRegions()

    if not showRegions and addonTable.CurrentSortBy == "region" then
        addonTable.CurrentSortBy = isBrowser and "rating" or "ilvl"
        addonTable.CurrentIsAscending = false
    end

    local browserCols = GetCurrentBrowserColumns()
    local browserRegionColumn = { x = browserCols.dungeonRegionSplit.x + browserCols.dungeonRegionSplit.w, w = REGION_TAG_WIDTH, align = "CENTER" }
    local pvpRegionColumn = { x = browserCols.pvpArenaRegionSplit.x + browserCols.pvpArenaRegionSplit.w, w = REGION_TAG_WIDTH, align = "CENTER" }
    local rbgRegionColumn = { x = browserCols.rbgActivityRegionSplit.x + browserCols.rbgActivityRegionSplit.w, w = REGION_TAG_WIDTH, align = "CENTER" }
    local raidRegionColumn = { x = browserCols.raidNameRegionSplit.x + browserCols.raidNameRegionSplit.w, w = REGION_TAG_WIDTH, align = "CENTER" }
    local browserColumns = {
        role   = showRegions and browserCols.dungeonRegionSplit or browserCols.dungeon,
        region = browserRegionColumn,
        class  = browserCols.title,
        spec   = nil,       -- hidden in non-raid browser
        ilvl   = browserCols.comp,    -- "Comp" in browser
        rating = browserCols.rating,
        key    = browserCols.age,     -- "Age" in browser
    }
    local pvpBrowserColumns = {
        role   = showRegions and browserCols.pvpArenaRegionSplit or browserCols.pvpArena,
        region = pvpRegionColumn,
        class  = browserCols.pvpTitle,
        spec   = nil,
        ilvl   = browserCols.pvpComp,
        rating = browserCols.pvpRating,
        key    = browserCols.pvpAge,
    }
    local rbgBrowserColumns = {
        role   = showRegions and browserCols.rbgActivityRegionSplit or browserCols.rbgActivity,
        region = rbgRegionColumn,
        class  = browserCols.rbgTitle,
        spec   = nil,
        ilvl   = browserCols.rbgComp,
        rating = browserCols.rbgRating,
        key    = browserCols.rbgAge,
    }
    local raidBrowserColumns = {
        role   = showRegions and browserCols.raidNameRegionSplit or browserCols.raidName,
        region = raidRegionColumn,
        class  = (OakLFGSorterDB and OakLFGSorterDB.hideNotes) and browserCols.raidTitleCollapsed or browserCols.raidTitle,
        spec   = browserCols.raidDiff,   -- "Difficulty" in raid browser
        ilvl   = browserCols.raidComp,
        rating = (OakLFGSorterDB and OakLFGSorterDB.hideNotes) and browserCols.raidKillsCollapsed or browserCols.raidKills,
        key    = (OakLFGSorterDB and OakLFGSorterDB.hideNotes) and browserCols.raidAgeCollapsed or browserCols.raidAge,
    }
    local defaultColumns = {
        role = C_ROLE,
        region = REGION_COLUMNS.applicant,
        class = showRegions and { x = 45, w = 104, align = "LEFT" } or C_CLASS,
        spec = C_SPEC,
        ilvl = C_ILVL,
        rating = C_RATING,
        key = C_KEY,
    }
    local pad = addonTable.GetThemeFramePadding and addonTable.GetThemeFramePadding() or 0
    local currentWidth = tonumber(OAK_LFG and OAK_LFG:GetWidth()) or FULL_FRAME_WIDTH
    local headerRightLimit = currentWidth - 14 - pad

    for _, header in ipairs(headers) do
        local column
        if isRaidBrowser then
            column = raidBrowserColumns[header.sortKey]
        elseif isRbgBrowser then
            column = rbgBrowserColumns[header.sortKey]
        elseif isPvpBrowser then
            column = pvpBrowserColumns[header.sortKey]
        elseif isBrowser then
            column = browserColumns[header.sortKey]
        else
            column = defaultColumns[header.sortKey]
        end

        if column then
            local headerWidth = math.max(20, math.min(column.w, headerRightLimit - column.x))
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", OAK_LFG, "TOPLEFT", column.x + pad, HEADER_TOP_OFFSET)
            header:SetSize(headerWidth, 22)
            local leftPadding = (column.align == "LEFT") and 6 or 2
            local rightPadding = (column.align == "LEFT") and 12 or 2
            header.text:ClearAllPoints()
            header.text:SetPoint("LEFT", header, "LEFT", leftPadding, 0)
            header.text:SetPoint("RIGHT", header, "RIGHT", -rightPadding, 0)
            header.text:SetJustifyH(column.align == "LEFT" and "LEFT" or "CENTER")
        end

        -- Visibility: spec shows in raid browser only; always show in applicant mode
        if isBrowser and header.sortKey == "spec" then
            if isRaidBrowser then
                header:Show()
            else
                header:Hide()
            end
        elseif header.sortKey == "key" then
            if isBrowser or showSecondaryMetric then
                header:Show()
            else
                header:Hide()
            end
        elseif header.sortKey == "region" then
            if showRegions then
                header:Show()
            else
                header:Hide()
            end
        else
            header:Show()
        end

        -- Text labels
        if header.sortKey == "rating" then
            if isRaidBrowser then
                header.text:SetText("Kills")
            else
                header.text:SetText(modeConfig.ratingLabel)
            end
        elseif header.sortKey == "key" then
            if isBrowser then
                header.text:SetText(L["Age"])
            else
                header.text:SetText(modeConfig.keyLabel)
            end
        elseif isBrowser and header.sortKey == "role" then
            if isRaidBrowser then
                header.text:SetText("Raid")
            elseif isPvpBrowser then
                header.text:SetText(isRbgBrowser and "Activity" or "Arena")
            elseif GetListingMode() == "delve" then
                header.text:SetText("Delve")
            elseif GetListingMode() == "generic" then
                -- Generic covers Custom Groups (shows Custom PvE/PvP activity types)
                -- and Questing (shows zone names). Distinguish by examining the first result.
                local ctxInfo = addonTable.CurrentSearchContext and addonTable.CurrentSearchContext.activityInfo
                local firstResult = addonTable.SearchResults and addonTable.SearchResults[1]
                local hint = strlower(
                    (ctxInfo and (ctxInfo.fullName or ctxInfo.shortName or ""))
                    or (firstResult and (firstResult.activityName or firstResult.dungeonName or ""))
                    or ""
                )
                if hint:find("custom", 1, true) then
                    header.text:SetText("Activity")
                else
                    header.text:SetText("Zone")
                end
            else
                header.text:SetText(L["Dungeon"])
            end
        elseif isBrowser and header.sortKey == "class" then
            header.text:SetText(L["Title"])
        elseif isBrowser and header.sortKey == "ilvl" then
            header.text:SetText(L["Comp"])
        elseif isRaidBrowser and header.sortKey == "spec" then
            header.text:SetText("Difficulty")
        elseif header.sortKey == "region" then
            header.text:SetText("Reg")
        else
            header.text:SetText(header.baseText)
        end

        if addonTable.CurrentSortBy == header.sortKey then
            header.arrow:SetTexture(addonTable.CurrentIsAscending and "Interface\\BUTTONS\\Arrow-Up-Up" or "Interface\\BUTTONS\\Arrow-Down-Up")
            header.arrow:Show()
        else
            header.arrow:Hide()
        end
    end
end

local function CreateHeader(label, sortKey, column)
    local btn = CreateFrame("Button", nil, OAK_LFG, "BackdropTemplate")
    btn:SetSize(column.w, 22)
    btn:SetPoint("TOPLEFT", OAK_LFG, "TOPLEFT", column.x, HEADER_TOP_OFFSET)
    btn:SetBackdrop({bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1})
    btn:SetBackdropColor(unpack(addonTable.OAK_COLOR_PANE))
    btn:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    btn:EnableMouse(true)
    btn:SetFrameLevel(OAK_LFG:GetFrameLevel() + 10)
    
    btn.baseText = label; btn.sortKey = sortKey
    btn.text = btn:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    local leftPadding = (column.align == "LEFT") and 6 or 2
    local rightPadding = (column.align == "LEFT") and 12 or 2
    btn.text:SetPoint("LEFT", btn, "LEFT", leftPadding, 0)
    btn.text:SetPoint("RIGHT", btn, "RIGHT", -rightPadding, 0)
    if column.align == "LEFT" then
        btn.text:SetJustifyH("LEFT")
    else
        btn.text:SetJustifyH("CENTER")
    end
    btn.text:SetText(label)
    btn.text:SetWordWrap(false)

    btn.arrow = btn:CreateTexture(nil, "OVERLAY")
    btn.arrow:SetSize(10, 10)
    btn.arrow:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
    btn.arrow:Hide()
    
    btn:SetScript("OnClick", function()
        if addonTable.CurrentSortBy == sortKey then addonTable.CurrentIsAscending = not addonTable.CurrentIsAscending
        else addonTable.CurrentSortBy = sortKey; addonTable.CurrentIsAscending = false end
        addonTable.UpdateHeaderVisuals(); addonTable.UpdateDisplay()
    end)
    btn:SetScript("OnEnter", function(self)
        local title, description = GetHeaderTooltipData(self.sortKey)
        if title and description then
            self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(title, 1, 1, 1)
            GameTooltip:AddLine(description, 1, 1, 1, true)
            GameTooltip:AddLine("Click to sort. Click again to reverse the order.", 0.75, 0.75, 0.75, true)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
        GameTooltip:Hide()
    end)
    table.insert(headers, btn)
    if sortKey == "key" then
        keyHeader = btn
    end
    return btn
end

local function GetCurrentNoteColumn()
    if IsBrowserMode() then
        local browserCols = GetCurrentBrowserColumns()
        if IsRaidBrowserMode() then
            if OakLFGSorterDB and OakLFGSorterDB.hideNotes then
                return browserCols.raidNoteCollapsed
            end
            return browserCols.raidNote
        end
        if IsPvpBrowserMode() then
            return IsRatedBattlegroundBrowserMode() and browserCols.rbgNote or browserCols.pvpNote
        end
        return browserCols.note
    end

    if UsesSecondaryMetricColumn() then
        return C_NOTE
    end

    return { x = C_KEY.x, w = C_KEY.w + C_NOTE.w, align = "LEFT" }
end

local function GetCurrentRowNoteColumn()
    return RowColumn(GetCurrentNoteColumn())
end

local function GetCurrentRaidBrowserColumns()
    local browserCols = GetCurrentBrowserColumns()
    if OakLFGSorterDB and OakLFGSorterDB.hideNotes then
        return {
            name = RowColumn(browserCols.raidName),
            diff = RowColumn(browserCols.raidDiff),
            comp = RowColumn(browserCols.raidComp),
            title = RowColumn(browserCols.raidTitleCollapsed),
            kills = RowColumn(browserCols.raidKillsCollapsed),
            age = RowColumn(browserCols.raidAgeCollapsed),
            note = RowColumn(browserCols.raidNoteCollapsed),
        }
    end

    return {
        name = RowColumn(browserCols.raidName),
        diff = RowColumn(browserCols.raidDiff),
        comp = RowColumn(browserCols.raidComp),
        title = RowColumn(browserCols.raidTitle),
        kills = RowColumn(browserCols.raidKills),
        age = RowColumn(browserCols.raidAge),
        note = RowColumn(browserCols.raidNote),
    }
end

GetBrowserApplicationPriority = function(result)
    if result.isRoleFilled then
        return 4
    end
    if addonTable.IsAppliedStatus and addonTable.IsAppliedStatus(result.applicationStatus) then
        return 3
    end
    if addonTable.IsDeclinedStatus and addonTable.IsDeclinedStatus(result.applicationStatus) then
        return 1
    end
    -- Friends: shown above normal results but below applied
    if (result.numBNetFriends or 0) > 0 or (result.numCharFriends or 0) > 0 then
        return 2.5
    end
    return 2
end

local function GetBrowserSetupSummary(result)
    if result._oakSetupSummary then
        return result._oakSetupSummary
    end

    local expectedRoles = { "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER" }
    local setup = {}
    local players = result.players or {}

    if #players > 0 then
        local sortedPlayers = {}
        local roleOrder = { TANK = 1, HEALER = 2, DAMAGER = 3 }

        for _, player in ipairs(players) do
            table.insert(sortedPlayers, player)
        end

        table.sort(sortedPlayers, function(a, b)
            return (roleOrder[a.role] or 99) < (roleOrder[b.role] or 99)
        end)

        local usedPlayers = {}
        for index, expectedRole in ipairs(expectedRoles) do
            local filled = false
            local className = nil

            for playerIndex, player in ipairs(sortedPlayers) do
                if not usedPlayers[playerIndex] and player.role == expectedRole then
                    filled = true
                    className = player.class
                    usedPlayers[playerIndex] = true
                    break
                end
            end

            setup[index] = {
                role = expectedRole,
                filled = filled,
                class = className,
            }
        end
    else
        local remaining = {
            TANK = tonumber(result.roleCounts and result.roleCounts.TANK) or 0,
            HEALER = tonumber(result.roleCounts and result.roleCounts.HEALER) or 0,
            DAMAGER = tonumber(result.roleCounts and result.roleCounts.DAMAGER) or 0,
        }
        for index, expectedRole in ipairs(expectedRoles) do
            local filled = (remaining[expectedRole] or 0) > 0
            if filled then
                remaining[expectedRole] = remaining[expectedRole] - 1
            end
            setup[index] = {
                role = expectedRole,
                filled = filled,
                class = nil,
            }
        end
    end

    result._oakSetupSummary = setup
    return setup
end

local function GetBrowserRowColor(result, isAltColor)
    if result.isRoleFilled then
        return 0.46, 0.30, 0.10, 0.60
    end
    if addonTable.IsAppliedStatus and addonTable.IsAppliedStatus(result.applicationStatus) then
        return 0.12, 0.32, 0.16, 0.55
    end
    if addonTable.IsDeclinedStatus and addonTable.IsDeclinedStatus(result.applicationStatus) then
        return 0.34, 0.10, 0.10, 0.55
    end
    if (result.numBNetFriends or 0) > 0 or (result.numCharFriends or 0) > 0 then
        return 0.12, 0.22, 0.36, 0.50
    end

    local color = isAltColor and addonTable.ROW_COLOR_B or addonTable.ROW_COLOR_A
    return unpack(color)
end

local function GetApplicantStatusText(group)
    local status = addonTable.NormalizeApplicationStatus and addonTable.NormalizeApplicationStatus(group and group.applicationStatus or "none") or tostring(group and group.applicationStatus or "none")
    if status == "invited" or status == "inviteaccepted" then
        return "Invited"
    end
    return nil
end

local function GetApplicantRowColor(group, isAltColor)
    if GetApplicantStatusText(group) then
        return 0.12, 0.32, 0.16, 0.55
    end
    local color = isAltColor and addonTable.ROW_COLOR_B or addonTable.ROW_COLOR_A
    return unpack(color)
end

CreateHeader(L["Role"], "role", C_ROLE)
CreateHeader("Reg", "region", REGION_COLUMNS.applicant)
CreateHeader(L["Class"], "class", C_CLASS)
CreateHeader(L["Spec"], "spec", C_SPEC)
CreateHeader(L["iLvl"], "ilvl", C_ILVL)
CreateHeader(L["Rating"], "rating", C_RATING)
CreateHeader(L["Key"], "key", C_KEY)

local notesToggleBtn = addonTable.CreateFlatButton(OAK_LFG, L["Notes"], C_NOTE.w)
notesToggleBtn:SetSize(C_NOTE.w, 22)
local notesHeader = CreateHeader(L["Notes"], "note", C_NOTE)
local noteVisibilityBtn = addonTable.CreateFlatButton(OAK_LFG, "-", 20)
noteVisibilityBtn:SetSize(20, 22)

local function UpdateNotesToggleLayout()
    local noteColumn = GetCurrentNoteColumn()
    local pad = addonTable.GetThemeFramePadding and addonTable.GetThemeFramePadding() or 0
    local xOffset = noteColumn.x + pad
    local hideNotes = OakLFGSorterDB and OakLFGSorterDB.hideNotes

    if hideNotes then
        notesToggleBtn:ClearAllPoints()
        notesToggleBtn:SetPoint("TOPLEFT", OAK_LFG, "TOPLEFT", xOffset, HEADER_TOP_OFFSET)
        -- Clamp width so the button never overflows past the frame's right edge.
        -- In raid-browser collapsed mode the note column starts at x=500 inside a
        -- 535px frame, leaving only 33px — the old hard-coded 55 caused overflow.
        local currentWidth = tonumber(OAK_LFG and OAK_LFG:GetWidth()) or GetTargetFrameWidth()
        local maxW = currentWidth - xOffset - 2
        notesToggleBtn:SetWidth(math.min(55, math.max(20, maxW)))
        -- Left-justify the "Notes" label in collapsed state
        notesToggleBtn.text:ClearAllPoints()
        notesToggleBtn.text:SetPoint("LEFT", notesToggleBtn, "LEFT", 6, 0)
        notesToggleBtn.text:SetJustifyH("LEFT")
        notesToggleBtn:Show()
        notesHeader:Hide()
        noteVisibilityBtn:Hide()
    else
        -- Restore centered text for the expanded toggle button
        notesToggleBtn.text:ClearAllPoints()
        notesToggleBtn.text:SetPoint("CENTER", notesToggleBtn, "CENTER", 0, 0)
        notesToggleBtn.text:SetJustifyH("CENTER")

        local headerWidth = math.max(36, noteColumn.w - 28)
        notesHeader:SetWidth(headerWidth)
        notesHeader:ClearAllPoints()
        notesHeader:SetPoint("TOPLEFT", OAK_LFG, "TOPLEFT", xOffset, HEADER_TOP_OFFSET)
        notesHeader:Show()

        noteVisibilityBtn:ClearAllPoints()
        noteVisibilityBtn:SetPoint("TOPLEFT", notesHeader, "TOPRIGHT", 2, 0)
        noteVisibilityBtn:Show()

        notesToggleBtn:Hide()
    end
end

local function UpdateNotesToggleVisual()
    notesToggleBtn:SetBackdropColor(unpack(addonTable.OAK_COLOR_PANE))
    notesToggleBtn:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    notesToggleBtn.text:SetText(L["Notes"])
    noteVisibilityBtn:SetBackdropColor(unpack(addonTable.OAK_COLOR_PANE))
    noteVisibilityBtn:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    noteVisibilityBtn.text:SetText((OakLFGSorterDB and OakLFGSorterDB.hideNotes) and "+" or "-")
end

addonTable.RegisterThemeRefresh("ui_rows_theme", function()
    local pad = addonTable.GetThemeFramePadding and addonTable.GetThemeFramePadding() or 0
    local scrollRightOffset = -12
    local scrollBottomOffset = 35
    if (addonTable.GetThemeStyle and (addonTable.GetThemeStyle() == "BLIZZARD" or addonTable.GetThemeStyle() == "BLIZZARD_GRAY")) then
        scrollRightOffset = -6
        scrollBottomOffset = 33
    else
        scrollRightOffset = -12 - pad
        scrollBottomOffset = 35 + pad
    end
    ApplyApplicantContextInsets()
    ApplyFooterInsets()
    suppBtn:ClearAllPoints()
    suppBtn:SetPoint("CENTER", footer, "CENTER", 18, GetFooterButtonYOffset())
    mythicPanelBtn:ClearAllPoints()
    mythicPanelBtn:SetPoint("RIGHT", suppBtn, "LEFT", -2, 0)
    lfrBtn:ClearAllPoints()
    lfrBtn:SetPoint("RIGHT", mythicPanelBtn, "LEFT", -2, 0)
    lfgBtn:ClearAllPoints()
    lfgBtn:SetPoint("RIGHT", lfrBtn, "LEFT", -2, 0)
    optionsBtn:ClearAllPoints()
    optionsBtn:SetPoint("LEFT", suppBtn, "RIGHT", 3, 0)
    listBtn:ClearAllPoints()
    listBtn:SetPoint("LEFT", optionsBtn, "RIGHT", 3, 0)
    pvpBtn:ClearAllPoints()
    pvpBtn:SetPoint("LEFT", listBtn, "RIGHT", 2, 0)
    if addonTable.RefreshFooterButtonWidths then
        addonTable.RefreshFooterButtonWidths()
    end
    stickyPanel:SetBackdropColor(unpack(addonTable.OAK_COLOR_STICKY or {0.05, 0.10, 0.05, 0.95}))
    applicantContextBar:SetBackdropColor(unpack(addonTable.OAK_COLOR_CONTEXT or {0.08, 0.08, 0.10, 0.75}))
    _ssLineTex:SetColorTexture(addonTable.ClassColor.r * (addonTable.OAK_COLOR_STICKY_ACCENT and addonTable.OAK_COLOR_STICKY_ACCENT[1] or 0.9), addonTable.ClassColor.g * (addonTable.OAK_COLOR_STICKY_ACCENT and addonTable.OAK_COLOR_STICKY_ACCENT[2] or 0.9), addonTable.ClassColor.b * (addonTable.OAK_COLOR_STICKY_ACCENT and addonTable.OAK_COLOR_STICKY_ACCENT[3] or 0.9), addonTable.OAK_COLOR_STICKY_ACCENT and addonTable.OAK_COLOR_STICKY_ACCENT[4] or 1.0)
    if scrollBar then
        local thumb = scrollBar:GetThumbTexture()
        if thumb then
            thumb:SetVertexColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
        end
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", OAK_LFG, "TOPRIGHT", scrollRightOffset, SCROLL_TOP_OFFSET - 1)
        scrollBar:SetPoint("BOTTOMRIGHT", OAK_LFG, "BOTTOMRIGHT", scrollRightOffset, scrollBottomOffset)
    end
    _bsepTex:SetColorTexture(addonTable.ClassColor.r * (addonTable.OAK_COLOR_STICKY_ACCENT_SOFT and addonTable.OAK_COLOR_STICKY_ACCENT_SOFT[1] or 0.7), addonTable.ClassColor.g * (addonTable.OAK_COLOR_STICKY_ACCENT_SOFT and addonTable.OAK_COLOR_STICKY_ACCENT_SOFT[2] or 0.7), addonTable.ClassColor.b * (addonTable.OAK_COLOR_STICKY_ACCENT_SOFT and addonTable.OAK_COLOR_STICKY_ACCENT_SOFT[3] or 0.7), addonTable.OAK_COLOR_STICKY_ACCENT_SOFT and addonTable.OAK_COLOR_STICKY_ACCENT_SOFT[4] or 0.9)
    UpdateNotesToggleVisual()
    if addonTable.RefreshBrowserResponsiveLayout then
        addonTable.RefreshBrowserResponsiveLayout()
    end
    if addonTable.UpdateDisplay then
        addonTable.UpdateDisplay()
    end
end)

notesToggleBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if OakLFGSorterDB and OakLFGSorterDB.hideNotes then
        GameTooltip:SetText("Show Notes", 1, 1, 1)
        GameTooltip:AddLine("Expand the Note column and restore the full sorter width.", 1, 1, 1, true)
    else
        GameTooltip:SetText("Hide Notes", 1, 1, 1)
        GameTooltip:AddLine("Collapse the Note column and shrink the sorter window.", 1, 1, 1, true)
    end
    GameTooltip:Show()
end)
notesToggleBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)
noteVisibilityBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(addonTable.ClassColor.r, addonTable.ClassColor.g, addonTable.ClassColor.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L["Hide Notes"], 1, 1, 1)
    GameTooltip:AddLine(L["Collapse the Note column and shrink the sorter window."], 1, 1, 1, true)
    GameTooltip:Show()
end)
noteVisibilityBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(unpack(addonTable.OAK_COLOR_BORDER))
    GameTooltip:Hide()
end)

local CreateRow
local PopulateBrowserRow
local rows = {}
local browserRenderGeneration = 0
local BROWSER_RENDER_BATCH_SIZE = 18

local function QueueBrowserRowRender(normalResults, startIndex, generation)
    if browserRenderGeneration ~= generation or not OAK_LFG:IsShown() or not IsBrowserMode() then
        return
    end

    local displayIndex = startIndex
    local batchEnd = math.min(#normalResults, startIndex + BROWSER_RENDER_BATCH_SIZE - 1)
    for resultIndex = startIndex, batchEnd do
        if not rows[displayIndex] then
            rows[displayIndex] = CreateRow(displayIndex)
        end
        local row = rows[displayIndex]
        PopulateBrowserRow(row, normalResults[resultIndex], (displayIndex % 2) == 0)
        row:Show()
        displayIndex = displayIndex + 1
    end

    if batchEnd < #normalResults then
        C_Timer.After(0, function()
            QueueBrowserRowRender(normalResults, batchEnd + 1, generation)
        end)
    end
end

local function SetFrameWidthPreservingLeft(targetWidth, preserveLeftEdge)
    local minWidth = targetWidth
    local maxWidth = targetWidth
    if IsBrowserMode() then
        minWidth = (OakLFGSorterDB and OakLFGSorterDB.hideNotes) and BROWSER_COLLAPSED_WIDTH or FULL_FRAME_WIDTH
        maxWidth = MAX_FRAME_WIDTH
    end
    OAK_LFG:SetResizeBounds(minWidth, 444, maxWidth, 800)
    if preserveLeftEdge then
        local oldLeft = OAK_LFG:GetLeft()
        local oldBottom = OAK_LFG:GetBottom()

        if not IsBrowserMode() or (OAK_LFG:GetWidth() or 0) < minWidth then
            OAK_LFG:SetWidth(targetWidth)
        end
        if oldLeft and oldBottom then
            OAK_LFG:ClearAllPoints()
            OAK_LFG:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", oldLeft, oldBottom)
            if OakLFGSorterDB then
                OakLFGSorterDB.framePos = { "BOTTOMLEFT", "BOTTOMLEFT", oldLeft, oldBottom }
            end
        end
    elseif (not IsBrowserMode()) and math.abs(OAK_LFG:GetWidth() - targetWidth) > 0.5 then
        OAK_LFG:SetWidth(targetWidth)
    end

    if not OAK_LFG.isOakDragging and not OAK_LFG.isOakResizing and addonTable.ClampFrameToScreen then
        addonTable.ClampFrameToScreen(OAK_LFG, OakLFGSorterDB, "framePos")
    end
end

local function ConfigureTextColumn(fontString, row, column, padding)
    padding = padding or 0
    fontString:ClearAllPoints()
    fontString:SetPoint("LEFT", row, "LEFT", column.x + padding, 0)
    fontString:SetPoint("RIGHT", row, "LEFT", column.x + column.w - padding, 0)
    if column.align == "LEFT" then
        fontString:SetJustifyH("LEFT")
    else
        fontString:SetJustifyH("CENTER")
    end
    fontString:SetWordWrap(false)
end

local function ConfigureTextColumnWithTrailingTag(fontString, tagFontString, row, column, padding, tagMarkup)
    padding = padding or 0
    fontString:ClearAllPoints()
    fontString:SetPoint("LEFT", row, "LEFT", column.x + padding, 0)

    if tagFontString and tagMarkup and tagMarkup ~= "" then
        tagFontString:ClearAllPoints()
        tagFontString:SetPoint("RIGHT", row, "LEFT", column.x + column.w - 4, 0)
        tagFontString:SetWidth(REGION_TAG_WIDTH)
        tagFontString:SetJustifyH("RIGHT")
        tagFontString:SetText(tagMarkup)
        tagFontString:Show()
        fontString:SetPoint("RIGHT", tagFontString, "LEFT", -4, 0)
    else
        if tagFontString then
            tagFontString:SetText("")
            tagFontString:Hide()
        end
        fontString:SetPoint("RIGHT", row, "LEFT", column.x + column.w - padding, 0)
    end

    if column.align == "LEFT" then
        fontString:SetJustifyH("LEFT")
    else
        fontString:SetJustifyH("CENTER")
    end
    fontString:SetWordWrap(false)
end

local function FormatAge(seconds)
    if not seconds or seconds <= 0 then return "--" end
    if seconds < 60 then return seconds .. "s" end
    return math.floor(seconds / 60) .. "m"
end

local function CanApplyToSearchResult()
    return not (C_LFGList and C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo())
end

local function GetPreferredScoreColor(score, defaultR, defaultG, defaultB)
    if RaiderIO and RaiderIO.GetScoreColor then
        local r, g, b = RaiderIO.GetScoreColor(score)
        if r and g and b then
            return r, g, b
        end
    end

    if C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor then
        local color = C_ChallengeMode.GetDungeonScoreRarityColor(score)
        if color then
            return color.r, color.g, color.b
        end
    end

    return defaultR, defaultG, defaultB
end

local function GetMemberRatingDisplay(member)
    local listingMode = GetListingMode()

    if listingMode == "rated_pvp" or listingMode == "pvp" then
        local pvpRating = math.floor(member.pvpRating or 0)
        return pvpRating > 0 and tostring(pvpRating) or "--"
    elseif listingMode == "raid" or listingMode == "legacy_raid" then
        return (member.raidProgress and member.raidProgress.raidName) or "--"
    end

    local ratingNum = math.floor(member.rating or 0)
    local ratingStr = (ratingNum > 0 and tostring(ratingNum)) or "--"

    if ratingNum > 0 then
        local cR, cG, cB = GetPreferredScoreColor(ratingNum, 1, 1, 1)
        ratingStr = string.format("|cFF%02x%02x%02x%s|r", cR * 255, cG * 255, cB * 255, ratingStr)
    end

    if member.mainScore and member.mainScore > ratingNum then
        local mcR, mcG, mcB = GetPreferredScoreColor(member.mainScore, 0.5, 0.5, 0.5)
        local mainStr = string.format("|cFF%02x%02x%02x[%d]|r", mcR * 255, mcG * 255, mcB * 255, math.floor(member.mainScore))
        if ratingNum == 0 then
            ratingStr = mainStr
        else
            ratingStr = ratingStr .. " " .. mainStr
        end
    end

    return ratingStr
end

local function GetRaidProgressFraction(progress)
    if type(progress) ~= "table" then
        return "--"
    end

    local text = tostring(progress.longText or progress.displayText or "")
    local fraction = text:match("(%d+/%d+)")
    if fraction and fraction ~= "" then
        return fraction
    end

    return "--"
end

local function GetMemberSecondaryDisplay(member)
    local listingMode = GetListingMode()

    if listingMode == "rated_pvp" or listingMode == "pvp" then
        return member.pvpBracket or "--"
    elseif listingMode == "raid" or listingMode == "legacy_raid" then
        return GetRaidProgressFraction(member.raidProgress)
    end

    return member.highestKey > 0 and "+" .. member.highestKey or "--"
end

local function GetBrowserRatingDisplay(result)
    local listingMode = GetListingMode()

    if listingMode == "raid" or listingMode == "legacy_raid" then
        return (result.raidProgress and result.raidProgress.displayText) or "--"
    end

    local ratingNum = math.floor(result.rating or 0)
    if ratingNum <= 0 then
        return "--"
    end

    local cR, cG, cB = GetPreferredScoreColor(ratingNum, 1, 1, 1)
    local ratingText = string.format("|cFF%02x%02x%02x%d|r", cR * 255, cG * 255, cB * 255, ratingNum)
    local mainRating = math.floor(result.mainRating or 0)
    if mainRating > ratingNum then
        local mcR, mcG, mcB = GetPreferredScoreColor(mainRating, 0.9, 0.9, 0.9)
        ratingText = string.format("%s |cFF%02x%02x%02x[%d]|r", ratingText, mcR * 255, mcG * 255, mcB * 255, mainRating)
    end
    return ratingText
end

local function GetColoredRaidDifficultyLabel(label)
    local text = tostring(label or "")
    local lowered = strlower(text)
    if lowered == "normal" then
        return "|cff0070dd" .. text .. "|r"
    elseif lowered == "heroic" then
        return "|cffa335ee" .. text .. "|r"
    elseif lowered == "mythic" then
        return "|cffff8000" .. text .. "|r"
    end
    return text
end

local function GetBrowserSecondaryDisplay(result)
    local listingMode = GetListingMode()

    if listingMode == "rated_pvp" or listingMode == "pvp" then
        return result.pvpBracket or "--"
    elseif listingMode == "raid" or listingMode == "legacy_raid" then
        return (result.raidListing and result.raidListing.progressText) or "--"
    end

    return (result.keyLevel and result.keyLevel > 0) and ("+" .. result.keyLevel) or "--"
end

-- isPvp=true uses larger slot sizes and spacing for spec icons
local function RepositionCompSlots(row, col, numSlots, isPvp)
    numSlots = numSlots or 5
    local slotSize    = isPvp and COMP_SLOT_SIZE_PVP    or COMP_SLOT_SIZE
    local slotSpacing = isPvp and COMP_SLOT_SPACING_PVP or COMP_SLOT_SPACING
    local iconSize    = isPvp and COMP_SLOT_ICON_PVP    or COMP_SLOT_ICON
    local totalSpan   = (numSlots - 1) * slotSpacing + slotSize
    local slotOffset  = math.floor((col.w - totalSpan) / 2)
    for index, slot in ipairs(row.compSlots) do
        slot:ClearAllPoints()
        slot:SetPoint("LEFT", row, "LEFT", col.x + slotOffset + ((index - 1) * slotSpacing), 0)
        if isPvp then
            slot:SetSize(slotSize, slotSize)
            slot.icon:SetSize(iconSize, iconSize)
        else
            slot:SetSize(COMP_SLOT_SIZE, COMP_SLOT_SIZE)
            slot.icon:SetSize(COMP_SLOT_ICON, COMP_SLOT_ICON)
        end
    end
end

local function ConfigureBrowserRowLayout(row)
    local browserCols = GetCurrentBrowserColumns()
    local regionMarkup = addonTable.GetRegionBadgeMarkup and addonTable.GetRegionBadgeMarkup(row.regionInfo) or ""
    ConfigureTextColumnWithTrailingTag(row.dungeonText, row.regionText, row, RowColumn(browserCols.dungeon), 5, regionMarkup)
    RepositionCompSlots(row, RowColumn(browserCols.comp))
    ConfigureTextColumn(row.nameText, row, RowColumn(browserCols.title), 5)
    ConfigureTextColumn(row.ratingText, row, RowColumn(browserCols.rating))
    if row.ageText then ConfigureTextColumn(row.ageText, row, RowColumn(browserCols.age)) end
    ConfigureTextColumn(row.noteText, row, RowColumn(browserCols.note), 5)
end

local function ConfigureCustomBrowserRowLayout(row)
    local browserCols = GetCurrentBrowserColumns()
    local regionMarkup = addonTable.GetRegionBadgeMarkup and addonTable.GetRegionBadgeMarkup(row.regionInfo) or ""
    ConfigureTextColumnWithTrailingTag(row.dungeonText, row.regionText, row, RowColumn(browserCols.dungeon), 5, regionMarkup)
    ConfigureTextColumn(row.ilvlText, row, RowColumn(browserCols.comp))
    ConfigureTextColumn(row.nameText, row, RowColumn(browserCols.title), 5)
    ConfigureTextColumn(row.ratingText, row, RowColumn(browserCols.rating))
    if row.ageText then ConfigureTextColumn(row.ageText, row, RowColumn(browserCols.age)) end
    ConfigureTextColumn(row.noteText, row, RowColumn(browserCols.note), 5)
end

-- PVP/Arena layout: narrow "Arena" column + 3-slot spec comp (larger icons) + wider title
local function ConfigurePvpBrowserRowLayout(row)
    local browserCols = GetCurrentBrowserColumns()
    local regionMarkup = addonTable.GetRegionBadgeMarkup and addonTable.GetRegionBadgeMarkup(row.regionInfo) or ""
    ConfigureTextColumnWithTrailingTag(row.dungeonText, row.regionText, row, RowColumn(browserCols.pvpArena), 5, regionMarkup)
    RepositionCompSlots(row, RowColumn(browserCols.pvpComp), 3, true)  -- true = PVP large-slot mode
    ConfigureTextColumn(row.nameText, row, RowColumn(browserCols.pvpTitle), 5)
    ConfigureTextColumn(row.ratingText, row, RowColumn(browserCols.pvpRating))
    if row.ageText then ConfigureTextColumn(row.ageText, row, RowColumn(browserCols.pvpAge)) end
    ConfigureTextColumn(row.noteText, row, RowColumn(browserCols.pvpNote), 5)
end

local function ConfigureRbgBrowserRowLayout(row)
    local browserCols = GetCurrentBrowserColumns()
    local regionMarkup = addonTable.GetRegionBadgeMarkup and addonTable.GetRegionBadgeMarkup(row.regionInfo) or ""
    ConfigureTextColumnWithTrailingTag(row.dungeonText, row.regionText, row, RowColumn(browserCols.rbgActivity), 5, regionMarkup)
    ConfigureTextColumn(row.ilvlText, row, RowColumn(browserCols.rbgComp))
    ConfigureTextColumn(row.nameText, row, RowColumn(browserCols.rbgTitle), 5)
    ConfigureTextColumn(row.ratingText, row, RowColumn(browserCols.rbgRating))
    if row.ageText then ConfigureTextColumn(row.ageText, row, RowColumn(browserCols.rbgAge)) end
    ConfigureTextColumn(row.noteText, row, RowColumn(browserCols.rbgNote), 5)
end

local function ConfigureRaidBrowserRowLayout(row)
    local cols = GetCurrentRaidBrowserColumns()
    local regionMarkup = addonTable.GetRegionBadgeMarkup and addonTable.GetRegionBadgeMarkup(row.regionInfo) or ""
    -- Raid | Difficulty | Comp | Title | Kills | Age | Notes
    ConfigureTextColumnWithTrailingTag(row.dungeonText, row.regionText, row, cols.name, 5, regionMarkup)
    ConfigureTextColumn(row.specText, row, cols.diff)
    -- ilvlText repurposed as raid comp (Tank/Healer/DPS counts); comp slots hidden in raid mode
    ConfigureTextColumn(row.ilvlText, row, cols.comp)
    ConfigureTextColumn(row.nameText, row, cols.title, 5)
    ConfigureTextColumn(row.ratingText, row, cols.kills)
    if row.ageText then ConfigureTextColumn(row.ageText, row, cols.age) end
    ConfigureTextColumn(row.noteText, row, cols.note, 5)
end

local function ConfigureApplicantRowLayout(row)
    local regionMarkup = addonTable.GetRegionBadgeMarkup and addonTable.GetRegionBadgeMarkup(row.regionInfo) or ""
    if row.regionText and regionMarkup ~= "" then
        row.regionText:ClearAllPoints()
        row.regionText:SetPoint("RIGHT", row, "LEFT", R_SPEC.x - 1, 0)
        row.regionText:SetJustifyH("RIGHT")
        row.regionText:SetText(regionMarkup)
        row.regionText:SetWidth(28)
        row.regionText:Show()

        row.nameText:ClearAllPoints()
        row.nameText:SetPoint("LEFT", row, "LEFT", R_CLASS.x + 3, 0)
        row.nameText:SetPoint("RIGHT", row.regionText, "LEFT", -2, 0)
        row.nameText:SetJustifyH("LEFT")
        row.nameText:SetWordWrap(false)
    else
        ConfigureTextColumnWithTrailingTag(row.nameText, row.regionText, row, R_CLASS, 5, regionMarkup)
    end
    ConfigureTextColumn(row.specText, row, R_SPEC, 5)
    ConfigureTextColumn(row.ilvlText, row, R_ILVL)
    ConfigureTextColumn(row.ratingText, row, R_RATING)
    ConfigureTextColumn(row.keyText, row, R_KEY)
    ConfigureTextColumn(row.noteText, row, GetCurrentRowNoteColumn(), 5)
end

local function GetBrowserInviteRightInset()
    return -5
end

RefreshBrowserResponsiveLayout = function()
    if addonTable.UpdateHeaderVisuals then
        addonTable.UpdateHeaderVisuals()
    end
    UpdateNotesToggleLayout()
    UpdateNotesToggleVisual()
    if addonTable.UpdateTopBarLayout then
        addonTable.UpdateTopBarLayout()
    end
    if addonTable.UpdateBrowserFilterPanel and addonTable.BrowserFilterPanel and addonTable.BrowserFilterPanel:IsShown() then
        addonTable.UpdateBrowserFilterPanel()
    end
end
addonTable.RefreshBrowserResponsiveLayout = RefreshBrowserResponsiveLayout

local function SetBrowserCompSlot(slotFrame, role, className, filled)
    local coords = addonTable.RoleTexCoords[role]
    if coords then
        slotFrame.icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        slotFrame.icon:SetTexCoord(unpack(coords))
    end

    if filled then
        local classKey = string.upper(className or "")
        local classColor = (classKey ~= "" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classKey]) or addonTable.ClassColor
        -- Solid class-colored background tile; border is a darker shade of the same color
        slotFrame:SetBackdropColor(classColor.r, classColor.g, classColor.b, 1.0)
        slotFrame:SetBackdropBorderColor(classColor.r * 0.55, classColor.g * 0.55, classColor.b * 0.55, 1)
        slotFrame.icon:SetDesaturated(false)
        slotFrame.icon:SetAlpha(1.0)
    else
        -- Empty slot: very dark background, desaturated dim icon
        slotFrame:SetBackdropColor(0.08, 0.08, 0.10, 0.95)
        slotFrame:SetBackdropBorderColor(0, 0, 0, 1)
        slotFrame.icon:SetDesaturated(true)
        slotFrame.icon:SetAlpha(0.35)
    end
end

-- PVP/Arena comp slot: shows spec icon; falls back to class icon atlas if specID unavailable.
local function SetBrowserCompSlotSpec(slotFrame, specID, className, filled)
    if filled then
        local iconSet = false
        -- Try spec icon first
        if specID and specID > 0 then
            local iconID = select(4, GetSpecializationInfoByID(specID))
            if iconID then
                slotFrame.icon:SetTexture(iconID)
                slotFrame.icon:SetTexCoord(0.075, 0.925, 0.075, 0.925)
                iconSet = true
            end
        end
        -- Fall back to class icon atlas (e.g. "classicon-hunter", "classicon-deathknight")
        if not iconSet and className and className ~= "" then
            local atlasName = "classicon-" .. strlower(className)
            slotFrame.icon:SetAtlas(atlasName, false)
            slotFrame.icon:SetTexCoord(0, 1, 0, 1)
            iconSet = true
        end
        -- Ultimate fallback: DAMAGER role icon
        if not iconSet then
            local coords = addonTable.RoleTexCoords["DAMAGER"]
            if coords then
                slotFrame.icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
                slotFrame.icon:SetTexCoord(unpack(coords))
            end
        end
        local classKey = string.upper(className or "")
        local classColor = (classKey ~= "" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classKey]) or addonTable.ClassColor
        slotFrame:SetBackdropColor(classColor.r, classColor.g, classColor.b, 1.0)
        slotFrame:SetBackdropBorderColor(classColor.r * 0.55, classColor.g * 0.55, classColor.b * 0.55, 1)
        slotFrame.icon:SetDesaturated(false)
        slotFrame.icon:SetAlpha(1.0)
    else
        slotFrame.icon:SetAtlas(nil)
        local coords = addonTable.RoleTexCoords["DAMAGER"]
        if coords then
            slotFrame.icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
            slotFrame.icon:SetTexCoord(unpack(coords))
        end
        slotFrame:SetBackdropColor(0.08, 0.08, 0.10, 0.95)
        slotFrame:SetBackdropBorderColor(0, 0, 0, 1)
        slotFrame.icon:SetDesaturated(true)
        slotFrame.icon:SetAlpha(0.35)
    end
end

-- Role icon texture markup (LFG portrait-roles spritesheet)
addonTable.RoleIconMarkup = {
    TANK    = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:13:13:0:0:64:64:0:19:22:41|t ",
    HEALER  = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:13:13:0:0:64:64:20:39:1:20|t ",
    DAMAGER = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:13:13:0:0:64:64:20:39:22:41|t ",
}
-- Text tag appended to the group leader's entry in the tooltip.
-- Plain text is used intentionally — WoW texture/atlas paths for the leader crown
-- vary across versions and font rendering of Unicode glyphs is inconsistent.
local LEADER_CROWN = " - Leader"

function addonTable.NormalizeTooltipLeaderName(name)
    local text = tostring(name or "")
    local baseName = text:match("([^%-]+)") or text
    return strlower(baseName)
end

function addonTable.FindLeaderPlayerIndex(result)
    if not (result and type(result.players) == "table" and #result.players > 0) then
        return nil
    end

    local leaderKey = addonTable.NormalizeTooltipLeaderName(result.leaderName)
    if leaderKey ~= "" then
        for index, player in ipairs(result.players) do
            local playerKey = addonTable.NormalizeTooltipLeaderName(player and player.name)
            if playerKey ~= "" and playerKey == leaderKey then
                return index
            end
        end
    end

    return 1
end

-- Append RIO milestones (Best Run, Best for Dungeon, Timed X-Y Runs) without
-- the "Raider.IO M+ Score" section header — the caller adds the header with the score value.
function addonTable.AppendRIOMilestonesNoHeader(tooltip, rioProfile)
    local mPlus = rioProfile and rioProfile.mythicKeystoneProfile
    if type(mPlus) ~= "table" then return end
    local milestones = mPlus.sortedMilestones
    if type(milestones) ~= "table" or #milestones == 0 then return end
    for _, m in ipairs(milestones) do
        if type(m) == "table" and m.label and m.text then
            tooltip:AddDoubleLine(m.label, m.text, 1, 1, 1, 1, 1, 1)
        end
    end
end

local function NormalizeFriendMatchName(name, realm)
    local fullName = tostring(name or "")
    if tostring(realm or "") ~= "" and not fullName:find("-", 1, true) then
        fullName = fullName .. "-" .. tostring(realm)
    end
    if Ambiguate then
        fullName = Ambiguate(fullName, "mail")
    end
    return strlower(fullName)
end

local function BuildSearchResultFriendNameList(result)
    if type(result) ~= "table" or type(result.players) ~= "table" or #result.players == 0 then
        return {}
    end

    local playerNames = {}
    for _, player in ipairs(result.players) do
        local normalized = NormalizeFriendMatchName(player and player.name)
        if normalized ~= "" then
            playerNames[normalized] = player.name or normalized
        end
    end

    local matches = {}
    local seen = {}

    local function AddMatch(name, realm)
        local normalized = NormalizeFriendMatchName(name, realm)
        local displayName = playerNames[normalized]
        if displayName and not seen[normalized] then
            seen[normalized] = true
            matches[#matches + 1] = displayName
        end
    end

    if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
        local numFriends = tonumber(C_FriendList.GetNumFriends()) or 0
        for i = 1, numFriends do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info then
                AddMatch(info.name, info.realmName)
            end
        end
    end

    if BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendAccountInfo then
        local numBNetFriends = select(1, BNGetNumFriends())
        numBNetFriends = tonumber(numBNetFriends) or 0
        for i = 1, numBNetFriends do
            local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
            if accountInfo then
                local gameInfo = accountInfo.gameAccountInfo
                if gameInfo then
                    AddMatch(gameInfo.characterName, gameInfo.realmName)
                end

                if C_BattleNet.GetFriendNumGameAccounts and C_BattleNet.GetFriendGameAccountInfo then
                    local numGameAccounts = tonumber(C_BattleNet.GetFriendNumGameAccounts(i)) or 0
                    for gameIndex = 1, numGameAccounts do
                        local extraGameInfo = C_BattleNet.GetFriendGameAccountInfo(i, gameIndex)
                        if extraGameInfo then
                            AddMatch(extraGameInfo.characterName, extraGameInfo.realmName)
                        end
                    end
                end
            end
        end
    end

    table.sort(matches, function(a, b)
        return strlower(tostring(a or "")) < strlower(tostring(b or ""))
    end)

    return matches
end

-- Build the rich hover tooltip for a browser search-result row (screenshot 1 style).
-- Shift-held is handled upstream and shows the full RIO profile panel instead.
function addonTable.BuildBrowserGroupTooltip(result)
    -- Fetch the RIO profile lazily at tooltip time (not stored in the result to save memory)
    local rioProfile = nil
    if result.leaderName and result.leaderName ~= "" and RaiderIO and RaiderIO.GetProfile then
        local charName, charRealm = strsplit("-", result.leaderName)
        if not charRealm or charRealm == "" then
            charRealm = GetNormalizedRealmName() or ""
        end
        rioProfile = RaiderIO.GetProfile(charName, charRealm)
    end
    local listingMode = result.mode or "generic"

    -- ── PVP: re-fetch rating fresh (may have been nil when result was first processed) ─
    if (listingMode == "rated_pvp" or listingMode == "pvp") and result.id and C_LFGList.GetSearchResultInfo then
        local fresh = C_LFGList.GetSearchResultInfo(result.id)
        if fresh and type(fresh.leaderPvpRatingInfo) == "table" then
            local entry = fresh.leaderPvpRatingInfo[1] or fresh.leaderPvpRatingInfo
            if type(entry) == "table" then
                local freshRating = tonumber(entry.rating or entry.pvpRating or entry.currentRating or entry.value) or 0
                if freshRating > 0 then
                    result.pvpRating = freshRating
                    result.rating    = freshRating
                end
                if not result.pvpBracket and GetPvpBracketLabel then
                    result.pvpBracket = GetPvpBracketLabel(entry)
                end
            end
        end
    end

    -- ── Title: "+13 Competitive" ──────────────────────────────────────────────
    local titleParts = {}
    if result.keyLevel and result.keyLevel > 0 then
        table.insert(titleParts, "+" .. result.keyLevel)
    end
    if result.playstyleLabel and result.playstyleLabel ~= "" and result.playstyleLabel ~= "Any" then
        table.insert(titleParts, result.playstyleLabel)
    end
    local titleStr = #titleParts > 0 and table.concat(titleParts, " ")
                     or (result.displayName ~= "" and result.displayName
                        or (result.activityName ~= "" and result.activityName or "Group"))
    GameTooltip:AddLine(titleStr, 1, 1, 0)

    -- ── Activity name: "Maisara Caverns (Mythic Keystone)" ───────────────────
    if result.activityName and result.activityName ~= "" then
        GameTooltip:AddLine(result.activityName, 0.70, 0.70, 0.70)
    end

    -- ── Playstyle label ───────────────────────────────────────────────────────
    if result.playstyleLabel and result.playstyleLabel ~= "" and result.playstyleLabel ~= "Any" then
        GameTooltip:AddLine(result.playstyleLabel, 0.50, 0.80, 1.0)
    end

    GameTooltip:AddLine(" ")

    -- ── Leader: name + score (M+ rating or PVP rating) ───────────────────────
    local leaderName = result.leaderName or ""
    if leaderName ~= "" then
        if listingMode == "rated_pvp" or listingMode == "pvp" then
            local pvpRating = math.floor(result.pvpRating or result.rating or 0)
            local ratingStr = pvpRating > 0 and tostring(pvpRating) or "--"
            GameTooltip:AddDoubleLine("Leader:  " .. leaderName, ratingStr, 1, 1, 1, 1, 1, 1)
        else
            local score = math.floor(result.ratingValue or result.rating or 0)
            if score > 0 then
                local cR, cG, cB = GetPreferredScoreColor(score, 1, 1, 1)
                GameTooltip:AddDoubleLine("Leader:  " .. leaderName, tostring(score), 1, 1, 1, cR, cG, cB)
            else
                GameTooltip:AddDoubleLine("Leader:", leaderName, 1, 1, 1, 1, 1, 1)
            end
        end
    end

    -- ── RIO best run + best for this dungeon ──────────────────────────────────
    if rioProfile and type(rioProfile.mythicKeystoneProfile) == "table" then
        local mPlus = rioProfile.mythicKeystoneProfile
        if type(mPlus.sortedDungeons) == "table" and #mPlus.sortedDungeons > 0 then
            -- Best run overall (sortedDungeons is sorted highest first)
            local best = mPlus.sortedDungeons[1]
            if best then
                local lvl  = tonumber(best.level) or 0
                local abbr = best.shortName or best.mapShortName or ""
                if lvl > 0 then
                    GameTooltip:AddDoubleLine("Best Run:", "+" .. lvl .. (abbr ~= "" and " " .. abbr or ""), 1, 1, 1, 1, 1, 1)
                end
            end
            -- Best for the specific dungeon being viewed
            local targetKey = strlower(result.dungeonName or result.activityFilterLabel or "")
            if targetKey ~= "" then
                for _, dng in ipairs(mPlus.sortedDungeons) do
                    local dngName = strlower(dng.name or dng.mapName or "")
                    if dngName ~= "" and (
                        targetKey:find(dngName:sub(1, 5), 1, true) or
                        dngName:find(targetKey:sub(1, 5), 1, true)
                    ) then
                        local lvl  = tonumber(dng.level) or 0
                        local abbr = dng.shortName or dng.mapShortName or ""
                        if lvl > 0 then
                            GameTooltip:AddDoubleLine("Best for Dungeon:", "+" .. lvl .. (abbr ~= "" and " " .. abbr or ""), 1, 1, 1, 1, 1, 1)
                        end
                        break
                    end
                end
            end
        end
    end

    -- ── Member list ───────────────────────────────────────────────────────────
    if result.players and #result.players > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Members: (" .. #result.players .. ")", 1, 0.82, 0)
        local isRaidContext = (listingMode == "raid" or listingMode == "legacy_raid" or listingMode == "open_world")
        local leaderIndex = addonTable.FindLeaderPlayerIndex(result) or 1
        if isRaidContext and #result.players > 5 then
            -- Raid: grouped display (spec×count) to keep tooltip compact.
            -- Show the group leader first with a crown, then group the rest.
            local leaderPlayer = result.players[leaderIndex]
            if leaderPlayer then
                local cc = leaderPlayer.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[leaderPlayer.class]
                local r, g, b = cc and cc.r or 1, cc and cc.g or 1, cc and cc.b or 1
                local roleIcon = addonTable.RoleIconMarkup[leaderPlayer.role] or addonTable.RoleIconMarkup.DAMAGER
                local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[leaderPlayer.class])
                                  or leaderPlayer.class or "?"
                local specPart = (leaderPlayer.specName and leaderPlayer.specName ~= "")
                                 and (" - " .. leaderPlayer.specName) or ""
                GameTooltip:AddLine(roleIcon .. className .. specPart .. LEADER_CROWN, r, g, b)
            end
            -- Group remaining members by role+class+spec
            local counts = {}
            local order  = {}
            for i = 1, #result.players do
                if i ~= leaderIndex then
                local player = result.players[i]
                local specKey = (player.role or "DAMAGER") .. "|" .. (player.class or "?") .. "|" .. (player.specName or "")
                if not counts[specKey] then
                    counts[specKey] = { role = player.role, class = player.class, specName = player.specName or "", count = 0 }
                    table.insert(order, specKey)
                end
                counts[specKey].count = counts[specKey].count + 1
                end
            end
            -- Sort: class first (keeps Holy/Ret Paladins together, etc.),
            -- then role within class, then spec name for a stable order.
            table.sort(order, function(a, b)
                local ca = counts[a].class or ""
                local cb = counts[b].class or ""
                if ca ~= cb then return ca < cb end
                local wa = roleWeights[counts[a].role] or 4
                local wb = roleWeights[counts[b].role] or 4
                if wa ~= wb then return wa < wb end
                return (counts[a].specName or "") < (counts[b].specName or "")
            end)
            for _, key in ipairs(order) do
                local entry = counts[key]
                local cc = RAID_CLASS_COLORS and entry.class and RAID_CLASS_COLORS[entry.class]
                local r, g, b = cc and cc.r or 1, cc and cc.g or 1, cc and cc.b or 1
                local roleIcon = addonTable.RoleIconMarkup[entry.role] or addonTable.RoleIconMarkup.DAMAGER
                local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[entry.class])
                                  or entry.class or "?"
                local specPart  = entry.specName ~= "" and (" - " .. entry.specName) or ""
                -- Use " x3" style count (Lua 5.1 has no \x hex escapes)
                local countPart = entry.count > 1 and (" x" .. entry.count) or ""
                GameTooltip:AddLine(roleIcon .. className .. specPart .. countPart, r, g, b)
            end
        else
            -- Non-raid / small group: leader shown first with crown, rest sorted by class.
            local function RenderMemberLine(player, isLeader)
                local cc = player.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[player.class]
                local r, g, b = cc and cc.r or 1, cc and cc.g or 1, cc and cc.b or 1
                local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[player.class])
                                  or player.class or "?"
                local roleIcon = addonTable.RoleIconMarkup[player.role] or addonTable.RoleIconMarkup.DAMAGER
                local line
                if player.specName and player.specName ~= "" then
                    line = roleIcon .. className .. " - " .. player.specName
                else
                    line = roleIcon .. className
                end
                if isLeader then line = line .. LEADER_CROWN end
                GameTooltip:AddLine(line, r, g, b)
            end
            -- Leader always first
            if result.players[leaderIndex] then
                RenderMemberLine(result.players[leaderIndex], true)
            end
            -- Remaining members sorted by class, then role, then spec
            if #result.players > 1 then
                local rest = {}
                for i = 1, #result.players do
                    if i ~= leaderIndex then
                        table.insert(rest, result.players[i])
                    end
                end
                table.sort(rest, function(a, b)
                    local ca = a.class or ""
                    local cb = b.class or ""
                    if ca ~= cb then return ca < cb end
                    local wa = roleWeights[a.role] or 4
                    local wb = roleWeights[b.role] or 4
                    if wa ~= wb then return wa < wb end
                    return (a.specName or "") < (b.specName or "")
                end)
                for _, player in ipairs(rest) do
                    RenderMemberLine(player, false)
                end
            end
        end
    end

    if result.raidListing and type(result.raidListing.defeatedBossList) == "table" and #result.raidListing.defeatedBossList > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Bosses Defeated:", 1, 0.82, 0)
        for _, bossName in ipairs(result.raidListing.defeatedBossList) do
            GameTooltip:AddLine(bossName, 1, 1, 1)
        end
    end

    -- ── Raider.IO M+ section ──────────────────────────────────────────────────
    if rioProfile and type(rioProfile.mythicKeystoneProfile) == "table" then
        local mPlus   = rioProfile.mythicKeystoneProfile
        local score   = math.floor(mPlus.currentScore or 0)
        local mainScore = math.floor(mPlus.mainCurrentScore or 0)
        GameTooltip:AddLine(" ")
        if score > 0 then
            local cR, cG, cB = GetPreferredScoreColor(score, 1, 0.82, 0)
            GameTooltip:AddDoubleLine("Raider.IO M+ Score", tostring(score), 1, 0.82, 0, cR, cG, cB)
        else
            GameTooltip:AddLine("Raider.IO M+ Score", 1, 0.82, 0)
        end
        if mainScore > score then
            local mcR, mcG, mcB = GetPreferredScoreColor(mainScore, 0.85, 0.85, 0.85)
            GameTooltip:AddDoubleLine("Main/Warband Rating", tostring(mainScore), 0.75, 0.75, 0.75, mcR, mcG, mcB)
        end
        addonTable.AppendRIOMilestonesNoHeader(GameTooltip, rioProfile)
    end

    -- ── Raid Progress ─────────────────────────────────────────────────────────
    if result.raidProgress then
        local rp = result.raidProgress
        local txt = rp.longText or rp.displayText or ""
        if txt ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Raider.IO Raid Progress", 1, 0.82, 0)
            GameTooltip:AddLine(txt, 1, 1, 1)
        end
    end

    -- ── Non-M+ modes: fallback stats ─────────────────────────────────────────
    if (listingMode == "raid" or listingMode == "legacy_raid") and (not result.raidProgress) then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Progress:", "--", 1, 1, 1, 1, 1, 1)
    end

    -- ── Region ───────────────────────────────────────────────────────────────
    if addonTable.AddRegionTooltipLine then
        addonTable.AddRegionTooltipLine(GameTooltip, result.regionInfo)
    end

    -- ── Friends ───────────────────────────────────────────────────────────────
    if (result.numBNetFriends or 0) > 0 or (result.numCharFriends or 0) > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Friends:", string.format("%d BNet / %d WoW", result.numBNetFriends or 0, result.numCharFriends or 0), 0.6, 0.85, 1, 0.6, 0.85, 1)
        local friendNames = BuildSearchResultFriendNameList(result)
        if #friendNames > 0 then
            GameTooltip:AddLine(table.concat(friendNames, ", "), 0.85, 0.85, 0.85, true)
        end
    end

    -- ── Note ──────────────────────────────────────────────────────────────────
    if result.comment and result.comment ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Note:", 1, 0.8, 0)
        GameTooltip:AddLine(result.comment, 0.85, 0.85, 0.85, true)
    end

    -- ── Shift hint ────────────────────────────────────────────────────────────
    if RaiderIO and RaiderIO.ShowProfile and leaderName ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Hold Shift for full Raider.IO profile", 0.50, 0.50, 0.50)
    end
end

CreateRow = function(index, parentOverride, prevRowOverride)
    local parent = parentOverride or scrollChild
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)

    if prevRowOverride then
        -- Sticky row: position relative to explicitly supplied previous row
        row:SetPoint("TOPLEFT", prevRowOverride, "BOTTOMLEFT", 0, 0)
        row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    elseif index == 1 then
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    else
        row:SetPoint("TOPLEFT", rows[index-1], "BOTTOMLEFT", 0, 0)
        row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    end

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()

    row.hoverBg = row:CreateTexture(nil, "ARTWORK")
    row.hoverBg:SetAllPoints()
    row.hoverBg:SetColorTexture(1, 1, 1, 0.1)
    row.hoverBg:Hide()

    row:SetScript("OnEnter", function(self) 
        self.hoverBg:Show() 

        if self.searchResultID and self.searchResult then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
            GameTooltip:ClearLines()
            self._oakShiftTooltipState = IsShiftKeyDown and IsShiftKeyDown() or false
            self:SetScript("OnUpdate", function(widget)
                local shiftDown = IsShiftKeyDown and IsShiftKeyDown() or false
                if widget._oakShiftTooltipState ~= shiftDown then
                    widget._oakShiftTooltipState = shiftDown
                    local onEnter = widget:GetScript("OnEnter")
                    if onEnter then
                        onEnter(widget)
                    end
                end
            end)

            local result = self.searchResult

            -- Shift held: hand off to Raider.IO's full profile panel (screenshot 2)
            if addonTable.TryShowRaiderIOProfileTooltip and addonTable.TryShowRaiderIOProfileTooltip(GameTooltip, result.leaderName) then
                return
            end

            -- Regular hover: rich group tooltip (screenshot 1)
            addonTable.BuildBrowserGroupTooltip(result)
            GameTooltip:Show()
        elseif self.applicantID and self.memberIdx then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
            GameTooltip:ClearLines()

            local name, class, localizedClass, level, itemLevel, honorLevel, tank, healer, damage, assignedRole, relationship, dungeonScore, _, _, _, _, isLeaver = C_LFGList.GetApplicantMemberInfo(self.applicantID, self.memberIdx)
            self._oakShiftTooltipState = IsShiftKeyDown and IsShiftKeyDown() or false
            self:SetScript("OnUpdate", function(widget)
                local shiftDown = IsShiftKeyDown and IsShiftKeyDown() or false
                if widget._oakShiftTooltipState ~= shiftDown then
                    widget._oakShiftTooltipState = shiftDown
                    local onEnter = widget:GetScript("OnEnter")
                    if onEnter then
                        onEnter(widget)
                    end
                end
            end)

            if addonTable.TryShowRaiderIOProfileTooltip and addonTable.TryShowRaiderIOProfileTooltip(GameTooltip, name) then
                return
            end
            
            if name then
                GameTooltip:AddLine(addonTable.ApplyClassColor(name, class or ""), 1, 1, 1)
                GameTooltip:AddLine(string.format("%s - Item Level: %d", localizedClass or "", math.floor(itemLevel or 0)), 1, 1, 1)
                if isLeaver then
                    GameTooltip:AddLine("|cffff4040<!>|r Recent M+ leaver flag", 1, 0.25, 0.25)
                end
                GameTooltip:AddLine(" ")

                local listingMode = GetListingMode()
                if listingMode == "rated_pvp" or listingMode == "pvp" then
                    GameTooltip:AddLine("PvP Profile", 0.2, 1, 0.2)
                    GameTooltip:AddDoubleLine("Rating:", (self.memberPvpRating and self.memberPvpRating > 0) and self.memberPvpRating or "--", 1, 1, 1, 1, 1, 1)
                    if self.memberPvpBracket then
                        GameTooltip:AddDoubleLine("Bracket:", self.memberPvpBracket, 1, 1, 1, 1, 1, 1)
                    end
                elseif listingMode == "raid" or listingMode == "legacy_raid" then
                    GameTooltip:AddLine("Raid Profile", 1, 0.8, 0)
                    if self.memberRaidProgress then
                        GameTooltip:AddDoubleLine(self.memberRaidProgress.raidName .. ":", self.memberRaidProgress.longText or self.memberRaidProgress.displayText, 1, 1, 1, 1, 1, 1)
                    else
                        GameTooltip:AddDoubleLine("Progress:", "--", 1, 1, 1, 1, 1, 1)
                    end
                else
                    GameTooltip:AddLine("Mythic+ Profile", 0.2, 1, 0.2)

                    local score = math.floor(self.memberRating or 0)
                    local cR, cG, cB = GetPreferredScoreColor(score, 1, 1, 1)

                    GameTooltip:AddDoubleLine("Overall Rating:", score > 0 and score or "--", 1, 1, 1, cR, cG, cB)

                    if self.rioProfile and type(self.rioProfile.mythicKeystoneProfile) == "table" then
                        local mPlus = self.rioProfile.mythicKeystoneProfile
                        local mainScore = math.floor(mPlus.mainCurrentScore or 0)
                        if mainScore > score then
                            local mcR, mcG, mcB = GetPreferredScoreColor(mainScore, 0.5, 0.5, 0.5)
                            GameTooltip:AddDoubleLine("Main Rating:", mainScore, 0.5, 0.5, 0.5, mcR, mcG, mcB)
                        end
                    end

                    local entryInfo = C_LFGList.GetActiveEntryInfo()
                    local activityID = entryInfo and tonumber(entryInfo.activityID)
                    if activityID == 0 then
                        activityID = nil
                    end
                    if activityID then
                        local success, bestForDungeon = pcall(C_LFGList.GetApplicantDungeonScoreForListing, self.applicantID, self.memberIdx, activityID)
                        if success and type(bestForDungeon) == "table" and type(bestForDungeon.bestRunLevel) == "number" and bestForDungeon.bestRunLevel > 0 then
                            GameTooltip:AddDoubleLine("Best for " .. (bestForDungeon.mapName or "Listing") .. ":", "+" .. bestForDungeon.bestRunLevel, 1, 1, 1, 1, 1, 1)
                        end
                    end

                    local successBest, bestOverall = pcall(C_LFGList.GetApplicantBestDungeonScore, self.applicantID, self.memberIdx)
                    if successBest and type(bestOverall) == "table" and type(bestOverall.bestRunLevel) == "number" and bestOverall.bestRunLevel > 0 then
                        GameTooltip:AddDoubleLine("Best Run:", "+" .. bestOverall.bestRunLevel .. " (" .. (bestOverall.mapName or "Unknown") .. ")", 1, 1, 1, 1, 1, 1)
                    end

                    if self.rioProfile and addonTable.AppendMythicPlusMilestonesToTooltip then
                        addonTable.AppendMythicPlusMilestonesToTooltip(GameTooltip, self.rioProfile)
                    end
                end

                if self.rioProfile and listingMode ~= "raid" and listingMode ~= "legacy_raid" then
                    local raidDataFound = {}
                    local function MineRaidData(t, depth)
                        if depth > 8 or type(t) ~= "table" then return end
                        if t.difficulty and t.progressCount and t.raid and type(t.raid) == "table" and t.raid.shortName then
                            local rname = t.raid.shortName
                            local diff = tonumber(t.difficulty) or t.difficulty
                            local count = tonumber(t.progressCount) or 0
                            local bosses = tonumber(t.raid.bossCount) or 9
                            if not raidDataFound[rname] then raidDataFound[rname] = {n=0, h=0, m=0, bosses=bosses} end
                            if diff == 1 or diff == "Normal" or diff == "N" then raidDataFound[rname].n = math.max(raidDataFound[rname].n, count) end
                            if diff == 2 or diff == "Heroic" or diff == "H" then raidDataFound[rname].h = math.max(raidDataFound[rname].h, count) end
                            if diff == 3 or diff == "Mythic" or diff == "M" then raidDataFound[rname].m = math.max(raidDataFound[rname].m, count) end
                            return
                        end
                        local name = t.shortName or t.raid_name or t.name or (t.raid and type(t.raid) == "table" and t.raid.shortName)
                        if name and (t.normal or t.heroic or t.mythic or t.normal_bosses_killed) then
                            local rname = tostring(name)
                            local n = t.normal or t.normal_bosses_killed or t.Normal or t.n or 0
                            local h = t.heroic or t.heroic_bosses_killed or t.Heroic or t.h or 0
                            local m = t.mythic or t.mythic_bosses_killed or t.Mythic or t.m or 0
                            local bosses = t.bossCount or t.boss_count or t.total_bosses or t.bosses or 9
                            if not raidDataFound[rname] then raidDataFound[rname] = {n=0, h=0, m=0, bosses=tonumber(bosses) or 9} end
                            raidDataFound[rname].n = math.max(raidDataFound[rname].n, tonumber(n) or 0)
                            raidDataFound[rname].h = math.max(raidDataFound[rname].h, tonumber(h) or 0)
                            raidDataFound[rname].m = math.max(raidDataFound[rname].m, tonumber(m) or 0)
                            return
                        end
                        for k, v in pairs(t) do
                            if type(v) == "table" then MineRaidData(v, depth + 1) end
                        end
                    end
                    MineRaidData(self.rioProfile, 1)
                    
                    local addedRaidHeader = false
                    for rname, data in pairs(raidDataFound) do
                        local rightText = ""
                        if data.n > 0 then rightText = rightText .. "|cff1eff00N|r " .. data.n .. "/" .. data.bosses .. " " end
                        if data.h > 0 then rightText = rightText .. "|cff0070ddH|r " .. data.h .. "/" .. data.bosses .. " " end
                        if data.m > 0 then rightText = rightText .. "|cffa335eeM|r " .. data.m .. "/" .. data.bosses .. " " end
                        
                        rightText = rightText:match("^(.-)%s*$")
                        if rightText ~= "" then
                            if not addedRaidHeader then
                                GameTooltip:AddLine(" ")
                                GameTooltip:AddLine("Raider.IO Raid Progress", 1, 0.8, 0)
                                addedRaidHeader = true
                            end
                            GameTooltip:AddDoubleLine(rname, rightText, 1, 1, 1, 1, 1, 1)
                        end
                    end
                end
            else
                GameTooltip:SetText("Applicant", 1, 1, 1)
            end

            if self.fullComment and self.fullComment ~= "" then
                if GameTooltip:NumLines() > 0 then GameTooltip:AddLine(" ") end
                GameTooltip:AddLine("Applicant Note:", 1, 0.8, 0)
                GameTooltip:AddLine(self.fullComment, 0.85, 0.85, 0.85, true) 
            end
            
            GameTooltip:Show()
        end
    end)
    
    row:SetScript("OnLeave", function(self) 
        self.hoverBg:Hide() 
        self._oakShiftTooltipState = nil
        self:SetScript("OnUpdate", nil)
        GameTooltip:Hide()
    end)

    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnDoubleClick", function(self)
        if self.searchResultID then
            if addonTable.ApplyToSearchResult then
                addonTable.ApplyToSearchResult(self.searchResultID)
            end
        elseif self.groupID then 
            C_LFGList.InviteApplicant(self.groupID)
            if self.inviteBtn then
                if self.searchResult == nil and self.bg then
                    self.bg:SetColorTexture(0.12, 0.32, 0.16, 0.55)
                end
                self.applicationStatus = "invited"
                self.groupApplicationStatus = "invited"
                self.inviteBtn:Hide()
                self.declineBtn:Hide()
                self.statusText:SetText("Invited")
                self.statusText:Show()
            end 
        end
    end)

    row.roleIcon = row:CreateTexture(nil, "OVERLAY")
    row.roleIcon:SetSize(16, 16)
    row.roleIcon:SetPoint("CENTER", row, "LEFT", R_ROLE.x + (R_ROLE.w / 2), 0)
    row.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")

    row.nameText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    row.regionText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.regionText:SetJustifyH("RIGHT")
    row.regionText:Hide()
    row.dungeonText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontSmall")
    row.specText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    row.specText:SetJustifyH("CENTER")
    row.ilvlText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    row.ratingText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    row.keyText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    row.noteText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    row.noteText:SetTextColor(0.7, 0.7, 0.7) 
    if OakLFGSorterDB and OakLFGSorterDB.hideNotes then
        row.noteText:Hide()
    end

    row.compSlots = {}
    local compRoles = { "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER" }
    -- COMP_SLOT_SIZE/ICON/SPACING are file-scope constants
    local compSlotOffset = math.floor((BR_COMP.w - COMP_TOTAL_SPAN) / 2)
    for index, role in ipairs(compRoles) do
        local slot = CreateFrame("Frame", nil, row, "BackdropTemplate")
        slot:SetSize(COMP_SLOT_SIZE, COMP_SLOT_SIZE)
        slot:SetPoint("LEFT", row, "LEFT", BR_COMP.x + compSlotOffset + ((index - 1) * COMP_SLOT_SPACING), 0)
        slot:SetBackdrop({ bgFile = addonTable.FLAT_TEX, edgeFile = addonTable.FLAT_TEX, edgeSize = 1 })
        slot:SetBackdropBorderColor(0, 0, 0, 1)
        slot:SetBackdropColor(0.10, 0.10, 0.12, 0.95)
        slot.icon = slot:CreateTexture(nil, "OVERLAY")
        slot.icon:SetSize(COMP_SLOT_ICON, COMP_SLOT_ICON)
        slot.icon:SetPoint("CENTER", slot, "CENTER", 0, 0)
        slot.icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        row.compSlots[index] = slot
    end

    row.ageText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    row.ageText:SetJustifyH("CENTER")
    row.ageText:Hide()

    ConfigureApplicantRowLayout(row)

    row.declineBtn = CreateFrame("Button", nil, row)
    row.declineBtn:SetSize(20, 20)
    row.declineBtn:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    row.declineBtn:SetNormalTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
    row.declineBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
    row.declineBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Decline", 1, 0.2, 0.2)
        GameTooltip:Show()
    end)
    row.declineBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    -- Static OnClick: reads groupID at call time — no closure over mutable data
    row.declineBtn:SetScript("OnClick", function(self)
        local r = self:GetParent()
        if r.groupID then
            C_LFGList.DeclineApplicant(r.groupID)
        end
    end)

    row.inviteBtn = CreateFrame("Button", nil, row)
    row.inviteBtn:SetSize(20, 20)
    row.inviteBtn:SetPoint("RIGHT", row.declineBtn, "LEFT", -10, 0)
    row.inviteBtn:SetNormalTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
    row.inviteBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
    -- Static OnClick: handles both browser (apply/cancel) and applicant (invite) modes
    row.inviteBtn:SetScript("OnClick", function(self)
        local r = self:GetParent()
        if r.searchResult then
            -- Browser mode
            local result = r.searchResult
            if addonTable.IsAppliedStatus and addonTable.IsAppliedStatus(result.applicationStatus) then
                C_LFGList.CancelApplication(result.id)
            else
                if not CanApplyToSearchResult() then
                    return
                end
                if addonTable.ApplyToSearchResult then
                    addonTable.ApplyToSearchResult(result.id)
                end
                addonTable.UpdateDisplay()
            end
        elseif r.groupID then
            -- Applicant mode
            C_LFGList.InviteApplicant(r.groupID)
            if r.searchResult == nil and r.bg then
                r.bg:SetColorTexture(0.12, 0.32, 0.16, 0.55)
            end
            r.applicationStatus = "invited"
            r.groupApplicationStatus = "invited"
            self:Hide()
            r.declineBtn:Hide()
            r.statusText:SetText("Invited")
            r.statusText:Show()
        end
    end)
    -- Static OnEnter: tooltip text depends on current row state at hover time
    row.inviteBtn:SetScript("OnEnter", function(self)
        local r = self:GetParent()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if r.searchResult then
            local result = r.searchResult
            if addonTable.IsAppliedStatus and addonTable.IsAppliedStatus(result.applicationStatus) then
                if result.isRoleFilled then
                    GameTooltip:SetText("Role Filled - Cancel", 1, 0.82, 0.30)
                else
                    GameTooltip:SetText("Cancel", 1, 0.2, 0.2)
                end
            else
                if CanApplyToSearchResult() then
                    GameTooltip:SetText("Apply", 0.2, 1, 0.2)
                else
                    GameTooltip:SetText(L["Cannot Apply While Listing"], 1.0, 0.82, 0.30)
                    GameTooltip:AddLine(L["You cannot sign up for another group while your own group is listed."], 1, 1, 1, true)
                end
            end
        else
            GameTooltip:SetText("Invite", 0.2, 1, 0.2)
        end
        GameTooltip:Show()
    end)
    row.inviteBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    row.statusText = row:CreateFontString(nil, "OVERLAY", "OakLFG_FontRegular")
    row.statusText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    row.statusText:SetTextColor(0.2, 1, 0.2)
    row.statusText:Hide()

    return row
end

function addonTable.ApplyHideNotesLayout(preserveLeftEdge)
    local hideNotes = OakLFGSorterDB and OakLFGSorterDB.hideNotes
    local targetWidth = GetTargetFrameWidth()
    local showSecondaryMetric = UsesSecondaryMetricColumn()
    local rowNoteColumn = GetCurrentRowNoteColumn()
    local isBrowser = IsBrowserMode()

    if not showSecondaryMetric and addonTable.CurrentSortBy == "key" then
        addonTable.CurrentSortBy = "rating"
        addonTable.CurrentIsAscending = false
    end

    local isRaidBrowser = IsRaidBrowserMode()
    local isPvpBrowser = IsPvpBrowserMode()
    local isCustomBrowser = IsCustomCategoryBrowserMode()
    for _, row in ipairs(rows) do
        if row.keyText then
            if showSecondaryMetric then row.keyText:Show() else row.keyText:Hide() end
        end
        if row.noteText then
            if isBrowser then
                if isRaidBrowser then
                    ConfigureRaidBrowserRowLayout(row)
                elseif isCustomBrowser then
                    local customMemberCount = row.searchResult and (tonumber(row.searchResult.numMembers) or #(row.searchResult.players or {})) or 0
                    if customMemberCount <= 5 then
                        ConfigureBrowserRowLayout(row)
                    else
                        ConfigureCustomBrowserRowLayout(row)
                    end
                elseif isPvpBrowser and row.searchResult and IsRatedBattlegroundResult(row.searchResult) then
                    ConfigureRbgBrowserRowLayout(row)
                elseif isPvpBrowser then
                    ConfigurePvpBrowserRowLayout(row)
                else
                    ConfigureBrowserRowLayout(row)
                end
            else
                ConfigureApplicantRowLayout(row)
            end
        end
        if row.noteText then
            if hideNotes then row.noteText:Hide() else row.noteText:Show() end
        end
        if row.dungeonText then
            if isBrowser then row.dungeonText:Show() else row.dungeonText:Hide() end
        end
        if row.roleIcon then
            if isBrowser then row.roleIcon:Hide() else row.roleIcon:Show() end
        end
        if row.ilvlText then
            if isBrowser then
                local usesSummaryComp = isRaidBrowser
                    or (isCustomBrowser and (row.searchResult and (tonumber(row.searchResult.numMembers) or #(row.searchResult.players or {})) or 0) > 5)
                    or (row.searchResult and IsRatedBattlegroundResult(row.searchResult))
                if usesSummaryComp then row.ilvlText:Show() else row.ilvlText:Hide() end
            else
                row.ilvlText:Show()
            end
        end
        if row.specText then
            -- In non-raid browser: hidden; in raid browser: Difficulty column; in applicant: Spec column
            if isBrowser then
                if isRaidBrowser then row.specText:Show() else row.specText:Hide() end
            else
                row.specText:Show()
            end
        end
        if row.keyText then
            -- In browser, keyText is replaced by ageText; in applicant, depends on mode
            if isBrowser then
                row.keyText:Hide()
            elseif showSecondaryMetric then
                row.keyText:Show()
            else
                row.keyText:Hide()
            end
        end
        if row.ageText then
            if isBrowser then row.ageText:Show() else row.ageText:Hide() end
        end
        if row.compSlots then
            for _, slot in pairs(row.compSlots) do
                -- Raid browser: comp slots hidden (ilvlText shows role counts instead)
                local usesSummaryComp = isRaidBrowser
                    or (isCustomBrowser and (row.searchResult and (tonumber(row.searchResult.numMembers) or #(row.searchResult.players or {})) or 0) > 5)
                if isBrowser and usesSummaryComp then
                    slot:Hide()
                elseif isBrowser then
                    slot:Show()
                else
                    slot:Hide()
                end
            end
        end
        -- In browser: pin the apply/cancel button to the row's right edge.
        -- We intentionally do NOT use noteCol.x + offset here because in raid-browser
        -- collapsed mode BR_RAID_NOTE.x + 27 = 517 which exceeds the 500px scrollChild
        -- width (535px frame − 10 left − 25 scrollbar), clipping the button off-screen.
        -- Note text is left-justified and never reaches the far-right anyway.
        if isBrowser and row.inviteBtn then
            row.inviteBtn:ClearAllPoints()
            row.inviteBtn:SetPoint("RIGHT", row, "RIGHT", GetBrowserInviteRightInset(), 0)
        end
    end

    -- Also update sticky rows (always browser-mode layout)
    for _, row in ipairs(stickyRows) do
        if row.keyText then row.keyText:Hide() end
        if row.noteText then
            if isRaidBrowser then
                ConfigureRaidBrowserRowLayout(row)
            elseif isCustomBrowser then
                ConfigureCustomBrowserRowLayout(row)
            else
                ConfigureBrowserRowLayout(row)
            end
            if hideNotes then row.noteText:Hide() else row.noteText:Show() end
        end
        if row.dungeonText then row.dungeonText:Show() end
        if row.roleIcon then row.roleIcon:Hide() end
        if row.ilvlText then
            if isRaidBrowser then row.ilvlText:Show() else row.ilvlText:Hide() end
        end
        if row.specText then
            if isRaidBrowser then row.specText:Show() else row.specText:Hide() end
        end
        if row.ageText then row.ageText:Show() end
        if row.compSlots then
            for _, slot in pairs(row.compSlots) do
                if isRaidBrowser then slot:Hide() else slot:Show() end
            end
        end
        if row.inviteBtn then
            row.inviteBtn:ClearAllPoints()
            row.inviteBtn:SetPoint("RIGHT", row, "RIGHT", GetBrowserInviteRightInset(), 0)
        end
    end

    SetFrameWidthPreservingLeft(targetWidth, preserveLeftEdge)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    UpdateNotesToggleLayout()
    UpdateNotesToggleVisual()

    if addonTable.UpdateTopBarLayout then
        addonTable.UpdateTopBarLayout()
    end

    if addonTable.UpdateDisplay then
        addonTable.UpdateDisplay()
    end
end

notesToggleBtn:SetScript("OnClick", function()
    OakLFGSorterDB.hideNotes = not OakLFGSorterDB.hideNotes
    addonTable.ApplyHideNotesLayout(true)
end)
noteVisibilityBtn:SetScript("OnClick", function()
    OakLFGSorterDB.hideNotes = true
    addonTable.ApplyHideNotesLayout(true)
end)

UpdateNotesToggleLayout()
UpdateNotesToggleVisual()
addonTable.ApplyHideNotesLayout()

-- Shared helper: populate a browser-mode row (used for both sticky and scroll rows)
PopulateBrowserRow = function(row, result, isAltColor)
    row.searchResultID = result.id
    row.searchResult = result
    row.groupID = nil
    row.applicantID = nil
    row.memberIdx = nil
    row.fullComment = result.comment
    row.rioProfile = nil          -- browser rows: RIO profile fetched lazily in BuildBrowserGroupTooltip
    row.memberRating = result.rating
    row.memberPvpRating = result.pvpRating
    row.memberPvpBracket = result.pvpBracket
    row.memberRaidProgress = result.raidProgress  -- non-nil only for raid/legacy_raid mode
    row.regionInfo = result.regionInfo

    row.bg:SetColorTexture(GetBrowserRowColor(result, isAltColor))

    -- Use the search context mode to determine layout: world bosses have result.mode="open_world"
    -- but should still render with the raid column layout when searched in a raid context.
    local searchCtxMode = GetListingMode()
    local isRaidMode = (result.mode == "raid" or result.mode == "legacy_raid")
                    or (IsBrowserMode() and (searchCtxMode == "raid" or searchCtxMode == "legacy_raid"))
    local isCustomCategory = IsCustomCategoryBrowserMode()
    local isPvpMode = not isCustomCategory and (result.mode == "pvp" or result.mode == "rated_pvp")
    local isRbgMode = isPvpMode and IsRatedBattlegroundResult(result)
    local hideNotes = OakLFGSorterDB and OakLFGSorterDB.hideNotes

    if isRaidMode then
        ConfigureRaidBrowserRowLayout(row)
    elseif isCustomCategory then
        if (tonumber(result.numMembers) or #(result.players or {})) <= 5 then
            ConfigureBrowserRowLayout(row)
        else
            ConfigureCustomBrowserRowLayout(row)
        end
    elseif isRbgMode then
        ConfigureRbgBrowserRowLayout(row)
    elseif isPvpMode then
        ConfigurePvpBrowserRowLayout(row)
    else
        ConfigureBrowserRowLayout(row)
    end
    row.dungeonText:Show()
    row.roleIcon:Hide()
    if not isRaidMode and not isRbgMode and not (isCustomCategory and (tonumber(result.numMembers) or #(result.players or {})) > 5) then row.ilvlText:Hide() end
    row.keyText:Hide()
    if row.ageText then row.ageText:Show() end

    -- specText: hidden in non-raid browser, shown as Difficulty in raid browser
    if isRaidMode then
        row.specText:SetJustifyH("CENTER")
        row.specText:Show()
    else
        row.specText:Hide()
    end

    if row.inviteBtn then
        -- Always anchor to right edge in browser mode; noteCol.x + offset is unreliable
        -- in raid-browser collapsed mode because BR_RAID_NOTE.x + 27 = 517 exceeds the
        -- 500px scrollChild width, pushing the button completely off-screen.
        row.inviteBtn:ClearAllPoints()
        row.inviteBtn:SetPoint("RIGHT", row, "RIGHT", GetBrowserInviteRightInset(), 0)
    end
    if isRaidMode then
        -- Raid mode: hide comp slots, show Tank/Healer/DPS counts in ilvlText
        for _, slot in pairs(row.compSlots) do slot:Hide() end
        local rc = result.roleCounts or {}
        local tanks   = tonumber(rc.TANK)    or 0
        local healers = tonumber(rc.HEALER)  or 0
        local dps     = tonumber(rc.DAMAGER) or 0
        row.ilvlText:SetWordWrap(false)
        row.ilvlText:SetText(addonTable.RoleIconMarkup.TANK .. tanks .. "  " .. addonTable.RoleIconMarkup.HEALER .. healers .. "  " .. addonTable.RoleIconMarkup.DAMAGER .. dps)
        row.ilvlText:Show()
    elseif isRbgMode then
        for _, slot in pairs(row.compSlots) do slot:Hide() end
        local rc = result.roleCounts or {}
        local tanks   = tonumber(rc.TANK)    or 0
        local healers = tonumber(rc.HEALER)  or 0
        local dps     = tonumber(rc.DAMAGER) or 0
        row.ilvlText:SetWordWrap(false)
        row.ilvlText:SetText(addonTable.RoleIconMarkup.TANK .. tanks .. "  " .. addonTable.RoleIconMarkup.HEALER .. healers .. "  " .. addonTable.RoleIconMarkup.DAMAGER .. dps)
        row.ilvlText:Show()
    elseif isPvpMode then
        -- PVP/Arena mode: show spec/class icons for each member (max 3 slots), hide slots 4-5
        row.ilvlText:Hide()
        local players = result.players or {}
        for idx = 1, 5 do
            local slot = row.compSlots[idx]
            if idx > 3 then
                slot:Hide()
            else
                local player = players[idx]
                local specID = ResolveSpecID(player and player.specID, player and player.specName, player and player.class)
                slot:Show()
                SetBrowserCompSlotSpec(slot, specID, player and player.class, player ~= nil)
            end
        end
    else
        -- Non-raid browser mode: show comp slots (role icons), hide ilvlText
        local setupSummary = GetBrowserSetupSummary(result)
        if isCustomCategory and (tonumber(result.numMembers) or #(result.players or {})) > 5 then
            for _, slot in pairs(row.compSlots) do slot:Hide() end
            local rc = result.roleCounts or {}
            local tanks   = tonumber(rc.TANK)    or 0
            local healers = tonumber(rc.HEALER)  or 0
            local dps     = tonumber(rc.DAMAGER) or 0
            row.ilvlText:SetWordWrap(false)
            row.ilvlText:SetText(addonTable.RoleIconMarkup.TANK .. tanks .. "  " .. addonTable.RoleIconMarkup.HEALER .. healers .. "  " .. addonTable.RoleIconMarkup.DAMAGER .. dps)
            row.ilvlText:Show()
        else
            row.ilvlText:Hide()
            local showSpecIcons = OakLFGSorterDB and OakLFGSorterDB.showSpecIcons
            local sortedPlayers = {}
            local usedPlayers = {}
            if showSpecIcons then
                local roleOrder = { TANK = 1, HEALER = 2, DAMAGER = 3 }
                for _, player in ipairs(result.players or {}) do
                    table.insert(sortedPlayers, player)
                end
                table.sort(sortedPlayers, function(a, b)
                    return (roleOrder[a.role] or 99) < (roleOrder[b.role] or 99)
                end)
            end
            for idx, slotInfo in ipairs(setupSummary) do
                local slot = row.compSlots[idx]
                slot:Show()
                if showSpecIcons and slotInfo.filled then
                    local player = nil
                    for playerIndex, candidate in ipairs(sortedPlayers) do
                        if not usedPlayers[playerIndex] and candidate.role == slotInfo.role then
                            player = candidate
                            usedPlayers[playerIndex] = true
                            break
                        end
                    end
                    local specID = ResolveSpecID(player.specID, player.specName, player.class or slotInfo.class)
                    SetBrowserCompSlotSpec(slot, specID, player.class or slotInfo.class, true)
                else
                    SetBrowserCompSlot(slot, slotInfo.role, slotInfo.class, slotInfo.filled)
                end
            end
        end
    end

    if isRaidMode then
        -- Title column: pure listing title (difficulty is its own column now)
        local title = (result.displayName ~= "" and result.displayName)
                   or (result.activityName ~= "" and result.activityName) or "--"
        row.nameText:SetText(title)

        -- Difficulty column (specText): blank for world bosses with no difficulty
        local diffLabel = result.raidListing and result.raidListing.difficultyLabel or ""
        row.specText:SetText(diffLabel ~= "" and GetColoredRaidDifficultyLabel(diffLabel) or "")

        -- Kills column: Core already formats progressText as "X/Y" or "N"
        local rl = result.raidListing
        local killsText = (rl and rl.progressText and rl.progressText ~= "" and rl.progressText ~= "--")
                          and rl.progressText or "--"
        row.ratingText:SetText(killsText)
    else
        row.nameText:SetText(result.displayName ~= "" and result.displayName or (result.activityName ~= "" and result.activityName or "--"))
        -- For PVP mode: re-fetch pvp rating fresh from the API (may have been nil at initial processing time)
        if isPvpMode and result.id and C_LFGList.GetSearchResultInfo then
            local fresh = C_LFGList.GetSearchResultInfo(result.id)
            if fresh and type(fresh.leaderPvpRatingInfo) == "table" then
                -- TWW wraps pvp info in an array; unwrap to get the actual entry
                local entry = fresh.leaderPvpRatingInfo[1] or fresh.leaderPvpRatingInfo
                if type(entry) == "table" then
                    local freshRating = tonumber(entry.rating or entry.pvpRating or entry.currentRating or entry.value) or 0
                    if freshRating > 0 then
                        result.pvpRating = freshRating
                        result.rating    = freshRating
                    end
                    if not result.pvpBracket and GetPvpBracketLabel then
                        result.pvpBracket = GetPvpBracketLabel(entry)
                    end
                end
            end
        end
        row.ratingText:SetText(GetBrowserRatingDisplay(result))
    end

    if row.ageText then
        if addonTable.IsDeclinedStatus and addonTable.IsDeclinedStatus(result.applicationStatus) then
            row.ageText:SetText("Declined")
            row.ageText:SetTextColor(1, 0.2, 0.2)
        elseif result.applicationStatus == "invited" or result.applicationStatus == "inviteaccepted" then
            row.ageText:SetText("Invited")
            row.ageText:SetTextColor(0.2, 1, 0.2)
        elseif result.isRoleFilled then
            row.ageText:SetText("Filled")
            row.ageText:SetTextColor(1.0, 0.82, 0.30)
        elseif addonTable.IsAppliedStatus and addonTable.IsAppliedStatus(result.applicationStatus) then
            row.ageText:SetText("Pending")
            row.ageText:SetTextColor(0.2, 1, 0.2)
        else
            row.ageText:SetText(FormatAge(result.age))
            row.ageText:SetTextColor(1, 1, 1)
        end
    end

    row.noteText:SetText(result.comment or "")
    if isPvpMode then
        local bracketText
        if isRbgMode then
            bracketText = "RBG"
        else
            bracketText = result.pvpBracket
                or (result.maxPlayers == 2 and "2v2")
                or (result.maxPlayers == 3 and "3v3")
                or (result.dungeonName ~= "" and result.dungeonName or "--")
        end
        row.dungeonText:SetText(bracketText)
    else
        row.dungeonText:SetText(result.dungeonName ~= "" and result.dungeonName or "--")
    end
    if result.mode == "delve" and addonTable.IsCurrentBountifulDelve and addonTable.IsCurrentBountifulDelve(result.activityFilterLabel or result.dungeonName or result.activityName) then
        row.dungeonText:SetTextColor(1.0, 0.82, 0.20)
    else
        row.dungeonText:SetTextColor(1, 1, 1)
    end

    row.statusText:Hide()
    row.declineBtn:Hide()
    row.inviteBtn:Show()
    -- Texture only — OnClick/OnEnter/OnLeave are static handlers set once in CreateRow
    if addonTable.IsAppliedStatus and addonTable.IsAppliedStatus(result.applicationStatus) then
        row.inviteBtn:SetNormalTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
    else
        row.inviteBtn:SetNormalTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
    end
    local inviteTexture = row.inviteBtn:GetNormalTexture()
    if inviteTexture then
        local isApplied = addonTable.IsAppliedStatus and addonTable.IsAppliedStatus(result.applicationStatus)
        local canApply = isApplied or CanApplyToSearchResult()
        inviteTexture:SetDesaturated(not isApplied and not canApply)
        inviteTexture:SetAlpha((isApplied or canApply) and 1 or 0.55)
    end
end

function addonTable.UpdateDisplay()
    browserRenderGeneration = browserRenderGeneration + 1
    if addonTable.RefreshBrowserResponsiveLayout and IsBrowserMode() then
        addonTable.RefreshBrowserResponsiveLayout()
    end
    addonTable.UpdateGroupBuffs()
    if addonTable.UpdateTopBarActions then
        addonTable.UpdateTopBarActions()
    end
    UpdateApplicantContextBar()
    addonTable.UpdateHeaderVisuals()
    UpdateNotesToggleLayout()

    -- Hide rows AND clear their data references so stale result entries can be GC'd.
    -- Without this, hidden rows keep old players/memberCounts/roleCounts tables alive
    -- even after those results have been removed from addonTable.SearchResults.
    for _, row in ipairs(rows) do
        row:Hide()
        row.searchResult    = nil
        row.rioProfile      = nil
        row.memberRaidProgress = nil
        row.fullComment     = nil
        row.regionInfo      = nil
    end
    for _, row in ipairs(stickyRows) do
        row:Hide()
        row.searchResult    = nil
        row.rioProfile      = nil
        row.memberRaidProgress = nil
        row.fullComment     = nil
        row.regionInfo      = nil
    end
    browserAppliedSeparator:Hide()
    emptyStateText:Hide()

    local isBrowser = IsBrowserMode()
    if addonTable.quickSignupBar then
        if isBrowser then
            addonTable.quickSignupBar:Show()
        else
            addonTable.quickSignupBar:Hide()
        end
    end
    -- Reset sticky state when in applicant mode so it doesn't bleed over
    if not isBrowser and stickyPanelHeight ~= 0 then
        stickyPanelHeight = 0
        UpdateApplicantContextLayout()
    end
    local displayIndex = 1
    local isAltColor = false
    local showSecondaryMetric = UsesSecondaryMetricColumn()

    if isBrowser then
        addonTable._browserRuntimeFilters = addonTable.BuildBrowserRuntimeFilters and addonTable.BuildBrowserRuntimeFilters() or nil
        local activeResults = {}
        for _, result in ipairs(addonTable.SearchResults or {}) do
            result.isRoleFilled = addonTable.IsAppliedRoleFilled and addonTable.IsAppliedRoleFilled(result) or false
            -- Groups the player has applied to are always shown regardless of filters
            -- so the user can always see and cancel their pending sign-ups.
            local isApplied = addonTable.IsAppliedStatus and addonTable.IsAppliedStatus(result.applicationStatus)
            if isApplied or not addonTable.ResultPassesBrowserFilters or addonTable.ResultPassesBrowserFilters(result) then
                table.insert(activeResults, result)
            end
        end

        -- Update "Showing X of Y groups" in the footer
        if addonTable.groupCountText then
            local total = #(addonTable.SearchResults or {})
            local shown = #activeResults
            addonTable.groupCountText:SetText(string.format("Showing %d of %d groups", shown, total))
        end

        table.sort(activeResults, function(a, b)
            return SortGroups(a, b, addonTable.CurrentSortBy, addonTable.CurrentIsAscending)
        end)

        -- Hide all sticky rows before re-rendering (data already cleared by the top-of-display loop)
        for _, row in ipairs(stickyRows) do row:Hide() end
        browserAppliedSeparator:Hide()

        -- Split activeResults: applied groups go to sticky panel, rest scroll normally
        local appliedResults = {}
        local normalResults = {}
        for _, r in ipairs(activeResults) do
            if GetBrowserApplicationPriority(r) >= 3 then
                table.insert(appliedResults, r)
            else
                table.insert(normalResults, r)
            end
        end

        -- Render applied groups into the sticky panel (always visible above scroll)
        local stickyIndex = 1
        for _, result in ipairs(appliedResults) do
            if not stickyRows[stickyIndex] then
                local prevRow = stickyRows[stickyIndex - 1]  -- nil for first row
                stickyRows[stickyIndex] = CreateRow(stickyIndex, stickyPanel, prevRow)
            end
            local sRow = stickyRows[stickyIndex]
            PopulateBrowserRow(sRow, result, stickyIndex % 2 == 0)
            sRow:Show()
            stickyIndex = stickyIndex + 1
        end

        -- Update sticky panel height and reposition scroll frame accordingly
        stickyPanelHeight = #appliedResults * ROW_HEIGHT
        UpdateApplicantContextLayout()

        scrollChild:SetHeight(math.max(1, #normalResults * ROW_HEIGHT))
        if #normalResults > 0 then
            QueueBrowserRowRender(normalResults, 1, browserRenderGeneration)
        end

        local categoryKey = addonTable.CurrentSearchContext and addonTable.CurrentSearchContext.selectedCategoryKey
        if #activeResults == 0 and categoryKey == "RAIDS_LEGACY" then
            emptyStateText:SetText("Legacy raid results must be loaded from Blizzard's Premade Groups panel first.\n\nOpen Blizzard's Group Finder, select Legacy Raids there, then Oak will display those results here.")
            emptyStateText:Show()
        end
        addonTable._browserRuntimeFilters = nil
        return
    else
        local activeGroups = {}
        for _, group in ipairs(addonTable.ApplicantGroups) do
            if addonTable.GroupPassesFilters(group) then
                table.insert(activeGroups, group)
            end
        end

        table.sort(activeGroups, function(a, b)
            return SortGroups(a, b, addonTable.CurrentSortBy, addonTable.CurrentIsAscending)
        end)

        for _, group in ipairs(activeGroups) do
            local isMulti = group.numMembers > 1
            local actionRowIndex = isMulti and math.ceil(group.numMembers / 2) or 1
            local bgColor = { GetApplicantRowColor(group, isAltColor) }
            local applicantStatusText = GetApplicantStatusText(group)

            for i, member in ipairs(group.members) do
                if not rows[displayIndex] then rows[displayIndex] = CreateRow(displayIndex) end
            local row = rows[displayIndex]

                row.searchResultID = nil
                row.searchResult = nil
                row.groupID = group.id
                row.applicantID = group.id
                row.memberIdx = member.memberIdx
                row.applicationStatus = group.applicationStatus
                row.groupApplicationStatus = group.applicationStatus
                row.memberName = member.name
                row.fullComment = group.comment
                row.rioProfile = member.rioProfile
                row.memberRating = member.rating
                row.memberPvpRating = member.pvpRating
                row.memberPvpBracket = member.pvpBracket
                row.memberRaidProgress = member.raidProgress
                row.regionInfo = addonTable.GetRegionInfoFromLeaderName and addonTable.GetRegionInfoFromLeaderName(member.name) or nil

                row.bg:SetColorTexture(unpack(bgColor))
                ConfigureApplicantRowLayout(row)
                row.dungeonText:Hide()
                row.roleIcon:Show()
                row.ilvlText:Show()
                for _, slot in pairs(row.compSlots) do
                    slot:Hide()
                end

                local coords = addonTable.RoleTexCoords[member.role]
                if coords then
                    row.roleIcon:SetTexCoord(unpack(coords))
                    row.roleIcon:Show()
                else
                    row.roleIcon:Hide()
                end

                local specIconText
                if OakLFGSorterDB and OakLFGSorterDB.showSpecIcons and member.specID then
                    local _, _, _, icon = GetSpecializationInfoByID(member.specID)
                    if icon then
                        specIconText = string.format("|T%s:16:16:0:0:64:64:5:59:5:59|t", icon)
                    end
                end

                if specIconText then
                    row.specText:SetText(specIconText)
                else
                    local specAbbr = addonTable.SpecShortNames and addonTable.SpecShortNames[member.specID] or ""
                    row.specText:SetText(addonTable.ApplyClassColor(specAbbr, member.class))
                end

                local formattedName = addonTable.ApplyClassColor(member.name, member.class)
                if member.isFriend then
                    formattedName = "|TInterface\\ChatFrame\\UI-ChatIcon-Battlenet:14|t " .. formattedName
                end
                if member.isLeaver then
                    formattedName = "|cffff4040<!>|r " .. formattedName
                end
                if isMulti then
                    formattedName = (i == 1) and " " .. formattedName or " > " .. formattedName
                end

                row.nameText:SetText(formattedName)
                row.ilvlText:SetText(member.ilvl)
                row.ratingText:SetText(GetMemberRatingDisplay(member))
                row.keyText:SetText(GetMemberSecondaryDisplay(member))
                if showSecondaryMetric then row.keyText:Show() else row.keyText:Hide() end

                if i == 1 then
                    row.noteText:SetText(group.comment or "")
                else
                    row.noteText:SetText("")
                end

                if i == actionRowIndex then
                    -- Restore applicant-mode button positions (rows may have been used in browser mode
                    -- which repositions inviteBtn to the right edge, causing the two buttons to stack)
                    row.declineBtn:ClearAllPoints()
                    local buttonYOffset = 0
                    if isMulti and group.numMembers % 2 == 0 then
                        buttonYOffset = -math.floor(ROW_HEIGHT / 2)
                    end
                    row.declineBtn:SetPoint("RIGHT", row, "RIGHT", -5, buttonYOffset)
                    row.inviteBtn:ClearAllPoints()
                    row.inviteBtn:SetPoint("RIGHT", row.declineBtn, "LEFT", -10, 0)
                    if applicantStatusText then
                        row.inviteBtn:Hide()
                        row.declineBtn:Hide()
                        row.statusText:SetText(applicantStatusText)
                        row.statusText:SetTextColor(0.2, 1, 0.2)
                        row.statusText:Show()
                    else
                        row.statusText:Hide()
                        row.inviteBtn:Show()
                        row.declineBtn:Show()
                        local inviteTexture = row.inviteBtn:GetNormalTexture()
                        if inviteTexture then
                            inviteTexture:SetDesaturated(false)
                            inviteTexture:SetAlpha(1)
                        end
                    end
                else
                    row.inviteBtn:Hide()
                    row.declineBtn:Hide()
                    row.statusText:Hide()
                end

                row:Show()
                displayIndex = displayIndex + 1
            end

            isAltColor = not isAltColor
        end
    end

    addonTable._browserRuntimeFilters = nil
    scrollChild:SetHeight(math.max(1, (displayIndex - 1) * ROW_HEIGHT))
end
