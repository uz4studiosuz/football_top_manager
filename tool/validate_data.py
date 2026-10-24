"""Checks assets/data the same way the game loads it (InitialDatabase._join).

    python -I tool/validate_data.py [path/to/assets/data]

Exit code 1 when there are errors (the game would refuse the data);
warnings are printed but do not fail.
"""
import json
import sys
from pathlib import Path

KEYS = ['attackingAwareness', 'ballControl', 'dribbling', 'tightPossession', 'lowPass', 'loftedPass', 'finishing',
        'heading', 'setPieceTaking', 'curl', 'defensiveAwareness', 'defensiveEngagement', 'tackling', 'aggression',
        'gkAwareness', 'gkCatching', 'gkParrying', 'gkReflexes', 'gkReach', 'speed', 'acceleration', 'kickingPower',
        'jumping', 'physicalContact', 'balance', 'stamina']
POSITIONS = {'GK', 'CB', 'LB', 'RB', 'DMF', 'CMF', 'AMF', 'LMF', 'RMF', 'LWF', 'RWF', 'SS', 'CF', 'ST'}
FORMATIONS = {'f433', 'f4231', 'f442', 'f352', 'f532', 'f4141', 'f343', 'f41212', 'f433d', 'f4222', 'f4411', 'f451',
              'f3412', 'f3421', 'f541', 'f4321'}
PLAYSTYLES = {'outWide', 'longBallCounter', 'possession', 'quickCounter', 'highPressing', 'longBall', 'overload'}


def main():
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / 'assets' / 'data'
    errors, warnings = [], []
    err = lambda where, msg: errors.append(f'{where}: {msg}')  # noqa: E731
    warn = lambda where, msg: warnings.append(f'{where}: {msg}')  # noqa: E731

    def read(name):
        path = root / name
        if not path.exists():
            err(name, 'file missing')
            return None
        return json.loads(path.read_text(encoding='utf8'))

    manifest = read('league.json')
    if manifest is None:
        return finish(errors, warnings)
    if manifest.get('schemaVersion') != 2:
        err('league.json', 'schemaVersion must be 2')
    for key in ('templatesFile', 'namesFile'):
        if not manifest.get(key) or read(manifest[key]) is None:
            err('league.json', f'{key} missing')
    club_ids, league_ids = set(), set()
    for lg in manifest.get('leagues', []):
        where = lg.get('name', lg.get('id'))
        if lg['id'] in league_ids:
            err(where, f"duplicate league id {lg['id']}")
        league_ids.add(lg['id'])
        clubs_doc, players_doc = read(lg['clubsFile']), read(lg['playersFile'])
        if clubs_doc is None or players_doc is None:
            continue
        players, owners = {}, set()
        for p in players_doc['players']:
            if p['id'] in players:
                err(where, f"duplicate player id {p['id']}")
            players[p['id']] = p
            if p.get('mainPosition') not in POSITIONS:
                err(p.get('name'), f"unknown position {p.get('mainPosition')}")
            for k in KEYS:
                v = p.get('stats', {}).get(k)
                if not isinstance(v, (int, float)):
                    err(p.get('name'), f'stats.{k} missing')
                elif not 40 <= v <= 100:
                    warn(p.get('name'), f'stats.{k}={v} outside 40-100')
        clubs = clubs_doc['clubs']
        if len(clubs) % 2:
            err(where, f'club count must be even ({len(clubs)})')
        for c in clubs:
            cw = f"{where} / {c.get('name')}"
            if c['id'] in club_ids:
                err(cw, f"duplicate club id {c['id']}")
            club_ids.add(c['id'])
            squad = set()
            for pid in c.get('squadIds', []):
                if pid not in players:
                    err(cw, f'unknown player {pid}')
                elif pid in owners:
                    err(cw, f'{pid} belongs to two clubs')
                owners.add(pid)
                squad.add(pid)
            xi, bench = c.get('startingLineupIds', []), c.get('benchIds', [])
            if len(xi) != 11 or len(set(xi)) != 11:
                err(cw, f'starting XI must be 11 different players ({len(xi)})')
            if not all(pid in squad for pid in xi + bench):
                err(cw, 'line-up uses a player outside the squad')
            if set(xi) & set(bench):
                err(cw, 'player both in XI and on the bench')
            if c.get('tactics', {}).get('formation') not in FORMATIONS:
                err(cw, 'unknown formation')
            if c.get('tactics', {}).get('playstyle') not in PLAYSTYLES:
                err(cw, 'unknown playstyle')
            if 'crest' not in c:
                err(cw, 'crest missing')
            keepers = sum(1 for pid in squad if players.get(pid, {}).get('mainPosition') == 'GK')
            if not 18 <= len(squad) <= 28:
                warn(cw, f'squad size {len(squad)} (18-28 expected)')
            if keepers < 2:
                warn(cw, f'{keepers} goalkeeper(s)')
        orphans = set(players) - owners
        if orphans:
            warn(where, f'{len(orphans)} players without a club')
    return finish(errors, warnings)


def finish(errors, warnings):
    for e in errors:
        print('ERROR  ', e)
    for w in warnings:
        print('warning', w)
    print(f'{len(errors)} errors, {len(warnings)} warnings')
    sys.exit(1 if errors else 0)


if __name__ == '__main__':
    main()
