"""Regression tests for the deployed AMX-only server preflight."""
import io
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

from tools.drazvio import PLACEHOLDER, PLUGINS, SCRIPTS, audit


class DeployedServerAuditTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self._file("samp-server.exe")
        self._file("samp-license.txt")
        self._file("gamemodes/mod05.amx")
        for script in SCRIPTS:
            self._file(f"filterscripts/{script}.amx")
        for plugin in PLUGINS:
            self._file(f"plugins/{plugin}.dll")
        self._file("server.cfg", (
            "gamemode0 mod05 1\n"
            "plugins " + " ".join(PLUGINS) + "\n"
            "filterscripts " + " ".join(SCRIPTS) + "\n"
            "rcon 0\n"
            "rcon_password " + "x" * 32 + "\n"
            "announce 0\n"
        ).encode("utf-8"))

    def _file(self, name, content=b"test"):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)

    def check(self):
        output = io.StringIO()
        with redirect_stdout(output):
            status = audit(self.root, deploy=True)
        return status, output.getvalue().replace('\\\\', '/')

    def test_deployed_server_needs_no_pawn_sources_or_compiler(self):
        result, log = self.check()
        self.assertEqual(result, 0, log)
        self.assertIn("PREFLIGHT OK", log)

    def test_missing_compiled_gamemode_is_error(self):
        (self.root / "gamemodes/mod05.amx").unlink()
        result, log = self.check()
        self.assertEqual(result, 1)
        self.assertIn("gamemodes/mod05.amx", log)

    def test_missing_compiled_filterscript_is_error(self):
        (self.root / "filterscripts/reklama.amx").unlink()
        result, log = self.check()
        self.assertEqual(result, 1)
        self.assertIn("filterscripts/reklama.amx", log)

    def test_missing_filefunctions_is_error(self):
        (self.root / "plugins/FileFunctions.dll").unlink()
        result, log = self.check()
        self.assertEqual(result, 1)
        self.assertIn("plugins/FileFunctions.dll", log)

    def test_debug_runtime_dependency_is_error(self):
        self._file("plugins/FileFunctions.dll", b"MZ....MSVCR100D.DLL")
        result, log = self.check()
        self.assertEqual(result, 1)
        self.assertIn("MSVCR100D.dll", log)

    def test_template_password_is_error(self):
        config = self.root / "server.cfg"
        config.write_text(config.read_text().replace("x" * 32, PLACEHOLDER))
        result, log = self.check()
        self.assertEqual(result, 1)
        self.assertIn("RCON password", log)


if __name__ == "__main__":
    unittest.main()
