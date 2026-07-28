# Risk, limitations, and trade-offs

What this lab knowingly does not do, the residual risk we accept, and what a production-grade version
could/would add. The point is to be honest about the edges rather than imply the lab is more than it is. The
reasoning behind each choice is in [decisions](decisions.md).

## Known limitations and residual risk

- **Single break-glass account.** A single point of failure for emergency access (decision 1).
  Production would use two, with different credential types and custodians.
- **No monitoring or alerting layer.** Controls are configured and point-tested, but nothing
  continuously verifies they still fire. A policy that silently stopped working would not raise an
  alert. This is the biggest gap; the production next step is sign-in and audit logs in Log Analytics
  with a workbook and alerts.
- **Manual verification, no automated tests.** Each phase ends with a test matrix run by hand. There
  is no automated validation or CI, so nothing catches a regression on its own.
- **Single app, single tenant.** Everything centres on one self-hosted Grafana app and a small cast of
  personas. The patterns generalise.
- **Reproducibility is uneven.** PIM, access reviews, and the break-glass account are portal steps,
  not code (decision 7), so the lab cannot be rebuilt from scripts alone.
- **Grafana email-based account linking.** `oauth_allow_insecure_email_lookup` is on, an accepted
  trade-off that is safe only because this is a single trusted tenant (decision 6).
- **Contractor path and separation of duties not live-exercised.** Both are deployed and explained,
  but neither was run end to end (no external-tenant credentials, and no single persona can hold both
  incompatible packages). See Phase 4.
- **No event-driven offboarding.** With Lifecycle Workflows out of scope (decision 8), a leaver's
  access is removed by the next scheduled access review, not on their last day.

## Controls mapping

A light, vendor-neutral map of what each phase contributes. Indicative for orientation, not a
compliance claim.

| Phase | Artifact | Zero Trust principle |
| --- | --- | --- |
| 0 | Break-glass account, FIDO2, least-standing-access foundations | Assume breach (recoverability) |
| 1 | MFA, block legacy auth, session controls | Verify explicitly |
| 2 | Named-location allow-list and risk-based Conditional Access | Verify explicitly, adaptive access |
| 3 | PIM just-in-time Grafana Admin | Use least-privilege access, JiT access |
| 4 | Entitlement management: requested, approved, expiring access | Use least-privilege access |
| 5 | Access reviews: recurring attestation and revocation | Least privilege, assume breach |
