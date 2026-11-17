#!/usr/bin/env python3
"""Fail CI if archives or runtime secrets enter the Git index."""
from pathlib import PurePosixPath
import subprocess
import sys

def main():
    tracked = subprocess.check_output(["git", "ls-files", "-z"]).decode("utf-8").split("\0")
    problems = []
    for name in filter(None, tracked):
        path = PurePosixPath(name)
        if name.startswith(("Мод/", "Оформление/")):
            problems.append("Old directory: "+name)
        if name.startswith((
            "server/scriptfiles/players/", "server/scriptfiles/accounts/",
            "server/scriptfiles/banlist/", "server/scriptfiles/bantime/",
            "server/scriptfiles/gangs/", "server/scriptfiles/businesses/",
            "server/scriptfiles/houses/"
        )):
            problems.append("Runtime/player data: "+name)
        if name in ("server/server.cfg", "server/plugins/FileFunctions.dll"):
            problems.append("Private/debug file: "+name)
        if name.startswith("server/scriptfiles/data/") and path.suffix.lower() == ".ini":
            problems.append("Runtime INI file: "+name)
        if path.suffix.lower() in (".zip",".rar",".7z",".bak",".savenew",".regnew",".swapold"):
            problems.append("Archive or temporary file: "+name)
        if name in (
            "server/gamemodes/mod05.amx",
            "server/filterscripts/gatesys2.amx",
            "server/filterscripts/reklama.amx",
        ):
            problems.append("Generated AMX: "+name)
    if problems:
        for p in problems: print("ERROR:",p)
        return 1
    print("Repository hygiene check: OK")
    return 0

if __name__ == "__main__":
    sys.exit(main())
