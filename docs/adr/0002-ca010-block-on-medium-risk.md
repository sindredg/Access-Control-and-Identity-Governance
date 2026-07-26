# ADR 0002: CA010 blocks on medium and high sign-in risk

**Status:** accepted for the lab.

## Context

Identity Protection scores each sign-in as low, medium, or high risk. We can respond by blocking, by
requiring a step-up (MFA), or by only logging. MFA is already enforced tenant-wide by CA001, so
requiring MFA again on risk would add little. That pushed us toward a block. The open question was the
threshold: high only, or medium and high.

## Decision

CA010 blocks on both medium and high sign-in risk, for all users and all apps.

## Consequences

This is deliberately strict. Medium risk carries a real false-positive rate, so this policy will
occasionally block a legitimate user and produce a support call. We accept that cost in exchange for a
tighter posture, which suits a lab where we want to see the control fire (the Phase 2 atypical-travel
test relies on exactly this).

## When we would revisit

In a larger or busier tenant we would reconsider blocking on medium. Options include starting at
high-only, routing medium to a step-up or password change rather than a hard block, or scoping the
medium block to more sensitive apps. The right setting depends on how much helpdesk load the
false positives create against the value of the tighter block.
