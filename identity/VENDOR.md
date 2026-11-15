# Vendors: Gryt Identity Service (AGPL-3.0)

This directory is vendored with the local patches below, from the upstream Gryt authentication
repository. The Identity Service is a certificate authority that binds
Keycloak users to EC P-256 device keys and issues signed JWT certificates.

- Upstream repository: https://github.com/Gryt-chat/auth (directory `identity/`)
- Pinned upstream commit: `77c38ca94dbe5a91adf271c234b535b5d4548fb2` (Auth PR #71; Identity source unchanged from `4bbd2348b65dc4ca61e2c1f39b100fb3d2ed05e4`)
- License: upstream AGPL-3.0-or-later notice; see [license text](../LICENSES/gryt-auth.txt)

To upgrade: inspect the selected upstream diff, selectively integrate changes,
preserve the local patches below, rebuild the image
(`docker compose build identity`), and re-run the test suite. Record the new
commit SHA here and in [root VENDOR.md](../VENDOR.md). Follow
[build and upstream checks](../docs/DEVELOPMENT.md#build-and-upstream-changes).

## Local patches

- Validate the gryt-web audience and required expiry/issued-at claims.
- Load the CA before serving health; refuse missing/corrupt configured keys.
- Only explicit initialization may create an absent CA key, with exclusive creation.
- Pin the Node base digest and frozen installs; add a separate test-runner stage.

Keep these changes when upgrading the pinned source. The certificate and pairing
wire formats remain upstream-compatible.
