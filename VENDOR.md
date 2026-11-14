# Vendored realm and bootstrap patches

Base: Gryt-chat/auth commit `4bbd2348b65dc4ca61e2c1f39b100fb3d2ed05e4`,
`realm/` and `bootstrap/`. Component-specific changes are recorded in
[Identity](identity/VENDOR.md) and [Pairing](keycloak-pairing/VENDOR.md).

Local adaptations include non-destructive Admin API initialization, audience
configuration, SMTP configuration and Inferlo realm defaults.

## BUG-01 / BUG-02 — Desktop allowlists

The pinned upstream realm was inspected before this change. It includes broad
host/path redirects and `http://127.0.0.1:*` in redirects and Web Origins.
The local realm now adds the exact tested official Desktop callback
`https://gryt.chat/auth/callback`, replaces the wildcard loopback entries with
the exact tested renderer Origin `http://127.0.0.1:15738`, and retains the
existing custom-scheme, Inferlo web and localhost development callbacks.

`bootstrap/client_access.py` validates optional additive exact URL/origin arrays.
Fresh realm initialization consumes them; `configure_client_access.py` provides
an explicit client-only update with dry run and read-back for existing realms.
It preserves other operator entries and does not replace users, realm or CA.
No upstream client protocol, PKCE requirement, Keycloak version, reverse-proxy
CORS behavior or pairing extension version is changed.

Keycloak 26.5.3's [token endpoint source](https://github.com/keycloak/keycloak/blob/26.5.3/services/src/main/java/org/keycloak/protocol/oidc/endpoints/TokenEndpoint.java)
uses client-specific allowed origins for POST responses, while OPTIONS uses a
preflight response. Regression coverage therefore checks real code/PKCE and
refresh responses, rather than relying only on OPTIONS.
