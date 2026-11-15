# Vendored sources and local patches

Base: Gryt-chat/auth commit [`77c38ca94dbe5a91adf271c234b535b5d4548fb2`](https://github.com/Gryt-chat/auth/commit/77c38ca94dbe5a91adf271c234b535b5d4548fb2),
`realm/` and `bootstrap/`. Component-specific changes are recorded in
[Identity](identity/VENDOR.md) and [Pairing](keycloak-pairing/VENDOR.md).

The upstream copyright notice and complete license are retained verbatim in
[LICENSES/gryt-auth.txt](LICENSES/gryt-auth.txt). The same pinned commit supplies
Identity, pairing, realm and bootstrap sources. Keycloak is pinned to **26.5.3**;
its image tag must match the provider pom.xml version. Image digests remain in
Compose/Dockerfiles, not a duplicate documentation manifest. Build/upgrade
checks are in [DEVELOPMENT](docs/DEVELOPMENT.md#build-and-upstream-changes).

Local adaptations include non-destructive Admin API initialization, audience
configuration, SMTP configuration and Inferlo realm defaults.

## Upstream PR #71 and Desktop callbacks

Upstream [Auth PR #71](https://github.com/Gryt-chat/auth/pull/71) changes only
`realm/gryt-realm.json`: it replaces `http://127.0.0.1:*` with the exact
Desktop renderer Origin `http://127.0.0.1:15738` and port-scoped loopback
redirect `http://127.0.0.1:15738/*`. The local realm keeps that exact Origin
and redirect while preserving its Inferlo realm defaults, audience mapper,
local web/development entries and non-destructive configuration.

Upstream [Client PR #1197](https://github.com/Gryt-chat/client/pull/1197),
merged as [`5d8e294a09cb6626a67e8bb0740158ee27232503`](https://github.com/Gryt-chat/client/commit/5d8e294a09cb6626a67e8bb0740158ee27232503),
defaults self-hosted Desktop sign-in to `gryt://auth/callback`. Local config
uses that as the primary callback and retains exact
`https://gryt.chat/auth/callback` for older Desktop releases. Both callback
flows use the same PKCE/state contract and exact renderer Origin; graphical
acceptance is pending an updated packaged Desktop release.

`bootstrap/client_access.py` validates optional additive exact URL/origin arrays.
It requires both callbacks, the upstream port-scoped redirect and exact Origin.
Fresh realm initialization consumes them; `configure_client_access.py` provides
an explicit client-only update with dry run and read-back for existing realms.
It preserves other operator entries and does not replace users, realm or CA.
No live realm is imported or replaced by this source update.

The local Identity and pairing patches remain unchanged. No client protocol,
PKCE requirement, Keycloak version, reverse-proxy CORS behavior or pairing
extension version is changed.

Keycloak 26.5.3's [token endpoint source](https://github.com/keycloak/keycloak/blob/26.5.3/services/src/main/java/org/keycloak/protocol/oidc/endpoints/TokenEndpoint.java)
uses client-specific allowed origins for POST responses, while OPTIONS uses a
preflight response. Regression coverage therefore checks real code/PKCE and
refresh responses, rather than relying only on OPTIONS.
