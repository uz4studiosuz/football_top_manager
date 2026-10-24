"""One-off patch: league cards and club grid on the selection screens."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent


def patch(rel, pairs):
    p = ROOT / rel
    s = p.read_text(encoding='utf8')
    for a, b in pairs:
        assert s.count(a) == 1, (rel, s.count(a), a[:80])
        s = s.replace(a, b, 1)
    p.write_text(s, encoding='utf8')


patch('lib/ui/league_picker.dart', [
    ("import 'app_theme.dart';\nimport 'team_widgets.dart';",
     "import '../models/crest.dart';\nimport 'app_theme.dart';\nimport 'widgets.dart';"),
])

p = ROOT / 'lib/screens/club_selection_screen.dart'
s = p.read_text(encoding='utf8')
a = s.index("          PillTabs(\n            labels: [\n              for (final l in InitialDatabase.leagues)")
b = s.index("          const SizedBox(height: 12),\n          AppCard(\n            child: Column(\n              children: [\n                ClubCrestWidget(config: club.crestConfig, size: 104),")
s = s[:a] + '''          SectionHeader(tr('Liga'), icon: Icons.emoji_events_outlined),
          LeaguePicker(selected: _league, onChanged: _switchLeague),
          const SizedBox(height: 16),
          SectionHeader(trf('Klublar ({0})', [_clubs.length]), icon: Icons.shield_outlined),
          LayoutBuilder(
            builder: (context, box) {
              final perRow = (box.maxWidth / 112).floor().clamp(3, 8);
              final tiles = <Widget>[
                for (var i = 0; i < _clubs.length; i++)
                  _clubChip(
                    selected: i == _selected,
                    onTap: () => setState(() => _selected = i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClubCrestWidget(config: _clubs[i].crestConfig, size: 40),
                        const SizedBox(height: 6),
                        Text(_clubs[i].shortName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        ValueBadge(_clubs[i].teamOVR, size: 22),
                      ],
                    ),
                  ),
                _clubChip(
                  selected: false,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => CustomClubCreatorScreen(managerProfile: widget.managerProfile, league: _league),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_circle_outline_rounded, size: 34, color: AppColors.primary),
                      const SizedBox(height: 6),
                      Text(
                        tr('Yangi klub'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ];
              return GridView.count(
                crossAxisCount: perRow,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.82,
                children: tiles,
              );
            },
          ),
''' + s[b:]
s = s.replace('''          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () => _start(club),
              icon: const Icon(Icons.play_arrow_rounded),
              label: FittedBox(child: Text(trf('{0}NI BOSHQARISH', [club.name.toUpperCase()]))),
            ),
          ),
        ],
      ),
    );''', '''        ],
      ),
      // Always reachable, however long the club list is.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () => _start(club),
              icon: const Icon(Icons.play_arrow_rounded),
              label: FittedBox(child: Text(trf('{0}NI BOSHQARISH', [club.name.toUpperCase()]))),
            ),
          ),
        ),
      ),
    );''', 1)
s = s.replace("""  Widget _clubChip({required bool selected, required VoidCallback onTap, required Widget child}) => SizedBox(
    width: 92,
    child: Material(""", """  Widget _clubChip({required bool selected, required VoidCallback onTap, required Widget child}) => SizedBox(
    child: Material(""", 1)
s = s.replace("""    _clubs = InitialDatabase.getClubs(id)..sort((a, b) => b.reputation.compareTo(a.reputation));
    // Big-league seed files list squads only; show each club's real best XI.
    if (id != 'super') {
      for (final c in _clubs) {
        GameState().autoPickLineup(c);
      }
    }""", """    _clubs = _load(id);""", 1)
s = s.replace("""  late List<Club> _clubs = InitialDatabase.getClubs(_league);""", """  late List<Club> _clubs = _load(_league);

  /// Clubs strongest first, with each club's real best XI picked.
  static List<Club> _load(String id) {
    final clubs = InitialDatabase.getClubs(id);
    for (final c in clubs) {
      GameState().autoPickLineup(c);
    }
    return clubs..sort((a, b) => b.teamOVR.compareTo(a.teamOVR));
  }""", 1)
s = s.replace("import '../ui/team_widgets.dart';", "import '../ui/team_widgets.dart';\nimport '../ui/league_picker.dart';", 1)
p.write_text(s, encoding='utf8')

# Custom club creator: same league cards.
p = ROOT / 'lib/screens/custom_club_creator_screen.dart'
s = p.read_text(encoding='utf8')
a = s.index("          for (final l in InitialDatabase.leagues)\n            Padding(")
b = s.index("          Text(\n            trf('Klubingiz {0} o‘rnini egallaydi · {1} tur.'")
s = s[:a] + "          LeaguePicker(selected: _league, onChanged: (id) => setState(() => _league = id)),\n          const SizedBox(height: 10),\n" + s[b:]
s = s.replace("import '../l10n/l10n.dart';", "import '../l10n/l10n.dart';\nimport '../ui/league_picker.dart';", 1)
p.write_text(s, encoding='utf8')
print('ok')
