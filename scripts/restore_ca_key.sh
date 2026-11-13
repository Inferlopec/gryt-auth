#!/usr/bin/env bash
# Restore only operator-selected backups. Normal startup never generates a replacement key.
set -euo pipefail
umask 077
cd "$(dirname "$0")/.."
[ ! -f "${GRYT_ENV_FILE:-.env}" ] || . "${GRYT_ENV_FILE:-.env}"
ARCHIVE="${1:?usage: scripts/restore_ca_key.sh <ca-key.tar.gz>}"
python3 scripts/validate_ca_archive.py "$ARCHIVE"
# Validate the private key cryptographically before stopping the service.
python3 scripts/validate_ca_archive.py "$ARCHIVE" --key |
  docker compose run --rm -T --no-deps --entrypoint node identity --input-type=module -e '
    import {createPrivateKey} from "node:crypto"; import {readFileSync} from "node:fs";
    const key = createPrivateKey(readFileSync(0));
    if (key.asymmetricKeyType !== "ec" || key.asymmetricKeyDetails.namedCurve !== "prime256v1") process.exit(1);'
printf 'This replaces the CA key and account-key records. Type YES to continue: '
read -r answer
[ "$answer" = YES ] || exit 1
docker compose stop identity
docker compose run --rm -T --no-deps --entrypoint sh identity -c '
  set -eu
  rm -rf /app/data/accounts
  tar xzf - -C /app/data
  chmod 600 /app/data/ca-key.pem
' < "$ARCHIVE"
docker compose up -d --no-deps --wait --wait-timeout 60 identity
echo 'CA restored. Verify its JWKS and an existing certificate before reopening traffic.'
