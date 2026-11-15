# Development

Read [SETUP](SETUP.md) for deployment and [OPERATIONS](OPERATIONS.md) for
administration/recovery. [AGENTS.md](../AGENTS.md) defines repository constraints;
[specification.md](../specification.md) retains requirements and the historical
owner audit. Track defects and acceptance checks in
[GitHub Issues](https://github.com/Inferlopec/gryt-auth/issues).

## Architecture and invariants

Keycloak authenticates with authorization code + PKCE S256. The audience mapper
adds the client audience; Identity validates signature, issuer, audience and
required `sub`/`exp`/`iat` claims against Keycloak JWKS. It signs an ES256 JWT
binding the account subject to a device's public EC P-256 key. Gryt verifies
the CA certificate plus a challenge-bound assertion signed by that device.
Each device has its own key; an account keeps its Keycloak subject.

The first trusted issuer owns Gryt's legacy unqualified namespace; additional
issuers use `<issuer>|<sub>` at the tested server revision. Preserve existing
issuer order; use the same order on servers that need matching account IDs.
Trust is authentication, not membership: ownership, roles, bans, invitations
and history remain per server.

PostgreSQL persists Keycloak accounts/realm state. Identity's Compose volume
holds `/app/data/ca-key.pem` and `accounts/` seed-key records. Preserve both.
Startup loads the CA before serving health and rejects missing/corrupt/unreadable
keys. Only explicit initialization can generate an absent default key, using
exclusive creation; it never overwrites a bad key. Keep issuer, realm and CA
origin stable after account creation.

The account-key gate records seed keys in compatibility mode; it does not prove
linked-device possession there. Enforcement requires separate compatibility
work. Certificate revocation/rotation limits are in
[OPERATIONS](OPERATIONS.md#accounts), not promises of protocol support.

Pairing relay sessions/messages are in memory and lost at restart. The relay
passes sealed messages, not history; history chunks live on the user's Gryt
server. Pairing uses relay/session credentials rather than Keycloak tokens and
also supports guests. Keys/commitments/sealed bodies are unpadded base64url.
Only explicitly trusted proxy peers can supply forwarded client/location
headers. Session creation/approval has upstream limits; relay success alone
does not establish graphical account-secret transfer.

## Source map and configuration ownership

| Path | Responsibility |
|---|---|
| `docker-compose.yml` | Independent auth services, private ports, volumes, resource/image pins |
| `.env.example` | Authoritative stack-variable/default reference; private `.env` supplies values |
| `realm/gryt-realm.json` | Fresh-realm template; not a live configuration sync mechanism |
| `bootstrap/` | Admin API initialization and explicit client/security/device/SMTP/email-policy/theme jobs |
| `identity/src/` | Token validation, CA/certificates, account keys and relay |
| `keycloak-pairing/` | Keycloak device-approval provider and Docker build |
| `scripts/` | Operator initialization, checks, accounts and backup/recovery |
| `tests/` | Isolated fixtures, protocol, archive and recovery checks |
| `config/`, `caddy-snippet*.txt` | Client/proxy examples and optional private-bind override |

Initialization starts DB/Keycloak, creates only a missing realm, applies policy
jobs, explicitly provisions the CA and starts Identity/backups. Normal Compose
startup has no bootstrap-job dependency. Existing realms are skipped by import;
only the flagged recovery script replaces them. SMTP, email-policy and
allowlist changes use explicit partial-update jobs rather than realm
replacement. SMTP setup does not enable verification or password recovery;
those switches are independent `.env` settings, default off, and applied to an
existing realm with `keycloak-email-policy` after delivery is verified.

For configuration semantics and explicit apply commands use
[SETUP](SETUP.md#live-realm-configuration). Internal process-only settings such
as Identity's listen port/data directory are wired by Compose. The CA-generation
flag is an initializer-only capability, not a normal runtime setting.

## APIs

Identity routes are implemented in [routes.ts](../identity/src/routes.ts) and
[pairing/routes.ts](../identity/src/pairing/routes.ts). The Keycloak provider is
separate from the relay.

| Method | Path | Contract |
|---|---|---|
| GET | `/health` | JSON status after CA startup validation |
| GET | `/.well-known/jwks.json` | Public CA signing key |
| POST | `/api/v1/certificate` | Keycloak bearer token + public `jwk`, optional seed `proof`; JSON `certificate` JWT |
| POST | `/api/v1/account-key/status` | Bearer token + `jwk`/seed `proof`; current key status |
| POST | `/api/v1/account-key/reset` | Same proof; request delayed reset; known key returns 409 |
| POST | `/api/v1/account-key/reset/cancel` | Same proof; cancel authorized reset |
| POST | `/api/v1/pairing/sessions` | Create relay session with commitment |
| POST | `/api/v1/pairing/sessions/claim` | Claim by ID/code |
| POST / GET | `/api/v1/pairing/sessions/:id/messages` | Send reveal/sealed messages or poll (up to 25 seconds) |
| DELETE | `/api/v1/pairing/sessions/:id` | Cancel/finish relay session |
| PUT / GET / DELETE | `/api/v1/pairing/sessions/:id/chunks/:n` | Legacy history compatibility: 507 / 404 / 204; no relay history storage |
| POST | `/realms/gryt/gryt-pairing/approve` | Keycloak provider approves a device-grant code |
| GET | `/realms/gryt/gryt-pairing/whoami` | Keycloak provider's authenticated-user lookup |

Certificate requests use `{"jwk":{"kty":"EC","crv":"P-256","x":"…","y":"…"}}`
with public coordinates only: private `d` is rejected. Certificates contain
`iss`, `sub`, `jwk`, `iat`, `exp` and optional `preferred_username`. Failures
include 401 invalid/missing token, 400 invalid body/key, 403 approval required
and 500 issuance failure. Account-key endpoints require seed proof; inspect
[accountKeys.ts](../identity/src/accountKeys.ts) before changing that protocol.
Legacy on-disk relay history is removed at startup. The external protocol
reference is [Gryt crypto pairing design](https://github.com/Gryt-chat/crypto/blob/main/docs/pairing-design.md);
local vendored source determines the behavior of this revision.

## Build and upstream changes

Docker builds use frozen dependencies and pinned bases; Node/Java/Maven are
not needed on the host. Retain source directories and lock files.

```bash
keycloak-pairing/build.sh
docker compose build identity
# Optional host Node 22+ version check:
node scripts/check-keycloak-version.mjs
```

The JAR is mounted into Keycloak's providers directory. Build before starting
Keycloak; [operations](OPERATIONS.md#service-lifecycle-and-updates) explains
recreation after replacement. Image/extension versions must match.

Upstream provenance and current auth pins live in [VENDOR.md](../VENDOR.md),
with component patch records linked there. Before an upstream change, inspect
the selected commit's identity, provider, realm and bootstrap changes. Preserve
local security patches, update image tags/digests with the provider version,
rebuild and run the full isolated suite. Record new source pins/patches in
VENDOR rather than duplicating them here. Never upgrade production Gryt to
make a compatibility test pass.

Distributions must retain license/attribution notices and the corresponding
source reference. There is no implemented thin prebuilt-image installer or
release workflow; current initialization reads/builds the source trees.

## Testing

Use Docker/Compose, Bash and Python 3 with disposable data only. Initial Gryt
fixture builds also need Git/network access. Test Compose uses independent
DB/CA/server volumes and loopback ports 18280/18281:

```bash
keycloak-pairing/build.sh
tests/run_all.sh --with-gryt
# Reuse a prepared test stack/images:
tests/run_all.sh --with-gryt --no-build
# Stop without deleting fixture state:
docker compose -f tests/docker-compose.test.yml --profile gryt down
```

Exit 0 means selected required checks passed; 1 is failure; 2 means required
checks were not executed. Missing Docker or omitting `--with-gryt` is not full
compatibility success. Reusing volumes preserves test accounts/ownership;
never reset only the auth DB while retaining server data and expect the same
IDs. A fresh run needs a coherent fresh set of fixtures.

```bash
python3 tests/test_archive_validation.py
python3 tests/test_client_access.py
# Upstream unit tests after building the test-runner image:
docker compose -f tests/docker-compose.test.yml run --rm --no-deps --entrypoint yarn test-runner test
```

Individual shell wrappers need the prepared stack; Gryt joins also require
`GRYT_TEST_SERVERS` and both fixtures. They do not replace the full recovery run.
`tests/run_all.sh --with-gryt` also invokes the actual deployed preflight's
`main()` against the isolated Keycloak/Identity fixtures before, during and after
callback/Origin removal. This test replaces only the HTTPS URL policy for the
fixed internal HTTP fixture addresses; production HTTPS validation stays enabled.
It verifies failure exit codes even when OPTIONS permits the removed Origin.
Offline regressions reject unusable P-256 points and non-OAuth responses to the
denied-Origin smoke request. The suite also verifies theme defaults and
non-destructive theme updates. Graphical responsive review of Keycloak login,
error, account and email pages remains a separate acceptance check.
For documentation-only edits, check links/anchors/file paths, shell syntax,
command semantics against source and `git diff --check`; a full stack run is
unnecessary. Report unexecuted commands explicitly.

### Compatibility references

| Component | Inspected/tested revision |
|---|---|
| Gryt Server fixtures | `f537aa5e3d8a4bdba3c75e34b6dbfece2d727f42` |
| Gryt Client PR #1197 | `5d8e294a09cb6626a67e8bb0740158ee27232503` |
| Gryt Auth PR #71 | `77c38ca94dbe5a91adf271c234b535b5d4548fb2` |
| Gryt CLI 0.8.1 procedure inspection | `2c7dea7a71c66aeb448fcb75e202c9cc5a266a81` |

### Recorded test evidence

On 2026-11-14 (Europe/Riga), the isolated full suite exited 0 after the Desktop
allowlist fixes: **20 Identity unit tests, 6 archive-safety tests, 4 client-access
tests and 9 main integration cases**, plus CA recreation and DB/CA recovery.
This supersedes the earlier 8-case integration count. No production keys,
data, DNS, Caddy or Gryt profiles were used or changed.

Coverage included code + PKCE/refresh, wrong password/verifier and signed
issuer/audience/expiry rejection; exact Desktop token-response/refresh CORS,
OPTIONS and denied Origins/callbacks for the then-current HTTPS callback; device
grant and sealed relay; two devices
on two actual servers, issuer isolation and independent bans; rejected untrusted/
expired certificates; preserved CA trust after recreation; repeated initialization,
SMTP/client-policy updates and destructive replacement followed by actual restore.
Version coupling, base/test/private-override Compose and syntax checks also passed.

This recorded run did not yet include the new deep-link callback flow. The
callback protocol test did not contact `gryt.chat`. Local logs were ephemeral
(`/tmp/gryt-auth-phase1-tests.log`); they are not archived production evidence.
The owner separately reported Desktop 1.15.12 macOS staging login, restart and
pairing after manual corrections. A fresh graphical Desktop regression, Web
acceptance, real DNS/proxy trust, SMTP delivery, MFA/TOTP enforcement, off-host
fresh-host recovery and production-server acceptance were **not executed** in
that isolated run. The subsequent callback protocol run is recorded below;
graphical and production checks remain pending.
Use [production readiness](OPERATIONS.md#production-readiness) for remaining gates.

### Callback update verification (2026-11-15)

`tests/run_all.sh --with-gryt` exited 0 with Docker access: 20 Identity unit
tests, 6 archive-safety tests, 4 client-access tests, 9 integration cases,
CA recreation and DB/CA recovery checks passed. The updated Desktop integration
case completed authorization-code + PKCE exchange and refresh for both
`gryt://auth/callback` and `https://gryt.chat/auth/callback` with the exact
renderer Origin. It also checked denied Origins and callback lookalikes. The
run used isolated test services and did not contact `gryt.chat` or production.
Graphical acceptance with an updated packaged Desktop release remains pending.

### Deployed preflight and themes (2026-11-15)

`tests/run_all.sh --with-gryt` exited 0 after adding BUG-04 negative fixtures
and the live theme-update job. The isolated Keycloak fixture rejected the
removed Desktop callback and stopped returning token-response CORS after the
renderer Origin was removed; both checks restored the fixture configuration.
The theme job passed dry-run and update/read-back against the existing realm,
then the existing test account completed code + PKCE login and refresh. The full
run also passed the two-server Gryt joins and DB/CA recovery cases. Only test
containers and volumes were used; deployed preflight against a public host and
graphical desktop/mobile or email-rendering review were not performed.

Review follow-up: the full isolated suite exited 0 after replacing the direct
Keycloak negative checks with two tests invoking the actual preflight `main()`.
Both demonstrated healthy → failure → healthy results for callback/Origin
removal, with OPTIONS still succeeding in the missing-Origin case. Six offline
preflight tests also passed, including malformed/off-curve Identity coordinates
and rejected gateway/HTML/non-`invalid_grant` responses for the denied Origin.
This remains HTTP fixture evidence; public HTTPS and graphical acceptance are
pending.
