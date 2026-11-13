# Development setup and testing

Use the current local working tree. The future repository is
`https://github.com/Inferlopec/gryt-auth`; source cloning is only possible after
its owner creates and publishes it. No CI or release workflow is installed yet.

## Dependencies

Docker Engine/Compose, Bash and Python 3 are required. Builds run Node and
Maven inside pinned Docker bases. Git/network access is needed for upstream
sources during the initial test-server image build. jq/curl/OpenSSL are also
used by operator tools; see [operator installation](../operator/installation.md).

## Full protocol and recovery suite

Run from the repository root:

```bash
keycloak-pairing/build.sh
tests/run_all.sh --with-gryt
```

The test project has its own PostgreSQL, CA keys, artifacts and server volumes.
Its host ports are 18280/18281 on loopback. The two actual Gryt server fixtures
are pinned by source commit in `tests/docker-compose.test.yml`.
The suite checks authorization code + PKCE, signed certificates, issuer/audience
rejection, device authorization, relay, independent server bans, CA recreation,
non-destructive SMTP updates and destructive-recovery round trips.

Exit 0 means all selected required checks passed; 1 means failure; 2 means a
required check was not executed. Omitting --with-gryt must not be reported as
full compatibility success. Tests require no production .env, data or keys.

For an already-running test stack:

```bash
tests/run_all.sh --with-gryt --no-build
```

To stop your test resources while preserving volumes:

```bash
docker compose -f tests/docker-compose.test.yml --profile gryt down
```

Reusing volumes preserves test account IDs/ownership. Do not remove only the
test auth database while keeping server data and then expect unchanged account
IDs. A fresh test run should use a coherent fresh set of fixtures.

## Targeted checks

```bash
python3 tests/test_archive_validation.py
```

After building the test-runner image, upstream Identity unit tests can run via:

```bash
docker compose -f tests/docker-compose.test.yml run --rm --no-deps --entrypoint yarn test-runner test
```

Individual `tests/test_*.sh` wrappers require the prepared test stack. Gryt
joins also require GRYT_TEST_SERVERS and the two server fixtures. The wrapper
scripts are not a replacement for the full recovery sequence.

## Documentation-only changes

Check local Markdown links, relative paths, shell examples and correspondence
with actual scripts/configuration. Check `git diff --check`. Do not run a full
Docker/recovery suite solely for moving documentation. If a documented command
was not executed, say so; previously recorded evidence does not prove a new
procedure ran on production.
