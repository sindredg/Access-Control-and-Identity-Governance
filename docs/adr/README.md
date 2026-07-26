# Decision records

Short notes on the choices in this lab that could reasonably have gone another way. The phase
walkthroughs show what we did; these explain why, and what we would revisit before running anything
like this for real.

They are deliberately brief. Each one follows the same shape: context, the decision, the
consequences we accept, and when we would revisit it. Most of these are lab trade-offs, and we have
tried to be honest about that rather than defend them as production-ready.

| ADR | Decision | Short version |
| --- | --- | --- |
| [0001](0001-single-break-glass-account.md) | One break-glass account | Simpler for a lab; Microsoft recommends two, so this is the first thing we would change |
| [0002](0002-ca010-block-on-medium-risk.md) | CA010 blocks on medium and high sign-in risk | Strict on purpose; accepts some false positives |
| [0003](0003-ca005-session-controls.md) | 8-hour sign-in frequency, no persistent browser, tenant-wide | Friction we accept in a lab; would scope it in production |
| [0004](0004-country-allow-list.md) | Country allow-list of NO, ES, GB | Matches where we operate and test; needs a travel exception in real use |
| [0005](0005-regular-mfa-for-pim-activation.md) | Regular MFA for PIM activation | Approval and justification carry it for now; phishing-resistant is the fix |
| [0006](0006-grafana-insecure-email-lookup.md) | oauth_allow_insecure_email_lookup on | Safe in a single trusted tenant; risky in federated setups |
| [0007](0007-access-package-durations.md) | 90-day employee, 30-day contractor expiry | Reasonable defaults, tied to review cadence |
