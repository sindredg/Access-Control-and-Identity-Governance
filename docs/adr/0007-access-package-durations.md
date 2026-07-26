# ADR 0007: Access-package durations, 90 days for employees and 30 for contractors

**Status:** accepted for the lab.

## Context

Access-package assignments are time-bound, so access expires on its own instead of lingering. The two
packages serve different populations, so a single duration did not fit both. Employees need steady
access to do their work; contractors should be short by default so access does not outlive the
engagement.

## Decision

The employee viewer package grants access for 90 days. The contractor guest package grants access for
30 days. Both require a fresh request and approval to continue past expiry.

## Consequences

Employees re-request roughly quarterly, which is light and lines up with a normal review rhythm.
Contractors re-request monthly, which keeps external access on a short leash and forces a regular
re-check of whether it is still needed. The numbers are defaults rather than the output of a formal
risk assessment.

## When we would revisit

These should track whatever access-review cadence Phase 5 establishes, so that expiry and attestation
reinforce each other rather than drift apart. If a real data classification existed for what Grafana
exposes, the durations would follow from that instead of from sensible defaults.
