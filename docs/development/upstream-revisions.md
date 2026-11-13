# Upstream Revisions

Inferlo Identity is built on the upstream Gryt authentication repository.
Every vendored component below is pinned to the commit listed here. Do not
upgrade a component in isolation: the pairing extension is compiled against a
specific Keycloak version, and the identity service is verified against the
realm and the Keycloak version it runs in front of.

| Component | Upstream path | Pinned commit | Pinned on |
|---|---|---|---|
| Gryt Identity Service (AGPL-3.0) | [`Gryt-chat/auth` `identity/`](https://github.com/Gryt-chat/auth/tree/main/identity) | `4bbd2348b65dc4ca61e2c1f39b100fb3d2ed05e4` | 2026-11-13 |
| Keycloak pairing extension (AGPL-3.0) | [`Gryt-chat/auth` `keycloak-pairing/`](https://github.com/Gryt-chat/auth/tree/main/keycloak-pairing) | `4bbd2348b65dc4ca61e2c1f39b100fb3d2ed05e4` | 2026-11-13 |
| Realm layout, bootstrap scripts | [`Gryt-chat/auth` `realm/`, `bootstrap/`](https://github.com/Gryt-chat/auth/tree/main/realm) | `4bbd2348b65dc4ca61e2c1f39b100fb3d2ed05e4` | 2026-11-13 |
| Keycloak image | [`quay.io/keycloak/keycloak`](https://quay.io/repository/keycloak/keycloak) | `26.5.3` (must equal `<keycloak.version>` in `keycloak-pairing/pom.xml`) | 2026-11-13 |

Upstream commit `4bbd2348...` is `main` as of 2026-11-13:
"Merge pull request #70 ... fix(ops): don't count probe failures when the probe has no internet".

## Upgrade procedure

1. Clone upstream at the new commit.
2. Diff `identity/`, `keycloak-pairing/`, `realm/gryt-realm.json`, `bootstrap/`.
3. If `keycloak.version` in `keycloak-pairing/pom.xml` changed, bump the Keycloak
   image tags in `docker-compose.yml` in the same change (checked by
   `scripts/check-keycloak-version.mjs`) and rebuild the pairing jar.
4. Replace the vendored directories, re-run `tests/run_all.sh --with-gryt`.
5. Update this file with the new SHA and date.

See [upstream upgrades](upstream-upgrades.md) for development and
[operator maintenance](../operator/maintenance.md) for deployment.

## Compatibility fixtures

- Gryt Server: `f537aa5e3d8a4bdba3c75e34b6dbfece2d727f42`, built and tested
  as two isolated servers by tests/docker-compose.test.yml.
- Gryt Client candidate: `0cd7718ae834485ed3d4e9f5699f9800d9c7cdc1`;
  runtime config, account settings and Electron callback code inspected;
  real Web/Desktop compatibility NOT EXECUTED.

Infrastructure bootstrap now uses the Admin API instead of offline realm
replacement. See identity/VENDOR.md for security patches to the vendored CA.

## Gryt CLI procedure reference

Operator file-layout/create/start examples were inspected at CLI v0.8.1
(commit `2c7dea7a71c66aeb448fcb75e202c9cc5a266a81`). Its `create` command
writes a new profile; `start` also writes/starts the shared project. The
operator guide intentionally applies existing-server trust through that
server's env_file and a targeted Compose recreation instead.
