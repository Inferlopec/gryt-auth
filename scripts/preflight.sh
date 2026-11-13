#!/usr/bin/env bash
# Preflight validation before 'docker compose up'.
#
# Run it from the project root: scripts/preflight.sh
# It fails (exit 1) on any hard problem and prints a summary. Warnings do not
# block startup.
set -uo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${DIR}"
fails=0
warns=0
fail() { echo "  FAIL: $*"; fails=$((fails + 1)); }
warn() { echo "  WARN: $*"; warns=$((warns + 1)); }
ok()   { echo "  ok:   $*"; }

echo "== .env =="
if [ ! -f .env ]; then
  fail ".env not found. Copy .env.example to .env and fill in the secrets."
else
  ok ".env present"
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

echo "== Secrets =="
for v in GRYT_KEYCLOAK_ADMIN_PASSWORD GRYT_AUTH_POSTGRES_PASSWORD; do
  val="${!v:-}"
  if [ -z "${val}" ]; then
    fail "${v} is empty"
  elif [ "${val}" = "change_me" ] || [ "${val}" = "admin" ]; then
    fail "${v} is still an example value"
  else
    ok "${v} is set"
  fi
done

echo "== Realm import state =="
case "${GRYT_IMPORT_REALM:-0}" in
  0) ok "GRYT_IMPORT_REALM=0 (normal post-initialization state)" ;;
  1) fail "GRYT_IMPORT_REALM=1 is retired. Set 0 and use scripts/initialize.sh (safe for existing accounts)." ;;
  *) fail "GRYT_IMPORT_REALM must be 0 or 1, got '${GRYT_IMPORT_REALM}'" ;;
esac

echo "== Pairing extension jar =="
JAR="keycloak-pairing/dist/gryt-pairing.jar"
if [ -f "${JAR}" ] && [ -s "${JAR}" ]; then
  ok "${JAR} present ($(du -h "${JAR}" | cut -f1))"
elif [ -d "${JAR}" ]; then
  fail "${JAR} is a directory (a missing bind-mount target). Remove it and run keycloak-pairing/build.sh — Keycloak will not start with it missing."
else
  fail "${JAR} missing. Run keycloak-pairing/build.sh (needs Docker). Keycloak will not start until it exists."
fi

echo "== Keycloak version coupling =="
if command -v node >/dev/null 2>&1; then
  if node scripts/check-keycloak-version.mjs >/dev/null 2>&1; then
    ok "pom.xml and compose image tags agree"
  else
    fail "keycloak-pairing/pom.xml <keycloak.version> does not match the Keycloak image tag in docker-compose.yml"
  fi
else
  pom="$(sed -n 's|.*<keycloak\.version>\([^<]*\)</keycloak\.version>.*|\1|p' keycloak-pairing/pom.xml | head -1)"
  imgs="$(grep -o 'quay\.io/keycloak/keycloak:[^" ]*' docker-compose.yml | sort -u | sed 's|@.*||;s|.*:||')"
  if [ -n "${pom}" ] && [ "${imgs}" = "${pom}" ]; then
    ok "pom.xml and compose image tags agree (${pom})"
  else
    fail "keycloak version mismatch: pom=${pom:-?} compose=${imgs:-?}"
  fi
fi

echo "== Realm file =="
if grep -q '"realm": *"gryt"' realm/gryt-realm.json 2>/dev/null; then
  ok "realm id is gryt"
else
  fail "realm/gryt-realm.json realm id is not 'gryt' — the issuer in .env would not match"
fi
if grep -q '"oauth2.device.authorization.grant.enabled": *"true"' realm/gryt-realm.json; then
  ok "device grant attributes present in the realm file"
else
  warn "device grant attributes missing from realm file (the keycloak-device-grant one-shot still applies them)"
fi
if grep -q '__GRYT_SMTP_' realm/gryt-realm.json; then
  if [ -n "${GRYT_SMTP_HOST:-}" ] && [ -n "${GRYT_SMTP_FROM:-}" ]; then
    ok "SMTP settings available for explicit initialization / keycloak-smtp job"
  else
    warn "SMTP is not configured — configure SMTP with the keycloak-smtp job; never replace a realm to change mail settings"
  fi
fi

echo "== Compose validation =="
if GRYT_KEYCLOAK_ADMIN_PASSWORD="${GRYT_KEYCLOAK_ADMIN_PASSWORD:-x}" GRYT_AUTH_POSTGRES_PASSWORD="${GRYT_AUTH_POSTGRES_PASSWORD:-y}" \
   docker compose config --quiet >/dev/null 2>&1; then
  ok "docker compose config passes"
else
  fail "docker compose config failed — run 'docker compose config' to see why"
fi

echo "== Public endpoints (informational, not blocking) =="
for u in "${GRYT_OIDC_ISSUER:-}" "${GRYT_IDENTITY_ORIGIN:-}"; do
  [ -n "${u}" ] || continue
  if curl -fsS -o /dev/null --max-time 5 "${u%/}/.well-known/jwks.json" 2>/dev/null \
     || curl -fsS -o /dev/null --max-time 5 "${u}/.well-known/openid-configuration" 2>/dev/null; then
    ok "reachable: ${u}"
  else
    warn "not reachable yet (expected before first deployment / before DNS exists): ${u}"
  fi
done

echo
echo "preflight: ${fails} failure(s), ${warns} warning(s)"
[ "${fails}" -eq 0 ] || exit 1