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
