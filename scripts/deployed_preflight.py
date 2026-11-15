#!/usr/bin/env python3
"""Read-only checks for the deployed public OIDC and Identity endpoints."""
import base64
import json
import os
import re
import secrets
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "bootstrap"))

from client_access import access_settings
from keycloak_admin import Admin


class CheckFailed(Exception):
    pass


class CheckUnavailable(Exception):
    pass


def fetch(url, *, method="GET", headers=None, body=None, label="endpoint"):
    request = urllib.request.Request(url, data=body, headers=headers or {}, method=method)
    try:
        with urllib.request.urlopen(request, timeout=10, context=ssl.create_default_context()) as response:
            return response.status, response.headers, response.read(1024 * 1024)
    except urllib.error.HTTPError as error:
        return error.code, error.headers, error.read(1024 * 1024)
    except (urllib.error.URLError, TimeoutError, ssl.SSLError, OSError) as error:
        raise CheckUnavailable(f"{label}: request failed ({type(error).__name__})") from None


def json_body(status, headers, body, label):
    if status != 200:
        raise CheckFailed(f"{label}: expected HTTP 200, got HTTP {status}")
    try:
        return json.loads(body)
    except (ValueError, TypeError):
        raise CheckFailed(f"{label}: response is not valid JSON") from None


def require_https(url, label):
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password or parsed.fragment:
        raise CheckFailed(f"{label}: expected a public HTTPS URL")


def validate_callback_response(status, headers, body):
    content_type = headers.get("Content-Type", "")
    if status != 200 or "text/html" not in content_type.lower():
        raise CheckFailed(f"Desktop authorization callback rejected (HTTP {status})")
    if b"<form" not in body.lower() or b"username" not in body.lower():
        raise CheckFailed("Desktop authorization did not reach the login form")


def validate_token_error(status, body):
    if status != 400:
        raise CheckFailed(f"token smoke request expected OAuth HTTP 400, got HTTP {status}")
    try:
        error = json.loads(body).get("error")
    except (ValueError, TypeError, AttributeError):
        error = None
    if error != "invalid_grant":
        raise CheckFailed("token smoke request did not receive the expected invalid_grant response")


def validate_token_cors(status, headers, body, origin):
    validate_token_error(status, body)
    if headers.get("Access-Control-Allow-Origin") != origin:
        raise CheckFailed("token response did not allow the exact Desktop Origin")


def validate_identity_key(key):
    if (not isinstance(key, dict) or key.get("kty") != "EC"
            or key.get("crv") != "P-256" or "d" in key):
        raise CheckFailed("public Identity JWKS must expose public EC P-256 keys only")
    coordinates = []
    for field in ("x", "y"):
        encoded = key.get(field)
        if not isinstance(encoded, str) or not re.fullmatch(r"[A-Za-z0-9_-]{43}", encoded):
            raise CheckFailed("Identity key requires 32-byte base64url x/y coordinates")
        raw = base64.urlsafe_b64decode(encoded + "=")
        if base64.urlsafe_b64encode(raw).decode().rstrip("=") != encoded:
            raise CheckFailed("Identity key coordinates are not canonical base64url")
        coordinates.append(int.from_bytes(raw, "big"))
    # SEC 2 secp256r1 parameters; a public point must satisfy y² = x³ - 3x + b.
    prime = 0xffffffff00000001000000000000000000000000ffffffffffffffffffffffff
    b = 0x5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b
    x, y = coordinates
    if x >= prime or y >= prime or (y * y - (x * x * x - 3 * x + b)) % prime:
        raise CheckFailed("Identity key coordinates do not describe a P-256 point")


def public_client(admin):
    clients = admin.require("GET", admin.path + "/clients?clientId=" + urllib.parse.quote(
        os.environ.get("GRYT_OIDC_CLIENT_ID", "gryt-web"), safe=""))
    if not isinstance(clients, list) or len(clients) != 1:
        raise CheckFailed("expected exactly one configured OIDC client")
    client = admin.require("GET", admin.path + "/clients/" + clients[0]["id"])
    if not isinstance(client, dict):
        raise CheckFailed("OIDC client Admin API response is invalid")
    try:
        expected = access_settings({})
    except ValueError:
        raise CheckFailed("configured callback or Web Origin additions are invalid") from None
    missing = {}
    for field, values in expected.items():
        current = client.get(field)
        if not isinstance(current, list):
            raise CheckFailed(f"OIDC client {field} is missing or invalid")
        absent = sorted(set(values) - set(current))
        if absent:
            missing[field] = absent
    if missing:
        raise CheckFailed("client callback or Web Origin allowlist is missing required entries")
    attributes = client.get("attributes")
    if not isinstance(attributes, dict):
        raise CheckFailed("OIDC client PKCE configuration is missing or invalid")
    if (client.get("enabled") is not True or client.get("publicClient") is not True
            or client.get("protocol") != "openid-connect"
            or client.get("standardFlowEnabled") is not True
            or attributes.get("pkce.code.challenge.method") != "S256"):
        raise CheckFailed("OIDC client must be enabled, public, use authorization code flow and require PKCE S256")
    return client


def check_admin_client():
    try:
        admin = Admin()
        public_client(admin)
    except CheckFailed:
        raise
    except ValueError as error:
        raise CheckFailed(str(error)) from None
    except Exception as error:
        raise CheckUnavailable(
            f"Keycloak Admin API check unavailable ({type(error).__name__}); check credentials and supported MFA flow"
        ) from None


def check_discovery_and_jwks():
    issuer = os.environ.get("GRYT_OIDC_ISSUER", "https://auth.inferlo.xyz/realms/gryt").rstrip("/")
    require_https(issuer, "GRYT_OIDC_ISSUER")
    discovery_url = issuer + "/.well-known/openid-configuration"
    status, headers, body = fetch(discovery_url, label="OIDC discovery")
    discovery = json_body(status, headers, body, "OIDC discovery")
    expected = {
        "issuer": issuer,
        "authorization_endpoint": issuer + "/protocol/openid-connect/auth",
        "token_endpoint": issuer + "/protocol/openid-connect/token",
        "jwks_uri": issuer + "/protocol/openid-connect/certs",
    }
    if any(discovery.get(key) != value for key, value in expected.items()):
        raise CheckFailed("OIDC discovery issuer or public endpoint URLs do not match configuration")
    status, headers, body = fetch(discovery["jwks_uri"], label="public OIDC JWKS")
    jwks = json_body(status, headers, body, "public OIDC JWKS")
    if not isinstance(jwks.get("keys"), list) or not jwks["keys"]:
        raise CheckFailed("public OIDC JWKS contains no keys")


def check_identity():
    origin = os.environ.get("GRYT_IDENTITY_ORIGIN", "https://id.inferlo.xyz").rstrip("/")
    require_https(origin, "GRYT_IDENTITY_ORIGIN")
    status, headers, body = fetch(origin + "/health", label="public Identity health")
    health = json_body(status, headers, body, "public Identity health")
    if health.get("status") != "ok":
        raise CheckFailed("public Identity health did not report status ok")
    status, headers, body = fetch(origin + "/.well-known/jwks.json", label="public Identity JWKS")
    jwks = json_body(status, headers, body, "public Identity JWKS")
    keys = jwks.get("keys")
    if not isinstance(keys, list) or not keys:
        raise CheckFailed("public Identity JWKS contains no keys")
    for key in keys:
        validate_identity_key(key)


def check_desktop_callbacks():
    issuer = os.environ.get("GRYT_OIDC_ISSUER", "https://auth.inferlo.xyz/realms/gryt").rstrip("/")
    auth = issuer + "/protocol/openid-connect/auth"
    callbacks = ("gryt://auth/callback", "https://gryt.chat/auth/callback")
    for callback in callbacks:
        query = urllib.parse.urlencode({
            "client_id": os.environ.get("GRYT_OIDC_CLIENT_ID", "gryt-web"),
            "response_type": "code", "redirect_uri": callback, "scope": "openid",
            "state": secrets.token_urlsafe(24), "code_challenge": secrets.token_urlsafe(32),
            "code_challenge_method": "S256",
        })
        status, headers, body = fetch(auth + "?" + query, label="Desktop authorization")
        validate_callback_response(status, headers, body)


def check_token_cors():
    issuer = os.environ.get("GRYT_OIDC_ISSUER", "https://auth.inferlo.xyz/realms/gryt").rstrip("/")
    origin = "http://127.0.0.1:15738"
    token_url = issuer + "/protocol/openid-connect/token"
    form = urllib.parse.urlencode({
        "grant_type": "authorization_code", "client_id": os.environ.get("GRYT_OIDC_CLIENT_ID", "gryt-web"),
        "code": "deployed-preflight-invalid-code", "redirect_uri": "gryt://auth/callback",
        "code_verifier": secrets.token_urlsafe(48),
    }).encode()
    status, headers, body = fetch(token_url, method="POST", body=form, headers={
        "Content-Type": "application/x-www-form-urlencoded", "Origin": origin,
    }, label="Desktop token CORS")
    validate_token_cors(status, headers, body, origin)
    denied = "https://preflight-untrusted.invalid"
    status, headers, body = fetch(token_url, method="POST", body=form, headers={
        "Content-Type": "application/x-www-form-urlencoded", "Origin": denied,
    }, label="denied Origin token CORS")
    validate_token_error(status, body)
    if headers.get("Access-Control-Allow-Origin") in (denied, "*"):
        raise CheckFailed("token endpoint allowed an untrusted Origin")


def run(label, check):
    try:
        check()
    except CheckUnavailable as error:
        print(f"  NOT EXECUTED: {label}: {error}")
        return "unavailable"
    except CheckFailed as error:
        print(f"  FAIL: {label}: {error}")
        return "failed"
    except Exception as error:
        print(f"  FAIL: {label}: unexpected error ({type(error).__name__})")
        return "failed"
    print(f"  ok:   {label}")
    return "passed"


def main():
    outcomes = [
        run("effective Keycloak callback/Origin settings and PKCE", check_admin_client),
        run("public OIDC discovery and JWKS", check_discovery_and_jwks),
        run("public Identity health and JWKS", check_identity),
        run("Desktop authorization callbacks", check_desktop_callbacks),
        run("token-response CORS", check_token_cors),
    ]
    if "failed" in outcomes:
        print("Deployed checks found configuration or authentication failures.")
        return 1
    if "unavailable" in outcomes:
        print("Deployed checks incomplete; unavailable checks are not PASS.")
        return 2
    print("Deployed endpoint checks passed. Graphical login/client acceptance is not established.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
