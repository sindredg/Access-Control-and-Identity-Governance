# Conditional Access: locations and risk (Phase 2)

**Goal:** move from the blanket baseline to signal-driven access. This phase adds a country
allow-list and risk-based policies (Microsoft Entra ID Protection) that respond to how risky a
sign-in or user is, then proves the risk response by triggering an atypical-travel block with a VPN.

> Requires Microsoft Entra ID P2 (Identity Protection). Policies deploy the same way as the
> baseline: one JSON per policy under `scripts/conditional-access/`, report-only first, break-glass
> excluded. See [Configure risk-based Conditional Access](https://learn.microsoft.com/entra/id-protection/howto-identity-protection-configure-risk-policies).

**Why this matters.** The baseline treats every sign-in the same. This phase adds context, so a
sign-in from a country we do not operate in, or one that looks risky, is treated differently from a
normal one. That is the move from blanket rules to signal-driven access.

**Trade-off from best practice.** Both choices here lean strict. CA010 blocks on medium as well as
high sign-in risk, which catches more but will occasionally block a legitimate user; a busier tenant
might start at high-only or use a step-up instead of a hard block (see
[ADR 0002](adr/0002-ca010-block-on-medium-risk.md)). The country allow-list has no travel-exception
path yet, so normal travel outside the list is blocked; real use needs a temporary-location or
named-user exception (see [ADR 0004](adr/0004-country-allow-list.md)).

## The policies (this phase)

| Policy | Trigger | Control |
| --- | --- | --- |
| `CA004-BlockOutsideAllowedCountries` | Sign-in from outside the allowed countries | Block |
| `CA010-SignInRisk-Block` | Medium or high sign-in risk | Block |
| `CA011-UserRisk-RequirePasswordChange` | High user risk | Require MFA + secure password change |

---

## 1. Country named location as code

We keep the allowed countries in their own JSON so the list lives in one editable place instead of
being buried inside a policy. We add a `named-locations/` folder containing
`loc-allowed-countries.json`, a country named location listing the allowed countries (Norway, Spain,
UK). We then extend `Deploy-CaPolicy.ps1`: when a policy contains the
`__ALLOWED_COUNTRIES_LOCATION_ID__` token (CA004 does), the script creates or updates that named
location from the JSON, waits for it to replicate, and substitutes the location's id into the policy
before deploying. Changing the allowed countries is now a one-line edit in the JSON.

## 2. Deploy the country block (CA004)

```powershell
.\Deploy-CaPolicy.ps1 -PolicyName CA004-BlockOutsideAllowedCountries
```

CA004 blocks any sign-in whose location is not in `loc-allowed-countries` (unknown regions included),
with `breakglass-accounts` excluded, in report-only first.

## 3. Deploy the risk-based policies (CA010, CA011)

We drop two more policy JSON files into `scripts/conditional-access/policies/` and deploy them:

```powershell
.\Deploy-CaPolicy.ps1 -PolicyName CA010-SignInRisk-Block
.\Deploy-CaPolicy.ps1 -PolicyName CA011-UserRisk-RequirePasswordChange
```

![Deploy the risk-based policies](images/phase2/deploy-risk-policies.png)

CA010 **blocks** on medium/high sign-in risk rather than just requiring MFA (MFA is already enforced
tenant-wide, so requiring it again on risk would add nothing). CA011 forces MFA and a secure password
change on high user risk.

## 4. Prove it: an atypical-travel block

First we check the current policies and their state:

```powershell
Get-MgIdentityConditionalAccessPolicy -All | Select-Object DisplayName, State | Sort-Object DisplayName
```

![Current policies and their state](images/phase2/ca-statuses.png)

Add `Id` to `Select-Object` if you also want each policy's id (handy for the enforce command).


Now the test. We connect a VPN with an exit in **Spain** (location Madrid) and sign in as **Amanda
Admin**. The sign-in succeeds: CA004 allows Spain (it is in the allow-list), and CA010 / CA011 are
still in report-only, so any risk is only logged, not enforced.

![Sign-in from Madrid, Spain succeeds](images/phase2/log-spain.png)

We switch **`CA010-SignInRisk-Block` to On** (enforced), then move the VPN exit to **Norway** and try
to sign in again within a couple of minutes. This time it fails: **"You cannot access this right now."**

Norway and Spain are both allowed locations, so CA004 is not the blocker. The block comes from
**sign-in risk**: signing in from Madrid and then Oslo within minutes is physically impossible, so
Identity Protection raises an **atypical-travel** detection (the impossible-travel style signal), the
sign-in risk rises to medium/high, and the now-enforced CA010 blocks.

We check the app's **Sign-in logs** and see the story: a successful sign-in from **Madrid, Spain**,
followed minutes later by a **blocked** sign-in from **Oslo, Norway**.

![Sign-in logs: Madrid success then Oslo blocked](images/phase2/signin-logs-madrid-oslo.png)

Opening the blocked sign-in's **Conditional Access** details, `CA010-SignInRisk-Block` is triggered
and is the control denying access. `CA001-AllUsers-RequireMFA` also shows, because MFA is required on
every sign-in, but a **block** grant control always wins over a grant like MFA, so the outcome is
denied regardless of the MFA requirement.

![Blocked sign-in: CA010 sign-in-risk-block is the denier](images/phase2/blocked-ca-policies.png)

We push the test further. We move the VPN exit to **Marseille, France**. France is not in the
allow-list, so the block now has two contributing conditions: the sign-in risk (still an
atypical-travel jump) and `CA004-BlockOutsideAllowedCountries`, which fires because the location is
outside the allowed countries. Both show against the blocked sign-in.

![Marseille, France: blocked by both sign-in risk and the country policy](images/phase2/marseille-blocked.png)

We then try from **Barcelona**. Even though Barcelona is in Spain (an allowed country, so CA004 does
not object), the sign-in is still blocked: Barcelona is at least a two-hour train from Madrid, so
hopping from Madrid to Barcelona in minutes is still physically implausible and keeps the
atypical-travel sign-in risk high, so CA010 blocks. Finally we switch the VPN back to **Madrid**, the
same location as our earlier successful sign-in, and access succeeds again.

![Barcelona blocked, then Madrid succeeds](images/phase2/barcelona-then-madrid.png)

This is the useful takeaway: CA004 and CA010 are independent signals. CA004 is about *which country*
(a boundary), while CA010 is about *whether the travel is feasible* (a distance-over-time judgement).
Barcelona passes the country test but fails the travel test, so risk still blocks it.

---

## Verification / test matrix

| # | Test | Type | Expected |
| --- | --- | --- | --- |
| 1 | Sign in from an allowed country (Spain) | + / control | Allowed; risk policies report-only only log |
| 2 | Spain then Norway within minutes, CA010 enforced | + | Atypical-travel sign-in risk raised, CA010 blocks |
| 3 | Blocked sign-in's CA details | + | CA010 block wins over CA001 MFA |
| 4 | Disallowed country (Marseille, France) | + | Blocked by both `CA004` (country) and `CA010` (risk) |
| 5 | Barcelona (in Spain) shortly after Madrid | + | Still blocked by `CA010`: in an allowed country, but the travel is implausible |
| 6 | Back to Madrid (an established location) | + / control | Succeeds again, no atypical travel |

---

### Reference
- [Configure risk-based Conditional Access policies](https://learn.microsoft.com/entra/id-protection/howto-identity-protection-configure-risk-policies)
- [What is Microsoft Entra ID Protection](https://learn.microsoft.com/entra/id-protection/overview-identity-protection)
- [Location condition and named locations](https://learn.microsoft.com/entra/identity/conditional-access/concept-assignment-network)
