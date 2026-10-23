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

- Four-step onboarding: identity, custom portrait, preferred philosophy, club.
- Possession Game, Quick Counter, Long Ball Counter, Out Wide and Long Ball
  proficiency all begin at **70**. Every five managed fixtures develops the
  currently used philosophy by one point, up to 100.
- Parametric faces include skin, jaw/face, eyes, nose, lips, eyebrows, hair cut
  and colour, beard, age lines, freckles and glasses. The same editor serves
  managers and players.
- New clubs receive randomly combined, unique player names from locale pools.
  Club crests support both manual choices and random generation.
- Squad, tactics, league, transfers and finance are separate pages. Mouse drag
  and touch long-press drag swap players; edges scroll during a drag. Tapping a
  player opens profile, individual instructions and substitution choices.
- Individual roles: balanced, stay back, make runs, hold width and playmaker.
- Profiles group all 26 requested attributes, show radar/strength bars, and place
  all 14 positional OVR ratings on a football pitch. GK OVR uses five actual GK
  attributes rather than outfield proxies.
- Scouting compares both teams on identical 0–100 scales, with actual numeric
  differences, fitness, formation, squad depth, danger player and recent results.

## Simulation

At 1x, one real second equals one match minute. Half-time pauses the match;
2x/5x and instant result use the same engine. The pitch is authoritative:
carriers advance into space, choose passes by progression/safety/style, and
receive pressure or interceptions. Completed shot flights produce goals, saves,
blocks and misses; a goal is written only when the ball reaches the goal line.
After a goal the conceding side restarts from the centre.

Geometry, canonical attributes, team tactics, individual instructions, manager
proficiency and fatigue influence decisions. Wide play/lofted crosses can lead
to headers; passing accounts for offside, and free kicks/corners use set-piece
attributes. AI fixtures run the same engine. Goals, assists, xG, passes,
on-target shots, fouls and cards come from its events rather than a separate
random scoreboard. Live substitution guards enforce five changes and no re-entry.

## Data

The bundled data is a fictional career seed, not a live real-world roster.

| Asset | Contents |
| --- | --- |
| `assets/data/league.json` | Versioned manifest and league metadata |
| `assets/data/clubs.json` | Clubs, budgets, crests, tactics and squad IDs |
| `assets/data/players.json` | Player identity, contracts and 26 attributes |
| `assets/data/names.json` | Locale-specific first/last name pools |
| `assets/data/squad_templates.json` | Generated squad positions and target levels |

Startup joins by IDs, validates lineups/ownership, and gives each new career
independent objects. Attributes are bounded to **40–100**. Runtime career
progress and edited faces currently remain in memory.

## Transfers and finance

The compact league's transfer windows are rounds 1–3 and 8–9. A seller retains
at least 14 players and one keeper; a buyer stays within 25 registrations,
transfer funds and weekly wage limits. Agent cost is 3% of the fee, signing bonus
four offered weekly wages, and purchases sign three-year contracts. AI clubs
trade with their own funds. Transfers preserve a single owner and replenish a
seller's starting XI. These are explicit game rules for this fictional league.

All clubs receive sponsorship and pay wages/operating costs each round. Home
clubs receive gate income and pay stadium costs. Finance and transfer history
are inspectable, and applying a match result twice cannot duplicate payments.

## Verification

`flutter test` covers attribute schema/ranges, goalkeeper OVR, generated names,
manager levels, drag on desktop and touch, menus, narrow layouts, ownership,
contract renewal, transfer accounting, match clock, physical goal completion and
a full 14-round season.

`flutter test tool/capture_ui_test.dart` additionally captures the key pages and
onboarding steps to `artifacts/qa`. Set `FLUTTER_ROOT` to the SDK for QA fonts.

With Python Playwright and Chrome installed, `python tool/web_smoke.py` runs the
served web release with external requests blocked: onboarding, club selection,
real-time 1x clock, match, next round and mobile viewport. Set `CHROME_BINARY` if
Chrome is installed elsewhere. Its screenshots/report are in `artifacts/qa`.
