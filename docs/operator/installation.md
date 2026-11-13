# Install alongside an existing Gryt deployment

This adds one independent authentication stack to the machine that already
runs Caddy, Gryt's shared SFU and at least one Gryt server. Existing chat and
voice endpoints stay in place. You will connect individual Gryt servers only
after the new auth endpoints work.

The procedure below is for the **current source snapshot**. It builds inside
Docker; it does not require Node, Java or Maven on the host. Ready-made release
installation will be documented when [downloads](download.md) are available.

## 1. Check the host

Run these as your normal deployment user:

```bash
docker version
docker compose version
gryt version
gryt list
free -h
df -h
ss -ltn
```

You need Docker access, Compose v2.24.4 or newer, Bash, Python 3, curl, jq,
OpenSSL and tar. On Ubuntu, missing command-line tools can be installed with:

```bash
sudo apt-get install python3 curl jq openssl tar
```

Check that ports `18080` and `18081` are free; otherwise choose different
`GRYT_KEYCLOAK_PORT` / `GRYT_IDENTITY_PORT` values. Keycloak adds a substantial
memory load: the audited 3.8 GiB host needs a resource upgrade before this
same-host layout is used for production. Budget for PostgreSQL, image builds,
backups and the existing Gryt workload; an 8 GiB host is the planning target,
not a guarantee of sufficient spare resources.

Confirm your existing Caddy runs with host networking before using the
loopback proxy snippet. For the audited installation:

```bash
docker inspect inferlo-caddy --format '{{.HostConfig.NetworkMode}}'
```

Expected: `host`. A bridge-network Caddy cannot reach host services through
its own 127.0.0.1; see [troubleshooting](troubleshooting.md).

## 2. Put the project in its own directory

Use `/opt/inferlo-identity` for the source snapshot. Copy the project there
using your normal deployment method and give your deployment user ownership
of that directory. Do not put it inside a Gryt server's data directory.

```bash
cd /opt/inferlo-identity
cp .env.example .env
chmod 600 .env
```

Follow [configuration](configuration.md) to set both generated passwords and
confirm the auth/id domains. Leave realm `gryt` and `GRYT_IMPORT_REALM=0`.
Leave SMTP empty if no mail provider has been selected yet.

## 3. Build and initialize

```bash
keycloak-pairing/build.sh
scripts/preflight.sh
scripts/initialize.sh
docker compose ps
```

The first build downloads images and dependencies. Preflight must show zero
failures. Public-endpoint warnings are expected before DNS/Caddy is ready.
Initialization creates only a missing realm and a missing CA key. Repeating
it preserves accounts; a corrupt existing key is a recovery problem.

Expected: PostgreSQL, Keycloak and Identity Service are healthy; pg-backup is
running. A Python/bootstrap job failing is a setup failure, even if some
containers are already healthy. Inspect it with [troubleshooting](troubleshooting.md).

Test the local backends:

```bash
curl -fsS http://127.0.0.1:18080/realms/gryt/.well-known/openid-configuration
curl -fsS http://127.0.0.1:18081/health
curl -fsS http://127.0.0.1:18081/.well-known/jwks.json
```

Use your configured ports if different. The first response must name your
public issuer; health must contain `"status":"ok"`; JWKS must contain a public
EC key without a private `d` field.

## 4. Configure DNS and the existing Caddy

Create DNS records for `auth.inferlo.xyz` and `id.inferlo.xyz` pointing at this
host. Use the actual host address; remove or correct stale IPv6 records too.
An `app.inferlo.xyz` record is only needed if you later host the web client.

Back up the existing Caddyfile. For the audited installation its host path is
`/opt/caddy/Caddyfile` and the container is `inferlo-caddy`:

```bash
sudo cp -p /opt/caddy/Caddyfile /opt/caddy/Caddyfile.before-identity
```

If that backup already exists, use a new filename. Add the two site blocks
from `caddy-snippet.txt` to the Caddyfile. Keep existing chat/SFU blocks.
Match proxy ports to `.env`, then validate and reload:

```bash
docker exec inferlo-caddy caddy validate --config /etc/caddy/Caddyfile
docker exec inferlo-caddy caddy reload --config /etc/caddy/Caddyfile
```

A reload applies the new routes without replacing the Caddy container.
Use the real config path/container name if your existing setup differs.

## 5. Set proxy trust and verify HTTPS

[Configure the proxy source addresses](configuration.md#proxy-trust) seen by
Keycloak and Identity Service. The source inside Docker may be the bridge
gateway, even though Caddy connects to a host loopback port. Do not trust an
arbitrary private subnet to make an error disappear.

```bash
curl -fsS https://auth.inferlo.xyz/realms/gryt/.well-known/openid-configuration
curl -fsS https://id.inferlo.xyz/health
curl -fsS https://id.inferlo.xyz/.well-known/jwks.json
```

Use normal certificate verification; do not bypass TLS errors with `-k`.
Keep PostgreSQL and Keycloak's management port unpublished.

## 6. Connect one server first

Follow [connect an existing server](existing-server.md), then [clients](clients.md).
Create a test account using [users](users.md) and verify that existing Gryt
users keep their ownership and roles. Only then attach additional servers.
Before opening registration or relying on this for production, complete the
[readiness checks](readiness.md) and configure [backups](backup-and-recovery.md).
