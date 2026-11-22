"""End-to-end regression coverage for safe handling of interrupted account saves.

Uses artificial player data only; never starts or modifies a real SA-MP server.
"""
import io
import tempfile
import unittest
import zipfile
from contextlib import redirect_stdout
from pathlib import Path

from tools.audit_account_saves import audit, scan
from tools.backup_server import backup
from tools.restore_backup import restore


class AccountRecoveryIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tempdir.cleanup)
        base = Path(self.tempdir.name)
        self.server = base / "server"
        self.players = self.server / "scriptfiles" / "players"
        self.players.mkdir(parents=True)
        self.config_bytes = b"gamemode0 mod05 1\r\nrcon_password PRIVATE-TEST-ONLY\r\n"
        (self.server / "server.cfg").write_bytes(self.config_bytes)
        self.archive = base / "backup.zip"
        self.restored = base / "verified-restore"

    def quiet(self, callback, *args):
        with redirect_stdout(io.StringIO()):
            return callback(*args)

    def test_interrupted_save_roundtrip_preserves_all_transaction_versions(self):
        original = b"Money=500\r\nRank=2\r\n"
        staged = b"Money=750\r\nRank=2\r\n"
        (self.players / "Test.ini").write_bytes(original)
        (self.players / "Test.ini.savenew").write_bytes(staged)
        (self.players / "Test.ini.swapold").write_bytes(original)
        pending_before, unsafe_before = scan(self.server)
        self.assertEqual(len(pending_before), 2)
        self.assertEqual(unsafe_before, [])
        self.assertEqual(self.quiet(audit, self.server), 1)

        self.assertEqual(self.quiet(backup, self.server, self.archive), 4)
        self.assertEqual(self.quiet(restore, self.archive, self.restored), 4)
        self.assertEqual(
            (self.restored / "server.cfg").read_bytes(),
            self.config_bytes,
        )
        for name, expected in (
            ("Test.ini", original),
            ("Test.ini.savenew", staged),
            ("Test.ini.swapold", original),
        ):
            self.assertEqual((self.restored / "scriptfiles/players" / name).read_bytes(), expected)
            self.assertEqual((self.players / name).read_bytes(), expected)

        self.assertEqual(scan(self.restored), (pending_before, []))
        self.assertEqual(self.quiet(audit, self.restored), 1)
        # No tool silently "repairs" an interrupted transaction or changes balances.
        self.assertEqual((self.players / "Test.ini").read_bytes(), original)

    def test_corrupted_archive_is_rejected_without_touching_player_data(self):
        player = self.players / "Test.ini"
        player.write_bytes(b"Money=100\r\n")
        self.quiet(backup, self.server, self.archive)
        raw = bytearray(self.archive.read_bytes())
        # Deterministically damage the stored CRC32 in the central directory.
        # ZIP data stays parseable, but testzip() must fail integrity validation.
        central = raw.find(b"PK\\x01\\x02")
        self.assertGreaterEqual(central, 0)
        raw[central + 16] ^= 0x01
        self.archive.write_bytes(raw)
        with self.assertRaises((ValueError, zipfile.BadZipFile, RuntimeError, EOFError, OSError)):
            self.quiet(restore, self.archive, self.restored)
        self.assertFalse(self.restored.exists())
        self.assertEqual(player.read_bytes(), b"Money=100\r\n")

    def test_recovery_does_not_publish_a_restore_over_existing_folder(self):
        player = self.players / "Test.ini"
        player.write_bytes(b"Money=900\r\n")
        self.quiet(backup, self.server, self.archive)
        self.restored.mkdir()
        protected = self.restored / "do-not-overwrite.txt"
        protected.write_bytes(b"protected")
        with self.assertRaises(FileExistsError):
            self.quiet(restore, self.archive, self.restored)
        self.assertEqual(protected.read_bytes(), b"protected")
        self.assertEqual(player.read_bytes(), b"Money=900\r\n")


if __name__ == "__main__":
    unittest.main()
