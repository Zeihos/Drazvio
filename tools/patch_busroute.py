#!/usr/bin/env python3
"""Apply one byte-preserving Pawn fix; reject unknown gamemode revisions."""
from hashlib import sha1
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
TARGET = ROOT / "server" / "gamemodes" / "mod05.pwn"
OLD_SHA = "ced4ead1f0cfb7e7d7422b76fb605a51e6c20524"
NEW_SHA = "d9cf5eab95be2986301c1d87aba520f9f66d102c"

OLD = (
    b"public busroutestoptimer(playerid)\n"
    b"{\n"
    b"\tif(IsPlayerConnected(playerid))\n"
    b"\t{\n"
    b"\t    if(GetVehicleModel(GetPlayerVehicleID(playerid)) == 407)\n"
    b"\t    {\n"
    b"\t        TogglePlayerControllable(playerid, 1);\n"
    b"\t    }\n"
    b"\t}\n"
    b"}"
)
NEW = OLD[:-1] + b"\treturn 1;\n}"


def git_blob_sha(data: bytes) -> str:
    return sha1(f"blob {len(data)}\0".encode("ascii") + data).hexdigest()


def patch_bytes(original: bytes) -> bytes:
    digest = git_blob_sha(original)
    if digest == NEW_SHA:
        return original
    if digest != OLD_SHA:
        raise ValueError(f"Unexpected mod05.pwn Git blob {digest}; not patching")
    if original.count(OLD) != 1:
        raise ValueError("Expected busroutestoptimer definition not found exactly once")
    result = original.replace(OLD, NEW, 1)
    if git_blob_sha(result) != NEW_SHA:
        raise ValueError("Patched content hash mismatch; refusing modified source")
    return result


def main() -> int:
    try:
        original = TARGET.read_bytes()
        updated = patch_bytes(original)
        if updated != original:
            TARGET.write_bytes(updated)
            print("Patched busroutestoptimer: added return 1; preserved all other bytes.")
        else:
            print("Pawn source already has the verified fix.")
        print("Git blob:", git_blob_sha(updated))
        return 0
    except (OSError, ValueError) as exc:
        print("ERROR:", exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
