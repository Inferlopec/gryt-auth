"""Apply the independent email verification and password recovery switches."""
import argparse
import json

from keycloak_admin import Admin, email_policy_settings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    desired = email_policy_settings()
    admin = Admin()
    current = admin.require("GET", admin.path)
    smtp = current.get("smtpServer") or {}
    if any(desired.values()) and not (smtp.get("host") and smtp.get("from")):
        raise RuntimeError(
            "Configure SMTP before enabling email verification or password recovery"
        )

    before = {key: current.get(key, False) for key in desired}
    print(json.dumps({"before": before, "after": desired}, indent=2))
    if args.dry_run:
        print("Dry run; no changes made.")
        return

    admin.require("PUT", admin.path, desired)
    actual = admin.require("GET", admin.path)
    if any(actual.get(key) is not value for key, value in desired.items()):
        raise RuntimeError("Email policy read-back failed")
    print("Email verification and password recovery settings applied; accounts preserved.")


if __name__ == "__main__":
    main()
