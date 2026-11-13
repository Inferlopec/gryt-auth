# Connect an existing Gryt server

Prerequisite: [installation](installation.md) is complete and both public auth
endpoints pass their HTTPS checks. This procedure changes one server's trust
list. It does not move users, copy its database or change its image version.

The file layout and service name below were checked against Gryt CLI 0.8.1.
If your generated Compose differs, inspect it first; do not overwrite it with
these examples. The installed server image must support issuer-scoped account
identities; see [readiness](readiness.md) before applying this to production.

## 1. Identify the server and save its configuration

```bash
gryt version
gryt list
SERVER_ID=inferlo-gaming
SERVER_DIR="$HOME/.config/gryt/servers/$SERVER_ID"
SERVER_CONTAINER="gryt-$SERVER_ID"
SERVER_PROJECT=$(docker inspect --format '{{ index .Config.Labels "com.docker.compose.project" }}' "$SERVER_CONTAINER")
```

Use the actual server ID. If `GRYT_CONFIG_DIR` is customized, adjust
`SERVER_DIR`. Confirm that `SERVER_PROJECT` is nonempty and matches the existing
project before using it below. Record the running image and protect a copy of
`profile.json`, `.env` and `compose.yaml` in a new backup directory:

```bash
umask 077
CONFIG_BACKUP="$HOME/gryt-config-$SERVER_ID-$(date +%Y%m%dT%H%M%S)"
mkdir "$CONFIG_BACKUP"
cp -p "$SERVER_DIR/profile.json" "$SERVER_DIR/.env" "$SERVER_DIR/compose.yaml" "$CONFIG_BACKUP/"
docker inspect --format '{{.Image}}' "$SERVER_CONTAINER" > "$CONFIG_BACKUP/image-id.txt"
```

These files can contain secrets. Also retain the Gryt server's normal data
backup before making production changes.

## 2. Add Inferlo trust in two places

Open `profile.json` and merge the following into its existing `extraEnv`
object. Keep all other profile fields and extraEnv settings:

```json
{
  "GRYT_TRUSTED_CERT_ISSUERS": "https://id.gryt.chat,https://id.inferlo.xyz",
  "GRYT_IDENTITY_TIERS": "account,local"
}
```

This example assumes the existing trust is the official CA and existing tiers
are `account,local`, as in the audited Inferlo server. If you already trust
other issuers, retain their exact order and append Inferlo once. Preserve your
existing tier policy. Putting Inferlo first can change existing account IDs.

Make the same two effective settings in that server's generated `.env`,
editing existing entries instead of adding duplicates:

```dotenv
GRYT_TRUSTED_CERT_ISSUERS=https://id.gryt.chat,https://id.inferlo.xyz
GRYT_IDENTITY_TIERS=account,local
```

The profile keeps the change across future CLI regeneration; `.env` applies it
to the existing Compose deployment now. CLI 0.8.1's server service reads this
file through `env_file`. Confirm your Compose does too.

Do not change server `GRYT_OIDC_*` settings just because the Identity Service
uses OIDC. This integration uses certificate trust. Leave existing JWT secrets,
SFU settings, management tokens, volumes and image tags intact.

## 3. Review and recreate only this server

```bash
cd "$SERVER_DIR"
docker compose -p "$SERVER_PROJECT" -f compose.yaml config --quiet
gryt env "$SERVER_ID" | grep -E 'GRYT_TRUSTED_CERT_ISSUERS|GRYT_IDENTITY_TIERS'
SERVER_IMAGE_REF=$(docker compose -p "$SERVER_PROJECT" -f compose.yaml config --format json | python3 -c 'import json,sys; print(json.load(sys.stdin)["services"]["server"]["image"])')
if [ "$(docker image inspect --format '{{.Id}}' "$SERVER_IMAGE_REF")" = "$(cat "$CONFIG_BACKUP/image-id.txt")" ]; then
    docker compose -p "$SERVER_PROJECT" -f compose.yaml up -d --no-deps --pull never server
else
    printf 'Stopped: the local image reference differs from the running image. Pin the original image before continuing.\n' >&2
fi
```

The expected service name is `server`; check `docker compose ... config
--services` if different. Recreating it briefly disconnects that server's
clients. `restart` alone would not apply changed environment values.

The image comparison prevents a moved local tag from changing the running
version. A mismatch stops this step without recreating the server; review and
pin the original image before retrying. Dependencies/shared services are skipped.
Avoid `gryt pull`, `gryt pull --shared` and `gryt start` for this step: the
first two update images, while `gryt start` also regenerates/starts the shared
project. [CLI 0.8.1 behavior](https://github.com/Gryt-chat/cli/blob/v0.8.1/internal/start/start.go).

## 4. Verify before attaching another server

Check this server's normal HTTPS health endpoint and confirm its image ID is
unchanged. Sign in using the configured [client](clients.md) and an Inferlo
[test account](users.md). Use an invitation if the server requires one.

Verify an existing official/local owner still has the same ownership, roles,
bans and history. A new Inferlo account is a new server identity; adding trust
does not grant it existing membership or administrator rights.

If verification fails, restore the saved profile and `.env`, recreate only
this server with the same image-checked command, and follow [rollback](rollback.md).
