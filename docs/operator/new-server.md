# Add another Gryt server

Use this when Identity, Caddy, the shared Gryt SFU and at least one server are
already working. You need one new Gryt profile/data directory and a public
chat address. Reuse the same auth/id endpoints and the existing SFU; do not
install another Identity stack.

The creation flags below were checked against
[Gryt CLI 0.8.1](https://github.com/Gryt-chat/cli/blob/v0.8.1/cmd/gryt/main.go).
Run `gryt create --help` on the installed version first. This guide assumes
host-network Caddy, as in [installation](installation.md).

## 1. Choose a name, port and domain

Example: server ID `inferlo-community`, free TCP port `5001`, chat domain
`community.inferlo.xyz`. Replace them if already in use.

```bash
gryt list
ss -ltn
```

Keep the existing public SFU address, for example `wss://sfu.inferlo.xyz`.
This is different from the new chat address.

## 2. Create the profile without starting shared services

```bash
gryt create --name inferlo-community --host 127.0.0.1 --port 5001 --security community --proxy-hops 1 --domain wss://sfu.inferlo.xyz --yes
```

On CLI 0.8.1, `create` writes the new profile and Compose files without starting
containers. The `--domain` flag contributes to the profile's public SFU
endpoints in this version; check the generated `SFU_PUBLIC_HOST`. The chat
hostname is configured in Caddy below. `community` allows account and local
identities; choose another policy deliberately if needed.

The default Linux location is:

```text
~/.config/gryt/servers/inferlo-community/
├── profile.json
├── .env
└── compose.yaml
```

## 3. Set this server's Identity and SFU configuration

Merge the trust settings from [existing server, step 2](existing-server.md#2-add-inferlo-trust-in-two-places)
into this new profile's `extraEnv` and `.env`. Use exactly the same CA order as
your other servers, including the official issuer first when preserving its
legacy namespace. Each server still decides membership, roles and bans.

Compare the new `.env` with the working server privately. The new server must
use the same `SFU_WS_HOST` and an appropriate public `SFU_PUBLIC_HOST`; preserve
any SFU authentication settings required by your installed deployment. Keep
its own JWT secret, management token, ports and data directory. Do not copy
the working server's entire profile or database.

Inspect the new Compose images and pin its server, data-init and image-worker
images to the reviewed versions already installed on this host. In particular,
use the same server image for `server` and `data-init`. Inspect running image
IDs/digests rather than assuming a mutable `latest` tag still names them. For
the audited existing server:

```bash
docker inspect gryt-inferlo-gaming --format '{{.Image}}'
docker inspect gryt-inferlo-gaming-image-worker --format '{{.Image}}'
```

Use `docker image inspect IMAGE_ID --format '{{json .RepoDigests}}'` with each
actual ID to find its immutable registry reference. Record that reference in
the new Compose file's corresponding image entries. If no registry digest is
available, use a reviewed locally tagged image and confirm its image ID.
Confirm the generated external network is the existing `gryt` network.

## 4. Start only the new server project

```bash
cd "$HOME/.config/gryt/servers/inferlo-community"
docker compose -p gryt-inferlo-community -f compose.yaml config --quiet
docker compose -p gryt-inferlo-community -f compose.yaml up -d --pull never
docker compose -p gryt-inferlo-community -f compose.yaml ps
```

This starts the new server and its own media worker/data initialization using
local images. It does not start a new SFU or operate the existing shared
project. If an image or external network is missing, investigate before
continuing; do not recreate shared infrastructure to get past the error.
The media worker is per server because it uses that server's data.

## 5. Add the chat route to existing Caddy

Create DNS for the new chat hostname and add this site block to the existing
Caddyfile after backing it up:

```caddyfile
community.inferlo.xyz {
    reverse_proxy 127.0.0.1:5001
}
```

Validate/reload Caddy as in [installation](installation.md#4-configure-dns-and-the-existing-caddy).
Do not duplicate the auth, id or SFU site blocks.

## 6. Verify access and ownership

Verify `https://community.inferlo.xyz/health`, then join with the same Inferlo
account used on the first server. On the checked upstream server, the first
successful joining user becomes owner; arrange the first login before
advertising the new server. Later users need the configured membership or
invitation flow. Test that a role or ban here does not alter another server.

If a self-hosted web client is used, add its origin to this server's existing
`CORS_ORIGIN` allowlist and preserve other required origins. Adding this Gryt
server does not require a new Keycloak realm, client or CA.
