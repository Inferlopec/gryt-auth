#!/usr/bin/env sh
# Off-host backup copy (disaster recovery layer).
#
# The pg-backup container verifies each dump (pg_dump exit code, size floor,
# gzip integrity) before naming it. This script copies the newest verified
# files to the off-host destination. Backups on the same VM as the stack are
# NOT sufficient disaster recovery: a disk or host failure takes both away.
#
# The destination is not selected yet (spec section 10): it must stay
# configurable. Set BACKUP_OFFSITE_CMD in .env to a single command that copies
# ./backups/keycloak-*.sql.gz and ./backups/ca-key-*.tar.gz to the destination,
# e.g.
#   BACKUP_OFFSITE_CMD='rsync -a "$BACKUPS/" backup-host:/var/backups/inferlo-identity/'
# or an rclone/rclone-crypt command for a bucket.
#
# Schedule it (example, cron on the stack host):
#   30 */6 * * * cd /opt/inferlo-identity && scripts/backup_offsite.sh >> /var/log/inferlo-backup-offsite.log 2>&1
#
# Run it manually any time; it is idempotent (copies whatever is newest).
set -eu

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${DIR}"
BACKUPS="${GRYT_AUTH_BACKUP_DIR:-${DIR}/backups}"

# shellcheck disable=SC1091
if [ -f "${DIR}/.env" ]; then
  set -a
  . "${DIR}/.env"
  set +a
fi

BACKUPS="${GRYT_AUTH_BACKUP_DIR:-${DIR}/backups}"
export BACKUPS
CMD="${BACKUP_OFFSITE_CMD:-}"
if [ -z "${CMD}" ]; then
  echo "[backup-offsite] BACKUP_OFFSITE_CMD is not set in .env — skipping."
  echo "[backup-offsite] Set it to a command that copies ${BACKUPS} to an off-host destination."
  exit 0
fi

newest_dump="$(ls -1t "${BACKUPS}"/keycloak-*.sql.gz 2>/dev/null | head -1 || true)"
newest_ca="$(ls -1t "${BACKUPS}"/ca-key-*.tar.gz 2>/dev/null | head -1 || true)"
if [ -z "${newest_dump}" ]; then
  echo "[backup-offsite] ERROR: no keycloak-*.sql.gz found in ${BACKUPS}. Did pg-backup run?" >&2
  exit 1
fi
if [ -z "${newest_ca}" ]; then
  echo "[backup-offsite] ERROR: no ca-key-*.tar.gz in ${BACKUPS}. Run scripts/ca_key_backup.sh first." >&2
  exit 1
fi

echo "[backup-offsite] Copying $(basename "${newest_dump}")$( [ -n "${newest_ca}" ] && echo " and $(basename "${newest_ca}")" )"
# The command is operator-supplied; it must exit non-zero on failure.
eval "${CMD}"
echo "[backup-offsite] Done."
