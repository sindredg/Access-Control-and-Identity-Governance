# Troubleshooting log (unexpected things that occurred)

A running log of things that did not go as expected, in the format: symptom, cause, fix, lesson.
The happy path lives in the phase walkthroughs; this file is where the real learning is captured.

---

## Phase 0 · FIDO2 passkey registered, but sign-in only prompted for normal MFA

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

## Entry template (for the next one)

## Phase X · <short symptom title>

**Symptom.** What you saw.

**Cause.** Why it happened.

**Fix.** What resolved it (numbered if multiple steps).

**Lesson.** The takeaway worth remembering.
