"""Championship and League One 2025/26 from 2026.db.

Squads, coaches, heights and skills come from the database; club identity
(colours, look-alike crest, stadium, nickname) is written here. Database
"power" maps onto our OVR scale with a fit against the hand-made Premier
League ratings (ovr ≈ 42 + 0.5 × power).

    python -I tool/efl_data.py [path/to/2026.db]
"""
import json
import random
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from epl_data import BAD, DB_NAT, DB_POS, FLAGS, SKILLS  # noqa: E402
from expand_squads import GROUP, WEIGHTS, generate, ovr, value  # noqa: E402

DATA = Path(__file__).resolve().parent.parent / 'assets' / 'data'

NAT = {
    **DB_NAT,
    'Japón': 'Yaponiya', 'Nueva Zelanda': 'Yangi Zelandiya', 'Canadá': 'Kanada', 'Polonia': 'Polsha',
    'Sierra Leona': 'Syerra-Leone', 'República Democrática del Cong': 'KDR', 'Corea del Sur': 'Janubiy Koreya',
    'Ucrania': 'Ukraina', 'Surinám': 'Surinam', 'Serbia': 'Serbiya', 'Hungría': 'Vengriya',
    'Guyana': 'Gayana', 'Gambia': 'Gambiya', 'Finlandia': 'Finlandiya', 'Eslovaquia': 'Slovakiya',
    'Chile': 'Chili', 'Austria': 'Avstriya', 'Sudáfrica': 'JAR', 'Guinea Bissau': 'Gvineya-Bisau',
    'Granada': 'Grenada', 'Eslovenia': 'Sloveniya', 'Curazao': 'Kyurasao', 'Croacia': 'Xorvatiya',
    'Bosnia-Herzegovina': 'Bosniya', 'Argelia': 'Jazoir', 'Uganda': 'Uganda', 'Tunez': 'Tunis',
    'Trinidad y Tobago': 'Trinidad va Tobago', 'Suiza': 'Shveysariya', 'República Checa': 'Chexiya',
    'Montenegro': 'Chernogoriya', 'Mali': 'Mali', 'Kenia': 'Keniya', 'Islandia': 'Islandiya',
    'Indonesia': 'Indoneziya', 'Georgia': 'Gruziya', 'Cabo Verde': 'Kabo-Verde', 'Zambia': 'Zambiya',
    'Zimbabwe': 'Zimbabve', 'Paraguay': 'Paragvay', 'Egipto': 'Misr', 'Burkina Faso': 'Burkina-Faso',
    'Albania': 'Albaniya', 'Israel': 'Isroil', 'Bulgaria': 'Bolgariya', 'Chipre': 'Kipr',
    'Malta': 'Malta', 'Irak': 'Iroq', 'Panamá': 'Panama', 'República del Congo': 'Kongo',
    'Namibia': 'Namibiya', 'Líbano': 'Livan', 'Jordania': 'Iordaniya', 'Bangladesh': 'Bangladesh',
    'Barbados': 'Barbados', 'Fiyi': 'Fiji',
}
EXTRA_FLAGS = {
    'Yangi Zelandiya': '🇳🇿', 'Syerra-Leone': '🇸🇱', 'Surinam': '🇸🇷', 'Gayana': '🇬🇾', 'Gambiya': '🇬🇲',
    'Chili': '🇨🇱', 'JAR': '🇿🇦', 'Gvineya-Bisau': '🇬🇼', 'Grenada': '🇬🇩', 'Kyurasao': '🇨🇼',
    'Uganda': '🇺🇬', 'Trinidad va Tobago': '🇹🇹', 'Chernogoriya': '🇲🇪', 'Keniya': '🇰🇪',
    'Indoneziya': '🇮🇩', 'Kabo-Verde': '🇨🇻', 'Isroil': '🇮🇱', 'Bolgariya': '🇧🇬', 'Kipr': '🇨🇾',
    'Malta': '🇲🇹', 'Iroq': '🇮🇶', 'Panama': '🇵🇦', 'Kongo': '🇨🇬', 'Namibiya': '🇳🇦', 'Livan': '🇱🇧',
    'Iordaniya': '🇯🇴', 'Bangladesh': '🇧🇩', 'Barbados': '🇧🇧', 'Fiji': '🇫🇯',
}
FLAG = {**FLAGS, **EXTRA_FLAGS}


def club(name, short, city, nick, founded, stadium, cap, colors, shape, pattern, emblem):
    return dict(name=name, short=short, city=city, nickname=nick, founded=founded, stadium=stadium,
                capacity=cap, colors=colors, shape=shape, pattern=pattern, emblem=emblem)


W, K, G = 0xFFFFFFFF, 0xFF111111, 0xFFE8C46A
# Database name -> (league, id, identity)
CLUBS = {
    # ------------------------------------------------------------ Championship
    'Leicester City': ('ch', 'ch_lei', club('Leicester City', 'LEI', 'Leicester', 'The Foxes', 1884, 'King Power Stadium', 32259, (0xFF003090, W, 0xFFFDBE11), 'roundel', 'solid', 'wolf')),
    'Ipswich Town': ('ch', 'ch_ips', club('Ipswich Town', 'IPS', 'Ipswich', 'The Tractor Boys', 1878, 'Portman Road', 29673, (0xFF0044A9, W, 0xFFDE2C37), 'shield', 'solid', 'tower')),
    'Sheffield United': ('ch', 'ch_shu', club('Sheffield United', 'SHU', 'Sheffield', 'The Blades', 1889, 'Bramall Lane', 32050, (0xFFEE2737, W, K), 'shield', 'verticalStripes', 'trident')),
    'Birmingham City': ('ch', 'ch_bir', club('Birmingham City', 'BIR', 'Birmingham', 'Blues', 1875, "St Andrew's", 29409, (0xFF1A3E8C, W, G), 'circle', 'solid', 'ball')),
    'Coventry City': ('ch', 'ch_cov', club('Coventry City', 'COV', 'Coventry', 'The Sky Blues', 1883, 'Coventry Building Society Arena', 32609, (0xFF6CABDD, W, 0xFF1D428A), 'modernShield', 'solid', 'tower')),
    'Middlesbrough': ('ch', 'ch_mid', club('Middlesbrough', 'MID', 'Middlesbrough', 'Boro', 1876, 'Riverside Stadium', 34742, (0xFFE11B22, W, 0xFF14213D), 'heater', 'solid', 'lion')),
    'Southampton': ('ch', 'ch_sou', club('Southampton', 'SOU', 'Southampton', 'The Saints', 1885, "St Mary's Stadium", 32384, (0xFFD71920, W, K), 'roundel', 'verticalStripes', 'tree')),
    'West Bromwich Albion': ('ch', 'ch_wba', club('West Bromwich Albion', 'WBA', 'West Bromwich', 'The Baggies', 1878, 'The Hawthorns', 26688, (0xFF122F67, W, G), 'shield', 'verticalStripes', 'bird')),
    'Wrexham': ('ch', 'ch_wre', club('Wrexham', 'WRE', 'Wrexham', 'The Red Dragons', 1864, 'Racecourse Ground', 13341, (0xFFD7182A, W, 0xFF14213D), 'badge', 'solid', 'lion')),
    'Bristol City': ('ch', 'ch_brc', club('Bristol City', 'BRC', 'Bristol', 'The Robins', 1894, 'Ashton Gate', 27000, (0xFFE21A23, W, 0xFFF2C14E), 'circle', 'solid', 'bird')),
    'Blackburn Rovers': ('ch', 'ch_bla', club('Blackburn Rovers', 'BLB', 'Blackburn', 'Rovers', 1875, 'Ewood Park', 31367, (0xFF009EE0, W, 0xFFE2001A), 'shield', 'halves', 'tree')),
    'Millwall': ('ch', 'ch_mil', club('Millwall', 'MIL', 'London', 'The Lions', 1885, 'The Den', 20146, (0xFF001D5E, W, G), 'pointed', 'solid', 'lion')),
    'Preston North End': ('ch', 'ch_pne', club('Preston North End', 'PNE', 'Preston', 'The Lilywhites', 1880, 'Deepdale', 23404, (W, 0xFF0B2240, G), 'shield', 'solid', 'star')),
    'Norwich City': ('ch', 'ch_nor', club('Norwich City', 'NOR', 'Norwich', 'The Canaries', 1902, 'Carrow Road', 27359, (0xFFFFF200, 0xFF00A650, W), 'roundel', 'solid', 'bird')),
    'Sheffield Wednesday': ('ch', 'ch_shw', club('Sheffield Wednesday', 'SHW', 'Sheffield', 'The Owls', 1867, 'Hillsborough', 39732, (0xFF2050A0, W, 0xFFF2C14E), 'oval', 'verticalStripes', 'bird')),
    'Hull City': ('ch', 'ch_hul', club('Hull City', 'HUL', 'Hull', 'The Tigers', 1904, 'MKM Stadium', 25586, (0xFFF5A12D, K, W), 'circle', 'pinstripes', 'lion')),
    'Derby County': ('ch', 'ch_der', club('Derby County', 'DER', 'Derby', 'The Rams', 1884, 'Pride Park', 32956, (W, K, 0xFFB8975A), 'modernShield', 'solid', 'ball')),
    'Watford': ('ch', 'ch_wat', club('Watford', 'WAT', 'Watford', 'The Hornets', 1881, 'Vicarage Road', 22200, (0xFFFBEE23, K, 0xFFED2127), 'badge', 'solid', 'star')),
    'Queens Park Rangers': ('ch', 'ch_qpr', club('Queens Park Rangers', 'QPR', 'London', 'The Hoops', 1882, 'Loftus Road', 18439, (0xFF1D5BA4, W, G), 'shield', 'hoops', 'monogram')),
    'Stoke City': ('ch', 'ch_sto', club('Stoke City', 'STK', 'Stoke-on-Trent', 'The Potters', 1863, 'bet365 Stadium', 30089, (0xFFE03A3E, W, 0xFF1B449C), 'heater', 'verticalStripes', 'tower')),
    'Swansea City': ('ch', 'ch_swa', club('Swansea City', 'SWA', 'Swansea', 'The Swans', 1912, 'Swansea.com Stadium', 21088, (W, K, G), 'oval', 'solid', 'bird')),
    'Charlton Athletic': ('ch', 'ch_cha', club('Charlton Athletic', 'CHA', 'London', 'The Addicks', 1905, 'The Valley', 27111, (0xFFD4021D, W, K), 'circle', 'solid', 'trident')),
    'Portsmouth': ('ch', 'ch_por', club('Portsmouth', 'POR', 'Portsmouth', 'Pompey', 1898, 'Fratton Park', 20899, (0xFF001489, W, G), 'shield', 'solid', 'star')),
    'Oxford United': ('ch', 'ch_oxf', club('Oxford United', 'OXF', 'Oxford', "The U's", 1893, 'Kassam Stadium', 12500, (0xFFFFD700, 0xFF00205B, W), 'roundel', 'solid', 'ball')),
    # ------------------------------------------------------------- League One
    'Wycombe Wanderers': ('l1', 'l1_wyc', club('Wycombe Wanderers', 'WYC', 'High Wycombe', 'The Chairboys', 1887, 'Adams Park', 10137, (0xFF7FB3E0, 0xFF0E2A5A, W), 'shield', 'quarters', 'monogram')),
    'Stockport County': ('l1', 'l1_skp', club('Stockport County', 'SKP', 'Stockport', 'The Hatters', 1883, 'Edgeley Park', 10841, (0xFF0055A5, W, G), 'circle', 'solid', 'star')),
    'Luton Town': ('l1', 'l1_lut', club('Luton Town', 'LUT', 'Luton', 'The Hatters', 1885, 'Kenilworth Road', 12000, (0xFFF78F1E, 0xFF002D62, W), 'badge', 'solid', 'star')),
    'Cardiff City': ('l1', 'l1_car', club('Cardiff City', 'CAR', 'Cardiff', 'The Bluebirds', 1899, 'Cardiff City Stadium', 33280, (0xFF0070B5, W, 0xFFD7182A), 'roundel', 'solid', 'bird')),
    'Bolton Wanderers': ('l1', 'l1_bol', club('Bolton Wanderers', 'BOL', 'Bolton', 'The Trotters', 1874, 'Toughsheet Community Stadium', 28723, (W, 0xFF1C2C5B, 0xFFD7182A), 'circle', 'solid', 'ball')),
    'Bradford City': ('l1', 'l1_bra', club('Bradford City', 'BRA', 'Bradford', 'The Bantams', 1903, 'Valley Parade', 25136, (0xFF8A1538, 0xFFF7A800, W), 'shield', 'verticalStripes', 'bird')),
    'Doncaster Rovers': ('l1', 'l1_don', club('Doncaster Rovers', 'DON', 'Doncaster', 'Rovers', 1879, 'Eco-Power Stadium', 15231, (0xFFE1251B, W, K), 'shield', 'hoops', 'monogram')),
    'Leyton Orient': ('l1', 'l1_ley', club('Leyton Orient', 'LEY', 'London', "The O's", 1881, 'Brisbane Road', 9271, (0xFFE1001A, W, K), 'badge', 'solid', 'bird')),
    'Plymouth Argyle': ('l1', 'l1_ply', club('Plymouth Argyle', 'PLY', 'Plymouth', 'The Pilgrims', 1886, 'Home Park', 17900, (0xFF00573F, W, K), 'shield', 'solid', 'ship')),
    'Blackpool': ('l1', 'l1_blp', club('Blackpool', 'BLP', 'Blackpool', 'The Seasiders', 1887, 'Bloomfield Road', 16616, (0xFFF68712, W, K), 'circle', 'solid', 'tower')),
    'Lincoln City': ('l1', 'l1_lin', club('Lincoln City', 'LIN', 'Lincoln', 'The Imps', 1884, 'Sincil Bank', 10669, (0xFFE20E0E, W, K), 'shield', 'verticalStripes', 'tower')),
    'Reading': ('l1', 'l1_rea', club('Reading', 'REA', 'Reading', 'The Royals', 1871, 'Select Car Leasing Stadium', 24161, (0xFF004494, W, G), 'modernShield', 'hoops', 'monogram')),
    'Peterborough United': ('l1', 'l1_pet', club('Peterborough United', 'PET', 'Peterborough', 'The Posh', 1934, 'London Road', 15314, (0xFF0066B3, W, G), 'circle', 'solid', 'ball')),
    'Huddersfield Town': ('l1', 'l1_hud', club('Huddersfield Town', 'HUD', 'Huddersfield', 'The Terriers', 1908, 'Accu Stadium', 24121, (0xFF0E63AD, W, G), 'shield', 'verticalStripes', 'wolf')),
    'Barnsley': ('l1', 'l1_bar', club('Barnsley', 'BAR', 'Barnsley', 'The Tykes', 1887, 'Oakwell', 23287, (0xFFD71920, W, K), 'oval', 'solid', 'tree')),
    'Wimbledon': ('l1', 'l1_wim', club('AFC Wimbledon', 'WIM', 'London', 'The Dons', 2002, 'Plough Lane', 9215, (0xFF0B2D6B, 0xFFFFD100, W), 'shield', 'solid', 'bird')),
    'Wigan Athletic': ('l1', 'l1_wig', club('Wigan Athletic', 'WIG', 'Wigan', 'The Latics', 1932, 'Brick Community Stadium', 25138, (0xFF1D59AF, W, G), 'circle', 'verticalStripes', 'tree')),
    'Stevenage': ('l1', 'l1_ste', club('Stevenage', 'STE', 'Stevenage', 'Boro', 1976, 'Lamex Stadium', 7800, (0xFFE0001B, W, K), 'badge', 'solid', 'monogram')),
    'Port Vale': ('l1', 'l1_pva', club('Port Vale', 'PVA', 'Burslem', 'The Valiants', 1876, 'Vale Park', 15036, (W, K, G), 'shield', 'solid', 'lion')),
    'Exeter City': ('l1', 'l1_exe', club('Exeter City', 'EXE', 'Exeter', 'The Grecians', 1904, "St James Park", 8696, (0xFFE2001A, W, K), 'roundel', 'verticalStripes', 'tower')),
    'Mansfield Town': ('l1', 'l1_mnf', club('Mansfield Town', 'MNF', 'Mansfield', 'The Stags', 1897, 'One Call Stadium', 9186, (0xFFF6A800, 0xFF1F3F8B, W), 'shield', 'solid', 'wolf')),
    'Rotherham United': ('l1', 'l1_rot', club('Rotherham United', 'ROT', 'Rotherham', 'The Millers', 1925, 'New York Stadium', 12021, (0xFFE2001A, W, K), 'circle', 'solid', 'tower')),
    'Burton Albion': ('l1', 'l1_brt', club('Burton Albion', 'BRT', 'Burton upon Trent', 'The Brewers', 1950, 'Pirelli Stadium', 6912, (0xFFFFD200, K, W), 'shield', 'verticalStripes', 'monogram')),
    'Northampton': ('l1', 'l1_ntn', club('Northampton Town', 'NTN', 'Northampton', 'The Cobblers', 1897, 'Sixfields Stadium', 7798, (0xFF7A263A, W, G), 'badge', 'solid', 'monogram')),
}

STYLES = [('f433', 'possession'), ('f4231', 'quickCounter'), ('f442', 'longBall'), ('f4231', 'outWide'),
          ('f352', 'longBallCounter'), ('f433', 'highPressing'), ('f442', 'quickCounter'), ('f4141', 'possession')]


def wage_for(ovr, rep):
    # Championship stars earn ~30k a week, League One regulars a few thousand.
    return max(2000, int(max(0, ovr - 52) ** 2 * 45 * (0.5 + rep / 140) / 500) * 500)


def ovr_of(power):
    return max(55, min(86, round(42 + power * 0.5)))


def position(raw, foot):
    if raw == 'Defensa Lateral':
        return 'LB' if foot == 'I' else 'RB'
    if raw == 'Mediocampista Extremo':
        return 'LMF' if foot == 'I' else 'RMF'
    if raw == 'Delantero Extremo':
        return 'RWF' if foot == 'I' else 'LWF'  # inverted wingers
    return DB_POS.get(raw)


def clean(name):
    # Accents lost in the database become plain letters ("Mart� Cifuentes" → "Marti").
    return name.replace(BAD, 'i' if name.find(BAD) > 0 and name[name.find(BAD) - 1] in 'rt' else 'e')


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else str(Path.home() / 'Downloads' / 'Telegram Desktop' / '2026.db')
    db = sqlite3.connect(f'file:{path}?mode=ro', uri=True)
    db.text_factory = lambda b: b.decode('utf-8', 'replace')
    rnd = random.Random(2526)
    out = {'ch': ([], []), 'l1': ([], [])}
    skipped = 0
    for dbname, (league, cid, c) in CLUBS.items():
        row = db.execute("""select equid, equi_entid, equi_poder from eq_equipos
                            where equi_nombre=? and equi_paid=185""", (dbname,)).fetchone()
        assert row, dbname
        coach = db.execute('select en_nombre from eq_entrenadores where entid=?', (row[1],)).fetchone()
        rows = db.execute(
            """select j.jug_nombre, j.jug_edad, j.jug_estatura, j.jug_poder, p.pos_nombre, j.jug_numero,
                      j.jug_perfil, n.nombre, j.jug_habilidad_A, j.jug_habilidad_B, j.jug_potencial
               from jug_jugadores j join eq_equipos_jugadores e on e.eqju_jugid=j.jugid
               join jug_posiciones p on p.posid=j.jug_posid join paises n on n.paid=j.jug_paid
               where e.eqju_equid=? order by j.jug_poder desc""", (row[0],)).fetchall()
        rep = row[2]
        players, clubs = out[league]
        picked, keepers = [], 0
        for r in rows:
            pos, nat = position(r[4], r[6]), NAT.get(r[7])
            if not pos or nat not in FLAG:
                skipped += 1
                continue
            if pos == 'GK':
                if keepers >= 3:
                    continue
                keepers += 1
            picked.append((r, pos, nat))
            if len(picked) >= 25:
                break
        # Every squad needs at least two keepers; the database sometimes
        # lists one, so a youth-team keeper is added.
        while keepers < 2:
            keepers += 1
            youth = f"{rnd.choice(['Harry', 'Jack', 'Oliver', 'Charlie', 'Alfie', 'Sam', 'Ben', 'Lewis'])} "                     f"{rnd.choice(['Walker', 'Hughes', 'Bennett', 'Carter', 'Price', 'Turner', 'Morris', 'Cole'])}"
            picked.append(((youth, 19, 188, 50, 'Portero', 30 + keepers, 'D',
                            'Inglaterra', None, None, 60), 'GK', 'Angliya'))
        ids, used = [], set()
        for r, pos, nat in picked:
            name = clean(r[0])
            parts = name.split()
            short = name if len(parts) == 1 else f"{parts[0][0]}. {' '.join(parts[1:])}"
            key = ''.join(ch for ch in short.lower() if ch.isalnum())[:14]
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
            # Skills and height must not lift the overall above the target.
            for _ in range(60):
                diff = target - ovr(stats, pos)
                if diff == 0:
                    break
                for k in WEIGHTS[GROUP[pos]]:
                    stats[k] = max(40, min(99, stats[k] + (1 if diff > 0 else -1)))
            players.append({
                'id': pid, 'name': name, 'shortName': short, 'age': r[1], 'nationality': nat,
                'countryFlag': FLAG[nat], 'number': r[5] or (len(ids) + 1), 'mainPosition': pos,
                'altPositions': [], 'preferredFoot': 'left' if r[6] == 'I' else 'right',
                'weakFoot': rnd.choice([2, 3, 3, 4]), 'stats': stats,
                'potential': max(target, ovr_of(r[10] or r[3])),
                **({'height': height} if height else {}),
                **({'traits': traits} if traits else {}),
                'contract': {'contractYears': rnd.choice([1, 2, 2, 3, 3, 4]),
                             'weeklyWage': wage_for(target, rep), 'releaseClause': 0},
                'marketValue': value(target, r[1]),
            })
            ids.append(pid)
        formation, style = STYLES[rnd.randrange(len(STYLES))]
        colors = c['colors']
        mono = ''.join(w[0] for w in c['name'].replace('AFC ', '').split() if w[0].isupper())[:4] or c['short']
        clubs.append({
            'id': cid, 'name': c['name'], 'shortName': c['short'],
            'primaryColor': colors[0], 'secondaryColor': colors[1], 'accentColor': colors[2],
            'stadiumName': c['stadium'], 'stadiumCapacity': c['capacity'], 'city': c['city'],
            'nickname': c['nickname'], 'founded': c['founded'], 'reputation': rep,
            'transferBudget': max(2, (rep - 44) * (2 if league == 'ch' else 1)) * 1000000,
            'wageBudget': 0,
            'ticketPrice': 18 + rep // 3,
            'tactics': {'formation': formation, 'playstyle': style, 'defensiveLine': 3, 'attackingIntensity': 3},
            'crest': {'shape': c['shape'], 'pattern': c['pattern'], 'primaryColor': colors[0],
                      'secondaryColor': colors[1], 'trimColor': colors[2], 'monogram': mono,
                      'stars': 0, 'crown': False, 'emblem': c['emblem']},
            'managerName': clean(coach[0]) if coach else '',
            'startingLineupIds': ids[:11], 'benchIds': ids[11:20], 'squadIds': ids,
        })
        wages = sum(p['contract']['weeklyWage'] for p in players if p['id'] in ids)
        clubs[-1]['wageBudget'] = int(wages * 1.25 / 10000) * 10000
    for league, (players, clubs) in out.items():
        (DATA / f'players_{league}.json').write_text(
            json.dumps({'schemaVersion': 2, 'players': players}, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf8')
        (DATA / f'clubs_{league}.json').write_text(
            json.dumps({'schemaVersion': 2, 'clubs': clubs}, ensure_ascii=False, indent=1) + '\n', encoding='utf8')
        print(league, 'clubs', len(clubs), 'players', len(players))
    print('skipped (unknown position/nationality):', skipped)


if __name__ == '__main__':
    main()
