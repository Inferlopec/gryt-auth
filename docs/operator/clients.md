# Configure a client

Prerequisite: the auth/id HTTPS endpoints work and the target Gryt server
[trusts Inferlo](existing-server.md). Use an existing invitation where required.

Graphical Web/Desktop acceptance for production remains open.
A successful macOS staging test is recorded under [Desktop callback](#desktop-callback).
The configuration below was checked against client source at
`0cd7718ae834485ed3d4e9f5699f9800d9c7cdc1`; test the release you actually use.
A backend protocol test does not prove OS deep-link handling works.

## Use the client's custom authentication settings

In the inspected client's account settings, set both:

| Field | Value |
|---|---|
| OIDC issuer | `https://auth.inferlo.xyz/realms/gryt` |
| Identity Service URL | `https://id.inferlo.xyz` |

Save and sign in with an [Inferlo account](users.md). Setting only the issuer
can leave certificate requests going to the official CA, which cannot validate
Inferlo tokens. If your installed release has no matching fields, stop and
confirm its supported configuration mechanism with the maintainer.

On Desktop, these two settings do not change the login callback. Use the
runtime configuration described below before treating the setup as independent
of official infrastructure.

## Self-hosted web client

If you already serve the upstream web container, the supplied file
`config/client.config.js` contains the auth settings read by that client's
`window.__GRYT_CONFIG__`. Copy it to a persistent location on your host and
bind-mount it read-only at `/usr/share/nginx/html/config.js` in that web
container. Keep the complete config file with your web deployment.

Alternatively, configure the upstream container environment using:

```dotenv
GRYT_OIDC_ISSUER=https://auth.inferlo.xyz/realms/gryt
GRYT_OIDC_REALM=gryt
GRYT_OIDC_CLIENT_ID=gryt-web
GRYT_IDENTITY_URL=https://id.inferlo.xyz
GRYT_AUTH_API=https://auth.inferlo.xyz
GRYT_AUTH_CALLBACK_URL=gryt://auth/callback
```

Recreate only that web client. Check the served `/config.js` contains the two
Inferlo endpoints and reload the browser. User-specific custom settings can
override runtime values, so clear stale overrides when testing deployment
configuration.

For `https://app.inferlo.xyz`, configure DNS and its Caddy route to your actual
web container port. The auth stack does not deploy a web client itself. The
realm already allows that app origin; preserve existing Gryt CORS origins and
add `https://app.inferlo.xyz` on each connected server. For another app origin,
update both Keycloak redirect/Web Origins and Gryt CORS deliberately.
Web login returns to its current page URL rather than the Desktop callback.

## Desktop callback

The owner tested official Gryt Desktop **1.15.12 on macOS** on November 14,
2026: login, staging-server certificate authentication, persistence after restart,
and pairing between two MacBooks succeeded after correcting Keycloak allowlists.
See the [deployment findings](../qa/known-issues.md). This is staging evidence;
production readiness and graphical Web acceptance remain separate checks.

That release sends `https://gryt.chat/auth/callback` and uses renderer Origin
`http://127.0.0.1:15738`. The realm template permits this exact callback and
Origin. The official callback creates a security and availability dependency on
`gryt.chat`; this setup does not yet meet full independence from official services.
Changing the issuer and Identity URL in account settings does not change that
callback.

The inspected source also supports `GRYT_AUTH_CALLBACK_URL` through runtime
configuration and accepts `gryt://` links. The existing
`gryt://auth/callback` allowlist entry is retained for custom builds. A direct
self-hosted handoff is a separate, unverified architecture; OS deep-link handling
and delivery of runtime configuration to a packaged release still need testing.
Do not replace the callback with `https://app.inferlo.xyz/auth/callback` unless
that route implements an actual bridge; an ordinary SPA fallback is insufficient.

For existing realms and other renderer ports, follow
[client allowlist configuration](configuration.md#oauth-callbacks-and-web-origins).

## Acceptance check

Use a disposable account and confirm: login, certificate issuance, joining the
first server, restarting the client, approving a second device, and joining a
second server as the same account. Check server membership/roles remain
independent. Repeat on Web and Desktop separately. If anything fails, use
[troubleshooting](troubleshooting.md) and keep the installation in testing.
