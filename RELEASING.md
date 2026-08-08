# Releasing OakLFGSorter

This repo now includes a root [`.pkgmeta`](.pkgmeta) so CurseForge can package the addon automatically from GitHub.
It also uses [CHANGELOG.md](CHANGELOG.md) as the manual CurseForge changelog source.
Upcoming notes can live in [NEXT_CHANGELOG.md](NEXT_CHANGELOG.md), which the release script consumes automatically.

## Patreon Supporter Sync

The release helper refreshes [Supporters.lua](Supporters.lua) from Patreon before creating the release commit. It reads these Windows user environment variables:

```text
OAKUI_PATREON_ACCESS_TOKEN
OAKUI_PATREON_CAMPAIGN_ID
```

The sync includes only members with `patron_status = active_patron` and a positive `currently_entitled_amount_cents`, then sorts them by `pledge_relationship_start` from oldest to newest. The sync helper is [sync-patreon-supporters.ps1](sync-patreon-supporters.ps1) and is kept out of the addon zip.

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

## One-Time Wago Setup

Wago's current docs recommend using the BigWigs packager through GitHub Actions.

This repo now includes [`.github/workflows/wago-release.yml`](.github/workflows/wago-release.yml), which watches for pushed tags like `v1.6.4` and publishes to Wago when the remaining Wago-specific values are configured.

You still need to do these two steps once:

1. Create or open your addon project on Wago and copy its 8-character project ID from the Wago developer dashboard.
2. Add that ID to `OakLFGSorter.toc` as:

   ```text
   ## X-Wago-ID: YOURWAGO
   ```

3. Create a Wago API token and save it as a GitHub repository secret named `WAGO_API_TOKEN`.

Once those are in place, every pushed release tag will also publish to Wago automatically.

## One-Time Discord Setup

This repo now includes [`.github/workflows/discord-release.yml`](.github/workflows/discord-release.yml), which posts a Discord announcement whenever you push a release tag like `v1.6.6`.

You still need to do this once:

1. In your Discord server, open the channel you want for release announcements.
2. Create a channel webhook:
   - Edit Channel -> Integrations -> Webhooks -> New Webhook
   - Copy the webhook URL
3. In GitHub, open [Smokenoaken/OakLFGSorter repository secrets](https://github.com/Smokenoaken/OakLFGSorter/settings/secrets/actions):
   - Settings -> Secrets and variables -> Actions
   - Create a new repository secret named `DISCORD_WEBHOOK_URL`
   - Paste the Discord webhook URL

After that, every pushed `v*` tag will post the matching `CHANGELOG.md` notes into Discord with a link back to the CurseForge project page.

## Recommended Release Flow

Tagged pushes are the safest setup for this addon.

Use the one-command helper:

```powershell
.\release-addon.ps1 -Version 1.6.4
```

What it does:

- reads bullet points from `NEXT_CHANGELOG.md` by default, or from `-Notes` if you pass them directly
- prepends a new release section into `CHANGELOG.md`
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
2. Add one bullet per line to [NEXT_CHANGELOG.md](NEXT_CHANGELOG.md)
3. Test in-game
4. Run `.\release-addon.ps1 -Version 1.6.4`
5. Let CurseForge package the pushed tag as a Release using `CHANGELOG.md`
6. Let the Wago GitHub Action publish that same tag to Wago, if `## X-Wago-ID` and `WAGO_API_TOKEN` are configured
7. Let the Discord GitHub Action announce that same tag, if `DISCORD_WEBHOOK_URL` is configured
8. Open the GitHub release page for that same tag and paste in your release notes

Optional one-liner if you want to skip editing `NEXT_CHANGELOG.md`:

```powershell
.\release-addon.ps1 -Version 1.6.6 -Notes "Fixed tooltip alignment","Added smarter role filtering"
```

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
