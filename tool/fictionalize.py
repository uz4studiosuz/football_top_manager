"""Replaces real names in assets/data with invented ones (for store builds).

Players get names from the name pools of their nationality, clubs become
"<city> <suffix>", stadiums "<city> Arena", leagues "First/Second
Division"; look-alike portrait hints are dropped and every attribute is
nudged by up to ±2 so ratings are not a copy of any source. Ids, squads,
colours and the game balance stay the same, and the result is the same on
every run (names come from a hash of the id).

It rewrites files in place, so it refuses to run without --in-place; use
tool/build_play.py, which backs the data up and restores it afterwards.

    python -I tool/fictionalize.py --in-place
"""
import hashlib
import json
import sys
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / 'assets' / 'data'
SUFFIXES = ['FK', 'Atletik', 'Sporting', 'Olimpik', 'Yulduz', 'Shunqor', 'Lochin', 'Bars', 'Burgut', 'Arslon']
DIVISIONS = {1: 'Birinchi divizion', 2: 'Ikkinchi divizion', 3: 'Uchinchi divizion'}
STAT_KEYS = ['attackingAwareness', 'ballControl', 'dribbling', 'tightPossession', 'lowPass', 'loftedPass',
             'finishing', 'heading', 'setPieceTaking', 'curl', 'defensiveAwareness', 'defensiveEngagement',
             'tackling', 'aggression', 'gkAwareness', 'gkCatching', 'gkParrying', 'gkReflexes', 'gkReach',
             'speed', 'acceleration', 'kickingPower', 'jumping', 'physicalContact', 'balance', 'stamina']


def h(text, salt=''):
    return int(hashlib.sha1(f'{salt}|{text}'.encode('utf8')).hexdigest(), 16)


class Names:
    def __init__(self):
        pools = json.loads((DATA / 'names.json').read_text(encoding='utf8'))['pools']
        self.by_nat = {p['nationality']: p for p in pools}
        self.all = pools

    def person(self, key, nationality):
        pool = self.by_nat.get(nationality) or self.all[h(key, 'pool') % len(self.all)]
        first = pool['firstNames'][h(key, 'f') % len(pool['firstNames'])]
        last = pool['lastNames'][h(key, 'l') % len(pool['lastNames'])]
        return f'{first} {last}', f'{first[0]}. {last}'


def nudge(value, key):
    return max(40, min(99, value + (h(key, 'n') % 5) - 2))


def player(p, names):
    p['name'], p['shortName'] = names.person(p['id'], p.get('nationality', ''))
    p.pop('face', None)
    stats = p.get('stats')
    if isinstance(stats, list):
        p['stats'] = [nudge(v, f"{p['id']}{i}") for i, v in enumerate(stats)]
    elif isinstance(stats, dict):
        p['stats'] = {k: nudge(v, f"{p['id']}{k}") for k, v in stats.items()}
    if 'potential' in p:
        p['potential'] = nudge(p['potential'], p['id'] + 'pot')


def club(c, names, country, used):
    city = (c.get('city') or '').strip()
    base = city or names.person(c['id'], country)[0].split()[-1]
    start = h(c['id'], 'suffix') % len(SUFFIXES)
    for i in range(len(SUFFIXES)):
        name = f'{base} {SUFFIXES[(start + i) % len(SUFFIXES)]}'
        if name not in used:
            break
    else:
        name = f"{base} {c['id'][-3:]}"
    used.add(name)
    c['name'] = name
    c['shortName'] = ''.join(ch for ch in base.upper() if ch.isalpha())[:3] or 'FTM'
    c['stadiumName'] = f'{base} Arena'
    c['nickname'] = ''
    c['managerName'] = names.person(c['id'] + 'coach', country)[0]
    crest = c.get('crest')
    if isinstance(crest, dict):
        crest['monogram'] = ''.join(w[0] for w in name.split())[:3].upper()


def main():
    if '--in-place' not in sys.argv:
        sys.exit('Rewrites assets/data in place: pass --in-place (or use tool/build_play.py).')
    names = Names()
    manifest = json.loads((DATA / 'league.json').read_text(encoding='utf8'))
    used = set()
    renamed = {}
    files = {}
    for league in manifest['leagues']:
        country = league.get('country', '')
        for key in ('clubsFile', 'playersFile'):
            path = DATA / league[key]
            if path not in files:
                files[path] = json.loads(path.read_text(encoding='utf8'))
        for c in files[DATA / league['clubsFile']].get('clubs', []):
            club(c, names, country, used)
            renamed[c['id']] = c['name']
        for p in files[DATA / league['playersFile']].get('players', []):
            player(p, names)
        if league['id'] != 'super':
            group = league['name'][-2:] if league['name'][-2:-1] == ' ' and league['name'][-1].isupper() else ''
            league['name'] = DIVISIONS.get(league.get('tier', 1), f"{league.get('tier', 1)}-divizion") + group
    for path, doc in files.items():
        compact = path.parent.name == 'world' or path.name.startswith('players')
        path.write_text(json.dumps(doc, ensure_ascii=False, separators=(',', ':') if compact else None,
                                   indent=None if compact else 1) + '\n', encoding='utf8')
    (DATA / 'league.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + '\n', encoding='utf8')
    index = DATA / 'world' / 'index.json'
    if index.exists():
        rows = json.loads(index.read_text(encoding='utf8'))
        for r in rows:
            r[1] = renamed.get(r[0], r[1])
        index.write_text(json.dumps(rows, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf8')
    print('clubs renamed', len(renamed), 'files', len(files))


if __name__ == '__main__':
    main()
