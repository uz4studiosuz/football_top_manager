"""Look-alike portrait hints for Premier League players (by full name).

Values follow FaceConfig: skin 0 (fair) – 9 (very dark); hair 0 black,
1 dark brown, 2 brown, 3 blonde, 4 grey, 5 auburn; cut 0 crop, 1 side part,
2 quiff, 3 curly top, 4 buzz, 5 bald, 6 waves, 7 afro, 8 long, 9 bun,
10 dreads, 11 mohawk, 12 slick back, 13 messy fringe, 14 heavy fringe,
15 fade; beard 0 none, 1 stubble, 2 short, 3 full, 4 goatee, 5 moustache,
6 chinstrap, 7 long. Extra keys (shape, eyes, brow, nose, mouth,
eyeColor) refine the few players described in detail.

    python -I tool/epl_faces.py     # patches assets/data/players_epl.json
"""
import json
from pathlib import Path

PLAYERS = Path(__file__).resolve().parent.parent / 'assets' / 'data' / 'players_epl.json'

# name: (skin, hair, cut, beard)
FACES = {
    'Erling Haaland': (0, 3, 9, 0), 'Virgil van Dijk': (6, 0, 15, 2), 'William Saliba': (9, 0, 4, 2),
    'Rodri': (2, 1, 1, 2), 'Mohamed Salah': (5, 0, 7, 3), 'Florian Wirtz': (1, 2, 0, 0),
    'Declan Rice': (1, 1, 0, 1), 'Cole Palmer': (1, 5, 15, 0), 'Bukayo Saka': (8, 0, 4, 0),
    'Alexander Isak': (7, 0, 15, 1), 'Rúben Dias': (2, 0, 1, 3), 'Martin Ødegaard': (1, 2, 1, 1),
    'Gianluigi Donnarumma': (2, 0, 0, 2), 'Gabriel Magalhães': (6, 0, 4, 3), 'Alisson Becker': (2, 1, 1, 3),
    'Viktor Gyökeres': (2, 1, 12, 2), 'Ryan Gravenberch': (8, 0, 3, 0), 'Moisés Caicedo': (6, 0, 15, 1),
    'Joško Gvardiol': (1, 1, 0, 1), 'Bruno Fernandes': (2, 1, 1, 2), 'Tijjani Reijnders': (4, 0, 3, 2),
    'Phil Foden': (1, 1, 4, 1), 'Martin Zubimendi': (2, 0, 13, 0), 'Emiliano Martínez': (2, 0, 15, 2),
    'David Raya': (2, 0, 0, 2), 'Bruno Guimarães': (4, 0, 15, 3), 'Alexis Mac Allister': (2, 1, 3, 1),
    'Xavi Simons': (5, 0, 3, 0), 'Mikel Merino': (2, 1, 1, 2), 'Marc-Israel Guehi': (8, 0, 4, 0),
    'Marc Guéhi': (8, 0, 4, 0), 'Ibrahima Konaté': (9, 0, 4, 1), 'Hugo Ekitiké': (8, 0, 3, 0),
    'Enzo Fernández': (2, 0, 12, 1), 'Eberechi Eze': (8, 0, 4, 1), 'Dominik Szoboszlai': (1, 3, 12, 0),
    'Cristian Romero': (3, 0, 15, 2), 'Bernardo Silva': (2, 1, 13, 3), 'Youri Tielemans': (2, 1, 0, 2),
    'Sandro Tonali': (2, 1, 8, 1), 'Reece James': (7, 0, 4, 2), 'Omar Marmoush': (4, 0, 3, 2),
    'Ollie Watkins': (7, 0, 4, 2), 'Micky van de Ven': (1, 3, 0, 0), 'Matheus Cunha': (5, 0, 15, 1),
    'Jérémy Doku': (9, 0, 4, 0), 'Jurriën Timber': (7, 0, 6, 0), 'João Pedro': (6, 0, 15, 0),
    'Bryan Mbeumo': (8, 0, 4, 2), 'Boubacar Kamara': (7, 0, 4, 2), 'Rayan Cherki': (5, 0, 3, 0),
    'Piero Hincapié': (6, 0, 15, 0), 'Pedro Porro': (2, 0, 0, 2), 'Pedro Neto': (3, 0, 15, 1),
    'Pau Torres': (2, 1, 1, 1), 'Morgan Rogers': (6, 0, 3, 0), 'Morgan Gibbs-White': (1, 1, 1, 1),
    'Mohammed Kudus': (8, 0, 15, 2), 'Matthijs de Ligt': (0, 3, 0, 0), 'João Palhinha': (2, 0, 0, 3),
    'Jordan Pickford': (1, 1, 15, 1), 'Jeremie Frimpong': (8, 0, 3, 0), 'Jarrod Bowen': (1, 1, 12, 2),
    'Guglielmo Vicario': (2, 1, 1, 2), 'Elliot Anderson': (1, 1, 0, 0), 'Cody Gakpo': (7, 0, 15, 0),
    'Antoine Semenyo': (8, 0, 4, 1), 'Anthony Gordon': (1, 1, 15, 0), 'Sven Botman': (1, 2, 1, 2),
    'Riccardo Calafiori': (1, 1, 8, 3), 'Rayan Aït-Nouri': (5, 0, 3, 1), 'Nikola Milenković': (1, 1, 0, 2),
    'Nick Woltemade': (1, 2, 1, 0), 'Nick Pope': (1, 1, 0, 1), 'Marc Cucurella': (2, 1, 8, 0),
    'Lisandro Martínez': (3, 0, 9, 3), 'Levi Colwill': (1, 1, 0, 0), 'Kai Havertz': (1, 2, 13, 1),
    'John Stones': (1, 1, 1, 1), 'Gabriel Martinelli': (3, 1, 3, 0), 'Ezri Konsa': (8, 0, 4, 1),
    'Carlos Baleba': (9, 0, 4, 0), 'Bernd Leno': (1, 2, 1, 2), 'Ben White': (1, 2, 0, 3),
    'Amadou Onana': (8, 0, 4, 1),
}

# Players described in more detail (full portrait).
DETAILED = {
    # Young Uzbek centre-back: thick straight black fringe, no beard,
    # almond brown eyes, strong straight brows, oval face.
    'Abdukodir Khusanov': dict(skin=2, hair=0, cut=14, beardStyle=0, shape=0, eyes=4, eyeColor=0,
                               brow=2, nose=1, mouth=0, age=0),
}


def apply(players):
    hit = 0
    for p in players:
        face = None
        if p['name'] in DETAILED:
            face = dict(DETAILED[p['name']])
        elif p['name'] in FACES:
            skin, hair, cut, beard = FACES[p['name']]
            face = dict(skin=skin, hair=hair, cut=cut, beardStyle=beard)
        if face:
            p['face'] = face
            hit += 1
    return hit


def main():
    doc = json.loads(PLAYERS.read_text(encoding='utf8'))
    hit = apply(doc['players'])
    PLAYERS.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
    missing = sorted(set(FACES) | set(DETAILED) - {p['name'] for p in doc['players']})
    missing = [n for n in missing if n not in {p['name'] for p in doc['players']}]
    print('faces applied:', hit, 'missing names:', missing)


if __name__ == '__main__':
    main()
