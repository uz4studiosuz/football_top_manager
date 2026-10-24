# Football Top Manager

A Flutter football management game with an eight-club, 14-round career.

## Run

```sh
flutter pub get
flutter run -d chrome
flutter analyze
flutter test
flutter build web --no-web-resources-cdn
```

Serve `build/web` over HTTP. For example:

```sh
python -m http.server 8787 --bind 127.0.0.1 --directory build/web
```

The release includes Roboto fonts and local CanvasKit resources. The app's
production Dart code has no filesystem/browser-only imports. Canvas UI, menus,
responsive navigation and touch/mouse interactions share the same Flutter code.

## Career and UI

- SofaScore-inspired clean design system (`lib/ui/app_theme.dart`,
  `lib/ui/widgets.dart`): white cards, rating pills (SofaScore scale), stat
  colours 90+ sky blue / 80–89 green / 70–79 amber / ≤69 red.
- Navigation: Boshqaruv · Jamoa (pitch, list, team tactics, instructions) ·
  Jadval · Transfer · Moliya (finance, real-date calendar, inbox, club profile).
- Leagues: Super League (8 clubs, 14 rounds) and the English pyramid –
  Premier League 2025/26 (20 clubs, 38 rounds), Championship and League One
  (24 clubs, 46 rounds each, squads and coaches from 2026.db) – with
  look-alike vector crests and portraits.
- The whole pyramid plays every season: the other divisions are simulated
  in the background (viewable tables), 3 go down, the top 2 plus the
  play-off winner (3rd–6th, two-legged semis and a final) go up. Relegated
  top-flight clubs get parachute money; TV money, sponsorship, prizes and
  running costs scale with the division. The transfer market covers every
  division with a league filter.
- Player and Manager of the Month awards.
- 16 formations; auto line-up solves the best XI with the Hungarian algorithm
  so players stay in their own positions. Tapping a player shows his fitting
  positions; dragging previews his OVR and fit at every slot.
- Pop-up banners and a dashboard inbox for offers, injuries, OVR growth,
  contracts and transfer windows.
- Every player has an eFootball playing style (PlayerPlayingStyles.md),
  a defending style and AI styles; all of them change match behaviour.
- New clubs get an average squad (≈64–73) plus one star chosen from three.
- Careers auto-save with shared_preferences (localStorage on the web);
  Profile → "Chiqish va saqlanganni tozalash" wipes the save.

## Languages

Uzbek, English and Russian. The language is chosen on first launch and can
be changed any time in the manager profile (or with the globe button during
onboarding). UI strings are written in Uzbek and wrapped in `tr()` /
`trf('{0}-tur', [round])`; translations live in `assets/l10n/en.json` and
`ru.json` (built from `tool/l10n_src` with `python -I tool/l10n_src/build.py`).
Match commentary has its own English/Russian banks. `test/l10n_test.dart`
fails when a key has no translation; `python -I tool/i18n_keys.py missing en`
lists them.

## Database

See [docs/DATABASE.md](docs/DATABASE.md): DB Studio (`tool/db_studio`) edits
leagues, clubs and players visually; `tool/validate_data.py` checks the data.

## Simulation

`lib/services/match_field.dart` drives a 2D pitch where action time runs at
`MatchField.tempo` relative to the clock. Calibrated averages per match
(`flutter test tool/calibrate_test.dart`): ~3.0 goals, xG ~2.6, ~24 shots,
~8 on target, ~830 passes at 84%, ~9 corners, ~21 fouls, ~3.6 yellows,
~3 offsides, home win ≈45% / draw ≈26%. Keepers cannot be tackled with the
ball and defenders avoid risky lanes in their own third, so goals come from
build-up rather than gifts.

Players earn live SofaScore-style ratings weighted by role, including errors
leading to a shot/goal, penalties won/conceded/saved, big chances created,
times dribbled past and cards. Every shot records body part, situation,
assist origin, goal-frame point and xGOT: tap a goal incident for the
SofaScore-like goal sheet, or a dot on the shot map. Fixtures store
momentum, shots (user matches), player lines and man of the match.

Real rules: added time, 5 substitutions in 3 in-play windows (half-time
free), yellow accumulation and red-card bans, injuries, offsides, penalties,
free kicks that mirror fouls + offsides, corners with players taking
realistic positions (box crowded, near-post marker, wall at free kicks).
Team tactics (build-up, attacking area, defensive approach, containment,
compactness, pressing, offside trap, time wasting), individual instructions
(Anchoring, Offensive, Defensive, Man/Tight Marking, Deep Line, Counter
Target) and set-piece takers/captain all feed the engine, as does the
manager's proficiency in the chosen playstyle.

## Progression and economy

- Manager proficiency grows with experience (matches, wins, clean sheets,
  season finish); players develop during the season from match ratings and
  at season end by age/potential.
- Real dates (Aug–May), summer/winter transfer windows, negotiation with
  counter-offers, AI bids for your players, free agents (signable any time),
  weekly wages, ticket pricing, prize money, board objective and confidence.
- The fixture draw, match outcomes and AI deals are random per career.

## Data

| Asset | Contents |
| --- | --- |
| `assets/data/clubs.json` | Clubs, budgets, crests, tactics and squad IDs |
| `assets/data/players.json` | Players, 26 attributes, look-alike face hints, playing styles |
| `assets/data/clubs_epl.json`, `players_epl.json` | Premier League 2025/26 (`tool/epl_data.py`) |
| `assets/data/clubs_ch.json`, `clubs_l1.json` (+ players) | Championship and League One (`tool/efl_data.py`) |
| `assets/data/names.json` | Locale name pools for generated players |
| `assets/data/squad_templates.json` | 23-slot template for new clubs |

Generators: `tool/expand_squads.py`, `tool/star_faces.py`, `tool/epl_faces.py`,
`tool/playing_styles.py`.

## Verification

`flutter test` (42 tests: rules, engine, ratings, save/restore, corners,
free kicks, widgets). `flutter test tool/capture_ui_test.dart` writes
screenshots to `artifacts/qa`.
