# Repository guide for agents

## Read first

- README.md: user entry point and current download status.
- docs/development/implementation-status.md: current implementation and open work.
- docs/qa/known-issues.md: canonical issue register. Record every new bug here
  and update its status, evidence and remaining acceptance checks with each fix.
- specification.md: requirements and the owner's recorded infrastructure audit.
- docs/development/architecture.md and upstream-revisions.md: identity semantics,
  component pins and compatibility boundaries.
- docs/development/testing.md: validation commands and isolated fixture lifecycle.

## Deployment model

The primary operator already has one Linux host running Caddy, shared Gryt
services (including SFU), and at least one Gryt server. Add one independent
Identity stack; connect existing/new servers to it individually. Each server
retains its own database, ownership, roles, bans and media worker. Do not
propose reinstalling Gryt or duplicating shared containers as the normal path.

Do not access production or request SSH for repository implementation. Keep
DNS, Caddy, firewall, current Gryt containers/images/data and identity migrations
outside automatic execution. Produce reviewed operator instructions instead.
Explicit user instructions about a deployment action take precedence.

## Documentation and distribution

All implementation docs, comments, scripts and templates are written in English.
Use docs/operator/ for task-oriented instructions with prerequisites, concrete
commands, expected results and recovery links. Use docs/development/ for
architecture, test evidence, upstream work and release engineering. Keep the
root README short and focused on the operator.

The intended GitHub URL is https://github.com/Inferlopec/gryt-auth. It is not
published yet. Do not invent successful downloads, releases, tags, GHCR images
or CI results. Update status pages when publication actually happens.

Keep source/tests/lock files/specification/agent docs in Git. The planned
operator archive is built with an explicit allowlist, not .gitignore; see
docs/development/releases.md. Current initialization still requires source
folders, so it cannot yet support a thin prebuilt-image package.

## Identity invariants

- Keep realm gryt, public issuer and CA origin stable after account creation.
- Retain existing trusted issuer order; append additional issuers. First issuer
  ownership of the legacy namespace must not be changed incidentally.
- Normal startup/initialization must preserve users and existing CA material.
- Never regenerate a corrupt/unreadable CA as a startup fallback.
- Keep registration closed and account-key gate learn unless explicitly changed.
- Disable/delete/password reset is not immediate revocation of old certificates.

Inspect the selected upstream revision before introducing environment variables,
CLI commands or protocol changes. Record local vendored patches in VENDOR.md.
Keep Keycloak and pairing extension versions coupled. Do not upgrade the
existing production Gryt version to make a compatibility test easier.

## Validation

Run checks appropriate to the change. For auth/recovery behavior use the
isolated tests/run_all.sh --with-gryt suite; never production keys or databases.
A missing Docker dependency or unexecuted test is not PASS. Keep protocol test
results distinct from graphical Web/Desktop and production acceptance.

For documentation-only changes, check links, file references, command syntax,
upstream command semantics and git diff --check; a full stack run is unnecessary.
Preserve unrelated user work and untracked specification/tests when editing.
