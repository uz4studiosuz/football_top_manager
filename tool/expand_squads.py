"""Expands every club to a 23-man squad and refreshes crest/club metadata.

Attributes for added players are generated from a positional profile and
then nudged until the Dart OVR formula (mirrored below) hits the target.
Run from the project root:  python -I tool/expand_squads.py
"""
import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'assets' / 'data'

WEIGHTS = {
    'ST': {'finishing': .27, 'attackingAwareness': .22, 'kickingPower': .12, 'heading': .10,
           'ballControl': .10, 'physicalContact': .08, 'speed': .06, 'acceleration': .05},
    'SS': {'attackingAwareness': .18, 'tightPossession': .18, 'dribbling': .16, 'ballControl': .16,
           'lowPass': .14, 'finishing': .12, 'acceleration': .06},
    'WF': {'speed': .18, 'acceleration': .17, 'dribbling': .18, 'ballControl': .14, 'tightPossession': .10,
           'lowPass': .08, 'loftedPass': .07, 'attackingAwareness': .08},
    'MF': {'lowPass': .16, 'loftedPass': .18, 'dribbling': .14, 'speed': .14, 'acceleration': .10,
           'stamina': .12, 'tightPossession': .08, 'attackingAwareness': .08},
    'AMF': {'lowPass': .23, 'tightPossession': .18, 'ballControl': .18, 'attackingAwareness': .14,
            'dribbling': .12, 'finishing': .08, 'curl': .07},
    'CMF': {'lowPass': .25, 'loftedPass': .18, 'tightPossession': .15, 'ballControl': .12,
            'defensiveEngagement': .10, 'stamina': .12, 'balance': .08},
    'DMF': {'defensiveAwareness': .20, 'defensiveEngagement': .18, 'tackling': .20, 'lowPass': .18,
            'physicalContact': .14, 'stamina': .10},
    'CB': {'defensiveAwareness': .25, 'defensiveEngagement': .19, 'tackling': .23, 'heading': .12,
           'physicalContact': .14, 'jumping': .07},
    'FB': {'speed': .14, 'acceleration': .10, 'stamina': .15, 'defensiveAwareness': .15, 'tackling': .14,
           'defensiveEngagement': .12, 'loftedPass': .12, 'lowPass': .08},
    'GK': {'gkAwareness': .25, 'gkCatching': .15, 'gkParrying': .15, 'gkReflexes': .30, 'gkReach': .15},
}
GROUP = {'ST': 'ST', 'CF': 'ST', 'SS': 'SS', 'LWF': 'WF', 'RWF': 'WF', 'LMF': 'MF', 'RMF': 'MF',
         'AMF': 'AMF', 'CMF': 'CMF', 'DMF': 'DMF', 'CB': 'CB', 'LB': 'FB', 'RB': 'FB', 'GK': 'GK'}
KEYS = ['attackingAwareness', 'ballControl', 'dribbling', 'tightPossession', 'lowPass', 'loftedPass',
        'finishing', 'heading', 'setPieceTaking', 'curl', 'defensiveAwareness', 'defensiveEngagement',
        'tackling', 'aggression', 'gkAwareness', 'gkCatching', 'gkParrying', 'gkReflexes', 'gkReach',
        'speed', 'acceleration', 'kickingPower', 'jumping', 'physicalContact', 'balance', 'stamina']
# Offsets from the target for non-weighted attributes, per group.
PROFILE = {
    'ST': {'defensiveAwareness': -38, 'defensiveEngagement': -35, 'tackling': -38, 'lowPass': -8,
           'loftedPass': -12, 'setPieceTaking': -10, 'stamina': -6},
    'SS': {'defensiveAwareness': -35, 'defensiveEngagement': -30, 'tackling': -35, 'heading': -14},
    'WF': {'defensiveAwareness': -36, 'defensiveEngagement': -30, 'tackling': -36, 'heading': -18,
           'finishing': -4, 'physicalContact': -14},
    'MF': {'defensiveAwareness': -18, 'tackling': -18, 'heading': -16, 'finishing': -10},
    'AMF': {'defensiveAwareness': -28, 'tackling': -30, 'defensiveEngagement': -24, 'heading': -18,
            'physicalContact': -12},
    'CMF': {'defensiveAwareness': -10, 'tackling': -10, 'finishing': -14, 'heading': -14, 'speed': -8},
    'DMF': {'finishing': -22, 'dribbling': -10, 'curl': -14, 'speed': -8, 'attackingAwareness': -18},
    'CB': {'finishing': -36, 'dribbling': -22, 'curl': -28, 'attackingAwareness': -34, 'tightPossession': -18,
           'setPieceTaking': -30, 'lowPass': -8, 'loftedPass': -10},
    'FB': {'finishing': -30, 'attackingAwareness': -20, 'heading': -12, 'curl': -14, 'setPieceTaking': -24},
    'GK': {k: -40 for k in KEYS if not k.startswith('gk')},
}


def ovr(stats, pos):
    w = WEIGHTS[GROUP[pos]]
    return round(sum(stats[k] * v for k, v in w.items()) / sum(w.values()))


def generate(pos, target, rnd):
    g = GROUP[pos]
    stats = {}
    for k in KEYS:
        base = target + PROFILE[g].get(k, -3) + rnd.randint(-4, 4)
        if k.startswith('gk') and g != 'GK':
            base = 40
        stats[k] = max(40, min(99, base))
    if g == 'GK':
        for k in KEYS:
            if not k.startswith('gk'):
                stats[k] = max(40, min(80, target - 40 + rnd.randint(-2, 18)))
    for _ in range(60):
        diff = target - ovr(stats, pos)
        if diff == 0:
            break
        for k in WEIGHTS[g]:
            stats[k] = max(40, min(99, stats[k] + (1 if diff > 0 else -1)))
    return stats


def value(target, age):
    base = (max(0, target - 55) / 10) ** 3.4 * 1600000
    factor = 1.45 if age <= 21 else 1.25 if age <= 24 else 1.05 if age <= 27 else 0.88 if age <= 29 \
        else 0.66 if age <= 31 else 0.42 if age <= 33 else 0.22
    v = int(base * factor)
    step = 500000 if v >= 10000000 else 100000
    return max(250000, round(v / step) * step)


# id, name, short, age, nationality, flag, number, pos, alt, foot, ovr, weekly wage
NEW = {
    'real_madrid': ('rma', [
        ('guler', 'Arda Güler', 'A. Güler', 20, 'Turkiya', '🇹🇷', 15, 'AMF', ['RWF', 'CMF'], 'left', 80, 90000),
        ('ceballos', 'Dani Ceballos', 'D. Ceballos', 28, 'Ispaniya', '🇪🇸', 19, 'CMF', ['AMF'], 'right', 79, 110000),
        ('vazquez', 'Lucas Vázquez', 'L. Vázquez', 33, 'Ispaniya', '🇪🇸', 17, 'RB', ['RMF'], 'right', 78, 120000),
        ('alaba', 'David Alaba', 'D. Alaba', 32, 'Avstriya', '🇦🇹', 4, 'CB', ['LB', 'DMF'], 'left', 82, 220000),
        ('fgarcia', 'Fran García', 'F. García', 25, 'Ispaniya', '🇪🇸', 20, 'LB', ['LMF'], 'left', 76, 70000),
        ('asencio', 'Raúl Asencio', 'R. Asencio', 21, 'Ispaniya', '🇪🇸', 35, 'CB', [], 'right', 75, 25000),
        ('fgonzalez', 'Fran González', 'F. González', 19, 'Ispaniya', '🇪🇸', 26, 'GK', [], 'right', 66, 12000),
    ]),
    'manchester_city': ('mci', [
        ('marmoush', 'Omar Marmoush', 'O. Marmoush', 25, 'Misr', '🇪🇬', 7, 'ST', ['LWF', 'CF'], 'right', 84, 180000),
        ('khusanov', 'Abdukodir Khusanov', 'A. Khusanov', 20, 'O‘zbekiston', '🇺🇿', 45, 'CB', [], 'right', 76, 55000),
        ('ake', 'Nathan Aké', 'N. Aké', 29, 'Niderlandiya', '🇳🇱', 6, 'CB', ['LB'], 'left', 83, 180000),
        ('lewis', 'Rico Lewis', 'R. Lewis', 20, 'Angliya', '🏴', 82, 'RB', ['CMF'], 'right', 77, 50000),
        ('nunes', 'Matheus Nunes', 'M. Nunes', 26, 'Portugaliya', '🇵🇹', 27, 'CMF', ['RB'], 'right', 79, 140000),
        ('grealish', 'Jack Grealish', 'J. Grealish', 29, 'Angliya', '🏴', 10, 'LWF', ['AMF'], 'right', 81, 300000),
        ('bobb', 'Oscar Bobb', 'O. Bobb', 21, 'Norvegiya', '🇳🇴', 52, 'RWF', ['AMF'], 'left', 74, 40000),
    ]),
    'arsenal': ('ars', [
        ('sterling', 'Raheem Sterling', 'R. Sterling', 30, 'Angliya', '🏴', 30, 'LWF', ['RWF'], 'right', 79, 300000),
        ('kiwior', 'Jakub Kiwior', 'J. Kiwior', 24, 'Polsha', '🇵🇱', 15, 'CB', ['LB'], 'left', 77, 70000),
        ('tomiyasu', 'Takehiro Tomiyasu', 'T. Tomiyasu', 26, 'Yaponiya', '🇯🇵', 18, 'RB', ['CB', 'LB'], 'right', 78, 90000),
        ('tierney', 'Kieran Tierney', 'K. Tierney', 27, 'Shotlandiya', '🏴', 3, 'LB', [], 'left', 76, 110000),
        ('nwaneri', 'Ethan Nwaneri', 'E. Nwaneri', 18, 'Angliya', '🏴', 53, 'AMF', ['RWF'], 'left', 74, 15000),
        ('skelly', 'Myles Lewis-Skelly', 'M. Lewis-Skelly', 18, 'Angliya', '🏴', 49, 'LB', ['CMF'], 'left', 73, 12000),
        ('neto', 'Neto', 'Neto', 35, 'Braziliya', '🇧🇷', 32, 'GK', [], 'right', 76, 60000),
    ]),
    'barcelona': ('fcb', [
        ('szczesny', 'Wojciech Szczęsny', 'W. Szczęsny', 34, 'Polsha', '🇵🇱', 25, 'GK', [], 'right', 81, 120000),
        ('inigo', 'Iñigo Martínez', 'I. Martínez', 33, 'Ispaniya', '🇪🇸', 5, 'CB', [], 'left', 81, 150000),
        ('ericgarcia', 'Eric García', 'E. García', 24, 'Ispaniya', '🇪🇸', 24, 'CB', ['DMF', 'RB'], 'right', 77, 90000),
        ('casado', 'Marc Casadó', 'M. Casadó', 21, 'Ispaniya', '🇪🇸', 17, 'DMF', ['CMF'], 'right', 77, 40000),
        ('ansu', 'Ansu Fati', 'Ansu Fati', 22, 'Ispaniya', '🇪🇸', 10, 'LWF', ['ST'], 'right', 75, 200000),
        ('gmartin', 'Gerard Martín', 'G. Martín', 22, 'Ispaniya', '🇪🇸', 35, 'LB', [], 'left', 73, 20000),
        ('pauvictor', 'Pau Víctor', 'P. Víctor', 23, 'Ispaniya', '🇪🇸', 18, 'ST', [], 'right', 72, 25000),
    ]),
    'bayern_munich': ('bay', [
        ('goretzka', 'Leon Goretzka', 'L. Goretzka', 30, 'Germaniya', '🇩🇪', 8, 'CMF', ['DMF'], 'right', 81, 300000),
        ('laimer', 'Konrad Laimer', 'K. Laimer', 27, 'Avstriya', '🇦🇹', 27, 'RB', ['CMF', 'DMF'], 'right', 80, 150000),
        ('ito', 'Hiroki Ito', 'H. Ito', 25, 'Yaponiya', '🇯🇵', 21, 'CB', ['LB'], 'left', 79, 120000),
        ('dier', 'Eric Dier', 'E. Dier', 31, 'Angliya', '🏴', 15, 'CB', ['DMF'], 'right', 78, 140000),
        ('zaragoza', 'Bryan Zaragoza', 'B. Zaragoza', 23, 'Ispaniya', '🇪🇸', 17, 'LWF', ['RWF'], 'right', 74, 60000),
        ('wanner', 'Paul Wanner', 'P. Wanner', 19, 'Germaniya', '🇩🇪', 14, 'AMF', ['CMF'], 'left', 72, 15000),
        ('ulreich', 'Sven Ulreich', 'S. Ulreich', 36, 'Germaniya', '🇩🇪', 26, 'GK', [], 'right', 74, 50000),
    ]),
    'paris_sg': ('psg', [
        ('kvara', 'Khvicha Kvaratskhelia', 'K. Kvaratskhelia', 24, 'Gruziya', '🇬🇪', 7, 'LWF', ['AMF'], 'right', 87, 260000),
        ('doue', 'Désiré Doué', 'D. Doué', 19, 'Fransiya', '🇫🇷', 14, 'AMF', ['RWF', 'LWF'], 'right', 80, 90000),
        ('ramos', 'Gonçalo Ramos', 'G. Ramos', 23, 'Portugaliya', '🇵🇹', 9, 'ST', [], 'right', 80, 160000),
        ('lhernandez', 'Lucas Hernández', 'L. Hernández', 29, 'Fransiya', '🇫🇷', 21, 'CB', ['LB'], 'left', 81, 200000),
        ('kimpembe', 'Presnel Kimpembe', 'P. Kimpembe', 29, 'Fransiya', '🇫🇷', 3, 'CB', [], 'left', 77, 170000),
        ('mayulu', 'Senny Mayulu', 'S. Mayulu', 18, 'Fransiya', '🇫🇷', 24, 'CMF', ['AMF'], 'right', 70, 12000),
        ('tenas', 'Arnau Tenas', 'A. Tenas', 23, 'Ispaniya', '🇪🇸', 80, 'GK', [], 'right', 72, 30000),
    ]),
    'inter_milan': ('int', [
        ('devrij', 'Stefan de Vrij', 'S. de Vrij', 32, 'Niderlandiya', '🇳🇱', 6, 'CB', [], 'right', 82, 140000),
        ('bisseck', 'Yann Bisseck', 'Y. Bisseck', 24, 'Germaniya', '🇩🇪', 31, 'CB', ['RB'], 'right', 79, 60000),
        ('darmian', 'Matteo Darmian', 'M. Darmian', 35, 'Italiya', '🇮🇹', 36, 'RB', ['CB', 'LB'], 'right', 78, 70000),
        ('asllani', 'Kristjan Asllani', 'K. Asllani', 22, 'Albaniya', '🇦🇱', 21, 'DMF', ['CMF'], 'right', 76, 45000),
        ('zalewski', 'Nicola Zalewski', 'N. Zalewski', 23, 'Polsha', '🇵🇱', 59, 'LB', ['LMF'], 'left', 75, 40000),
        ('arnautovic', 'Marko Arnautović', 'M. Arnautović', 35, 'Avstriya', '🇦🇹', 8, 'ST', ['CF'], 'right', 77, 70000),
        ('correa', 'Joaquín Correa', 'J. Correa', 30, 'Argentina', '🇦🇷', 11, 'SS', ['ST'], 'right', 75, 90000),
    ]),
    'liverpool': ('liv', [
        ('chiesa', 'Federico Chiesa', 'F. Chiesa', 27, 'Italiya', '🇮🇹', 14, 'RWF', ['LWF'], 'right', 78, 150000),
        ('endo', 'Wataru Endō', 'W. Endō', 31, 'Yaponiya', '🇯🇵', 3, 'DMF', ['CB'], 'right', 78, 70000),
        ('gomez', 'Joe Gomez', 'J. Gomez', 27, 'Angliya', '🏴', 2, 'CB', ['RB', 'LB'], 'right', 79, 85000),
        ('tsimikas', 'Kostas Tsimikas', 'K. Tsimikas', 28, 'Gretsiya', '🇬🇷', 21, 'LB', [], 'left', 77, 60000),
        ('quansah', 'Jarell Quansah', 'J. Quansah', 21, 'Angliya', '🏴', 78, 'CB', [], 'right', 76, 30000),
        ('bradley', 'Conor Bradley', 'C. Bradley', 21, 'Shimoliy Irlandiya', '🇬🇧', 84, 'RB', [], 'right', 75, 30000),
        ('doak', 'Ben Doak', 'B. Doak', 19, 'Shotlandiya', '🏴', 50, 'RWF', [], 'right', 70, 15000),
    ]),
}

CLUB_META = {
    'real_madrid': dict(city='Madrid', nickname='Los Blancos', founded=1902, reputation=96,
                        crest=dict(shape='circle', pattern='diagonalSash', primaryColor=0xFFFFFFFF,
                                   secondaryColor=0xFF2C3E91, trimColor=0xFFE2B400, monogram='RM',
                                   stars=0, emblem='monogram', crown=True)),
    'manchester_city': dict(city='Manchester', nickname='The Citizens', founded=1880, reputation=93,
                            crest=dict(shape='roundel', pattern='solid', primaryColor=0xFF6CABDD,
                                       secondaryColor=0xFF1C2C5B, trimColor=0xFFF4C430, monogram='MC',
                                       stars=0, emblem='ship', crown=False, ringText='MANCHESTER CITY',
                                       ringColor=0xFF1C2C5B)),
    'arsenal': dict(city='London', nickname='The Gunners', founded=1886, reputation=87,
                    crest=dict(shape='heater', pattern='solid', primaryColor=0xFFDB0007,
                               secondaryColor=0xFFFFFFFF, trimColor=0xFFE8C46A, monogram='AFC',
                               stars=0, emblem='cannon', crown=False)),
    'barcelona': dict(city='Barcelona', nickname='Blaugrana', founded=1899, reputation=92,
                      crest=dict(shape='pointed', pattern='splitCross', primaryColor=0xFF004D98,
                                 secondaryColor=0xFFA50044, trimColor=0xFFF2C14E, monogram='FCB',
                                 stars=0, emblem='ball', crown=False)),
    'bayern_munich': dict(city='München', nickname='Die Roten', founded=1900, reputation=92,
                          crest=dict(shape='roundel', pattern='lozenges', primaryColor=0xFFFFFFFF,
                                     secondaryColor=0xFF0066B2, trimColor=0xFFFFFFFF, monogram='FCB',
                                     stars=0, emblem='monogram', crown=False, ringText='FC BAYERN MÜNCHEN',
                                     ringColor=0xFFDC052D)),
    'paris_sg': dict(city='Paris', nickname='Les Parisiens', founded=1970, reputation=89,
                     crest=dict(shape='roundel', pattern='solid', primaryColor=0xFFDA291C,
                                secondaryColor=0xFF004170, trimColor=0xFFFFFFFF, monogram='PSG',
                                stars=0, emblem='tower', crown=False, ringText='PARIS SAINT-GERMAIN',
                                ringColor=0xFF004170)),
    'inter_milan': dict(city='Milano', nickname='Nerazzurri', founded=1908, reputation=85,
                        crest=dict(shape='roundel', pattern='rings', primaryColor=0xFF0068A8,
                                   secondaryColor=0xFF111111, trimColor=0xFFE7C35A, monogram='IM',
                                   stars=2, emblem='monogram', crown=False, ringText='INTERNAZIONALE MILANO',
                                   ringColor=0xFF111111)),
    'liverpool': dict(city='Liverpool', nickname='The Reds', founded=1892, reputation=90,
                      crest=dict(shape='heater', pattern='solid', primaryColor=0xFFC8102E,
                                 secondaryColor=0xFF00B2A9, trimColor=0xFFF6EB61, monogram='LFC',
                                 stars=0, emblem='bird', crown=False)),
}


def main():
    rnd = random.Random(2027)
    players_doc = json.loads((DATA / 'players.json').read_text(encoding='utf8'))
    clubs_doc = json.loads((DATA / 'clubs.json').read_text(encoding='utf8'))
    players = players_doc['players']
    existing = {p['id'] for p in players}
    for club in clubs_doc['clubs']:
        prefix, extra = NEW[club['id']]
        used_numbers = {p['number'] for p in players if p['id'] in club['squadIds']}
        added = []
        for key, name, short, age, nat, flag, num, pos, alt, foot, target, wage in extra:
            pid = f'{prefix}_{key}'
            if pid in existing:
                continue
            while num in used_numbers:
                num += 1
            used_numbers.add(num)
            stats = generate(pos, target, rnd)
            players.append({
                'id': pid, 'name': name, 'shortName': short, 'age': age, 'nationality': nat,
                'countryFlag': flag, 'number': num, 'mainPosition': pos, 'altPositions': alt,
                'preferredFoot': foot, 'weakFoot': rnd.choice([2, 3, 3, 4]), 'stats': stats,
                'contract': {'contractYears': rnd.choice([2, 3, 4]), 'weeklyWage': wage, 'releaseClause': 0},
                'marketValue': value(target, age),
            })
            existing.add(pid)
            club['squadIds'].append(pid)
            added.append(pid)
        # Matchday bench of nine: the original five plus the best four new.
        if len(club['benchIds']) < 9:
            for pid in added[:9 - len(club['benchIds'])]:
                club['benchIds'].append(pid)
        meta = CLUB_META[club['id']]
        for k in ('city', 'nickname', 'founded', 'reputation'):
            club[k] = meta[k]
        club['crest'] = meta['crest']
        wages = sum(p['contract']['weeklyWage'] for p in players if p['id'] in club['squadIds'])
        club['wageBudget'] = max(club['wageBudget'], int(wages * 1.18 / 100000) * 100000)
        club['ticketPrice'] = 35 + meta['reputation'] // 2
    (DATA / 'players.json').write_text(json.dumps(players_doc, ensure_ascii=False, indent=2) + '\n',
                                       encoding='utf8')
    (DATA / 'clubs.json').write_text(json.dumps(clubs_doc, ensure_ascii=False, indent=2) + '\n',
                                     encoding='utf8')
    templates = {'slots': [
        {'pos': 'GK', 'ovr': 76, 'num': 1}, {'pos': 'LB', 'ovr': 75, 'num': 3}, {'pos': 'CB', 'ovr': 78, 'num': 4},
        {'pos': 'CB', 'ovr': 76, 'num': 5}, {'pos': 'RB', 'ovr': 75, 'num': 2}, {'pos': 'DMF', 'ovr': 78, 'num': 6},
        {'pos': 'CMF', 'ovr': 79, 'num': 8}, {'pos': 'AMF', 'ovr': 80, 'num': 10}, {'pos': 'LWF', 'ovr': 77, 'num': 11},
        {'pos': 'CF', 'ovr': 82, 'num': 9}, {'pos': 'RWF', 'ovr': 81, 'num': 7},
        {'pos': 'GK', 'ovr': 71, 'num': 12}, {'pos': 'CB', 'ovr': 73, 'num': 15}, {'pos': 'CMF', 'ovr': 74, 'num': 14},
        {'pos': 'ST', 'ovr': 74, 'num': 19}, {'pos': 'LB', 'ovr': 70, 'num': 17}, {'pos': 'RWF', 'ovr': 72, 'num': 20},
        {'pos': 'CB', 'ovr': 70, 'num': 23}, {'pos': 'RB', 'ovr': 69, 'num': 22}, {'pos': 'DMF', 'ovr': 71, 'num': 16},
        {'pos': 'AMF', 'ovr': 70, 'num': 18}, {'pos': 'LWF', 'ovr': 69, 'num': 21}, {'pos': 'GK', 'ovr': 64, 'num': 31},
    ]}
    (DATA / 'squad_templates.json').write_text(json.dumps(templates, indent=2) + '\n', encoding='utf8')
    print('players', len(players))


if __name__ == '__main__':
    main()
