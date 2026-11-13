#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -z "${GRYT_TEST_SERVERS:-}" ]; then
  echo 'NOT EXECUTED: run tests/run_all.sh --with-gryt'; exit 2
fi
docker compose -f tests/docker-compose.test.yml run --rm --no-deps test-runner --test-name-pattern='Two devices join' /app/integration/integration.test.mjs
