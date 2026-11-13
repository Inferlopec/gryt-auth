#!/usr/bin/env bash
# Keycloak user management via the Admin REST API.
#
# Usage (on the server, from the project root):
#   scripts/users.sh create_user <username> <password>     # create a new user
#   scripts/users.sh reset_password <username> <password>  # change an existing user's password
#   scripts/users.sh set_user_disabled <username> true|false
#   scripts/users.sh list_users
#
# Reads credentials from the .env file in the parent directory
# (GRYT_KEYCLOAK_ADMIN_USERNAME / GRYT_KEYCLOAK_ADMIN_PASSWORD).
# Requires jq and curl on the host (both ship with Ubuntu 24.04; install
# with `apt install jq` if missing).
set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required (apt install jq)" >&2; exit 1; }

DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
[ ! -f "${GRYT_ENV_FILE:-${DIR}/.env}" ] || . "${GRYT_ENV_FILE:-${DIR}/.env}"

KC_URL="http://127.0.0.1:${GRYT_KEYCLOAK_PORT:-18080}"
REALM="${GRYT_REALM:-gryt}"
ADMIN_USER="${GRYT_KEYCLOAK_ADMIN_USERNAME:-admin}"
ADMIN_PASS="${GRYT_KEYCLOAK_ADMIN_PASSWORD:?GRYT_KEYCLOAK_ADMIN_PASSWORD not set in .env}"

cmd="${1:-help}"
case "${cmd}" in
  help)
    sed -n '3,10p' "$0"
    exit 0
    ;;
esac
shift

token=$(curl -sS -X POST "${KC_URL}/realms/master/protocol/openid-connect/token" \
  -d client_id=admin-cli -d grant_type=password \
  --data-urlencode "username=${ADMIN_USER}" \
  --data-urlencode "password=${ADMIN_PASS}" \
  | jq -r '.access_token // empty')
if [ -z "${token}" ]; then
  echo "ERROR: could not get admin token. Check .env credentials." >&2
  exit 1
fi
auth=(-H "Authorization: Bearer ${token}")

find_user() {
  # Prints the user id, or nothing if the user does not exist.
  curl -sS "${auth[@]}" --get --data-urlencode "username=${1}" --data-urlencode exact=true "${KC_URL}/admin/realms/${REALM}/users" \
    | jq -r '.[0].id // empty'
}

case "${cmd}" in
  create_user)
    username="${1:?username required}"
    password="${2:?password required}"
    case "$username" in *@*.*) ;; *) echo 'ERROR: use an email address as the username.' >&2; exit 1 ;; esac
    if [ -n "$(find_user "${username}")" ]; then
      echo "ERROR: user '${username}' already exists. Use reset_password to change its password." >&2
      exit 1
    fi
    code=$(curl -sS -o /tmp/user.out -w '%{http_code}' -X POST "${auth[@]}" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg u "${username}" '{username: $u, email: $u, enabled: true, emailVerified: false}')" \
      "${KC_URL}/admin/realms/${REALM}/users")
    [ "${code}" = "201" ] || { echo "ERROR: user creation returned ${code}"; cat /tmp/user.out; exit 1; }
    newid="$(find_user "${username}")"
    [ -n "${newid}" ] || { echo "ERROR: user created but cannot be found by username '${username}'." >&2; exit 1; }
    code=$(curl -sS -o /tmp/cred.out -w '%{http_code}' -X PUT "${auth[@]}" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg p "${password}" '{type: "password", value: $p, temporary: false}')" \
      "${KC_URL}/admin/realms/${REALM}/users/${newid}/reset-password")
    [ "${code}" = "204" ] || { echo "ERROR: password set returned ${code}"; cat /tmp/cred.out; exit 1; }
    echo "OK: user '${username}' created (id ${newid}), password set."
    echo "Login: username '${username}', realm '${REALM}'."
    ;;
  reset_password)
    username="${1:?username required}"
    password="${2:?password required}"
    id="$(find_user "${username}")"
    [ -n "${id}" ] || { echo "ERROR: user '${username}' not found. Use create_user first." >&2; exit 1; }
    code=$(curl -sS -o /tmp/cred.out -w '%{http_code}' -X PUT "${auth[@]}" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg p "${password}" '{type: "password", value: $p, temporary: false}')" \
      "${KC_URL}/admin/realms/${REALM}/users/${id}/reset-password")
    [ "${code}" = "204" ] || { echo "ERROR: reset-password returned ${code}"; cat /tmp/cred.out; exit 1; }
    echo "OK: password updated for user '${username}' (id ${id}). Active sessions for this user are invalidated."
    ;;
  set_user_disabled)
    username="${1:?username required}"
    state="${2:?true|false required}"
    case "${state}" in true|false) ;; *) echo "ERROR: state must be true or false" >&2; exit 1 ;; esac
    id="$(find_user "${username}")"
    [ -n "${id}" ] || { echo "ERROR: user '${username}' not found." >&2; exit 1; }
    code=$(curl -sS -o /tmp/dis.out -w '%{http_code}' -X PUT "${auth[@]}" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --argjson e "${state}" '{enabled: ($e | not)}')" \
      "${KC_URL}/admin/realms/${REALM}/users/${id}")
    [ "${code}" = "204" ] || { echo "ERROR: returned ${code}"; cat /tmp/dis.out; exit 1; }
    echo "OK: user '${username}' disabled=${state}."
    ;;
  list_users)
    curl -sS "${auth[@]}" "${KC_URL}/admin/realms/${REALM}/users?max=100" \
      | jq -r '.[] | [.id, .username, .enabled] | @tsv'
    ;;
  *)
    echo "Unknown command: ${cmd}" >&2
    exit 1
    ;;
esac
