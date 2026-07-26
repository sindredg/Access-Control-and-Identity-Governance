# ADR 0003: Session controls, 8-hour sign-in frequency and no persistent browser

**Status:** accepted for the lab, would be scoped in production.

## Context

CA005 sets a sign-in frequency of 8 hours and turns off persistent browser sessions, so a stolen or
walked-away session cannot stay valid indefinitely. This is the highest-friction policy in the set:
it reaches every user on every app and makes people re-authenticate more often. Our own CA README
flags it as a candidate for scoping to admins or unmanaged devices before enforcing.

## Decision

We enforce 8-hour sign-in frequency and no persistent browser, tenant-wide. The 8 hours roughly
matches a working day, so most users re-authenticate about once per day rather than mid-task.

## Consequences

Everyone re-authenticates more often, which is real friction. In a lab with a handful of personas
that is fine and it makes the control easy to observe. At scale, applying the highest-friction control
to all users and all apps is the kind of thing that generates complaints and, worse, pushes people
toward workarounds.

## When we would revisit

Before enforcing widely in production. The note in the CA README is the right instinct: scope the
tighter session controls to admins, sensitive apps, or unmanaged devices, and leave a lighter setting
for everyday managed access. We enforced it flat here mainly to keep the lab simple and to see the
behaviour.
