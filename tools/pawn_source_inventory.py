#!/usr/bin/env python3
"""Encoding-safe static inventory of key DRAZVIO Pawn entry points.

Reads mod05.pwn as bytes: never decodes or writes the legacy source.
Only prints a fixed allowlist of identifiers and line numbers (no source text
or player data is disclosed in public CI logs).
"""
import argparse
from pathlib import Path

TOKENS = (
    b"OnPlayerConnect", b"OnPlayerDisconnect", b"OnDialogResponse",
    b"OnPlayerDeath", b"OnPlayerSpawn", b"OnPlayerCommandText",
    b"DZ_AccountSnapshotValid", b"DZ_EpochAt", b"fileMove",
    b"fileOpen", b"fileClose", b"fileRead", b"fileWrite",
    b"busroutestoptimer",
)
SOURCE = Path(__file__).resolve().parents[1] / "server/gamemodes/mod05.pwn"


def inventory(data: bytes):
    # CRLF and LF have the same logical line boundaries.
    result = {}
    lines = data.splitlines()
    for token in TOKENS:
        line_numbers = [
            line_number for line_number, line in enumerate(lines, 1)
            if token in line
        ]
        result[token.decode("ascii")] = line_numbers
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=SOURCE)
    args = parser.parse_args()
    data = args.source.read_bytes()
    matches = inventory(data)
    print(f"Pawn source bytes: {len(data)}")
    for name, lines in matches.items():
        preview = ", ".join(map(str, lines[:15]))
        extra = f" ... (+{len(lines)-15})" if len(lines) > 15 else ""
        print(f"{name}: {len(lines)} occurrence(s); lines [{preview}]{extra}")
    # These anchors are mandatory for supported account-save and timer paths.
    essential = ("OnPlayerConnect", "OnPlayerDisconnect", "OnDialogResponse",
                 "DZ_AccountSnapshotValid", "DZ_EpochAt")
    missing = [name for name in essential if not matches[name]]
    if missing:
        print("ERROR: missing essential Pawn source identifier(s): " + ", ".join(missing))
        return 1
    print("SOURCE INVENTORY OK (static identifiers only; not runtime verification)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
