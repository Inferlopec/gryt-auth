# Architecture

Keycloak at `https://auth.inferlo.xyz/realms/gryt` authenticates users through
OIDC code + PKCE (`gryt-web`). Identity Service at `https://id.inferlo.xyz`
validates issuer, signature, expiry and `aud=gryt-web`; a protocol mapper adds
that audience to access tokens. A certificate binds the Keycloak subject to a
public P-256 device key. Gryt verifies the CA signature and a challenge-bound
assertion signed by that device.

Each device has its own key. The account's subject remains the same. The CA
private key and account-key records live in `/app/data` on a persistent volume;
Keycloak state lives in PostgreSQL. Pairing relay sessions are ephemeral and
must be retried if the relay restarts.

Authentication does not share server membership databases. Each Gryt server
keeps its own ownership, roles, bans and history. All servers must use the same
trusted issuer ordering if they expect the same qualified identity spelling.
The first issuer owns the legacy unqualified namespace; additional issuers use
`<issuer>|<sub>` at the tested server revision. Never reorder existing issuers.

Bootstrap uses the live Admin API after Keycloak creates its master realm and
initial administrator. A missing realm is created; an existing one is skipped.
Only the explicit recovery command deletes/recreates a realm. Normal startup
has no dependency on bootstrap jobs.
