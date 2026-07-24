# Conditional Access baseline (tenant-wide)

**Goal:** deploy the baseline Conditional Access policies in report-only, verify them in the
portal, and validate their effect with the What-If tool before anything is enforced. The
break-glass account is excluded from every policy.

> Each policy lives as its own JSON file under `scripts/conditional-access/policies/` and is
> deployed one at a time (or all at once) with `Deploy-CaPolicy.ps1`. See
> [Plan a Conditional Access deployment](https://learn.microsoft.com/entra/identity/conditional-access/plan-conditional-access).

## The policies

| Policy | Who | Control |
| --- | --- | --- |
| `CA001-AllUsers-RequireMFA` | All users | Require MFA |
| `CA003-BlockLegacyAuth` | All users | Block legacy authentication |
| `CA005-AllUsers-SessionControls` | All users | Sign-in frequency + no persistent browser |
| `CA006-Guests-RequireMFA` | Guests / external users | Require MFA |
| `CA007-AzureManagement-RequireMFA` | All users | Require MFA for the Azure management plane |
| `CA008-SecurityInfoRegistration-MFA` | All users | Require MFA to register security info |

All are created in report-only, and the security group `breakglass-accounts` is excluded from each.

---

## Phase 1: Deploy the baseline policies

**1.**We deploy the baseline Conditional Access policies. First, list what is available:

```powershell
.\Deploy-CaPolicy.ps1 -List
```

![Available policy files](images/phase1/deploy-list.png)

Then deploy them all (report-only, break-glass excluded, idempotent):

```powershell
.\Deploy-CaPolicy.ps1 -All
```

![Deploy all policies](images/phase1/deploy-all.png)

**2.** Double-check in the portal. Open **Entra ID > Conditional Access > Policies** and confirm the policies and their report-only state.

![Policies listed in the portal](images/phase1/portal-policy-list.png)

Open a policy and review its configuration on the **Edit policy** view (assignments, conditions, grant / session controls, and the break-glass exclusion).

![Edit policy configuration](images/phase1/edit-policy-config.png)

---

## Phase 2: Validate with the What-If tool

**1.** In **Entra ID > Conditional Access**, we open the **What-If** tool to see which policies would apply for a given scenario. We simulate **Adam Analyst** accessing the in-house Grafana app from a **Windows** device using **modern authentication**.

![What-If input: Adam Analyst, Windows, modern auth](images/phase1/whatif-adam-windows.png)

We get back the policies that would apply: **require MFA** (CA001) and the **session controls** (CA005).

![What-If result: MFA and session controls apply](images/phase1/whatif-result-mfa-session.png)

**2.** We then simulate **Adam Analyst** signing in from a **Linux** device, with the client on an **unsupported platform** (legacy authentication).

![What-If input: Linux device, legacy client](images/phase1/whatif-adam-linux-legacy.png)

The MFA policy still evaluates as required, but access would be **blocked** by the legacy authentication block policy (CA003).

![What-If result: blocked by legacy auth policy](images/phase1/whatif-result-blocked-legacy.png)

---

## Enforce (separate, deliberate step)

Deployment only ever creates report-only policies. After the What-If checks and the report-only
impact look right, we enforce one policy at a time:

```powershell
$p = Get-MgIdentityConditionalAccessPolicy -All | Where-Object DisplayName -eq "CA001-AllUsers-RequireMFA"
Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $p.Id -State "enabled"
```

We can now se in the portal that all policyes show as 'State: On', rather than 'report-only'.
![Conditional Access policies enforced](images/phase1/ca-enforced.png)


---

### Reference
- [Conditional Access What-If tool](https://learn.microsoft.com/entra/identity/conditional-access/what-if-tool)
- [Plan a Conditional Access deployment](https://learn.microsoft.com/entra/identity/conditional-access/plan-conditional-access)
- [Conditional Access report-only mode](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-report-only)
