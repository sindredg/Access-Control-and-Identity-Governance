# ADR 0001: One break-glass account

**Status:** accepted for the lab, flagged for change in production.

## Context

The break-glass account is the way back in if a Conditional Access policy locks everyone out. It has
standing Global Admin, a FIDO2 key as its only method, and is excluded from every policy. Microsoft's
guidance is to keep at least two emergency-access accounts, so that a single lost key, expired
credential, or fluke of a method being unavailable cannot lock the tenant out entirely.

## Decision

We built one break-glass account rather than two, to keep the lab simple.

## Consequences

We accept that if the single FIDO2 key is lost or fails, recovery becomes very hard. There is no
second independent path back in. For a learning environment that can be torn down and rebuilt, that
is a tolerable trade. In a real tenant it would not be.

## When we would revisit

Before any production use. The change is small and worth doing early: add a second emergency-access
account, ideally secured with a different phishing-resistant method and its credential stored
separately from the first, so the two do not share a single point of failure. Both would still be
excluded from Conditional Access and kept out of PIM, and both would be covered by the break-glass
sign-in alerting planned for Phase 7.
