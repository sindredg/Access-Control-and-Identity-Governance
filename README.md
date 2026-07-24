# Access Control & Identity Governance on Entra ID

> **Status: work in progress.** Phases 0 to 2 are built and documented. The privileged-access and
> identity-governance phases (PIM, entitlement management, access reviews, lifecycle workflows,
> monitoring) are planned. This README will grow as they land.

A hands-on lab that governs access to a self-hosted application with Microsoft Entra ID: SSO, Conditional
Access, risk-based policies, and (coming) Privileged Identity Management and identity governance.

It builds directly on [IAM-on-self-hosted-webapp](https://github.com/sindredg/IAM-on-self-hosted-webapp),
which stood up Entra ID as the identity provider for a self-hosted **Grafana** app (OIDC SSO,
app-role mapping, SCIM provisioning). Where that project answered *who can sign in and what role
they get*, this one governs *under what conditions they sign in, how privilege is granted, and how
access is reviewed and revoked*.

Aligned to the two SC-300 learning paths: [Authentication and access management](https://learn.microsoft.com/training/paths/implement-authentication-access-management-solution/)
and [Identity governance strategy](https://learn.microsoft.com/training/paths/plan-implement-identity-governance-strategy/).

## Status by phase

| Phase | Focus | State | Docs |
| --- | --- | --- | --- |
| 0 | Foundations: break-glass account (FIDO2), personas | Done | [break-glass](docs/00-phase0-breakglass-walkthrough.md) |
| 1 | Conditional Access baseline (MFA, legacy-auth, session, guests, mgmt, security-info) | Done | [conditional-access](docs/01-conditional-access.md) |
| 2 | Locations and risk (country allow-list, sign-in / user risk) | Done | [context-risk](docs/02-ca-context-risk.md) |
| 3 | Privileged Identity Management (JIT admin, PIM for Groups) | Planned | |
| 4 | Entitlement management (access packages) | Planned | |
| 5 | Access reviews | Planned | |
| 6 | Lifecycle workflows (joiner / mover / leaver) | Planned | |
| 7 | Monitoring, audit and evidence | Planned | |

## Conditional Access policies (built)

Every policy is a JSON definition deployed one at a time (or all) with `Deploy-CaPolicy.ps1`,
authored in report-only, with the break-glass group excluded.

| Policy | What it does |
| --- | --- |
| `CA001-AllUsers-RequireMFA` | Require MFA for all users |
| `CA003-BlockLegacyAuth` | Block legacy authentication |
| `CA004-BlockOutsideAllowedCountries` | Block sign-ins outside the allowed countries (Norway, Spain, UK) |
| `CA005-AllUsers-SessionControls` | Sign-in frequency + no persistent browser |
| `CA006-Guests-RequireMFA` | MFA for guest / external users |
| `CA007-AzureManagement-RequireMFA` | MFA for the Azure management plane |
| `CA008-SecurityInfoRegistration-MFA` | MFA to register / change security info |
| `CA010-SignInRisk-Block` | Block on medium / high sign-in risk (Identity Protection) |
| `CA011-UserRisk-RequirePasswordChange` | MFA + secure password change on high user risk |

## The cast

| Persona | Group | Role | Purpose |
| --- | --- | --- | --- |
| Amanda Admin | `grafana-admins` | Admin | Admin persona (Phase 3 moves this to PIM-eligible) |
| Priya Approver | `grafana-admins` | Approver | Approves PIM activations and access reviews |
| Edvard Editor | `grafana-editors` | Editor | Standard workforce user |
| Victoria Viewer | `grafana-viewers` | Viewer | Standard workforce user |
| Nils Worker | `grafana-viewers` | Viewer | Drives the lifecycle workflow (Phase 6) |
| Adam Analyst | `grafana-viewers` | Viewer | Requests access via an access package (Phase 4) |
| Carla Contractor | external (B2B) | Viewer | Guest access + entitlement management |
| Break-glass | `breakglass-accounts` | Global Admin | Emergency access, FIDO2, excluded from all CA and PIM |

## Repository layout

```
entra-access-governance-lab/
├── README.md                         This file
├── docs/
│   ├── 00-phase0-breakglass-walkthrough.md   Break-glass account + FIDO2 (portal)
│   ├── 01-conditional-access.md              Phase 1: CA baseline + enforcement behavior
│   ├── 02-ca-context-risk.md                 Phase 2: country allow-list + risk policies
│   ├── 99-troubleshooting.md                 Symptom / cause / fix / lesson log
│   └── images/                               Evidence screenshots, per phase
└── scripts/
    ├── 00-seed-personas.ps1                  Seed the extended cast + groups + guest invite
    └── conditional-access/
        ├── Deploy-CaPolicy.ps1               Deploy one policy (or all), report-only, idempotent
        ├── policies/                         One JSON per CA policy
        └── named-locations/                  Country allow-list as JSON
```

Break-glass is deliberately a portal walkthrough (a one-off, security-critical task), not a script.

## Conventions

- **No secrets in the repo.** Placeholders only; tenant IDs and object GUIDs are not committed.
- **Break-glass first, always excluded.** It exists before any policy is enforced and is excluded
  from every Conditional Access policy.
- **Report-only before enforce.** No policy goes straight to On; enforcement is a separate, manual step.
- **The things that belong in the portal, we do in the portal;** the repetitive / at-scale work is
  scripted (Microsoft Graph PowerShell / az CLI), idempotent, and exported back as code.
- **Every phase ends with a test matrix** (positive and negative cases) and evidence screenshots.
- **The troubleshooting log is where the real learning lives** (the walkthroughs show the clean path).

> Note: the lab tenant and the Grafana environment may be torn down between sessions, so live
> hostnames and object IDs are not guaranteed to be reachable.
