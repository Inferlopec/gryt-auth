# Vendored: Gryt Keycloak Pairing Extension (AGPL-3.0)

This directory is vendored, unmodified, from the upstream Gryt authentication
repository. The extension adds `POST /realms/gryt/gryt-pairing/approve` and
`GET /realms/gryt/gryt-pairing/whoami` to Keycloak, which lets an already
signed-in device approve a device-grant user code for a new device (in-app
device linking; the protocol is in Gryt-chat/crypto `docs/pairing-design.md`).

- Upstream repository: https://github.com/Gryt-chat/auth (directory `keycloak-pairing/`)
- Pinned upstream commit: `4bbd2348b65dc4ca61e2c1f39b100fb3d2ed05e4` (main, 2026-11-13)
- License: upstream AGPL-3.0-or-later notice; see [license text](../LICENSES/gryt-auth.txt)

## Build and version coupling

Build/validation commands are maintained in
[DEVELOPMENT](../docs/DEVELOPMENT.md#build-and-upstream-changes).
The JAR is mounted at `/opt/keycloak/providers/gryt-pairing.jar`.
`<keycloak.version>` in pom.xml must equal the Keycloak image tag in Compose;
`scripts/check-keycloak-version.mjs` checks this coupling. Rebuild/retest the
provider for a Keycloak change. No provider source changes are introduced by
the documentation consolidation.
