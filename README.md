# Inferlo Identity

One Keycloak account across Gryt servers that trust your Identity CA. Install
one independent auth stack alongside existing Caddy/Gryt services; each server
keeps its own members, roles, bans, data and media worker.

Source-based installation is available. Isolated protocol/recovery tests passed;
production acceptance remains open. Updated Desktop source supports the `gryt://`
callback; the exact Gryt-hosted HTTPS callback remains allowed for older releases.
Graphical acceptance awaits an updated Desktop release. See
[readiness and limits](docs/OPERATIONS.md#production-readiness).

## Quick start

With the [host prerequisites](docs/SETUP.md#prerequisites) satisfied:

```bash
git clone https://github.com/Inferlopec/gryt-auth.git
cd gryt-auth
cp .env.example .env
chmod 600 .env
```

Fill in secrets and URLs using [.env.example](.env.example), then follow
[SETUP](docs/SETUP.md) to build/initialize, configure HTTPS, connect one server
and verify clients. Do not initialize with an incomplete configuration.

- [SETUP](docs/SETUP.md): installation, integration and client verification.
- [OPERATIONS](docs/OPERATIONS.md): accounts, updates, recovery and troubleshooting.
- [DEVELOPMENT](docs/DEVELOPMENT.md): architecture, APIs, builds and tests.
- [GitHub Issues](https://github.com/Inferlopec/gryt-auth/issues): defects and acceptance work.

Gryt sources are covered by the [upstream license](LICENSES/gryt-auth.txt).
[VENDOR.md](VENDOR.md) records attribution, revisions and local changes.
