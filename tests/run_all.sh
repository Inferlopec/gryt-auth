#!/usr/bin/env bash
# Exit 0: all selected checks passed; 1: failure; 2: required checks not executed.
set -euo pipefail
cd "$(dirname "$0")/.."
compose=(docker compose -f tests/docker-compose.test.yml)
with_gryt=0
reuse=0
for arg in "$@"; do
  case "$arg" in
    --with-gryt) with_gryt=1 ;;
    --no-build) reuse=1 ;;
    *) echo "Usage: tests/run_all.sh [--with-gryt] [--no-build]" >&2; exit 1 ;;
  esac
done
if ! docker info >/dev/null 2>&1; then
  echo 'NOT EXECUTED: Docker unavailable. Reproduce: tests/run_all.sh --with-gryt'
  exit 2
fi
if [ "$reuse" = 0 ]; then
  test -s keycloak-pairing/dist/gryt-pairing.jar || keycloak-pairing/build.sh
  "${compose[@]}" build identity test-runner
  "${compose[@]}" up -d --wait --wait-timeout 300 postgres keycloak
  "${compose[@]}" run --rm --no-deps keycloak-import
  "${compose[@]}" run --rm --no-deps keycloak-client-policy
  "${compose[@]}" run --rm --no-deps keycloak-device-grant
  "${compose[@]}" run --rm --no-deps keycloak-security-policy
  for svc in identity other-identity; do
    "${compose[@]}" run --rm --no-deps -e GRYT_CA_ALLOW_GENERATE=1 "$svc" \
      node --input-type=module -e 'import {getCAPublicJwk} from "./dist/keys.js"; await getCAPublicJwk();'
  done
  "${compose[@]}" up -d --wait --wait-timeout 120 identity other-identity
fi
if [ "$with_gryt" = 1 ]; then
  "${compose[@]}" up -d --wait --wait-timeout 300 gryt-a gryt-b
  export GRYT_TEST_SERVERS=http://gryt-a:5000,http://gryt-b:5000
fi
python3 tests/test_archive_validation.py
"${compose[@]}" run --rm --no-deps --entrypoint yarn test-runner test
"${compose[@]}" run --rm --no-deps test-runner
# Recreate (not merely restart) the CA; then cryptographically re-check a saved certificate.
"${compose[@]}" run --rm --no-deps test-runner --test-name-pattern='CA snapshot before recreation' /app/integration/persistence.test.mjs
"${compose[@]}" up -d --no-deps --force-recreate --wait --wait-timeout 60 identity
"${compose[@]}" run --rm --no-deps test-runner --test-name-pattern='CA verifies after recreation' /app/integration/persistence.test.mjs
bash tests/test_recovery.sh
if [ "$with_gryt" = 0 ]; then
  echo 'NOT EXECUTED: two-server Gryt joins. Reproduce: tests/run_all.sh --with-gryt'
  exit 2
fi
