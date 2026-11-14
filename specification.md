# Requirements and historical infrastructure audit

Owner audit: 2026-11-13. Condensed on 2026-11-14; this is a historical baseline,
not evidence of current host capacity, DNS or production readiness. The normal
layout is now an Identity stack on the existing host after a resource upgrade;
the earlier preference for a dedicated VM is superseded.

## Required behavior

- One account on multiple explicitly trusting Gryt servers, with issuer
  isolation and independent per-server membership, ownership, roles, bans,
  permissions, invitations, messages and media storage.
- Upstream-compatible OIDC code + PKCE, device certificates/JWKS and pairing;
  stable account subjects and CA across restarts/recovery. Avoid custom auth
  protocols where upstream already supplies one.
- Closed registration initially; administrator-created accounts, password policy,
  brute-force protection, configurable verification/recovery mail and tested
  administrator MFA/TOTP/WebAuthn policies before claiming production support.
- Independent source-based installation, explicit non-destructive initialization,
  version-coupled components, private DB, TLS/proxy trust and protected secrets.
- Database/CA/account-key backups, configurable off-host transport and restoration
  preserving subjects/trust. Exceptional destructive replacement must be explicit.
- Full independence from official authentication infrastructure remains an
  objective; the tested Desktop hosted-callback dependency is an open limitation.
- Prepare operator integration/rollback instructions without accessing production,
  reinstalling Gryt, changing its running version or migrating identities.

Current instructions and acceptance are maintained in [SETUP](docs/SETUP.md),
[OPERATIONS](docs/OPERATIONS.md) and [DEVELOPMENT](docs/DEVELOPMENT.md).
Unfinished functionality must not be presented as implemented; defects and
acceptance work belong in [GitHub Issues](https://github.com/Inferlopec/gryt-auth/issues).

## Owner-reported host snapshot

| Item | Recorded value |
|---|---|
| OS / architecture | Ubuntu 24.04.5 LTS / x86_64 |
| CPU | 4 vCPU, Intel Xeon E5-2630 v4 |
| RAM / available / swap | 3.8 GiB / 2.9 GiB / 3.8 GiB unused |
| Root disk / used / available | 30 GiB / 16 GiB / 14 GiB; inode use 17% |
| Docker images / reclaimable | 5.652 GB / approximately 2.889 GB |
| Container / local-volume / build-cache usage | 454.7 kB / 12.44 kB reported / 430.8 MB |
| Runtime / firewall | Docker + Compose; `gryt-port-filter.service` active |
| Gryt | Inferlo Gaming, slug `inferlo-gaming`; CLI 0.8.1 |
| Server public / backend / management | `https://chat.inferlo.xyz` / TCP 5000 / `127.0.0.1:5090` |
| Server files/data | `/home/inferlo/.config/gryt/servers/inferlo-gaming/`; SQLite and uploads under `data/`, mounted at `/data` in server/worker |
| Existing network | `gryt`; shared SFU has no persistent mount |
| Caddy | `inferlo-caddy`, host networking; `/opt/caddy/Caddyfile` |
| Caddy volumes | `gryt-prod_gryt-prod-caddy-config`, `gryt-prod_gryt-prod-caddy-data`; retain both |
| Routes | chat → loopback 5000; `sfu.inferlo.xyz` → loopback 5005 |
| Health/images | Primary Gryt containers healthy, public health HTTP 200; images tagged `latest`, preserve running versions |
| DNS | Auth/id/app hostnames had no IPv4 records; owner handles DNS separately |

Containers: `gryt-inferlo-gaming`, `gryt-inferlo-gaming-image-worker`, `gryt-sfu`,
`inferlo-caddy`, independent `gryt-gigachad-gigachad-1` and `searxng-core`.

Recorded server policy: account/local tiers, legacy availability mode `required`,
one trusted proxy hop; no explicit OIDC issuer/audience or trusted-CA list.
Absence of those settings is not evidence that authentication was disabled.
SFU used internal `ws://gryt-sfu:5005` and public `wss://sfu.inferlo.xyz`.
Existing CORS allowed the Desktop loopback Origin and official app/beta/chat
origins. Preserve effective policy rather than replacing it from this snapshot.

The host needs more resources before production Keycloak use. Original planning
suggested 4 vCPU, 8 GiB RAM and 40–60 GiB disk for a separate auth VM; these are
planning estimates, not measured minimums. SMTP and off-host backup destinations
were unselected. Repository work has no permission to access host data, rotate
production secrets or apply infrastructure/identity changes.
