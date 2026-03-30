param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$CommitMessage,

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

$status = & "C:\Program Files\Git\cmd\git.exe" status --porcelain
if ($LASTEXITCODE -ne 0) {
    throw "Could not read git status."
}
if (-not [string]::IsNullOrWhiteSpace($status)) {
    throw "Git working tree is not clean. Commit or stash your changes before running release-addon.ps1."
}

$tocPath = Join-Path $scriptDir "OakLFGSorter.toc"
$headerPath = Join-Path $scriptDir "UI_Header.lua"
$readmePath = Join-Path $scriptDir "README.md"

Update-FileText -Path $tocPath -Pattern '(?m)^## Version:\s*.+$' -Replacement "## Version: $normalizedVersion"
Update-FileText -Path $headerPath -Pattern '(?m)VersionText:SetText\("\|cff888888v.*?\|r"\)' -Replacement "VersionText:SetText(""|cff888888v$normalizedVersion|r"")"
Update-FileText -Path $readmePath -Pattern '(?m)^Current repo version:\s*`[^`]+`$' -Replacement "Current repo version: ``$normalizedVersion``"

Invoke-Git -Arguments @("add", "OakLFGSorter.toc", "UI_Header.lua", "README.md")
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
Write-Host "GitHub release page:"
Write-Host "https://github.com/Smokenoaken/OakLFGSorter/releases/new?tag=$tagName"
