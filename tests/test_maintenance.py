"""Safety regressions for setup and public packaging. Stdlib only."""
import io
import tempfile
import unittest
import zipfile
from contextlib import redirect_stdout
from pathlib import Path

from tools.drazvio import PLACEHOLDER, init
from tools.verify_package import verify


class ServerInitTests(unittest.TestCase):
    def test_init_repeat_preserves_config_and_saved_data(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            data = root / "scriptfiles" / "data"
            data.mkdir(parents=True)
            (root / "server.cfg.example").write_text(
                "gamemode0 mod05 1\nrcon_password " + PLACEHOLDER + "\n",
                encoding="utf-8",
            )
            (data / "cash.ini.example").write_bytes(b"I00=0\r\n")
            with redirect_stdout(io.StringIO()):
                init(root)
            cfg = (root / "server.cfg").read_text(encoding="utf-8")
            self.assertNotIn(PLACEHOLDER, cfg)
            self.assertGreaterEqual(len(cfg.split("rcon_password ", 1)[1].strip()), 20)
            (data / "cash.ini").write_bytes(b"I00=9988\r\n")
            (data / "keyscan.ini.example").write_bytes(b"SLMon=0\r\n")
            with redirect_stdout(io.StringIO()):
                init(root)
            self.assertEqual((root / "server.cfg").read_text(encoding="utf-8"), cfg)
            self.assertEqual((data / "cash.ini").read_bytes(), b"I00=9988\r\n")
            self.assertEqual((data / "keyscan.ini").read_bytes(), b"SLMon=0\r\n")

    def test_existing_config_without_template_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "server.cfg").write_text("keep this private\n", encoding="utf-8")
            (root / "scriptfiles" / "data").mkdir(parents=True)
            with redirect_stdout(io.StringIO()):
                init(root)
            self.assertEqual((root / "server.cfg").read_text(encoding="utf-8"),
                             "keep this private\n")


class PackageSafetyTests(unittest.TestCase):
    def test_missing_files_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "test.zip"
            with zipfile.ZipFile(out, "w") as z:
                z.writestr("server.cfg.example", "rcon_password PLACEHOLDER\n")
            with self.assertRaisesRegex(ValueError, "Missing files"):
                verify(out)

    def test_unexpected_private_file_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "test.zip"
            from tools.verify_package import EXPECTED
            with zipfile.ZipFile(out, "w") as z:
                for name in EXPECTED:
                    z.writestr(name, b"test")
                z.writestr("scriptfiles/players/Private.ini", "Key=secret")
            with self.assertRaisesRegex(ValueError, "unexpected files"):
                verify(out)


if __name__ == "__main__":
    unittest.main()
