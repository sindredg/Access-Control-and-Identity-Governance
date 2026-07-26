# Conditional Access policies (deploy one at a time)

Each policy is a JSON definition under `policies/`. `Deploy-CaPolicy.ps1` deploys a single
policy, or all of them, in report-only. This lets you roll out one policy, review its impact,
then move to the next.

## How it works

- Every policy file is authored in **report-only** (`"state": "enabledForReportingButNotEnforced"`).
- The break-glass group id is not stored in the files. The token `__BREAKGLASS_GROUP_ID__` is
  substituted at deploy time (resolved from the group display name `breakglass-accounts`, or
  passed with `-BreakGlassGroupId`).
- Policies are created with raw Graph JSON via `Invoke-MgGraphRequest`, so `@odata.bind`
  bindings (for example authentication strengths) are preserved.
- Deploy is **idempotent**: a policy whose display name already exists is skipped.

## Named locations

`CA004` references a country allow-list by id, via the token `__ALLOWED_COUNTRIES_LOCATION_ID__`.
When a policy being deployed contains that token, the script creates or updates the named location
from `named-locations/loc-allowed-countries.json` and substitutes the resulting id.

Edit that file to change the allowed countries (currently `NO`, `ES`, `GB`). A newly created named
location needs a moment to replicate before a policy can reference it, so the script waits and
retries on the `NamedLocation ... does not exist` error.

## Usage

```powershell
# List available policy files
.\Deploy-CaPolicy.ps1 -List

# Deploy one policy
.\Deploy-CaPolicy.ps1 -PolicyName CA001-AllUsers-RequireMFA

# Deploy a specific file
.\Deploy-CaPolicy.ps1 -PolicyFile .\policies\CA005-AllUsers-SessionControls.json

# Deploy all (skips any that already exist)
.\Deploy-CaPolicy.ps1 -All
```

Scopes: `Policy.ReadWrite.ConditionalAccess`, `Policy.Read.All`, `Group.Read.All`.
Role: Conditional Access Administrator (or Security Administrator).

## Enforce a policy (separate, deliberate step)

Deployment only creates report-only policies. After reviewing impact enforce one at a time:

```powershell
$p = Get-MgIdentityConditionalAccessPolicy -All | Where-Object DisplayName -eq "<Policy-Name>"
Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $p.Id -State "enabled"
```

## Policies

Phase 1, baseline:

| File | What it does | Notes |
| --- | --- | --- |
| `CA001-AllUsers-RequireMFA` | Require MFA for all users | Core baseline |
| `CA003-BlockLegacyAuth` | Block legacy authentication | Core baseline |
| `CA005-AllUsers-SessionControls` | Sign-in frequency (8h) + no persistent browser | Highest friction, consider scoping to admins / unmanaged before enforcing |
| `CA006-Guests-RequireMFA` | MFA for guest / external users | |
| `CA007-AzureManagement-RequireMFA` | MFA for the Azure management plane | |
| `CA008-SecurityInfoRegistration-MFA` | MFA when registering / changing security info | Uses a user action, not an app target. Can deadlock a user with no MFA method yet, see the [troubleshooting log](../../docs/99-troubleshooting.md) |

Phase 2, location and risk:

| File | What it does | Notes |
| --- | --- | --- |
| `CA004-BlockOutsideAllowedCountries` | Block sign-ins from outside the allowed countries | Needs `named-locations/loc-allowed-countries.json` |
| `CA010-SignInRisk-Block` | Block on medium / high sign-in risk | Identity Protection |
| `CA011-UserRisk-RequirePasswordChange` | MFA + secure password change on high user risk | Identity Protection |

Numbering gaps: `CA002` (phishing-resistant MFA for admins) and `CA009` are reserved and not
built in this lab.
