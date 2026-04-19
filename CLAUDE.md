# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@AGENTS.md

---

## Development workflow

- **Testing**: Edit `.lua` files directly in the addon folder, then type `/reload` in WoW to pick up changes immediately. No build step required.
- **Release**: `.\release-addon.ps1 -Version X.Y.Z` — updates version refs in `.toc` and `UI_Header.lua`, writes changelog, commits, tags, and builds a zip to `dist/`. Run from the addon root in PowerShell.
- **Versioning**: Version must be updated in two places together — `## Version:` in `OakLFGSorter.toc` and `VersionText:SetText(...)` in `UI_Header.lua`.

Current shipped version: `3.0.13`

---

## Shared namespace pattern

All files receive `(addonName, addonTable)` via `local addonName, addonTable = ...` at the top. Cross-file communication happens exclusively through `addonTable`:

- `addonTable.OAK_LFG` — the main frame (created in `UI_Header.lua`, consumed everywhere)
- `addonTable.SearchResults` — browser results array (written by `Core.lua`, read by `UI_Rows.lua`)
- `addonTable.L` — locale lookup table (set up in `Init.lua`)
- `addonTable.CurrentBrowserMode` — active browser sub-mode string, set by `Core.lua`

Load order is defined by `.toc` and matters: `Init.lua` runs before UI files; `Core.lua` and `Search_Integration.lua` run last.

---

## Row rendering pipeline

When search results arrive, the flow is:

1. `Core.lua:ProcessSearchResults` → builds `addonTable.SearchResults`
2. `UI_Rows.lua:RenderBrowserRows` → iterates results, calls `PopulateBrowserRow` per row
3. `PopulateBrowserRow` → calls layout helpers (`SetBrowserCompSlotSpec`, `ApplyHideNotesLayout`, etc.) and re-fetches live data from `C_LFGList.GetSearchResultInfo` for PVP ratings

The applicant mode follows the same frame but calls `RenderApplicantRows` instead, which reads fresh data directly from `C_LFGList` APIs rather than a cached array.

Browser comp rendering details:
- `UI_Rows.lua:GetBrowserSetupSummary` defines the fixed 5-man role-slot model: `TANK`, `HEALER`, `DAMAGER`, `DAMAGER`, `DAMAGER`
- `PopulateBrowserRow` decides whether a `Custom` listing renders as 5-man comp or raid-style role counts based on displayed member count
- When `OakLFGSorterDB.showSpecIcons` is enabled, 5-man browser comp uses spec icons but keeps those fixed role-slot positions
- PVP browser still uses its own 3-slot spec-icon path and should be treated separately

---

## Filter system

Filters are applied in `UI_Rows.lua` at render time (rows are shown/hidden, not removed). `UI_Filters.lua` owns the filter UI widgets and writes filter state to `OakLFGSorterDB.browserFilters`. `Search_FilterModes.lua` controls which filter widgets appear per activity category (M+, raid, PvP, etc.).

---

## Current status

- Applicant region filters are fixed and shipped. Applicant groups now respect the same shared region filter state as browser results.
- `Core.lua` now stores applicant-group `leadName` and `regionInfo`, and `UI_Filters.lua:GroupPassesFilters` applies region filtering to applicant groups.
- Mythic+ teleport support is fixed and shipped in `3.0.2`.
- Use `addonTable.GetDungeonTeleportSpellID(mapID)` from `Init.lua` for dungeon teleports. It resolves challenge-map data, prefers `QUI_DungeonData` when available, and falls back to built-in spell IDs.
- `Party_Keys.lua` and `MythicPlus_Panel.lua` both use that shared resolver now.
- The player's current key text in `MythicPlus_Panel.lua` is clickable for teleport when the portal spell is known.
- Do not anchor secure teleport buttons to `FontString`s or other regions. Anchor them directly to frames with explicit points.
- Browser comp behavior changed after `3.0.2` and is currently committed but unreleased:
  - `Custom` rows render 5-man comp when `numMembers <= 5`
  - `Custom` rows render raid-style role counts when `numMembers > 5`
  - 5-man browser rows use fixed-slot spec icons when `Show Spec Icons` is enabled
  - Browser rows show `Invited` in green for `invited` / `inviteaccepted` application states

## Current browser dungeon filter status

- The intended model is still to use Blizzard's native dungeon advanced filters and search behavior, not to replace them with an Oak-only dungeon search implementation.
- `Core.lua:RunBrowserSearch` prefers `LFGListSearchPanel_DoSearch(panel)` when Oak is already on Blizzard's active category so Blizzard remains the real search driver.
- `UI_Filters.lua:SyncBrowserNativeActivities` writes Oak's selected dungeon checkboxes into Blizzard's native `advancedFilter.activities`.
- `UI_Filters.lua:SyncBrowserSelectedActivitiesFromNative` reads Blizzard's native activity selection back into Oak's checkbox state.

Recent confirmed fix:
- The Magisters' Terrace browser-filter bug was caused by duplicate Blizzard activities sharing the same normalized dungeon label.
- `C_LFGList.GetAvailableActivities(categoryID)` returned both:
  - legacy BC Magisters activities with `groupFinderActivityGroupID = 37`
  - current-season Magisters activities with `groupFinderActivityGroupID = 399`
- Oak's label lookup was taking the first normalized match, which pointed Blizzard's `advancedFilter.activities` at the legacy group instead of the current-season group.
- `Core.lua:GetAvailableBrowserActivities` now prefers the activity with the highest `groupFinderActivityGroupID` when multiple activities collapse to the same normalized dungeon label.
- That fix restored Blizzard-pane syncing and full-result searching for Magisters' Terrace while keeping the Blizzard-native filter/search model intact.

Current browser dungeon status:
- All tested dungeon filters, including Magisters' Terrace, are now expected to sync correctly to Blizzard's native dungeon filter pane.
- A small local fallback remains in `UI_Filters.lua:ResultMatchesSelectedActivities` so Oak can match selected activity keys against normalized variants without replacing Blizzard's native search behavior.

Recommended future debugging rule:
1. If one dungeon breaks while others still sync, inspect duplicate Blizzard activities under the same normalized label first.
2. Check `groupFinderActivityGroupID` before attempting broader filter rewrites.
3. Keep Blizzard's native filter/search path as the source of truth for dungeon searches.

## Playstyle filter notes

- `Core.lua:ProcessSearchResults` already populates:
  - `playstyleValue`
  - `playstyleLabel`
  - `playstyleShortLabel`
- If Claude adds a playstyle filter, the likely touch points are:
  - `Init.lua` or existing DB-default wiring for any new saved filter fields
  - `UI_Filters.lua` for the control and `GroupPassesFilters`
  - `Search_FilterModes.lua` for per-browser-mode visibility
- Be conservative about category support. Blizzard playstyle data may be missing or inconsistent outside categories that explicitly use playstyle selection.
