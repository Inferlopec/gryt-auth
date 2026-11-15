"""Update mail settings through the live API without replacing accounts."""
from keycloak_admin import Admin, smtp_settings

admin = Admin()
smtp = smtp_settings()
if not smtp:
    raise ValueError("Set GRYT_SMTP_HOST and GRYT_SMTP_FROM before configuring SMTP")
admin.require("PUT", admin.path, {"smtpServer": smtp})
current = admin.require("GET", admin.path)
if current.get("smtpServer", {}).get("host") != smtp["host"]:
    raise RuntimeError("SMTP read-back failed")
print("SMTP updated; email verification and password recovery settings were left unchanged.")
