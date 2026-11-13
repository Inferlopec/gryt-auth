# Manage users

Accounts belong to Keycloak realm **gryt**. Creating an account does not add
it to every Gryt server or assign server roles. Use invitations and server
settings for those tasks.

## Open the administrator console

Open `https://auth.inferlo.xyz/admin` and sign in with the administrator
configured in `.env`. Select realm **gryt** before opening **Users**; `master`
is for Keycloak administration, not Gryt accounts. Adapt the domain if changed.

For routine work, the console avoids putting passwords on a shell command
line. The current CLI scripts use the admin password grant; MFA-compatible
automation is still [pending](readiness.md). Do not turn off administrator MFA
to make a script work.

## Create an account

In realm gryt, open **Users**, create a user with their email address, and set
a password in that user's credentials. Provide requested profile fields.
With working SMTP, have the person verify their email; do not mark an address
verified unless you have actually verified it.

For the current script-based setup, run from `/opt/inferlo-identity`:

```bash
read -r -s -p 'New account password: ' ACCOUNT_PASSWORD
scripts/users.sh create_user alice@example.com "$ACCOUNT_PASSWORD"
unset ACCOUNT_PASSWORD
```

Use a password of at least 12 characters that differs from the username/email.
The script creates an enabled account with an unverified email. The realm can
ask for missing profile details on first login. A password rejected after user
creation can leave the account present: use reset_password below to complete
setup instead of trying to create it again. Shell variables reduce history
exposure, but the invoked process still receives the password as an argument.

## List accounts

```bash
scripts/users.sh list_users
```

Output columns: user ID, username/email, enabled status. The script lists up
to 100 accounts; use the console's search/pagination for larger installations.

## Reset a password

Use the user's credentials page in the console, or:

```bash
read -r -s -p 'Replacement password: ' ACCOUNT_PASSWORD
scripts/users.sh reset_password alice@example.com "$ACCOUNT_PASSWORD"
unset ACCOUNT_PASSWORD
```

Ask the person to sign in again. Do not interpret a password reset as revoking
all previously issued Gryt certificates. With configured SMTP, the user can
also use Keycloak's password-recovery page.

## Disable or enable an account

Turn the user's enabled state off/on in the console, or:

```bash
scripts/users.sh set_user_disabled alice@example.com true
scripts/users.sh set_user_disabled alice@example.com false
```

The first command disables; the second enables. Confirm with list_users.
Disabling stops future account authentication, but does not immediately revoke
existing access tokens/certificates. For immediate server exclusion, apply a
ban separately on each relevant Gryt server. Certificates last 30 days by
default, with verification clock tolerance.

## Delete an account

There is currently **no delete command in users.sh**. In Keycloak realm gryt,
find the exact user, verify their email and ID, select the delete action and
confirm it. Back up the database first if the deletion may need reversing.

Deletion removes the central account. It does not delete chat history or
membership records stored by individual Gryt servers, and it is not immediate
revocation of an existing certificate. Ban the identity on affected servers
if immediate exclusion is needed. Recreating the same email creates a new
account ID; it does not restore the old identity or ownership. Use database
[recovery](backup-and-recovery.md) to recover original IDs when appropriate.
