<#
.SYNOPSIS
    Phase 4, step 4 - mark the two access packages incompatible (separation of duties).

.DESCRIPTION
    A user holding the contractor package can no longer request the employee package (and vice
    versa). Idempotent.

.NOTES
    Scopes : EntitlementManagement.ReadWrite.All
#>

[CmdletBinding()]
param(
    [string] $ViewerPackageName     = "ap-grafana-viewer-employees",
    [string] $ContractorPackageName = "ap-grafana-contractor-guests"
)

$ErrorActionPreference = "Stop"
$beta = "https://graph.microsoft.com/beta/identityGovernance/entitlementManagement"

Import-Module Microsoft.Graph.Authentication
Connect-MgGraph -Scopes "EntitlementManagement.ReadWrite.All" -NoWelcome
function Get-Many { param($Uri) (Invoke-MgGraphRequest -Method GET -Uri $Uri).value }

$packages = Get-Many "$beta/accessPackages"
$viewer     = $packages | Where-Object displayName -eq $ViewerPackageName     | Select-Object -First 1
$contractor = $packages | Where-Object displayName -eq $ContractorPackageName | Select-Object -First 1
if (-not $viewer -or -not $contractor) { throw "Both packages must exist. Run 02-access-packages.ps1 first." }

# Already linked?
$already = Get-Many "$beta/accessPackages/$($viewer.id)/incompatibleAccessPackages" |
    Where-Object id -eq $contractor.id
if ($already) {
    Write-Host "Already incompatible." -ForegroundColor Yellow
} else {
    Invoke-MgGraphRequest -Method POST -Uri "$beta/accessPackages/$($viewer.id)/incompatibleAccessPackages/`$ref" -Body (@{
        "@odata.id" = "$beta/accessPackages/$($contractor.id)"
    } | ConvertTo-Json) | Out-Null
    Write-Host "Marked '$ContractorPackageName' incompatible with '$ViewerPackageName'" -ForegroundColor Green
}
