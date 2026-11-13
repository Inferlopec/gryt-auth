"""Recovery must reject archives that can replace unrelated files or omit the CA."""
import io
import pathlib
import subprocess
import tarfile
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class ArchiveValidation(unittest.TestCase):
    def check_archive(self, entries, expected):
        with tempfile.TemporaryDirectory() as folder:
            archive = pathlib.Path(folder) / "backup.tar"
            with tarfile.open(archive, "w") as output:
                for name, kind in entries:
                    member = tarfile.TarInfo(name)
                    if kind == "link":
                        member.type = tarfile.SYMTYPE
                        member.linkname = "/tmp/unrelated-key"
                        output.addfile(member)
                    else:
                        data = b"-----BEGIN PRIVATE KEY-----\nfixture-header-only\n"
                        member.size = len(data)
                        output.addfile(member, io.BytesIO(data))
            result = subprocess.run(
                ["python3", str(ROOT / "scripts/validate_ca_archive.py"), str(archive)],
                capture_output=True,
            )
            self.assertEqual(result.returncode == 0, expected)

    def test_requires_key(self):
        self.check_archive([], False)

    def test_rejects_traversal(self):
        self.check_archive([("../ca-key.pem", "file")], False)

    def test_rejects_links(self):
        self.check_archive([("ca-key.pem", "link")], False)

    def test_rejects_duplicates(self):
        self.check_archive([("ca-key.pem", "file"), ("./ca-key.pem", "file")], False)

    def test_rejects_unrelated_files(self):
        self.check_archive([("ca-key.pem", "file"), ("unrelated.txt", "file")], False)

    def test_accepts_expected_layout(self):
        # The restore command performs the separate cryptographic key validation.
        self.check_archive([("./ca-key.pem", "file"), ("./accounts/abc.json", "file")], True)


if __name__ == "__main__":
    unittest.main()
