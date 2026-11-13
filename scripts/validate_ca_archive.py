"""Reject empty archives, traversal, links, and unrelated files before CA restoration."""
import pathlib
import sys
import tarfile

with tarfile.open(sys.argv[1], "r:*") as archive:
    key = None
    seen = set()
    for member in archive:
        path = pathlib.PurePosixPath(member.name)
        if path.is_absolute() or ".." in path.parts or member.issym() or member.islnk():
            raise ValueError("Unsafe path or link in CA archive")
        name = str(path)
        if name in seen:
            raise ValueError("Duplicate archive member")
        seen.add(name)
        if member.isdir():
            if name not in (".", "accounts"):
                raise ValueError("Unexpected directory in CA archive")
            continue
        if not member.isfile():
            raise ValueError("Only regular files/directories are allowed")
        if name != "ca-key.pem" and not (len(path.parts) == 2 and path.parts[0] == "accounts" and path.suffix == ".json"):
            raise ValueError("Unexpected file in CA archive")
        if member.size > 1024 * 1024:
            raise ValueError("Oversized CA archive member")
        if name == "ca-key.pem":
            key = archive.extractfile(member).read()
    if not key or not key.startswith(b"-----BEGIN PRIVATE KEY-----"):
        raise ValueError("Archive does not contain a nonempty PKCS8 CA key")
    if "--key" in sys.argv:
        sys.stdout.buffer.write(key)
