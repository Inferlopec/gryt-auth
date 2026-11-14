# Agent instructions

Read [README](README.md), [DEVELOPMENT](docs/DEVELOPMENT.md) and the relevant
[SETUP](docs/SETUP.md)/[OPERATIONS](docs/OPERATIONS.md) sections before changes.
[specification.md](specification.md) retains requirements and the historical
owner audit; it is not a current host-health report.

- Keep docs/comments in English. Maintain the three guides above; configuration
  definitions belong in `.env.example`, upstream pins/patches in `VENDOR.md` and
  component VENDOR files. Do not create parallel status/configuration guides.
- Use [GitHub Issues](https://github.com/Inferlopec/gryt-auth/issues) as the issue
  register. Record new bugs and update evidence, remaining checks and status
  with fixes. Use GitHub issue numbers as primary identifiers.
  Preserve legacy IDs only for historical traceability. FIXED remains open
  until acceptance is verified. Do not recreate a local issue register.
- Normal deployment adds one Identity stack to existing Caddy/shared Gryt/SFU;
  connect servers individually. Preserve their images, data and shared services.
  Do not access production or request SSH. DNS, proxy/firewall changes and
  identity migrations are operator actions unless explicitly authorized.
- Preserve realm, public issuer, CA origin/key, existing users and trusted issuer
  order. Append issuers; the first owns the legacy namespace. Never generate a
  replacement for a corrupt/unreadable CA. Keep registration closed and the
  account-key gate in `learn` unless explicitly changed. Account disable/delete/
  reset does not immediately revoke certificates.
- Inspect pinned upstream before protocol/options changes; preserve and record
  vendored patches. Couple Keycloak/provider versions. Do not upgrade production
  Gryt to pass compatibility checks. Keep source/tests/lock files and attribution.
- Auth/recovery changes require isolated `tests/run_all.sh --with-gryt`; never
  production keys/DBs. Missing dependencies/unexecuted checks are not PASS.
  Distinguish protocol evidence, graphical clients and production acceptance.
  Docs-only: verify links, commands/source semantics and `git diff --check`.
- Preserve unrelated work. Do not claim releases, images, CI or production
  readiness without evidence, or document unimplemented deployment workflows.
- Development uses direct commits, not pull requests.
  Reference issues in commit messages (`#123`).
  Do not automatically close issues requiring manual verification.
