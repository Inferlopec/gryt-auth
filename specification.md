# Technical Specification: Inferlo Identity

**Project:** Inferlo Identity — Centralized Authentication for Gryt Chat\
**Date:** November 13, 2026\
**Implementation type:** Self-hosted authentication infrastructure\
**Target platform:** Ubuntu 24.04 LTS, Docker Compose, Keycloak, PostgreSQL\
**Status:** Infrastructure audit completed; implementation pending

---

## 1. Project Objective

Design and implement an independent, self-hosted authentication platform named **Inferlo Identity**, based on the official Gryt authentication architecture.

The system must provide a single user identity across multiple Gryt Chat servers operated by Inferlo.

### Core requirements

- Centralized account registration, authentication, and recovery.
- One persistent user identity across all participating Gryt servers.
- Support for multiple devices per account.
- Compatibility with Gryt's existing identity and certificate protocols.
- Independent server-specific permissions, memberships, roles, and bans.
- No dependency on the official Gryt authentication infrastructure for Inferlo-issued identities.
- Independent lifecycle, upgrades, and backups.
- No disruption to the existing production Gryt server.

**Identity scope:** Inferlo Identity accounts must be recognized only by Gryt servers explicitly configured to trust the Inferlo certificate authority. They must never impersonate official Gryt identities.

Avoid implementing custom authentication protocols where an official Gryt mechanism already exists.

## 2. Authoritative References

Primary sources:

- Gryt Auth: https://github.com/Gryt-chat/auth
- Gryt Identity Service: https://github.com/Gryt-chat/auth/tree/main/identity
- Gryt Client: https://github.com/Gryt-chat/client
- Gryt Server: https://github.com/Gryt-chat/server
- Gryt Hosting Documentation: https://docs.gryt.chat/docs/host/
- Keycloak Documentation: https://www.keycloak.org/documentation

The upstream Gryt Auth repository is published primarily for transparency and development, rather than as a turnkey third-party production deployment.

Use its implementation as the compatibility reference, but adapt its infrastructure configuration for Inferlo.

Before editing, inspect the relevant upstream code and configuration schemas. Do not assume environment variables or configuration options that are not supported by the selected upstream revision.

## 3. Completed Infrastructure Audit

The following information has already been verified by the infrastructure owner.

**The implementation agent does not need to conduct a host audit and will not have access to the production server.**

### 3.1 Existing production host

| Property | Verified value |
|---|---|
| Operating system | Ubuntu 24.04.5 LTS |
| Architecture | x86_64 |
| CPU | 4 vCPU, Intel Xeon E5-2630 v4 |
| Total RAM | 3.8 GiB |
| Available RAM at audit | 2.9 GiB |
| Swap | 3.8 GiB, unused |
| Root filesystem | 30 GiB |
| Used disk | 16 GiB |
| Available disk | 14 GiB |
| Filesystem inode usage | 17% |
| Container engine | Docker + Compose |
| Firewall | `gryt-port-filter.service`, enabled and active |

Docker storage usage:

- Images: 5.652 GB, approximately 2.889 GB reclaimable.
- Containers: 454.7 kB.
- Local volumes: 12.44 kB reported by Docker.
- Build cache: 430.8 MB.

The available storage is sufficient for the existing installation but provides limited capacity for an additional authentication database and its backup history.

### 3.2 Gryt Server

Production server:

- Name: `Inferlo Gaming`
- Slug: `inferlo-gaming`
- Gryt CLI: `0.8.1`
- Public endpoint: `https://chat.inferlo.xyz`
- Docker network: `gryt`
- Main port: TCP 5000
- Management API: `127.0.0.1:5090`

CLI configuration:

```text
/home/inferlo/.config/gryt/servers/inferlo-gaming/
├── profile.json
├── .env
├── compose.yaml
└── data/
```

Important environment settings:

```dotenv
SERVER_NAME=Inferlo Gaming
HOST=0.0.0.0
PORT=5000
DATA_DIR=/data
STORAGE_BACKEND=filesystem

GRYT_AUTH_MODE=required
GRYT_IDENTITY_TIERS=account,local
GRYT_TRUSTED_PROXY_HOPS=1

SFU_WS_HOST=ws://gryt-sfu:5005
SFU_PUBLIC_HOST=wss://sfu.inferlo.xyz

CORS_ORIGIN=http://127.0.0.1:15738,https://app.gryt.chat,https://beta.gryt.chat,https://chat.inferlo.xyz
```

`GRYT_AUTH_MODE=required` is a legacy server-availability setting, not the account requirement policy.

The following variables are not explicitly configured in the audited environment:

- `GRYT_OIDC_ISSUER`
- `GRYT_OIDC_AUDIENCE`
- `GRYT_TRUSTED_CERT_ISSUERS`

Do not assume that their absence means authentication is disabled. Investigate the current upstream defaults before preparing integration changes.

### 3.3 Containers and persistent data

Existing containers:

| Container | Purpose |
|---|---|
| `gryt-inferlo-gaming` | Gryt Server |
| `gryt-inferlo-gaming-image-worker` | Media processing |
| `gryt-sfu` | Shared SFU |
| `inferlo-caddy` | TLS reverse proxy |
| `gryt-gigachad-gigachad-1` | Independent bot |
| `searxng-core` | Independent search service |

The Gryt Server and Image Worker share the same bind mount:

```text
Host:
/home/inferlo/.config/gryt/servers/inferlo-gaming/data

Container:
/data
```

The Gryt Server uses SQLite, with files and uploads stored under its persistent data directory.

The SFU has no persistent mount in the audited deployment.

All primary Gryt containers were healthy during the audit.

Existing Gryt images use the `latest` tag. Their versions must not be changed as part of this project.

### 3.4 Caddy and networking

Caddy runs in Docker using host networking.

Configuration:

```text
/opt/caddy/Caddyfile
```

Existing virtual hosts:

```caddyfile
chat.inferlo.xyz {
    reverse_proxy 127.0.0.1:5000
}

sfu.inferlo.xyz {
    reverse_proxy 127.0.0.1:5005
}
```

Both production HTTPS health endpoints returned HTTP 200.

Caddy persistent volumes:

```text
gryt-prod_gryt-prod-caddy-config
gryt-prod_gryt-prod-caddy-data
```

These volumes are actively mounted and must not be deleted.

The existing firewall protects directly published Gryt backend ports.

### 3.5 DNS status

The intended authentication endpoints are:

| Hostname | Purpose | Current state |
|---|---|---|
| `auth.inferlo.xyz` | Keycloak | No IPv4 record |
| `id.inferlo.xyz` | Identity Service | No IPv4 record |
| `app.inferlo.xyz` | Self-hosted web client | No IPv4 record |

DNS creation will be handled separately by the infrastructure owner.

No DNS-related assumptions should be embedded into the implementation beyond these intended hostnames.

## 4. Deployment Architecture

### 4.1 Recommended infrastructure

Because the existing Gryt host has only 3.8 GiB of RAM, deploying a production Keycloak instance on it without a resource upgrade is not recommended.

Preferred deployment: **dedicated authentication VM**.

Recommended initial resource allocation:

| Resource | Target |
|---|---|
| CPU | 4 vCPU |
| RAM | 8 GiB |
| Disk | 40–60 GiB |
| Operating system | Ubuntu 24.04 LTS |
| Runtime | Docker Engine + Compose |

These are capacity-planning targets, not minimum compatibility requirements.

The deployment must also support placement on the existing host if its resources are expanded.

### 4.2 Authentication stack

Implement the following independent services:

1. PostgreSQL — persistent Keycloak database.
2. Keycloak — central OIDC identity provider.
3. Gryt Identity Service — certificate authority and device-pairing relay.
4. Bootstrap jobs — initial realm configuration and security policies.
5. Backup and restore tooling.

Recommended deployment root:

```text
/opt/inferlo-identity/
```

Use a dedicated Docker Compose project and isolated network.

Do not modify the existing Gryt Compose project.

### 4.3 Reverse proxy

Reuse the existing Caddy infrastructure where practical.

Intended public endpoints:

```text
https://auth.inferlo.xyz
https://id.inferlo.xyz
```

If both stacks share a host, publish Keycloak and Identity Service only to loopback addresses.

Suggested host-side ports:

```text
127.0.0.1:18080 -> Keycloak
127.0.0.1:18081 -> Gryt Identity Service
```

If the authentication stack runs on a separate VM, use a private, firewall-restricted network connection between Caddy and the authentication services, with appropriate transport encryption for the selected network topology.

Do not assume localhost routing works across separate VMs.

Never publish PostgreSQL publicly.

Provide Caddy snippets for both deployment layouts. Do not apply either configuration automatically.

## 5. Keycloak Requirements

Use the upstream Gryt Keycloak implementation as the basis.

### Realm configuration

- Realm: `gryt`
- Public issuer: `https://auth.inferlo.xyz/realms/gryt`
- Primary OIDC client: `gryt-web`
- Authorization Code Flow with PKCE S256
- Appropriate redirect URIs and Web Origins
- Verified compatibility with Gryt Web and Desktop clients

Avoid changing the realm ID once accounts have been created.

### Account functionality

Implement:

- Administrator-created accounts as the initial registration policy.
- Email verification support.
- Password recovery.
- Password policy.
- Brute-force protection.
- TOTP and WebAuthn support.
- Account management.
- Future self-registration capability, disabled initially.

SMTP must be configurable without hardcoding a provider. The production SMTP service has not been selected.

All required account policies must be applied by reproducible bootstrap procedures.

### Device authorization

Gryt supports device linking through OAuth Device Authorization Grant and an upstream Keycloak pairing extension.

Include the relevant upstream integration.

Ensure:

- New devices can authenticate.
- Existing devices can approve sign-in where supported.
- OAuth device-grant settings are reproducible.
- Provider extension versions match the selected Keycloak version.
- Linking behavior is verified against the selected Gryt client revision.

Do not silently omit device-grant support.

### Realm initialization safety

Realm import must be a one-time initialization procedure.

A normal container startup or upgrade must never run a destructive realm replacement.

In particular:

```dotenv
GRYT_IMPORT_REALM=0
```

must be the normal post-initialization state.

The workflow must guard against accidental use of `--override true` on an existing realm.

Include a separate, explicitly authorized recovery or re-import procedure.

## 6. Gryt Identity Service Requirements

Use the official Gryt Identity Service implementation.

Required functionality:

- Validate access tokens issued by Inferlo Keycloak.
- Bind authenticated Keycloak subjects to client EC P-256 public keys.
- Issue signed identity certificates.
- Publish the CA's public keys through JWKS.
- Support the upstream pairing relay.
- Maintain consistent certificate issuer and subject semantics.
- Preserve the CA private key across container recreation.

Expected endpoints include:

```text
GET  /health
GET  /.well-known/jwks.json
POST /api/v1/certificate

POST   /api/v1/pairing/sessions
POST   /api/v1/pairing/sessions/claim
POST   /api/v1/pairing/sessions/:id/messages
GET    /api/v1/pairing/sessions/:id/messages
DELETE /api/v1/pairing/sessions/:id
```

Configure and verify supported upstream settings:

```dotenv
GRYT_OIDC_ISSUER=https://auth.inferlo.xyz/realms/gryt
GRYT_IDENTITY_ORIGIN=https://id.inferlo.xyz

GRYT_CERT_LIFETIME_DAYS=30
GRYT_ACCOUNT_KEY_GATE=learn
```

Use persistent, protected CA key storage.

The `learn` account-key gate is the initial compatibility mode. Switching to `enforce` requires separate testing and approval.

Configure trusted reverse-proxy addresses explicitly. Do not trust arbitrary client-provided forwarding headers.

## 7. Gryt Client Compatibility

The authentication platform must support the existing Gryt client protocol.

Required client-facing configuration:

```dotenv
GRYT_OIDC_ISSUER=https://auth.inferlo.xyz/realms/gryt
GRYT_OIDC_REALM=gryt
GRYT_OIDC_CLIENT_ID=gryt-web
GRYT_IDENTITY_URL=https://id.inferlo.xyz
GRYT_AUTH_API=https://auth.inferlo.xyz
```

Treat `GRYT_AUTH_CALLBACK_URL` as a separate setting that must match the actual registered callback route.

For the future self-hosted web client, use:

```text
https://app.inferlo.xyz
```

The upstream web client supports runtime configuration through `/config.js`. Prefer this mechanism over rebuilding the client solely to change authentication endpoints.

Document the setup procedure.

Validate web and desktop compatibility separately, including multiple devices and account persistence.

A complete custom web-client deployment may be implemented as a separate integration package; it must not delay delivery of the core authentication infrastructure.

## 8. Multi-Server Identity and Trust

The design must support multiple independent Gryt servers trusting the same Inferlo CA.

Each Gryt server retains authority over:

- Server membership.
- Roles.
- Permissions.
- Invitations.
- Moderation.
- Bans.
- Channels and message history.

The authentication system must not centralize these server-specific permissions.

### Identity isolation

Investigate and document how Gryt handles:

- Multiple trusted certificate issuers.
- Issuer-scoped user identities.
- Subject collisions between different issuers.
- Certificate verification and trust ordering.
- Existing account and local identity namespaces.

Never allow a certificate issued by Inferlo Identity to impersonate a user from another trusted issuer.

### Existing Inferlo Gaming integration

The production server currently permits:

```dotenv
GRYT_IDENTITY_TIERS=account,local
```

Maintain this setting during the proposed transition.

Do not remove official Gryt trust or local identities until migration behavior is tested and explicitly approved.

Prepare a configuration proposal for adding Inferlo as a trusted issuer without disrupting existing accounts.

Preserve existing identity mappings, administrator privileges, ownership, roles and bans.

Any local-to-account migration must be planned and tested separately.

## 9. Security Requirements

Apply production security principles:

- Version-pinned container images, preferably immutable digests.
- Explicit container memory and CPU limits.
- Minimum necessary container privileges.
- Non-root processes where supported.
- Restricted secret and certificate storage.
- Secure and reproducible secret generation.
- No passwords, access tokens or private keys in Git.
- No database port exposed publicly.
- No unnecessary application ports exposed publicly.
- Correct reverse-proxy trust configuration.
- TLS at public endpoints.
- Keycloak administrator MFA.
- Brute-force protection and endpoint rate limiting.
- Conservative account registration policy.
- No unauthenticated administrative endpoints.
- Validated redirect URIs and Web Origins.

Provide a documented security baseline and identify any deviations required by upstream Gryt compatibility.

Do not attempt to protect registration using Keycloak login brute-force settings alone; account creation needs its own abuse controls if public registration is enabled later.

## 10. Persistence, Backup and Recovery

Implement persistent storage for:

- PostgreSQL.
- Identity Service CA private key.
- Any other identity state required by the selected upstream implementation.

Provide:

- Consistent PostgreSQL backups.
- Protected backup of the CA key.
- Configurable backup scheduling.
- Configurable retention.
- Backup integrity checks.
- Restore procedures.
- Off-host backup integration.
- Clear recovery instructions.

The external backup destination has not been selected. It must remain configurable.

Do not treat backups on the same VM as sufficient disaster recovery.

Recovery must preserve user IDs and the existing CA trust relationship.

Document both planned CA key rotation and unexpected CA key loss, including their impact on previously issued certificates.

## 11. Implementation Scope

The agent's task is to **produce a complete deployable implementation**, not to operate the existing production host.

### Phase 1 — Project preparation

Create the project layout, configuration templates and documentation.

Use pinned, compatible upstream revisions.

Prepare the production-oriented Compose configuration and required dependencies.

### Phase 2 — Authentication implementation

Configure Keycloak, PostgreSQL, the Gryt Identity Service and its pairing integrations.

Implement bootstrap jobs and security policies.

### Phase 3 — Operations and recovery

Implement:

- Initialization.
- Start/stop.
- Configuration validation.
- Health checks.
- Upgrade procedure.
- Backups.
- Restore tooling.
- Recovery documentation.

### Phase 4 — Compatibility testing

Provide automated tests where possible and a reproducible integration test plan for:

- OIDC authentication.
- Identity certificate issuance.
- JWKS verification.
- Incorrect issuer and audience rejection.
- Expired and invalid certificate rejection.
- Device authorization and pairing.
- CA persistence after restart.
- Multi-server trust.
- Issuer namespace isolation.

An isolated test Gryt Server may be included in the implementation for integration testing.

Do not use production data or keys for tests.

### Phase 5 — Production integration package

Prepare, but do not apply:

- DNS requirements.
- Caddy snippets.
- Gryt CLI profile changes.
- Client runtime configuration.
- CORS adjustments.
- Trusted issuer configuration.
- Deployment checklist.
- Rollback checklist.
- Verification procedures.

All changes affecting production must be separately reviewed and authorized.

## 12. Deliverables

Provide a self-contained project containing at minimum:

```text
inferlo-identity/
├── compose.yaml
├── .env.example
├── README.md
├── bootstrap/
├── config/
├── scripts/
├── tests/
└── docs/
    ├── architecture.md
    ├── deployment.md
    ├── security.md
    ├── backup-restore.md
    ├── upgrades.md
    ├── gry t-integration.md
    └── rollback.md
```

Use `gryt-integration.md` as the actual filename (without the visual spacing shown above).

The precise layout may be improved if justified.

All implementation documentation, scripts, code comments and configuration templates must be written in English.

Deliver:

1. Fully prepared Docker Compose deployment.
2. Complete configuration templates.
3. Realm initialization and security bootstrap scripts.
4. Gryt Identity Service integration.
5. Device authorization support.
6. Persistent storage and backup tooling.
7. Automated validation and test scripts.
8. Deployment and operational documentation.
9. Production integration plan.
10. Rollback and disaster-recovery documentation.

Do not include real production secrets.

## 13. Acceptance Criteria

Implementation preparation is considered complete when:

- The Compose configuration passes validation.
- All required services are correctly defined.
- Configuration and secrets are externalized.
- Container versions are pinned.
- Required volumes are persistent.
- Health checks and startup dependencies are implemented.
- Realm initialization is protected against accidental destructive imports.
- OIDC, certificate issuance and device pairing are covered by tests.
- Certificate issuer and identity namespace isolation are addressed.
- Backup and restore tooling is present.
- The deployment procedure is reproducible.
- Both same-host and dedicated-VM network requirements are documented.
- The Gryt integration procedure contains exact proposed configuration changes.
- A rollback plan is included.

A successful isolated test deployment and end-to-end Gryt login are required before declaring the system production-ready.

If the agent cannot execute integration tests in its environment, it must explicitly mark them as **not executed** and provide reproducible test commands. It must not report unperformed tests as passed.

## 14. Operational Constraints and Exclusions

The implementation agent has no access to the production Gryt host.

Do not request or rely on SSH access.

The completed audit information in this specification is authoritative for initial implementation.

The agent must not:

- Modify the existing Gryt installation.
- Change production Docker containers.
- Change production DNS records.
- Modify the existing Caddy configuration.
- Modify firewall rules.
- Rotate production secrets.
- Access or modify existing SQLite data.
- Import an existing production user database.
- Perform an unapproved identity migration.
- Assume production SMTP or external backups are already configured.

Any missing deployment-specific value must be provided through a configuration placeholder and documented clearly.

Do not invent infrastructure details.

## 15. Final Objective

Deliver a secure, maintainable, production-oriented **Inferlo Identity** implementation that can be deployed independently and integrated with multiple Gryt servers.

The solution must follow Gryt's authentication and identity protocols, preserve compatibility with existing clients and provide complete operational documentation.

The implementation must be ready for independent testing and subsequent operator-controlled deployment, without changing the current production Inferlo Gaming server.

**Primary success condition:** A single Inferlo account can securely authenticate on multiple Gryt servers that explicitly trust the Inferlo certificate authority, without identity collisions or changes to existing production users.
