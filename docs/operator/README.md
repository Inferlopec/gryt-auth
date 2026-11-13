# Operator guide

Start with [download](download.md), [installation](installation.md) and
[configuration](configuration.md). Then connect your
[existing Gryt server](existing-server.md) and configure a [client](clients.md).

Once that works, use [new server](new-server.md) to attach additional Gryt
servers to the same Identity installation and shared SFU.

For everyday tasks: [users](users.md), [maintenance](maintenance.md),
[backups](backup-and-recovery.md) and [troubleshooting](troubleshooting.md).
[Readiness](readiness.md) lists the remaining checks before public use;
[rollback](rollback.md) explains how to withdraw the integration.

Commands assume Bash on the existing Linux host. Run Gryt CLI commands as the
same Unix user who owns the existing Gryt profiles. Run Identity commands from
`/opt/inferlo-identity`, unless a command explicitly changes directories.
Examples use Inferlo domains; replace them together if using different names.
