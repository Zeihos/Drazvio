"""Binary-only Pawn source inventory regression tests."""
import unittest
from tools.pawn_source_inventory import TOKENS, inventory


class PawnInventoryTests(unittest.TestCase):
    def test_preserves_legacy_non_utf8_source(self):
        original = b"public OnPlayerConnect(playerid)\r\n{\r\n// \xca\xe0\xe1\xe8\xed\xe5\xf2\r\n}\r\n"
        snapshot = bytes(original)
        found = inventory(original)
        self.assertEqual(found["OnPlayerConnect"], [1])
        self.assertEqual(original, snapshot)

    def test_line_numbers_and_multiple_occurrences(self):
        source = b"fileMove(a,b)\nline\r\nfileMove(c,d)\n"
        self.assertEqual(inventory(source)["fileMove"], [1, 3])

    def test_all_token_names_are_safe_ascii(self):
        for token in TOKENS:
            self.assertEqual(token.decode("ascii").encode("ascii"), token)


if __name__ == "__main__":
    unittest.main()
