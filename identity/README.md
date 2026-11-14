# Gryt Identity Service

Vendored certificate authority and pairing relay. It validates Keycloak tokens,
binds account subjects to device public keys and publishes its CA JWKS.

- [Architecture, APIs, build and tests](../docs/DEVELOPMENT.md)
- [Configuration and explicit initialization](../docs/SETUP.md)
- [Backup and recovery](../docs/OPERATIONS.md#backups-and-recovery)
- [Upstream attribution and local patches](VENDOR.md)

Normal startup refuses missing/corrupt/unreadable CA material; it does not
silently provision a replacement key.
