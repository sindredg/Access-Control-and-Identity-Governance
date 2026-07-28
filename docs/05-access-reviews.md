# Access reviews: recurring attestation and auto-revocation (Phase 5)

**Goal:** close the governance loop. The Grafana Viewer access we hand out in Phase 4 is not a
one-time decision. On a schedule, a reviewer confirms each person still needs it, and anyone denied
is removed automatically, through the group and SCIM, all the way to the Grafana account. This is
what turns the project from *granting* access into *governing* it: grant, use, review, revoke.

We run three reviews, one per Grafana access tier, with apply behavior deliberately matched to risk:

- **Viewers** (`grafana-viewers`), reviewed by **Amanda**: low-risk read access, so denials
  **auto-apply** and revoke straight through to Grafana. The full hands-off loop.
- **Editors** (`grafana-editors`), reviewed by **Sindre G**: editors can change dashboards, so we
  keep a human in the loop. The review attests and audits, but **auto-apply is off**, so a denial is
  a signal to action, not an automatic removal.
- **Admin eligibility** (`grafana-admins`, PIM), two stages (managers, then **Sindre G**): privileged
  and PIM-managed, so **auto-apply is off** for a second reason too, explained in section 4.

> **Best practice:** access should be re-attested periodically, not granted and forgotten. Microsoft
> recommends recurring access reviews, applying results automatically for low-risk access and keeping
> a reviewer in the loop for privileged access. Requires Microsoft Entra ID P2 (or Entra ID Governance).
> See [What are access reviews](https://learn.microsoft.com/entra/id-governance/access-reviews-overview).

Done in the portal: like PIM in Phase 3, this is deliberate governance configuration where we want to
see every setting. The reviewer experience then happens in the My Access portal.

---

## 1. Create the access review

1. **Entra admin center > ID Governance > Access reviews > New access review**.
2. **Review type**: **Teams + Groups**, **Review scope**: **Select Teams + groups**, and choose
   **`grafana-viewers`**. **Scope**: **All users**.

3. **Reviews** tab: **Reviewers** = **Selected user**, choose **Amanda Admin**. **Duration**: 3 days,
   **Recurrence**: Quarterly, **Start**: today, **End**: Never.

![Reviewer and recurrence](images/phase5/viewers-review-create.png)

4. **Settings** tab:
   - **Auto apply results to resource**: Yes (denied users are actually removed)
   - **If reviewers don't respond**: **No change** (a missed review does not lock anyone out)
   - **Reviewer decision helpers > No sign-in within 30 days**: Yes (Entra flags inactive users)
   - **Justification required**: Yes; **Email notifications** and **Reminders**: Yes
   - **Additional content for reviewer email**: "Review viewer access to the Grafana app"

![Review settings: auto-apply, no change on no response, decision helpers](images/phase5/viewers-review-create2.png)

Create the review. A one-time or first recurring instance starts within a few minutes.

---

## 2. Amanda performs the review in My Access

**1.** Amanda opens `https://myaccess.microsoft.com > Access reviews` and sees `ar-grafana-viewers`
with every current member of `grafana-viewers` and a **recommendation** next to each name. Active
users show **Approve**; the inactive test user (`nils.new`) is flagged **Deny, Inactive user** by the
no-sign-in decision helper.

![Amanda's review list with recommendations](images/phase5/review-myaccess-list.png)

**2.** Amanda **approves** the four users who are active on the project (Adam, Nils Normal, Sindre G,
Victoria) in one action, with a reason: "The users are part of the project and need viewer access to
Grafana".

![Approve continued access for the active users](images/phase5/review-approve.png)

**3.** Amanda **denies** the inactive user (`nils.new`), following the recommendation, with a reason:
"The user is no longer part of the project and access is no longer needed".

![Deny the inactive user](images/phase5/review-deny.png)

> Two Nils personas on purpose: **Nils Normal** (`nils.worker`) is the active requestor from Phase 4
> and is approved; **Nils Worker** (`nils.new`) is a deliberately inactive account used to show the
> decision helper flagging and the reviewer removing stale access.

**4.** The results show every decision, the recommendation, and the reviewer (**Amanda Admin**).
Because auto-apply is on, the denied user is removed from `grafana-viewers` when the review ends,
which SCIM deprovisions, so the account loses its Grafana Viewer role, the exact reverse of the
Phase 4 grant. The approved users keep their access.

![Review results: decisions recorded and attributed to Amanda](images/phase5/review-results.png)

**Takeaway:** access now expires by attestation, not just by time. A reviewer who says "no" actually
removes the access, the decision helper surfaces the obvious candidates (inactive users), and the
whole decision (who, when, why) is recorded.

---

## 3. The editor review: attest and audit (no auto-revoke)

We create the same kind of review over **`grafana-editors`**, reviewed by **Sindre G**, with one
deliberate difference: **Auto apply results to resource is turned off**. Cadence, decision helpers,
and justification match the viewer review.

The effect is different on purpose. Sindre's approvals and denials are recorded and audited, but
access is **not** removed automatically. A denial becomes a documented signal for us to remove that
editor deliberately. This is the right posture for a tier that can change dashboards and data
sources: we keep the attestation and the trail, but a human actions the removal.

![The three reviews: viewers, editors, admin eligibility](images/phase5/reviews-list.png)

## 4. The admin eligibility review: privileged and careful (no auto-revoke)

`grafana-admins` is the sensitive tier, and it is **managed by PIM** (Phase 3). We review its
eligibility with two deliberate safeguards.

**1. Two-stage review.** ID Governance > Access reviews > New access review > Teams + Groups >
**`grafana-admins`**. The portal confirms the group is PIM-managed and that the review covers **both
eligible and active** assignments (there is no eligible-only scope for a group). We enable
**Multi-stage review**: stage one is the users' **managers**, stage two is **Sindre G** as the
independent final reviewer, who can overwrite the managers' decisions. Recurrence monthly.

![Admin eligibility review over the PIM-managed group](images/phase5/admin-review-create.png)
![Two-stage review: managers, then Sindre G](images/phase5/admin-review-stages.png)

**2. Auto-apply OFF, on purpose.** This is the key setting, and the reason access is not revoked
automatically here. For a PIM-managed group, auto-applying a decision can convert an **eligible**
member into a **standing (permanent) admin**, which is exactly the problem we hit the first time we
tried this. So we leave **Auto apply results to resource unchecked**, review across the two stages,
then apply results manually only after confirming in **PIM > Groups > `grafana-admins` >
Assignments** that approved users are still **Eligible**, not Active.

![Auto-apply off for the privileged review](images/phase5/admin-review-settings.png)

> Why no auto-revoke here: a Teams + Groups review of a PIM group reviews eligible and active
> together, and applying "approve" persists whatever assignment type was in scope. Keeping auto-apply
> off puts a human between the decision and the change, so eligibility is never silently promoted to
> standing access.

---

## Verification / test matrix

| # | Test | Type | Result |
| --- | --- | --- | --- |
| 1 | Review runs over `grafana-viewers` | + | Lists every current member, reviewer Amanda |
| 2 | Active users approved | + | Access retained, recorded with a reason |
| 3 | Inactive user denied | + | Removed from group, SCIM deprovisions, Grafana Viewer role gone |
| 4 | Decision helper | + | Flags the inactive user (no sign-in within 30 days) as Deny |
| 5 | Reviewer does not respond | control | No change (access kept), per the chosen setting |
| 6 | Results / audit | + | Full record of reviewer, decision, and reason |
| 7 | Editor review (Sindre, auto-apply off) | + | Decisions recorded and audited; denial actioned manually, not auto-removed |
| 8 | Admin eligibility review (PIM, two-stage) | + | Managers then Sindre; auto-apply off; decisions recorded |
| 9 | PIM safety check after manual apply | control | Approved admins remain Eligible, never promoted to standing/active |

---

## Notes

- **This is the loop closing.** Phase 4 grants access; Phase 5 makes someone periodically justify
  keeping it, and removes it automatically when they cannot. Grant, use, review, revoke.
- **We review the group, not just the package.** `grafana-viewers` catches everyone with Viewer
  access however they got it, so nobody slips through by having been added outside entitlement
  management.
- **Removal reuses the grant pipeline.** A denied member is removed from the group, which SCIM
  deprovisions to Grafana. Revocation lands in the app the same way grants do, no separate teardown.
- **Decision helpers are a helper, not a gate.** The no-sign-in-in-30-days signal recommends a
  decision to speed the reviewer up; Amanda still decides.
- **No response means no change, on purpose.** The safe default: a busy reviewer missing a cycle does
  not accidentally lock people out. Entra can instead remove access on no response (stricter); we note
  it as a deliberate trade-off.
- **Feeds Phase 6.** The joiner / mover / leaver lifecycle workflows drive access off employment
  events rather than periodic review; reviews and workflows together cover the scheduled and the
  event-driven cases.

---

## Wrapping up Phase 5

Three reviews now cover the three Grafana tiers, with apply behavior matched to risk:

| Review | Group | Reviewer(s) | Auto-apply | A denial means |
| --- | --- | --- | --- | --- |
| ar-grafana-viewers | grafana-viewers | Amanda | On | Access removed automatically (SCIM revokes) |
| ar-grafana-editors | grafana-editors | Sindre G | Off | Recorded, then removed manually |
| ar-eligable-grafana-admin | grafana-admins (PIM) | Managers, then Sindre G | Off | Recorded, applied manually after a PIM check |

This closes the loop the rest of the project opened: Phase 3 grants privilege just-in-time, Phase 4
grants access self-service, and Phase 5 makes someone periodically re-justify all of it. The
escalating caution is the point: the more powerful the access, the more deliberate the review, from
hands-off auto-revocation for read, to a human in the loop for edit, to a two-stage, manual-apply
review for privileged eligibility (see the troubleshooting log for why the privileged one must not
auto-apply).

---

### Reference
- [What are access reviews](https://learn.microsoft.com/entra/id-governance/access-reviews-overview)
- [Create an access review of groups and applications](https://learn.microsoft.com/entra/id-governance/create-access-review)
- [Complete an access review in My Access](https://learn.microsoft.com/entra/id-governance/perform-access-review)
- [Review recommendations (decision helpers)](https://learn.microsoft.com/entra/id-governance/review-recommendations-access-reviews)
