# Phase 4 - Entitlement management (access packages) as code

Deploy the Grafana access packages with Microsoft Graph. Split into small, ordered, idempotent
scripts so a failure in one step doesn't block the others, and so each step is easy to re-run.

## Run order

```powershell
.\01-catalog-resource.ps1                    # catalog cat-grafana + grafana-viewers resource
.\02-access-packages.ps1                      # two package shells + Member role scope
.\03-assignment-policies.ps1 -ApproverUpn "Sindre@<tenant>.onmicrosoft.com"
.\04-separation-of-duties.ps1                 # mark the two packages incompatible
```

Each script resolves everything by name (catalog, group, packages, approver), so there are no IDs
to pass between them. All are idempotent: re-running skips what already exists.

## What each builds

| Script | Builds |
| --- | --- |
| `01-catalog-resource` | Catalog `cat-grafana` (externally visible) + `grafana-viewers` as a resource |
| `02-access-packages` | `ap-grafana-viewer-employees` + `ap-grafana-contractor-guests`, each granting the group's **Member** role |
| `03-assignment-policies` | Viewer: internal members, **manager** approval, 90 days. Contractor: external users, **Sindre G** approval, 30 days |
| `04-separation-of-duties` | The two packages marked incompatible |

