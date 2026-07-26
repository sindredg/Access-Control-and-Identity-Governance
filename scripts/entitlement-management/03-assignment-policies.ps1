<#
.SYNOPSIS
    Phase 4, step 3 - create the request / approval policies for the two access packages.

.DESCRIPTION
    Defines WHO can request each package, the approval flow, and the lifetime. Idempotent (one
    policy per package). Uses the beta accessPackageAssignmentPolicies shape (requestorSettings /
    durationInDays / requestApprovalSettings), which is the documented classic form.

      viewer-employees  : internal members request; the requestor's MANAGER approves; 90 days.
      contractor-guests : external users request; SINDRE G approves; 30 days.

.NOTES
    Scopes : EntitlementManagement.ReadWrite.All, User.Read.All
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ApproverUpn,        # e.g. "Sindre@grytebdigitalsolutions.onmicrosoft.com"
    [string] $ViewerPackageName     = "ap-grafana-viewer-employees",
    [string] $ContractorPackageName = "ap-grafana-contractor-guests",
    [int]    $ViewerDurationDays     = 90,
    [int]    $ContractorDurationDays = 30
)

$ErrorActionPreference = "Stop"
$beta = "https://graph.microsoft.com/beta/identityGovernance/entitlementManagement"

Import-Module Microsoft.Graph.Authentication
Connect-MgGraph -Scopes @("EntitlementManagement.ReadWrite.All", "User.Read.All") -NoWelcome
function Get-Many { param($Uri) (Invoke-MgGraphRequest -Method GET -Uri $Uri).value }

$approver = Get-Many "https://graph.microsoft.com/v1.0/users?`$filter=userPrincipalName eq '$ApproverUpn'" | Select-Object -First 1
if (-not $approver) { throw "Approver '$ApproverUpn' not found." }
$approverId = $approver.id
Write-Host "Approver: $ApproverUpn ($approverId)" -ForegroundColor Cyan

$packages = Get-Many "$beta/accessPackages"
$allPolicies = Get-Many "$beta/accessPackageAssignmentPolicies"

function New-PolicyIfMissing {
    param([string] $PackageName, [hashtable] $Body)
    $pkg = $packages | Where-Object displayName -eq $PackageName | Select-Object -First 1
    if (-not $pkg) { throw "Access package '$PackageName' not found. Run 02-access-packages.ps1 first." }
    if ($allPolicies | Where-Object accessPackageId -eq $pkg.id) {
        Write-Host "$PackageName : policy already exists" -ForegroundColor Yellow
        return
    }
    $Body.accessPackageId = $pkg.id
    Invoke-MgGraphRequest -Method POST -Uri "$beta/accessPackageAssignmentPolicies" -Body ($Body | ConvertTo-Json -Depth 10) | Out-Null
    Write-Host "$PackageName : created policy" -ForegroundColor Green
}

# Viewer - manager approval, internal, 90 days
New-PolicyIfMissing -PackageName $ViewerPackageName -Body @{
    displayName    = "Employees - manager approval - $ViewerDurationDays days"
    description    = "Internal members request; the requestor's manager approves."
    durationInDays = $ViewerDurationDays
    requestorSettings = @{ scopeType = "AllExistingDirectoryMemberUsers"; acceptRequests = $true; allowedRequestors = @() }
    requestApprovalSettings = @{
        isApprovalRequired = $true; isApprovalRequiredForExtension = $false
        isRequestorJustificationRequired = $true; approvalMode = "SingleStage"
        approvalStages = @(@{
            approvalStageTimeOutInDays = 7; isApproverJustificationRequired = $true; isEscalationEnabled = $false
            primaryApprovers = @(
                @{ "@odata.type" = "#microsoft.graph.requestorManager"; managerLevel = 1 }
                @{ "@odata.type" = "#microsoft.graph.singleUser"; id = $approverId; isBackup = $true }
            )
        })
    }
}

# Contractor - Sindre G approval, external, 30 days
New-PolicyIfMissing -PackageName $ContractorPackageName -Body @{
    displayName    = "External contractors - approver Sindre G - $ContractorDurationDays days"
    description    = "External / B2B users request; Sindre G approves."
    durationInDays = $ContractorDurationDays
    requestorSettings = @{ scopeType = "AllExternalSubjects"; acceptRequests = $true; allowedRequestors = @() }
    requestApprovalSettings = @{
        isApprovalRequired = $true; isApprovalRequiredForExtension = $false
        isRequestorJustificationRequired = $true; approvalMode = "SingleStage"
        approvalStages = @(@{
            approvalStageTimeOutInDays = 7; isApproverJustificationRequired = $true; isEscalationEnabled = $false
            primaryApprovers = @(@{ "@odata.type" = "#microsoft.graph.singleUser"; id = $approverId })
        })
    }
}