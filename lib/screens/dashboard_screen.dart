import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/league.dart';
import '../services/game_state.dart';
import '../ui/face_avatar.dart';
import 'manager_profile_screen.dart';
import 'match_screen.dart';
import 'widgets/opponent_squad_sheet.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onNavigateToTactics;
  final VoidCallback? onNavigateToSquad, onNavigateToFinance;
  const DashboardScreen({
    super.key,
    required this.onNavigateToTactics,
    this.onNavigateToSquad,
    this.onNavigateToFinance,
  });
  static const ink = Color(0xFF192B42),
      muted = Color(0xFF637184),
      blue = Color(0xFF1769E0);
  @override
  Widget build(BuildContext context) {
    final game = GameState();
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final club = game.userClub, manager = game.managerProfile;
        final next = game.nextUserFixture;
        final standing = game.sortedStandings.firstWhere(
              (s) => s.clubId == club.id,
            ),
            rank =
                game.sortedStandings.indexWhere((s) => s.clubId == club.id) + 1;
        final upcoming = game.fixtures
            .where(
              (f) =>
                  !f.isPlayed &&
                  (f.homeClubId == club.id || f.awayClubId == club.id),
            )
            .take(4)
            .toList();
        final played = game.fixtures
            .where(
              (f) =>
                  f.isPlayed &&
                  (f.homeClubId == club.id || f.awayClubId == club.id),
            )
            .toList()
            .reversed
            .take(4)
            .toList();
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                ClubCrestWidget(config: club.crestConfig, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'Super League',
                        style: TextStyle(fontSize: 10, color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Menejer profili',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ManagerProfileScreen(),
                  ),
                ),
                icon: FaceAvatar(
                  config: manager.face,
                  size: 34,
                  shirt: const Color(0xFF34475E),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sezon markazi',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Qarorlar maydonda natija beradi.',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${game.currentRound} / 14 tur',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _metric('Liga o‘rni', '$rank / 8'),
                    _metric('Ochko', '${standing.points}'),
                    _metric(
                      'To‘plar farqi',
                      '${standing.goalDifference > 0 ? '+' : ''}${standing.goalDifference}',
                    ),
                    _metric('Mablag‘', club.formattedTransferBudget),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, box) {
                  final match = _matchPanel(context, game, club, next);
                  final prep = _readiness(
                    club,
                    manager.ratingFor(club.tactics.playstyle),
                  );
                  if (box.maxWidth > 800) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: match),
                        const SizedBox(width: 20),
                        Expanded(flex: 4, child: prep),
                      ],
                    );
                  }
                  return Column(
                    children: [match, const SizedBox(height: 16), prep],
                  );
                },
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, box) {
                  final schedule = _panel(
                    'Oldindagi o‘yinlar',
                    upcoming.isEmpty
                        ? [
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Text(
                                'Barcha uchrashuvlar yakunlangan.',
                                style: TextStyle(color: muted),
                              ),
                            ),
                          ]
                        : [for (final f in upcoming) _fixture(game, club, f)],
                  );
                  final results = _panel(
                    'Oxirgi natijalar',
                    played.isEmpty
                        ? [
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Text(
                                'Birinchi natija hali oldinda.',
                                style: TextStyle(color: muted),
                              ),
                            ),
                          ]
                        : [for (final f in played) _fixture(game, club, f)],
                  );
                  if (box.maxWidth > 800) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: schedule),
                        const SizedBox(width: 20),
                        Expanded(child: results),
                      ],
                    );
                  }
                  return Column(
                    children: [schedule, const SizedBox(height: 16), results],
                  );
                },
              ),
              const SizedBox(height: 20),
              _panel('Klub hisoboti', [
                _line(
                  'Haftalik maosh',
                  '€${(club.totalWeeklyWages / 1000).toStringAsFixed(0)}K',
                ),
                _line(
                  'Bo‘sh maosh limiti',
                  '€${(club.remainingWageBudget / 1000).toStringAsFixed(0)}K',
                ),
                _line('Stadion', club.stadiumName),
                if (onNavigateToFinance != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onNavigateToFinance,
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('Moliyani ko‘rish'),
                    ),
                  ),
              ]),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _metric(String title, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: ink,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(title, style: const TextStyle(fontSize: 10, color: muted)),
      ],
    ),
  );
  Widget _panel(String title, List<Widget> children) => Container(
    color: Colors.white,
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: muted),
          ),
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
  Widget _readiness(Club c, int rating) {
    final fitness =
        (c.startingXI.fold<int>(0, (sum, p) => sum + p.currentStamina) /
                c.startingXI.length)
            .round();
    return _panel('Uchrashuvga tayyorgarlik', [
      _line('Asosiy tarkib', '${c.startingXI.length} / 11'),
      _line('Jismoniy holat', '$fitness%'),
      ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: fitness / 100,
          minHeight: 4,
          backgroundColor: const Color(0xFFEDF1F5),
        ),
      ),
      const SizedBox(height: 8),
      _line('Sxema', c.tactics.formation.label.split(' ').first),
      _line('Falsafa', c.tactics.playstyle.displayName),
      _line('Menejer reytingi', '$rating / 100'),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onNavigateToTactics,
          icon: const Icon(Icons.tune_outlined, size: 17),
          label: const Text('Tarkib va reja'),
        ),
      ),
    ]);
  }

  Widget _matchPanel(
    BuildContext context,
    GameState game,
    Club club,
    Fixture? f,
  ) {
    if (f == null) {
      return _panel(
        game.currentRound == 14 ? 'Mavsum yakunlandi' : 'Tur yakunlandi',
        [
          const Text(
            'Natijalar liga jadvaliga yozildi.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 20),
          if (game.currentRound < 14)
            FilledButton.icon(
              onPressed: game.nextRound,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Keyingi turga o‘tish'),
            ),
        ],
      );
    }
    final h = game.getClubById(f.homeClubId)!,
        a = game.getClubById(f.awayClubId)!;
    final rival = h.id == club.id ? a : h;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.sports_soccer_outlined, size: 16, color: blue),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'NAVBATDAGI UCHRASHUV',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: muted,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Text(
                '${f.round}-tur',
                style: const TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _team(h),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    Text(
                      'VS',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '1x · 90 soniya',
                      style: TextStyle(fontSize: 9, color: muted),
                    ),
                  ],
                ),
              ),
              _team(a),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            h.stadiumName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: muted),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      OpponentSquadSheet.show(context, opponentClub: rival),
                  icon: const Icon(Icons.remove_red_eye_rounded, size: 16),
                  label: const Text('Raqib tahlili'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => MatchScreen(fixture: f),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_outlined, size: 18),
                  label: const Text('Boshlash'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _team(Club c) => Expanded(
    child: Column(
      children: [
        ClubCrestWidget(config: c.crestConfig, size: 54),
        const SizedBox(height: 12),
        Text(
          c.name,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        Text(
          'OVR ${c.teamOVR}',
          style: const TextStyle(fontSize: 11, color: muted),
        ),
      ],
    ),
  );
  Widget _fixture(GameState game, Club club, Fixture f) {
    final home = f.homeClubId == club.id,
        opponent = game.getClubById(home ? f.awayClubId : f.homeClubId)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              '${f.round}-tur',
              style: const TextStyle(fontSize: 10, color: muted),
            ),
          ),
          ClubCrestWidget(config: opponent.crestConfig, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              opponent.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            f.isPlayed
                ? f.scoreDisplay
                : home
                ? 'Uyda'
                : 'Safarda',
            style: TextStyle(
              fontSize: f.isPlayed ? 14 : 10,
              fontWeight: f.isPlayed ? FontWeight.w700 : FontWeight.w400,
              color: f.isPlayed ? ink : muted,
            ),
          ),
        ],
      ),
    );
  }
}
