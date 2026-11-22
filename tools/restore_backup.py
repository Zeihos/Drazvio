#!/usr/bin/env python3
"""Restore a private DRAZVIO backup ONLY into a new, empty staging directory.

Never writes into a live server. Stop SA-MP before copying inspected files.
"""
import argparse
import re
import shutil
import stat
import zipfile
from pathlib import Path, PurePosixPath

MAX_FILE_BYTES = 256 * 1024 * 1024
MAX_TOTAL_BYTES = 2 * 1024 * 1024 * 1024
MAX_ENTRIES = 50000
WINDOWS_RESERVED = re.compile(r"^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?$", re.I)


def check_member(info):
    name = info.filename
    if not name or name.endswith("/") or "\\" in name or name.startswith("/"):
        raise ValueError(f"Unsafe archive entry: {name!r}")
    parts = PurePosixPath(name).parts
    if not parts or any(
        part in ("", ".", "..") or part.endswith((" ", ".")) or
        ":" in part or any(ord(ch) < 32 for ch in part) or
        WINDOWS_RESERVED.match(part) for part in parts
    ):
        raise ValueError(f"Unsafe archive path: {name!r}")
    if name != "server.cfg" and not (len(parts) >= 2 and parts[0] == "scriptfiles"):
        raise ValueError(f"Unexpected backup entry: {name!r}")
    mode = (info.external_attr >> 16) & 0xFFFF
    if stat.S_IFMT(mode) not in (0, stat.S_IFREG):
        raise ValueError(f"Non-regular archive entry: {name!r}")
    if info.flag_bits & 1:
        raise ValueError(f"Encrypted archive entry: {name!r}")
    if info.file_size > MAX_FILE_BYTES:
        raise ValueError(f"Oversized backup entry: {name!r}")


def restore(archive_path: Path, destination: Path) -> int:
    archive_path = archive_path.absolute()
    destination = destination.absolute()
    if not archive_path.is_file() or archive_path.is_symlink():
        raise ValueError("Backup ZIP must be a real file")
    if destination.exists() or destination.is_symlink():
        raise FileExistsError("Destination already exists; refusing to overwrite")
    if not destination.parent.is_dir() or destination.parent.is_symlink():
        raise ValueError("Destination parent must be a real directory")
    with zipfile.ZipFile(archive_path) as archive:
        members = archive.infolist()
        if not members or len(members) > MAX_ENTRIES:
            raise ValueError("Invalid backup entry count")
        names = set()
        total = 0
        for info in members:
            check_member(info)
            normalized = info.filename.casefold()
            if normalized in names:
                raise ValueError(f"Duplicate backup path: {info.filename}")
            names.add(normalized)
            total += info.file_size
            if total > MAX_TOTAL_BYTES:
                raise ValueError("Backup exceeds maximum total uncompressed size")
        if "server.cfg" not in names or not any(n.startswith("scriptfiles/") for n in names):
            raise ValueError("Backup must include server.cfg and scriptfiles data")
        if archive.testzip() is not None:
            raise ValueError("Backup failed CRC validation")
        # Exclusive directory creation; no existing or live server is overwritten.
        destination.mkdir()
        try:
            for info in members:
                target = destination.joinpath(*PurePosixPath(info.filename).parts)
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(info, "r") as source, target.open("xb") as output:
                    remaining = info.file_size
                    while remaining:
                        chunk = source.read(min(1024 * 1024, remaining))
                        if not chunk:
                            raise ValueError("Truncated backup entry")
                        output.write(chunk)
                        remaining -= len(chunk)
                    if source.read(1):
                        raise ValueError("Unexpected extra entry data")
        except BaseException:
            shutil.rmtree(destination)
            raise
    print(f"RESTORE OK: {len(members)} files extracted into NEW directory: {destination}")
    print("Inspect the restored files before any manual deployment to a stopped server.")
    return len(members)


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract private backup into a NEW staging directory")
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--destination", type=Path, required=True)
    args = parser.parse_args()
    try:
        restore(args.archive, args.destination)
        return 0
    except (OSError, ValueError, zipfile.BadZipFile, RuntimeError) as exc:
        print("ERROR:", exc)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
