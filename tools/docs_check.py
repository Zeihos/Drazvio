#!/usr/bin/env python3
"""Проверка локальных ссылок Markdown в публичной документации DRAZVIO."""
import re
import sys
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
MARKDOWN = [ROOT / name for name in ("README.md", "CONTRIBUTING.md", "SECURITY.md")]
MARKDOWN += sorted((ROOT / "docs").glob("*.md"))
MARKDOWN += sorted((ROOT / ".github" / "ISSUE_TEMPLATE").glob("*.md"))
MARKDOWN += [ROOT / ".github" / "PULL_REQUEST_TEMPLATE.md"]
LINKS = re.compile(r"(?<!!)\[[^\]]+\]\(([^)]+)\)")
HTML_LINKS = re.compile(r"""(?:href|src)=["\']([^"\']+)["\']""")

def main():
    problems = []
    for md in MARKDOWN:
        if not md.is_file():
            problems.append(f"Отсутствует документ: {md.relative_to(ROOT)}")
            continue
        text = md.read_text(encoding="utf-8")
        refs = LINKS.findall(text) + HTML_LINKS.findall(text)
        for item in refs:
            link = unquote(item.split("#", 1)[0].strip())
            if not link or link.startswith(("https://", "http://", "mailto:", "data:")):
                continue
            full = (md.parent / link).resolve()
            if not full.is_relative_to(ROOT) or not full.exists():
                problems.append(f"{md.relative_to(ROOT)}: недоступная ссылка {item}")
    for issue in problems:
        print("ОШИБКА:", issue)
    if not problems:
        print(f"OK: проверено {len(MARKDOWN)} Markdown-файлов")
    return int(bool(problems))

if __name__ == "__main__":
    sys.exit(main())
