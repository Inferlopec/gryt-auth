// Runtime configuration for Gryt Client PR #1197. Verify packaged deep-link handling
// in an updated Desktop release on each target OS before graphical acceptance.
window.__GRYT_CONFIG__ = {
  GRYT_OIDC_ISSUER: "https://auth.inferlo.xyz/realms/gryt",
  GRYT_OIDC_REALM: "gryt",
  GRYT_OIDC_CLIENT_ID: "gryt-web",
  GRYT_IDENTITY_URL: "https://id.inferlo.xyz",
  GRYT_AUTH_API: "https://auth.inferlo.xyz",
  GRYT_AUTH_CALLBACK_URL: "gryt://auth/callback"
};
