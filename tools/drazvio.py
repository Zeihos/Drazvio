#!/usr/bin/env python3
"""Preflight and local configuration for DRAZVIO. Python stdlib only."""
import argparse
import secrets
import sys
from pathlib import Path

SCRIPTS = (
    'BonusSys', 'elevator2', 'Garage', 'gatesys2', 'island',
    'keyscan', 'MPSys', 'myobj', 'reklama', 'gps', 'radio3',
)
PLUGINS = ('FileFunctions', 'sscanf', 'streamer')
PLACEHOLDER = 'REPLACE_WITH_UNIQUE_PRIVATE_RCON_PASSWORD'


def config_values(text):
    values = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith(('#', '//', ';')):
            continue
        key, _, value = line.partition(' ')
        values[key.lower()] = value.strip()
    return values


def audit(root: Path, deploy: bool) -> int:
    problems = []
    warnings = []
    required = [root / 'gamemodes/mod05.pwn', root / 'pawno/pawncc.exe',
                root / 'pawno/include/a_samp.inc']
    required += [root / 'filterscripts' / (name + '.pwn') for name in SCRIPTS]
    required += [root / 'plugins' / (name + '.dll') for name in ('sscanf','streamer')]
    required += [root / 'filterscripts' / (name + '.amx') for name in SCRIPTS if name not in ('gatesys2', 'reklama')]
    required += [root / 'samp-server.exe',root / 'samp-license.txt']
    for file in required:
        if not file.is_file() or file.stat().st_size == 0:
            problems.append(f'Missing or empty: {file.relative_to(root)}')
    cfg_path = root / ('server.cfg' if deploy else 'server.cfg.example')
    if not cfg_path.is_file():
        problems.append(f'Missing config: {cfg_path.name}')
    else:
        cfg = config_values(cfg_path.read_text(encoding='utf-8-sig', errors='replace'))
        if cfg.get('gamemode0', '').split()[:1] != ['mod05']:
            problems.append('gamemode0 must load mod05')
        if cfg.get('plugins', '').split() != list(PLUGINS):
            problems.append('Plugin list must match FileFunctions sscanf streamer')
        missing = [name for name in SCRIPTS if name not in cfg.get('filterscripts', '').split()]
        if missing:
            problems.append('Unlisted filterscripts: ' + ', '.join(missing))
        if cfg.get('rcon') != '0':
            warnings.append('RCON is not disabled (rcon 0 is recommended during testing)')
        password = cfg.get('rcon_password', '')
        if deploy and (not password or password == PLACEHOLDER or len(password) < 20):
            problems.append('RCON password is missing, templated, or too short')
        if cfg.get('announce') == '1' and not deploy:
            warnings.append('Template announces server publicly; use announce 0 before tests')
    ff = root / 'plugins/FileFunctions.dll'
    if deploy and not ff.is_file():
        problems.append('FileFunctions.dll missing; download the tested CI artifact first')
    if ff.is_file():
        binary = ff.read_bytes().upper()
        if b'MSVCR100D.DLL' in binary:
            msg = ('FileFunctions.dll imports MSVCR100D.dll (Visual C++ DEBUG runtime); '
                   'replace with a release-built, compatible DLL before deployment')
            (problems if deploy else warnings).append(msg)
    if not deploy and not ff.is_file():
        warnings.append('FileFunctions.dll is compiled by GitHub Actions; not tracked in source')
    for issue in warnings:
        print('WARNING:', issue)
    for issue in problems:
        print('ERROR:', issue)
    if not problems:
        print('PREFLIGHT OK' if not warnings else 'PREFLIGHT OK WITH WARNINGS')
    return 1 if problems else 0


def init(root: Path):
    target = root / 'server.cfg'
    template = root / 'server.cfg.example'
    if target.exists():
        print('Existing private server.cfg preserved.')
    else:
        raw = template.read_text(encoding='utf-8')
        if raw.count(PLACEHOLDER) != 1:
            raise RuntimeError('Template must contain one password placeholder')
        password = secrets.token_urlsafe(32)
        # Exclusive creation refuses overwrites even if a second process raced us.
        with target.open('x', encoding='utf-8', newline='\n') as output:
            output.write(raw.replace(PLACEHOLDER, password))
        print('Created private server.cfg (RCON password not displayed).')
    data_dir = root / 'scriptfiles' / 'data'
    made = 0
    for sample in sorted(data_dir.glob('*.ini.example')):
        destination = sample.with_suffix('')
        try:
            with destination.open('xb') as output:
                output.write(sample.read_bytes())
                made += 1
        except FileExistsError:
            continue
    print(f'Initialized {made} missing INI files; existing game data preserved.')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('action', choices=['check', 'init'])
    p.add_argument('--root', default='server')
    p.add_argument('--deploy', action='store_true', help='Validate real server.cfg and fail on debug CRT')
    args = p.parse_args()
    root = Path(args.root).resolve()
    try:
        if args.action == 'init':
            init(root)
            return 0
        return audit(root, args.deploy)
    except (OSError, RuntimeError) as exc:
        print('ERROR:', exc)
        return 1


if __name__ == '__main__':
    sys.exit(main())
