# Releasing OakLFGSorter

This repo now includes a root [`.pkgmeta`](.pkgmeta) so CurseForge can package the addon automatically from GitHub.

## One-Time CurseForge Setup

1. Generate a CurseForge API token:
   - Open https://www.curseforge.com/account/api-tokens
   - Create a token for webhook packaging
2. Add a GitHub webhook on [Smokenoaken/OakLFGSorter](https://github.com/Smokenoaken/OakLFGSorter):
   - GitHub repo Settings -> Webhooks -> Add webhook
   - Payload URL:
     `https://www.curseforge.com/api/projects/1494166/package?token=YOUR_TOKEN_HERE`
   - Leave the other settings at their defaults
3. In CurseForge packaging settings, choose whether you want:
   - all commits packaged as alpha, or
   - tagged pushes only

## Recommended Release Flow

Tagged pushes are the safest setup for this addon.

Use the one-command helper:

```powershell
.\release-addon.ps1 -Version 1.6.4
```

What it does:

- updates the version in `OakLFGSorter.toc`
- updates the in-window version text in `UI_Header.lua`
- updates the version line in `README.md`
- creates a release commit
- creates and pushes a tag such as `v1.6.4`
- pushes `main`
- builds a local zip in `dist\`
- leaves you on the GitHub release page URL for the new tag

Recommended release steps:

1. Finish your code changes
2. Test in-game
3. Run `.\release-addon.ps1 -Version 1.6.4`
4. Let CurseForge package the pushed tag as a Release
5. Open the GitHub release page for that same tag and paste in your release notes

Tag naming rules from CurseForge:

- tags containing `alpha` become Alpha files
- tags containing `beta` become Beta files
- other pushed tags are treated as Release files

## Local Zip Fallback

If you ever want to build a zip manually instead of using automatic packaging:

```powershell
.\package-release.ps1
```

What it does:

- reads the version from `OakLFGSorter.toc`
- creates `dist\OakLFGSorter-v<version>.zip`
- puts all addon files under the correct top-level folder `OakLFGSorter\`
- excludes repo-only and local helper files like `.git`, `.gitignore`, browser temp profiles, PDFs, and packaging scripts

Optional examples:

```powershell
.\package-release.ps1 -Version 1.6.3
.\package-release.ps1 -OutputDir C:\Users\YourName\Desktop\OakReleases
```
