"""Create a missing realm; replacing one is a separate, destructive recovery action."""
import json
import pathlib
import sys

from keycloak_admin import Admin, email_policy_settings, smtp_settings
from client_access import access_settings


def main():
    admin = Admin()
    realm = json.loads(pathlib.Path("/realm/gryt-realm.json").read_text())
    if realm["realm"] != admin.realm:
        raise ValueError("GRYT_REALM must match the versioned realm template")
    client = next(c for c in realm["clients"] if c["clientId"] == "gryt-web")
    client.update(access_settings(client))
    smtp = smtp_settings()
    email_policy = email_policy_settings()
    if any(email_policy.values()) and not smtp:
        raise ValueError("SMTP must be configured before enabling email verification or password recovery")
    realm["smtpServer"] = smtp
    realm.update(email_policy)
    status, _ = admin.call("GET", admin.path)
    if status == 200:
        if sys.argv[1:] != ["--replace-realm"]:
            print("Realm already exists; accounts and configuration left intact.")
            return
        admin.require("DELETE", admin.path)
    elif status != 404:
        raise RuntimeError(f"Cannot check realm existence (HTTP {status})")
    admin.require("POST", "/admin/realms", realm, expected=(201,))
    print("Realm created. Email policy: " + str(email_policy))


if __name__ == "__main__":
    main()
