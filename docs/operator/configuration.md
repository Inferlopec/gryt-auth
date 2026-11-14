# Configuration

Edit `/opt/inferlo-identity/.env`. Keep it private (`chmod 600 .env`) and retain
it when updating the program. Scripts source this trusted file as shell code;
quote values containing spaces, `$`, `#` or other shell characters.

## Required for the first installation

Generate two independent passwords:

```bash
openssl rand -base64 32
openssl rand -base64 32
```

Paste one into `GRYT_KEYCLOAK_ADMIN_PASSWORD` and the other into
`GRYT_AUTH_POSTGRES_PASSWORD`. Keep them in your password manager. Leave
`GRYT_KEYCLOAK_ADMIN_USERNAME=admin` for the current bootstrap workflow.
Changing the database password only in `.env` does not change an existing
PostgreSQL user's password; treat later rotation as a separate operation.

| Setting | Inferlo value / action |
|---|---|
| `GRYT_KEYCLOAK_HOSTNAME_URL` | `https://auth.inferlo.xyz` |
| `GRYT_KEYCLOAK_HOSTNAME_ADMIN_URL` | `https://auth.inferlo.xyz` |
| `GRYT_OIDC_ISSUER` | `https://auth.inferlo.xyz/realms/gryt` |
| `GRYT_IDENTITY_ORIGIN` | `https://id.inferlo.xyz` |
| `GRYT_KEYCLOAK_PORT` | Free loopback port, default `18080` |
| `GRYT_IDENTITY_PORT` | Free loopback port, default `18081` |

For different domains, change the corresponding Caddy blocks and client
configuration too. The realm template allows the Inferlo app origin; if using
another web domain, update the client's redirect URI/origin allowlist in
Keycloak before testing it. Do not change the issuer or realm after creating
accounts without a migration plan.

Keep these defaults for the documented setup: realm `gryt`, client/audience
`gryt-web`, certificate lifetime `30`, account-key gate `learn`, and
`GRYT_IMPORT_REALM=0`. Leave `GRYT_CA_PRIVATE_KEY_FILE` empty to use the
persistent key provisioned by initialization. Never delete its volume to fix
a startup error.

The client-facing variables in `.env` are a reference: they are not applied to
an existing client automatically. Follow [clients](clients.md).

## OAuth callbacks and Web Origins

Fresh initialization includes the exact official Desktop 1.15.12 callback
`https://gryt.chat/auth/callback` and renderer Origin `http://127.0.0.1:15738`.
Development callbacks on localhost ports 3666/3667, the custom `gryt://` callback,
and the Inferlo web app settings remain available. See
[Desktop callback limitations](clients.md#desktop-callback), including the
ongoing dependency on `gryt.chat`.

Additional exact callback URLs and HTTP(S) Origins can be supplied as JSON arrays
in `.env`. Example for a custom web client and a different Electron renderer port:

```dotenv
GRYT_OIDC_EXTRA_REDIRECT_URIS='["https://custom.example.net/auth/callback"]'
GRYT_OIDC_EXTRA_WEB_ORIGINS='["https://custom.example.net","http://127.0.0.1:20000"]'
```

Origins have no path or trailing slash. Inspect the actual client request's
`redirect_uri` and `Origin`; do not infer the callback from the renderer port.
Wildcards are rejected in these additions. `GRYT_AUTH_CALLBACK_URL` describes
client runtime configuration and does not itself register a Keycloak callback.

For an **existing realm**, review and explicitly apply the client-only update
from the Identity project directory using current administrator credentials:

```bash
docker compose run --rm --no-deps keycloak-client-access --dry-run
docker compose run --rm --no-deps keycloak-client-access
```

Expected: the dry run shows before/after allowlists; the apply command prints
`gryt-web callback and Web Origins configured; accounts preserved.` It reads
back the settings to verify the update. Existing custom allowlist entries are
preserved; only the legacy `http://127.0.0.1:*` entry is removed from both lists.
No realm replacement, user deletion, CA change or Gryt restart is involved.
Review retained entries separately if the realm has other permissive settings.
A normal startup does not apply the update. Explicit initialization runs it,
and fresh realm creation incorporates the additional addresses too.

Removing an address from `.env` does not revoke a previously added address.
For rollback, restore the reviewed prior allowlists in the Keycloak Admin
Console, under `gryt` → Clients → `gryt-web`; avoid restoring the ineffective
wildcard. Retest with a disposable account. See [rollback](rollback.md) for
integration rollback and [backup and recovery](backup-and-recovery.md) for
recovery procedures. Never reimport a realm to adjust these lists.

## Proxy trust

Inspect the isolated network after initialization:

```bash
docker network inspect inferlo-identity --format '{{json .IPAM.Config}}'
```

This shows the subnet/gateway, not proof of the peer address seen by the
application. For host-network Caddy connecting to Docker-published ports, the
gateway is a common source address. Confirm the connection's peer on your
host, for example with your normal packet-capture tools during a request from
Caddy; then set both variables to the confirmed proxy address:

```dotenv
GRYT_KEYCLOAK_TRUSTED_PROXIES=CONFIRMED_PROXY_IP
GRYT_PAIRING_TRUSTED_PROXIES=CONFIRMED_PROXY_IP
```

To check the peer with packet capture, install tcpdump if needed and run:

```bash
IDENTITY_IP=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' inferlo-identity-service)
sudo tcpdump -n -i any "dst host $IDENTITY_IP and tcp dst port 3000"
```

In another terminal, request `https://id.inferlo.xyz/health`. Read the source IP
on traffic to the container, then stop capture with Ctrl-C. Repeat for
`inferlo-identity-keycloak`, destination port 8080, while requesting public
OIDC discovery. Use each confirmed source in its respective setting. Packet
capture needs administrator access on the deployment host; it is an operator
verification, not something repository setup runs automatically.

Replace the placeholder; do not paste it literally. The Caddy snippet replaces
`CF-Connecting-IP` with the visitor address so the relay can enforce per-client
limits. Leave it in place. Trusting all Docker peers or passing the visitor's
own forwarding header would weaken this boundary.

Apply changes from the Identity directory:

```bash
docker compose up -d --no-deps --wait keycloak identity
```

This can briefly interrupt authentication; it does not recreate Gryt or its SFU.

## Email verification and password recovery

Without SMTP, initialization disables these two features explicitly. When a
provider is chosen, fill `GRYT_SMTP_HOST`, `GRYT_SMTP_PORT` (usually `587`),
`GRYT_SMTP_FROM`, and credentials if the provider requires authentication.
Optional display names and reply-to addresses are also in `.env.example`.
The current job requires STARTTLS; implicit-TLS-only providers need additional
implementation. Example values:

```dotenv
GRYT_SMTP_HOST=smtp.example.net
GRYT_SMTP_PORT=587
GRYT_SMTP_FROM=identity@example.net
GRYT_SMTP_FROM_NAME='Inferlo Identity'
GRYT_SMTP_USER=YOUR_SMTP_USERNAME
GRYT_SMTP_PASS='YOUR_SMTP_PASSWORD'
```

Then run:

```bash
docker compose run --rm --no-deps keycloak-smtp
```

Expected: `SMTP updated; accounts preserved.` Send a test email through the
Keycloak realm's email settings, then test verification and password recovery
with a disposable account. Updating `.env` alone does not apply mail settings.
Never replace the realm to change SMTP.

## Backups

Choose `GRYT_AUTH_BACKUP_DIR` (default `./backups`),
`BACKUP_RETAIN_DAYS` (default `30`) and quoted `BACKUP_CRON` (default
`"0 */6 * * *"`, in the container's timezone). Schedule CA and off-host copies
as described in [backup and recovery](backup-and-recovery.md).

## Later changes

Container environment changes take effect after `docker compose up -d` recreates
the affected service. Use the SMTP job for mail, client-policy/device-grant jobs
for their explicit settings, and Keycloak Admin Console for live account or
realm administration. Re-running initialization skips an existing realm and
does not overwrite all its settings from the JSON template.
