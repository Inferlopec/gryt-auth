# Vendored: Gryt Keycloak Pairing Extension (AGPL-3.0)

This directory is vendored, unmodified, from the upstream Gryt authentication
repository. The extension adds `POST /realms/gryt/gryt-pairing/approve` and
`GET /realms/gryt/gryt-pairing/whoami` to Keycloak, which lets an already
signed-in device approve a device-grant user code for a new device (in-app
device linking; the protocol is in Gryt-chat/crypto `docs/pairing-design.md`).

- Upstream repository: https://github.com/Gryt-chat/auth (directory `keycloak-pairing/`)
- Pinned upstream commit: `4bbd2348b65dc4ca61e2c1f39b100fb3d2ed05e4` (main, 2026-11-13)
- License: AGPL-3.0 (see upstream `LICENSE`)

## Build

The extension is a plain jar mounted into the Keycloak container at
`/opt/keycloak/providers/gryt-pairing.jar`. Build it with:

```bash
keycloak-pairing/build.sh   # builds in Docker, writes keycloak-pairing/dist/gryt-pairing.jar
```

A missing jar becomes a directory on the bind mount, and Keycloak then refuses
to start — `scripts/preflight.sh` checks for it before `compose up`.

## Version coupling

`<keycloak.version>` in `pom.xml` must equal the `quay.io/keycloak/keycloak:*`
image tag in `docker-compose.yml`. `scripts/check-keycloak-version.mjs` fails
the check otherwise, so a Keycloak bump requires rebuilding and re-testing the
extension against the new image.
