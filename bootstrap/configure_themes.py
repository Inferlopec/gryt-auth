"""Set supported built-in login, account and email themes without replacing the realm."""
import argparse
import json

from keycloak_admin import Admin


THEMES = {
    "loginTheme": "keycloak.v2",
    "accountTheme": "keycloak.v3",
    "emailTheme": "keycloak",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    admin = Admin()
    current = admin.require("GET", admin.path)
    before = {key: current.get(key) for key in THEMES}
    print(json.dumps({"before": before, "after": THEMES}, indent=2))
    if args.dry_run:
        print("Dry run; no changes made.")
        return

    admin.require("PUT", admin.path, THEMES)
    actual = admin.require("GET", admin.path)
    if any(actual.get(key) != value for key, value in THEMES.items()):
        raise RuntimeError("Realm theme read-back failed")
    print("Built-in Keycloak themes applied; accounts preserved. Graphical acceptance remains pending.")


if __name__ == "__main__":
    main()
