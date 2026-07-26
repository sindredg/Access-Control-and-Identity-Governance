<#
.SYNOPSIS
    Phase 4, step 2 - create the two access-package shells and attach the Member role scope.

.DESCRIPTION
    Defines WHAT each package grants (membership of grafana-viewers, Member role). Idempotent.

    The role scope is the call that is brittle across the two entitlement management API
    generations. We look up the REAL Member role from the catalog (v1.0 catalogs/{id}/resourceRoles
    with $expand=resource) and create the scope with what Graph returns, using v1.0 endpoints
    throughout, which is what the documented example uses.

.NOTES
    Scopes : EntitlementManagement.ReadWrite.All, Group.Read.All
#>

[CmdletBinding()]
param(
    [string]   $CatalogName     = "cat-grafana",
    [string]   $ViewerGroupName = "grafana-viewers",
    [string[]] $PackageNames    = @("ap-grafana-viewer-employees", "ap-grafana-contractor-guests")
)

$ErrorActionPreference = "Stop"
$beta = "https://graph.microsoft.com/beta/identityGovernance/entitlementManagement"
$v1   = "https://graph.microsoft.com/v1.0/identityGovernance/entitlementManagement"

Import-Module Microsoft.Graph.Authentication
Connect-MgGraph -Scopes @("EntitlementManagement.ReadWrite.All", "Group.Read.All") -NoWelcome
function Get-Many { param($Uri) (Invoke-MgGraphRequest -Method GET -Uri $Uri).value }

# Resolve group, catalog, resource
$group = Get-Many "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$ViewerGroupName'" | Select-Object -First 1
if (-not $group) { throw "Group '$ViewerGroupName' not found." }
$catalog = Get-Many "$beta/accessPackageCatalogs" | Where-Object displayName -eq $CatalogName | Select-Object -First 1
if (-not $catalog) { throw "Catalog '$CatalogName' not found. Run 01-catalog-resource.ps1 first." }
$resource = Get-Many "$v1/catalogs/$($catalog.id)/resources" | Where-Object originId -eq $group.id | Select-Object -First 1
if (-not $resource) { throw "Group resource not found in catalog. Run 01-catalog-resource.ps1 first." }
Write-Host "Catalog $CatalogName ($($catalog.id)); resource $($resource.id)" -ForegroundColor Cyan

# Look up the REAL Member role of the group resource (v1.0, expanded)
$roleUri = "$v1/catalogs/$($catalog.id)/resourceRoles?`$filter=(originSystem eq 'AadGroup' and displayName eq 'Member' and resource/id eq '$($resource.id)')&`$expand=resource"
$memberRole = Get-Many $roleUri | Select-Object -First 1
if (-not $memberRole) { throw "Could not find the Member role for the group resource." }
Write-Host "Member role: $($memberRole.originId)" -ForegroundColor Cyan

# Existing packages (client-side match)
$existing = Get-Many "$beta/accessPackages"

foreach ($name in $PackageNames) {
    $pkg = $existing | Where-Object { $_.displayName -eq $name -and $_.catalogId -eq $catalog.id } | Select-Object -First 1
    if (-not $pkg) {
        $pkg = Invoke-MgGraphRequest -Method POST -Uri "$beta/accessPackages" -Body (@{
            catalogId   = $catalog.id
            displayName = $name
            description = "Grafana Viewer access"
        } | ConvertTo-Json)
        Write-Host "Created access package $name ($($pkg.id))" -ForegroundColor Green
    } else {
        Write-Host "Access package $name exists ($($pkg.id))" -ForegroundColor Yellow
    }

    # Member role scope (idempotent)
    $scopes = Get-Many "$v1/accessPackages/$($pkg.id)/resourceRoleScopes"
    if (-not $scopes) {
        Invoke-MgGraphRequest -Method POST -Uri "$v1/accessPackages/$($pkg.id)/resourceRoleScopes" -Body (@{
            role  = @{
                originId     = $memberRole.originId
                displayName  = $memberRole.displayName
                originSystem = $memberRole.originSystem
                resource     = @{
                    id           = $memberRole.resource.id
                    originId     = $memberRole.resource.originId
                    originSystem = $memberRole.resource.originSystem
                }
            }
            scope = @{ originId = $memberRole.resource.originId; originSystem = "AadGroup"; isRootScope = $true }
        } | ConvertTo-Json -Depth 8) | Out-Null
        Write-Host "  attached Member role scope" -ForegroundColor Green
    } else {
        Write-Host "  Member role scope already present" -ForegroundColor Yellow
    }
}