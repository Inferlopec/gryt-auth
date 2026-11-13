# Security baseline and limits

Images in the authentication Compose file and Identity Service base are
pinned to digests. Identity Service runs without root. Services have resource
limits; the database has no published port. Configuration/secrets remain
outside Git. Backup scripts use umask 077 and validate archives before use.

Certificates require an OIDC token with the configured issuer and audience.
New/existing realms need the gryt-web audience mapper before enabling the
stricter validator. `scripts/initialize.sh` applies it idempotently.
The normal service refuses missing, corrupt or unreadable CA keys, including
an explicit key path. Only explicit initialization can generate an absent key;
initialization cannot overwrite a corrupt one.

Registration is closed. Bootstrap applies password length 12 and brute-force
protection to gryt, and brute-force protection to master. Pairing has upstream
session/approval limits. The certificate endpoint has no separate issuance
rate limiter yet; public release requires an operator-selected edge limit and
verification that it works. Do not treat login lockouts as registration abuse
protection.

`GRYT_ACCOUNT_KEY_GATE=learn` is the requested compatibility mode. It records
seed keys but does not enforce linked-device possession. Enforce mode needs
separate client testing/approval. Do not interpret relay success as proof that
the graphical client transferred every required account secret.

## Account suspension and certificate expiry

Disabling a Keycloak account is not immediate revocation of an existing Gryt
certificate. Certificates last 30 days by default, and server verification can
allow clock tolerance. Stolen access tokens may also remain usable until token
expiry. For immediate exclusion, apply bans independently to participating
Gryt servers. There is no centralized certificate revocation mechanism in this
implementation. Changing this is a separate protocol/policy decision.

## Outstanding release work

Master administrator MFA is not enforced by this repository yet. The vendored
realm includes passkey registration and an OTP setup action, but the custom
browser flow's OTP enforcement must be completed and tested before claiming
full TOTP support. Test the real Web/Desktop releases separately. Do not
publish the admin console for routine operation until the chosen MFA/access
policy and automation path are verified.

No production SMTP delivery, off-host copy, real Caddy trust chain or public
endpoint penetration testing has been performed. See [operator readiness](../operator/readiness.md) for release gates.
