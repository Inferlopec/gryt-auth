# Rollback

Before production integration, save the exact original Gryt profile extraEnv,
CORS and Caddy blocks and record the CA trust list order. Do not replace
production data or volumes as part of authentication rollback.

To withdraw a newly added Inferlo issuer, the operator restores the saved
profile/CORS and recreates only the affected Gryt service using the single-service Compose command in [existing server](existing-server.md#3-review-and-recreate-only-this-server). Preserve the official issuer's position and account/local tiers.
Inferlo accounts then cannot join that server; existing official/local users
must retain their mappings. Restore Caddy's saved configuration only if the
auth endpoints are being withdrawn, and validate/reload it normally.

To stop the independent auth stack use `docker compose down` without `-v`.
Keep volumes, backups and configuration; do not prune Caddy or production Gryt
volumes. Restarting the same revision reuses the original users and CA key.

For a failed auth-stack upgrade use the saved revision/images and matching DB
backup as described in [maintenance](maintenance.md). Use restore_ca_key.sh only when recovering
the original CA volume. Verify the saved JWKS, known account sub and a prior
certificate before reopening traffic.
