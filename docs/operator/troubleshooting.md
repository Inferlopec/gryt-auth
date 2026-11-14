# Troubleshooting

Start from `/opt/inferlo-identity`:

```bash
docker compose ps
docker compose logs --tail 100 keycloak identity postgres pg-backup
```

Logs and configuration may contain personal data or secrets. Remove those
before sharing a report.

## There is no release to download

That is the current state. The intended repository has not been created and
no project images are published. Follow [download](download.md); do not use a
made-up release URL or a different project's auth images.

## Preflight reports a missing pairing JAR

In the current source snapshot, run `keycloak-pairing/build.sh` from the root,
then preflight again. If Docker previously created an empty directory named
`keycloak-pairing/dist/gryt-pairing.jar`, the build script handles an empty
one. Stop and inspect a nonempty unexpected directory rather than deleting it
blindly. A ready-made JAR/image will come with the future operator release.

## Keycloak stays unhealthy or restarts

Check `docker compose logs --tail 100 keycloak postgres`, available host memory,
and `docker inspect inferlo-identity-keycloak --format '{{.State.OOMKilled}}'`.
A true OOM flag indicates insufficient memory. Check DB credentials and the
pairing JAR/version too. Changing `.env`'s DB password does not rotate an
existing database password. Do not remove volumes or re-import the realm to
solve a startup failure.

## Caddy returns 502

Check local backends using the curl commands in
[installation](installation.md#3-build-and-initialize). If those fail, fix the
backend first. If local checks work, confirm Caddy's upstream ports match
`.env` and Caddy uses host networking. A bridge-network Caddy's 127.0.0.1 points
at its own container, not the host; use a reviewed network-specific route or
the appropriate existing proxy network. The supplied loopback snippet is for
host networking only.

## HTTPS discovery redirects incorrectly, or login reports an invalid issuer

Confirm `.env`'s public Keycloak URL and OIDC issuer use the same auth domain
and `/realms/gryt`. Confirm DNS and proxy headers, including the actual
trusted-proxy address. The discovery response must advertise the public issuer.
Follow [configuration](configuration.md#proxy-trust); do not set trust to every
address or disable hostname checks as a workaround.

## Certificate requests say invalid token or no applicable JWKS key

Confirm the client uses both Inferlo issuer and Identity Service URL. Check
that the access token was issued by this realm and intended for gryt-web;
do not paste tokens into public decoders. For an older existing realm, apply
the missing audience mapper and sign in again:

```bash
docker compose run --rm --no-deps keycloak-client-policy
```

This preserves accounts. A new token is necessary; the old token's claims do
not change when a mapper is updated.

## A trusted account still cannot join a server

Check the specific Gryt server's logs, its effective trust list and issuer
order, and whether that user needs an invitation or is banned. Confirm it is
the supported server revision. A Keycloak account is not automatic server
membership. If users unexpectedly lose roles, stop the rollout and restore
the original issuer order/profile using [rollback](rollback.md).

## Desktop opens a browser but never completes login

Inspect the selected Desktop release's callback setting and OS gryt:// handler.
Changing issuer/Identity fields in the UI does not change the callback. Follow
[clients](clients.md#desktop-callback); do not assume an app-hosted SPA path is
a callback bridge. The macOS staging result and remaining callback limitations are documented there.

## Email verification or password reset never arrives

Check that SMTP was configured through the keycloak-smtp job, not only edited
in `.env`. Test sending in Keycloak's realm email settings. Check credentials,
STARTTLS/port, sender restrictions and the provider's delivery logs/spam folder.
No SMTP means these features were disabled at initialization. Do not replace
the realm to change mail settings.

## Identity refuses to load the CA key

This is deliberate protection against replacing an existing identity authority.
Inspect its persistent volume/mount and file permissions; restore the original
key from [backup](backup-and-recovery.md). Do not enable key generation on a
normal running installation or delete the volume to bypass the error.

## Everyone shares the pairing rate limit

Confirm Caddy overwrites CF-Connecting-IP as in the supplied snippet, and
Identity trusts Caddy's actual socket source. Host-loopback publication does
not guarantee a 127.0.0.1 peer inside the container. Do not solve this by
trusting visitor-supplied headers or disabling rate limits.
