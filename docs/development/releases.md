# Operator distribution contract

This describes work to implement next. There is currently no release workflow,
operator archive or published project image. Intended repository:
`https://github.com/Inferlopec/gryt-auth`.

## Separate three deliverables

The Git repository contains source, tests, agent/development docs, lock files,
configuration templates and build tooling. An operator downloads a curated
release asset; they do not need the repository to use a finished release.
Project container images are delivered through GHCR. PostgreSQL and other
standard dependencies currently come from their official image registries;
that still requires registry network access. An offline distribution, if
needed later, must explicitly bundle every required image.

## Intended operator archive

```text
inferlo-identity/
├── README.md
├── compose.yaml
├── .env.example
├── VERSION
├── images.json
├── scripts/
├── bootstrap/
├── realm/
├── config/
├── docs/operator/
└── LICENSES/
```

Use a versioned name such as `inferlo-identity-VERSION.tar.gz`, accompanied by
SHA256SUMS. VERSION denotes the real published tag. Record source revision,
image digests and supported architecture(s) in machine-readable metadata.
Generate the operator-facing README so it has no missing development links.

Build the manifest from explicit file paths; do not package `git ls-files` or
an entire directory tree and rely on .gitignore. The archive must exclude
.env, secrets, backups, data volumes, local state, tests, agent instructions,
development docs and project source/build caches. Runtime bootstrap Python and
shell files remain necessary even when application images are prebuilt.

The release Compose must have image references instead of local build contexts
and must use matching immutable Identity and Keycloak-with-provider images.
Embed the compiled JAR in the release Keycloak image to avoid host-side Maven
builds/bind-mount mistakes. Preserve the source-mode Compose for development.

## Required package checks

Extract the archive in a clean temporary directory without the repository,
provide throwaway env values and validate Compose and all referenced mounts.
Confirm initialization does not try to read pom.xml, build.sh, identity/ or
other excluded paths. Re-run initialize/start/SMTP/backup/restore through the
package itself in an isolated project. Verify secrets/build caches never enter
the archive and check checksums/executable permissions.

Archive docs must describe commands supported by that exact package, not
source-build commands copied from the current snapshot. Include license
notices and a precise source reference for distributed upstream/modified code.

## Publication

Prepare and validate artifacts before publication. The first release should
remain a prerelease while the production checklist is open. After owner
publication authorization, publish images and attach the curated archive and
checksums to the matching GitHub release. Make public image accessibility part
of the install test. Publishing should not change production infrastructure.

Source: [GitHub release assets](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)
and [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry).
