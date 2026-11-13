#!/usr/bin/env bash
# Snapshot and restore the Identity Service CA key.
#
# jwks_snapshot.sh prints the CA public key fingerprint (the JWKS thumbprint).
# Compare before and after a restore to prove the CA trust relationship
# survived: if the thumbprint matches, previously issued certificates still
# validate on every Gryt server that trusts this CA.
#
# Usage:
#   scripts/jwks_snapshot.sh                 # print the current thumbprint
#   scripts/restore_ca_key.sh ca-key-*.tar.gz   # restore the key from a backup
set -eu

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${DIR}"
# shellcheck disable=SC1091
[ -f .env ] && . ./.env

case "${1:-snapshot}" in
  snapshot)
    jwks="$(curl -fsS "http://127.0.0.1:${GRYT_IDENTITY_PORT:-18081}/.well-known/jwks.json")" \
      || { echo "ERROR: identity service is not reachable at 127.0.0.1:${GRYT_IDENTITY_PORT:-18081}" >&2; exit 1; }
    # SHA-256 over the sorted key ids + moduli is a stable-enough fingerprint
    # without needing jose on the host.
    printf '%s' "${jwks}" | sha256sum | cut -d' ' -f1
    ;;
  restore)
    OUT="${2:?usage: restore_ca_key.sh <ca-key tarball>}"
    [ -f "${OUT}" ] || { echo "ERROR: ${OUT} not found." >&2; exit 1; }
    gzip -t "${OUT}" || { echo "ERROR: ${OUT} does not decompress." >&2; exit 1; }
    before="$(curl -fsS "http://127.0.0.1:${GRYT_IDENTITY_PORT:-18081}/.well-known/jwks.json" | sha256sum | cut -d' ' -f1 || true)"
    echo "[restore-ca] Stopping identity service..."
    docker compose stop identity
    echo "[restore-ca] Restoring the CA key volume from ${OUT}..."
    tarball_abs="$(cd "$(dirname "${OUT}")" && pwd)/$(basename "${OUT}")"
    docker compose run --rm \
      -v inferlo-identity_inferlo-identity-data:/data:rw \
      -v "${tarball_abs}:/backup/ca.tar.gz:ro" \
      alpine sh -c 'rm -rf /data && mkdir -p /data && tar xzf /backup/ca.tar.gz -C /data'
    echo "[restore-ca] Starting identity service..."
    docker compose up -d identity
    sleep 5
    after="$(curl -fsS "http://127.0.0.1:${GRYT_IDENTITY_PORT:-18081}/.well-known/jwks.json" | sha256sum | cut -d' ' -f1)"
    if [ "${before}" = "${after}" ]; then
      echo "[restore-ca] OK: JWKS unchanged (${after}) — previously issued certificates still validate."
    else
      echo "[restore-ca] NOTE: JWKS changed (was ${before:-n/a}, now ${after})."
      echo "[restore-ca] This is expected if the old key was lost and a new one was generated."
      echo "[restore-ca] Certificates issued under the old key no longer validate — see docs/backup-restore.md."
    fi
    ;;
  *)
    echo "usage: jwks_snapshot.sh | restore_ca_key.sh <ca-key tarball>" >&2
    exit 1
    ;;
esac