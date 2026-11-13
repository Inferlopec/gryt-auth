#!/usr/bin/env bash
# Explicit, repeatable setup. Normal `compose up` never imports or replaces realms.
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose config --quiet
test -s keycloak-pairing/dist/gryt-pairing.jar || keycloak-pairing/build.sh
docker compose build identity
docker compose up -d --wait --wait-timeout 300 postgres keycloak
docker compose run --rm --no-deps keycloak-import
docker compose run --rm --no-deps keycloak-client-policy
docker compose run --rm --no-deps keycloak-security-policy
docker compose run --rm --no-deps keycloak-device-grant
docker compose run --rm --no-deps -e GRYT_CA_ALLOW_GENERATE=1 identity \
  node --input-type=module -e 'import {getCAPublicJwk} from "./dist/keys.js"; await getCAPublicJwk();'
docker compose up -d --wait --wait-timeout 120 identity pg-backup
echo 'Initialization complete. Keep production integration changes operator-controlled.'
