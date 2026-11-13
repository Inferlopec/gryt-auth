#!/usr/bin/env sh
# Back up the Identity Service CA private key.
#
# The key lives in the named volume inferlo-identity-data (mounted at
# /app/data in the identity container). Losing it invalidates every
# previously issued certificate (see docs/backup-restore.md, "CA key loss").
# The dump is verified (size floor + gzip integrity) before it is named,
# so a half-written file is never mistaken for a backup.
#
# Usage: scripts/ca_key_backup.sh [output-file]
# Default output: backups/ca-key-<timestamp>.tar.gz
# Schedule it next to the pg backup, e.g. in cron:
#   35 */6 * * * cd /opt/inferlo-identity && scripts/ca_key_backup.sh
set -eu

DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKUPS="${DIR}/backups"
mkdir -p "${BACKUPS}"

OUT="${1:-${BACKUPS}/ca-key-$(date -u +%Y%m%dT%H%M%SZ).tar.gz}"
RAW="${OUT}.raw"
PART="${OUT}.part"
trap 'rm -f "${RAW}" "${PART}"' EXIT

echo "[ca-key-backup] $(date -u +%FT%TZ) Creating ${OUT}"
# Extract the volume into a tarball. The volume holds the CA key (and the
# account-key-gate records); it is small, a few kilobytes.
if ! docker run --rm -v inferlo-identity_inferlo-identity-data:/data:ro alpine tar cf - -C /data . > "${RAW}"; then
  echo "[ca-key-backup] FAILED: volume extraction failed. Existing backups left alone." >&2
  exit 1
fi
size="$(wc -c < "${RAW}" | tr -d ' ')"
if [ "${size}" -lt 100 ]; then
  echo "[ca-key-backup] FAILED: archive is ${size} bytes — the volume looks empty. Existing backups left alone." >&2
  exit 1
fi
gzip -c "${RAW}" > "${PART}"
if ! gzip -t "${PART}"; then
  echo "[ca-key-backup] FAILED: the archive does not decompress. Existing backups left alone." >&2
  exit 1
fi
mv "${PART}" "${OUT}"
echo "[ca-key-backup] Done ($(du -h "${OUT}" | cut -f1), from ${size} bytes)"
echo "[ca-key-backup] Store it OFF the host: see scripts/backup_offsite.sh / BACKUP_OFFSITE_CMD."