#!/usr/bin/env bash
# One-shot: гарантирует существование master admin.
# kc.sh import создаёт master realm как side effect, поэтому KC_BOOTSTRAP_ADMIN_*
# из переменных окружения не срабатывают. Этот скрипт добирает admin вручную.
set -uo pipefail

USER_NAME="${GRYT_KEYCLOAK_ADMIN_USERNAME:-}"
if [[ -z "${USER_NAME}" || -z "${GRYT_KEYCLOAK_ADMIN_PASSWORD:-}" ]]; then
  echo "[bootstrap-admin] ERROR: GRYT_KEYCLOAK_ADMIN_USERNAME / _PASSWORD not set."
  exit 1
fi

if [[ "${GRYT_KEYCLOAK_ADMIN_PASSWORD}" == "admin" || "${GRYT_KEYCLOAK_ADMIN_PASSWORD}" == "change_me" ]]; then
  echo "[bootstrap-admin] WARNING: the admin password is still an example value."
  echo "[bootstrap-admin] Set GRYT_KEYCLOAK_ADMIN_PASSWORD in .env."
fi

out=$(/opt/keycloak/bin/kc.sh bootstrap-admin user --no-prompt \
  --username:env GRYT_KEYCLOAK_ADMIN_USERNAME \
  --password:env GRYT_KEYCLOAK_ADMIN_PASSWORD 2>&1)
rc=$?

if [[ ${rc} -ne 0 ]]; then
  echo "${out}"
  echo "[bootstrap-admin] ERROR: kc.sh bootstrap-admin exited ${rc}."
  exit "${rc}"
fi

echo "[bootstrap-admin] ${out}"
echo "[bootstrap-admin] OK: master admin '${USER_NAME}' ensured."
