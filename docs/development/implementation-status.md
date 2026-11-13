# Implementation status

Updated 2026-11-14. The owner plans to create
`https://github.com/Inferlopec/gryt-auth` after the local commit. No GitHub
repository, release or project GHCR images are available at the time of this
update. Documentation examples must not imply otherwise.

## Implemented and checked locally

- Source-based Compose installation with independent auth database and CA volume.
- Explicit Admin API initialization that skips existing realms.
- Audience mapper and OIDC issuer/audience/expiry checks.
- Missing/corrupt CA protection and explicit first-time key provisioning.
- Pairing relay and built Keycloak device-authorization provider.
- Database and CA backup/recovery tools, including real restore exercises.
- Independent two-server joins, issuer namespace isolation and per-server bans.
- Operator/development documentation split and root agent entry point.

See [test results](test-results.md) for exact executed checks and fixture pins.

## Delivery work remaining

1. Build a versioned operator archive using an explicit allowlist.
2. Publish matching Identity and Keycloak-with-provider images and pin their digests.
3. Adapt initialization/preflight for a pull-only package without source trees,
   Maven builds, pom.xml or local Docker build contexts.
4. Add/test CI, package validation and release workflows after the repository exists.
5. Include source/license attribution and version/image manifests in distribution.

The current initialize.sh still builds from identity/ and keycloak-pairing/.
An archive that merely omits those directories would be broken.

## Production work remaining

The current operator checklist is [readiness](../operator/readiness.md).
Administrator MFA/automation, custom-flow TOTP enforcement, real client login,
network topology, mail delivery and off-host disaster recovery remain open.
Preparing documentation or an archive does not close these checks.

The chosen primary deployment is one existing host with Caddy, shared Gryt
services and one or more server projects. The separate-VM notes are optional.
Do not silently restore a dedicated-VM-first assumption.
