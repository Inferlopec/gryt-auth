"""Offline checks for deployed preflight validation and safe failure cases."""
import base64
import json
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from deployed_preflight import (  # noqa: E402
    CheckFailed,
    check_admin_client,
    check_identity,
    check_token_cors,
    validate_callback_response,
    validate_token_cors,
)


class FakeResponseHeaders(dict):
    pass


class DeployedPreflightTests(unittest.TestCase):
    def test_identity_rejects_unusable_public_keys(self):
        def coordinate(number):
            return base64.urlsafe_b64encode(number.to_bytes(32, "big")).decode().rstrip("=")

        # Standard P-256 generator point, independent of the validation code.
        key = {"kty": "EC", "crv": "P-256",
               "x": coordinate(0x6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296),
               "y": coordinate(0x4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5)}

        def check(candidate):
            responses = [(200, {}, b'{"status":"ok"}'),
                         (200, {}, json.dumps({"keys": [candidate]}).encode())]
            with patch("deployed_preflight.fetch", side_effect=responses):
                check_identity()

        check(key)
        invalid = [
            {"kty": "EC", "crv": "P-256"},
            {**key, "x": "!" * 43}, {**key, "y": "AA"},
            {**key, "x": coordinate(0), "y": coordinate(0)},
            {**key, "x": coordinate(2**256 - 1)}, {**key, "d": coordinate(1)},
        ]
        for candidate in invalid:
            with self.subTest(candidate=candidate), self.assertRaises(CheckFailed):
                check(candidate)

    def test_denied_origin_requires_an_oauth_response(self):
        allowed = (400, {"Access-Control-Allow-Origin": "http://127.0.0.1:15738"},
                   b'{"error":"invalid_grant"}')
        denied = (400, {}, b'{"error":"invalid_grant"}')
        with patch("deployed_preflight.fetch", side_effect=[allowed, denied]):
            check_token_cors()
        for response in [(502, {}, b"Bad Gateway"), (200, {}, b"<html>proxy</html>"),
                         (400, {}, b'{"error":"invalid_client"}'), (400, {}, b"not JSON"),
                         (400, {"Access-Control-Allow-Origin": "*"}, denied[2]),
                         (400, {"Access-Control-Allow-Origin": "https://preflight-untrusted.invalid"}, denied[2])]:
            with self.subTest(response=response):
                with patch("deployed_preflight.fetch", side_effect=[allowed, response]):
                    with self.assertRaises(CheckFailed):
                        check_token_cors()

    def test_callback_login_form_is_accepted(self):
        validate_callback_response(200, FakeResponseHeaders({"Content-Type": "text/html"}),
                                  b'<form><input name="username"></form>')

    def test_rejected_callback_is_detected(self):
        with self.assertRaisesRegex(CheckFailed, "callback rejected"):
            validate_callback_response(400, FakeResponseHeaders({"Content-Type": "text/html"}),
                                      b"Invalid parameter: redirect_uri")

    def test_token_response_requires_exact_cors_origin(self):
        body = json.dumps({"error": "invalid_grant"}).encode()
        validate_token_cors(400, FakeResponseHeaders({"Access-Control-Allow-Origin": "http://127.0.0.1:15738"}),
                            body, "http://127.0.0.1:15738")
        with self.assertRaisesRegex(CheckFailed, "exact Desktop Origin"):
            validate_token_cors(400, FakeResponseHeaders({}), body, "http://127.0.0.1:15738")

    def test_client_check_detects_missing_callback_or_origin(self):
        class FakeAdmin:
            path = "/admin/realms/gryt"

            def __init__(self, missing):
                self.missing = missing

            def require(self, method, path):
                if "?clientId=" in path:
                    return [{"id": "fixture"}]
                client = {
                    "enabled": True, "publicClient": True, "protocol": "openid-connect",
                    "standardFlowEnabled": True,
                    "attributes": {"pkce.code.challenge.method": "S256"},
                    "redirectUris": ["gryt://auth/callback", "https://gryt.chat/auth/callback",
                                     "http://127.0.0.1:15738/*"],
                    "webOrigins": ["http://127.0.0.1:15738"],
                }
                if self.missing == "callback":
                    client["redirectUris"].remove("gryt://auth/callback")
                if self.missing == "origin":
                    client["webOrigins"].clear()
                return client

        with patch("deployed_preflight.Admin", return_value=FakeAdmin(None)):
            check_admin_client()
        for missing in ("callback", "origin"):
            with self.subTest(missing=missing), patch("deployed_preflight.Admin", return_value=FakeAdmin(missing)):
                with self.assertRaisesRegex(CheckFailed, "allowlist"):
                    check_admin_client()
        with patch("deployed_preflight.Admin", return_value=FakeAdmin(None)):
            with patch.dict(os.environ, {"GRYT_OIDC_EXTRA_WEB_ORIGINS": "not-json"}):
                with self.assertRaisesRegex(CheckFailed, "callback or Web Origin additions"):
                    check_admin_client()


if __name__ == "__main__":
    unittest.main()
