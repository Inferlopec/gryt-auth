"""Regression checks for allowlist validation and non-destructive live updates."""
import copy
import json
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'bootstrap'))
from client_access import access_settings, CALLBACK, DESKTOP_ORIGIN
import configure_client_access


class ClientAccessTests(unittest.TestCase):
    def test_template(self):
        client = json.loads((ROOT / 'realm/gryt-realm.json').read_text())['clients'][0]
        self.assertIn(CALLBACK, client['redirectUris'])
        self.assertIn(DESKTOP_ORIGIN, client['webOrigins'])
        self.assertEqual(access_settings(client), {k: client[k] for k in ('redirectUris', 'webOrigins')})
        self.assertEqual(client['attributes']['pkce.code.challenge.method'], 'S256')

    def test_preservation_and_idempotency(self):
        current = {'redirectUris': ['gryt://auth/callback', 'https://custom.test/cb', 'http://127.0.0.1:*'],
                   'webOrigins': ['https://custom.test', 'http://127.0.0.1:*']}
        before = copy.deepcopy(current)
        with patch.dict(os.environ, {'GRYT_OIDC_EXTRA_REDIRECT_URIS': '["https://other.test/cb"]',
                                     'GRYT_OIDC_EXTRA_WEB_ORIGINS': '["http://127.0.0.1:20000"]'}):
            desired = access_settings(current)
            self.assertEqual(access_settings(desired), desired)
        self.assertEqual(current, before)
        self.assertIn('https://custom.test/cb', desired['redirectUris'])
        self.assertIn('http://127.0.0.1:20000', desired['webOrigins'])
        self.assertNotIn('http://127.0.0.1:*', desired['webOrigins'])

    def test_invalid_additions(self):
        for name in ('GRYT_OIDC_EXTRA_REDIRECT_URIS', 'GRYT_OIDC_EXTRA_WEB_ORIGINS'):
            for value in ('null', '{}', '"https://example.test"', '[1]', '["*"]',
                          '["http://127.0.0.1:*"]', '["https://u:p@example.test"]',
                          '["https://example.test/#fragment"]'):
                with self.subTest(name=name, value=value), patch.dict(os.environ, {name: value}):
                    with self.assertRaises(ValueError):
                        access_settings({})
        for value in ('["https://example.test/"]', '["https://example.test/path"]', '["null"]'):
            with patch.dict(os.environ, {'GRYT_OIDC_EXTRA_WEB_ORIGINS': value}):
                with self.assertRaises(ValueError):
                    access_settings({})

    def test_live_update_only_changes_allowlists(self):
        class FakeAdmin:
            path = '/admin/realms/gryt'
            client = {'id': 'abc', 'redirectUris': ['gryt://auth/callback'], 'webOrigins': [],
                      'attributes': {'pkce.code.challenge.method': 'S256'}, 'publicClient': True}
            writes = []

            def require(self, method, path, body=None):
                if method == 'PUT':
                    self.writes.append(copy.deepcopy(body))
                    self.client.update({k: list(reversed(v)) for k, v in body.items()})
                    return
                if '?' in path:
                    return [{'id': 'abc'}]
                return copy.deepcopy(self.client)

        admin = FakeAdmin()
        with patch.object(configure_client_access, 'Admin', return_value=admin):
            with patch.object(sys, 'argv', ['configure_client_access.py', '--dry-run']):
                configure_client_access.main()
                self.assertFalse(admin.writes)
            with patch.object(sys, 'argv', ['configure_client_access.py']):
                configure_client_access.main()
                configure_client_access.main()
        self.assertEqual(set(admin.writes[0]), {'redirectUris', 'webOrigins'})
        self.assertEqual({k: set(v) for k, v in admin.writes[0].items()},
                         {k: set(v) for k, v in admin.writes[1].items()})
        self.assertTrue(admin.client['publicClient'])
        self.assertEqual(admin.client['attributes']['pkce.code.challenge.method'], 'S256')


if __name__ == '__main__':
    unittest.main()
