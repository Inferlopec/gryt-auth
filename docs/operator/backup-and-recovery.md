# Backup and recovery

Run commands from `/opt/inferlo-identity`. Keep a current database dump, the CA
archive and the matching program/configuration version before upgrades or
account deletion. `.env` also needs a protected backup in your password/secret
storage; never commit it to Git.

## Take a manual backup

Use your configured backup directory in place of ./backups if changed:

```bash
umask 077
mkdir -p ./backups
DB_BACKUP="./backups/keycloak-manual-$(date -u +%Y%m%dT%H%M%SZ).sql"
docker compose exec -T postgres sh -c 'exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB"' > "$DB_BACKUP"
```

Check that pg_dump exited successfully before continuing. On failure, discard
the incomplete new file and keep older backups. After a successful dump:

```bash
test -s "$DB_BACKUP"
gzip "$DB_BACKUP"
gzip -t "$DB_BACKUP.gz"
scripts/ca_key_backup.sh
scripts/jwks_snapshot.sh > ./backups/ca-jwks.sha256
```

Expected: the gzip check succeeds, the CA script reports its archive path,
and the saved fingerprint can be compared during recovery. Copy these files
off this host using the configured backup transport. Do not consider a backup
complete until a restore has been tested.

## Schedule backups

PostgreSQL contains account IDs, credentials, realm configuration and sessions.
The CA volume contains `ca-key.pem` and account-key records in `accounts/`.
Preserve both. Losing the account database or replacing the realm changes
subjects; losing the CA breaks verification after caches expire.

`pg-backup` runs every six hours by default. Set quoted `BACKUP_CRON`,
`BACKUP_RETAIN_DAYS` and `GRYT_AUTH_BACKUP_DIR` in `.env`. Dumps are only renamed
and old backups pruned after successful pg_dump, size and gzip checks. These
checks detect damaged archives; only restoration proves database recoverability.

```bash
scripts/ca_key_backup.sh
scripts/backup_offsite.sh
```

Schedule the CA backup and off-host copy as separate host cron/systemd jobs
following the DB backup (for example minute 20 and 30 every six hours). Keep
archives readable only by the backup operator. CA backups contain a private
key; encrypt them at rest and during transfer. Set quoted `BACKUP_OFFSITE_CMD`
to the chosen destination command using single quotes so `$BACKUPS` expands
when the copy runs, for example:

```dotenv
BACKUP_OFFSITE_CMD='rsync -a "$BACKUPS/" backup-host:/var/backups/inferlo-identity/'
```

`BACKUPS` is exported by the script from GRYT_AUTH_BACKUP_DIR. Copy both DB and CA archives. Off-site transport is intentionally
operator-supplied; no external destination has been selected or tested.

## Restore accounts and the CA

For a restore, restrict public traffic first and use the same Compose file(s),
project and PostgreSQL major version as the backed-up installation:

```bash
scripts/restore_postgres.sh backups/keycloak-TIMESTAMP.sql.gz
scripts/restore_ca_key.sh backups/ca-key-TIMESTAMP.tar.gz
scripts/jwks_snapshot.sh
```

Both restoration commands require typing YES. Replace TIMESTAMP with the actual
archive names; the commands replace current state with the selected backup. The DB script validates/decompresses
the dump before stopping Keycloak, connects to the maintenance database to
recreate the target, restores transactionally, then waits for Keycloak health.
A failed restore leaves Keycloak stopped for investigation. Do not restart it
against a partial database.

CA restoration rejects traversal, links, duplicate/unrelated archive members
and invalid private keys before stopping Identity Service. It replaces CA and
account-key records on the actual Compose volume, then waits for service
health. Compare saved JWKS and cryptographically verify a certificate issued
before the backup. Keep any pre-restore backups until this check passes.
Custom CA paths must remain inside the backed-up data volume at the standard
`/app/data/ca-key.pem`; otherwise provide dedicated backup tooling first.

## Exceptional realm replacement (destructive)

`scripts/reimport_realm.sh --i-understand-this-deletes-all-users` takes fresh
DB and CA backups before deleting/recreating the realm through the Admin API.
This is destructive recovery, not an upgrade, SMTP change or initialization.
Restore the database backup if user IDs must be preserved.

## CA rotation or loss

Planned rotation needs overlapping JWKS for old certificates until expiry and
cache refresh, then coordinated retirement. Current upstream publishes a
single CA key; rolling rotation tooling is not implemented. Do not simply
replace ca-key.pem on a live deployment.

On loss, restore the original key from a protected off-host backup. Without
it, retain the Keycloak database to preserve account subjects, provision a new
CA only through an explicit incident procedure, and have clients obtain new
certificates. Previously issued certificates cannot be recovered by creating
a new private key. Document the trust/cache disruption before proceeding.
