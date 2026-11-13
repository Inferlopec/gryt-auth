#!/usr/bin/env bash
# Back up the actual Compose volume, including account-key records, with private permissions.
set -euo pipefail
umask 077
cd "$(dirname "$0")/.."
[ ! -f "${GRYT_ENV_FILE:-.env}" ] || . "${GRYT_ENV_FILE:-.env}"
BACKUPS="${GRYT_AUTH_BACKUP_DIR:-./backups}"
mkdir -p "$BACKUPS"
OUT="${1:-${BACKUPS}/ca-key-$(date -u +%Y%m%dT%H%M%SZ).tar.gz}"
RAW="$(mktemp)"
PART="${OUT}.part"
trap 'rm -f "$RAW" "$PART"' EXIT
docker compose run --rm -T --no-deps --entrypoint sh identity -c '
  node --input-type=module -e '\''import {createPrivateKey} from "node:crypto"; import {readFileSync} from "node:fs";
    const key = createPrivateKey(readFileSync("/app/data/ca-key.pem"));
    if (key.asymmetricKeyType !== "ec" || key.asymmetricKeyDetails.namedCurve !== "prime256v1") process.exit(1);'\''
  test "$?" = 0 || exit 1
  tar cf - -C /app/data .
' > "$RAW"
python3 scripts/validate_ca_archive.py "$RAW"
gzip -c "$RAW" > "$PART"
gzip -t "$PART"
mv "$PART" "$OUT"
echo "CA and account-key records backed up to $OUT. Copy it off-host."
