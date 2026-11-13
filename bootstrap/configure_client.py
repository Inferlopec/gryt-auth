"""Ensure certificates only accept tokens intended for the Gryt client."""
from keycloak_admin import Admin

admin = Admin()
clients = admin.require("GET", admin.path + "/clients?clientId=gryt-web")
if len(clients) != 1:
    raise RuntimeError("Expected exactly one gryt-web client")
path = admin.path + "/clients/" + clients[0]["id"] + "/protocol-mappers/models"
mapper = {
    "name": "inferlo-identity-audience", "protocol": "openid-connect",
    "protocolMapper": "oidc-audience-mapper", "consentRequired": False,
    "config": {"included.client.audience": "gryt-web", "id.token.claim": "false",
               "access.token.claim": "true"},
}
existing = next((m for m in admin.require("GET", path) if m["name"] == mapper["name"]), None)
if existing:
    admin.require("PUT", path + "/" + existing["id"], {**mapper, "id": existing["id"]})
else:
    admin.require("POST", path, mapper, expected=(201,))
print("gryt-web access-token audience configured.")
