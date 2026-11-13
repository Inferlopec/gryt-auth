# Configure a client

Prerequisite: the auth/id HTTPS endpoints work and the target Gryt server
[trusts Inferlo](existing-server.md). Use an existing invitation where required.

Real graphical Web/Desktop login has not yet been accepted for production.
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

The inspected Desktop client reads `GRYT_AUTH_CALLBACK_URL` from runtime config
for authorization and code exchange. Its Electron process accepts `gryt://`
links and forwards them to the callback handler, which verifies state. The
proposed direct callback is `gryt://auth/callback`, already allowed by the
realm. This avoids needing an official hosted callback bridge.

The selected Desktop release must actually receive that runtime configuration
through its supported packaging/build mechanism. OS registration and the
browser-to-application handoff are not tested yet. Do not replace the callback
with `https://app.inferlo.xyz/auth/callback` unless that route implements an
actual bridge; an ordinary SPA fallback is insufficient.

## Acceptance check

Use a disposable account and confirm: login, certificate issuance, joining the
first server, restarting the client, approving a second device, and joining a
second server as the same account. Check server membership/roles remain
independent. Repeat on Web and Desktop separately. If anything fails, use
[troubleshooting](troubleshooting.md) and keep the installation in testing.
