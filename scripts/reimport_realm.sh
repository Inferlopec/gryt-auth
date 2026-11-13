#!/usr/bin/env sh
# Authorized re-import of the realm (recovery procedure).
#
# `GRYT_IMPORT_REALM=1` is the normal one-time initialization path. This script
# is the separate, explicitly authorized procedure for re-importing a realm
# that already has users in it. It refuses to proceed unless:
#   1. you pass --i-understand-this-deletes-all-users
#   2. a verified pg dump younger than 24 h exists (it takes a fresh one)
#   3. the CA key is backed up too (it takes a fresh one)
#
# What it does, in order:
#   1. fresh pg dump + CA key backup (both verified before naming)
#   2. stops keycloak
#   3. runs the keycloak-import one-shot with GRYT_IMPORT_REALM=1
#   4. brings the stack up and re-applies the one-shot configuration
#      (security policy + device grant) that a fresh import deletes
#
# Usage: scripts/reimport_realm.sh --i-understand-this-deletes-all-users
set -eu

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${DIR}"

if [ "${1:-}" != "--i-understand-this-deletes-all-users" ]; then
  echo "This script DELETES the realm and every user in it, then re-imports" >&2
  echo "realm/gryt-realm.json (kc.sh import --override true)." >&2
  echo >&2
  echo "It is the recovery path for a broken realm, not a routine operation." >&2
  echo "If you mean to initialize a fresh stack, set GRYT_IMPORT_REALM=1 in .env" >&2
  echo "once before the first 'docker compose up'." >&2
  echo >&2
  echo "To proceed, re-run with: scripts/reimport_realm.sh --i-understand-this-deletes-all-users" >&2
  exit 1
fi

# shellcheck disable=SC1091
. ./.env

echo "[reimport] Step 1/4: fresh backups (pg + CA key)..."
ts="$(date -u +%Y%m%dT%H%M%SZ)"
docker compose exec -T postgres pg_dump -d "${GRYT_AUTH_POSTGRES_DB:-keycloak}" > "backups/.keycloak-${ts}.sql"
if [ "$(wc -c < "backups/.keycloak-${ts}.sql" | tr -d ' ')" -lt 10000 ]; then
  echo "[reimport] ERROR: pg dump is too small — the database may be empty or pg_dump failed. Aborting — nothing was touched." >&2
  rm -f "backups/.keycloak-${ts}.sql"
  exit 1
fi
gzip -c "backups/.keycloak-${ts}.sql" > "backups/keycloak-${ts}-pre-reimport.sql.gz.part"
gzip -t "backups/keycloak-${ts}-pre-reimport.sql.gz.part" || { echo "[reimport] ERROR: dump archive failed integrity check. Aborting." >&2; exit 1; }
mv "backups/keycloak-${ts}-pre-reimport.sql.gz.part" "backups/keycloak-${ts}-pre-reimport.sql.gz"
rm -f "backups/.keycloak-${ts}.sql"
scripts/ca_key_backup.sh || { echo "[reimport] ERROR: CA key backup failed. Aborting — nothing was touched." >&2; exit 1; }

echo "[reimport] Step 2/4: stopping keycloak..."
docker compose stop keycloak

echo "[reimport] Step 3/4: running the realm import (GRYT_IMPORT_REALM=1)..."
GRYT_IMPORT_REALM=1 docker compose up --no-deps keycloak-import
# The import must have completed successfully; a failed exit code stops here.
docker compose ps keycloak-import | grep -q Exited \(0\) \
  || { echo "[reimport] ERROR: the import container did not exit 0. Check: docker compose logs keycloak-import" >&2; exit 1; }

echo "[reimport] Step 4/4: starting the stack and re-applying one-shot configuration..."
docker compose up -d
# Re-apply what a fresh import deletes: security policy and the device grant.
docker compose run --rm --no-deps keycloak-security-policy
docker compose run --rm --no-deps keycloak-device-grant

echo "[reimport] Done. The realm is re-imported from realm/gryt-realm.json."
echo "[reimport] Verify: docker compose ps, then create a test user with scripts/users.sh create_user"
echo "[reimport] If anything went wrong: scripts/restore_postgres.sh <the pre-reimport dump>"