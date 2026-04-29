Added a new theme system with Classic and Modern modes. Classic is now the default appearance and is designed to feel seamless with Blizzard's built-in World of Warcraft UI.
Added Modern theme styling as an optional appearance layer with selectable styles, accent colors, and custom accent support.
Restyled major UI surfaces through the theme system, including the browser frame, options panel, filter panels, side panels, headers, rows, buttons, dropdowns, toggles, sliders, scrollbars, popups, and panel chrome.
Preserved the OAK LFG Sorter badge/logo in both Classic and Modern themes.
Added a reload notice beside the Theme selector so users know changing themes will force a UI reload.
Updated the addon title to OAK LFG Sorter and kept the release as a single unified addon identity.
Added /lfg and /oaklfg slash commands, while keeping existing slash command compatibility.
Added right-click support for browser results so Oak opens Blizzard's native listing context menu, including Whisper Leader, Report Group, Report Advertisement, and Raider.IO menu entries when available.
Added right-click support for applicant rows so Oak opens Blizzard's native applicant/member context menu, including Whisper, Report Player, Ignore Player, and Raider.IO menu entries when available.
Added Main/Warband Mythic+ score support in the browser rating column when Raider.IO profile data is available.
Added Keep Gone, an option that can keep a small number of delisted, unavailable, or declined browser results pinned in place to reduce list jumping.
Added safeguards so large Blizzard result refreshes or empty transient result pages do not incorrectly mark the whole browser as delisted.
Improved declined-result handling so declined groups can remain visible when Hide Declined is off, and added a tooltip clarifying that Hide Declined hides groups that declined the user's application.
Moved region filter selection into the browser Filters panel and compacted it into a smaller region section.
Kept Show Regions and Show Flags Instead of Tags in Options as shared display controls.
Improved browser refresh behavior, row stability, responsive layout refreshes, resize handling, and frame position saving.
Improved browser opacity handling so the selected opacity applies correctly across themed browser surfaces.
Improved applicant and browser header/action button positioning for both browser and applicant views.
Improved Modern button hover feedback so button borders use the selected accent color on mouseover.
Restored Classic button styling in Classic mode and prevented Modern styling from leaking into Classic controls.
Updated sliders to use Blizzard-style slider handles while still applying Modern accent colors where appropriate.
Improved options panel layout for larger font sizes, including inline Font Size and Window Opacity values.
Improved addon-wide font handling with Friz Quadrata TT as the Classic default and OakUI Font available as an optional font.
Improved Party Keys panel styling, spacing, and theme integration.
Improved Mythic+ Overview panel styling and theme integration.
Improved Quick Sign Up bar styling, persisted note controls, and theme integration.
Improved Supporters & Links layout so current supporters fit without a scrollbar.
Reduced package media size by replacing the large logo asset with the optimized OAK LFG Sorter logo asset.
