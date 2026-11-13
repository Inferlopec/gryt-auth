"""Small Admin API client shared by explicit bootstrap jobs (stdlib only)."""
import json
import os
import urllib.error
import urllib.parse
import urllib.request


class Admin:
    def __init__(self):
        self.base = os.environ.get("KC_URL", "http://keycloak:8080").rstrip("/")
        self.realm = os.environ.get("GRYT_REALM", "gryt")
        self.token = None
        form = urllib.parse.urlencode({
            "client_id": "admin-cli", "grant_type": "password",
            "username": os.environ.get("GRYT_KEYCLOAK_ADMIN_USERNAME", "admin"),
            "password": os.environ["GRYT_KEYCLOAK_ADMIN_PASSWORD"],
        }).encode()
        status, data = self.call("POST", "/realms/master/protocol/openid-connect/token", form)
        if status != 200:
            raise RuntimeError(f"Admin authentication failed (HTTP {status})")
        self.token = data["access_token"]

    @property
    def path(self):
        return "/admin/realms/" + urllib.parse.quote(self.realm, safe="")

    def call(self, method, path, body=None):
        headers = {}
        if self.token:
            headers["Authorization"] = "Bearer " + self.token
        if isinstance(body, bytes):
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        elif body is not None:
            headers["Content-Type"] = "application/json"
            body = json.dumps(body).encode()
        request = urllib.request.Request(self.base + path, body, headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                raw = response.read()
                return response.status, json.loads(raw) if raw else None
        except urllib.error.HTTPError as error:
            # Do not print server bodies: realm representations can contain secrets.
            return error.code, None

    def require(self, method, path, body=None, expected=(200, 204)):
        status, data = self.call(method, path, body)
        if status not in expected:
            raise RuntimeError(f"{method} {path} failed (HTTP {status})")
        return data


def smtp_settings():
    host = os.environ.get("GRYT_SMTP_HOST", "")
    sender = os.environ.get("GRYT_SMTP_FROM", "")
    if bool(host) != bool(sender):
        raise ValueError("Set both GRYT_SMTP_HOST and GRYT_SMTP_FROM")
    smtp = {
        key: os.environ.get("GRYT_SMTP_" + env, default)
        for key, env, default in (
            ("host", "HOST", ""), ("port", "PORT", "587"),
            ("from", "FROM", ""), ("fromDisplayName", "FROM_NAME", "Inferlo"),
            ("replyTo", "REPLY_TO", ""), ("replyToDisplayName", "REPLY_TO_NAME", ""),
            ("user", "USER", ""), ("password", "PASS", ""),
        )
    }
    smtp["port"] = smtp["port"] or "587"
    smtp.update(starttls="true", ssl="false", auth=str(bool(smtp["user"])).lower())
    if smtp["user"] and not smtp["password"]:
        raise ValueError("GRYT_SMTP_PASS is required when GRYT_SMTP_USER is set")
    return smtp if host else {}
