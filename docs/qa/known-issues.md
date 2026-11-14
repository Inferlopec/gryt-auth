# Known issues

Updated November 14, 2026. This is the canonical issue register for
`Inferlopec/gryt-auth`. Record every newly found bug here, retain its ID, and
update its evidence, remaining work and status when implementation changes.
Keep detailed test logs in [test results](../development/test-results.md) and
operator procedures in [operator documentation](../operator/README.md).

## Status and evidence

- **OPEN:** Confirmed issue with implementation work remaining.
- **INVESTIGATE:** Observation recorded; cause or impact needs confirmation.
- **FIXED:** Implementation complete; the stated acceptance check remains.
- **VERIFIED:** Acceptance check passed; retain a short entry with evidence.

Upstream ownership is recorded under component, separately from status.
Priorities: **P0** blocks authentication; **P1** affects reliability or repeatable
setup; **P2** affects usability or operations.

Initial staging: Ubuntu 24.04, Docker Compose, Keycloak 26.5.3, Gryt Server
1.12.9, official Gryt Desktop 1.15.12 on two MacBooks. After manual Keycloak
corrections, login, certificate authentication, first-user Owner assignment,
persistence after restart and device pairing succeeded. This does not establish
production readiness or independence from Gryt-operated services.

Phase 1 repository changes passed `tests/run_all.sh --with-gryt` (exit 0):
9 main integration cases, 20 Identity unit tests, 6 archive safety tests,
4 client-access tests, CA recreation and database/CA recovery. See
[phase 1 evidence](../development/test-results.md#phase-1--bug-01-and-bug-02).
A graphical Desktop regression with these changes has not been executed.
Production was not changed.

## BUG-01 — Official Desktop callback rejected

**P0 · FIXED · Keycloak client configuration**

**Evidence:** Desktop 1.15.12 sends
`redirect_uri=https://gryt.chat/auth/callback`; the previous template rejected it
with `Invalid parameter: redirect_uri`.

**Implemented:** Added that exact callback, retaining the Inferlo web,
localhost development and `gryt://auth/callback` options. Added an explicit
`keycloak-client-access` update for existing realms with dry run and read-back,
without realm replacement. Automated code + PKCE succeeds; unregistered paths
on the official host and lookalike hosts are rejected.

**To close:** Complete graphical login on the intended Desktop release using
fresh repository initialization, without manual Keycloak allowlist edits.
Existing realms use the [client allowlist procedure](../operator/configuration.md#oauth-callbacks-and-web-origins).
The hosted callback dependency is tracked separately as ARCH-01.

## BUG-02 — Electron token response blocked by CORS

**P0 · FIXED · Keycloak Web Origins**

**Evidence:** With `http://127.0.0.1:*` configured, Keycloak processed the token
request but omitted the required CORS header for Origin
`http://127.0.0.1:15738`. Desktop reported `Failed to fetch`; adding the exact
Origin allowed login.

**Implemented:** Removed the ineffective wildcard loopback entry from redirects
and Web Origins; added the exact tested Origin. Additional exact addresses use
`GRYT_OIDC_EXTRA_REDIRECT_URIS` and `GRYT_OIDC_EXTRA_WEB_ORIGINS` JSON arrays.
The client update preserves other operator entries. Automated checks cover
successful token exchange, refresh CORS, OPTIONS and denied Origins. No proxy
CORS bypass was added.

**To close:** Confirm graphical Desktop token exchange after fresh initialization
without manual Keycloak edits. For another renderer port, configure its exact
Origin using the [documented procedure](../operator/configuration.md#oauth-callbacks-and-web-origins).

## BUG-03 — Insufficient authentication diagnostics

**P1 · OPEN · Identity Service / observability**

**Evidence:** Troubleshooting logs showed startup information without useful
request diagnostics. The original CORS failure preceded Identity Service calls;
missing logs do not prove lost requests.

**Remaining:** Add structured request IDs, endpoint, status, duration and
sanitized error categories for certificate issuance and identity verification.
Document correlation with Keycloak, proxy and Gryt Server events. Never log
tokens, authorization codes, passwords or signing keys.

**To close:** Operators can distinguish browser CORS, OAuth, certificate issuance
and server verification failures from documented diagnostics.

## BUG-04 — Preflight misses Desktop authentication incompatibility

**P1 · OPEN · Installation / preflight**

**Evidence:** Installation/preflight passed with the configurations behind
BUG-01 and BUG-02. Phase 1 now covers callback and token CORS in the isolated
suite; deployed-environment preflight validation remains missing.

**Remaining:** Validate configured callback/Web Origins, public OIDC
issuer/discovery and public Identity endpoints. Add a deployed token-CORS smoke
check. Clearly distinguish infrastructure health from graphical client acceptance.

**To close:** Diagnostics identify BUG-01/BUG-02 configuration errors before the
first Desktop login, including on an existing realm skipped by import.

## BUG-05 — Unstyled Keycloak login page

**P2 · OPEN · Keycloak themes**

**Evidence:** Login appeared as an unstyled HTML form. The realm template
explicitly selects `base` for login, account and email themes.

**Remaining:** Select maintained themes available in pinned Keycloak 26.5.3;
check login, error, account and responsive layouts. Custom branding is separate.

**To close:** Login is styled and responsive, and authentication still succeeds.

## OPS-01 — Trusted proxy setup needs clearer validation

**P2 · INVESTIGATE · Reverse proxy / deployment**

**Evidence:** The staging proxy peer appeared as Docker bridge address
`172.20.0.1`; trust settings required adjustment. This address is specific to
that deployment, not a default for other hosts.

**Remaining:** Provide ordinary diagnostics for the effective proxy peer,
validate trust settings and explain unexpected forwarded-header behavior.
Current [instructions](../operator/configuration.md#proxy-trust) require packet
capture to confirm the peer. Preserve strict trust boundaries; do not trust all
Docker networks or arbitrary forwarded headers.

**To close:** An operator can determine and verify the correct trust values
without packet capture in the documented topology.

## DOC-01 — Desktop custom authentication setup is hard to find

**P1 · OPEN · Client documentation**

**Evidence:** On a second MacBook the controls appeared only after enabling
`Settings → General → Advanced → Show advanced settings`, then opening
`Settings → Account & security → Account → Auth server`.

**Remaining:** Add these paths to the client guide, explain both issuer and
Identity Service URL fields, and state that each device needs its own settings.

**To close:** A fresh Desktop 1.15.12 installation on macOS can be configured
using the guide without inspecting source code.

## DOC-02 — Readiness and publication statements need reconciliation

**P1 · OPEN · README / deployment documentation**

**Progress:** The client guide now records successful macOS staging login and
pairing, the official callback dependency and the limits of that evidence.
Phase 1 automated evidence is recorded separately.

**Remaining:** Reconcile the README, readiness checklist and deployment documents
with those findings. Verify publication claims before changing them; a configured
Git remote is not evidence of a published repository, release or image.

**To close:** Documentation consistently separates owner-reported staging success,
automated protocol checks, pending graphical regressions and production acceptance.

## UX-01 — Server connection disappears after identity merge

**P2 · INVESTIGATE · Official Gryt Desktop; upstream candidate**

**Evidence:** A previously connected server disappeared from the local list
after accepting the local-to-account identity merge. The disposable old identity
had no saved recovery phrase. Server-side membership or data loss was not shown.

**Remaining:** Reproduce with disposable identities/servers, distinguish local
connection metadata from server membership, and report upstream if confirmed.

**To close:** Merging preserves connections or clearly explains reconnection;
server-side membership behavior is established.

## UX-02 — Device approval workflow is hard to discover

**P2 · OPEN · Client documentation / official Gryt Desktop**

**Evidence:** A second MacBook displayed `Approve this device`; pairing succeeded
once the approval workflow was found.

**Remaining:** Document trusted-device `Your devices → Link a device`, code entry
and emoji verification. Consider an upstream onboarding improvement after the
local guide is complete.

**To close:** A user can approve another device using the guide without external
troubleshooting instructions.

## ARCH-01 — Official Desktop depends on the hosted Gryt callback

**P1 · OPEN · Client architecture; known limitation**

**Evidence:** The tested release uses `https://gryt.chat/auth/callback` even with
a custom issuer and Identity Service URL. Phase 1 permits that exact route and
documents the dependency; it does not provide an independent callback.

**Remaining:** Inspect the selected client release and design a fully self-hosted
callback/handoff. Verify supported runtime configuration and OS deep-link behavior
before changing working authentication.

**To close:** A tested Desktop login completes without the Gryt-hosted callback,
with state/PKCE checks and the intended self-hosted identity endpoints preserved.

## Next work

1. Finish phase 1 acceptance: graphical regressions for BUG-01 and BUG-02.
2. Phase 2: BUG-03, BUG-04 and OPS-01.
3. Phase 3: BUG-05, DOC-01 and DOC-02.
4. Phase 4: reproduce UX-01 and improve UX-02 documentation/upstream onboarding.
5. Separate architecture work: ARCH-01. Keep it distinct from the phase 1 fixes.

General production security and recovery acceptance lives in
[readiness](../operator/readiness.md), rather than as unconfirmed bugs here.
Follow [AGENTS.md](../../AGENTS.md) for repository/deployment constraints.
Keep fixes scoped, add regression coverage where practical, cite issue IDs in
related commits, and record actual evidence before advancing a status.
