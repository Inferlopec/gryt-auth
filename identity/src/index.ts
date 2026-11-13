import { serve } from "@hono/node-server";

import { rm } from "node:fs/promises";
import { join } from "node:path";

import { app, relay } from "./routes.js";
import { getCAPublicJwk } from "./keys.js";

const port = parseInt(process.env.PORT || "3000", 10);

console.log(`Gryt Identity Service starting on port ${port}...`);
// Refuse to advertise a healthy service if the configured CA cannot be loaded.
await getCAPublicJwk();
if (!process.env.GRYT_PAIRING_TRUSTED_PROXIES) {
  console.warn("pairing: GRYT_PAIRING_TRUSTED_PROXIES is empty, so every client counts as the tunnel's address");
}
// History chunks the relay used to hold, from before GRYT-2055.
await rm(join(process.env.GRYT_IDENTITY_DATA_DIR || "./data", "pairing"), { recursive: true, force: true });
relay.start();

serve({
  fetch: app.fetch,
  port,
});

console.log(`Gryt Identity Service listening on http://0.0.0.0:${port}`);
