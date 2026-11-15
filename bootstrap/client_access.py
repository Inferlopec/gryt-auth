"""Explicit OAuth allowlists for BUG-01/BUG-02; no wildcard origins or ports."""
import json
import os
from urllib.parse import urlsplit


CALLBACKS = ("gryt://auth/callback", "https://gryt.chat/auth/callback")
DESKTOP_LOOPBACK_REDIRECT = "http://127.0.0.1:15738/*"
DESKTOP_ORIGIN = "http://127.0.0.1:15738"


def additions(name, origin=False):
    values = json.loads(os.environ.get(name, "[]"))
    if not isinstance(values, list):
        raise ValueError(f"{name} must be a JSON array")
    for value in values:
        if not isinstance(value, str) or not value or any(c.isspace() for c in value):
            raise ValueError(f"{name} requires nonempty URLs without whitespace")
        parsed = urlsplit(value)
        # Additional callbacks must be exact, including any custom scheme route.
        if ("*" in value or not parsed.scheme or not parsed.netloc
                or parsed.username or parsed.password or parsed.fragment):
            raise ValueError(f"{name} requires exact URLs without credentials or fragments")
        if origin:
            if (parsed.scheme not in ("http", "https") or parsed.path
                    or parsed.query or value != f"{parsed.scheme}://{parsed.netloc}"):
                raise ValueError(f"{name} requires exact HTTP(S) origins without paths")
        # Validate numeric port syntax/range too.
        parsed.port
    return values


def access_settings(client):
    redirects = additions("GRYT_OIDC_EXTRA_REDIRECT_URIS")
    origins = additions("GRYT_OIDC_EXTRA_WEB_ORIGINS", origin=True)
    result = {}
    for field, required, extra in (
        ("redirectUris", (*CALLBACKS, DESKTOP_LOOPBACK_REDIRECT), redirects),
        ("webOrigins", (DESKTOP_ORIGIN,), origins),
    ):
        # Remove only the known ineffective legacy entry; preserve operator settings.
        current = [v for v in client.get(field, []) if v != "http://127.0.0.1:*"]
        result[field] = list(dict.fromkeys([*current, *required, *extra]))
    return result
