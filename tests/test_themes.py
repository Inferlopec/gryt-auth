"""Realm theme defaults and non-destructive live theme updates."""
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bootstrap"))

import configure_themes  # noqa: E402


class ThemeTests(unittest.TestCase):
    def test_realm_uses_themes_available_in_pinned_keycloak(self):
        realm = json.loads((ROOT / "realm/gryt-realm.json").read_text())
        self.assertEqual(realm["loginTheme"], "keycloak.v2")
        self.assertEqual(realm["accountTheme"], "keycloak.v3")
        self.assertEqual(realm["emailTheme"], "keycloak")

    def test_live_update_only_changes_theme_fields_and_preserves_accounts(self):
        class FakeAdmin:
            path = "/admin/realms/gryt"

            def __init__(self):
                self.realm = {
                    **configure_themes.THEMES,
                    "realm": "gryt", "id": "realm-id", "registrationAllowed": False,
                    "smtpServer": {"host": "mail.example.test"},
                    "users": [{"id": "existing-user", "username": "alice"}],
                }
                self.writes = []

            def require(self, method, path, body=None):
                if method == "GET":
                    return json.loads(json.dumps(self.realm))
                if method == "PUT":
                    self.writes.append(dict(body))
                    self.realm.update(body)
                    return None
                raise AssertionError(f"Unexpected request: {method} {path}")

        admin = FakeAdmin()
        admin.realm.update({"loginTheme": "base", "accountTheme": "base", "emailTheme": "base"})
        with patch.object(configure_themes, "Admin", return_value=admin):
            with patch.object(sys, "argv", ["configure_themes.py", "--dry-run"]):
                configure_themes.main()
                self.assertFalse(admin.writes)
            with patch.object(sys, "argv", ["configure_themes.py"]):
                configure_themes.main()

        self.assertEqual(admin.writes, [configure_themes.THEMES])
        self.assertEqual(admin.realm["users"][0]["id"], "existing-user")
        self.assertFalse(admin.realm["registrationAllowed"])
        self.assertEqual(admin.realm["smtpServer"], {"host": "mail.example.test"})


if __name__ == "__main__":
    unittest.main()
