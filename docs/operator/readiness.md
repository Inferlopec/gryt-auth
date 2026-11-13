# Readiness and current limits

The current source snapshot is suitable for isolated integration testing.
It is not yet a production-ready release. The GitHub repository and operator
release are not published; see [download](download.md).

## Already checked

Local tests passed for OIDC code + PKCE, signed device certificates,
issuer/audience/expiry rejection, device authorization, pairing, two devices
joining two actual Gryt servers, CA namespace isolation and independent bans.
Account IDs and certificate trust survived the tested database/CA recovery
procedures. Repeated initialization preserved existing users.

## Complete before public use

| Area | Required result |
|---|---|
| Existing host | Enough spare memory/disk for Keycloak, database, builds and backups alongside Gryt |
| Existing Gryt image | Its exact deployed version isolates account IDs by CA issuer; existing users retain their rights |
| Caddy and DNS | Correct public HTTPS endpoints and confirmed trusted-proxy source addresses |
| Administrator access | Permanent admin with verified MFA; temporary bootstrap admin replaced; compatible automation credentials |
| TOTP | Custom realm browser flow enforces OTP where required, not merely offers enrollment |
| Client compatibility | Actual Web/Desktop releases pass login, restart, device approval and two-server checks |
| SMTP | Verification and password-recovery emails are delivered successfully |
| Recovery | Encrypted off-host backups and a successful independent fresh-host restore |
| Abuse controls | Verified rate limiting for certificate issuance; registration stays closed initially |
| Distribution | Versioned operator archive, checksums and matching prebuilt images are built and tested |

Current administrative scripts use a password grant. MFA-compatible automation
still needs implementation; turning MFA off is not the intended production
solution. The realm includes an OTP setup action but its custom browser flow
has not completed OTP enforcement.

Account disable/delete/password reset is not centralized certificate
revocation. Certificates last 30 days by default, with server clock tolerance.
Use per-server bans when immediate exclusion is required. The current CA
publishes one signing key; rotation with overlapping old/new keys is not
implemented.

Maintainers record detailed test evidence separately in development docs;
operators should use this page as the current release checklist.
