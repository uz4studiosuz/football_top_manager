"""Downloads the flag SVGs the game uses from lipis/flag-icons (MIT).

Every flag emoji found in assets/data and lib/data/countries.dart, plus the
UK nations, lands in assets/flags/<code>.svg with the licence beside it.

    python -I tool/fetch_flags.py
"""
import re
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'flags'
BASE = 'https://raw.githubusercontent.com/lipis/flag-icons/main'
PAIR = re.compile('[\U0001F1E6-\U0001F1FF]{2}')


def codes():
    found = {'gb-eng', 'gb-sct', 'gb-wls', 'gb-nir'}
    files = [ROOT / 'lib' / 'data' / 'countries.dart', *(ROOT / 'assets' / 'data').rglob('*.json')]
    for f in files:
        for pair in PAIR.findall(f.read_text(encoding='utf8')):
            found.add(''.join(chr(ord(ch) - 0x1F1E6 + 97) for ch in pair))
    return sorted(found)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    missing = []
    for code in codes():
        target = OUT / f'{code}.svg'
        if target.exists():
            continue
        try:
            with urllib.request.urlopen(f'{BASE}/flags/4x3/{code}.svg', timeout=20) as r:
                target.write_bytes(r.read())
        except Exception as e:  # noqa: BLE001
            missing.append(f'{code} ({e})')
    with urllib.request.urlopen(f'{BASE}/LICENSE', timeout=20) as r:
        (OUT / 'LICENSE').write_bytes(r.read())
    print('flags', len(list(OUT.glob('*.svg'))), 'missing', missing)


if __name__ == '__main__':
    main()
