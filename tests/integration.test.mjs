import assert from 'node:assert/strict';
import { before, test } from 'node:test';
import { createServer } from 'node:http';
import { readFile, mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { once } from 'node:events';
import { createLocalJWKSet, decodeJwt, exportJWK, generateKeyPair, importPKCS8, jwtVerify, SignJWT } from 'jose';
import { io } from 'socket.io-client';
import { KC, ID, realm, random, digest, request, adminToken, ensureUser, login, deviceCertificate, verifyCertificate } from './helpers.mjs';

let tokens;
before(async () => { await ensureUser(); tokens = await login(); });

test('OIDC code + PKCE, refresh, wrong password and wrong verifier', async () => {
  const discovery = await request(`${realm}/.well-known/openid-configuration`);
  assert.equal(discovery.status, 200);
  assert.equal(discovery.data.issuer, realm);
  const claims = decodeJwt(tokens.access_token);
  assert.equal(claims.iss, realm);
  assert.ok([claims.aud].flat().includes('gryt-web'));
  const keys = await request(`${realm}/protocol/openid-connect/certs`);
  await jwtVerify(tokens.access_token, createLocalJWKSet(keys.data), { issuer: realm, audience: 'gryt-web' });
  const refreshed = await request(`${realm}/protocol/openid-connect/token`, { method: 'POST', form: {
    grant_type: 'refresh_token', client_id: 'gryt-web', refresh_token: tokens.refresh_token,
  } });
  assert.equal(refreshed.status, 200);
  assert.equal(decodeJwt(refreshed.data.access_token).sub, claims.sub);
  const direct = await request(`${realm}/protocol/openid-connect/token`, { method: 'POST', form: {
    grant_type: 'password', client_id: 'gryt-web', username: 'testuser@example.test', password: 'Test-Pass-123',
  } });
  assert.equal(direct.status, 400, 'password grant remains disabled');
  await login('wrong-password');
  await login('Test-Pass-123', random(48));
});

test('BUG-01/BUG-02 official Desktop callback and token CORS', async () => {
  const redirect = 'https://gryt.chat/auth/callback';
  const origin = 'http://127.0.0.1:15738';
  const desktop = await login('Test-Pass-123', undefined, { redirect, origin });
  assert.equal(decodeJwt(desktop.access_token).sub, decodeJwt(tokens.access_token).sub);
  const refreshed = await request(`${realm}/protocol/openid-connect/token`, {
    method: 'POST', headers: { Origin: origin }, form: {
      grant_type: 'refresh_token', client_id: 'gryt-web', refresh_token: desktop.refresh_token,
    },
  });
  assert.equal(refreshed.status, 200);
  assert.equal(refreshed.headers.get('access-control-allow-origin'), origin);
  // OPTIONS alone cannot prove client-specific token response permissions.
  const preflight = await request(`${realm}/protocol/openid-connect/token`, {
    method: 'OPTIONS', headers: { Origin: origin, 'Access-Control-Request-Method': 'POST',
      'Access-Control-Request-Headers': 'content-type' },
  });
  assert.equal(preflight.status, 200);
  assert.equal(preflight.headers.get('access-control-allow-origin'), origin);
  for (const denied of ['https://untrusted.example', 'http://127.0.0.1:15739']) {
    const response = await request(`${realm}/protocol/openid-connect/token`, {
      method: 'POST', headers: { Origin: denied }, form: {
        grant_type: 'authorization_code', client_id: 'gryt-web', code: 'invalid-test-code',
        redirect_uri: redirect, code_verifier: random(48),
      },
    });
    assert.notEqual(response.headers.get('access-control-allow-origin'), denied);
    assert.notEqual(response.headers.get('access-control-allow-origin'), '*');
  }
  for (const denied of ['https://gryt.chat/auth/callback/extra',
    'https://gryt.chat/other', 'https://gryt.chat.evil.example/auth/callback']) {
    const query = new URLSearchParams({ client_id: 'gryt-web', response_type: 'code',
      redirect_uri: denied, code_challenge: digest(random(48)), code_challenge_method: 'S256' });
    const response = await request(`${realm}/protocol/openid-connect/auth?${query}`);
    assert.equal(response.status, 400, 'unregistered callback rejected');
    assert.equal(response.headers.get('location'), null);
  }
});

test('Two device keys receive cryptographically verified certificates for one account', async () => {
  const a = await deviceCertificate(tokens.access_token);
  const b = await deviceCertificate(tokens.access_token);
  assert.notEqual(a.jwk.x, b.jwk.x);
  const ca = await verifyCertificate(a);
  const cb = await verifyCertificate(b);
  assert.equal(ca.sub, cb.sub);
  assert.equal(ca.sub, decodeJwt(tokens.access_token).sub);
  const noToken = await request(`${ID}/api/v1/certificate`, { method: 'POST', json: { jwk: a.jwk } });
  assert.equal(noToken.status, 401);
  const badToken = await request(`${ID}/api/v1/certificate`, { method: 'POST', token: 'invalid.jwt.token', json: { jwk: a.jwk } });
  assert.equal(badToken.status, 401);
  const tampered = a.certificate.split('.');
  tampered[1] = Buffer.from(JSON.stringify({ ...ca, sub: 'other-user' })).toString('base64url');
  await assert.rejects(() => verifyCertificate({ ...a, certificate: tampered.join('.') }));
});

test('OIDC validator rejects signed wrong issuer, wrong audience, expiry and missing expiry', async () => {
  const keys = await generateKeyPair('RS256', { extractable: true });
  const jwk = { ...await exportJWK(keys.publicKey), alg: 'RS256', kid: 'test' };
  const stub = createServer((req, res) => {
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ keys: [jwk] }));
  });
  stub.listen(0, '127.0.0.1'); await once(stub, 'listening');
  const issuer = `http://127.0.0.1:${stub.address().port}`;
  const previous = process.env.GRYT_OIDC_ISSUER;
  process.env.GRYT_OIDC_ISSUER = issuer;
  try {
    const { verifyKeycloakToken } = await import('../dist/keycloak.js');
    const sign = (claims) => new SignJWT({ sub: 'test', iss: issuer, aud: 'gryt-web',
      iat: Math.floor(Date.now()/1000), exp: Math.floor(Date.now()/1000)+60, ...claims })
      .setProtectedHeader({ alg: 'RS256', kid: 'test' }).sign(keys.privateKey);
    assert.equal((await verifyKeycloakToken(await sign({}))).sub, 'test');
    for (const claims of [{ iss: 'https://wrong.example' }, { aud: 'other-app' },
      { exp: 1 }, { exp: undefined }]) {
      const token = await sign(claims);
      await assert.rejects(() => verifyKeycloakToken(token));
    }
  } finally {
    if (previous === undefined) delete process.env.GRYT_OIDC_ISSUER;
    else process.env.GRYT_OIDC_ISSUER = previous;
    await new Promise(resolve => stub.close(resolve));
  }
});

test('CA refuses missing or corrupt keys on normal startup', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'ca-safety-'));
  try {
    const run = (extra = {}) => spawnSync(process.execPath, ['--input-type=module', '-e',
      'import {getCAPublicJwk} from "./dist/keys.js"; await getCAPublicJwk();'], {
      env: { ...process.env, GRYT_IDENTITY_DATA_DIR: dir, GRYT_CA_ALLOW_GENERATE: '0', ...extra },
    });
    assert.notEqual(run().status, 0);
    assert.equal(run({ GRYT_CA_ALLOW_GENERATE: '1' }).status, 0);
    assert.equal(run().status, 0);
    await writeFile(join(dir, 'ca-key.pem'), 'corrupt-key');
    assert.notEqual(run({ GRYT_CA_ALLOW_GENERATE: '1' }).status, 0);
    assert.equal(await readFile(join(dir, 'ca-key.pem'), 'utf8'), 'corrupt-key');
    assert.notEqual(run({ GRYT_CA_PRIVATE_KEY_FILE: join(dir, 'missing.pem'), GRYT_CA_ALLOW_GENERATE: '1' }).status, 0);
  } finally { await rm(dir, { recursive: true }); }
});

test('Device grant approval creates an independent refreshable session', async () => {
  const verifier = random(48), binding = random();
  const started = await request(`${realm}/protocol/openid-connect/auth/device`, { method: 'POST', form: {
    client_id: 'gryt-web', scope: 'openid profile email offline_access', nonce: binding,
    code_challenge: digest(verifier), code_challenge_method: 'S256',
  } });
  assert.equal(started.status, 200);
  const approved = await request(`${realm}/gryt-pairing/approve`, { method: 'POST', token: tokens.access_token,
    json: { user_code: started.data.user_code, binding } });
  assert.equal(approved.status, 204);
  const polled = await request(`${realm}/protocol/openid-connect/token`, { method: 'POST', form: {
    client_id: 'gryt-web', grant_type: 'urn:ietf:params:oauth:grant-type:device_code',
    device_code: started.data.device_code, code_verifier: verifier,
  } });
  assert.equal(polled.status, 200);
  const original = decodeJwt(tokens.access_token), linked = decodeJwt(polled.data.access_token);
  assert.equal(linked.sub, original.sub);
  assert.notEqual(linked.sid, original.sid);
  const refreshed = await request(`${realm}/protocol/openid-connect/token`, { method: 'POST', form: {
    client_id: 'gryt-web', grant_type: 'refresh_token', refresh_token: polled.data.refresh_token,
  } });
  assert.equal(refreshed.status, 200);
  const retry = await request(`${realm}/gryt-pairing/approve`, { method: 'POST', token: tokens.access_token,
    json: { user_code: started.data.user_code, binding } });
  assert.ok([400, 409].includes(retry.status));
});

test('Pairing relay checks commitments and delivers reveal and sealed messages', async () => {
  const pkN = random(), pkA = random();
  const commit = digest(Buffer.concat([Buffer.from('gryt-pair-v1 commit'), Buffer.from(pkN, 'base64url')]));
  const opened = await request(`${ID}/api/v1/pairing/sessions`, { method: 'POST', json: { commit } });
  assert.equal(opened.status, 201);
  const claimed = await request(`${ID}/api/v1/pairing/sessions/claim`, { method: 'POST', json: { code: opened.data.code, pkA } });
  assert.equal(claimed.status, 200);
  const path = `${ID}/api/v1/pairing/sessions/${opened.data.id}`;
  const bad = await request(`${path}/messages`, { method: 'POST', token: opened.data.token, json: { type: 'reveal', pkN: random() } });
  assert.equal(bad.status, 409);
  const reveal = await request(`${path}/messages`, { method: 'POST', token: opened.data.token, json: { type: 'reveal', pkN } });
  assert.equal(reveal.status, 201);
  const messages = await request(`${path}/messages`, { token: claimed.data.token });
  assert.ok(messages.data.messages.some(m => m.type === 'reveal' && m.pkN === pkN));
  const body = random(24);
  assert.equal((await request(`${path}/messages`, { method: 'POST', token: claimed.data.token, json: { type: 'sealed', body } })).status, 201);
  const received = await request(`${path}/messages`, { token: opened.data.token });
  assert.ok(received.data.messages.some(m => m.type === 'sealed' && m.body === body));
  assert.equal((await request(path, { method: 'DELETE', token: opened.data.token })).status, 204);
});

test('Pairing relay enforces per-address session rate limit', async () => {
  let limited = false;
  for (let i = 0; i < 15; i++) {
    const r = await request(`${ID}/api/v1/pairing/sessions`, { method: 'POST', json: { commit: random() } });
    if (r.status === 429) { limited = true; break; }
    assert.equal(r.status, 201);
    await request(`${ID}/api/v1/pairing/sessions/${r.data.id}`, { method: 'DELETE', token: r.data.token });
  }
  assert.ok(limited);
});

async function joinServer(url, device, action) {
  const socket = io(url, { transports: ['websocket'], reconnection: false, autoConnect: false });
  const wait = (event) => new Promise((resolve, reject) => {
    const timer = setTimeout(() => { cleanup(); reject(new Error(`timeout: ${event}`)); }, 15000);
    const cleanup = () => { clearTimeout(timer); socket.off(event, ok); socket.off('server:error', bad); socket.off('connect_error', bad); };
    const ok = data => { cleanup(); resolve(data); };
    const bad = data => { cleanup(); reject(new Error(JSON.stringify(data))); };
    socket.once(event, ok); socket.once('server:error', bad); socket.once('connect_error', bad);
  });
  try {
    const connected = wait('connect'); socket.connect(); await connected;
    const challenged = wait('server:challenge'); socket.emit('server:join', { nickname: 'Integration User' });
    const challenge = await challenged;
    const assertion = await new SignJWT({ nonce: challenge.nonce }).setProtectedHeader({ alg: 'ES256' })
      .setSubject(decodeJwt(device.certificate).sub).setAudience(challenge.serverHost)
      .setIssuedAt().setExpirationTime('60s').sign(device.privateKey);
    const joined = wait('server:joined');
    socket.emit('server:verify', { certificate: device.certificate, assertion });
    const result = await joined;
    if (result.isOwner) {
      const configured = wait('server:settings');
      socket.emit('server:settings:update', { accessToken: result.accessToken, joinPolicy: 'open' });
      await configured;
    }
    if (action) await action(socket, wait, result);
    return result;
  } finally { socket.disconnect(); }
}

test('Two devices join two actual Gryt servers; distinct CA subjects stay isolated', {
  skip: !process.env.GRYT_TEST_SERVERS && 'Run tests/run_all.sh --with-gryt',
}, async () => {
  const servers = process.env.GRYT_TEST_SERVERS.split(',');
  assert.equal(servers.length, 2);
  const a = await deviceCertificate(tokens.access_token), b = await deviceCertificate(tokens.access_token);
  for (const server of servers) {
    const first = await joinServer(server, a), second = await joinServer(server, b);
    const ca = decodeJwt(first.accessToken), cb = decodeJwt(second.accessToken);
    assert.deepEqual(ca.grytUserId, cb.grytUserId);
    assert.equal(ca.grytUserId, `${ID}|${decodeJwt(a.certificate).sub}`);
    // Same Keycloak sub signed by a different, explicitly trusted CA must not inherit A.
    const other = await deviceCertificate(tokens.access_token, 'http://other-identity:3000');
    const foreign = await joinServer(server, other);
    assert.notEqual(decodeJwt(foreign.accessToken).grytUserId, ca.grytUserId);
    assert.equal(foreign.isOwner, false);
    const jwks = await request(`${ID}/.well-known/jwks.json`);
    const caKey = await importPKCS8(await readFile('/ca-data/ca-key.pem', 'utf8'), 'ES256');
    const kid = jwks.data.keys[0].kid;
    const forge = async (iss, exp) => ({ ...a, certificate: await new SignJWT({ jwk: a.jwk })
      .setProtectedHeader({ alg: 'ES256', kid }).setSubject(decodeJwt(a.certificate).sub)
      .setIssuer(iss).setIssuedAt().setExpirationTime(exp).sign(caKey) });
    await assert.rejects(() => forge('http://untrusted.example', '30d').then(d => joinServer(server, d)), /identity_verification_failed/);
    await assert.rejects(() => forge(ID, 1).then(d => joinServer(server, d)), /identity_verification_failed/);
    if (server === servers[0]) {
      try {
        await joinServer(server, a, async (socket, wait, owner) => {
          const banned = wait('server:ban:success');
          socket.emit('server:ban', { accessToken: owner.accessToken,
            targetServerUserId: decodeJwt(foreign.accessToken).serverUserId });
          await banned;
        });
        await assert.rejects(() => joinServer(server, other), /join_refused/);
        // The same user remains accepted by the other independent server.
        const secondOwner = await joinServer(servers[1], a);
        assert.equal(secondOwner.isOwner, true);
        const elsewhere = await joinServer(servers[1], other);
        assert.equal(elsewhere.isOwner, false);
      } finally {
        await joinServer(server, a, async (socket, wait, owner) => {
          const unbanned = wait('server:unban:success');
          socket.emit('server:unban', { accessToken: owner.accessToken,
            grytUserId: decodeJwt(foreign.accessToken).grytUserId });
          await unbanned;
        });
      }
    }
  }
});
