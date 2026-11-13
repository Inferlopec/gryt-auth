# Download

## Available now

The project currently exists as a local source snapshot. The intended
repository is `https://github.com/Inferlopec/gryt-auth`, but it has not been
created and there are no published releases or GHCR images yet.

If you already have the working project folder, use it for the
[current installation procedure](installation.md). Otherwise obtain that
snapshot from the maintainer. A ready-made operator download is not available
at this stage.

After the repository is created, source checkouts will be available there.
A source checkout still needs Docker builds; it is different from the planned
operator package.

## Planned operator download

Once releases are published, the repository's **Releases → Assets** section
will contain a versioned operator archive and `SHA256SUMS`. Download both files
for the same version. Choose the custom operator archive, not GitHub's
automatic **Source code** archive, which contains the full repository.

The intended archive name is `inferlo-identity-VERSION.tar.gz`. `VERSION` is a
placeholder for a published version, not an available release today. Once you
have the real files in the same folder:

```bash
sha256sum --check SHA256SUMS
```

Continue only when your selected archive reports `OK`. Follow the instructions
bundled with that version. The package is intended to contain Compose,
configuration examples, operational scripts, operator documentation, notices
and an image manifest. It will use prebuilt project images from GHCR.

Release packaging and the pull-only installer are not implemented yet. Do not
remove source folders from the current snapshot: today's initialize script
builds Identity Service and the pairing extension from them.
