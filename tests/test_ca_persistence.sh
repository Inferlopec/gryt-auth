#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
c=(docker compose -f tests/docker-compose.test.yml)
"${c[@]}" run --rm --no-deps test-runner --test-name-pattern='CA snapshot before recreation' /app/integration/persistence.test.mjs
"${c[@]}" up -d --no-deps --force-recreate --wait --wait-timeout 60 identity
"${c[@]}" run --rm --no-deps test-runner --test-name-pattern='CA verifies after recreation' /app/integration/persistence.test.mjs
