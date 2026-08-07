# Entitlement management: self-service access packages (Phase 4)

**Built:** two access packages deployed with Graph, so Grafana access is requested in My Access,
approved, time-bound and provisioned through SCIM instead of being a manual group-add. Ran the
internal flow end to end with a real user.

> [What is entitlement management](https://learn.microsoft.com/entra/id-governance/entitlement-management-overview).

| Object | What it does |
| --- | --- |
| Catalog `cat-grafana` | Holds the Grafana groups as requestable resources |
| `ap-grafana-viewer-employees` | Grants `grafana-viewers` to internal users, manager approval, 90-day expiry |
| `ap-grafana-contractor-guests` | Grants `grafana-viewers` to external / B2B users, approver Sindre G, 30-day expiry |
| Separation of duties | The two packages marked incompatible |

Group membership flows straight to Grafana: the group maps to an app role and SCIM provisions it,
so an approved request ends in a real Grafana account and an expired one is deprovisioned.

---

## 1. Deploy as code

Entitlement management has a chained, partly asynchronous object graph, so the deployment is four
small ordered idempotent scripts. Each resolves everything by name (catalog, group, packages,
approver), so there are no IDs to pass between them.

```powershell
# scripts/entitlement-management  (reset any earlier attempt first, see the folder README)
.\01-catalog-resource.ps1                    # catalog cat-grafana + grafana-viewers resource
.\02-access-packages.ps1                     # the two packages + Member role scope
.\03-assignment-policies.ps1 -ApproverUpn "Sindre@<tenant>.onmicrosoft.com"
.\04-separation-of-duties.ps1                # mark the two packages incompatible
```

![Access packages deployed by the scripts](images/phase4/deploy-scripts.png)

**ID Governance > Entitlement management > Access packages** confirms both packages with the
`grafana-viewers` Member resource role, the request policies, and the incompatibility.

![Access packages in the portal](images/phase4/portal-packages.png)

---

## 2. Test the employee flow end to end

Run with **Nils Normal** (`nils.worker@<tenant>.onmicrosoft.com`), who has no standing Grafana
access.

**1.** Nils opens `https://myaccess.microsoft.com` and sees `ap-grafana-viewer-employees` as the one
package available to him.

![Nils sees the viewer package in My Access](images/phase4/nils-request.png)

**2.** He requests for himself with a justification.

![Nils enters a justification and submits](images/phase4/nils-justification.png)

**3.** His manager **Amanda Admin** gets the approval in My Access and approves with a reason. It
routed to her automatically from the manager relationship seeded in Phase 0; no approver is named
on this policy.

![Amanda approves Nils's request](images/phase4/amanda-approve.png)

**4.** Entra grants the assignment and SCIM provisions Nils into Grafana (**Create, Success**).

![SCIM provisions Nils into Grafana](images/phase4/scim-provisioning.png)

**5.** Nils signs in to Grafana as **Viewer**. This first failed with "User sync failed", a
Grafana-side reconciliation problem between the SCIM-created account and the OIDC login. The
one-line config fix is in the [troubleshooting log](99-troubleshooting.md).

![Nils signed in to Grafana as Viewer](images/phase4/nils-grafana-viewer.png)

![Nils signed in to Grafana sign in logs](images/phase4/nils-grafana-log.png)

---

## 3. Separation of duties (deployed, not exercised)

`04-separation-of-duties.ps1` marks the two packages incompatible, visible under each package's
**Separation of Duties** tab. Holding one then blocks requesting the other.

Not exercised live: one package targets internal users and the other external guests, so no persona
can hold both and trigger the block. The guardrail is deployed and verifiable in the portal.

## 4. The contractor path (design, not live-tested)

`ap-grafana-contractor-guests` is deployed but was not run end to end, because the test contractor
lives in a separate tenant we do not hold credentials for.

- **The request creates the guest.** The policy's requestor scope is All external users
  (`AllExternalSubjects` in `03-assignment-policies.ps1`), so the contractor does not need to exist
  in the tenant first. They get a tenant-scoped My Access link
  (`https://myaccess.microsoft.com/@<tenant>.onmicrosoft.com`), sign in with their own email, and
  request. Sindre G's approval triggers the B2B guest invitation, so invite, guest object and access
  grant are one governed flow rather than a manual invite-then-add.
- **Auto-expiry.** 30 days, after which group membership is removed, SCIM deprovisions the account,
  and the guest keeps no standing access.
- **Separate approver.** External access routes to Sindre G rather than a manager, because a
  contractor has no manager relationship in the directory.

---

## Verification / test matrix

| # | Test | Type | Result |
| --- | --- | --- | --- |
| 1 | Nils requests the viewer package | + | Provisioned only after approval (verified) |
| 2 | Approval routing | + | Routed automatically to the manager (Amanda), no named approver |
| 3 | Nils after approval + Grafana sign-in | + | Gets the Grafana Viewer role (after the user-sync fix) |
| 4 | Contractor package (external / B2B) | design only | Deployed, not run live, no credentials for the external tenant |
| 5 | Separation of duties | configured | Packages marked incompatible, visible in the portal, not live-exercised |
| 6 | Every grant | + | Has a requestor, approver, justification and expiry in the request history |

Evidence in `images/phase4/`: the deploy scripts, packages and resource roles in the portal, Nils's
request and justification, Amanda's approval, the SCIM provisioning log, the "User sync failed"
error, and the successful Viewer sign-in.

---

## Notes

- Every grant now answers who requested it, who approved it, why, and when it expires.
- Two approval patterns on purpose: internal to the requestor's manager, external to a designated
  approver.
- Provisioning reuses the existing pipeline, so no new integration was needed.
- Phase 5 adds an access review on top of these packages.

---

### Reference
- [What is entitlement management](https://learn.microsoft.com/entra/id-governance/entitlement-management-overview)
- [Manage access packages with the entitlement management APIs](https://learn.microsoft.com/graph/tutorial-access-package-api)
- [Separation of duties (incompatible access packages)](https://learn.microsoft.com/entra/id-governance/entitlement-management-access-package-incompatible)
- [My Access portal](https://learn.microsoft.com/entra/id-governance/my-access-portal-overview)
