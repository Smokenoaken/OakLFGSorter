param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$CommitMessage,

    [string[]]$Notes,

    [switch]$SkipZip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $gitExe = "C:\Program Files\Git\cmd\git.exe"
    & $gitExe @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Git command failed: git $($Arguments -join ' ')"
    }
}

function Update-FileText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter(Mandatory = $true)]
        [string]$Replacement
    )

    $content = Get-Content -LiteralPath $Path -Raw
    $updated = [regex]::Replace($content, $Pattern, $Replacement, 1)
    if ($updated -eq $content) {
        throw "Could not update expected pattern in '$Path'."
    }

    [System.IO.File]::WriteAllText($Path, $updated, [System.Text.UTF8Encoding]::new($false))
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Get-ReleaseNotes {
    param(
        [string[]]$InlineNotes,
        [string]$NextChangelogPath
    )

    $resolvedNotes = @()

    if ($InlineNotes -and $InlineNotes.Count -gt 0) {
        if ($InlineNotes.Count -eq 1 -and $InlineNotes[0].Contains(",")) {
            $InlineNotes = $InlineNotes[0] -split '\s*,\s*'
        }
        foreach ($note in $InlineNotes) {
            $trimmed = $note.Trim()
            if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                $resolvedNotes += $trimmed.TrimStart('-', '*', ' ')
            }
        }
        return ,$resolvedNotes
    }

    if (-not (Test-Path -LiteralPath $NextChangelogPath)) {
        return @()
    }

    foreach ($line in Get-Content -LiteralPath $NextChangelogPath) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed.StartsWith("#")) { continue }
        $resolvedNotes += $trimmed.TrimStart('-', '*', ' ')
    }

    return ,$resolvedNotes
}

function Update-Changelog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [string]$ChangelogPath,

        [Parameter(Mandatory = $true)]
        [string[]]$ReleaseNotes
    )

    if ($ReleaseNotes.Count -eq 0) {
        throw "No release notes were provided. Add bullets to NEXT_CHANGELOG.md or pass -Notes."
    }

    $sectionLines = @("## v$Version", "")
    foreach ($note in $ReleaseNotes) {
        $sectionLines += "- $note"
    }
    $newSection = ($sectionLines -join [Environment]::NewLine).TrimEnd()

    $existing = ""
    if (Test-Path -LiteralPath $ChangelogPath) {
        $existing = (Get-Content -LiteralPath $ChangelogPath -Raw).Trim()
    }

    if ($existing -match "(?m)^## v$([regex]::Escape($Version))$") {
        throw "CHANGELOG.md already contains an entry for v$Version."
    }

    if ([string]::IsNullOrWhiteSpace($existing)) {
        Write-Utf8NoBom -Path $ChangelogPath -Content ($newSection + [Environment]::NewLine)
    } else {
        Write-Utf8NoBom -Path $ChangelogPath -Content ($newSection + [Environment]::NewLine + [Environment]::NewLine + $existing + [Environment]::NewLine)
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $scriptDir

$normalizedVersion = $Version.Trim()
if ($normalizedVersion.StartsWith("v", [System.StringComparison]::OrdinalIgnoreCase)) {
    $normalizedVersion = $normalizedVersion.Substring(1)
}

if ([string]::IsNullOrWhiteSpace($normalizedVersion)) {
    throw "Version cannot be empty."
}

$tagName = "v$normalizedVersion"
if (-not $CommitMessage) {
    $CommitMessage = "Release $tagName"
}

$tocPath = Join-Path $scriptDir "OakLFGSorter.toc"
$headerPath = Join-Path $scriptDir "UI_Header.lua"
$readmePath = Join-Path $scriptDir "README.md"
$changelogPath = Join-Path $scriptDir "CHANGELOG.md"
$nextChangelogPath = Join-Path $scriptDir "NEXT_CHANGELOG.md"

$releaseNotes = Get-ReleaseNotes -InlineNotes $Notes -NextChangelogPath $nextChangelogPath

$rawStatus = & "C:\Program Files\Git\cmd\git.exe" status --porcelain
if ($LASTEXITCODE -ne 0) {
    throw "Could not read git status."
}

$blockingStatus = @()
foreach ($line in ($rawStatus -split "`r?`n")) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $pathPart = $line.Substring(3).Trim()
    if ($pathPart -eq "NEXT_CHANGELOG.md") { continue }
    $blockingStatus += $line
}

if ($blockingStatus.Count -gt 0) {
    throw "Git working tree is not clean. Commit or stash your changes before running release-addon.ps1."
}

Update-Changelog -Version $normalizedVersion -ChangelogPath $changelogPath -ReleaseNotes $releaseNotes
Update-FileText -Path $tocPath -Pattern '(?m)^## Version:\s*.+$' -Replacement "## Version: $normalizedVersion"
Update-FileText -Path $headerPath -Pattern '(?m)VersionText:SetText\("\|cff888888v.*?\|r"\)' -Replacement "VersionText:SetText(""|cff888888v$normalizedVersion|r"")"
Update-FileText -Path $readmePath -Pattern '(?m)^Current repo version:\s*`[^`]+`$' -Replacement "Current repo version: ``$normalizedVersion``"
Write-Utf8NoBom -Path $nextChangelogPath -Content "# Add one bullet per line for the next release.`r`n# Example:`r`n# Fixed applicant tooltip positioning`r`n# Added a new quick filter preset`r`n"

Invoke-Git -Arguments @("add", "CHANGELOG.md", "NEXT_CHANGELOG.md", "OakLFGSorter.toc", "UI_Header.lua", "README.md")
Invoke-Git -Arguments @("commit", "-m", $CommitMessage)
Invoke-Git -Arguments @("tag", "-a", $tagName, "-m", $tagName)
Invoke-Git -Arguments @("push")
Invoke-Git -Arguments @("push", "origin", $tagName)

if (-not $SkipZip) {
    & (Join-Path $scriptDir "package-release.ps1") -Version $normalizedVersion
    if ($LASTEXITCODE -ne 0) {
        throw "package-release.ps1 failed."
    }
}

Write-Host ""
Write-Host "Release complete."
Write-Host "Version: $normalizedVersion"
Write-Host "Tag: $tagName"
Write-Host "If your integrations are configured, this pushed tag will trigger CurseForge and Wago automation."
Write-Host "Changelog source: CHANGELOG.md"
Write-Host "GitHub release page:"
Write-Host "https://github.com/Smokenoaken/OakLFGSorter/releases/new?tag=$tagName"
