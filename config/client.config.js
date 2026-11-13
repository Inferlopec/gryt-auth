// Runtime configuration for the inspected Gryt Client revision. Desktop deep-link
// handling must still be verified in the selected release on each target OS.
window.__GRYT_CONFIG__ = {
  GRYT_OIDC_ISSUER: "https://auth.inferlo.xyz/realms/gryt",
  GRYT_OIDC_REALM: "gryt",
  GRYT_OIDC_CLIENT_ID: "gryt-web",
  GRYT_IDENTITY_URL: "https://id.inferlo.xyz",
  GRYT_AUTH_API: "https://auth.inferlo.xyz",
  GRYT_AUTH_CALLBACK_URL: "gryt://auth/callback"
};
