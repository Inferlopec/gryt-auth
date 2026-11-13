# Isolated validation evidence

Executed 2026-11-14 (Europe/Riga; work began November 13) in the local Docker
environment. No production data, keys, DNS, Caddy configuration or Gryt profile
was accessed or changed. Test containers were stopped after validation; test
volumes are retained for repeatability/review.

## Commands and outcomes

```bash
keycloak-pairing/build.sh
tests/run_all.sh --with-gryt
# Final run after rebuilding the extension from source:
tests/run_all.sh --with-gryt --no-build
```

The final full run exited 0. Raw local log: `/tmp/inferlo-identity-final-tests.log`
(ephemeral, not an archive of production evidence).

| Check | Outcome |
|---|---|
| Identity TypeScript compilation / image build | Passed |
| Pairing extension build from pinned Maven base and source | Passed |
| Existing upstream Identity unit tests | 20 passed |
| CA archive safety regression tests | 6 passed |
| Main integration cases | 8 passed, 0 failed, 0 skipped |
| OIDC code + PKCE and refresh | Passed; password grant remains disabled |
| Wrong password / wrong verifier | Rejected |
| Two device certificates for one account | Signatures, subject, issuer, JWK and lifetime verified |
| Signed wrong issuer/audience, expired/missing-exp token | Rejected by the actual Identity token validator with a controlled JWKS |
| Device grant approval and independent session refresh | Passed against Keycloak and the built extension |
| Pairing commitments, reveal, sealed messages and rate limiting | Passed |
| Two devices joining two actual Gryt servers | Passed |
| Same raw sub from another trusted CA | Different server identity, no owner inheritance |
| Per-server bans | Ban on A did not block B; test ban removed afterwards |
| Untrusted / expired certificates at Gryt join | Rejected with identity_verification_failed; positive controls passed |
| CA container recreation | Same JWKS; pre-recreation certificate verified cryptographically |
| Repeated initialization/client-policy jobs | Existing account subject and login preserved |
| SMTP settings update | Existing users preserved; quoted display name encoded correctly; old settings restored |
| Exceptional destructive realm replacement | Original account actually removed; pre-replacement backup created |
| Database restore through operational script | Original sub/login restored; post-backup marker absent |
| CA restore after deliberately corrupting the test key | Original JWKS and prior certificate trust restored |
| Base Compose and dedicated-VM override validation | Passed |
| Keycloak image / extension version coupling | Passed |
| Shell/Python/realm syntax and git diff whitespace checks | Passed |

Gryt Server fixture: `f537aa5e3d8a4bdba3c75e34b6dbfece2d727f42`.
The client/runtime/desktop-callback source was inspected at
`0cd7718ae834485ed3d4e9f5699f9800d9c7cdc1`, but it was not launched.

## Not executed / release blockers

- Real graphical Web/Desktop login, OS deep-link handling and client seed transfer.
- Public DNS/TLS and the real same-host or dedicated-VM Caddy/network topology.
- SMTP delivery, email verification and password-reset email receipt.
- Permanent administrator MFA and the corresponding automation credential path.
- Full TOTP enforcement in the custom realm browser flow.
- Off-host encrypted backup transport and a separate fresh-host restore exercise.
- Edge rate limiting for certificate issuance and real production-server compatibility.

These results establish the protocol/recovery milestone, not production readiness.
