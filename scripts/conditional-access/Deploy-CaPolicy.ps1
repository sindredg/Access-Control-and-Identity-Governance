<#
.SYNOPSIS
    Deploy Conditional Access policies from JSON files, one at a time (or all), in report-only.

.DESCRIPTION
    Each policy lives as its own JSON file under ./policies. This lets you deploy one policy at a
    time, review its impact, then deploy the next.

    The break-glass group id is NOT stored in the files. The token __BREAKGLASS_GROUP_ID__ is
    substituted at deploy time (resolved from the group display name, or -BreakGlassGroupId).

    Policies are created via raw Graph JSON (Invoke-MgGraphRequest), which preserves @odata.bind
    bindings such as authentication strengths (the typed SDK drops those). Idempotent: a policy
    whose displayName already exists is skipped.

.EXAMPLE
    .\Deploy-CaPolicy.ps1 -PolicyName CA001-AllUsers-RequireMFA
    Deploy a single policy by name.

.EXAMPLE
    .\Deploy-CaPolicy.ps1 -All
    Deploy every policy file in ./policies (skips any that already exist).

.EXAMPLE
    .\Deploy-CaPolicy.ps1 -List
    List the available policy files without deploying.

.NOTES
    Scopes : Policy.ReadWrite.ConditionalAccess, Policy.Read.All, Group.Read.All
    Role   : Conditional Access Administrator (or Security Administrator)
    All policy files are authored in report-only. Enforcement is a separate, deliberate action:
      Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId <id> -State "enabled"
#>

[CmdletBinding(DefaultParameterSetName = 'One')]
param(
    [Parameter(ParameterSetName = 'One', Position = 0)]
    [string] $PolicyName,

    [Parameter(ParameterSetName = 'File')]
    [string] $PolicyFile,

    [Parameter(ParameterSetName = 'All')]
    [switch] $All,

    [Parameter(ParameterSetName = 'List')]
    [switch] $List,

    [string] $PoliciesPath = (Join-Path $PSScriptRoot 'policies'),
    [string] $NamedLocationsPath = (Join-Path $PSScriptRoot 'named-locations'),
    [string] $BreakGlassGroupName = "breakglass-accounts",
    [string] $BreakGlassGroupId
)

$ErrorActionPreference = "Stop"

# --- List mode: no connection needed ----------------------------------------
if ($List) {
    Get-ChildItem -Path $PoliciesPath -Filter '*.json' | Sort-Object Name |
        ForEach-Object { Write-Host ("  {0}" -f $_.BaseName) }
    return
}

Import-Module Microsoft.Graph.Authentication
Connect-MgGraph -Scopes @(
    "Policy.ReadWrite.ConditionalAccess",
    "Policy.Read.All",
    "Group.Read.All"
) -NoWelcome

# --- Resolve break-glass exclusion group ------------------------------------
if (-not $BreakGlassGroupId) {
    $bg = Get-MgGroup -Filter "displayName eq '$BreakGlassGroupName'" -ConsistencyLevel eventual -CountVariable c -All | Select-Object -First 1
    if (-not $bg) { throw "Break-glass group '$BreakGlassGroupName' not found. Create it (Phase 0) or pass -BreakGlassGroupId." }
    $BreakGlassGroupId = $bg.Id
}
Write-Host "Break-glass exclusion group: $BreakGlassGroupName ($BreakGlassGroupId)" -ForegroundColor Cyan

# --- Determine which policy file(s) to deploy -------------------------------
$files = switch ($PSCmdlet.ParameterSetName) {
    'All'  { Get-ChildItem -Path $PoliciesPath -Filter '*.json' | Sort-Object Name }
    'File' { Get-Item -Path $PolicyFile }
    'One'  {
        if (-not $PolicyName) { throw "Provide -PolicyName, -PolicyFile, -All, or -List." }
        $p = Join-Path $PoliciesPath ("{0}.json" -f ($PolicyName -replace '\.json$', ''))
        if (-not (Test-Path $p)) { throw "Policy file not found: $p" }
        Get-Item $p
    }
}

# --- Ensure the allowed-countries named location (only if a policy needs it) -
# CA004 references the country allow-list by id via the __ALLOWED_COUNTRIES_LOCATION_ID__ token.
# The country set is defined in named-locations/loc-allowed-countries.json (edit that file to
# change the allowed countries). We create or update the named location from it here.
$allowedCountriesLocationId = $null
if ($files | Where-Object { (Get-Content $_.FullName -Raw) -match "__ALLOWED_COUNTRIES_LOCATION_ID__" }) {
    $locFile = Join-Path $NamedLocationsPath 'loc-allowed-countries.json'
    if (-not (Test-Path $locFile)) { throw "Named location file not found: $locFile" }
    $locJson = Get-Content -Path $locFile -Raw
    $locDef  = $locJson | ConvertFrom-Json
    $locName = $locDef.displayName
    $countryList = ($locDef.countriesAndRegions -join ', ')

    $existingLoc = Get-MgIdentityConditionalAccessNamedLocation -All |
        Where-Object { $_.DisplayName -eq $locName } | Select-Object -First 1

    if ($existingLoc) {
        Invoke-MgGraphRequest -Method PATCH `
            -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations/$($existingLoc.Id)" `
            -Body $locJson | Out-Null
        $allowedCountriesLocationId = $existingLoc.Id
        Write-Host "Updated named location '$locName' ($countryList)" -ForegroundColor Yellow
    } else {
        $resp = Invoke-MgGraphRequest -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations" `
            -Body $locJson
        $allowedCountriesLocationId = $resp.id
        Write-Host "Created named location '$locName' ($countryList)" -ForegroundColor Green
        # A new named location needs a moment to replicate before a policy can reference it.
        Write-Host "Waiting for named location to replicate..." -ForegroundColor DarkGray
        for ($i = 1; $i -le 12; $i++) {
            if (Get-MgIdentityConditionalAccessNamedLocation -NamedLocationId $allowedCountriesLocationId -ErrorAction SilentlyContinue) { break }
            Start-Sleep -Seconds 5
        }
        Start-Sleep -Seconds 10
    }
}

# --- Deploy ------------------------------------------------------------------
$existing = Get-MgIdentityConditionalAccessPolicy -All

foreach ($f in $files) {
    $body = (Get-Content -Path $f.FullName -Raw).Replace("__BREAKGLASS_GROUP_ID__", $BreakGlassGroupId)
    if ($allowedCountriesLocationId) {
        $body = $body.Replace("__ALLOWED_COUNTRIES_LOCATION_ID__", $allowedCountriesLocationId)
    }
    $name = ($body | ConvertFrom-Json).displayName

    if ($existing | Where-Object { $_.DisplayName -eq $name }) {
        Write-Host "Skipping '$name' (already exists)" -ForegroundColor Yellow
        continue
    }

    # Retry to absorb named-location replication lag (400 "NamedLocation ... does not exist").
    $created = $false
    for ($i = 1; $i -le 5 -and -not $created; $i++) {
        try {
            Invoke-MgGraphRequest -Method POST `
                -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" `
                -Body $body -ErrorAction Stop | Out-Null
            $created = $true
            Write-Host "Created (report-only): $name" -ForegroundColor Green
        } catch {
            if ($_.Exception.Message -match "NamedLocation.*does not exist") {
                Write-Host "Named location not propagated yet, retrying in 10s ($i/5)..." -ForegroundColor Yellow
                Start-Sleep -Seconds 10
            } else {
                throw
            }
        }
    }
    if (-not $created) { throw "Failed to create '$name' after retries." }
}
