#!/usr/bin/env bash
# Execute production recovery tools only against the explicitly selected disposable project.
set -euo pipefail
cd "$(dirname "$0")/.."
export COMPOSE_FILE="$PWD/tests/docker-compose.test.yml"
export GRYT_ENV_FILE=/dev/null
export GRYT_AUTH_BACKUP_DIR
GRYT_AUTH_BACKUP_DIR="$(mktemp -d)"
trap 'rm -rf "$GRYT_AUTH_BACKUP_DIR"' EXIT
c=(docker compose)
run() { "${c[@]}" run --rm --no-deps test-runner --test-name-pattern="$1" /app/integration/recovery.test.mjs; }
run 'Account and CA snapshot before recovery'
# Creating a realm again must leave all user IDs intact.
"${c[@]}" run --rm --no-deps keycloak-import
"${c[@]}" run --rm --no-deps keycloak-client-policy
"${c[@]}" run --rm --no-deps keycloak-client-access
run 'Recovery preserves user subject'
run 'Save original mail settings'
"${c[@]}" run --rm --no-deps -e GRYT_SMTP_HOST=mail.example.test \
  -e GRYT_SMTP_FROM=identity@example.test -e 'GRYT_SMTP_FROM_NAME=Inferlo "Tests"' keycloak-smtp
run 'SMTP update preserves users'
"${c[@]}" run --rm --no-deps -e GRYT_VERIFY_EMAIL=true \
  -e GRYT_RESET_PASSWORD_ALLOWED=false keycloak-email-policy
run 'Email policy update preserves SMTP and users'
"${c[@]}" exec -T postgres pg_dump -U keycloak -d keycloak > "$GRYT_AUTH_BACKUP_DIR/database.sql"
gzip "$GRYT_AUTH_BACKUP_DIR/database.sql"
run 'Create post-backup marker account'
bash scripts/reimport_realm.sh --i-understand-this-deletes-all-users
run 'Realm replacement removed original account'
printf 'YES\n' | scripts/restore_postgres.sh "$GRYT_AUTH_BACKUP_DIR/database.sql.gz"
run 'Restore removes post-backup marker account'
run 'Recovery preserves user subject'
scripts/ca_key_backup.sh "$GRYT_AUTH_BACKUP_DIR/ca.tar.gz"
"${c[@]}" stop identity
"${c[@]}" run --rm -T --no-deps --entrypoint node identity -e 'require("node:fs").writeFileSync("/app/data/ca-key.pem", "damaged-test-key")'
printf 'YES\n' | scripts/restore_ca_key.sh "$GRYT_AUTH_BACKUP_DIR/ca.tar.gz"
run 'Recovery preserves user subject'
