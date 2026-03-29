param(
    [string]$Version,
    [string]$OutputDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonName = Split-Path -Leaf $scriptDir
$tocPath = Join-Path $scriptDir "$addonName.toc"

if (-not (Test-Path -LiteralPath $tocPath)) {
    throw "Could not find TOC file at '$tocPath'."
}

if (-not $Version) {
    $tocVersionLine = Select-String -Path $tocPath -Pattern '^## Version:\s*(.+)$' | Select-Object -First 1
    if (-not $tocVersionLine) {
        throw "Could not find a '## Version:' line in '$tocPath'."
    }
    $Version = $tocVersionLine.Matches[0].Groups[1].Value.Trim()
}

if (-not $OutputDir) {
    $OutputDir = Join-Path $scriptDir "dist"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$zipPath = Join-Path $OutputDir "$addonName-v$Version.zip"
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

$excludeNames = @(
    ".git",
    ".chrome-profile",
    ".edge-profile",
    "dist"
)

$excludeFiles = @(
    ".gitignore",
    "README.md",
    "RELEASING.md",
    "package-release.ps1",
    "addon_summary_onepager.html",
    "OakLFGSorter_Summary.pdf"
)

$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)

try {
    $files = Get-ChildItem -LiteralPath $scriptDir -Recurse -File | Where-Object {
        $fullPath = $_.FullName
        $relativePath = $fullPath.Substring($scriptDir.Length).TrimStart('\')
        $parts = $relativePath -split '[\\/]'

        if ($parts.Length -eq 0) {
            return $false
        }

        if ($excludeNames -contains $parts[0]) {
            return $false
        }

        if ($excludeFiles -contains $relativePath) {
            return $false
        }

        if ($relativePath -like '*.zip') {
            return $false
        }

        return $true
    }

    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($scriptDir.Length).TrimStart('\')
        $entryName = ($addonName + "\" + $relativePath).Replace("\", "/")
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip,
            $file.FullName,
            $entryName,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
}
finally {
    $zip.Dispose()
}

Write-Host "Created release zip:"
Write-Host $zipPath
