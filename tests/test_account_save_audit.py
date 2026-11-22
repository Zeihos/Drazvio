"""Tests for read-only account transaction audit."""
import io
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from tools.audit_account_saves import audit, scan


class AccountSaveAuditTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "server"
        (self.root / "scriptfiles" / "players").mkdir(parents=True)
        self.player_dir = self.root / "scriptfiles" / "players"

    def run_audit(self):
        stream = io.StringIO()
        with redirect_stdout(stream):
            status = audit(self.root)
        return status, stream.getvalue()

    def test_normal_ini_does_not_warn(self):
        (self.player_dir / "Player.ini").write_bytes(b"Money=10")
        status, output = self.run_audit()
        self.assertEqual(status, 0, output)
        self.assertIn("AUDIT OK", output)

    def test_interrupted_save_detected_without_modifying_contents(self):
        file = self.player_dir / "Player.ini.savenew"
        file.write_bytes(b"Money=12345")
        status, output = self.run_audit()
        self.assertEqual(status, 1)
        self.assertIn("Player.ini.savenew", output)
        self.assertEqual(file.read_bytes(), b"Money=12345")

    def test_rollback_and_registration_staging_detected(self):
        (self.player_dir / "Player.ini.swapold").write_bytes(b"old")
        (self.player_dir / "New.ini.regnew").write_bytes(b"new")
        pending, unsafe = scan(self.root)
        self.assertEqual(len(pending), 2)
        self.assertEqual(unsafe, [])

    def test_nested_staging_case_insensitive(self):
        sub = self.root / "scriptfiles" / "other"
        sub.mkdir()
        (sub / "TEST.INI.SAVENEW").write_bytes(b"x")
        pending, _ = scan(self.root)
        self.assertEqual(pending, ["scriptfiles/other/TEST.INI.SAVENEW"])

    def test_symlink_not_followed_when_supported(self):
        outside = Path(self.tmp.name) / "outside"
        outside.mkdir()
        (outside / "stolen.ini.savenew").write_bytes(b"x")
        link = self.root / "scriptfiles" / "foreign"
        try:
            link.symlink_to(outside, target_is_directory=True)
        except (OSError, NotImplementedError):
            self.skipTest("Creating symlinks unavailable")
        pending, unsafe = scan(self.root)
        self.assertFalse(pending)
        self.assertEqual(unsafe, ["scriptfiles/foreign"])

    def test_missing_scriptfiles_is_error(self):
        with self.assertRaisesRegex(ValueError, "scriptfiles"):
            scan(Path(self.tmp.name))


if __name__ == "__main__":
    unittest.main()
