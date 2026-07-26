# ADR 0006: Enable oauth_allow_insecure_email_lookup on Grafana

**Status:** accepted for the lab, tied to a specific precondition.

## Context

Two paths manage the same person in Grafana: SCIM pre-creates the account, and OIDC login then tries
to reconcile against it. Since the CVE-2023-3128 hardening, Grafana does not link an OIDC login to an
existing user by email by default, so the login failed with "User sync failed". The full symptom,
cause, and fix are in the [troubleshooting log](../99-troubleshooting.md).

## Decision

We set `GF_AUTH_OAUTH_ALLOW_INSECURE_EMAIL_LOOKUP: "true"` so OIDC login links to the SCIM-created
account by email.

## Consequences

This re-enables email-based account linking, which is exactly what the CVE warned about. The reason
it is acceptable here is that the precondition for the attack does not hold: the IdP is our own single
Entra tenant, the email and UPN come from accounts we provision, users cannot freely rewrite a
verified UPN to impersonate someone, and every sign-in has already passed Conditional Access and MFA.
We already trust Entra's email claim elsewhere, so this adds no new trust assumption. It is still a
standing weakening of a secure default, which is why it is recorded here and in the risk register
rather than only in a fix note.

## When we would revisit

In any multi-tenant or federated setup, or any tenant that allows unverified self-service email edits,
this flag should stay off. The cleaner long-term fix, even here, is to reconcile on the immutable
object ID (oid or sub) rather than email, so the SCIM bridge and the OIDC login match on a stable
identifier and the flag is not needed at all.
