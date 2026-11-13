# Maintain Identity

Run these from `/opt/inferlo-identity`. They operate the separate Identity
Compose project, not the existing Gryt/shared project.

## Inspect services and logs

```bash
docker compose ps
docker compose logs --tail 100 keycloak identity postgres pg-backup
```

Expected: PostgreSQL, Keycloak and Identity Service are healthy; pg-backup is
running. Avoid sharing logs or full `docker compose config` output publicly
without removing secrets.

## Start, restart or apply a setting

```bash
docker compose up -d --wait
```

This starts services and recreates those whose configuration changed. Normal
startup neither imports the realm nor generates a replacement CA. For a
simple process restart without configuration changes:

```bash
docker compose restart identity
```

Use [configuration](configuration.md) for SMTP or realm/client policy changes.
Restarting a container alone does not apply a changed environment value.

## Stop without deleting accounts

```bash
docker compose down
```

This stops Identity and removes its service containers/network. Its volumes
remain. Existing Gryt certificates may still work while auth is offline;
account login, renewal and pairing will be unavailable. Do not add `-v`, prune
volumes or delete the CA directory during routine maintenance.

## Update the current source installation

No operator release is published yet. Obtain a reviewed source snapshot from
the maintainer; keep the current `.env`, volumes and backups. Before replacing
files, take a fresh database dump and CA backup following
[backup and recovery](backup-and-recovery.md), and record the old snapshot and
image IDs. Stop Identity during a schema-changing upgrade.

Follow the snapshot's version-specific upgrade notes. At minimum, a changed
pairing extension needs its JAR rebuilt, and changed Identity code needs its
image rebuilt:

```bash
keycloak-pairing/build.sh
docker compose build identity
docker compose up -d --wait
```

If the pairing JAR was replaced, recreate Keycloak so Docker mounts the new
file (a simple restart may keep an old bind-mounted inode):

```bash
docker compose up -d --no-deps --force-recreate --wait keycloak
```

The maintainer must validate matching Keycloak/JAR versions before delivery.
Apply explicitly documented client/security policy jobs when required; never
replace the realm as an update step. A Keycloak schema upgrade may require
restoring the matching pre-upgrade database to roll back.

Verify HTTPS health, a known user's login, old-certificate trust and second-device
approval before reopening normal traffic. These commands do not upgrade Gryt,
its SFU or the per-server media workers. Future ready-made releases will carry
their own pull-based update procedure.
