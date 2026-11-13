import { createHash } from "node:crypto";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { dirname } from "node:path";

import { exportJWK, generateKeyPair, importPKCS8, type JWK } from "jose";

const ALG = "ES256";

let cachedPrivateKey: CryptoKey | null = null;
let cachedPublicJwk: JWK | null = null;
let cachedKid: string | null = null;

function deriveKid(jwk: JWK): string {
  const material = `${jwk.crv}:${jwk.x}:${jwk.y}`;
  const hash = createHash("sha256").update(material).digest("hex");
  return hash.slice(0, 16);
}

async function loadOrGenerateKey(): Promise<{
  privateKey: CryptoKey;
  publicJwk: JWK;
  kid: string;
}> {
  if (cachedPrivateKey && cachedPublicJwk && cachedKid) {
    return { privateKey: cachedPrivateKey, publicJwk: cachedPublicJwk, kid: cachedKid };
  }

  const keyPath = process.env.GRYT_CA_PRIVATE_KEY_FILE;

  if (keyPath) {
    try {
      const pem = await readFile(keyPath, "utf-8");
      const privateKey = await importPKCS8(pem, ALG, { extractable: true });
      const jwk = await exportJWK(privateKey);
      const kid = deriveKid(jwk);
      const { d: _, ...publicJwk } = jwk;

      const pub: JWK = { ...publicJwk, alg: ALG, use: "sig", kid };
      cachedPrivateKey = privateKey;
      cachedPublicJwk = pub;
      cachedKid = kid;
      return { privateKey, publicJwk: pub, kid };
    } catch (e) {
      throw new Error(`Cannot load configured CA key ${keyPath}; refusing to replace it`, { cause: e });
    }
  }

  const dataDir = process.env.GRYT_IDENTITY_DATA_DIR || "./data";
  const autoKeyPath = `${dataDir}/ca-key.pem`;

  try {
    const pem = await readFile(autoKeyPath, "utf-8");
    const privateKey = await importPKCS8(pem, ALG, { extractable: true });
    const jwk = await exportJWK(privateKey);
    const kid = deriveKid(jwk);
    const { d: _, ...publicJwk } = jwk;

    const pub: JWK = { ...publicJwk, alg: ALG, use: "sig", kid };
    cachedPrivateKey = privateKey;
    cachedPublicJwk = pub;
    cachedKid = kid;
    console.log(`Loaded existing CA key from ${autoKeyPath}`);
    return { privateKey, publicJwk: pub, kid };
  } catch (e) {
    if ((e as NodeJS.ErrnoException).code !== "ENOENT" || process.env.GRYT_CA_ALLOW_GENERATE !== "1") {
      throw new Error(`Cannot load CA key ${autoKeyPath}; run explicit initialization for a new installation or restore the original key`, { cause: e });
    }
  }

  console.log("Generating new ECDSA P-256 CA keypair...");
  const { privateKey, publicKey } = await generateKeyPair(ALG, {
    extractable: true,
  });

  const privateJwk = await exportJWK(privateKey);
  const pubJwk = await exportJWK(publicKey);
  const kid = deriveKid(pubJwk);

  // Serialize private key to PEM via PKCS8
  const { exportPKCS8 } = await import("jose");
  const pem = await exportPKCS8(privateKey);

  await mkdir(dirname(autoKeyPath), { recursive: true });
  await writeFile(autoKeyPath, pem, { mode: 0o600, flag: "wx" });
  console.log(`Saved new CA key to ${autoKeyPath}`);

  const pub: JWK = { ...pubJwk, alg: ALG, use: "sig", kid };
  cachedPrivateKey = privateKey;
  cachedPublicJwk = pub;
  cachedKid = kid;

  return { privateKey, publicJwk: pub, kid };
}

export async function getCAPrivateKey(): Promise<CryptoKey> {
  const { privateKey } = await loadOrGenerateKey();
  return privateKey;
}

export async function getCAPublicJwk(): Promise<JWK & { kid: string }> {
  const { publicJwk, kid } = await loadOrGenerateKey();
  return { ...publicJwk, kid } as JWK & { kid: string };
}

export async function getCAKid(): Promise<string> {
  const { kid } = await loadOrGenerateKey();
  return kid;
}

export const CA_ALG = ALG;
