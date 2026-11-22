#!/usr/bin/env python3
"""Read-only audit of incomplete DRAZVIO account-save transactions.

Run with SA-MP stopped. Never repair or delete transaction files automatically.
"""
import argparse
import os
import sys
from pathlib import Path

STAGING_SUFFIXES = (".savenew", ".swapold", ".regnew")


def scan(root: Path):
    root = root.absolute()
    data = root / "scriptfiles"
    if not root.is_dir() or root.is_symlink():
        raise ValueError("Server directory is missing or is a symlink")
    if not data.is_dir() or data.is_symlink():
        raise ValueError("scriptfiles directory is missing or is a symlink")
    found = []
    unsafe = []
    for current, dirs, files in os.walk(data, followlinks=False):
        parent = Path(current)
        for folder in list(dirs):
            if (parent / folder).is_symlink():
                unsafe.append((parent / folder).relative_to(root).as_posix())
                dirs.remove(folder)
        for file in files:
            path = parent / file
            if path.is_symlink():
                unsafe.append(path.relative_to(root).as_posix())
            elif file.lower().endswith(STAGING_SUFFIXES):
                found.append(path.relative_to(root).as_posix())
    return sorted(found, key=str.casefold), sorted(unsafe, key=str.casefold)


def audit(root: Path) -> int:
    pending, unsafe = scan(root)
    if unsafe:
        print(f"ERROR: {len(unsafe)} symlink(s) found under scriptfiles; manual inspection required.")
    if pending:
        print(f"WARNING: {len(pending)} incomplete save transaction file(s) found:")
        for name in pending:
            print("  " + name)
        print("Do NOT delete/rename these files automatically. Make an offline backup first.")
        print("Review .ini, .savenew and .swapold timestamps and contents with SA-MP stopped.")
    if not pending and not unsafe:
        print("ACCOUNT SAVE AUDIT OK: no pending transaction files or symlinks found.")
    return 1 if pending or unsafe else 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Read-only audit of account save leftovers")
    parser.add_argument("--root", type=Path, required=True, help="Stopped SA-MP server directory")
    args = parser.parse_args()
    try:
        return audit(args.root)
    except (ValueError, OSError) as exc:
        print("ERROR:", exc)
        return 2


if __name__ == "__main__":
    sys.exit(main())
