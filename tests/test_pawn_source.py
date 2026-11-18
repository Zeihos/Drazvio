"""Regression guards for the legacy Pawn game-mode. Uses binary I/O."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "server" / "gamemodes" / "mod05.pwn"


class PawnSourceRegressions(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.src = GAME.read_bytes()

    def test_busroute_timer_returns_value(self):
        anchor = b"public busroutestoptimer(playerid)\n{"
        self.assertEqual(self.src.count(anchor), 1)
        after = self.src.split(anchor, 1)[1].split(b"\n//====", 1)[0]
        self.assertTrue(
            after.rstrip().endswith(b"\treturn 1;\n}"),
            "busroutestoptimer must return a value on all paths (Pawn warning 209)",
        )
        self.assertIn(b"if(IsPlayerConnected(playerid))", after)

    def test_timer_still_uses_connection_epoch(self):
        self.assertIn(b'public DZ_Guard_busroutestoptimer(playerid, dz_epoch0)', self.src)
        self.assertIn(b'DZ_EpochAt(playerid)', self.src)

    def test_save_keeps_snapshot_and_rollback_barriers(self):
        self.assertIn(b'DZ_AccountSnapshotValid(dz_stage, playerid)', self.src)
        self.assertIn(b'fileMove(string3, dz_swapold)', self.src)
        self.assertIn(b'fileMove(dz_stage, string3)', self.src)
        self.assertIn(b'fileMove(dz_swapold, string3)', self.src)


if __name__ == "__main__":
    unittest.main()
