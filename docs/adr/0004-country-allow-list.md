# ADR 0004: Country allow-list of Norway, Spain, and the UK

**Status:** accepted for the lab.

## Context

CA004 blocks sign-ins from outside a named list of countries. A location allow-list is a blunt
control, but it cheaply removes a large amount of untargeted sign-in noise from places we never
operate in. The list has to reflect where the organisation and its people actually are.

## Decision

The allowed countries are Norway, Spain, and the UK, kept in
`scripts/conditional-access/named-locations/loc-allowed-countries.json` so the list lives in one
editable place. Unknown regions are treated as not allowed. These three match where we work and where
we run the Phase 2 travel tests from.

## Consequences

Legitimate sign-ins from anywhere else are blocked, including normal travel. With no exception path, a
user at a conference in Germany would be locked out until the list is changed or an exception is made.
For a lab that is acceptable and even useful, since it makes the block easy to demonstrate.

## When we would revisit

In real use this needs a companion process: a way to add a temporary location for travel, or a
trusted-location and named-user exception, so the control does not turn into a self-inflicted
outage. The country list itself should be reviewed whenever the organisation's footprint changes.
