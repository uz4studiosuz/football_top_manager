"""Name pools for generated players (youth, regens, free agents, custom
squads) from every real player in 2026.db, grouped by nationality.

Hand-written pools in names.json are kept and merged, so the Uzbek pool
keeps its spellings.

    python -I tool/names_data.py [path/to/2026.db]
"""
import json
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from efl_data import BAD  # noqa: E402
from world_data import country, flag_of  # noqa: E402

DATA = Path(__file__).resolve().parent.parent / 'assets' / 'data'
MIN_PLAYERS = 25   # smaller nations borrow names from bigger pools
CAP = 450          # names per list


def ok(word):
    return len(word) >= 2 and BAD not in word and word[0].isupper() and not any(ch.isdigit() for ch in word)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else str(Path.home() / 'Downloads' / 'Telegram Desktop' / '2026.db')
    db = sqlite3.connect(f'file:{path}?mode=ro', uri=True)
    db.text_factory = lambda b: b.decode('utf-8', 'replace')
    pools = {}
    for name, nombre, iso in db.execute(
            'select j.jug_nombre, n.nombre, n.iso2 from jug_jugadores j join paises n on n.paid=j.jug_paid'):
        nat = country(nombre, iso)
        parts = name.split()
        if nat is None or len(parts) < 2 or not ok(parts[0]) or not ok(parts[-1]):
            continue
        pool = pools.setdefault(nat, {'flag': flag_of(nat, iso), 'first': {}, 'last': {}, 'n': 0})
        pool['n'] += 1
        pool['first'][parts[0]] = pool['first'].get(parts[0], 0) + 1
        last = ' '.join(parts[1:])
        if len(parts) <= 3:
            pool['last'][last] = pool['last'].get(last, 0) + 1
    doc = json.loads((DATA / 'names.json').read_text(encoding='utf8'))
    old = {p['nationality']: p for p in doc['pools']}
    out = []
    for nat, pool in sorted(pools.items(), key=lambda kv: -kv[1]['n']):
        if pool['n'] < MIN_PLAYERS and nat not in old:
            continue
        first = [w for w, _ in sorted(pool['first'].items(), key=lambda kv: -kv[1])][:CAP]
        last = [w for w, _ in sorted(pool['last'].items(), key=lambda kv: -kv[1])][:CAP]
        if nat in old:
            first = list(dict.fromkeys(old[nat]['firstNames'] + first))
            last = list(dict.fromkeys(old[nat]['lastNames'] + last))
        if len(first) < 5 or len(last) < 5:
            continue
        out.append({'nationality': nat, 'flag': old.get(nat, {}).get('flag', pool['flag']),
                    'weight': pool['n'], 'firstNames': first, 'lastNames': last})
    for nat, p in old.items():
        if nat not in pools:
            out.append(p)
    doc['pools'] = out
    (DATA / 'names.json').write_text(json.dumps(doc, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf8')
    print('pools', len(out), 'first names', sum(len(p['firstNames']) for p in out),
          'last names', sum(len(p['lastNames']) for p in out))


if __name__ == '__main__':
    main()
