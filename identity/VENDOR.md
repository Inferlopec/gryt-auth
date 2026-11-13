# Vendors: Gryt Identity Service (AGPL-3.0)

This directory is vendored, unmodified, from the upstream Gryt authentication
repository. The Identity Service is a certificate authority that binds
Keycloak users to EC P-256 device keys and issues signed JWT certificates.

- Upstream repository: https://github.com/Gryt-chat/auth (directory `identity/`)
- Pinned upstream commit: `4bbd2348b65dc4ca61e2c1f39b100fb3d2ed05e4` (main, 2026-11-13)
- License: AGPL-3.0 (see upstream `LICENSE`)

To upgrade: re-clone the upstream at a new commit, replace this directory,
rebuild the image (`docker compose build identity`), and re-run the test suite.
Record the new commit SHA here and in `docs/upstream-revisions.md`.
