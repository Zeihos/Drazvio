"""Regression tests for the deployed AMX-only server preflight."""
import io
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

from tools.drazvio import PLACEHOLDER, PLUGINS, SCRIPTS, audit
from tests.test_package_pe_binaries import synthetic_pe


class DeployedServerAuditTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self._file("samp-server.exe", synthetic_pe())
        self._file("samp-license.txt")
        self._file("gamemodes/mod05.amx")
        for script in SCRIPTS:
            self._file(f"filterscripts/{script}.amx")
        for plugin in PLUGINS:
            self._file(f"plugins/{plugin}.dll", synthetic_pe())
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
        return status, output.getvalue().replace(chr(92), '/')

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
        self._file("plugins/FileFunctions.dll", synthetic_pe(tail=b"MSVCR100D.DLL"))
        result, log = self.check()
        self.assertEqual(result, 1)
        self.assertIn("MSVCR100D.DLL", log)

    def test_rejects_x64_server_executable(self):
        self._file("samp-server.exe", synthetic_pe(machine=0x8664, magic=0x20B))
        result, log = self.check()
        self.assertEqual(result, 1)
        self.assertIn("samp-server.exe", log)
        self.assertIn("x86", log)

    def test_rejects_invalid_streamer_dll(self):
        self._file("plugins/streamer.dll", b"not a PE file")
        result, log = self.check()
        self.assertEqual(result, 1)
        self.assertIn("plugins/streamer.dll", log)

    def test_rejects_debug_runtime_in_sscanf_dll(self):
        self._file("plugins/sscanf.dll", synthetic_pe(tail=b"MSVCP100D.DLL"))
        result, log = self.check()
        self.assertEqual(result, 1)
        self.assertIn("MSVCP100D.DLL", log)

    def test_duplicate_critical_option_is_error(self):
        config = self.root / "server.cfg"
        with config.open("a", encoding="utf-8") as output:
            output.write("rcon 1\n")
        result, log = self.check()
        self.assertEqual(result, 1)
        self.assertIn("Duplicate config key: rcon", log)

    def test_duplicate_critical_option_case_insensitive(self):
        config = self.root / "server.cfg"
        with config.open("a", encoding="utf-8") as output:
            output.write("PLUGINs FileFunctions\n")
        result, log = self.check()
        self.assertEqual(result, 1)
        self.assertIn("Duplicate config key: plugins", log)

    def test_tab_separated_config_options(self):
        config = self.root / "server.cfg"
        content = config.read_text(encoding="utf-8")
        config.write_text(content.replace("plugins ", "plugins\t")
                          .replace("gamemode0 ", "gamemode0\t"), encoding="utf-8")
        result, log = self.check()
        self.assertEqual(result, 0, log)

    def test_template_password_is_error(self):
        config = self.root / "server.cfg"
        config.write_text(config.read_text().replace("x" * 32, PLACEHOLDER))
        result, log = self.check()
        self.assertEqual(result, 1)
        self.assertIn("RCON password", log)


if __name__ == "__main__":
    unittest.main()
