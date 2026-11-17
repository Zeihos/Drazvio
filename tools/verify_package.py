#!/usr/bin/env python3
"""DRAZVIO: check that a public test ZIP contains *only* allowed files."""
import argparse
import struct
import sys
import zipfile
from pathlib import Path, PurePosixPath

FILTERS = (
    "BonusSys", "elevator2", "Garage", "gatesys2", "island", "keyscan",
    "MPSys", "myobj", "reklama", "gps", "radio3",
)
CARS = (
    "2dvernie", "4dvernie", "bikes", "funcars", "furgons", "gonochnie",
    "goscars", "gruzcars", "jeeps", "lodki", "lowriders", "moshnie",
    "paid", "racecars", "radiocars", "transcars", "vozdcars",
)
DATA = ("cash", "cortime", "keyscan", "line", "openip", "servcon")

EXPECTED = frozenset(
    {"samp-server.exe", "samp-license.txt", "server.cfg.example",
     "gamemodes/mod05.amx", "plugins/FileFunctions.dll",
     "plugins/sscanf.dll", "plugins/streamer.dll"}
    | {f"filterscripts/{name}.amx" for name in FILTERS}
    | {f"scriptfiles/CarSpawn/{name}.txt" for name in CARS}
    | {f"scriptfiles/data/{name}.ini" for name in DATA}
)


def verify(path: Path) -> None:
    with zipfile.ZipFile(path) as archive:
        members = [x for x in archive.infolist() if not x.is_dir()]
        names = [x.filename.replace("\\", "/") for x in members]
        if len(names) != len(set(names)):
            raise ValueError("Archive contains duplicate filenames")
        for name in names:
            pure = PurePosixPath(name)
            if name.startswith("/") or ".." in pure.parts or "." in pure.parts:
                raise ValueError(f"Unsafe entry path: {name}")
        missing = EXPECTED - set(names)
        unexpected = set(names) - EXPECTED
        if missing or unexpected:
            raise ValueError(
                f"Missing files: {sorted(missing)}; unexpected files: {sorted(unexpected)}"
            )
        if archive.testzip() is not None:
            raise ValueError("Broken ZIP member checksum")
        for info in members:
            if info.file_size == 0:
                raise ValueError(f"Empty required file: {info.filename}")

        config = archive.read("server.cfg.example").decode("utf-8-sig")
        if "REPLACE_WITH_UNIQUE_PRIVATE_RCON_PASSWORD" not in config:
            raise ValueError("Public config example lost its RCON placeholder")

        plugin = archive.read("plugins/FileFunctions.dll")
        if plugin[:2] != b"MZ" or len(plugin) < 0x100:
            raise ValueError("FileFunctions is not a Windows DLL")
        pe_offset = struct.unpack_from("<I", plugin, 0x3C)[0]
        if plugin[pe_offset : pe_offset + 4] != b"PE\x00\x00":
            raise ValueError("Broken FileFunctions PE header")
        machine = struct.unpack_from("<H", plugin, pe_offset + 4)[0]
        if machine != 0x14C:
            raise ValueError("FileFunctions must be 32-bit (x86)")
        for name in (b"MSVCR100D.DLL", b"VCRUNTIME140D.DLL", b"UCRTBASED.DLL"):
            if name in plugin.upper():
                raise ValueError("Debug runtime dependency detected in FileFunctions")
    print(f"PASS: {len(EXPECTED)} exact entries, no player files, correct x86 DLL and valid ZIP")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    try:
        verify(args.archive)
    except (ValueError, OSError, zipfile.BadZipFile) as exc:
        print("ERROR:", exc)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
