#!/usr/bin/env bash
# Exceptional recovery only: fresh backups precede Admin API realm deletion/recreation.
set -euo pipefail
umask 077
cd "$(dirname "$0")/.."
if [ "${1:-}" != --i-understand-this-deletes-all-users ]; then
  echo 'This deletes the realm and all its users. For safe initialization use scripts/initialize.sh.' >&2
  echo 'Exceptional recovery: scripts/reimport_realm.sh --i-understand-this-deletes-all-users' >&2
  exit 1
fi
[ ! -f "${GRYT_ENV_FILE:-.env}" ] || . "${GRYT_ENV_FILE:-.env}"
BACKUPS="${GRYT_AUTH_BACKUP_DIR:-./backups}"
mkdir -p "$BACKUPS"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
raw="$(mktemp)"
part="$BACKUPS/keycloak-${ts}-pre-reimport.sql.gz.part"
trap 'rm -f "$raw" "$part"' EXIT
docker compose exec -T postgres pg_dump -U "${GRYT_AUTH_POSTGRES_USER:-keycloak}" \
  -d "${GRYT_AUTH_POSTGRES_DB:-keycloak}" > "$raw"
[ "$(wc -c < "$raw")" -ge 10000 ] || { echo 'Database backup too small; aborting.' >&2; exit 1; }
gzip -c "$raw" > "$part"
gzip -t "$part"
mv "$part" "${part%.part}"
scripts/ca_key_backup.sh
docker compose run --rm --no-deps keycloak-import --replace-realm
docker compose run --rm --no-deps keycloak-client-policy
docker compose run --rm --no-deps keycloak-security-policy
docker compose run --rm --no-deps keycloak-device-grant
echo "Realm replaced. To recover previous user IDs restore ${part%.part}."
