"""Exercise the actual deployed preflight against isolated HTTP fixtures (#4)."""
import contextlib
import io
import os
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, "/scripts")
import deployed_preflight as preflight


class DeployedIntegrationTests(unittest.TestCase):
    def setUp(self):
        # Never run this mutation harness against operator-provided endpoints.
        self.assertEqual(os.environ["KC_URL"], "http://keycloak:8080")
        self.assertEqual(os.environ["GRYT_OIDC_ISSUER"], "http://keycloak:8080/realms/gryt")
        self.assertEqual(os.environ["GRYT_IDENTITY_ORIGIN"], "http://identity:3000")
        self.admin = preflight.Admin()
        clients = self.admin.require("GET", self.admin.path + "/clients?clientId=gryt-web")
        self.assertEqual(len(clients), 1)
        self.path = self.admin.path + "/clients/" + clients[0]["id"]
        client = self.admin.require("GET", self.path)
        self.original = {name: client[name] for name in ("redirectUris", "webOrigins")}
        self.addCleanup(self.admin.require, "PUT", self.path, self.original)

    def run_preflight(self):
        def fixture_transport(url, label):
            # Only the HTTPS policy is replaced: every request, parser,
            # validator and exit-code decision comes from the production module.
            self.assertIn(url, ("http://keycloak:8080/realms/gryt", "http://identity:3000"))

        output = io.StringIO()
        with patch.object(preflight, "require_https", side_effect=fixture_transport):
            with contextlib.redirect_stdout(output):
                result = preflight.main()
        return result, output.getvalue()

    def assert_healthy(self):
        result, output = self.run_preflight()
        self.assertEqual(result, 0, output)

    def test_removed_callback_fails_actual_preflight(self):
        self.assert_healthy()
        self.admin.require("PUT", self.path, {"redirectUris": [
            uri for uri in self.original["redirectUris"] if uri != "gryt://auth/callback"
        ]})
        result, output = self.run_preflight()
        self.assertEqual(result, 1, output)
        self.assertIn("FAIL: Desktop authorization callbacks", output)
        self.assertIn("callback rejected (HTTP 400)", output)
        self.admin.require("PUT", self.path, self.original)
        self.assert_healthy()

    def test_removed_origin_fails_actual_preflight_despite_options(self):
        self.assert_healthy()
        self.admin.require("PUT", self.path, {"webOrigins": [
            origin for origin in self.original["webOrigins"] if origin != "http://127.0.0.1:15738"
        ]})
        status, headers, _ = preflight.fetch(
            os.environ["GRYT_OIDC_ISSUER"] + "/protocol/openid-connect/token",
            method="OPTIONS", headers={"Origin": "http://127.0.0.1:15738",
                                       "Access-Control-Request-Method": "POST"})
        self.assertEqual(status, 200)
        self.assertEqual(headers.get("Access-Control-Allow-Origin"), "http://127.0.0.1:15738")
        result, output = self.run_preflight()
        self.assertEqual(result, 1, output)
        self.assertIn("FAIL: token-response CORS", output)
        self.assertIn("token response did not allow the exact Desktop Origin", output)
        self.admin.require("PUT", self.path, self.original)
        self.assert_healthy()


if __name__ == "__main__":
    unittest.main()
