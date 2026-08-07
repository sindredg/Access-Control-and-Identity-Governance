# Troubleshooting log

Things that did not go as expected: symptom, cause, fix, lesson. The phase walkthroughs show the
clean path; this is the rest of it.

---

## Phase 0: FIDO2 passkey registered, but sign-in only prompted for normal MFA

**Symptom.** After registering a FIDO2 passkey on the break-glass account, the first sign-in used
the key. After signing out and back in, the account was only prompted for Microsoft Authenticator.

**Cause.** Registering a passkey makes the method available, it does not make Entra require it. The
account still had Authenticator and phone registered, pulled in partly by the SSPR proof-up prompt.
With multiple methods present, Entra offered the default one.

**Fix.**
1. Removed all non-FIDO2 methods (Authenticator, phone/SMS, email), leaving the key alone.
2. Stopped SSPR re-adding a proof-up: scope SSPR away from the account, or disable admin SSPR via
   `Update-MgPolicyAuthorizationPolicy`.
3. Re-tested. Sign-in goes straight to the key.

**Lesson.** Registration is not enforcement. For break-glass, making FIDO2 the only method forces
phishing-resistant sign-in with no CA policy involved. For normal users, do it the other way: a CA
phishing-resistant authentication strength, not method-stripping.

**How to prove it.**
- Portal: Users, the account, Authentication methods, "Passkey (FIDO2)" listed.
- Graph:
  ```powershell
  Connect-MgGraph -Scopes "UserAuthenticationMethod.Read.All"
  Get-MgUserAuthenticationFido2Method -UserId "<breakglass-upn>" |
      Select-Object DisplayName, Model, CreatedDateTime
  ```

---

## Phase 1: PowerShell won't run the script ("not digitally signed")

**Symptom.** `.\Deploy-CaPolicy.ps1 -List` fails with `File ... cannot be loaded. The file ... is
not digitally signed. You cannot run this script on the current system.`

**Cause.** The execution policy (RemoteSigned or AllSigned) blocks unsigned scripts carrying the
mark of the web, and files synced through OneDrive or downloaded from GitHub get that mark.

**Fix.** Current session only:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```
Or as a standing dev-machine setup:
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
Get-ChildItem -Path . -Recurse -Filter *.ps1 | Unblock-File
```

**Lesson.** Environment issue, not a code issue. Prefer `-Scope Process Bypass` while iterating so
the machine default stays strict.

---

## Phase 1: password reset locks a user out of MFA registration (CA008 deadlock)

**Symptom.** After resetting Adam's password, both sign-in and `https://aka.ms/mysecurityinfo`
returned: "Your sign-in was blocked. We are currently unable to collect additional security
information. Your organisation requires this information to be set from specific locations or
devices."

**Cause.** `CA008-SecurityInfoRegistration-MFA` requires MFA to register security info. The password
reset left no usable method, so the user cannot do MFA and cannot register one.

**Fix.** Bootstrap with a Temporary Access Pass, which counts as MFA, then let the user register a
real method. Three sub-issues on the way:
1. The TAP method was off by default. Enable it first:
   `PATCH /policies/authenticationMethodsPolicy/authenticationMethodConfigurations/TemporaryAccessPass`
   with `state = enabled` and an `includeTargets` group (`all_users`).
2. `New-MgUserAuthenticationTemporaryAccessPassMethod` returned 404 "user could not be found"
   because the UPN still had the literal `<tenant>` placeholder. Resolve with `Get-MgUser` and pass
   the object Id.
3. The pass code is only returned at creation and is not in the default table output. Capture it
   with `$result.TemporaryAccessPass`. An existing TAP blocks creating another, so delete the old
   one first.

TAP is time-limited (60 min here) and ours expired mid-test and had to be reissued.

Quicker unblock: set CA008 to `enabledForReportingButNotEnforced`, let the user register, set it
back to `enabled`.

**Lesson.** Any policy gating MFA *registration* deadlocks users who have no MFA yet, which means
new hires and any password reset that clears methods. Pair it with TAP onboarding or a
trusted-location exception.

---

## Phase 4: Grafana "Login failed: User sync failed" after access package + SCIM

**Symptom.** Nils's access was requested and approved, Entra provisioning logs show the SCIM sync
succeeded, and the sign-in logs show a successful sign-in. Grafana itself returns
**"Login failed: User sync failed."**

![Grafana: Login failed, User sync failed](images/phase4/grafana-sync-failed.png)

**Cause.** Two provisioning paths manage the same person. SCIM pre-created the Grafana user, and the
OIDC login then tries to reconcile against it. Since the CVE-2023-3128 hardening, Grafana does not
link an OAuth/OIDC login to an existing user by email by default
(`oauth_allow_insecure_email_lookup` defaults to `false`), so the login cannot match the
SCIM-created account. Entra did its job; the failure is Grafana reconciling two identities for one
user.

**Fix.**
1. Confirm the reason in the Grafana server logs (`sudo docker compose logs -f grafana`), looking
   for a user lookup or duplicate email line around the failed login.
2. Allow OAuth to link to the existing SCIM user by email. Our compose file uses the `KEY: "value"`
   mapping style, so in the grafana service `environment:` block:
   ```yaml
   GF_AUTH_OAUTH_ALLOW_INSECURE_EMAIL_LOOKUP: "true"
   ```
   (Or in `grafana.ini` under `[auth]`: `oauth_allow_insecure_email_lookup = true`.)
3. Recreate the container. A plain restart is not enough, env changes only take effect on recreate:
   ```bash
   sudo docker compose up -d --force-recreate grafana
   sudo docker compose exec grafana env | grep INSECURE_EMAIL_LOOKUP
   ```
   Look for "Container grafana Recreated", not "Running", and the grep echoing the value.

   ![Nils signs in to Grafana as Viewer after the fix](images/phase4/nils-grafana-viewer.png)
4. Alternative with no email matching at all: reconcile on `oid`/`sub` by making the SCIM bridge set
   the Grafana user's auth identity to the Entra object ID the OIDC token presents. More work and a
   bridge change, but the flag becomes unnecessary.

**On the risk.** The setting name is deliberately alarming, so being precise about it:

- **What it guards against.** Email-based linking is dangerous when the IdP hands out email claims
  that are unverified and user-settable. An attacker sets their profile email to
  `victim@company.com`, signs in, gets linked to the victim's Grafana account, and takes it over.
- **Why it is acceptable here.** That precondition does not hold. The IdP is our own single Entra
  tenant, the email and UPN come from accounts we provision, users cannot rewrite their verified UPN,
  and every sign-in has already passed Conditional Access and MFA. We already trust Entra's email
  claim everywhere else in the project.
- **When it would not be.** Multi-tenant or federated setups where email claims come from IdPs you
  do not control, or tenants allowing unverified self-service email edits. There, use the
  immutable-ID approach in step 4 and leave the flag `false`.

**Lesson.** When SCIM pre-provisioning and JIT OIDC login manage the same user, identity
reconciliation is the hard part, not provisioning. "Entra sign-in succeeded" and "SCIM synced" do
not guarantee the app accepts the login. The long-term fix is reconciling on immutable IDs, not
email.

---

## Phase 5: auto-apply on a PIM-managed review promoted eligible to standing

**Symptom.** Applying results of an access review over `grafana-admins` converted an **eligible**
member into a **standing (active)** admin, the opposite of what Phase 3 set up.

**Cause.** A Teams + Groups review of a PIM-managed group covers eligible and active assignments
together, since there is no eligible-only scope. Applying "approve" persists whatever assignment
type was in scope.

**Fix.** Leave **Auto apply results to resource** unchecked on privileged reviews. Review across the
two stages, then apply manually only after confirming in
**PIM > Groups > grafana-admins > Assignments** that approved users are still Eligible.

**Lesson.** Auto-apply is safe for low-risk membership reviews and unsafe on PIM-managed groups.
Scale the apply behaviour to the tier being reviewed, which is why the viewer review auto-applies
and the editor and admin reviews do not.
