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
- Eight clubs with 23-man squads, look-alike vector crests (crowned roundel,
  ringed badges, pointed shield, heater shields) and look-alike portraits.
- Every player has an eFootball playing style (PlayerPlayingStyles.md),
  a defending style and AI styles; all of them change match behaviour.
- New clubs get an average squad (≈64–73) plus one star chosen from three.
- Careers auto-save with shared_preferences (localStorage on the web);
  Profile → "Chiqish va saqlanganni tozalash" wipes the save.

## Simulation

`lib/services/match_field.dart` drives a 2D pitch where action time runs at
`MatchField.tempo` relative to the clock. Calibrated averages per match
(`flutter test tool/calibrate_test.dart`): ~2.8 goals, ~23 shots, ~8 on
target, ~830 passes at 84%, ~9 corners, ~24 fouls, ~4 yellows, ~3 offsides,
home win ≈45% / draw ≈24%. Players earn live SofaScore-style ratings;
fixtures store momentum, shot maps, player lines and man of the match.

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
| `assets/data/names.json` | Locale name pools for generated players |
| `assets/data/squad_templates.json` | 23-slot template for new clubs |

Generators: `tool/expand_squads.py`, `tool/star_faces.py`,
`tool/playing_styles.py`.

## Verification

`flutter test` (33 tests: rules, engine, ratings, save/restore, corners,
free kicks, widgets). `flutter test tool/capture_ui_test.dart` writes
screenshots to `artifacts/qa`.
