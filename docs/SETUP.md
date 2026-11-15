# Setup

Add one Identity stack to the Linux host already running Caddy, Gryt shared
services/SFU and at least one Gryt server. Connect servers individually; each
keeps its database, ownership, roles, bans and media worker. Commands below
are operator actions; repository development does not apply them to production.

## Prerequisites

Use the Unix user who owns the existing Gryt profiles. Required: Docker,
Compose >=2.24.4, Bash, Python 3, curl, jq, OpenSSL, tar, gzip and Git. Builds
run Node/Maven in Docker and need registry/package-network access.

```bash
docker version
docker compose version
gryt version
gryt list
free -h
df -h
ss -ltn
docker inspect inferlo-caddy --format '{{.HostConfig.NetworkMode}}'
```

The supplied Caddy snippet requires `host` networking. Its loopback upstreams
are unreachable from a bridge-network Caddy container. Check available memory,
disk and ports before adding Keycloak: the owner's original 3.8 GiB host needs
more resources for production; 8 GiB is a planning target, not a capacity test.
Container names/domains below describe that installation; adapt them to yours.

## Source and configuration

The current installer builds from source. Keep `identity/`, `keycloak-pairing/`,
lock files and build tooling. There is no implemented operator-package workflow.
Place the checkout outside Gryt's data directories, owned by your deployment user:

```bash
git clone https://github.com/Inferlopec/gryt-auth.git /opt/inferlo-identity
cd /opt/inferlo-identity
cp .env.example .env
chmod 600 .env
openssl rand -base64 32
openssl rand -base64 32
```

Use the two outputs as independent admin and database passwords. Edit `.env`
before continuing. Scripts source it as trusted shell code: quote spaces, `$`,
`#` and shell metacharacters; never commit secrets.

[.env.example](../.env.example) is the authoritative list of configurable stack
variables and defaults. [docker-compose.yml](../docker-compose.yml) defines
service wiring; [client.config.js](../config/client.config.js) is the web runtime
example. Do not maintain another copy of their configuration tables.

Required configuration review:

- Set both passwords; retain the bootstrap administrator name for initialization.
- Set public Keycloak and Identity URLs consistently; adapt Caddy and client URLs
  together if domains differ. Keep realm, public issuer and CA origin stable
  after accounts exist.
- Select unused loopback ports. Do not publish PostgreSQL or the management port.
- Keep registration closed, the account-key gate in `learn`, and the import
  compatibility marker at `0`. Leave the custom CA path empty for a new install.
  Changing to `enforce` needs separate client testing and authorization.
- Set proxy trust after observing each container's actual proxy peer below.
- Choose backup storage/retention and an off-host destination; see
  [backups](OPERATIONS.md#backups-and-recovery). SMTP may remain empty initially.

Changing `.env` does not rotate an existing PostgreSQL password or update live
realm settings. Client-facing variables are reference values, not automatic
configuration of existing clients.

## Initialize and check local endpoints

```bash
keycloak-pairing/build.sh
scripts/preflight.sh
scripts/initialize.sh
docker compose ps
curl -fsS http://127.0.0.1:18080/realms/gryt/.well-known/openid-configuration
curl -fsS http://127.0.0.1:18081/health
curl -fsS http://127.0.0.1:18081/.well-known/jwks.json
```

Use configured ports if different. Installation preflight must report zero
failures; public-endpoint warnings can precede DNS/Caddy setup. After public
DNS and proxy routes are active, run `scripts/preflight.sh --deployed`. This
read-only mode checks the live client allowlists through the local Admin API,
public discovery/issuer and JWKS, Identity health/JWKS, both Desktop callback
requests and a token-response CORS POST. Identity keys must contain valid public
P-256 coordinates; both allowed and denied Origin requests must return the
expected OAuth error before CORS is evaluated. It checks existing realms even though
initialization skips their import. It requires working admin credentials and
does not change realm settings. A missing callback or Origin is a failure;
unreachable required checks return exit 2 and are not PASS. Successful endpoint
checks do not establish graphical client compatibility or a successful user
login. PostgreSQL, Keycloak and Identity must be healthy,
pg-backup running, and every bootstrap job successful. Discovery must advertise
the public issuer; health returns `{"status":"ok"}`; JWKS contains a public EC
key with no private `d` field.

Initialization creates a missing realm, applies explicit policy jobs and
provisions an absent CA. Repeating it preserves existing accounts; it does not
reapply the entire realm template. Normal startup cannot generate a missing CA.
A corrupt/unreadable key must be recovered, never replaced as a startup fallback.

## DNS, Caddy and proxy trust

Create auth/id DNS records for the actual host; correct stale IPv6 records.
The app hostname is needed only for a separately hosted web client. Back up the
existing Caddyfile to a new filename, add [caddy-snippet.txt](../caddy-snippet.txt)
and match its upstream ports to `.env`. Keep chat/SFU routes. For the audited
Caddy paths/container:

```bash
sudo cp -p /opt/caddy/Caddyfile "/opt/caddy/Caddyfile.before-identity-$(date +%Y%m%dT%H%M%S)"
docker exec inferlo-caddy caddy validate --config /etc/caddy/Caddyfile
docker exec inferlo-caddy caddy reload --config /etc/caddy/Caddyfile
```

Determine the peer seen by each backend. The Docker gateway is a candidate,
not proof of the address. With tcpdump installed, run:

```bash
docker network inspect inferlo-identity --format '{{json .IPAM.Config}}'
IDENTITY_IP=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' inferlo-identity-service)
sudo tcpdump -n -i any "dst host $IDENTITY_IP and tcp dst port 3000"
```

Request public Identity health in another terminal; read the packet source and
stop capture. Repeat for `inferlo-identity-keycloak`, destination port 8080,
while requesting public discovery. Set each confirmed peer in its corresponding
trusted-proxy variable. Do not trust all Docker networks. Keep Caddy's overwrite
of `CF-Connecting-IP` and removal of location headers: visitor input must not
control pairing identity/rate limits.

```bash
docker compose up -d --no-deps --wait keycloak identity
curl -fsS https://auth.inferlo.xyz/realms/gryt/.well-known/openid-configuration
curl -fsS https://id.inferlo.xyz/health
curl -fsS https://id.inferlo.xyz/.well-known/jwks.json
```

Verify the same issuer/public-key properties as locally. Do not bypass TLS
verification with `-k`.

## Live realm configuration

### Callback and Origin allowlists

Fresh initialization includes the Desktop deep-link callback, exact HTTPS
compatibility callback, upstream loopback redirect on port 15738, and renderer
Origin described under [Desktop](#desktop-and-web-clients). Additional callbacks
and Origins use the two additive JSON-array settings in `.env.example`.
Origins have no path/trailing slash; additions reject wildcards. Inspect the
actual `redirect_uri` and `Origin`, not assumptions about renderer ports.
A client runtime callback setting does not register it in Keycloak.

For an existing realm, review and apply the explicit client-only update:

```bash
docker compose run --rm --no-deps keycloak-client-access --dry-run
docker compose run --rm --no-deps keycloak-client-access
```

Expected: before/after lists, then `gryt-web callback and Web Origins configured;
accounts preserved.` Read-back verifies the result. Other entries remain;
only the ineffective `http://127.0.0.1:*` entry is removed. Review any other
permissive existing entries separately. Removing an addition from `.env` does
not revoke it. Restore reviewed prior lists through `gryt` → Clients → `gryt-web`
for allowlist rollback; do not restore that wildcard or reimport the realm.

### Login, account and email themes

Fresh realms select the built-in `keycloak.v2` login theme, `keycloak.v3`
account theme and `keycloak` email theme available in pinned Keycloak 26.5.3.
Existing realms are not changed by initialization. Preview and explicitly
apply just the three theme fields with the configure-profile job:

```bash
docker compose run --rm --no-deps keycloak-themes --dry-run
docker compose run --rm --no-deps keycloak-themes
```

The job reads its result back and preserves users and other realm settings.
To roll back, restore the three values printed by the dry run through Keycloak
Admin Console → **Realm settings** → **Themes**. Confirm login, error, account
and email pages on desktop and mobile; this built-in theme change adds no custom
branding.

### SMTP

Set the SMTP fields in `.env.example` for your provider, then:

```bash
docker compose run --rm --no-deps keycloak-smtp
```

Expected: `SMTP updated; accounts preserved.` The job requires STARTTLS;
implicit-TLS-only providers are unsupported. Without SMTP, initialization
explicitly disables verification and password recovery. Send a test email in
Keycloak realm email settings, then verify email and password recovery with a
disposable account. Never replace a realm to change mail settings.

## Connect an existing Gryt server

The procedure was checked against [CLI 0.8.1 source](https://github.com/Gryt-chat/cli/blob/2c7dea7a71c66aeb448fcb75e202c9cc5a266a81/cmd/gryt/main.go).
Inspect generated files on other versions. Verify the installed server supports
issuer-scoped account IDs before changing production trust; do not upgrade it
for this integration. Keep a normal server data backup as well as these files:

```bash
SERVER_ID=inferlo-gaming
SERVER_DIR="$HOME/.config/gryt/servers/$SERVER_ID"
SERVER_CONTAINER="gryt-$SERVER_ID"
SERVER_PROJECT=$(docker inspect --format '{{ index .Config.Labels "com.docker.compose.project" }}' "$SERVER_CONTAINER")
umask 077
CONFIG_BACKUP="$HOME/gryt-config-$SERVER_ID-$(date +%Y%m%dT%H%M%S)"
mkdir "$CONFIG_BACKUP"
cp -p "$SERVER_DIR/profile.json" "$SERVER_DIR/.env" "$SERVER_DIR/compose.yaml" "$CONFIG_BACKUP/"
docker inspect --format '{{.Image}}' "$SERVER_CONTAINER" > "$CONFIG_BACKUP/image-id.txt"
```

Adjust the directory for `GRYT_CONFIG_DIR`. Confirm the project is nonempty and
matches the running server. Configuration backups contain secrets.

Append the Inferlo CA once to the existing `GRYT_TRUSTED_CERT_ISSUERS` list in
**both** `profile.json`'s `extraEnv` and the generated `.env`; retain every
existing issuer in its original order and retain `GRYT_IDENTITY_TIERS`.
For the audited official-first, account/local setup the effective values are:

```dotenv
GRYT_TRUSTED_CERT_ISSUERS=https://id.gryt.chat,https://id.inferlo.xyz
GRYT_IDENTITY_TIERS=account,local
```

The profile preserves settings across CLI regeneration; `.env` applies them
now through the service's `env_file`. Merge fields, avoid duplicate entries,
and confirm that wiring in the installed Compose. Do not change server OIDC,
JWT secrets, SFU configuration, management tokens, volumes or images.

Recreate only this server, after checking its image still matches:

```bash
cd "$SERVER_DIR"
docker compose -p "$SERVER_PROJECT" -f compose.yaml config --quiet
gryt env "$SERVER_ID" | grep -E 'GRYT_TRUSTED_CERT_ISSUERS|GRYT_IDENTITY_TIERS'
SERVER_IMAGE_REF=$(docker compose -p "$SERVER_PROJECT" -f compose.yaml config --format json | python3 -c 'import json,sys; print(json.load(sys.stdin)["services"]["server"]["image"])')
if [ "$(docker image inspect --format '{{.Id}}' "$SERVER_IMAGE_REF")" = "$(cat "$CONFIG_BACKUP/image-id.txt")" ]; then
    docker compose -p "$SERVER_PROJECT" -f compose.yaml up -d --no-deps --pull never server
else
    printf 'Stopped: image differs; pin the original image before retrying.\n' >&2
fi
```

Inspect `config --services` if the service is not named `server`. A restart
alone does not apply environment changes. Avoid `gryt pull` and `gryt start`:
[start also regenerates/starts the shared project](https://github.com/Gryt-chat/cli/blob/2c7dea7a71c66aeb448fcb75e202c9cc5a266a81/internal/start/start.go).

Check normal server HTTPS health and unchanged image ID. Test a disposable
Inferlo account using an invitation where required. Confirm existing
official/local owners retain IDs, ownership, roles, bans and history.
Trust does not grant membership or admin rights. If these checks fail, use
[rollback](OPERATIONS.md#rollback) before connecting more servers.

## Add another server

Reuse Identity, Caddy, the shared SFU and existing `gryt` network. Choose a free
port/name and check `gryt create --help` against the installed CLI. On 0.8.1:

```bash
gryt create --name inferlo-community --host 127.0.0.1 --port 5001 --security community --proxy-hops 1 --domain wss://sfu.inferlo.xyz --yes
```

`create` writes files without starting containers; `--domain` supplies the
public SFU address, not the chat hostname. `community` permits account/local
identities. Apply the same trust order using the preceding section.

Compare SFU settings privately with the working server; retain its required SFU
authentication. Keep a new JWT secret, management token and separate data.
Pin new `server`/`data-init` to the same reviewed server image and the media
worker to its reviewed image; inspect existing container `.Image` and
`docker image inspect IMAGE_ID --format '{{json .RepoDigests}}'` rather than
assuming a mutable tag is unchanged. Confirm the external network exists.

```bash
cd "$HOME/.config/gryt/servers/inferlo-community"
docker compose -p gryt-inferlo-community -f compose.yaml config --quiet
docker compose -p gryt-inferlo-community -f compose.yaml up -d --pull never
docker compose -p gryt-inferlo-community -f compose.yaml ps
```

This starts only the new server project, including its own media worker and
data initialization. Investigate missing images/networks; do not duplicate SFU.
Add DNS and a backed-up, validated Caddy route for the new chat hostname:

```caddyfile
community.inferlo.xyz {
    reverse_proxy 127.0.0.1:5001
}
```

Check HTTPS `/health`, then join with the same account. The tested server grants
ownership to the first successful joining user: arrange that login before
advertising it. Check roles/bans remain independent between servers.

## Desktop and web clients

Create a disposable account using [administration](OPERATIONS.md#accounts).
On the owner's Desktop 1.15.12 macOS installation, enable
`Settings → General → Advanced → Show advanced settings`, then open
`Settings → Account & security → Account → Auth server`. On **each device**, set
both the OIDC issuer and Identity Service URL to your configured endpoints.
Setting only one can send certificate requests to the wrong CA.

The updated Client source in [PR #1197](https://github.com/Gryt-chat/client/pull/1197)
defaults to `gryt://auth/callback` for a custom issuer. It keeps code, PKCE and
state handling unchanged and uses that same URI for authorization and token
exchange. The exact legacy callback `https://gryt.chat/auth/callback` remains
registered for older Desktop releases. Both use renderer Origin
`http://127.0.0.1:15738`; the realm also keeps the upstream loopback redirect on
that exact port. Auth PR [#71](https://github.com/Gryt-chat/auth/pull/71) records
the exact Origin fix. The isolated Docker-backed integration test passed code +
PKCE exchange, refresh and denied callback controls for both callbacks, using
the exact renderer Origin. Graphical deep-link delivery and login remain
unverified until an updated Desktop release is tested on target OSes. Do not
replace either callback with an arbitrary SPA route.

For an existing self-hosted web container, adapt
[config/client.config.js](../config/client.config.js) and bind-mount it read-only
at `/usr/share/nginx/html/config.js`. Check the served `/config.js` and clear
stale user overrides. The web client returns to its current page URL; its
callback behavior differs from Desktop. Configure app DNS/Caddy separately
and add its origin to Keycloak and each server's existing `CORS_ORIGIN` list,
preserving required origins. Identity does not deploy a web client.

For second-device approval, on a trusted device open `Your devices → Link a
device`, enter the new device's code and verify the emoji comparison before
approving. UI paths are owner-reported for 1.15.12; test your actual release.

## Initial verification

Using disposable identities, verify Web and Desktop separately:

1. Log in; confirm certificate issuance and joining the first server.
2. Restart the client; verify the same identity and membership.
3. Approve a second device and confirm the intended account secrets transferred.
4. Join a second server with the same account; verify independent roles/bans.
5. Verify original official/local users retain their rights on existing servers.

Owner-reported macOS staging login/pairing succeeded after manual allowlist
corrections on Desktop 1.15.12. The isolated protocol run passed for both the
new deep-link callback and legacy HTTPS callback; graphical regression with an
updated Desktop release and graphical Web/production acceptance remain open. See
[test evidence](DEVELOPMENT.md#recorded-test-evidence) and
[production readiness](OPERATIONS.md#production-readiness).

## Optional separate auth VM

The existing [private-bind override](../config/compose.private.yaml) and
[VM Caddy snippet](../caddy-snippet-vm.txt) are unverified on real infrastructure.
They require an encrypted tunnel or TLS, restricted reachability from Caddy,
and a real tunnel-interface bind address. Loopback does not cross VM boundaries.
Set the private-bind variable from `.env.example` and export
`COMPOSE_FILE=docker-compose.yml:config/compose.private.yaml` for **every**
initialization, maintenance and recovery command. Loopback helpers
`users.sh`/`jwks_snapshot.sh` need address adaptation and testing in this layout.
Keep DB/management ports private and verify actual proxy peers. This is not
the primary installation path.
