"""Create a missing realm; replacing one is a separate, destructive recovery action."""
import json
import pathlib
import sys

from keycloak_admin import Admin, smtp_settings
from client_access import access_settings


def main():
    admin = Admin()
    realm = json.loads(pathlib.Path("/realm/gryt-realm.json").read_text())
    if realm["realm"] != admin.realm:
        raise ValueError("GRYT_REALM must match the versioned realm template")
    client = next(c for c in realm["clients"] if c["clientId"] == "gryt-web")
    client.update(access_settings(client))
    realm["smtpServer"] = smtp_settings()
    realm["verifyEmail"] = bool(realm["smtpServer"])
    realm["resetPasswordAllowed"] = bool(realm["smtpServer"])
    status, _ = admin.call("GET", admin.path)
    if status == 200:
        if sys.argv[1:] != ["--replace-realm"]:
            print("Realm already exists; accounts and configuration left intact.")
            return
        admin.require("DELETE", admin.path)
    elif status != 404:
        raise RuntimeError(f"Cannot check realm existence (HTTP {status})")
    admin.require("POST", "/admin/realms", realm, expected=(201,))
    print("Realm created. Email verification/recovery: " + str(bool(realm["smtpServer"])))


if __name__ == "__main__":
    main()
