#!/usr/bin/env bash
# One-shot: import the inferlo realm into Keycloak (kc.sh import --override true).
# Runs ONLY when GRYT_IMPORT_REALM=1 and only while keycloak is NOT running.
set -euo pipefail

if [[ "${GRYT_IMPORT_REALM:-0}" != "1" ]]; then
  echo "[keycloak-import] GRYT_IMPORT_REALM!=1, skipping realm import."
  exit 0
fi

# Refuse to import into a database a running Keycloak is holding open:
# --override true deletes the realm and every user in it.
if (exec 3<>/dev/tcp/keycloak/8080) 2>/dev/null; then
  echo "[keycloak-import] ERROR: Keycloak is running. Refusing to import." >&2
  echo "[keycloak-import] Stop it first:" >&2
  echo "[keycloak-import]   docker compose stop keycloak && docker compose up -d" >&2
  exit 1
fi

echo "[keycloak-import] WARNING: SMTP is not configured. Password reset and"
echo "[keycloak-import] email verification will not work until SMTP is added."
echo "[keycloak-import] Admins create users with scripts/create_user.sh."

tmp="/tmp/inferlo-import"
rm -rf "${tmp}"
mkdir -p "${tmp}"
cp -a /opt/keycloak/data/import-src/. "${tmp}/"

# Realm file is inferlo-realm.json (already adapted, no SMTP placeholders)
exec /opt/keycloak/bin/kc.sh import --dir "${tmp}" --override true
