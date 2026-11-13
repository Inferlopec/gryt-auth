#!/usr/bin/env bash
# Restore the Keycloak database from a verified pg dump.
#
# This is the account-recovery path after an accidental realm re-import or a
# lost database. It preserves user IDs (they come back exactly as they were
# in the dump), so the certificates already issued stay valid as long as the
# CA key is also restored (see restore_ca_key.sh).
#
# What it does, in order:
#   1. verifies the dump (gzip integrity + size floor)
#   2. stops keycloak (it must not hold the database open)
#   3. drops and recreates the database, restores the dump
#   4. starts keycloak, waits for it to become healthy
#
# Usage: scripts/restore_postgres.sh backups/keycloak-<timestamp>.sql.gz
# Ask for confirmation first: type YES when prompted.
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${DIR}"
# shellcheck disable=SC1091
[ ! -f "${GRYT_ENV_FILE:-.env}" ] || . "${GRYT_ENV_FILE:-.env}"

DUMP="${1:?usage: restore_postgres.sh <path-to-keycloak-dump.sql.gz>}"
DB="${GRYT_AUTH_POSTGRES_DB:-keycloak}"
PGUSER="${GRYT_AUTH_POSTGRES_USER:-keycloak}"

if [ ! -f "${DUMP}" ]; then
  echo "ERROR: ${DUMP} not found." >&2
  exit 1
fi
if ! gzip -t "${DUMP}"; then
  echo "ERROR: ${DUMP} does not decompress. Do not restore from it." >&2
  exit 1
fi
RAW="$(mktemp)"
trap 'rm -f "${RAW}"' EXIT
umask 077
gunzip -c "${DUMP}" > "${RAW}"
size="$(wc -c < "${RAW}" | tr -d ' ')"
if [ "${size}" -lt 10000 ]; then
  echo "ERROR: ${DUMP} decompresses to only ${size} bytes — it looks truncated." >&2
  exit 1
fi

printf 'This will DELETE the current Keycloak database "%s" and restore it from %s.\n' "${DB}" "${DUMP}"
printf 'Every account currently in the realm is replaced by the accounts in the dump.\n'
printf 'Type YES to continue: '
read -r ANSWER
[ "${ANSWER}" = "YES" ] || { echo "Aborted."; exit 1; }

echo "[restore] Stopping keycloak..."
docker compose stop keycloak

echo "[restore] Restoring ${DB} from ${DUMP} (verified, ${size} bytes)..."
docker compose exec -T -e PGUSER="${PGUSER}" postgres \
  dropdb --maintenance-db=postgres --if-exists --force -- "${DB}"
docker compose exec -T -e PGUSER="${PGUSER}" postgres \
  createdb --maintenance-db=postgres --owner="${PGUSER}" -- "${DB}"
docker compose exec -T -e PGUSER="${PGUSER}" postgres \
  psql -q --dbname="${DB}" -v ON_ERROR_STOP=1 --single-transaction < "${RAW}"

echo "[restore] Starting keycloak..."
docker compose up -d --no-deps --wait --wait-timeout 300 keycloak
echo "[restore] Complete. Verify a known user and the CA JWKS before reopening traffic."
