"""Validate every executable in the downloadable DRAZVIO server archive."""
import struct
import unittest

from tools.verify_package import PE_BINARIES, validate_x86_pe


def synthetic_pe(*, machine=0x14C, magic=0x10B, tail=b""):
    data = bytearray(512)
    data[:2] = b"MZ"
    struct.pack_into("<I", data, 0x3C, 0x80)
    data[0x80:0x84] = bytes([80, 69, 0, 0])
    struct.pack_into("<H", data, 0x84, machine)
    struct.pack_into("<H", data, 0x98, magic)
    return bytes(data) + tail


class PortableExecutableTests(unittest.TestCase):
    def test_all_four_required_binaries_are_checked(self):
        self.assertEqual(
            set(PE_BINARIES),
            {"samp-server.exe", "plugins/FileFunctions.dll",
             "plugins/sscanf.dll", "plugins/streamer.dll"},
        )

    def test_accepts_valid_pe32_x86(self):
        for name in PE_BINARIES:
            with self.subTest(name=name):
                validate_x86_pe(synthetic_pe(), name)

    def test_rejects_x64_machine(self):
        with self.assertRaisesRegex(ValueError, "x86"):
            validate_x86_pe(synthetic_pe(machine=0x8664, magic=0x20B), "streamer.dll")

    def test_rejects_pe32_plus_magic(self):
        with self.assertRaisesRegex(ValueError, "x86"):
            validate_x86_pe(synthetic_pe(magic=0x20B), "sscanf.dll")

    def test_rejects_truncated_header(self):
        data = bytearray(synthetic_pe())
        struct.pack_into("<I", data, 0x3C, 0xFFFFF)
        with self.assertRaisesRegex(ValueError, "truncated"):
            validate_x86_pe(bytes(data), "FileFunctions.dll")

    def test_rejects_missing_signature(self):
        data = bytearray(synthetic_pe())
        data[0x80:0x84] = b"FAIL"
        with self.assertRaisesRegex(ValueError, "signature"):
            validate_x86_pe(bytes(data), "samp-server.exe")

    def test_rejects_debug_runtime_for_each_binary(self):
        for name in PE_BINARIES:
            with self.subTest(name=name):
                with self.assertRaisesRegex(ValueError, "debug CRT"):
                    validate_x86_pe(synthetic_pe(tail=b"msvcr100d.dll"), name)


if __name__ == "__main__":
    unittest.main()
