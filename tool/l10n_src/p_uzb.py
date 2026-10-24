"""One-off patch: Uzbekistan Super League in tool/efl_data.py."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
p = ROOT / 'tool/efl_data.py'
s = p.read_text(encoding='utf8')


def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:70])
    s = s.replace(a, b, 1)


rep("""    'Barbados': 'Barbados', 'Fiyi': 'Fiji',""", """    'Barbados': 'Barbados', 'Fiyi': 'Fiji',
    'Uzbekistán': 'O‘zbekiston', 'Tayikistán': 'Tojikiston', 'Kirguistán': 'Qirg‘iziston', 'Rusia': 'Rossiya',
    'Macedonia': 'Shimoliy Makedoniya', 'Liberia': 'Liberiya',""")
rep("""    'Iordaniya': '🇯🇴', 'Bangladesh': '🇧🇩', 'Barbados': '🇧🇧', 'Fiji': '🇫🇯',""",
    """    'Iordaniya': '🇯🇴', 'Bangladesh': '🇧🇩', 'Barbados': '🇧🇧', 'Fiji': '🇫🇯',
    'Tojikiston': '🇹🇯', 'Qirg‘iziston': '🇰🇬', 'Rossiya': '🇷🇺', 'Shimoliy Makedoniya': '🇲🇰', 'Liberiya': '🇱🇷',""")

# Uzbek clubs (database country 240)
rep("""STYLES = [""", """
def uz(name, short, city, nick, founded, stadium, cap, colors, shape, pattern, emblem):
    return dict(club(name, short, city, nick, founded, stadium, cap, colors, shape, pattern, emblem), paid=240)


CLUBS.update({
    'Pakhtakor': ('uzb', 'uz_pak', uz('Pakhtakor', 'PAK', 'Toshkent', 'Paxtakorlar', 1956, 'Pakhtakor Markaziy stadioni', 35000, (0xFF0B8F3C, W, 0xFFF2C14E), 'shield', 'solid', 'tree')),
    'Navbahor': ('uzb', 'uz_nav', uz('Navbahor', 'NAV', 'Namangan', 'Namanganliklar', 1978, 'Markaziy stadion (Namangan)', 22000, (0xFF0E7A3E, 0xFFFFD100, W), 'roundel', 'halves', 'star')),
    'Nasaf Qarshi': ('uzb', 'uz_nas', uz('Nasaf', 'NAS', 'Qarshi', 'Qarshiliklar', 1986, 'Markaziy stadion (Qarshi)', 21000, (0xFF1F5FBF, W, 0xFFF2C14E), 'shield', 'verticalStripes', 'lion')),
    'Lokomotiv Tashkent': ('uzb', 'uz_lok', uz('Lokomotiv Toshkent', 'LOK', 'Toshkent', 'Temiryo‘lchilar', 2002, 'Lokomotiv stadioni', 8000, (0xFFC8102E, W, 0xFF0B8F3C), 'badge', 'solid', 'monogram')),
    'Bunyodkor': ('uzb', 'uz_bun', uz('Bunyodkor', 'BUN', 'Toshkent', 'Bunyodkorlar', 2005, 'Milliy stadion', 34000, (0xFFFFD100, 0xFF1F3F8B, W), 'modernShield', 'solid', 'bird')),
    'AGMK': ('uzb', 'uz_agm', uz('AGMK', 'AGM', 'Olmaliq', 'Konchilar', 2004, 'OKMK stadioni', 12000, (0xFFF26B21, 0xFF1F3F8B, W), 'shield', 'chevron', 'tower')),
    'Neftchi': ('uzb', 'uz_nef', uz('Neftchi', 'NEF', 'Farg‘ona', 'Neftchilar', 1962, 'Istiqlol stadioni', 20000, (W, 0xFFC8102E, 0xFF111111), 'circle', 'solid', 'tower')),
    'Andijon': ('uzb', 'uz_and', uz('Andijon', 'AND', 'Andijon', 'Andijonliklar', 1964, 'Bobur Arena', 18000, (0xFF1F5FBF, W, 0xFFF2C14E), 'shield', 'hoops', 'wolf')),
    'Buxoro': ('uzb', 'uz_bux', uz('Buxoro', 'BUX', 'Buxoro', 'Buxoroliklar', 1958, 'Buxoro Arena', 22700, (0xFF0FA3B1, W, 0xFFF2C14E), 'roundel', 'solid', 'tower')),
    'Dinamo Samarqand': ('uzb', 'uz_din', uz('Dinamo Samarqand', 'DSM', 'Samarqand', 'Dinamochilar', 1960, 'Dinamo stadioni', 16000, (0xFF1F3F8B, W, 0xFF0FA3B1), 'shield', 'diagonalSash', 'monogram')),
    'Kokand 1912': ('uzb', 'uz_kok', uz('Qo‘qon 1912', 'KOK', 'Qo‘qon', 'Qo‘qonliklar', 1912, 'Markaziy stadion (Qo‘qon)', 10500, (0xFF1F5FBF, 0xFFFFD100, W), 'heater', 'solid', 'star')),
    'Sogdiana': ('uzb', 'uz_sog', uz('So‘g‘diyona', 'SOG', 'Jizzax', 'Jizzaxliklar', 1970, 'So‘g‘diyona stadioni', 11650, (0xFF0B8F3C, W, 0xFFF2C14E), 'circle', 'verticalStripes', 'bird')),
    'Surkhon Termez': ('uzb', 'uz_sur', uz('Surxon', 'SUR', 'Termiz', 'Surxonliklar', 1968, 'Alpomish stadioni', 10000, (0xFFFFD100, 0xFF0B8F3C, W), 'shield', 'solid', 'ball')),
    'Mashʼal': ('uzb', 'uz_mas', uz('Mash’al', 'MAS', 'Muborak', 'Mash’alchilar', 1980, 'Bahrom Vafoev stadioni', 10000, (0xFF1F5FBF, W, 0xFFF26B21), 'badge', 'solid', 'trident')),
    'Qizilqum': ('uzb', 'uz_qiz', uz('Qizilqum', 'QZQ', 'Zarafshon', 'Konchilar', 1967, 'Yoshlar stadioni', 12500, (0xFFFFD100, 0xFFC8102E, W), 'shield', 'halves', 'lion')),
    'Xorazm': ('uzb', 'uz_xor', uz('Xorazm', 'XOR', 'Urganch', 'Xorazmliklar', 1972, 'Xorazm stadioni', 13500, (0xFFC8102E, 0xFF1F3F8B, W), 'roundel', 'solid', 'cannon')),
})

UZ_FIRST = ['Sardor', 'Jasur', 'Otabek', 'Bekzod', 'Dilshod', 'Javohir', 'Shohruh', 'Azizbek', 'Ulug‘bek', 'Islom']
UZ_LAST = ['Tursunov', 'Rahimov', 'Karimov', 'Yusupov', 'Ergashev', 'Nazarov', 'Qodirov', 'Sobirov', 'Aliyev', 'Hasanov']

STYLES = [""")
rep("""    out = {'ch': ([], []), 'l1': ([], [])}""", """    out = {'ch': ([], []), 'l1': ([], []), 'uzb': ([], [])}""")
rep("""                            where equi_nombre=? and equi_paid=185\"\"\", (dbname,)).fetchone()""",
    """                            where equi_nombre=? and equi_paid=?\"\"\", (dbname, c.get('paid', 185))).fetchone()""")
rep("""        ids, used = [], set()
        for r, pos, nat in picked:""", """        # Short database squads (Uzbekistan) are topped up with youth players.
        fill = ['CB', 'CMF', 'LB', 'RB', 'CF', 'LWF', 'RWF', 'DMF', 'AMF', 'CB']
        db_pos = {'CB': 'Defensa Central', 'CMF': 'Mediocampista Central', 'LB': 'Defensa Lateral',
                  'RB': 'Defensa Lateral', 'CF': 'Centro Delantero', 'LWF': 'Delantero Extremo',
                  'RWF': 'Delantero Extremo', 'DMF': 'Mediocampista Defensivo', 'AMF': 'Mediocampista Ofensivo'}
        while league == 'uzb' and len(picked) < 22:
            pos = fill[len(picked) % len(fill)]
            name = f'{rnd.choice(UZ_FIRST)} {rnd.choice(UZ_LAST)}'
            foot = 'I' if pos in ('LB', 'RWF') else 'D'
            picked.append(((name, 18 + rnd.randint(0, 3), 178, 40 + rnd.randint(0, 10), db_pos[pos], 60 + len(picked),
                            foot, 'Uzbekistán', None, None, 62), pos, 'O‘zbekiston'))
        ids, used = [], set()
        for r, pos, nat in picked:""")
rep("""                             'weeklyWage': wage_for(target, rep), 'releaseClause': 0},""",
    """                             'weeklyWage': max(1000, int(wage_for(target, rep) * (0.35 if league == 'uzb' else 1))), 'releaseClause': 0},""")
rep("""            'transferBudget': max(2, (rep - 44) * (2 if league == 'ch' else 1)) * 1000000,""",
    """            'transferBudget': max(2, (rep - 44) * (2 if league == 'ch' else 1)) * 1000000 if league != 'uzb' else 3000000,""")
p.write_text(s, encoding='utf8')
print('ok')
