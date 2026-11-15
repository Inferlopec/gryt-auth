#!/usr/bin/env python3
"""Offline validation for independent email policy environment settings."""
import os
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "bootstrap"))
from keycloak_admin import email_policy_settings  # noqa: E402


class EmailPolicySettingsTests(unittest.TestCase):
    def test_defaults_are_disabled(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(email_policy_settings(), {
                "verifyEmail": False,
                "resetPasswordAllowed": False,
            })

    def test_settings_are_independent(self):
        with patch.dict(os.environ, {
            "GRYT_VERIFY_EMAIL": "true",
            "GRYT_RESET_PASSWORD_ALLOWED": "false",
        }, clear=True):
            self.assertEqual(email_policy_settings(), {
                "verifyEmail": True,
                "resetPasswordAllowed": False,
            })

    def test_invalid_value_is_rejected(self):
        with patch.dict(os.environ, {
            "GRYT_VERIFY_EMAIL": "sometimes",
        }, clear=True):
            with self.assertRaisesRegex(ValueError, "GRYT_VERIFY_EMAIL"):
                email_policy_settings()


if __name__ == "__main__":
    unittest.main()
