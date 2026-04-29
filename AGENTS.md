# OakLFGSorter — AGENTS.md

## What this addon is

**Oakensoul LFG Sorter** is a World of Warcraft Retail addon (TWW, Interface 120001) for group leaders. It replaces Blizzard's default applicant list and group browser with a sortable, filterable window that supports Mythic+, raids, PvP (arena/rated), delves, and open-world content. The author is Smokenoaken (GitHub user). Published on Wago (`X-Wago-ID: 96d2nXGO`).

---

## Two primary modes

### Applicant mode
Shown when the player has an active LFG listing. Displays people who have applied to join — one row per member (multi-member groups span multiple rows). Sortable by role, class, spec, item level, M+ rating, highest key, and note.

### Browser mode
Shown when browsing public LFG listings (Mythic+, raid, PvP, delve, etc.). Each row is a listed group with columns: dungeon/activity, comp icons, title, rating, age, notes. The layout switches between sub-modes:
- **Default browser** — Dungeon | Comp (5 role-icon slots) | Title | Rating | Age | Notes
- **Raid browser** — Raid | Difficulty | Comp (role counts) | Title | Kills | Age | Notes
- **PVP browser** — Arena | Comp (3 spec-icon slots, larger) | Title | PVP Rating | Age | Notes

---

## File map

| File | Purpose |
|---|---|
| `OakLFGSorter.toc` | Addon metadata, load order, SavedVariables declaration |
| `Init.lua` | `OakLFGSorterDB` defaults, locale system, shared constants, font/color setup |
| `UI_Header.lua` | Main frame (`OAK_LFG`), title bar, scale/opacity controls, version text |
| `UI_Filters.lua` | Filter panel (role checkboxes, min rating, Party Fit, etc.), Blizzard UI hooks |
| `UI_Rows.lua` | **Everything row-related:** column constants, headers, row creation/population, comp slot rendering, tooltips, sorting, notes toggle, `ApplyHideNotesLayout` |
| `Core.lua` | WoW event handling, `ProcessSearchResults`, applicant data fetching, `GetListingMode`, `GetPvpBracketLabel`, slash commands |
| `RegionInfo.lua` | Region badge detection from realm names ([NA], [EU], [LATAM], etc.) |
| `Search_Config.lua` | Browser search activity categories and filter configurations |
| `Search_FilterModes.lua` | Per-mode filter panel setup (what checkboxes appear for M+ vs raid vs PvP) |
| `Search_Integration.lua` | Hooks into Blizzard's LFG browse panel; triggers OakLFG browser mode |
| `Search_Signup.lua` | Quick Sign Up bar at the bottom of the browser |
| `Supporters.lua` | Supporter list displayed in the footer |
| `Locales/` | Locale tables (enUS default, deDE, frFR, esES, esMX, ruRU) |

---

## Key data structures

### `addonTable.SearchResults` (browser mode)
Array of result entries built by `Core.lua:ProcessSearchResults`. Each entry:
```lua
{
  id,            -- searchResultID from C_LFGList
  mode,          -- "mythic_plus" | "rated_pvp" | "pvp" | "raid" | "legacy_raid" | "delve" | "open_world" | "generic"
  displayName,   -- formatted title string
  dungeonName,   -- activity filter label (e.g. "The War Within Season 2")
  activityName,  -- full activity name
  rating,        -- numeric: M+ score for dungeons; pvpRating for PVP; 0 otherwise
  pvpRating,     -- leader's PVP rating (rated_pvp / pvp modes)
  pvpBracket,    -- "2v2" | "3v3" | "Solo" | "Blitz" | "RBG" | nil
  players,       -- array of { name, role, class, specID, specName }
  maxPlayers,    -- from activityInfo.maxNumPlayers
  raidListing,   -- non-nil for raid mode: { difficultyLabel, progressText, raidName, ... }
  raidProgress,  -- RIO raid progress summary (raid mode only)
  playstyleValue, playstyleLabel, playstyleShortLabel,
  regionInfo,    -- { tag, isLocal } from RegionInfo.lua
  comment,       -- listing note
  age,           -- seconds since posted
  applicationStatus, pvpRating, pvpBracket, hasSelf, isRoleFilled, ...
}
```

### Applicant members (applicant mode)
Fetched fresh in `Core.lua`. Per-member fields include `name`, `class`, `role`, `specID`, `specName`, `ilvl`, `rating`, `pvpRating`, `pvpBracket`, `highestKey`, `rioProfile`.

---

## Important WoW API quirks

### `leaderPvpRatingInfo` is an array (TWW 11.x)
`C_LFGList.GetSearchResultInfo(id).leaderPvpRatingInfo` returns a **table with a numeric key `[1]`** whose value is the actual rating table. Always unwrap:
```lua
local entry = pvpInfo[1] or pvpInfo   -- unwrap the array
local rating = tonumber(entry.rating) or 0
```
`GetPvpBracketLabel` in `Core.lua` also performs this unwrap.

### PVP rating timing
`leaderPvpRatingInfo` is often nil when `ProcessSearchResults` first runs (data arrives async). Both `PopulateBrowserRow` and `BuildBrowserGroupTooltip` re-call `C_LFGList.GetSearchResultInfo(result.id)` at render/tooltip time to get fresh data.

### Spec icons in browser mode
`C_LFGList.GetSearchResultPlayerInfo` may return `specName` but not `specID` for some group members. `UI_Rows.lua` maintains a `specNameToID` lookup table (built from all ~40 known TWW spec IDs at load time via `GetSpecializationInfoByID`) to resolve spec icons from name when ID is absent.

For 5-player browser comp, `Show Spec Icons` now preserves fixed role-slot order:
- slot 1 = `TANK`
- slot 2 = `HEALER`
- slots 3-5 = `DAMAGER`

This applies to normal 5-man browser rows and to `Custom` rows when the listing has `<= 5` members. The icons should not follow raw player order.

### Class icon atlas
WoW atlas names follow the pattern `"classicon-" .. strlower(classFilename)` (e.g. `"classicon-deathknight"`). Used as fallback in `SetBrowserCompSlotSpec` when both specID and specName lookups fail.

---

## Column layout constants (UI_Rows.lua)

All x values are absolute positions from the left edge of `OAK_LFG`. Row columns use `RowColumn(B_*)` which subtracts `ROW_X_OFFSET = 10`.

```
Default browser:  Dungeon(10,145) | Comp(155,103) | Title(258,102) | Rating(360,70) | Age(430,45) | Note(475,130)
Raid browser:     Raid(10,120) | Diff(130,65) | Comp(195,103) | Title(298,107) | Kills(405,50) | Age(455,45) | Note(500,105)
PVP browser:      Arena(10,88) | Comp(98,72) | Title(170,120) | PVPRating(290,80) | Age(370,45) | Note(415,190)
```

PVP comp slots use `COMP_SLOT_SIZE_PVP=22`, `COMP_SLOT_ICON_PVP=17`, `COMP_SLOT_SPACING_PVP=26` (vs 18/13/20 for standard).

---

## Listing modes (`GetListingMode` in Core.lua)

Detected from `activityInfo` flags:
- `isMythicPlusActivity` → `"mythic_plus"`
- `isRatedPvpActivity` → `"rated_pvp"`
- `isPvpActivity` → `"pvp"`
- `isCurrentRaidActivity` → `"raid"`
- text contains "legacy" + "raid" → `"legacy_raid"`
- text contains "delve" or known delve name → `"delve"`
- text contains "world" or "outdoor" → `"open_world"`
- otherwise → `"generic"`

---

## SavedVariables (`OakLFGSorterDB`)

| Key | Default | Purpose |
|---|---|---|
| `autoOpen` | `true` | Auto-open with Blizzard's LFG panel |
| `scale` | `1.0` | Frame scale |
| `windowOpacity` | `0.85` | Background opacity |
| `hideNotes` | `false` | Collapse notes column |
| `muteApplicantPing` | `true` | Suppress new-applicant sound |
| `autoHideFilledRoles` | `false` | Hide groups with filled needed role |
| `showRegions` | `false` | Show region badges |
| `lowLatencyOnly` | `false` | Filter to local-region groups |
| `fontName` / `fontSize` | `"OakUI Font"` / `12` | UI font settings |
| `regionFilters` | `{}` | Per-region filter state |
| `browserFilters` | `{}` | Browser-mode filter state |

---

## Versioning

- Current version in `.toc`: `## Version: 3.0.13`
- Current in-game display in `UI_Header.lua`: `VersionText:SetText("|cff888888v3.0.13|r")`
- **Both must be updated together** when bumping versions.
- Release script: `release-addon.ps1 -Version X.Y.Z` (updates all version refs, writes changelog, commits, tags, builds zip to `dist/`)

---

## Debug tools

- `/sorter` — toggle the addon window
- `/sorter reset` — reset saved position and scale
- `/oakpvpdebug` — while Arena search results are loaded, dumps raw `leaderPvpRatingInfo` fields to chat (useful for diagnosing PVP rating API structure changes)

---

## Raider.IO integration

Optional. When `RaiderIO` global is present:
- M+ scores fetched via `RaiderIO.GetProfile(name, realm)` at tooltip time (not cached on results to save memory)
- `RaiderIO.ShowProfile(name, realm)` opens full profile panel on Shift+hover
- Raid progress summary built from RIO profile data in `Core.lua:GetRaidProgressSummary`

---

## Recent handoff summary

This section summarizes the work done after adding the browser keybind work and the Oak footer controls for Blizzard finder/listing access.

### Files touched during this pass

- `Core.lua`
- `UI_Rows.lua`
- `UI_Filters.lua`
- `Init.lua`
- `OakLFGSorter.toc`
- `Party_Keys.lua` (new)

### Browser keybind / keyboard capture changes

- The browser keybind capture lives in `UI_Filters.lua`.
- Keyboard propagation was changed so Oak no longer blocks normal chat input while open.
- `optionsPanel:SetPropagateKeyboardInput(true)` is now the default.
- Keyboard capture is only disabled during active browser-keybind capture, then restored afterward.
- On hide, the options panel clears capture state and restores keyboard propagation.

### Oak footer controls added

- `UI_Rows.lua` now adds browser footer buttons:
  - `LFG`
  - `LFR`
  - `List`
- These sit near `Supporters & Links`.
- `List` opens a custom upward dropdown with:
  - `Dungeons`
  - `Raids - Current`
  - `Raids - Legacy`
  - `Delves`
  - `Questing`
  - `Custom`
  - `RBG`
  - `Arena`
- Footer visibility is now mode-aware. Browser-only controls are intended to hide while listing/applicant views are active.

### Blizzard-style button theming changes

- For `BLIZZARD` and `BLIZZARD_GRAY`, button readability was improved in `Init.lua`.
- Flat buttons and cog buttons now use a visible inner fill overlay based on the quick-signup/footer-bar color so they do not blend into the darker frame backgrounds.
- Earlier border-tint experiments were removed. The final direction was fill-based contrast, not accent-outline borders.

### Auto-close / persistence changes

- Oak should no longer auto-hide when Blizzard search/listing panels change state.
- `UI_Filters.lua` no longer hides Oak from the Blizzard search-panel `OnShow` path.
- `Core.lua` no longer hides Oak from `GROUP_ROSTER_UPDATE` when an active listing disappears.
- Intentional design at handoff time: Oak should only close when the user closes it explicitly, ideally by `X` or Escape.
- Chat-blocking behavior improved, but Escape-close behavior may still need direct verification if Claude continues this line of work.

### Party Keys panel

- Added `Party_Keys.lua` and loaded it from `OakLFGSorter.toc`.
- Added SavedVariable default in `Init.lua`:
  - `showPartyKeys = true`
- Added an options toggle in `UI_Filters.lua`:
  - `Show Party Keys`
- Current intended behavior:
  - show while browsing dungeons
  - show while listing a dungeon group
  - only if the option is enabled
- Current panel placement:
  - anchored `TOPLEFT` of the Party Keys frame to `BOTTOMLEFT` of the Oak browser
  - grows downward below the main Oak window
- Layout was tightened to be smaller and denser than the first pass.
- Teleport support:
  - uses `LibOpenRaid-1.0` if available for party keystone data
  - uses `QUI_DungeonData` if present for dungeon/portal spell mapping
- A secure-frame anchoring error was fixed:
  - old issue: `Action[SetPoint] failed because[Cannot anchor protected frames to regions]`
  - fix: teleport button anchors to the row frame, not a texture region
- Visual/UX quality of this panel is still considered unfinished.

### Current Blizzard listing integration

- Main logic is in `Core.lua`.
- Oak currently tries to drive Blizzard's native listing flow from the footer `List` dropdown.
- The implementation opens Blizzard Group Finder, routes to `Premade Groups`, tries to select the target category, then attempts `Start a Group`.
- Multiple strategies were attempted during this pass:
  - label-based category clicks
  - top-tab switching (`Dungeons & Raids` vs `Player vs. Player`)
  - explicit category/filter assignment
  - delayed retries using `C_Timer.After`
  - hardcoded fallback attempts against Blizzard buttons
- The hardcoded button attempt was too aggressive and caused a blank Blizzard panel at one point; it was backed out.

### Current List-button status at handoff

Working from Oak `List`:
- `Dungeons`
- `Delves`
- `Questing`
- `Custom`

Not working from Oak `List`:
- `Raids - Current`
- `Raids - Legacy`
- `RBG`
- `Arena`

Observed behavior during latest debugging:
- `Dungeons`, `Delves`, `Questing`, and `Custom` can reach Blizzard entry creation correctly.
- `Raids - Current` / `Raids - Legacy` stay on `LFGListFrame.CategorySelection` and never advance.
- `RBG` / `Arena` switch to Blizzard's PvP tab, but still do not advance into entry creation.

### Blizzard listing debug tools added

- Added `/oaklistdebug` in `Core.lua`.
- Added automatic delayed debug snapshots after Oak `List` clicks.
- Debug output currently prints:
  - whether `PVEFrame` is shown
  - whether `LFGListFrame` is shown
  - whether `CategorySelection` is shown
  - whether `EntryCreation` is shown
  - whether `SearchPanel` is shown
  - `CategorySelection.selectedCategory`
  - `CategorySelection.selectedFilters`
  - whether Blizzard `StartGroupButton` is enabled
  - selected `PVEFrameTab`
  - visible `GroupFinderFrameGroupButton1..8`
  - visible category buttons and their selected state
  - activity data if entry creation becomes visible

### Latest known debug state for failing categories

#### `Raids - Current`

- `PVEFrame shown = true`
- `LFGListFrame shown = true`
- `CategorySelection shown = true`
- `EntryCreation shown = false`
- `SearchPanel shown = false`
- `CategorySelection.selectedCategory = nil`
- `CategorySelection.selectedFilters = nil`
- `StartGroupButton enabled = false`
- `Tab1: Dungeons & Raids selected=true`
- visible buttons still include:
  - `Questing`
  - `Delves`
  - `Dungeons`
  - `Raids - Midnight`
  - `Raids - Legacy`
  - `Custom`

#### `Raids - Legacy`

- Same visible frame state as `Raids - Current`
- `CategorySelection.selectedCategory = nil`
- `CategorySelection.selectedFilters = nil`
- `StartGroupButton enabled = false`

#### `RBG`

- `PVEFrame shown = true`
- `LFGListFrame shown = true`
- `CategorySelection shown = true`
- `EntryCreation shown = false`
- `SearchPanel shown = false`
- `CategorySelection.selectedCategory = 9`
- `CategorySelection.selectedFilters = 0`
- `StartGroupButton enabled = false`
- `Tab2: Player vs. Player selected=true`
- Despite PvP tab being selected, the visible `CategorySelection` buttons printed by Oak still look like the PvE category set.

#### `Arena`

- `PVEFrame shown = true`
- `LFGListFrame shown = true`
- `CategorySelection shown = true`
- `EntryCreation shown = false`
- `SearchPanel shown = false`
- `CategorySelection.selectedCategory = 4`
- `CategorySelection.selectedFilters = 0`
- `StartGroupButton enabled = false`
- `Tab2: Player vs. Player selected=true`
- Same pattern as `RBG`: category/filter values are set, but Blizzard still does not enable `StartGroupButton`.

### Most important unresolved problem

- Oak can reach Blizzard's category-selection state for raids and PvP, but Blizzard is not accepting the selection as valid for entry creation.
- For raids, category selection often remains effectively unset (`selectedCategory`/`selectedFilters` nil).
- For PvP, category/filter values can be set numerically, but `StartGroupButton` still remains disabled.
- This suggests the missing step is not just assigning category/filter IDs. Blizzard likely requires an additional internal selection path, panel mutation, or callback that Oak is not currently reproducing.

### Recommendation for next engineer

- Do not keep broadening blind click fallbacks.
- Start from the current `/oaklistdebug` instrumentation in `Core.lua`.
- Verify which Blizzard function or selection callback fires when the user manually clicks:
  - `Raids - Midnight`
  - `Raids - Legacy`
  - `Rated Battlegrounds`
  - `Arenas`
- Compare that to Oak's current path through `LFGListFrame.CategorySelection`.
- The main gap appears to be the Blizzard-internal state transition that enables `Start a Group`, not merely reaching the correct tab or setting numeric category IDs.

### Current shipped status

- Applicant region filters were fixed and released in `v3.0.1`.
- `UI_Filters.lua:GroupPassesFilters` now applies shared region filters to applicant groups, not just browser results.
- `Core.lua:FetchApplicantData` now stores applicant-group `leadName` and `regionInfo`.
- Mythic+ teleport fixes were released in `v3.0.2`.
- Root cause was map-ID mismatch: teleport lookup needs the instance map ID, while some Oak paths were passing challenge map IDs directly.
- `Init.lua` now provides shared teleport helpers:
  - `addonTable.GetChallengeMapInfo(mapID)`
  - `addonTable.GetDungeonTeleportSpellID(mapID)`
- Teleport lookup now prefers `QUI_DungeonData` when present, then falls back to built-in spell IDs for the currently supported dungeon pool.
- `Party_Keys.lua` now uses the shared teleport resolver and corrected map-ID handling for its dungeon buttons.
- `MythicPlus_Panel.lua` now:
  - uses the shared teleport resolver for season-best dungeon rows
  - allows clicking the player's current key text to teleport when the portal spell is known
- A secure-frame anchoring regression was found and fixed during the current-key teleport work:
  - bad approach: anchoring the secure button to a `FontString`/region
  - final fix: anchor the secure button directly to the panel with explicit coordinates
- Browser comp display was updated after `v3.0.2` but not released yet:
  - `Custom` browser rows now switch per listing:
    - `<= 5` members: show 5-man comp slots
    - `> 5` members: show raid-style `Tank / Healer / DPS` counts
  - For 5-man browser rows, enabling `Show Spec Icons` now uses spec icons in fixed slot order: `Tank / Healer / DPS / DPS / DPS`
  - Browser rows now show `Invited` in green when `applicationStatus` is `invited` or `inviteaccepted`

### Playstyle filter handoff

- `Core.lua:ProcessSearchResults` already stores:
  - `playstyleValue`
  - `playstyleLabel`
  - `playstyleShortLabel`
- The playstyle extraction helper is already part of the browser search-result build path in `Core.lua`.
- The likely implementation path for a playstyle filter is:
  - add saved filter state in `OakLFGSorterDB.browserFilters`
  - add the UI control in `UI_Filters.lua`
  - enable/disable it per mode in `Search_FilterModes.lua`
  - enforce it in `UI_Filters.lua:GroupPassesFilters`
- Do not assume every category reliably returns playstyle data. Some listings may have nil/empty playstyle fields depending on Blizzard category behavior.

### Browser dungeon filter handoff

- The intended design for dungeon filtering is still: Oak mirrors Blizzard's native dungeon advanced filter state rather than inventing a separate search model.
- `UI_Filters.lua:SyncBrowserNativeActivities` is the write path from Oak's dungeon checkboxes into `C_LFGList.GetAdvancedFilter()` / `SaveAdvancedFilter()`.
- `UI_Filters.lua:SyncBrowserSelectedActivitiesFromNative` is the reverse sync path when Oak rebuilds from Blizzard's native advanced filter.
- `Core.lua:RunBrowserSearch` currently prefers Blizzard's own `LFGListSearchPanel_DoSearch(panel)` when Oak is already on the same category, specifically to preserve Blizzard's native search behavior and locale-sensitive state.
- `Core.lua:GetAvailableBrowserActivities` currently builds the Oak dungeon checkbox list from:
  - `GetLocalizedSeasonDungeonLabels()`
  - `C_LFGList.GetAvailableActivities(categoryID)` plus `GetActivityInfoTable(activityID)`
  - current `addonTable.SearchResults` as a fallback

#### Current browser dungeon filter status

- The Magisters' Terrace browser-filter bug was diagnosed and fixed after the previous handoff.
- As of the latest test pass, all tested dungeon filters, including **Magisters' Terrace**, now update Blizzard's native dungeon filter pane correctly.
- The intended model remains unchanged: Oak should keep using Blizzard's native dungeon advanced filter/search path so the user gets Blizzard's full result set for each dungeon.

#### Confirmed root cause of the Magisters bug

- `C_LFGList.GetAvailableActivities(categoryID)` returned multiple Blizzard activities that all normalized to the same dungeon label for **Magisters' Terrace**.
- Specifically, Magisters had:
  - legacy Burning Crusade activities with `groupFinderActivityGroupID = 37`
  - current-season activities with `groupFinderActivityGroupID = 399`
- Oak's activity-label lookup was previously taking the first match for the normalized label, which resolved Magisters to the legacy group instead of the current-season group.
- Oak then wrote the wrong group ID into Blizzard's native `advancedFilter.activities`, so Blizzard's dungeon filter pane would not update correctly for Magisters and Oak-only filtering could return no results.

#### Final fix that worked

- In `Core.lua:GetAvailableBrowserActivities`, when multiple Blizzard activities share the same normalized dungeon label, Oak now prefers the entry with the **highest** `groupFinderActivityGroupID`.
- This preserves the current-season/current-context mapping instead of accidentally selecting an older legacy activity.
- For Magisters' Terrace this changed the resolved mapping from:
  - legacy group `37`
  - to current-season group `399`
- After that change, Oak's dungeon checkbox for Magisters correctly drives Blizzard's native dungeon filter, and Blizzard returns the expected Magisters result set.

#### Important recent investigation notes

- A broader attempt to normalize all dungeon activity keys and add extra activity fallbacks was tried during debugging and then intentionally backed out because it broke Blizzard-pane syncing for multiple dungeons.
- The confirmed fix was much narrower: prefer the higher `groupFinderActivityGroupID` when duplicate normalized dungeon labels collide.
- A small local matching fallback remains in `UI_Filters.lua:ResultMatchesSelectedActivities` so Oak can treat exact and normalized activity-label keys equivalently when checking selected activities.
- Temporary `/oakdungdebug` instrumentation was used to prove the Magisters resolution bug and has since been removed.

#### Recommendation for next engineer

- Preserve the current overall strategy of using Blizzard's native filter/search path for dungeon queries wherever possible.
- If a future dungeon-specific filter bug appears, check first for duplicate Blizzard activities under the same normalized label before rewriting the dungeon filter model.
- In particular, inspect `groupFinderActivityGroupID` collisions inside `Core.lua:GetAvailableBrowserActivities`.

---

## Development notes

- **Platform**: Windows, WoW installed at `C:\Blizzard Games\World of Warcraft\_retail_\`
- **Addon path**: `Interface\AddOns\OakLFGSorter\`
- **Testing**: Edit files directly in the addon folder, then `/reload` in WoW to pick up changes immediately
- **Lua environment**: Standard WoW addon Lua — no external dependencies, no build step required
- **No TypeScript/JS**: Pure Lua only; do not suggest or introduce non-Lua tooling
