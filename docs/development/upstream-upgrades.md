# Upgrade upstream components (maintainers)

For installed-system commands use [operator maintenance](../operator/maintenance.md).
This page covers source changes and validation before delivering an update.

Record the running image digests, configuration revision, CA JWKS and user
subject before upgrading. Take a verified PostgreSQL backup and CA backup;
copy them off-host and rehearse recovery with the old images. Schedule a
maintenance window and restrict incoming traffic while changing schema.

Review upstream changes at a pinned commit. Keep Keycloak and the extension's
pom.xml version coupled, rebuild the JAR and run the full isolated suite:

```bash
keycloak-pairing/build.sh
tests/run_all.sh --with-gryt
```

Run `scripts/check-keycloak-version.mjs` with Node 22 (or in the test-runner
image with this repository mounted as the working directory). Update image
tags and digests together. Preserve local security patches listed in
identity/VENDOR.md. Do not clone mutable main over the deployed sources.

After review, rebuild/pull the selected new images and run `docker compose up
-d --wait`. Apply explicit policy jobs if their configuration changed. Existing
realms need `keycloak-client-policy` before an Identity Service upgrade that
requires aud=gryt-web. Never replace the realm as an upgrade step.

Verify OIDC login, certificate issuance, pairing and old-certificate trust.
On a database schema migration, rolling back just the image can be unsafe;
restore the matching pre-upgrade database backup before starting old Keycloak.
Keep the same CA volume and issuer URLs. No upgrade procedure changes the
production Gryt server version.
