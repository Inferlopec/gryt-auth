#!/usr/bin/env bash
# Keycloak user management via the Admin REST API.
# Usage (on the server, from /opt/inferlo-identity):
#   scripts/users.sh create_user <username> <password>   # create user, or reset password if it exists
#   scripts/users.sh set_user_disabled <username> true|false
#   scripts/users.sh list_users
#
# Reads credentials from the .env file in the parent directory
# (GRYT_KEYCLOAK_ADMIN_USERNAME / GRYT_KEYCLOAK_ADMIN_PASSWORD).
set -eu

DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "${DIR}/.env"

KC_URL="http://127.0.0.1:${GRYT_KEYCLOAK_PORT:-18080}"
REALM="${GRYT_REALM:-inferlo}"
ADMIN_USER="${GRYT_KEYCLOAK_ADMIN_USERNAME:-admin}"
ADMIN_PASS="${GRYT_KEYCLOAK_ADMIN_PASSWORD:?GRYT_KEYCLOAK_ADMIN_PASSWORD not set in .env}"

cmd="${1:-help}"
case "${cmd}" in
  help)
    sed -n '2,9p' "$0"
    exit 0
    ;;
esac
shift

token=$(curl -sS -X POST "${KC_URL}/realms/master/protocol/openid-connect/token" \
  -d client_id=admin-cli -d grant_type=password \
  --data-urlencode "username=${ADMIN_USER}" \
  --data-urlencode "password=${ADMIN_PASS}" \
  | sed -n 's/.*"access_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
if [ -z "${token}" ]; then
  echo "ERROR: could not get admin token. Check .env credentials." >&2
  exit 1
fi
auth=(-H "Authorization: Bearer ${token}")

case "${cmd}" in
  create_user)
    username="${1:?username required}"
    password="${2:?password required}"
    # If the user exists — reset the password; otherwise create the user.
    existing=$(curl -sS "${auth[@]}" "${KC_URL}/admin/realms/${REALM}/users?username=${username}&exact=true")
    id=$(printf '%s' "${existing}" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    if [ -n "${id}" ]; then
      code=$(curl -sS -o /tmp/cred.out -w '%{http_code}' -X PUT "${auth[@]}" \
        -H "Content-Type: application/json" \
        -d "{\"type\":\"password\",\"value\":\"${password}\",\"temporary\":false}" \
        "${KC_URL}/admin/realms/${REALM}/users/${id}/reset-password")
      [ "${code}" = "204" ] || { echo "ERROR: reset-password returned ${code}"; cat /tmp/cred.out; exit 1; }
      echo "OK: password updated for existing user '${username}' (id ${id})."
    else
      code=$(curl -sS -o /tmp/user.out -w '%{http_code}' -X POST "${auth[@]}" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${username}\",\"enabled\":true,\"emailVerified\":true}" \
        "${KC_URL}/admin/realms/${REALM}/users")
      [ "${code}" = "201" ] || { echo "ERROR: user creation returned ${code}"; cat /tmp/user.out; exit 1; }
      newid=$(curl -sS "${auth[@]}" "${KC_URL}/admin/realms/${REALM}/users?username=${username}&exact=true" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
      code=$(curl -sS -o /tmp/cred.out -w '%{http_code}' -X PUT "${auth[@]}" \
        -H "Content-Type: application/json" \
        -d "{\"type\":\"password\",\"value\":\"${password}\",\"temporary\":false}" \
        "${KC_URL}/admin/realms/${REALM}/users/${newid}/reset-password")
      [ "${code}" = "204" ] || { echo "ERROR: password set returned ${code}"; cat /tmp/cred.out; exit 1; }
      echo "OK: user '${username}' created (id ${newid}), password set."
    fi
    echo "Login: username '${username}', realm '${REALM}'."
    ;;
  set_user_disabled)
    username="${1:?username required}"
    state="${2:?true|false required}"
    id=$(curl -sS "${auth[@]}" "${KC_URL}/admin/realms/${REALM}/users?username=${username}&exact=true" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    [ -n "${id}" ] || { echo "ERROR: user '${username}' not found."; exit 1; }
    code=$(curl -sS -o /tmp/dis.out -w '%{http_code}' -X PUT "${auth[@]}" \
      -H "Content-Type: application/json" \
      -d "{\"enabled\":${state}}" \
      "${KC_URL}/admin/realms/${REALM}/users/${id}")
    [ "${code}" = "204" ] || { echo "ERROR: returned ${code}"; cat /tmp/dis.out; exit 1; }
    echo "OK: user '${username}' enabled=${state}."
    ;;
  list_users)
    curl -sS "${auth[@]}" "${KC_URL}/admin/realms/${REALM}/users?max=100" \
      | sed -n 's/.*"username"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
    ;;
  *)
    echo "Unknown command: ${cmd}" >&2
    exit 1
    ;;
esac
