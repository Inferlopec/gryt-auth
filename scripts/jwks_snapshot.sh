#!/usr/bin/env bash
# Fingerprint public JWKS for before/after recovery comparisons.
set -euo pipefail
cd "$(dirname "$0")/.."
[ ! -f "${GRYT_ENV_FILE:-.env}" ] || . "${GRYT_ENV_FILE:-.env}"
if [ "${1:-}" = restore ]; then exec scripts/restore_ca_key.sh "${2:?archive required}"; fi
curl -fsS "http://127.0.0.1:${GRYT_IDENTITY_PORT:-18081}/.well-known/jwks.json" |
  python3 -c 'import json,hashlib,sys; d=json.load(sys.stdin); print(hashlib.sha256(json.dumps(d,sort_keys=True,separators=(",",":")).encode()).hexdigest())'
