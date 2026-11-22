"""Tests of staging-only restore, malicious archives and data integrity."""
import stat
import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.backup_server import backup
from tools.restore_backup import restore


class StagedRestoreTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.server = self.home / "server"
        (self.server / "scriptfiles" / "players").mkdir(parents=True)
        (self.server / "server.cfg").write_bytes(b"rcon_password secret\r\n")
        (self.server / "scriptfiles" / "players" / "Player.ini").write_bytes(b"Money=1500\r\n")
        self.zip = self.home / "backup.zip"
        self.stage = self.home / "staged"

    def test_round_trip_preserves_bytes_and_server_untouched(self):
        backup(self.server, self.zip)
        self.assertEqual(restore(self.zip, self.stage), 2)
        self.assertEqual((self.stage / "server.cfg").read_bytes(), b"rcon_password secret\r\n")
        self.assertEqual((self.stage / "scriptfiles/players/Player.ini").read_bytes(), b"Money=1500\r\n")
        self.assertEqual((self.server / "scriptfiles/players/Player.ini").read_bytes(), b"Money=1500\r\n")

    def test_refuses_existing_directory(self):
        backup(self.server, self.zip)
        self.stage.mkdir()
        (self.stage / "keep.txt").write_bytes(b"keep")
        with self.assertRaises(FileExistsError):
            restore(self.zip, self.stage)
        self.assertEqual((self.stage / "keep.txt").read_bytes(), b"keep")

    def make_zip(self, extra_name, extra_content=b"bad"):
        with zipfile.ZipFile(self.zip, "w") as archive:
            archive.writestr("server.cfg", "private")
            archive.writestr("scriptfiles/players/Player.ini", "Money=1")
            archive.writestr(extra_name, extra_content)

    def test_refuses_path_traversal(self):
        self.make_zip("scriptfiles/../../outside.ini")
        with self.assertRaisesRegex(ValueError, "Unsafe"):
            restore(self.zip, self.stage)
        self.assertFalse(self.stage.exists())

    def test_refuses_unexpected_file(self):
        self.make_zip("plugins/FileFunctions.dll")
        with self.assertRaisesRegex(ValueError, "Unexpected"):
            restore(self.zip, self.stage)

    def test_refuses_windows_device_name(self):
        self.make_zip("scriptfiles/players/NUL.ini")
        with self.assertRaisesRegex(ValueError, "Unsafe"):
            restore(self.zip, self.stage)

    def test_refuses_duplicate_case_insensitive_path(self):
        self.make_zip("scriptfiles/players/player.INI")
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            restore(self.zip, self.stage)

    def test_refuses_symlink_entry(self):
        link = zipfile.ZipInfo("scriptfiles/players/link.ini")
        link.create_system = 3
        link.external_attr = (stat.S_IFLNK | 0o777) << 16
        with zipfile.ZipFile(self.zip, "w") as archive:
            archive.writestr("server.cfg", "cfg")
            archive.writestr("scriptfiles/players/Player.ini", "data")
            archive.writestr(link, "../../private")
        with self.assertRaisesRegex(ValueError, "Non-regular"):
            restore(self.zip, self.stage)

    def test_refuses_oversized_member(self):
        # Inspect metadata without allocating a huge file.
        from tools.restore_backup import check_member, MAX_FILE_BYTES
        info = zipfile.ZipInfo("scriptfiles/players/big.ini")
        info.file_size = MAX_FILE_BYTES + 1
        with self.assertRaisesRegex(ValueError, "Oversized"):
            check_member(info)


if __name__ == "__main__":
    unittest.main()
