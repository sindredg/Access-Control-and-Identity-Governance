# Privileged Identity Management: just-in-time Grafana Admin (Phase 3)

**Goal:** remove standing Grafana Admin privileges. `grafana-admins` (the Admin role) becomes just-in-time:
**Amanda Admin and Edvard Editor** are *eligible* for it and activate it on demand with MFA, a
justification, and approval. The **approver is Sindre G** (an IAM Architect), kept separate from the
eligible users for a clean separation of duties. Amanda holds standing **Editor** access (a member
of `grafana-editors`), so her day-to-day role is Editor and she elevates to Admin only when needed.
Justification is required on every activation.

Groups to App Roles overview on the Grafana app:
![App Roles overview](images/phase3/app-roles.png)
> We can see that grafana-admin is associated with the 'Admin'-role on the app, 
> while the grafana-editor is associaated with the in-app 'Editor'-role

> **Best practice:** grant privilege just-in-time, not standing. For groups that elevate access,
> Microsoft recommends requiring approval for eligible member activations. This uses regular MFA on
> activation. Requires Microsoft Entra ID P2.
> See [PIM for Groups](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/concept-pim-for-groups).

Done in the portal: this is deliberate, one-time privileged-access configuration where we want to
see and verify every setting.

---

## 1. Bring `grafana-admins` under PIM management

1. **Entra admin center > ID Governance > Privileged Identity Management > Groups**.
2. We choose `grafana-admins`.

> Note: once a group is managed by PIM it cannot be taken back out of management (by design, so
> another admin can't quietly strip the PIM settings).

## 2. Remove standing admin, assign eligibility

**1.** Remove **Amanda Admin** from `grafana-admins` (her standing/active membership) and add her to
`grafana-editors`, so her standing role is Editor, not Admin.

![Remove Amanda from grafana-admins](images/phase3/remove-amanda-admin.png)
![Add Amanda to grafana-editors](images/phase3/add-amanda-editor.png)

**2.** Make **Amanda Admin** and **Edvard Editor** **eligible** members of `grafana-admins`, eligible
for the next 12 months.

![Assign eligibility for Amanda and Edvard](images/phase3/pim-eligible-assign.png)

**3.** Both now appear under **Eligible assignments** for the group, with no standing (active)
membership.

![Amanda and Edvard under eligible assignments](images/phase3/pim-eligible-list.png)

## 3. Configure the member activation settings

Open **Groups > grafana-admins > Settings > Member > Edit** and set:

- **Require multifactor authentication on activation**: On (Azure MFA)
- **Require justification on activation**: On
- **Require approval to activate**: On, approver **Sindre G**
- **Activation maximum duration**: 6 hours
- Leave **"Require pre-approval custom extension (Preview)"** unchecked (that calls a custom Logic
  App we have not built; it is not the same as "Require approval to activate")
- **Notifications**: On

![Member activation settings: MFA, justification, approval by Sindre G, duration](images/phase3/pim-member-settings.png)

---

## 4. Test: activate, approve, and revoke early

**1.** As **Amanda**, we sign in to **Entra admin center > PIM > My roles > Groups**. Amanda sees an
eligible assignment for direct membership of `grafana-admins`.

![Amanda's eligible assignment](images/phase3/pim-my-roles.png)

**2.** Amanda selects **Activate**, requests a **0.5-hour** activation, and enters a reason:
"Managing users and teams in Grafana".

![Amanda activates for 0.5 hours with a justification](images/phase3/pim-activate.png)

**3.** **Sindre G** approves the request (adding an approval reason).

![Sindre G approves the activation](images/phase3/pim-approve.png)

**4.** Amanda is now an active member of `grafana-admins` (Active assignments shows **Activated**),
and after a fresh Grafana sign-in she has the **Admin** role.

![Amanda's active (activated) assignment](images/phase3/pim-active.png)

**5.** Amanda finishes the task well before the 0.5-hour window and tells us, so we **revoke her access
early**: Sindre G removes her membership from `grafana-admins` in PIM.


**6.** We review the audit log (**grafana-admins > My audit**), which tells the full story: Amanda's
activation (Add member to role completed, PIM activation), followed by Sindre G's early removal
(Remove member from role requested and completed).

![PIM audit log: activation then early removal](images/phase3/pim-audit.png)

**Takeaway:** just-in-time means access exists only for as long as it is needed. Amanda held Admin
for minutes, not permanently, and the moment the work was done it was revoked. Every step (who,
when, why, and who approved) is captured in the PIM audit log.

---

## Verification / test matrix

| # | Test | Type | Expected |
| --- | --- | --- | --- |
| 1 | Amanda before activation | + / control | Standing Editor only, no Admin |
| 2 | Activation requires MFA + justification + Sindre G's approval | + | Cannot activate without all three |
| 3 | After approval + fresh Grafana sign-in | + | Amanda has the Admin role |
| 4 | Early removal (or expiry) | + | Membership and Admin role removed |
| 5 | Audit log | + | Captures activation and the early removal, with reasons and approver |
| 6 | Break-glass account | + / control | Keeps standing access, never placed under PIM |

---

## Notes

- **Separation of duties.** The approver (Sindre G) is an IAM Architect with no relation to the Grafana app,
  except for managing access. He is therefore not one of the eligible users, so no one
  approves their own elevation. This is the recommended pattern.
- `grafana-admins` drives the Admin role through the enterprise app's group-to-app-role mapping (and
  SCIM), so activation and deactivation propagate to Grafana. Because OIDC app-role claims are issued
  at sign-in, the activating user needs a **fresh Grafana sign-in** for the Admin role to appear.
- The approval workflow applies cleanly here because `grafana-admins` governs *app* access, not an
  Entra directory role. For groups that elevate into Entra roles, approval behavior is governed at
  the Entra-role level instead, a separate consideration we do not hit here.
- Regular MFA is sufficient on activation; no phishing-resistant method is required.

---

### Reference
- [PIM for Groups](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/concept-pim-for-groups)
- [Bring groups under PIM management](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/groups-discover-groups)
- [Assign eligibility for a group in PIM](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/groups-assign-member-owner)
- [Configure PIM for Groups settings](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/groups-role-settings)
