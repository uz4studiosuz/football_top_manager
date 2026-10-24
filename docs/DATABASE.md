# FTM27 database guide

All game data lives in `assets/data` as plain JSON. The game reads it once at
start-up (`lib/data/initial_database.dart`), joins clubs to players by id and
refuses data that breaks the rules below.

## Tools

| Tool | What it does |
| --- | --- |
| `tool/db_studio/index.html` | Visual editor for leagues, clubs, players, attributes, crests, portraits; validation; CSV import/export |
| `tool/validate_data.py` | Command-line check, same rules as the game (exit code 1 on errors) |
| `tool/efl_data.py`, `tool/epl_data.py` | Generators that build leagues from `2026.db` |
| `tool/epl_faces.py`, `tool/star_faces.py` | Look-alike portrait hints |

### DB Studio

* **Chrome / Edge:** open `tool/db_studio/index.html`, press
  **"assets/data papkasini ochish"**, pick the `assets/data` folder. Edits are
  written straight back with **Saqlash**.
* **Any browser:** serve the repository and use **"Loyihadan yuklash"**:

  ```
  python -m http.server 8792
  ```

  then open `http://localhost:8792/tool/db_studio/index.html`. Changed files
  are downloaded; copy them into `assets/data`.
* **Spreadsheets:** *CSV eksport* writes one row per player (club, bio,
  contract, all 26 attributes). Edit in Excel/Google Sheets, then *CSV import*:
  rows update players by `id`, new ids become new players, the `club` column
  moves players. Press **Avto tarkib** afterwards and run **Tekshirish**.

Typical workflow: edit → **Tekshirish** (0 errors) → **Saqlash** →
`python -I tool/validate_data.py` → `flutter run`.

## Files

### `league.json` (manifest)

```json
{
  "schemaVersion": 2,
  "templatesFile": "squad_templates.json",
  "namesFile": "names.json",
  "leagues": [
    {"id": "epl", "name": "Premier League", "country": "Angliya",
     "clubsFile": "clubs_epl.json", "playersFile": "players_epl.json",
     "pyramid": "eng", "tier": 1, "relegate": 3, "economy": 1.0},
    {"id": "ch", "name": "Championship", "country": "Angliya",
     "clubsFile": "clubs_ch.json", "playersFile": "players_ch.json",
     "pyramid": "eng", "tier": 2, "promote": 2, "playoff": [3, 6], "relegate": 3, "economy": 0.2}
  ]
}
```

* Leagues with the same `pyramid` exchange clubs every summer. The number
  going down from tier N must equal `promote` + play-off winner of tier N+1.
* `economy` scales TV money, sponsorship, prizes and running costs (1 = top
  flight).
* Club count must be even; rounds = (clubs − 1) × 2.

### `clubs_*.json`

```json
{"schemaVersion": 2, "clubs": [{
  "id": "uz_pakhtakor", "name": "Pakhtakor", "shortName": "PAK",
  "primaryColor": 4278222848, "secondaryColor": 4294967295, "accentColor": 4293443690,
  "stadiumName": "Pakhtakor Markaziy", "stadiumCapacity": 35000,
  "city": "Toshkent", "nickname": "Paxtakorlar", "founded": 1956, "reputation": 62,
  "transferBudget": 8000000, "wageBudget": 400000, "ticketPrice": 25,
  "tactics": {"formation": "f4231", "playstyle": "possession", "defensiveLine": 3, "attackingIntensity": 3},
  "crest": {"shape": "shield", "pattern": "verticalStripes", "primaryColor": 4278222848,
            "secondaryColor": 4294967295, "trimColor": 4293443690, "monogram": "PFC",
            "stars": 0, "crown": false, "emblem": "ball"},
  "managerName": "Maksim Shatskikh",
  "squadIds": ["uz_pakhtakor_..."], "startingLineupIds": ["... 11 ids ..."], "benchIds": ["... up to 9 ..."]
}]}
```

* Colours are ARGB integers (`0xFF` + RGB hex, e.g. `#0055A5` → `0xFF0055A5`
  = 4278212005). DB Studio converts them for you.
* `startingLineupIds` follows the formation's slot order (GK first). Leagues
  other than the Super League are re-picked automatically when a career
  starts, so an approximate XI is fine.
* Enums — formation: `f433 f4231 f442 f352 f532 f4141 f343 f41212 f433d f4222
  f4411 f451 f3412 f3421 f541 f4321`; playstyle: `outWide longBallCounter
  possession quickCounter highPressing longBall overload`; crest shape:
  `shield modernShield circle oval roundel pointed heater badge`; pattern:
  `solid verticalStripes pinstripes hoops diagonalSash halves quarters lozenges
  chevron rings splitCross`; emblem: `monogram ball star cannon bird ship tower
  lion trident tree hammers wolf`.

### `players_*.json`

```json
{"schemaVersion": 2, "players": [{
  "id": "uz_pakhtakor_jsharipov", "name": "Jaloliddin Sharipov", "shortName": "J. Sharipov",
  "age": 24, "nationality": "O‘zbekiston", "countryFlag": "🇺🇿", "number": 10,
  "mainPosition": "AMF", "altPositions": ["CMF"], "preferredFoot": "left", "weakFoot": 3,
  "stats": {"attackingAwareness": 74, "...": "all 26 keys, 40-99"},
  "contract": {"contractYears": 3, "weeklyWage": 12000, "releaseClause": 0},
  "marketValue": 3500000, "potential": 78,
  "playingStyle": "creativePlaymaker", "height": 178, "traits": ["Paslar"],
  "face": {"skin": 2, "hair": 0, "cut": 14, "beardStyle": 0}
}]}
```

* Positions: `GK CB LB RB DMF CMF AMF LMF RMF LWF RWF SS CF`.
* OVR is not stored: the game computes it from `stats` with position
  weights (DB Studio shows the same number and can regenerate attributes for
  a target OVR).
* `face` is optional and partial: missing keys are generated from id,
  nationality and age. Keys: skin 0–9, hair 0–8, cut 0–15, beardStyle 0–7,
  shape 0–4, eyes 0–4, eyeColor 0–4, brow 0–3, nose 0–3, mouth 0–3.
* Playing styles: see `lib/models/playing_style.dart` (e.g. `goalPoacher`,
  `boxToBox`, `buildUp`, `defensiveGoalkeeper`).

## Rules the game enforces

Errors (the game refuses to load the data): duplicate ids, a player listed
by two clubs, a squad id without a player, XI not exactly 11 different squad
players, bench outside the squad or overlapping the XI, unknown
formation/playstyle, missing crest. An odd club count also counts as an
error because the fixture generator needs an even number.

Warnings (loads, but play suffers): squads outside 18–28, fewer than two
goalkeepers, attributes outside 40–100, players without a club.
