<#
.SYNOPSIS
    Phase 4, step 1 - create the catalog and add the grafana-viewers group as a resource.

.DESCRIPTION
    The foundation the access packages sit on. Idempotent; filters client-side (get all, then
    Where-Object) because the beta $filter on these collections is unreliable and was creating
    duplicate catalogs.

.NOTES
    Scopes : EntitlementManagement.ReadWrite.All, Group.Read.All
#>

[CmdletBinding()]
param(
    [string] $CatalogName     = "cat-grafana",
    [string] $ViewerGroupName = "grafana-viewers"
)

$ErrorActionPreference = "Stop"
$base = "https://graph.microsoft.com/beta/identityGovernance/entitlementManagement"

Import-Module Microsoft.Graph.Authentication
Connect-MgGraph -Scopes @("EntitlementManagement.ReadWrite.All", "Group.Read.All") -NoWelcome
function Get-Many { param($Uri) (Invoke-MgGraphRequest -Method GET -Uri $Uri).value }

# Group
$group = Get-Many "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$ViewerGroupName'" | Select-Object -First 1
if (-not $group) { throw "Group '$ViewerGroupName' not found." }
Write-Host "Viewer group: $ViewerGroupName ($($group.id))" -ForegroundColor Cyan

# Catalog (idempotent)
$catalog = Get-Many "$base/accessPackageCatalogs" | Where-Object displayName -eq $CatalogName | Select-Object -First 1
if (-not $catalog) {
    $catalog = Invoke-MgGraphRequest -Method POST -Uri "$base/accessPackageCatalogs" -Body (@{
        displayName         = $CatalogName
        description         = "Grafana access packages"
        catalogType         = "UserManaged"
        state               = "published"
        isExternallyVisible = $true
    } | ConvertTo-Json)
    Write-Host "Created catalog $CatalogName ($($catalog.id))" -ForegroundColor Green
} else {
    Write-Host "Catalog $CatalogName exists ($($catalog.id))" -ForegroundColor Yellow
}

# Group resource (idempotent, async)
$resource = Get-Many "$base/accessPackageCatalogs/$($catalog.id)/accessPackageResources" |
    Where-Object originId -eq $group.id | Select-Object -First 1
if (-not $resource) {
    Invoke-MgGraphRequest -Method POST -Uri "$base/accessPackageResourceRequests" -Body (@{
        catalogId             = $catalog.id
        requestType           = "AdminAdd"
        accessPackageResource = @{ resourceType = "AadGroup"; originId = $group.id; originSystem = "AadGroup" }
    } | ConvertTo-Json) | Out-Null
    Write-Host "Requested add of '$ViewerGroupName', waiting..." -ForegroundColor DarkGray
    for ($i = 1; $i -le 12 -and -not $resource; $i++) {
        Start-Sleep -Seconds 5
        $resource = Get-Many "$base/accessPackageCatalogs/$($catalog.id)/accessPackageResources" |
            Where-Object originId -eq $group.id | Select-Object -First 1
    }
    if (-not $resource) { throw "Resource did not appear in time. Re-run to continue." }
    Write-Host "Group resource added ($($resource.id))" -ForegroundColor Green
} else {
    Write-Host "Group resource already in catalog ($($resource.id))" -ForegroundColor Yellow
}
