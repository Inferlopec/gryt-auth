import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { decodeJwt, createLocalJWKSet, jwtVerify } from 'jose';
import { ID, KC, ensureUser, login, request, adminToken } from './helpers.mjs';

test('Account and CA snapshot before recovery', async () => {
  await ensureUser();
  const tokens = await login();
  await writeFile('/artifacts/recovery-before.json', JSON.stringify({ sub: decodeJwt(tokens.access_token).sub,
    jwks: (await request(`${ID}/.well-known/jwks.json`)).data }));
});

test('Recovery preserves user subject, login and existing certificate trust', async () => {
  const before = JSON.parse(await readFile('/artifacts/recovery-before.json', 'utf8'));
  const tokens = await login();
  assert.equal(decodeJwt(tokens.access_token).sub, before.sub);
  const jwks = (await request(`${ID}/.well-known/jwks.json`)).data;
  assert.deepEqual(jwks, before.jwks);
  const certificate = JSON.parse(await readFile('/artifacts/ca-before.json', 'utf8')).certificate;
  await jwtVerify(certificate, createLocalJWKSet(jwks), { issuer: ID });
});

test('Create post-backup marker account', async () => {
  const token = await adminToken();
  const r = await request(`${KC}/admin/realms/gryt/users`, { method: 'POST', token,
    json: { username: 'restore-marker@example.test', email: 'restore-marker@example.test', enabled: true } });
  assert.equal(r.status, 201);
});

test('Restore removes post-backup marker account', async () => {
  const token = await adminToken();
  const r = await request(`${KC}/admin/realms/gryt/users?username=restore-marker%40example.test&exact=true`, { token });
  assert.equal(r.status, 200);
  assert.equal(r.data.length, 0, 'database was actually restored to the backup state');
});

test('Realm replacement removed original account', async () => {
  const token = await adminToken();
  const r = await request(`${KC}/admin/realms/gryt/users?username=testuser%40example.test&exact=true`, { token });
  assert.equal(r.status, 200);
  assert.equal(r.data.length, 0);
});

test('Save original mail settings', async () => {
  const token = await adminToken();
  const r = await request(`${KC}/admin/realms/gryt`, { token });
  assert.equal(r.status, 200);
  await writeFile('/artifacts/smtp-before.json', JSON.stringify({ smtpServer: r.data.smtpServer || {},
    verifyEmail: r.data.verifyEmail, resetPasswordAllowed: r.data.resetPasswordAllowed }));
});

test('SMTP update preserves users and safely encodes display name', async () => {
  const token = await adminToken();
  const r = await request(`${KC}/admin/realms/gryt`, { token });
  assert.equal(r.status, 200);
  try {
    assert.equal(r.data.smtpServer.host, 'mail.example.test');
    assert.equal(r.data.smtpServer.fromDisplayName, 'Inferlo "Tests"');
    assert.equal(r.data.verifyEmail, true);
    const before = JSON.parse(await readFile('/artifacts/recovery-before.json', 'utf8'));
    assert.equal(decodeJwt((await login()).access_token).sub, before.sub);
  } finally {
    const settings = JSON.parse(await readFile('/artifacts/smtp-before.json', 'utf8'));
    const restored = await request(`${KC}/admin/realms/gryt`, { method: 'PUT', token, json: settings });
    assert.equal(restored.status, 204);
  }
});
