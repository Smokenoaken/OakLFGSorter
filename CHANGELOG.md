## v4.0.1

- Fixed a browser-width regression where switching from a listed group into browsing could leave the Oak window too narrow when notes were collapsed.
- Fixed raid applicant progress so the Prog column now shows difficulty-prefixed progress such as `N 5/9`, `H 5/9`, or `M 5/9`, matched to the user's active raid listing difficulty.
- Added LibDataBroker launcher support so broker displays can open Oak without relying on the minimap button.

## v4.0.0

- Added a new theme system with Classic and Modern modes. Classic is now the default appearance and is designed to feel seamless with Blizzard's built-in World of Warcraft UI.
- Added Modern theme styling as an optional appearance layer with selectable styles, accent colors, and custom accent support.
- Restyled major UI surfaces through the theme system, including the browser frame, options panel, filter panels, side panels, headers, rows, buttons, dropdowns, toggles, sliders, scrollbars, popups, and panel chrome.
- Preserved the OAK LFG Sorter badge/logo in both Classic and Modern themes.
- Added a reload notice beside the Theme selector so users know changing themes will force a UI reload.
- Updated the addon title to OAK LFG Sorter and kept the release as a single unified addon identity.
- Added /lfg and /oaklfg slash commands, while keeping existing slash command compatibility.
- Added right-click support for browser results so Oak opens Blizzard's native listing context menu, including Whisper Leader, Report Group, Report Advertisement, and Raider.IO menu entries when available.
- Added right-click support for applicant rows so Oak opens Blizzard's native applicant/member context menu, including Whisper, Report Player, Ignore Player, and Raider.IO menu entries when available.
- Added Main/Warband Mythic+ score support in the browser rating column when Raider.IO profile data is available.
- Added Keep Gone, an option that can keep a small number of delisted, unavailable, or declined browser results pinned in place to reduce list jumping.
- Added safeguards so large Blizzard result refreshes or empty transient result pages do not incorrectly mark the whole browser as delisted.
- Improved declined-result handling so declined groups can remain visible when Hide Declined is off, and added a tooltip clarifying that Hide Declined hides groups that declined the user's application.
- Moved region filter selection into the browser Filters panel and compacted it into a smaller region section.
- Kept Show Regions and Show Flags Instead of Tags in Options as shared display controls.
- Improved browser refresh behavior, row stability, responsive layout refreshes, resize handling, and frame position saving.
- Improved browser opacity handling so the selected opacity applies correctly across themed browser surfaces.
- Improved applicant and browser header/action button positioning for both browser and applicant views.
- Improved Modern button hover feedback so button borders use the selected accent color on mouseover.
- Restored Classic button styling in Classic mode and prevented Modern styling from leaking into Classic controls.
- Updated sliders to use Blizzard-style slider handles while still applying Modern accent colors where appropriate.
- Improved options panel layout for larger font sizes, including inline Font Size and Window Opacity values.
- Improved addon-wide font handling with Friz Quadrata TT as the Classic default and OakUI Font available as an optional font.
- Improved Party Keys panel styling, spacing, and theme integration.
- Improved Mythic+ Overview panel styling and theme integration.
- Improved Quick Sign Up bar styling, persisted note controls, and theme integration.
- Improved Supporters & Links layout so current supporters fit without a scrollbar.
- Reduced package media size by replacing the large logo asset with the optimized OAK LFG Sorter logo asset.

## v3.0.21

- Fixed browser group comp class colors when Show Spec Icons is disabled.

## v3.0.20

- Fixed the browser loading stutter when opening Oak for the first time
- Reduced refresh hitching while browsing groups
- Kept apply-to-group interactions responsive during browser updates

## v3.0.19

- Added horizontal browser width adjustment with responsive browser column sizing.
- Fixed locale-sensitive browser dungeon filtering and seasonal teleport resolution, including German article/name mismatches like Die Himmelsnadel.
- Fixed browser reload layout issues so collapsed-note headers restore cleanly without manual resizing.
- Updated the Supporters panel layout and supporter list.
- If you find a locale-specific browser filter or teleport issue, please report it on Discord: https://discord.gg/FRGUFaEEVd

## v3.0.18

- Fixed browser filter issues.

## v3.0.17

- Updated supporters list.

## v3.0.16

- Updated supporters list.

## v3.0.15

- Fixed browser spec-icon fallback so ambiguous spec names like Frost
- Protection
- Holy
- and Restoration now resolve by class instead of showing the wrong icon

## v3.0.14

- Fixed Magisters' Terrace dungeon filter sync so Oak now resolves the current-season Blizzard activity group instead of the legacy dungeon group

## v3.0.13

- Raised Oak's browser stack so the main window clears action bars and similar UI overlays again.
- Kept Blizzard's application popup explicitly above Oak while the browser is raised.
- Made the browser filter panel widen itself for larger localized fonts and longer translated labels so filter text fits better across locales.

## v3.0.12

- Fixed the Mythic+ Overview panel so it refreshes while open after key, score, seasonal-best, and Great Vault updates.
- Fixed the Mythic+ Overview panel combat refresh guard so the panel no longer opens blank with Lua errors.

## v3.0.11

- Saved the persisted signup note text per character so it now survives reloads and relogs
- Sanitized restored signup notes to remove Blizzard-invalid line breaks before the popup uses them

## v3.0.10

- Sanitized persisted signup notes so pasted multiline notes are flattened into a single Blizzard-valid line before signup
- Added a defensive fallback that clears blocked signup notes for the current application when Blizzard disables the Sign Up button with note text present

## v3.0.9

- Streamlined Quick Sign Up behavior and browser signup flow
- Added patch 12.0.5 interface compatibility

## v3.0.7

- Fixed Party Keys teleports so Oak can be hidden in combat without protected-frame errors.
- Oak now closes automatically when combat starts instead of getting stuck open.

## v3.0.5

- Added optional GroupfinderFlags-backed region flag display and sorting
- Synchronized Oak Quick Sign Up roles with Blizzard Dungeon Finder and Raid Finder role selectors
- Improved Lust and Battle Resurrection filters with party-aware utility-fit logic and added explanatory tooltips

## v3.0.4

- Fixed minimap open/close behavior so left-click now cleanly toggles Oak
- Prevented combat lockdown errors by queuing minimap opens until combat ends
- Added chat feedback when Oak or its options cannot open during combat

## v3.0.3

- Added applicant isLeaver flagging with red <!> markers and tooltip detail
- Improved applicant party row presentation, region tag alignment, and applicant column spacing
- Adjusted multi-applicant action-button placement and prevented resize-grip click jumps
- Released v3.0.3

## v3.0.2

- Fixed Mythic+ teleport actions so dungeon portal buttons resolve correctly

## v3.0.1

- Fixed region filters so applicant view now respects enabled regions

## v3.0.0

- Added Oak footer controls for Blizzard LFG, LFR, List, PvP, and Mythic+ access
- Added a Mythic+ overview side panel with season best, affixes, and Great Vault progress
- Added Party Keys support with Raider.IO-style dungeon abbreviations and improved key readability
- Added applicant view listing edit access and improved applicant invite row handling
- Improved browser and applicant footer layout, button styling, tooltips, scaling, and theme/accent behavior
- Expanded raid browser tooltip details and improved Blizzard finder/listing integration behavior

## v2.5.5

- Disabled browser apply while the player has an active group listing and added an explanatory tooltip.
- Kept the browser join checkmark visible but desaturated so leaders can see why group signup is blocked.
- Included the recent localized browser search sync and filter-panel quality-of-life improvements.

## v2.5.4

- Fixed localized browser searches so Oak now matches Blizzard results on non-English clients.
- Restored same-category searches to Blizzard's live search path to avoid request mismatches.
- Added the player's current M+ rating to the dungeon filter panel with Raider.IO/Blizzard score coloring.
- Expanded the Supporters panel and updated localized browser/filter UI labels and auto-fit sizing.

## v2.5.3

- Added live bountiful delve detection with yellow-highlighted delve labels in both the browser list and delve filter panel.
- Added delve-only bountiful filtering plus faster bulk delve filter toggles, including persistent season delve entries even when no groups are listed.
- Expanded the theme options with a Light Gray accent, renamed Mint and Blizzard Brown labels, and added a new Blizzard Gray style.
- Reduced Oak browser CPU usage by stopping hidden-window background refreshes, throttling live search-result rebuilds, and skipping browser repaints when search data has not materially changed.

## v2.5.2

- You can now search group categories directly from Oak without opening Blizzard's Premade Groups browser first.
- Added Oak theme styling options and shared UI theming polish across the browser and applicant views.
- Restored the minimap button with left-click browser access, right-click options access, tooltip support, and an options toggle to hide it.

## v2.5.1

- Added a new theme selector in Oak's options panel with preset accent colors.
- Added a custom color picker option so you can create and save your own Oak accent theme.
- Applied theme accents live across Oak's main frame, filter and options panels, notes controls, sticky browser accents, and quick sign-up UI.

## v2.5.0

- Unified Oak into a single browser window that replaces the old split search/browser setup, with mode-aware layouts for Mythic+, raids, PvP, delves, and open-world listings.
- Completely rebuilt the Find Group side of the addon with a cleaner shared frame, rebuilt result rows and columns, integrated Blizzard search/filter handoff, better quick sign-up flow, and stronger apply/cancel visibility for active applications.
- Delivered a major optimization pass by removing the retired browser codepath, reducing dead helpers and duplicated UI, tightening refresh behavior, and improving memory usage and overall responsiveness.
- Expanded browser support with dedicated raid and PvP presentations, richer comp rendering, class/spec-aware icons, better tooltip detail, region context, and stronger Raider.IO integration.
- Polished the experience across the release cycle with improved notes handling, friend and applied-group prioritization, footer and header cleanup, safer auto-open/load behavior, and broader filter stability fixes.

## v2.0.12

- Added Specialization Icon Toggles

## v2.0.11

- Improved search signup responsiveness by making normal apply clicks open Blizzard's signup dialog more reliably and keeping Quick Sign Up on the faster direct-apply path.
- Added a top-bar reminder that you can only sign up for a total of 5 groups at a time and tightened its layout to fit beside the quick signup role icons.
- Kept the latest native dungeon filter reset behavior so Oak and Blizzard start from a cleaner shared baseline after reloads.

## v2.0.10

- Fixed the native dungeon filter hotfix so Oak no longer taints Blizzard's protected Search() path when refreshing dungeon filters.
- Stopped the dungeon filter UI from recursing into a long refresh loop while repainting Blizzard-backed activity selections.
- Kept the safer immediate checkbox refresh behavior for Blizzard-backed dungeon filters without requiring unsafe protected calls.

## v2.0.9

- Stopped Oak windows from continuing to follow Blizzard's Dungeons & Raids frame after the user places them
- so reset/fresh install still dock while normal dragging stays where you put it.
- Fixed the search browser comp column to render filled role slots from Blizzard role counts when per-member class details are unavailable.
- Fixed a load-breaking Lua syntax error introduced during the drag hotfix pass.

## v2.0.8

- Kept all signed-up groups visible and pinned at the top even when listings become full or stop matching filters
- so applications can always be cancelled from Oak.
- Replaced the find-browser Low Latency checkbox with shared per-region filter toggles and persisted shared font/region display settings more reliably.
- Reduced browser drag jitter by backing off auto-clamping while Oak windows are actively being dragged or resized.

## v2.0.7

- Restored browser results for listings where Blizzard delays the direct activityID field.
- Kept the taint fix by resolving fallback activityIDs through a fresh secure lookup instead of addon-owned secret tables.

## v2.0.6

- Fixed Blizzard LFG taint caused by touching protected activityIDs on search/listing data.
- Sanitized cached listing data so Oak no longer keeps Blizzard secret tables in addon state.

## v2.0.5

- Added a localization framework with English fallback so contributors can add translations without editing logic files.
- Added starter locale files for enUS, deDE, frFR, esES, and esMX.
- Localized the main Oak window, search window, options panel, notes controls, and quick sign-up labels/tooltips to use the new locale system.
- Improved native dungeon filter behavior so dungeon entries can still be selected even before Blizzard exposes a live activity ID for them.
- Fixed native Mythic+/Mythic difficulty syncing so Oak's dungeon difficulty selection maps back to Blizzard's advanced filter more reliably.

## v2.0.4

- Made the Notes column sortable while keeping it hideable in both the applicant/browser and search windows.
- Added raid role range filters for Tanks, Healers, and DPS, including friendlier single-number minimum matching.
- Cleaned up the raid search filter layout so the new role filters fit cleanly in the panel.

## v2.0.3

- Added a Filled state for applied groups that no longer fit your role or party
- keeping them pinned so they can be cancelled faster.
- Added a Low Latency option to show only groups from your region.

## v2.0.2

- Fixed Party Fit filtering so it no longer filters out valid groups incorrectly.

## v2.0.1

- Fixed mute ping taint by removing the unsafe global sound hook.

## v2.0.0

## v3.0.8

- Added a Mythic+ playstyle filter in the browser with immediate refresh behavior to narrow results by Learning, Relaxed, Competitive, or Carry groups.
- Updated browser comp rendering so Custom listings show 5-man role slots for groups of 5 or fewer and raid-style role counts for larger groups.
- When Show Spec Icons is enabled, 5-man browser comp now keeps static Tank, Healer, and DPS slot ordering for faster at-a-glance group checks.
- Browser rows now show invited applications in green for clearer status scanning.

- Added a full Find Group browser with dedicated sorting, filtering, quick sign-up controls, scalable detached-window support, and a hosted Blizzard search box inside Oak's pane.
- Added Blizzard-backed dungeon filters, mode-aware search panels for dungeons, raids, delves, PvP, custom, and legacy content, plus cleaner compact layouts across the addon.
- Added Mythic+ Gives Score forecasting with per-dungeon key targets, estimated score gains, +/++/+++ tooltip breakdowns, and season-dungeon All/None controls.
- Added major raid browser improvements including difficulty-aware columns, rarity-colored raid difficulties, kills tracking, boss-kill expression filtering, and lockout matching.
- Added optional visible region tags and region-aware tooltips across finder and applicant rows, with the toggle moved into a shared options panel.
- Added a shared options panel in both browsers with SharedMedia font selection, live font previews, font size, opacity controls, and improved footer/options layout.
- Added richer Raider.IO integration including anchored profile panels, detailed Shift-hover profile tooltips, score-aware styling, and stronger group/applicant context.
- Added quick sign-up role syncing, improved friend detection, better tooltip polish, safer detached-window clamping, and many search/filter stability fixes.

## v2.0.0-alpha3

- Tightened the Blizzard-backed dungeon filter pane so the full season dungeon list fits without scrolling, and added All/None helpers plus refresh guidance
- Added Mythic+ Gives Score estimates in the dungeon filter list, including score-gain values and richer tooltip breakdowns
- Restored the simpler applicant Edit button behavior that clicks Blizzard's visible Edit control without the later PVEFrame reopen experiments

## v2.0.0-alpha2

- Added Oak quick-signup role controls that now correctly sync into Blizzard's signup popup
- Restored raid browser mode-aware columns, including a dedicated Difficulty column and raid-specific Kills sorting/display
- Added applicant listing context under the Oak header and refined toggle visuals across the addon
- Kept Blizzard listing edit handoff available from Oak even though the hidden-PVEFrame reopen issue remains unresolved in this alpha

## v2.0.0-alpha1

- Refined the Find Group browser scaling and anchoring so the browser stays aligned with Blizzard's LFG pane when resized
- Fixed search/browser stability issues around sorting, activity lookups, and Blizzard result syncing
- Reworked the search filter pane to be mode-aware for dungeons, raids, delves, and generic categories
- Added Blizzard-backed dungeon filter integration in Oak's filter pane, plus a PGF compatibility warning when shared dungeon filters are detected

## v1.6.8-alpha2

- Removed accidental local `.claude` worktree metadata from the tracked repo contents so the published alpha tree stays clean

## v1.6.8-alpha1

- Added the Oak Find Group browser view for Blizzard search results with dedicated browser rows and filters
- Hosted Blizzard's native search box inside the Oak filter pane without search drift while preserving direct search execution
- Polished browser column spacing, compact Notes behavior, and Raider.IO tooltip anchoring around the new search panes

## v1.6.7

- Added adaptive applicant modes that change the sorter display based on the active listing type
- Added PvP-aware applicant data and PVP Rating support for PvP listings
- Added raid-aware applicant progress summaries for current-tier raid listings when Raider.IO data is available
- Simplified raid and PvP layouts to use a single metric column with Notes expanding into the freed space
- Refined the compact header and Supporters pane spacing for a cleaner overall layout

## v1.6.7-alpha1

- Alpha tag to validate Discord release announcements,No addon behavior changes from v1.6.6

## v1.6.6

- Added a collapsible Notes header toggle to show or hide the note column,Resized the sorter dynamically while keeping the Filters and Supporters panes anchored to the frame,Kept the left edge fixed when collapsing Notes so only the right side of the window shifts,Polished the compact layout with a header-style Notes control, footer version text, and mini reset button

## v1.6.5

- Added a manual packaged changelog so CurseForge releases use clean release notes instead of raw Git history
- Updated the repo to use a GitHub noreply email for future commits
- Maintained the CurseForge and Wago automated release workflow
