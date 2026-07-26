# ADR 0005: Regular MFA for PIM activation

**Status:** accepted for the lab, with a known follow-up.

## Context

Activating Grafana Admin through PIM requires MFA, a justification, and approval by Sindre G. The MFA
here is a regular method (Microsoft Authenticator), not a phishing-resistant one. The break-glass
account, by contrast, is FIDO2-only. So the everyday privileged path is protected a little more
weakly than the emergency one, which is the wrong way round if we are strict about it.

## Decision

For now, PIM activation uses regular MFA. We did not require a phishing-resistant authentication
strength on activation in this phase.

## Consequences

The most privileged everyday action in the tenant (elevating to Admin) rests on push MFA, which is
phishable, rather than a key. The mitigations that make this acceptable in the short term are that
activation is not standing, it still needs approval and a justification, and the window is short.

## When we would revisit

This is a small, worthwhile change and is already anticipated as CA002 (phishing-resistant MFA for
admins). Requiring a phishing-resistant authentication strength for privileged activation would line
the admin path up with the break-glass account and remove the inconsistency. We would treat it as the
next hardening step once the baseline settles.
