# Break-glass account with phishing-resistant MFA (FIDO2)

**Goal:** create a cloud-only emergency-access (break-glass) account with a permanent Global
Administrator role, then secure it with phishing-resistant MFA (a FIDO2 security key) so it's
the guaranteed way back in if Conditional Access ever locks us out.

> **Best practice:** Microsoft recommends emergency-access accounts use a phishing-resistant
> passwordless method, **passkey (FIDO2)** (recommended) or certificate-based auth, rather than
> a password alone, and that they're excluded from enforced Conditional Access policies.
> See [Manage emergency access accounts in Microsoft Entra ID](https://learn.microsoft.com/entra/identity/role-based-access-control/security-emergency-access).

**Why this matters.** If Conditional Access is ever misconfigured, a normal admin can be locked out
along with everyone else. The break-glass account is the one identity we keep deliberately outside
every policy, so there is always a way back in.

**Trade-off from best practice.** Microsoft recommends at least two emergency-access accounts, so a
single lost key cannot lock the tenant out. We run one here to keep the lab simple, which leaves that
FIDO2 key as a single point of failure, and the account is not monitored yet (alerting is Phase 7).
The production version would add a second account with a different method stored separately, and alert
on every break-glass sign-in. See [ADR 0001](adr/0001-single-break-glass-account.md) and the
[risk register](risk-and-controls.md).

---

## Phase 1: Create the break-glass account

**1. Create a break-glass security group** in Entra ID and assign it the permanent Global Administrator role.

![Break-glass security group with Global Administrator role](images/phase0/breakglass-group-ga-role.png)

**2. Create the break-glass account** (cloud-only, on the `*.onmicrosoft.com` domain).

![Create break-glass user](images/phase0/create-breakglass-account.png)

**3. Add the break-glass account to the break-glass security group.**

![Add account to break-glass group](images/phase0/add-account-to-group.png)

**4. In PowerShell, connect to Microsoft Graph and set / verify "password never expires" on the account.**

```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All"

Update-MgUser -UserId <BREAKGLASS_OBJECT_ID> -PasswordPolicies DisablePasswordExpiration

Get-MgUser -UserId "<BREAKGLASS_OBJECT_ID>" -Property DisplayName, UserPrincipalName, PasswordPolicies |
    Select-Object DisplayName, UserPrincipalName, PasswordPolicies
```

![Password policy set and verified](images/phase0/password-never-expires.png)

---

## Phase 2: MFA and FIDO2

**1.** Sign in with the break-glass account and change the password to a random, complex string that is saved securely (offline).

![First sign-in and password change](images/phase0/first-signin-password-change.png)

**2.** Set up MFA and sign in to the break-glass account for the first time.

![MFA setup](images/phase0/mfa-setup.png)

**3.** After setting up MFA - configure the FIDO2 key from the Microsoft Authenticator app on the mobile device.

**4.** Sign out and in again: We're now prompted for both MFA and FIDO2 during setup. We test FIDO2 for the first time and it works.

**5.** Go to the break-glass account and check **Authentication methods**, both the normal MFA method and the FIDO2 key are listed.

![Authentication methods: MFA and FIDO2](images/phase0/auth-methods-both.png)

**6.** Remove the other method so the account uses only phishing-resistant MFA with FIDO2.

![Only FIDO2 remaining](images/phase0/fido2-only.png)

**7.** Try to sign in again: we're now prompted only for the FIDO2 key, and sign in.

![Sign in FIDO2 only](images/phase0/sign-in-fido2.png)

**8.** We are now signed in as the break-glass account, secured with phishing-resistant MFA (FIDO2).

![Signed in with FIDO2 only](images/phase0/signed-in-fido2.png)

---

## Verification / test matrix

| # | Test | Type | Result |
| --- | --- | --- | --- |
| 1 | Break-glass signs in with the FIDO2 key | + | Succeeds passwordless, no other prompt |
| 2 | Only the FIDO2 method is registered | control | Authenticator and phone removed, the key is the sole method |
| 3 | Password set to never expire | control | Verified through Graph (`PasswordPolicies`) |
| 4 | Sign-in offers a non-FIDO2 method | - | Should not happen once other methods are removed; if it does, an unwanted method is still registered |
| 5 | Break-glass excluded from enforced Conditional Access | + / control | Confirmed in Phase 1 and 3: the account keeps access with every policy On |

Not yet covered: alerting on break-glass use. That is Phase 7, and until then the account is a
known unmonitored gap (see the [risk register](risk-and-controls.md)).

---

### Reference
- [Manage emergency access accounts in Microsoft Entra ID](https://learn.microsoft.com/entra/identity/role-based-access-control/security-emergency-access). Microsoft's best-practice guidance (create cloud-only GA accounts, secure with FIDO2/passkey, exclude from Conditional Access, monitor and test).
