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
