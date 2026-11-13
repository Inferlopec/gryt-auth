import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { createLocalJWKSet, jwtVerify } from 'jose';
import { ID, ensureUser, login, request, deviceCertificate } from './helpers.mjs';

test('CA snapshot before recreation', async () => {
  await ensureUser();
  const token = (await login()).access_token;
  const device = await deviceCertificate(token);
  const jwks = (await request(`${ID}/.well-known/jwks.json`)).data;
  await writeFile('/artifacts/ca-before.json', JSON.stringify({ certificate: device.certificate, jwks }));
});

test('CA verifies after recreation', async () => {
  const before = JSON.parse(await readFile('/artifacts/ca-before.json', 'utf8'));
  const after = (await request(`${ID}/.well-known/jwks.json`)).data;
  assert.deepEqual(after, before.jwks);
  await jwtVerify(before.certificate, createLocalJWKSet(after), { issuer: ID });
});
