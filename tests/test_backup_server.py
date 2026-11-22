"""Regression coverage for offline backups of private server data."""
import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.backup_server import backup


class BackupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        home = Path(self.tmp.name)
        self.root = home / "server"
        self.root.mkdir()
        self.data = self.root / "scriptfiles"
        (self.data / "players").mkdir(parents=True)
        (self.root / "server.cfg").write_bytes(b"rcon_password SECRET\r\n")
        (self.data / "players" / "test.ini").write_bytes(b"Money=4500\r\n")
        self.out = home / "private-backup.zip"

    def test_backup_keeps_exact_private_file_bytes(self):
        count = backup(self.root, self.out)
        self.assertEqual(count, 2)
        with zipfile.ZipFile(self.out) as z:
            self.assertEqual(sorted(z.namelist()), ["scriptfiles/players/test.ini", "server.cfg"])
            self.assertEqual(z.read("server.cfg"), b"rcon_password SECRET\r\n")
            self.assertEqual(z.read("scriptfiles/players/test.ini"), b"Money=4500\r\n")
            self.assertIsNone(z.testzip())

    def test_refuses_overwriting_existing_backup(self):
        self.out.write_bytes(b"previous")
        with self.assertRaises(FileExistsError):
            backup(self.root, self.out)
        self.assertEqual(self.out.read_bytes(), b"previous")

    def test_refuses_backup_inside_server(self):
        with self.assertRaisesRegex(ValueError, "outside"):
            backup(self.root, self.root / "snapshot.zip")

    def test_refuses_missing_private_config(self):
        (self.root / "server.cfg").unlink()
        with self.assertRaisesRegex(ValueError, "server.cfg"):
            backup(self.root, self.out)
        self.assertFalse(self.out.exists())

    def test_refuses_missing_scriptfiles(self):
        (self.data / "players" / "test.ini").unlink()
        (self.data / "players").rmdir()
        self.data.rmdir()
        with self.assertRaisesRegex(ValueError, "scriptfiles"):
            backup(self.root, self.out)

    def test_refuses_symlinked_player_files_when_supported(self):
        link = self.data / "players" / "linked.ini"
        try:
            link.symlink_to(self.root / "server.cfg")
        except (OSError, NotImplementedError):
            self.skipTest("Symlinks unavailable on this Windows runner")
        with self.assertRaisesRegex(ValueError, "Unsupported file"):
            backup(self.root, self.out)
        self.assertFalse(self.out.exists())


if __name__ == "__main__":
    unittest.main()
