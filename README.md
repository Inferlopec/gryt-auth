# Inferlo Identity Stack

Self-hosted authentication for the **Inferlo Gaming** Gryt server.

| Component | Image | Role |
|---|---|---|
| `keycloak` | `quay.io/keycloak/keycloak:26.5.3` | OIDC identity provider, realm `inferlo` |
| `identity` | built from `./identity` (Node 22, Hono, jose) | Gryt Identity Service — certificate authority that binds EC P-256 device keys to Keycloak users |
| `postgres` | `postgres:16-alpine` | Keycloak database |
| `pg-backup` | `postgres:16-alpine` | Cron backups of the Keycloak DB (every 6 h, keep 30 days) |
| one-shots | — | realm import, master admin bootstrap, security policy |

## Architecture

```
                    Caddy (host network, /opt/caddy)
   auth.inferlo.xyz ──► 127.0.0.1:18080 ──► keycloak:8080
   id.inferlo.xyz   ──► 127.0.0.1:18081 ──► identity:3000

Desktop client
  ├─► Keycloak (OIDC + PKCE)          → access token
  ├─► Identity Service (CA)           → signed JWT certificate (30 days)
  └─► Gryt server (challenge-response, verified against id.inferlo.xyz JWKS)
```

How it works (short version): the client logs into Keycloak, then presents its
access token together with a locally generated EC P-256 public key to the
Identity Service. The service issues a signed certificate binding the Keycloak
`sub` to that key. The Gryt server verifies certificates against the CA's JWKS
endpoint and runs a challenge-response join — it never sees a reusable token.
See [Gryt security docs](https://docs.gryt.chat/docs/about/security).

Key properties:

- **Pure add-on.** Nothing in the existing Gryt / Caddy / firewall setup is
  modified by this stack. Ports are published on `127.0.0.1` only, so the
  firewall (`gryt-port-filter.service`) needs no changes.
- **Admin-only registration.** `registrationAllowed=false`. Users are created
  with `scripts/users.sh`.
- **No SMTP on day one.** `verifyEmail` and `resetPasswordAllowed` are off;
  passwords are set directly by the admin.

## Files

```
docker-compose.yml            the whole stack
.env / .env.example           secrets and URLs (generated on LOT 1)
realm/inferlo-realm.json      realm definition (imported once, GRYT_IMPORT_REALM=1)
bootstrap/import_realm.sh     one-shot: kc.sh import (refuses to run while keycloak is up)
bootstrap/bootstrap_admin.sh  one-shot: ensure master admin exists
bootstrap/apply_security_policy.sh  one-shot: brute-force lockout, password policy,
                                    failed sign-in log (idempotent, re-runnable)
scripts/users.sh              user management via Admin REST API
identity/                     copied from https://github.com/Gryt-chat/auth (AGPL-3.0)
backups/                      pg-backup output (keycloak-*.sql.gz)
caddy-snippet.txt             Caddyfile blocks for auth./id. subdomains
```

## Setup (LOT 1-4 reference)

### LOT 1 — files and secrets

```bash
mkdir -p /opt/inferlo-identity
tar xzf gryt-auth-lot1.tgz -C /opt/inferlo-identity
cd /opt/inferlo-identity
chmod +x bootstrap/*.sh scripts/*.sh
mkdir -p backups

# secrets
KC_ADMIN_PW=$(openssl rand -base64 24)
PG_PW=$(openssl rand -base64 24)
sed -e "s|^GRYT_KEYCLOAK_ADMIN_PASSWORD=.*|GRYT_KEYCLOAK_ADMIN_PASSWORD=${KC_ADMIN_PW}|" \
    -e "s|^GRYT_AUTH_POSTGRES_PASSWORD=.*|GRYT_AUTH_POSTGRES_PASSWORD=${PG_PW}|" \
    .env.example > .env
chmod 600 .env

# Identity Service source (AGPL-3.0)
git clone --depth 1 https://github.com/Gryt-chat/auth.git /tmp/gryt-auth-src
cp -r /tmp/gryt-auth-src/identity /opt/inferlo-identity/identity
rm -rf /tmp/gryt-auth-src

docker compose config --quiet && echo "COMPOSE OK"
```

### LOT 2 — Caddy + first start + realm import

```bash
cp /opt/caddy/Caddyfile /opt/caddy/Caddyfile.bak-$(date +%F)
# append the two site blocks from caddy-snippet.txt to /opt/caddy/Caddyfile
docker exec inferlo-caddy caddy reload --config /etc/caddy/Caddyfile
# (a 500 from Keycloak is fine before the import — Caddy just needs to reach 18080)

cd /opt/inferlo-identity
GRYT_IMPORT_REALM=1 docker compose up -d   # import + bootstrap + start keycloak + identity + backups
docker compose logs keycloak-import keycloak-bootstrap-admin
# once keycloak is healthy:
docker compose up -d keycloak-security-policy
docker compose ps
```

### LOT 3 — wire the Gryt server (brief container recreate only)

Add to the Gryt CLI profile `extraEnv` (survives `gryt` updates):

```bash
cd ~/.config/gryt/servers/inferlo-gaming
cp .env .env.bak-$(date +%F)
python3 - <<'EOF'
import json
p = "profile.json"
d = json.load(open(p))
d.setdefault("extraEnv", {}).update({
    "GRYT_OIDC_ISSUER": "https://auth.inferlo.xyz/realms/inferlo",
    "GRYT_OIDC_AUDIENCE": "gryt-web",
    "GRYT_TRUSTED_CERT_ISSUERS": "https://id.gryt.chat,https://id.inferlo.xyz",
})
json.dump(d, open(p, "w"), indent=2)
EOF
gryt env inferlo-gaming | grep -E 'OIDC|TRUSTED'   # verify
# restart the gryt stack as you normally do (CLI / compose up -d)
```

`GRYT_TRUSTED_CERT_ISSUERS` lists both CAs, so accounts from the official
`id.gryt.chat` and from your own `id.inferlo.xyz` are both accepted
(`GRYT_IDENTITY_TIERS=account,local` stays as is).

### LOT 4 — first user + smoke test

```bash
cd /opt/inferlo-identity
scripts/users.sh create_user inferlo '<strong-password>'
scripts/users.sh list_users

# smoke tests
curl -fsS https://id.inferlo.xyz/health
curl -fsS https://id.inferlo.xyz/.well-known/jwks.json
curl -fsS https://auth.inferlo.xyz/realms/inferlo/.well-known/openid-configuration | head
```

Then in the desktop client: **Settings → Account & security** → set the issuer
to `https://auth.inferlo.xyz` (realm `inferlo` is derived automatically),
log in with the new user, and join the server.

## Day-2 operations

### User management

```bash
cd /opt/inferlo-identity
scripts/users.sh create_user <username> <password>      # create, or reset password
scripts/users.sh set_user_disabled <username> true|false
scripts/users.sh list_users
```

### Backups

`backups/keycloak-*.sql.gz` — every 6 hours, 30-day retention. Each dump is
verified (pg_dump exit code + size floor + `gzip -t`) before old ones are
pruned. **Also back up the CA key** — it lives in the `inferlo-identity-data`
volume:

```bash
docker run --rm -v inferlo-identity_inferlo-identity-data:/data alpine \
  tar czf /dev/stdin -C /data . > ca-key-$(date +%F).tar.gz
```

Restoring accounts: stop the stack, restore the dump into postgres, start.
Restoring the CA key: extract the tarball into the volume. Until you restore
it, previously issued certificates stop validating.

### Re-importing the realm (rare, destructive)

`GRYT_IMPORT_REALM=1` runs `kc.sh import --override true`, which **deletes the
realm and every user in it**. Take a fresh pg backup first. The import refuses
to run while the keycloak container is up.

### Upgrades

```bash
cd /opt/inferlo-identity
# bump the keycloak image tag in docker-compose.yml, then:
docker compose pull keycloak keycloak-import keycloak-bootstrap-admin
docker compose up -d
docker compose up -d keycloak-security-policy   # re-apply (safe)
# identity service: re-clone Gryt-chat/auth, replace ./identity, then:
docker compose build identity && docker compose up -d identity
```

### Uninstall (reversible)

```bash
cd /opt/inferlo-identity
docker compose down            # keep volumes
# remove the two Caddy site blocks, caddy reload
# remove GRYT_OIDC_* / GRYT_TRUSTED_CERT_ISSUERS from the gryt profile, restart gryt
# full removal: docker compose down -v && rm -rf /opt/inferlo-identity
```

## Security notes

- `KC_HOSTNAME_STRICT=true` — Keycloak rejects requests whose Host header does
  not match `auth.inferlo.xyz`; Caddy terminates TLS.
- Brute-force lockout: 8 failures → 60 s, doubling to 15 min, cleared after
  12 h. Password policy: `length(12) and notUsername and notEmail`
  (checked when a password is set).
- Failed sign-in events are kept for 30 days (failure types only).
- The Keycloak admin console is at `https://auth.inferlo.xyz/admin`
  (master admin from `.env`). Consider restricting it by IP later.
- `GRYT_ACCOUNT_KEY_GATE=learn` — the CA records each account's seed key.
  Switch to `enforce` only after all devices are linked.
