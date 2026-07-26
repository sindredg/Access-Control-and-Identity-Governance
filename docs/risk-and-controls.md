# Risk and controls

This is a cross-cutting note that sits alongside the phase walkthroughs. The walkthroughs cover
*what* we built and show that it works. This page tries to answer the questions a reviewer usually
asks next: why these controls, what they map to, and what we knowingly left open.

It is written for a lab, so the honest framing matters. Several choices here are fine for a
single-tenant learning environment and would need to change before anything like this ran in
production. We have tried to say clearly where that line is rather than present the lab as if it
were a hardened deployment.

## What we were trying to reduce

The underlying risk is unwanted access to a self-hosted Grafana app that is exposed to the internet:
an attacker signing in as a real user, a legitimate user keeping more privilege than they need, or a
contractor holding access long after the work is done. The controls in this repo each chip away at
one of those.

| Risk we care about | The control we leaned on | Where it lives |
| --- | --- | --- |
| Stolen or phished credentials used to sign in | MFA for everyone, plus block on risky sign-ins | CA001, CA010, Phase 1 and 2 |
| Legacy protocols that bypass MFA | Block legacy authentication | CA003, Phase 1 |
| Sign-in from somewhere we do not operate | Country allow-list | CA004, Phase 2 |
| A compromised session staying valid too long | Sign-in frequency and no persistent browser | CA005, Phase 1 |
| Standing admin rights sitting around unused | Just-in-time admin through PIM | Phase 3 |
| Access granted with no record or expiry | Access packages with approval and time limits | Phase 4 |
| A contractor keeping access forever | Auto-expiring guest access | Phase 4 |
| A misconfigured policy locking everyone out | Break-glass account excluded from all policies | Phase 0 |

## Accepted residual risk

These are the gaps we are aware of. Listing them is the point: an unstated gap looks like an
oversight, a stated one looks like a decision. Most of these are reasonable for a lab and would be
revisited for production. The related decisions are written up in more detail under `adr/`.

**One break-glass account, not two.** Microsoft recommends at least two emergency-access accounts so
a single lost key or failed credential cannot lock us out. We built one, secured with a single FIDO2
key and stripped of every other method. If that key is lost, recovery gets very hard. For a lab this
is an accepted trade for simplicity, but it is the single most important thing we would change first
in production (add a second account, ideally with a different method, stored separately). See
`adr/0001-single-break-glass-account.md`.

**No device condition anywhere.** None of the Conditional Access policies check device compliance,
Intune enrolment, or hybrid join. That leaves out a whole Zero Trust pillar (devices). It is a
deliberate scoping choice because the lab has no MDM in place, not a claim that device state does not
matter. In production this is where we would go next after the identity controls settle.

**The most privileged path uses ordinary MFA.** PIM activation for Grafana Admin is protected by
regular MFA (Authenticator), not a phishing-resistant method. The break-glass account is FIDO2-only,
but the just-in-time admin path is not, which is a bit inconsistent. The mitigation is that
activation still needs approval and a justification, and the window is short. Tightening this to a
phishing-resistant authentication strength (the planned CA002) is a small change and would close the
gap. See `adr/0005-regular-mfa-for-pim-activation.md`.

**Break-glass is not monitored yet.** Standing Global Admin, excluded from every policy, never under
PIM: all correct, but it only stays safe if its use is alerted on. That alerting is Phase 7
(monitoring), which is not built. So today the highest-privilege account in the tenant could be used
without anything firing. This is a known gap we are carrying until Phase 7, not a design we are happy
with long term.

**oauth_allow_insecure_email_lookup is on.** To let SCIM pre-provisioning and OIDC login reconcile
to one Grafana account, we set this flag on the app. The reasoning and threat model are written up in
the [troubleshooting log](99-troubleshooting.md), and it is acceptable here because the IdP is our
own single tenant with verified emails. It is still a standing weakening of a secure default, so it
belongs on this list rather than only in a fix note. See `adr/0006-grafana-insecure-email-lookup.md`.

**CA010 blocks on medium risk, which has a cost.** Blocking on medium and high sign-in risk is
deliberately strict. Medium has a real false-positive rate, so this will occasionally block a
legitimate user and generate a support call. We chose availability-for-security here on purpose, but
it is a trade worth naming, and in a larger tenant we might start at high-only or route medium to a
step-up rather than a hard block. See `adr/0002-ca010-block-on-medium-risk.md`.

**The separation-of-duties control cannot currently fire.** The two access packages are marked
incompatible, but their requestor scopes already make them mutually exclusive (one internal, one
external), so no single person could ever hold both. The marking is deployed and visible, but in its
current form it does not add a real guardrail. A meaningful separation-of-duties pairing would be
something like an admin package versus an audit or review package, where one person genuinely should
not hold both. We call this out in Phase 4 and would rework it when an access-review package exists
in Phase 5.

## Control mapping

A rough mapping of what we built to two frameworks. Zero Trust is the natural lens because this is an
Entra-native project and it speaks Microsoft's own model. CIS Controls v8 gives a vendor-neutral
cross-check, mostly in Control 5 (account management) and Control 6 (access control management). This
is indicative, to show the controls line up with recognised practice, not a formal audit or a
compliance claim.

| What we built | Zero Trust | CIS v8 (indicative) |
| --- | --- | --- |
| Break-glass, FIDO2, dedicated admin account | Identities, verify explicitly | 5.4, 6.5 |
| CA001 MFA for all users | Identities, verify explicitly | 6.3, 6.5 |
| CA003 block legacy authentication | Identities | 4.8, 6.3 |
| CA004 country allow-list | Identities and networks, use context | 4.4, 13.x (network locale) |
| CA005 session controls | Identities, assume breach | 6.x session |
| CA006 MFA for guests | Identities | 6.3 |
| CA007 MFA for Azure management | Identities, protect the control plane | 6.5 |
| CA008 MFA to register security info | Identities | 5.2, 6.5 |
| CA010 block on sign-in risk | Identities, assume breach, real-time signal | 6.x, 8.11 (log and respond) |
| CA011 password change on user risk | Identities | 5.2 |
| PIM just-in-time admin | Identities, least privilege | 5.4, 6.8 |
| Entitlement management access packages | Least privilege, access lifecycle | 6.1, 6.2, 6.8 |
| SCIM provisioning and deprovisioning | Automate access lifecycle | 5.1, 5.3, 6.2 |
| Separation of duties (packages) | Least privilege | 6.8 |

For a Norwegian context it is worth noting that identity and access controls of this kind also
support the access-control and logging expectations under NIS2, which applies to a widening set of
sectors. We are not making a compliance claim, only pointing at where this work would be relevant.

## What good would look like

If we were measuring this rather than just building it, these are the numbers we would track. They
also set up Phase 7 (monitoring), which otherwise risks being "collect logs" with no target to hold
them against.

- Standing Grafana Admins outside break-glass: target zero (PIM makes this achievable).
- Share of privileged activations on a phishing-resistant method: target 100 percent (needs CA002).
- Share of access grants that carry an expiry: target 100 percent (access packages already do this).
- Time from "no longer needed" to access removed: as short as possible, ideally automatic on expiry.
- Break-glass sign-ins: every one alerted and reviewed (Phase 7).
- Legacy-authentication attempts: trending to zero once CA003 is enforced.

## How we would roll back

Break-glass is the safety net if enforcement goes wrong, but the faster everyday fix is to move a
policy back to report-only. Since every policy is authored in report-only and enforced as a separate
manual step, reverting one is a single command:

```powershell
$p = Get-MgIdentityConditionalAccessPolicy -All | Where-Object DisplayName -eq "<Policy-Name>"
Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $p.Id -State "enabledForReportingButNotEnforced"
```

If sign-in is broken tenant-wide, the break-glass account (excluded from every policy) is the way
back in. A production version of this repo would spell out who is authorised to use it, where the key
is kept, and how we would know we need it, which is part of what Phase 7 is for.
