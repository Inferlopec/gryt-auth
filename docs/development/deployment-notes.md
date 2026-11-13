# Optional separate-VM deployment

The primary documented installation is the existing single host with Caddy,
Gryt shared services and one or more Gryt servers. Operators start with
[installation](../operator/installation.md). This page preserves the optional
auth-on-another-VM layout; it is not the normal installation path.

Use a dedicated auth VM only if deliberately chosen, for example when the
existing host cannot be expanded. Capacity planning originally suggested
4 vCPU, 8 GiB RAM and 40–60 GiB disk. These are targets, not guarantees or
minimum protocol requirements.

Provision an encrypted private connection between the existing Caddy host and
the auth VM (for example WireGuard). Use actual private addresses and restrict
reachability to Caddy. Ordinary private-subnet HTTP is not transport encryption;
provision TLS if not using an encrypted tunnel.

On the auth VM, set GRYT_PRIVATE_BIND_ADDRESS to its tunnel interface address:

```bash
export COMPOSE_FILE=docker-compose.yml:config/compose.private.yaml
scripts/initialize.sh
docker compose up -d --wait
```

The override needs Compose >=2.24.4 and replaces loopback publications with the
selected private interface. Reuse the same COMPOSE_FILE for every subsequent
operation. This is still the source-based initializer, not a release installer.
Host-loopback helpers such as users.sh/jwks_snapshot.sh assume the base layout;
their addresses must be adapted and tested for the private-bind layout before
calling this a supported operator package.

Review caddy-snippet-vm.txt and replace its example upstream address on the
Caddy machine. WireGuard does not automatically forward interface ports to
127.0.0.1. Confirm the actual source seen inside each auth container and set
Keycloak/Identity proxy trust accordingly. Keep PostgreSQL and management
ports unpublished. DNS/TLS, client and recovery checks are the same as in
[operator readiness](../operator/readiness.md); this topology is not yet
verified on real infrastructure.
