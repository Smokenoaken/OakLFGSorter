$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-ConfiguredValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $value = [Environment]::GetEnvironmentVariable($Name, "Process")
    if ([string]::IsNullOrWhiteSpace($value)) {
        $value = [Environment]::GetEnvironmentVariable($Name, "User")
    }

    return $value
}

function Read-Utf8Text {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $utf8 = [System.Text.UTF8Encoding]::new($false, $true)
    $reader = [System.IO.StreamReader]::new($Path, $utf8, $true)
    try {
        return $reader.ReadToEnd()
    }
    finally {
        $reader.Dispose()
    }
}

function Escape-LuaString {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    if ($Value -match '[\x00-\x1F]') {
        throw "Patreon supporter name contains a control character: '$Value'."
    }

    return $Value.Replace('\', '\\').Replace('"', '\"')
}

function Update-LuaStringList {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Declaration,

        [Parameter(Mandatory = $true)]
        [string[]]$Names
    )

    $content = Read-Utf8Text -Path $Path
    $start = $content.IndexOf($Declaration, [System.StringComparison]::Ordinal)
    if ($start -lt 0) {
        throw "Could not find '$Declaration' in '$Path'."
    }

    $bodyStart = $content.IndexOf("`n", $start)
    if ($bodyStart -lt 0) {
        throw "Could not find the end of '$Declaration' in '$Path'."
    }
    $bodyStart++

    $closingMatch = [regex]::Match($content.Substring($bodyStart), '(?m)^[ \t]*\}')
    if (-not $closingMatch.Success) {
        throw "Could not find the closing brace for '$Declaration' in '$Path'."
    }

    $closeStart = $bodyStart + $closingMatch.Index
    $newline = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lines = foreach ($name in $Names) {
        '    "' + (Escape-LuaString -Value $name) + '",'
    }
    $replacement = $Declaration + $newline + ($lines -join $newline) + $newline + '}'
    $updated = $content.Substring(0, $start) + $replacement + $content.Substring($closeStart + $closingMatch.Length)

    if ($updated -ne $content) {
        [System.IO.File]::WriteAllText($Path, $updated, [System.Text.UTF8Encoding]::new($false))
        return $true
    }

    return $false
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$supportersPath = Join-Path $scriptDir "Supporters.lua"
$accessToken = Get-ConfiguredValue -Name "OAKUI_PATREON_ACCESS_TOKEN"
$campaignId = Get-ConfiguredValue -Name "OAKUI_PATREON_CAMPAIGN_ID"

if ([string]::IsNullOrWhiteSpace($accessToken)) {
    throw "OAKUI_PATREON_ACCESS_TOKEN is not configured."
}
if ([string]::IsNullOrWhiteSpace($campaignId)) {
    throw "OAKUI_PATREON_CAMPAIGN_ID is not configured."
}

$headers = @{ Authorization = "Bearer $accessToken" }
$baseUrl = "https://www.patreon.com/api/oauth2/v2/campaigns/$campaignId/members?page%5Bcount%5D=100&fields%5Bmember%5D=full_name,patron_status,currently_entitled_amount_cents,pledge_relationship_start"
$nextUrl = $baseUrl
$allMembers = [System.Collections.Generic.List[object]]::new()

do {
    $page = Invoke-RestMethod -Uri $nextUrl -Headers $headers -Method Get
    foreach ($member in @($page.data)) {
        [void]$allMembers.Add($member)
    }

    $nextUrl = $null
    if ($page.PSObject.Properties.Name -contains "links" -and $page.links -and $page.links.PSObject.Properties.Name -contains "next" -and $page.links.next) {
        $nextUrl = [string]$page.links.next
    }
    $nextCursor = $null
    if ($page.PSObject.Properties.Name -contains "meta" -and $page.meta -and $page.meta.PSObject.Properties.Name -contains "pagination" -and $page.meta.pagination -and $page.meta.pagination.PSObject.Properties.Name -contains "cursors" -and $page.meta.pagination.cursors -and $page.meta.pagination.cursors.PSObject.Properties.Name -contains "next" -and $page.meta.pagination.cursors.next) {
        $nextCursor = [string]$page.meta.pagination.cursors.next
    }
    if ([string]::IsNullOrWhiteSpace($nextUrl) -and -not [string]::IsNullOrWhiteSpace($nextCursor)) {
        $cursor = [uri]::EscapeDataString($nextCursor)
        $nextUrl = "$baseUrl&page%5Bcursor%5D=$cursor"
    }
} while (-not [string]::IsNullOrWhiteSpace($nextUrl))

$eligibleMembers = @(
    $allMembers |
        Where-Object {
            $attributes = $_.attributes
            $attributes -and
            $attributes.patron_status -eq "active_patron" -and
            [int64]$attributes.currently_entitled_amount_cents -gt 0 -and
            -not [string]::IsNullOrWhiteSpace([string]$attributes.full_name) -and
            -not [string]::IsNullOrWhiteSpace([string]$attributes.pledge_relationship_start)
        } |
        Sort-Object `
            @{ Expression = { [datetime]$_.attributes.pledge_relationship_start }; Ascending = $true }, `
            @{ Expression = { [string]$_.attributes.full_name }; Ascending = $true }
)

if ($eligibleMembers.Count -eq 0) {
    throw "Patreon returned no eligible active paid members; refusing to erase the existing supporter list."
}

$names = @($eligibleMembers | ForEach-Object { ([string]$_.attributes.full_name).Trim() })
$changed = Update-LuaStringList -Path $supportersPath -Declaration "addonTable.Patreons = {" -Names $names

if ($changed) {
    Write-Host "Updated Supporters.lua with $($names.Count) active paid Patreon supporters."
}
else {
    Write-Host "Supporters.lua already contains the current $($names.Count)-member Patreon list."
}
