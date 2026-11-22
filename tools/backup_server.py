#!/usr/bin/env python3
"""Offline backup of private DRAZVIO server data. Python standard library only.

Stop the SA-MP server first to obtain a consistent snapshot.
The resulting ZIP contains secrets and must NEVER be published to GitHub.
"""
import argparse
import os
import tempfile
import zipfile
from pathlib import Path


def backup(root: Path, output: Path) -> int:
    root = root.absolute()
    output = output.absolute()
    if not root.is_dir() or root.is_symlink():
        raise ValueError("Server root must be an existing, real directory")
    if not (root / "server.cfg").is_file() or (root / "server.cfg").is_symlink():
        raise ValueError("Missing or symlinked server.cfg")
    data = root / "scriptfiles"
    if not data.is_dir() or data.is_symlink():
        raise ValueError("Missing or symlinked scriptfiles directory")
    if output == root or root in output.parents:
        raise ValueError("Backup must be outside the server directory")
    if output.exists() or output.is_symlink():
        raise FileExistsError("Backup already exists; refusing to overwrite")
    if not output.parent.is_dir():
        raise ValueError("Backup destination directory does not exist")
    if output.parent.resolve() == root.resolve() or root.resolve() in output.parent.resolve().parents:
        raise ValueError("Backup destination resolves inside the server directory")
    files = [root / "server.cfg"]
    for current, dirs, names in os.walk(data, followlinks=False):
        base = Path(current)
        for name in dirs:
            if (base / name).is_symlink():
                raise ValueError(f"Symlinked directory: {(base / name).relative_to(root)}")
        for name in names:
            path = base / name
            if path.is_symlink() or not path.is_file():
                raise ValueError(f"Unsupported file: {path.relative_to(root)}")
            files.append(path)
    files.sort(key=lambda p: str(p.relative_to(root)).lower())
    # Create the archive in the destination directory, then atomically publish it
    # without replacing a backup if another process created the same filename.
    fd, temporary = tempfile.mkstemp(prefix=".drazvio-backup-", suffix=".tmp", dir=output.parent)
    os.close(fd)
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED, allowZip64=True) as archive:
            for path in files:
                archive.write(path, path.relative_to(root).as_posix())
        with zipfile.ZipFile(temporary) as archive:
            if archive.testzip() is not None:
                raise ValueError("Backup failed ZIP integrity check")
            if len(archive.namelist()) != len(files):
                raise ValueError("Backup entry count mismatch")
        os.link(temporary, output)  # fails if the destination already exists
    finally:
        Path(temporary).unlink(missing_ok=True)
    print(f"BACKUP OK: {len(files)} files -> {output}")
    print("PRIVATE BACKUP: contains server.cfg and player data; store offline, never commit or upload publicly.")
    return len(files)


def main() -> int:
    parser = argparse.ArgumentParser(description="Offline backup of server.cfg and scriptfiles")
    parser.add_argument("--root", type=Path, required=True, help="Path to stopped SA-MP server")
    parser.add_argument("--output", type=Path, required=True, help="ZIP path OUTSIDE server folder")
    args = parser.parse_args()
    try:
        backup(args.root, args.output)
        return 0
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        print("ERROR:", exc)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
