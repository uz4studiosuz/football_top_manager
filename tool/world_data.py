"""Every other league of 2026.db (all countries and divisions).

England and the Uzbekistan Super League have their own generators
(epl_data.py, efl_data.py); everything else in the database becomes one
lazily loaded league per country and division. Club identity (colours,
crest) is derived from the club name; squads, ages, heights, numbers,
skills and coaches come from the database.

    python -I tool/world_data.py [path/to/2026.db]
"""
import hashlib
import json
import math
import random
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from efl_data import FLAG, NAT, clean, position  # noqa: E402
from epl_data import SKILLS  # noqa: E402
from expand_squads import GROUP, WEIGHTS, generate, ovr, value  # noqa: E402
from world_countries import GB_NATIONS, ISO, flag  # noqa: E402

DATA = Path(__file__).resolve().parent.parent / 'assets' / 'data'
# One file per league (clubs and players together): world/es1.json is
# Spain's first division, world/it3b the second Serie C group, and so on.
WORLD = DATA / 'world'
L10N = Path(__file__).resolve().parent / 'l10n_src' / 'extra_world.json'

# Same order as PlayerStats.fromMap: world files store stats as a list.
STAT_KEYS = ['attackingAwareness', 'ballControl', 'dribbling', 'tightPossession', 'lowPass', 'loftedPass',
             'finishing', 'heading', 'setPieceTaking', 'curl', 'defensiveAwareness', 'defensiveEngagement',
             'tackling', 'aggression', 'gkAwareness', 'gkCatching', 'gkParrying', 'gkReflexes', 'gkReach',
             'speed', 'acceleration', 'kickingPower', 'jumping', 'physicalContact', 'balance', 'stamina']

SHAPES = ['heater', 'roundel', 'shield', 'circle', 'modernShield', 'badge', 'pointed', 'oval']
PATTERNS = ['solid', 'solid', 'solid', 'verticalStripes', 'halves', 'hoops', 'pinstripes', 'quarters',
            'chevron', 'diagonalSash']
EMBLEMS = ['wolf', 'tower', 'trident', 'ball', 'lion', 'tree', 'bird', 'star', 'monogram', 'cannon', 'ship']
PALETTE = [0xFFD7182A, 0xFF0B3D91, 0xFF1F5FBF, 0xFF6CABDD, 0xFF0B8F3C, 0xFF00573F, 0xFFFFD100, 0xFFF26B21,
           0xFF7A263A, 0xFF5B2C83, 0xFF111111, 0xFFFFFFFF, 0xFF0FA3B1, 0xFFE8C46A, 0xFF8A1538, 0xFF14213D]
STYLES = [('f433', 'possession'), ('f4231', 'quickCounter'), ('f442', 'longBall'), ('f4231', 'outWide'),
          ('f352', 'longBallCounter'), ('f433', 'highPressing'), ('f442', 'quickCounter'), ('f4141', 'possession')]
SKIP = {('GB', 'Inglaterra')}  # handled by epl_data / efl_data
UZ_TOP = ('UZ', 1)


def ovr_of(power):
    # Elite database ratings already match our scale; below that the
    # Championship fit (42 + power / 2) keeps lower leagues apart.
    return max(48, min(93, power if power >= 84 else round(42 + power * 0.5)))


def economy_of(avg_power):
    return round(max(0.03, min(1.0, ((avg_power - 35) / 43) ** 3)), 3)


def wage_for(target, economy):
    base = max(500, (target - 45) ** 2.4 * 22)
    return max(300, int(base * (0.25 + economy * 1.6) / 100) * 100)


def h(text):
    return int(hashlib.md5(text.encode('utf8')).hexdigest(), 16)


def identity(name):
    x = h(name)
    p = PALETTE[x % len(PALETTE)]
    s = PALETTE[(x // 17) % len(PALETTE)]
    if s == p:
        s = 0xFFFFFFFF if p != 0xFFFFFFFF else 0xFF111111
    t = PALETTE[(x // 289) % len(PALETTE)]
    return (p, s, t), SHAPES[(x // 7) % len(SHAPES)], PATTERNS[(x // 11) % len(PATTERNS)], EMBLEMS[(x // 13) % len(EMBLEMS)]


def country(nombre, iso):
    if iso == 'GB':
        return GB_NATIONS.get(nombre, 'Angliya')
    u = NAT.get(nombre)
    if u in FLAG:
        return u
    return ISO[iso][0] if iso in ISO else None


def flag_of(nat, iso):
    return FLAG.get(nat) or flag(iso)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else str(Path.home() / 'Downloads' / 'Telegram Desktop' / '2026.db')
    db = sqlite3.connect(f'file:{path}?mode=ro', uri=True)
    db.text_factory = lambda b: b.decode('utf-8', 'replace')
    rnd = random.Random(2627)
    manifest = json.loads((DATA / 'league.json').read_text(encoding='utf8'))
    keep = [e for e in manifest['leagues'] if not e.get('world')]
    WORLD.mkdir(exist_ok=True)
    for f in [*DATA.glob('*_w_*.json'), *WORLD.glob('*.json')]:
        f.unlink()
    groups = {}
    for equid, name, abbr, founded, power, estaid, paid, entid, div, nombre, iso in db.execute(
        """select e.equid, e.equi_nombre, e.equi_abrev, e.equi_funda, e.equi_poder, e.equi_estaid, e.equi_paid,
                  e.equi_entid, e.equi_division, p.nombre, p.iso2
           from eq_equipos e join paises p on p.paid=e.equi_paid"""):
        if (iso, nombre) in SKIP or (iso, div) == UZ_TOP or div < 1:
            continue
        groups.setdefault((paid, div), []).append((equid, name, abbr, founded, power, estaid, entid, nombre, iso))
    leagues, translations, total_players = [], {}, 0
    tiers = {}  # paid -> {div: league entry} (only undivided divisions)
    for (paid, div), clubs in sorted(groups.items(), key=lambda kv: (kv[0][0], kv[0][1])):
        clubs.sort(key=lambda c: -c[4])
        nombre, iso = clubs[0][7], clubs[0][8]
        cname = country(nombre, iso)
        if cname is None or len(clubs) < 4:
            continue
        if iso in ISO:
            translations[cname] = list(ISO[iso][1:])
        # Big divisions play in regional groups of at most 20 clubs.
        # Big divisions play in regional groups of at most 24 clubs; every
        # group needs an even number of clubs, so at most one club sits out.
        n_groups = math.ceil(len(clubs) / 24)
        pairs = len(clubs) // 2
        sizes = [2 * (pairs // n_groups + (1 if i < pairs % n_groups else 0)) for i in range(n_groups)]
        if min(sizes) < 4:
            continue
        order = [c for i in range(n_groups) for c in clubs[i::n_groups]]
        chunks, at = [], 0
        for size in sizes:
            chunks.append(sorted(order[at:at + size], key=lambda c: -c[4]))
            at += size
        tor = db.execute(
            """select t.tor_nombre from tor_torneos t join tor_torneos_paises tp on tp.tp_torid=t.torid
               where tp.tp_paid=? and t.tor_idiv=? and t.tor_organizacion=1""", (paid, div)).fetchone()
        base_name = clean(tor[0]) if tor else f'{cname} {div}'
        for gi, chunk in enumerate(chunks):
            lid = f'{iso.lower()}{div}' + (chr(97 + gi) if n_groups > 1 else '')
            lname = base_name + (f' {chr(65 + gi)}' if n_groups > 1 else '')
            avg = sum(c[4] for c in chunk) / len(chunk)
            eco = economy_of(avg)
            players, out_clubs = build(db, rnd, lid, chunk, eco, iso, cname)
            total_players += len(players)
            (WORLD / f'{lid}.json').write_text(
                json.dumps({'schemaVersion': 2, 'clubs': out_clubs, 'players': players},
                           ensure_ascii=False, separators=(',', ':')) + '\n',
                encoding='utf8')
            entry = {'id': lid, 'name': lname, 'country': cname, 'flag': flag_of(cname, iso),
                     'clubsFile': f'world/{lid}.json', 'playersFile': f'world/{lid}.json',
                     'economy': eco, 'tier': div, 'clubs': len(out_clubs), 'level': round(avg),
                     'world': True, 'lazy': True}
            leagues.append(entry)
            if n_groups == 1:
                tiers.setdefault(paid, {})[div] = entry
    # Countries with consecutive single-group divisions form a pyramid.
    for paid, by_div in tiers.items():
        divs = sorted(by_div)
        chain = [d for i, d in enumerate(divs) if d == i + 1]
        if len(chain) < 2:
            continue
        for d in chain:
            e = by_div[d]
            e['pyramid'] = f'w_{e["id"][:2]}'
            if d + 1 in chain:
                below = by_div[d + 1]
                e['relegate'] = 3 if min(e['clubs'], below['clubs']) >= 12 else 2 if min(e['clubs'], below['clubs']) >= 8 else 1
            if d - 1 in chain:
                e['promote'] = by_div[d - 1]['relegate']
    manifest['leagues'] = keep + leagues
    (DATA / 'league.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + '\n', encoding='utf8')
    L10N.write_text(json.dumps(translations, ensure_ascii=False, indent=1, sort_keys=True) + '\n', encoding='utf8')
    print('leagues', len(leagues), 'clubs', sum(e['clubs'] for e in leagues), 'players', total_players)


def build(db, rnd, lid, chunk, eco, iso, cname):
    players, clubs = [], []
    for equid, name, abbr, founded, power, estaid, entid, _, _ in chunk:
        name = clean(name)
        cid = f'{lid}_{equid}'
        stadium = db.execute('select es_nombre, es_tot_general, es_ciudad from eq_estadios where estaid=?', (estaid,)).fetchone()
        coach = db.execute('select en_nombre from eq_entrenadores where entid=?', (entid,)).fetchone()
        rows = db.execute(
            """select j.jug_nombre, j.jug_edad, j.jug_estatura, j.jug_poder, p.pos_nombre, j.jug_numero,
                      j.jug_perfil, n.nombre, j.jug_habilidad_A, j.jug_habilidad_B, j.jug_potencial, n.iso2
               from jug_jugadores j join eq_equipos_jugadores e on e.eqju_jugid=j.jugid
               join jug_posiciones p on p.posid=j.jug_posid join paises n on n.paid=j.jug_paid
               where e.eqju_equid=? order by j.jug_poder desc""", (equid,)).fetchall()
        picked, keepers = [], 0
        for r in rows:
            pos = position(r[4], r[6])
            if not pos:
                continue
            if pos == 'GK':
                if keepers >= 3:
                    continue
                keepers += 1
            nat = country(r[7], r[11]) or cname
            picked.append((r, pos, nat, flag_of(nat, r[11]) if nat != cname else flag_of(cname, iso)))
            if len(picked) >= 25:
                break
        outfield = [x for x in picked if x[1] != 'GK']
        if keepers < 2 or len(outfield) < 14:
            # Thin database squads get youth players so a lineup always exists.
            need = [('GK', 'Portero')] * max(0, 2 - keepers) + [
                ('CB', 'Defensa Central'), ('CMF', 'Mediocampista Central'), ('CF', 'Centro Delantero'),
                ('RB', 'Defensa Lateral'), ('LB', 'Defensa Lateral'), ('DMF', 'Mediocampista Defensivo'),
                ('AMF', 'Mediocampista Ofensivo'), ('CB', 'Defensa Central'), ('LWF', 'Delantero Extremo'),
                ('RWF', 'Delantero Extremo')] * 2
            for i, (pos, raw) in enumerate(need):
                if pos != 'GK' and len([x for x in picked if x[1] != 'GK']) >= 16:
                    break
                foot = 'I' if pos in ('LB', 'RWF') else 'D'
                low = min((x[0][3] for x in picked), default=40)
                firsts = [x[0][0].split()[0] for x in picked if len(x[0][0].split()) > 1] or ['Alex']
                lasts = [x[0][0].split()[-1] for x in picked if len(x[0][0].split()) > 1] or [name.split()[0]]
                youth = (f'{rnd.choice(firsts)} {rnd.choice(lasts)}', 17 + rnd.randint(0, 2), 178, max(20, low - 5), raw,
                         70 + i, foot, '', None, None, low + 10, iso)
                picked.append((youth, pos, cname, flag_of(cname, iso)))
        ids, used, numbers = [], set(), set()
        for r, pos, nat, fl in picked:
            pname = clean(r[0])
            parts = pname.split()
            short = pname if len(parts) == 1 else f"{parts[0][0]}. {' '.join(parts[1:])}"
            key = ''.join(ch for ch in short.lower() if ch.isalnum())[:12] or 'p'
            pid = f'{cid}_{key}'
            while pid in used:
                pid += 'x'
            used.add(pid)
            target = ovr_of(r[3])
            stats = generate(pos, target, rnd)
            traits = []
            for sid in (r[8], r[9]):
                if sid in SKILLS:
                    label, keys = SKILLS[sid]
                    traits.append(label)
                    for k in keys:
                        stats[k] = min(99, stats[k] + 3)
            height = r[2]
            if height and pos != 'GK':
                bonus = round((height - 182) / 4)
                for k in ('heading', 'jumping'):
                    stats[k] = max(40, min(99, stats[k] + bonus))
            for _ in range(60):
                diff = target - ovr(stats, pos)
                if diff == 0:
                    break
                for k in WEIGHTS[GROUP[pos]]:
                    stats[k] = max(40, min(99, stats[k] + (1 if diff > 0 else -1)))
            number = r[5] or 0
            while number <= 0 or number in numbers:
                number = number + 1 if number > 0 else len(numbers) + 1
            numbers.add(number)
            players.append({
                'id': pid, 'name': pname, 'shortName': short, 'age': r[1], 'nationality': nat, 'countryFlag': fl,
                'number': number, 'mainPosition': pos, 'altPositions': [],
                'preferredFoot': 'left' if r[6] == 'I' else 'right', 'weakFoot': rnd.choice([2, 3, 3, 4]),
                'stats': [max(40, min(99, stats[k])) for k in STAT_KEYS],
                'potential': max(target, ovr_of(r[10] or r[3])),
                **({'height': height} if height else {}),
                **({'traits': traits} if traits else {}),
                'contract': {'contractYears': rnd.choice([1, 2, 2, 3, 3, 4]),
                             'weeklyWage': wage_for(target, eco), 'releaseClause': 0},
                'marketValue': max(25000, int(value(target, r[1]) * (0.35 + 0.65 * eco ** 0.5) / 25000) * 25000),
            })
            ids.append(pid)
        gk = [i for i, x in enumerate(picked) if x[1] == 'GK']
        order = [gk[0]] + [i for i in range(len(picked)) if i != gk[0] and picked[i][1] != 'GK'][:10]
        order += [i for i in range(len(picked)) if i not in order]
        ids = [ids[i] for i in order]
        colors, shape, pattern, emblem = identity(name)
        formation, style = STYLES[h(name) % len(STYLES)]
        rep = max(30, min(95, round(power)))
        mono = ''.join(w[0] for w in name.split() if w[:1].isupper())[:3] or (abbr or name[:3]).upper()
        wages = sum(p['contract']['weeklyWage'] for p in players if p['id'] in ids)
        clubs.append({
            'id': cid, 'name': name, 'shortName': (abbr or name[:3]).upper()[:4],
            'primaryColor': colors[0], 'secondaryColor': colors[1], 'accentColor': colors[2],
            'stadiumName': clean(stadium[0]) if stadium else f'{name} Stadium',
            'stadiumCapacity': max(3000, stadium[1]) if stadium and stadium[1] else 8000,
            'city': clean(stadium[2]) if stadium and stadium[2] else '',
            'nickname': '', 'founded': founded or 1920, 'reputation': rep,
            'transferBudget': max(200000, int((rep - 30) ** 2 * 9000 * (0.15 + eco) / 100000) * 100000),
            'wageBudget': max(20000, int(wages * 1.25 / 1000) * 1000),
            'ticketPrice': max(5, round((10 + rep // 3) * (0.4 + eco))),
            'tactics': {'formation': formation, 'playstyle': style, 'defensiveLine': 3, 'attackingIntensity': 3},
            'crest': {'shape': shape, 'pattern': pattern, 'primaryColor': colors[0], 'secondaryColor': colors[1],
                      'trimColor': colors[2], 'monogram': mono, 'stars': 0, 'crown': False, 'emblem': emblem},
            'managerName': clean(coach[0]) if coach else '',
            'startingLineupIds': ids[:11], 'benchIds': ids[11:20], 'squadIds': ids,
        })
    return players, clubs


if __name__ == '__main__':
    main()
