import assert from 'node:assert/strict';
import { randomBytes, createHash } from 'node:crypto';
import { createLocalJWKSet, decodeJwt, exportJWK, generateKeyPair, jwtVerify } from 'jose';

export const KC = process.env.KC_URL || 'http://keycloak:8080';
export const ID = process.env.ID_URL || 'http://identity:3000';
export const realm = `${KC}/realms/gryt`;
export const random = (n = 32) => randomBytes(n).toString('base64url');
export const digest = (s) => createHash('sha256').update(s).digest('base64url');
export async function request(url, { method = 'GET', form, json, token, headers = {} } = {}) {
  const response = await fetch(url, {
    method, redirect: 'manual', signal: AbortSignal.timeout(15000),
    headers: { ...headers, ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(form ? { 'Content-Type': 'application/x-www-form-urlencoded' } : {}),
      ...(json ? { 'Content-Type': 'application/json' } : {}) },
    body: form ? new URLSearchParams(form) : json ? JSON.stringify(json) : undefined,
  });
  const text = await response.text();
  let data;
  try { data = JSON.parse(text); } catch { data = null; }
  return { status: response.status, headers: response.headers, text, data };
}
export async function adminToken() {
  const r = await request(`${KC}/realms/master/protocol/openid-connect/token`, {
    method: 'POST', form: { client_id: 'admin-cli', grant_type: 'password', username: 'admin', password: 'test-only' },
  });
  assert.equal(r.status, 200, 'test admin authentication');
  return r.data.access_token;
}
export async function ensureUser() {
  const token = await adminToken();
  const path = `${KC}/admin/realms/gryt/users`;
  const found = await request(`${path}?username=testuser%40example.test&exact=true`, { token });
  assert.equal(found.status, 200);
  if (!found.data.length) {
    const created = await request(path, { method: 'POST', token, json: {
      username: 'testuser@example.test', email: 'testuser@example.test', emailVerified: true, enabled: true,
      firstName: 'Test', lastName: 'User',
      credentials: [{ type: 'password', value: 'Test-Pass-123', temporary: false }],
    } });
    assert.equal(created.status, 201, 'seed test user');
  }
}
// Same code/PKCE exchange as the Gryt clients. No direct-grant exception in fixtures.
export async function login(password = 'Test-Pass-123', verifierOverride, { redirect = 'http://localhost:3666/cb', origin } = {}) {
  const verifier = random(48);
  const state = random();
  const query = new URLSearchParams({ client_id: 'gryt-web', response_type: 'code',
    redirect_uri: redirect, scope: 'openid profile email offline_access', state,
    code_challenge: digest(verifier), code_challenge_method: 'S256' });
  const cookies = new Map();
  async function browser(url, options = {}) {
    const r = await request(url, { ...options, headers: { Cookie: [...cookies].map(([k,v]) => `${k}=${v}`).join('; ') } });
    for (const cookie of r.headers.getSetCookie()) {
      const [key, ...rest] = cookie.split(';')[0].split('=');
      cookies.set(key, rest.join('='));
    }
    return r;
  }
  const page = await browser(`${realm}/protocol/openid-connect/auth?${query}`);
  assert.equal(page.status, 200, 'login form');
  const action = page.text.match(/<form[^>]*action="([^"]+)"/)?.[1]?.replaceAll('&amp;', '&');
  assert.ok(action, 'login form action');
  const done = await browser(action, { method: 'POST', form: { username: 'testuser@example.test', password, credentialId: '' } });
  if (password !== 'Test-Pass-123') {
    assert.equal(done.status, 200, 'wrong password stays on login form');
    assert.ok(!done.headers.get('location'), 'wrong password cannot receive an authorization code');
    return;
  }
  assert.equal(done.status, 302, 'login callback: ' + done.text.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').slice(-1800));
  const location = new URL(done.headers.get('location'));
  assert.equal(location.href.split(/[?#]/, 1)[0], redirect);
  assert.equal(location.searchParams.get('state'), state);
  const tokens = await request(`${realm}/protocol/openid-connect/token`, { method: 'POST', headers: origin ? { Origin: origin } : {}, form: {
    grant_type: 'authorization_code', client_id: 'gryt-web', code: location.searchParams.get('code'),
    redirect_uri: redirect, code_verifier: verifierOverride || verifier,
  } });
  if (verifierOverride) { assert.equal(tokens.status, 400, 'wrong PKCE verifier'); return; }
  assert.equal(tokens.status, 200, 'code/PKCE exchange');
  if (origin) assert.equal(tokens.headers.get('access-control-allow-origin'), origin, 'token response CORS');
  return tokens.data;
}
export async function deviceCertificate(token, origin = ID) {
  const keys = await generateKeyPair('ES256', { extractable: true });
  const jwk = await exportJWK(keys.publicKey);
  const r = await request(`${origin}/api/v1/certificate`, { method: 'POST', token, json: { jwk } });
  assert.equal(r.status, 200, 'certificate issuance');
  assert.equal(typeof r.data.certificate, 'string');
  return { ...keys, jwk, certificate: r.data.certificate };
}
export async function verifyCertificate(device, origin = ID) {
  const jwks = await request(`${origin}/.well-known/jwks.json`);
  assert.equal(jwks.status, 200);
  const verified = await jwtVerify(device.certificate, createLocalJWKSet(jwks.data), { issuer: origin, algorithms: ['ES256'] });
  assert.deepEqual(verified.payload.jwk, device.jwk);
  assert.equal(verified.payload.exp - verified.payload.iat, 30 * 86400);
  assert.equal(verified.payload.sub, decodeJwt(device.certificate).sub);
  return verified.payload;
}
