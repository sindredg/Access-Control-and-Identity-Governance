# Troubleshooting log (unexpected things that occurred)

A running log of things that did not go as expected, in the format: symptom, cause, fix, lesson.
The happy path lives in the phase walkthroughs; this file is where the real learning is captured.

---

## Phase 0: FIDO2 passkey registered, but sign-in only prompted for normal MFA

**Symptom.** After registering a FIDO2 passkey on the break-glass account, the first sign-in
used the key as expected. But after signing out and back in, the account was only prompted for
normal MFA (Microsoft Authenticator), not the FIDO2 key.

**Cause.** Registering a passkey makes the method *available*, it does not make Entra *require*
it. The account still had other authentication methods registered (Authenticator / phone). Those
were pulled in partly by the SSPR (self-service password reset) "proof-up" prompt, which asks the
user to register phone / Authenticator. With multiple methods present, Entra offered the default
one at sign-in instead of the key.

**Fix.**
1. Removed all non-FIDO2 methods (Authenticator, phone/SMS, email) from the account, leaving the
   FIDO2 key as the only method.
2. Stopped SSPR from re-adding a proof-up: scope SSPR away from the account, or disable admin
   SSPR via `Update-MgPolicyAuthorizationPolicy`.
3. Re-tested: sign-in now goes straight to the FIDO2 key.

**Lesson.** Registration is not enforcement. For a break-glass account, making FIDO2 the *only*
method forces phishing-resistant sign-in with no Conditional Access policy involved. For normal
users you get the same guarantee the other way: enforce it with a Conditional Access
phishing-resistant authentication strength (Phase 2), not by stripping methods.

**How to prove it.**
- Registered (portal): Users, the account, Authentication methods, "Passkey (FIDO2)" listed.
- Registered (Graph):
  ```powershell
  Connect-MgGraph -Scopes "UserAuthenticationMethod.Read.All"
  Get-MgUserAuthenticationFido2Method -UserId "<breakglass-upn>" |
      Select-Object DisplayName, Model, CreatedDateTime
  ```

---

## Phase 1: Environment - PowerShell won't run the script ("not digitally signed")

**Symptom.** Running a repo script (for example `.\Deploy-CaPolicy.ps1 -List`) fails with
`File ... cannot be loaded. The file ... is not digitally signed. You cannot run this script on
the current system.`

**Cause.** Two things together: the machine's PowerShell execution policy (RemoteSigned or
AllSigned) blocks unsigned scripts that carry the "mark of the web", and files synced through
OneDrive or downloaded from GitHub get that mark, so freshly synced repo scripts are treated as
untrusted remote files.

**Fix.** Either allow scripts for the current session only (reverts when the window closes):
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```
Or, as a standing dev-machine setup, allow local and signed-remote scripts for your user and
strip the mark of the web from the repo:
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
Get-ChildItem -Path . -Recurse -Filter *.ps1 | Unblock-File
```

**Lesson.** This is an environment issue, not a code issue. Scripts pulled from OneDrive or GitHub
carry a mark-of-the-web zone tag; with RemoteSigned or AllSigned they need `Unblock-File` or a
relaxed execution policy. Prefer `-Scope Process Bypass` while iterating so the machine default
stays strict.

---

## Phase 1 · Password reset locks a user out of MFA registration (CA008 deadlock)

**Symptom.** After resetting a test user's password (Adam), sign-in and
`https://aka.ms/mysecurityinfo` both returned: "Your sign-in was blocked. We are currently
unable to collect additional security information. Your organisation requires this information
to be set from specific locations or devices."

**Cause.** `CA008-SecurityInfoRegistration-MFA` requires MFA to register security info. The
password reset left the account with no usable MFA method, so the user is deadlocked: they can't
do MFA (nothing registered) and can't register (policy requires MFA first).

**Fix.** Bootstrap the user with a Temporary Access Pass (a TAP counts as MFA), then let them
register their real method. Getting there surfaced three sub-issues, each a lesson on its own:
1. The TAP *method* was off by default. Enable it first:
   `PATCH /policies/authenticationMethodsPolicy/authenticationMethodConfigurations/TemporaryAccessPass`
   with `state = enabled` and an `includeTargets` group (`all_users`).
2. `New-MgUserAuthenticationTemporaryAccessPassMethod` returned 404 "user could not be found"
   because the UPN still had the literal `<tenant>` placeholder. Resolve the user first
   (`Get-MgUser`) and pass the object Id.
3. The pass code is only returned at creation and is not in the default table output. Capture it
   explicitly: `$result.TemporaryAccessPass`. A TAP already existing blocks creating another, so
   delete the old one first.

The user then signs in with the TAP code instead of a password, which satisfies MFA, passes
CA008, and lets them register. TAP is time-limited (60 min here), so register promptly, ours
expired mid-test and had to be reissued.

Quick alternative unblock: set CA008 to `enabledForReportingButNotEnforced`, let the user register
password + Authenticator, then set it back to `enabled`.

**Lesson.** Any policy that gates MFA *registration* creates a chicken-and-egg for users who have
no MFA yet (new hires, password resets that clear methods). Pair it with TAP-based onboarding or a
trusted-location exception so first registration is possible. This is the same TAP pattern the
Phase 6 lifecycle workflows use for new-hire onboarding.---

---

## Phase 2: Entry template (copy for the next one)

## Phase X · <short symptom title>

**Symptom.** What you saw.

**Cause.** Why it happened.

**Fix.** What resolved it (numbered if multiple steps).

**Lesson.** The takeaway worth remembering.

## Entry template (for the next one)

## Phase X · <short symptom title>

**Symptom.** What you saw.

**Cause.** Why it happened.

**Fix.** What resolved it (numbered if multiple steps).

**Lesson.** The takeaway worth remembering.
