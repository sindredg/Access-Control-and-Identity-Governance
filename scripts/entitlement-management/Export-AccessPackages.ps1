<#
.SYNOPSIS
    Phase 4 (code half) - export the Grafana access packages, their policies, role scopes, and
    separation-of-duties links to JSON, as repo evidence.

.DESCRIPTION
    The access packages are built in the portal wizard (the reliable path for the finicky create
    flow). This script is READ-ONLY: it reads the finished configuration back out and writes it to
    a JSON file, so the repo captures the "as code / policy as evidence" story without fighting the
    entitlement management create APIs.

    Filtering is done client-side (get all, then Where-Object) because the beta $filter on some of
    these collections is unreliable.

.NOTES
    Module : Microsoft.Graph.Authentication
    Scopes : EntitlementManagement.Read.All
    Output : ./access-packages-export.json (move into policies/entitlement-management/ in the repo)
#>

[CmdletBinding()]
param(
    [string] $CatalogName = "cat-grafana",
    [string] $PackagePrefix = "ap-grafana-",
    [string] $OutFile = (Join-Path $PSScriptRoot "access-packages-export.json")
)

$ErrorActionPreference = "Stop"
$em = "https://graph.microsoft.com/beta/identityGovernance/entitlementManagement"

Import-Module Microsoft.Graph.Authentication
Connect-MgGraph -Scopes "EntitlementManagement.Read.All" -NoWelcome

function Get-Many { param($Uri) (Invoke-MgGraphRequest -Method GET -Uri $Uri).value }

# Catalog
$catalog = Get-Many "$em/accessPackageCatalogs" | Where-Object displayName -eq $CatalogName | Select-Object -First 1
if (-not $catalog) { throw "Catalog '$CatalogName' not found." }
Write-Host "Catalog: $CatalogName ($($catalog.id))" -ForegroundColor Cyan

# Packages in that catalog
$packages = Get-Many "$em/accessPackages" |
    Where-Object { $_.catalogId -eq $catalog.id -and $_.displayName -like "$PackagePrefix*" }

$allPolicies = Get-Many "$em/accessPackageAssignmentPolicies"

$export = [ordered]@{
    exportedDateTime = (Get-Date).ToString("o")
    catalog = [ordered]@{
        displayName         = $catalog.displayName
        description         = $catalog.description
        catalogType         = $catalog.catalogType
        state               = $catalog.state
        isExternallyVisible = $catalog.isExternallyVisible
    }
    accessPackages = @()
}

foreach ($p in $packages) {
    Write-Host "  package: $($p.displayName)" -ForegroundColor Green
    $roleScopes  = Get-Many "$em/accessPackages/$($p.id)/accessPackageResourceRoleScopes"
    $incompat    = Get-Many "$em/accessPackages/$($p.id)/incompatibleAccessPackages"
    $policies    = $allPolicies | Where-Object accessPackageId -eq $p.id

    $export.accessPackages += [ordered]@{
        displayName   = $p.displayName
        description   = $p.description
        resourceRoles = @($roleScopes | ForEach-Object { $_.role.displayName + " on " + $_.role.originId })
        incompatibleWith = @($incompat | ForEach-Object { $_.displayName })
        policies = @($policies | ForEach-Object {
            [ordered]@{
                displayName    = $_.displayName
                durationInDays = $_.durationInDays
                requestorScope = $_.requestorSettings.scopeType
                approvalRequired = $_.requestApprovalSettings.isApprovalRequired
                approvalMode     = $_.requestApprovalSettings.approvalMode
            }
        })
    }
}

$export | ConvertTo-Json -Depth 10 | Out-File -Encoding utf8 $OutFile
Write-Host "`nWrote $OutFile" -ForegroundColor Cyan
