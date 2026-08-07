# Risk, limitations and trade-offs

What this lab does not do, and the residual risk we accept. Reasoning for each choice is in
[decisions](decisions.md).

- **Single break-glass account** (decision 1). A single point of failure for emergency access.
  Production would use two, with different credential types and custodians.
- **No monitoring or alerting.** Controls are configured and point-tested, but nothing continuously
  verifies they still fire, and a policy that silently stopped working would not raise an alert.
  This is the biggest gap. Next step is sign-in and audit logs in Log Analytics with a workbook and
  alerts.
- **Manual verification, no automated tests.** Each phase ends with a hand-run test matrix. No CI,
  so nothing catches a regression on its own.
- **Single app, single tenant.** One self-hosted Grafana app and a small cast of personas.
- **Reproducibility is uneven** (decision 7). PIM, access reviews and the break-glass account are
  portal steps, so the lab cannot be rebuilt from scripts alone.
- **Grafana email-based account linking** (decision 6). `oauth_allow_insecure_email_lookup` is on,
  safe only because this is a single trusted tenant.
- **Contractor path and separation of duties not live-exercised.** Both deployed, neither run end to
  end: no external-tenant credentials, and no single persona can hold both incompatible packages.
- **No event-driven offboarding** (decision 8). Lifecycle Workflows needs an Entra ID Governance
  licence this tenant does not have, so a leaver's access goes at the next scheduled review rather
  than on their last day.

## Controls mapping

Indicative orientation, not a compliance claim.

| Phase | Artifact | Zero Trust principle |
| --- | --- | --- |
| 0 | Break-glass account, FIDO2, least-standing-access foundations | Assume breach (recoverability) |
| 1 | MFA, block legacy auth, session controls | Verify explicitly |
| 2 | Named-location allow-list and risk-based Conditional Access | Verify explicitly, adaptive access |
| 3 | PIM just-in-time Grafana Admin | Use least-privilege access, JiT access |
| 4 | Entitlement management: requested, approved, expiring access | Use least-privilege access |
| 5 | Access reviews: recurring attestation and revocation | Least privilege, assume breach |
