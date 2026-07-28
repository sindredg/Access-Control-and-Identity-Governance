# Decision records

Short records of the debatable choices in this lab: the context, what we decided, the consequences we
accepted, and when we would revisit. The aim is that a reader never has to guess why something is the
way it is.

## 1. One break-glass account, not two
**Context.** Microsoft recommends at least two emergency-access accounts so a single expired or lost
credential cannot strand you.
**Decision.** We use one, for lab simplicity.
**Consequences.** A single point of failure, accepted because this is a lab and not production.
**Revisit.** Any shared or production tenant.

## 2. The country policy blocks, and the allow-list is three named countries
**Context.** We could MFA-challenge foreign sign-ins instead of blocking, and we could allow a broad
region such as the whole EU.
**Decision.** `CA004` hard-blocks outside Norway, Spain, and the UK, the countries this (simulated) workforce operates in. A challenge would add nothing because MFA is already enforced on every sign-in.
**Consequences.** Legitimate travel outside those three countries is blocked. Fine for a small, known workforce; a larger org would pair this with trusted locations and potentially a travel process.
**Revisit.** When the workforce geography changes.

## 3. Sign-in risk blocks (CA010)
**Context.** The default risk-policy pattern is "require MFA on risk".
**Decision.** Because MFA is already required on every sign-in, we block on medium or high sign-in
risk instead. Requiring MFA again on risk would be a no-op.
**Consequences.** Stricter: a risky but legitimate sign-in is completely blocked.
**Revisit.** If session controls and MFA stops being enforced tenant-wide.

## 4. Regular MFA on PIM activation, no phishing-resistant step-up
**Context.** We prototyped a phishing-resistant authentication context to gate PIM and app access.
**Decision.** We reverted it. Regular Azure MFA on activation, plus approval and justification, is
enough for this scenario as we have already showcased FIDO2 on the breakglass account.
**Consequences.** Activation is not phishing-resistant. Accepted because just-in-time access, approval,
and audit already constrain the elevation. True privileged access in production should require a
phishing-resistant method.
**Revisit.** For higher-sensitivity roles or a production tenant.

## 5. Access-review auto-apply is scaled to risk
**Context.** Auto-applying review results is convenient, but on a PIM-managed group approving a member
can convert eligible access into standing access (we hit this, see the troubleshooting log).
**Decision.** Auto-apply is on for the low-risk viewer review and off (manual apply, then a PIM check)
for the editor and admin-eligibility reviews.
**Consequences.** Privileged reviews need a human apply step, a deliberate trade of convenience for
safety.
**Revisit.** Not applicable.

## 6. Grafana links OIDC logins to SCIM accounts by email
**Context.** SCIM pre-provisions the Grafana user. Since the CVE-2023-3128 hardening, an OIDC login
will not link to an existing user by email by default, which broke sign-in ("User sync failed").
**Decision.** We set `oauth_allow_insecure_email_lookup = true` so the OIDC login links to the
SCIM-created account by email.
**Consequences.** We accept email-based account linking. Safe here because it is a single tenant we
control with verified emails; it would be risky with an untrusted or federated IdP. The cleaner fix is
to reconcile on the immutable object id (`oid` / `sub`) instead.
**Revisit.** Any federated or multi-tenant setup.

## 7. Portal for deliberate config, code for the repetitive work
**Context.** Everything could be scripted, or everything clicked.
**Decision.** Conditional Access and entitlement management are code (MS Graph / JSON); PIM, Access Reviews
access reviews, and the break-glass account are portal walkthroughs.
**Consequences.** Reproducibility is uneven, the whole lab cannot be stood up from code alone.
Accepted because the portal work is one-time and easier to verify by eye. A production version would 
likely script the PIM and review definitions via Graph.
**Revisit.** If the lab needs repeatable, one-command setup.

## 8. Lifecycle Workflows (joiner / mover / leaver) left out of scope
**Context.** Automated joiner-mover-leaver was planned, but Lifecycle Workflows requires an Entra ID
Governance license, which this tenant does not have (P2 only).
**Decision.** Cut it rather than gate the project on a license.
**Consequences.** No event-driven offboarding. Residual access on exit is caught by the Phase 5
access reviews instead, which are scheduled, not last-day. Production should add Lifecycle Workflows
for immediate revocation.
**Revisit.** With an Entra ID Governance license.
