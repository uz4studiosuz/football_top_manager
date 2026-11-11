# Manager workspace and broadcast match — 1.5.0

The interface remains Flutter. No 3D runtime or external service is required.

## Broadcast match overhaul

The supplied match clip reads 47:42 at its first frame and 48:08 at 19 seconds.
Playback therefore uses a measured base rate of 26/19 match seconds per real
second. The user-facing controls contain exactly **1x, 5x and 10x**.

User matches and their quick-result path use physical mode. Simulation runs at
20 fixed ticks per game second; rendering interpolates positions, headings and
ball height. A different render frame rate produces the same seeded simulation.
Movement uses pitch metres, not unequal normalized x/y speeds. Acceleration,
turning inertia and short-lived directional feints replace instant changes.
The marker's white pointer displays the player's facing; passes and shots wait
for the body to turn. Deflections remain loose balls until a reachable player
collects them. A receiver must physically reach a pass for it to count.

The initial position and halftime restart use kickoff positions, not attacking
formation positions. Both teams begin in their own half; the defending team
stands outside the 9.15 m circle. Natural restarts wait for the taker instead of
teleporting him after a timeout. Distance statistics use actual travelled metres.

The stadium is a cached local drawing: checker-cut grass, a roof shadow,
seating, concourse, advertising strips, nets and officials. The broadcast camera
follows the ball smoothly; the camera control switches to a whole-pitch view.
Tap detection shares the same coordinate transform. Keepers have distinct kits,
the scoreboard uses MM:SS, and an interactive player/condition strip sits below
the pitch. The ball is smaller than player markers and its shadow tracks loft.

Background divisions retain the compressed simulation for career performance.
The natural calibration report is in `artifacts/qa/natural-calibration.txt`.
`test/match_broadcast_test.dart` covers kickoff laws for every formation,
reference timing, physical movement bounds, pass collection, camera hit testing
and independence from rendering rate.

## References reviewed

The three supplied MP4 files were sampled throughout their duration, with the
portrait recordings rotated for inspection. The references show a weekly
training calendar, tactical complexity and understanding, a formation with a
player table, a top-down 2D match, match commentary, and post-match information.
The two supplied stills show a touchline instruction menu and grouped player
attributes. Frame sheets are in `artifacts/reference/`.

This release adapts those patterns to the existing game's data and rules.
It does not invent unavailable mental attributes or convert the game to a
different football database. The attribute scale switch is display-only:
1–20 is the original value divided by five and rounded. The underlying
26 attributes and simulation keep their existing values.

## Interface

- Dark manager palette by default; an explicitly saved appearance is retained.
- Desktop sidebar at 1200px; compact rail at 760px; bottom navigation below.
  The navigation scrolls in short landscape windows.
- Wider desktop workspace; formation and editable starting-player roles
  alongside tactical readiness. Phone formation and bench remain touch/draggable.
- Player attributes use three groups plus a goalkeeper panel, alternating rows,
  a 1–20 / 1–100 switch, and an expandable radar.
- Squad search and dense desktop player table; mobile player cards remain.
- Larger match field, mowing pattern, live commentary ribbon, and a bounded
  touchline sheet with Team and Individual instructions.

## Simulation and training

`TrainingSchedule` is a repeating Monday–Sunday plan with three sessions a day.
The next five weeks can be previewed. Editing a weekday changes its recurring
session. A fixture replaces all training on that date; the following morning
is reserved for recovery. League, cup and super-cup dates are considered.

Intensity changes workload and development. Load reduces the normal fitness
recovery between fixtures. Rest gives no development, recovery limits fatigue,
and the scheduled drill mix weights which eligible attributes develop.
Existing individual targets and per-line training selections still apply.
The elapsed number of days scales development, avoiding a full week's gains
between two closely spaced fixtures.

Understanding is stored for each formation/playstyle combination, grows through
practice, and slowly decays for unused combinations. Tactical readiness combines
understanding, actual player attributes, existing player bonds, and instruction
complexity. Its match effect is deliberately bounded to −3…+3 coaching points.
These are game-model indicators, not measurements imported from real football.

Touchline orders compose against the match's base tactics. Contradictory orders
replace one another, and a reset restores the base. The regular career tactics
and player instructions return after leaving a match. Orders affect existing
width, buildup, tempo, block, pressing and stamina rules. Added mechanics:

- Harder tackling raises foul and booking probabilities.
- Low pressing limits how far the nearest defender leaves the block.
- Quick passing under pressure and fatigue can reduce accuracy.
- Swap wings mirrors wide attackers' positions without changing player IDs.
- When trailing from minute 85, the optional goalkeeper order sends the keeper
  into attacking corners; he can receive the cross and must run back normally.

Training, familiarity and new tactical fields are saved. Old saves receive
defaults. The training snapshot copies its maps so an in-memory restore cannot
erase the save it is reading.

## Verification

`test/manager_refresh_test.dart` exercises conflict resolution, save compatibility,
actual career progression, fixture/recovery overrides, and stamina differences
in played matches. It renders the main screens at 390×844 and 1440×960 and checks
320×640, 768×1024 and 844×390 with 120% text scaling. Captures are stored under
`artifacts/qa/manager-*.png`.

The goal-flight invariant is evaluated across five seeded matches: a valid 0–0
must not make the test fail, while every actual goal must still cross the goal
line and match the recorded events and shots.

Run `flutter analyze`, `flutter test`, and `flutter test tool/calibrate_test.dart`.
For web: `flutter build web --no-web-resources-cdn`.

Release validation: the full suite passed 110 tests; after final movement and
rendering refinements the relevant suites passed another 51 tests. Static
analysis reported no issues and the release web build succeeded. A separate
headless Chrome profile loads a synthetic QA career; browser screenshots and
runtime results live under `artifacts/qa/browser-*`. It never modifies the
user's browser save. The 8-second local demo is under
`artifacts/releases/football-top-manager-1.5.0-demo.mp4`.
