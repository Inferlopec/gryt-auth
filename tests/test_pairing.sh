#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose -f tests/docker-compose.test.yml run --rm --no-deps test-runner --test-name-pattern='Device grant|Pairing relay checks' /app/integration/integration.test.mjs
