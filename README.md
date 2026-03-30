# OakLFGSorter

Oakensoul LFG Sorter is a World of Warcraft Retail addon that gives group leaders a cleaner way to review Group Finder applicants. It adds a sortable, filterable applicant window focused on quick triage for Mythic+ and other premade listings.

## Highlights

- sortable applicant columns for role, class, spec, item level, Mythic+ rating, highest key, and note
- role and class filters with quick presets for Lust, Battle Rez, and armor types
- direct invite and decline buttons in the custom applicant list
- multi-member applicant group display
- optional auto-open beside Blizzard's applicant viewer
- optional Raider.IO profile enrichment when Raider.IO is installed
- saved frame position, scale, and auto-open preferences

## Requirements

- World of Warcraft Retail
- Interface version `120001`
- Raider.IO is optional, but supported for score/profile data

## Installation

1. Download or clone this repo.
2. Place the addon folder here:

```text
World of Warcraft\_retail_\Interface\AddOns\OakLFGSorter
```

3. Launch WoW Retail.
4. Make sure `Oakensoul LFG Sorter` is enabled in the AddOns list.

## Usage

Open Group Finder and review applicants for your active listing. The addon provides its own applicant window with sorting, filtering, and direct actions.

Slash commands:

```text
/oaklfg
/oaklfg reset
```

- `/oaklfg` toggles the addon window
- `/oaklfg reset` resets saved position and scale

## Raider.IO Support

If Raider.IO is installed, OakLFGSorter uses Raider.IO profile data and Raider.IO score colors where available. If Raider.IO is not installed, the addon falls back to Blizzard's built-in applicant and score data.

## Files

- [OakLFGSorter.toc](OakLFGSorter.toc) loads the addon and declares metadata
- [Init.lua](Init.lua) initializes fonts, styling, and shared addon data
- [UI_Header.lua](UI_Header.lua) builds the main frame and window controls
- [UI_Filters.lua](UI_Filters.lua) handles filtering, quick presets, and Blizzard UI hooks
- [UI_Rows.lua](UI_Rows.lua) renders headers, rows, sorting, tooltips, and row actions
- [Core.lua](Core.lua) fetches applicants, reacts to events, and refreshes display data

## Releasing

This repo supports manual zip builds, CurseForge automatic packaging, and Wago publishing from GitHub tags.

For automatic packaging, configure a GitHub webhook that points at your CurseForge project packaging URL. The repo root already includes a [`.pkgmeta`](.pkgmeta) file so CurseForge packages the addon under the correct top-level folder name.

For Wago, the repo includes [`.github/workflows/wago-release.yml`](.github/workflows/wago-release.yml). After you add your `## X-Wago-ID` to [OakLFGSorter.toc](OakLFGSorter.toc) and set a `WAGO_API_TOKEN` GitHub secret, pushed version tags will publish there automatically too.

For the easiest tagged release flow, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\release-addon.ps1 -Version 1.6.4
```

Put one bullet per line in [NEXT_CHANGELOG.md](NEXT_CHANGELOG.md), then run the command. The script rolls those notes into [CHANGELOG.md](CHANGELOG.md), updates the repo version files, commits the release, creates and pushes the Git tag, and builds a local zip in `dist\`.

For manual fallback builds only, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\package-release.ps1
```

That produces a release zip in `dist\` with the correct top-level addon folder. More detail is in [RELEASING.md](RELEASING.md).

## Version

Current repo version: `1.6.7-alpha1`

## Project Summary

Oakensoul LFG Sorter is built for players who lead groups and want faster, cleaner applicant review than the default Blizzard list provides. It gives you a dedicated applicant window with sorting, filtering, direct invite and decline controls, group composition context, and optional Raider.IO profile enrichment for Mythic+ decision-making.

Whether you are building keys, raids, or other premade groups, the goal is simple: spend less time fighting the applicant list and more time building the right group.
