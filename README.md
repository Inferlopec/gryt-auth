# Inferlo Identity

One Inferlo account for multiple Gryt servers. Each server keeps its own
members, roles, bans and message history.

This project adds authentication to a host that already runs **Caddy, Gryt
shared services and at least one Gryt server**. Install Identity once, then
connect each existing or new Gryt server to it.

**Status:** isolated login, multi-server identity and recovery tests pass.
Real Web/Desktop acceptance and production security setup are still pending.
See [what is ready and what remains](docs/operator/readiness.md).

## Operator instructions

| I want to… | Read |
|---|---|
| Download the right files | [Download](docs/operator/download.md) |
| Install alongside my existing Gryt setup | [Install](docs/operator/installation.md) |
| Fill in domains, passwords, mail and backups | [Configuration](docs/operator/configuration.md) |
| Connect an existing Gryt server | [Existing server](docs/operator/existing-server.md) |
| Add another server using the same Identity and SFU | [New server](docs/operator/new-server.md) |
| Set up a Web or Desktop client | [Clients](docs/operator/clients.md) |
| Create, disable, reset or delete a user | [Users](docs/operator/users.md) |
| Start, stop, inspect or update Identity | [Maintenance](docs/operator/maintenance.md) |
| Back up or recover accounts and keys | [Backup and recovery](docs/operator/backup-and-recovery.md) |
| Diagnose a problem | [Troubleshooting](docs/operator/troubleshooting.md) |
| Undo the integration | [Rollback](docs/operator/rollback.md) |

The intended GitHub repository is `https://github.com/Inferlopec/gryt-auth`.
It has not been created yet; no operator release or project images are
published. [Download](docs/operator/download.md) distinguishes today's source
snapshot from the planned ready-made operator package.

## Development and agents

Start with [AGENTS.md](AGENTS.md) and the
[development documentation](docs/development/README.md). Architecture, tests,
upstream pins and release engineering live there; operators can follow the
instructions above without reading them.

Gryt components are based on AGPL-3.0 upstream sources. Attribution and local
patches are recorded in [Identity VENDOR.md](identity/VENDOR.md) and
[Pairing VENDOR.md](keycloak-pairing/VENDOR.md).
