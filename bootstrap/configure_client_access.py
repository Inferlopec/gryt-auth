"""Apply reviewed client allowlist additions without replacing the realm or users."""
import argparse
import json

from client_access import access_settings
from keycloak_admin import Admin


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    # Reject invalid additions before authenticating or making any changes.
    access_settings({})
    admin = Admin()
    clients = admin.require("GET", admin.path + "/clients?clientId=gryt-web")
    if len(clients) != 1:
        raise RuntimeError("Expected exactly one gryt-web client")
    path = admin.path + "/clients/" + clients[0]["id"]
    current = admin.require("GET", path)
    desired = access_settings(current)
    print(json.dumps({"before": {k: current.get(k, []) for k in desired},
                      "after": desired}, indent=2))
    if args.dry_run:
        print("Dry run; no changes made.")
        return
    # Partial ClientRepresentation update touches only these two allowlists.
    admin.require("PUT", path, desired)
    actual = admin.require("GET", path)
    if any(set(actual.get(k, [])) != set(v) for k, v in desired.items()):
        raise RuntimeError("Client access allowlist read-back failed")
    print("gryt-web callback and Web Origins configured; accounts preserved.")


if __name__ == "__main__":
    main()
