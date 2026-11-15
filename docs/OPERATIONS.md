# Operations

Run Identity commands from `/opt/inferlo-identity` with the original Compose
project/files, `.env` and volumes. Settings are defined in
[.env.example](../.env.example); live realm changes are described in
[SETUP](SETUP.md#live-realm-configuration). Restrict access to logs, dumps and
rendered Compose output: they can contain secrets or personal data.

## Accounts

Open the configured Keycloak host's `/admin`, select **gryt**, then **Users**.
Use the console for routine account creation, credentials, enable/disable and
deletion. The master realm holds administrators, not Gryt accounts. Do not
mark an email verified without verification. Registration stays closed.

The CLI uses the admin password grant; MFA-compatible automation is unresolved.
Do not disable administrator MFA to accommodate scripts. Current CLI commands:

```bash
read -r -s -p 'Account password: ' ACCOUNT_PASSWORD
scripts/users.sh create_user alice@example.com "$ACCOUNT_PASSWORD"
# For an existing account instead:
# scripts/users.sh reset_password alice@example.com "$ACCOUNT_PASSWORD"
unset ACCOUNT_PASSWORD
scripts/users.sh list_users
scripts/users.sh set_user_disabled alice@example.com true
# Re-enable when intended:
# scripts/users.sh set_user_disabled alice@example.com false
```

Use an email username and a password satisfying the realm policy. CLI passwords
remain visible in process arguments despite avoiding shell-history literals.
Creation leaves email unverified; missing profile fields may be requested at
login. If password assignment fails after creation, reset the existing account's
password rather than creating it again. Listing returns at most 100 users;
use console pagination for more. There is no CLI delete command.

Before console deletion, verify the exact email/ID and back up the database.
Recreating the same email produces a new subject and does not restore ownership.
Use database recovery to recover the original subject when appropriate.

**Disable, delete and password reset do not immediately revoke old access tokens
or Gryt certificates.** There is no centralized certificate revocation;
certificates remain usable until expiry, including server clock tolerance.
Use bans on each affected server for immediate exclusion. Central account
operations do not remove server memberships, roles or chat history.

## Service lifecycle and updates

```bash
docker compose ps
docker compose logs --tail 100 keycloak identity postgres pg-backup
docker compose up -d --wait
# Process restart only; does not apply changed environment:
docker compose restart identity
# Stop while preserving accounts and CA:
docker compose down
```

Expect healthy DB/Keycloak/Identity and running pg-backup. Normal startup does
not import realms or provision CA keys. Never use `down -v`, volume pruning or
CA deletion for routine maintenance. While Identity is offline, existing
certificates may still work; login, renewal and pairing are unavailable.

For source updates, review the exact revision/diff and applicable upgrade notes.
Record current source/image IDs, a known user's subject and JWKS fingerprint;
take [backups](#backups-and-recovery) and retain the matching `.env` and images.
Restrict traffic and stop Identity services during schema-changing upgrades.
Preserve Keycloak/provider version coupling and local patches:

```bash
keycloak-pairing/build.sh
docker compose build identity
# Recreate Keycloak after replacing the bind-mounted JAR:
docker compose up -d --no-deps --force-recreate --wait keycloak
docker compose up -d --wait
```

A restart alone may keep the old JAR inode. Run only required, reviewed policy
jobs; never replace a realm as an upgrade step. Existing realms need
`keycloak-client-policy` before an upgrade requiring the audience mapper.
Verify HTTPS, a known user's login, prior certificate trust and device approval
before reopening traffic. These commands do not update Gryt/shared services.
Downgrading Keycloak after a schema migration can require the matching old DB
backup, not just the old image.

To preview or apply the supported built-in realm themes on an existing realm,
use the explicit [`keycloak-themes` job](SETUP.md#login-account-and-email-themes).
The job changes only login/account/email theme selections; capture their current
values with `--dry-run` for rollback. Verify login, error and account pages at
desktop and mobile sizes, plus rendered email content, before treating the
visual change as accepted.

## Backups and recovery

Protect the PostgreSQL database, CA key **and** `accounts/` records, `.env`,
program/configuration revision and matching images. DB loss/realm replacement
can change subjects; CA loss breaks existing certificate verification. Keep
copies off-host, encrypted at rest/in transit; a same-host archive is not
disaster recovery. Test restoration, not just archive integrity.

### Create backups

Use the configured backup directory if different from this example:

```bash
umask 077
mkdir -p ./backups
DB_BACKUP="./backups/keycloak-manual-$(date -u +%Y%m%dT%H%M%SZ).sql"
if docker compose exec -T postgres sh -c 'exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB"' > "$DB_BACKUP"; then
    test -s "$DB_BACKUP" && gzip "$DB_BACKUP" && gzip -t "$DB_BACKUP.gz"
else
    printf 'Dump failed; discard this incomplete file and retain older backups.\n' >&2
fi
scripts/ca_key_backup.sh
scripts/jwks_snapshot.sh > ./backups/ca-jwks.sha256
```

Check every result before copying. The CA script validates the key and archives
the actual Compose data volume. It writes only validated archives. Keep custom
CA storage at `/app/data/ca-key.pem` for these tools; other paths need dedicated
backup/restore tooling.

`pg-backup` uses the schedule/retention/directory in `.env.example`, checks
pg_dump exit status, minimum size and gzip integrity, and only then publishes
the dump and prunes older ones. It does not schedule CA or off-host copies.
Schedule those separately after successful DB backup:

```bash
scripts/ca_key_backup.sh
scripts/backup_offsite.sh
```

Configure the operator-supplied off-site command in `.env` to copy DB and CA
archives; the script exports `BACKUPS` as the chosen directory. Use single
quotes around the command so `$BACKUPS` expands at execution. An unset command
prints a skip message and exits successfully: that is **not** a completed
transfer. No transport/destination is configured or verified by the repository.

### Restore

Restrict public traffic first. Retain current backups and use the matching
program/configuration, Compose project/files and PostgreSQL major version.
Replace TIMESTAMP with actual backup names:

```bash
scripts/restore_postgres.sh backups/keycloak-TIMESTAMP.sql.gz
scripts/restore_ca_key.sh backups/ca-key-TIMESTAMP.tar.gz
scripts/jwks_snapshot.sh
```

Each restore requires typing `YES` and replaces current state with that backup.
Restore the CA only when its state needs recovery. The DB script validates and
decompresses before stopping Keycloak, recreates the DB via the maintenance
DB, restores transactionally and waits for health. Failure leaves Keycloak
stopped; do not start it against a partial database.

CA restoration rejects traversal, links, duplicate/unrelated members and
invalid keys before stopping Identity; it replaces CA/account-key state and
waits for health. Compare the saved JWKS fingerprint, verify a known account's
subject/login and cryptographically verify a certificate issued before backup.
Retain pre-restore backups until those checks pass.

### Exceptional realm replacement and CA loss

`scripts/reimport_realm.sh --i-understand-this-deletes-all-users` takes DB/CA
backups, then deletes/recreates the realm. Use only for an explicitly intended
reset, never startup, updates, SMTP or allowlist changes. Restore the database
to recover previous subjects.

Restore a lost CA from its original protected backup. Creating another key
cannot recover old certificates. If no backup exists, preserve Keycloak's DB
and plan an explicit incident migration, client certificate renewal and
trust/cache disruption. Current JWKS publishes one key; overlapping-key
rotation tooling is absent. Do not replace a live CA key as routine rotation.

## Troubleshooting

Start with `docker compose ps` and the service logs above. Redact tokens,
authorization codes, passwords and keys before sharing diagnostics.

| Symptom | Check / action |
|---|---|
| Missing pairing JAR | Run `keycloak-pairing/build.sh`, then preflight. It handles an empty bind-mount directory; investigate a nonempty one before deleting anything. |
| Keycloak unhealthy/restarting | Check DB credentials, JAR/version, memory and `docker inspect inferlo-identity-keycloak --format '{{.State.OOMKilled}}'`. Editing the DB password in `.env` does not rotate it in PostgreSQL. |
| Caddy 502 | Run [local endpoint checks](SETUP.md#initialize-and-check-local-endpoints); confirm upstream ports and host networking. A bridge Caddy's loopback points at itself. |
| Wrong discovery issuer/redirect | Check public hostname, realm and [proxy trust](SETUP.md#dns-caddy-and-proxy-trust). Do not disable hostname checks or trust every peer. |
| Invalid token / no applicable JWKS key | Check both client auth endpoints and token issuer/audience locally; do not send tokens to public decoders. For an older realm run `docker compose run --rm --no-deps keycloak-client-policy`, then obtain a new token. |
| Desktop callback rejected / token blocked by CORS | Check actual redirect URI and Origin against [allowlists](SETUP.md#callback-and-origin-allowlists); OPTIONS success alone does not prove token-response CORS. |
| Desktop browser login never completes | Check the selected release's callback and OS handler; see [Desktop limitations](SETUP.md#desktop-and-web-clients). An arbitrary SPA route is not a callback bridge. |
| Login page appears unstyled | Run `scripts/preflight.sh --deployed` for endpoint/configuration checks, then confirm the realm's selected theme and reload without a stale browser cache. Endpoint success does not prove CSS assets render in the graphical client. |
| Account cannot join | Check server trust order, version, invitation/membership and bans. Stop rollout and [roll back](#rollback) if existing users lose roles. |
| Verification/reset email absent | Check the independent email policy switches and [SMTP setup](SETUP.md#smtp-and-email-policy). Apply `keycloak-smtp` for mail configuration, verify delivery, then apply `keycloak-email-policy` as needed; check STARTTLS, sender restrictions and provider logs/spam. Never reimport. |
| CA load refused | Check persistent mount/permissions and restore the original key. Do not enable generation or remove its volume to bypass the error. |
| All devices share pairing rate limit | Confirm Caddy overwrites `CF-Connecting-IP` and Identity trusts the observed proxy socket source; retain rate limits. |

## Rollback

Restore the saved server `profile.json`, `.env`, CORS settings and original
issuer order. Recreate **only** that server with the image-checked command in
[server integration](SETUP.md#connect-an-existing-gryt-server). Withdrawing
Inferlo trust prevents its accounts joining; verify official/local identities
retain their mappings. Do not replace server databases or volumes.

If withdrawing auth endpoints, restore the saved Caddy configuration and
validate/reload. Stop Identity with `docker compose down` without `-v`; retain
configuration, CA and account data. For a failed upgrade, use the saved
revision/images and matching DB backup. Restore the original CA only if needed.
Verify subject, JWKS and a prior certificate before reopening traffic.

## Production readiness

The repository supports source-based isolated testing. It does not establish
production readiness. [Recorded test evidence](DEVELOPMENT.md#recorded-test-evidence)
is distinct from owner-reported staging results and the checks below.

Current baseline: digest-pinned auth images/bases, resource limits, non-root
Identity, private DB, closed registration, password/brute-force policies and
validated backup archives. Login lockouts do not protect public registration.
Before public use, establish evidence for each gate:

- [ ] Capacity for existing Gryt plus Keycloak, DB, builds and backup retention.
- [ ] Exact installed Gryt revision isolates issuers; old users retain rights.
- [ ] Public DNS/TLS, proxy peers and firewall exposure verified; DB/management private.
- [ ] Permanent administrator MFA/access policy and compatible automation tested;
      replace temporary bootstrap credentials. Do not expose routine admin access
      before this policy works.
- [ ] Custom browser flow enforces required OTP. An OTP setup action or passkey
      registration is not proof of enforcement.
- [ ] Real Web/Desktop login, restart, device-secret transfer and multi-server checks,
      including graphical regression of the callback/CORS fixes with an updated
      Desktop release that handles `gryt://auth/callback`.
- [ ] SMTP verification and recovery mail delivered.
- [ ] Encrypted off-host backups and an independent fresh-host restore exercised.
- [ ] Certificate issuance edge rate limit selected and tested; no separate
      application issuance limiter exists. Keep registration closed.

Open work and acceptance evidence belong in
[GitHub Issues](https://github.com/Inferlopec/gryt-auth/issues), not a second local
issue register. A successful protocol suite does not close these gates.
