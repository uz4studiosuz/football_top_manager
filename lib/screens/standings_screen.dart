import 'package:flutter/material.dart';
import '../models/club.dart';
import '../services/game_state.dart';
import 'widgets/opponent_squad_sheet.dart';
import 'widgets/player_detail_view.dart';

/// Apple Clean Minimalist Super League Turnir Jadvali, To'purarlar va Taqvim Ekrani
class StandingsScreen extends StatefulWidget {
  const StandingsScreen({super.key});
  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GameState _gameState = GameState();
  // Statistika sub-tabi: 0 = To'purarlar, 1 = Assistentlar, 2 = Quruq o'yinlar
  int _statsCategoryIndex = 0;
  // Taqvimda tanlangan tur
  int _selectedRound = 1;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedRound = _gameState.currentRound;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8), // 60% Canvas
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF), // 30% Surface
        elevation: 0,
        title: const Text(
          'Super League Markazi',
          style: TextStyle(
            color: Color(0xFF192B42),
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF1769E0),
          indicatorWeight: 3,
          labelColor: const Color(0xFF1769E0),
          unselectedLabelColor: Color(0xFF637184),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Jadval'),
            Tab(text: 'To\'purarlar'),
            Tab(text: 'Taqvim'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. TURNIR JADVALI
          _buildStandingsTable(),
          // 2. TO'PURARLAR VA STATISTIKA (USER REQUIREMENT)
          _buildStatsView(),
          // 3. MAVSUM TAQVIMI
          _buildFixturesSchedule(),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. TURNIR JADVALI (STANDINGS)
  // ===========================================================================
  Widget _buildStandingsTable() {
    final standings = _gameState.sortedStandings;
    final userClubId = _gameState.userClubId;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // Sarlavha satri
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Color(0xFF192B42).withValues(alpha: 0.05),
            ),
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '#',
                  style: TextStyle(
                    color: Color(0xFF778496),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Klub',
                  style: TextStyle(
                    color: Color(0xFF778496),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                width: 24,
                child: Text(
                  'O\'',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF778496),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                width: 24,
                child: Text(
                  'G\'',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF778496),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                width: 24,
                child: Text(
                  'D\'',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF778496),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                width: 24,
                child: Text(
                  'M\'',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF778496),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  'TN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF778496),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                width: 30,
                child: Text(
                  'O',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF1769E0),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Klublar qatorlari
        ...standings.asMap().entries.map((entry) {
          final pos = entry.key + 1;
          final s = entry.value;
          final club = _gameState.getClubById(s.clubId);
          final isUser = s.clubId == userClubId;
          final isUCL = pos <= 4;
          return GestureDetector(
            onTap: () {
              if (club != null && !isUser) {
                OpponentSquadSheet.show(context, opponentClub: club);
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF1769E0).withValues(alpha: 0.15)
                    : const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isUser
                      ? const Color(0xFF1769E0)
                      : isUCL
                      ? const Color(0xFF1769E0).withValues(alpha: 0.25)
                      : Color(0xFF192B42).withValues(alpha: 0.05),
                  width: isUser ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Pos #
                      SizedBox(
                        width: 22,
                        child: Text(
                          '$pos',
                          style: TextStyle(
                            color: isUCL
                                ? const Color(0xFF1769E0)
                                : Color(0xFF637184),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      // Crest
                      if (club != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ClubCrestWidget(
                            config: club.crestConfig,
                            size: 22,
                          ),
                        ),
                      // Name
                      Expanded(
                        child: Text(
                          club?.shortName ?? s.clubId,
                          style: TextStyle(
                            color: isUser
                                ? const Color(0xFF1769E0)
                                : Color(0xFF192B42),
                            fontWeight: isUser
                                ? FontWeight.w900
                                : FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${s.played}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF526174),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${s.won}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF526174),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${s.drawn}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF526174),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${s.lost}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF526174),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${s.goalDifference > 0 ? '+${s.goalDifference}' : s.goalDifference}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF637184),
                            fontSize: 10,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        child: Text(
                          '${s.points}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF1769E0),
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Form Guide Dots (Oxirgi 5 ta o'yin)
                  if (s.formGuide.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const SizedBox(width: 28),
                        const Text(
                          'Forma: ',
                          style: TextStyle(
                            color: Color(0xFFD7DEE7),
                            fontSize: 9,
                          ),
                        ),
                        ...s.formGuide.map((f) {
                          Color dotColor;
                          if (f == 'W') {
                            dotColor = const Color(0xFF1769E0);
                          } else if (f == 'D') {
                            dotColor = const Color(0xFFF59E0B);
                          } else {
                            dotColor = const Color(0xFFEF4444);
                          }
                          return Container(
                            margin: const EdgeInsets.only(right: 3),
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                f,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        // Zone Legend
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color(0xFF192B42).withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1769E0),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '1-4 o‘rinlar: yuqori to‘rtlik',
                    style: TextStyle(color: Color(0xFF526174), fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Qatorni bosish orqali jamoaning tarkibi va taktik sxemasini tekshirishingiz mumkin.',
                style: TextStyle(color: Color(0xFF778496), fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. TO'PURARLAR VA STATISTIKA (TOP SCORERS & ASSISTS)
  // ===========================================================================
  Widget _buildStatsView() {
    return Column(
      children: [
        // Sub-segmented selector (Apple Style Pill)
        Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color(0xFF192B42).withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              _buildCategoryPill(
                0,
                'To\'purarlar',
                Icons.sports_soccer_rounded,
              ),
              _buildCategoryPill(1, 'Assistentlar', Icons.alt_route_rounded),
              _buildCategoryPill(2, 'Quruq O\'yinlar', Icons.pan_tool_rounded),
            ],
          ),
        ),
        Expanded(child: _buildCategoryList()),
      ],
    );
  }

  Widget _buildCategoryPill(int index, String title, IconData icon) {
    final isSel = _statsCategoryIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _statsCategoryIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFF1769E0) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSel ? Colors.white : Color(0xFF637184),
              ),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  color: isSel ? Colors.white : Color(0xFF637184),
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    if (_statsCategoryIndex == 0) {
      // To'purarlar (Golden Boot)
      final scorers = _gameState.topScorers;
      if (scorers.isEmpty) {
        return _buildEmptyStats(
          'Hali gollar kiritilmagan. O\'yinlar o\'tkazilgach, to\'purarlar bu yerda chiqadi.',
        );
      }
      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: scorers.length,
        itemBuilder: (context, i) {
          final entry = scorers[i];
          final p = entry.player;
          final club = entry.club;
          final rank = i + 1;
          return _buildLeaderboardTile(
            rank: rank,
            player: p,
            club: club,
            primaryMetric: '${p.seasonGoals}',
            primaryLabel: 'Gol',
            secondaryMetric: '${p.seasonAssists} pas',
            highlightColor: rank == 1
                ? const Color(0xFFF59E0B)
                : const Color(0xFF1769E0),
          );
        },
      );
    } else if (_statsCategoryIndex == 1) {
      // Assistentlar
      final assists = _gameState.topAssists;
      if (assists.isEmpty) {
        return _buildEmptyStats('Hali golli uzatmalar amalga oshirilmagan.');
      }
      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: assists.length,
        itemBuilder: (context, i) {
          final entry = assists[i];
          final p = entry.player;
          final club = entry.club;
          final rank = i + 1;
          return _buildLeaderboardTile(
            rank: rank,
            player: p,
            club: club,
            primaryMetric: '${p.seasonAssists}',
            primaryLabel: 'Pas',
            secondaryMetric: '${p.seasonGoals} gol',
            highlightColor: const Color(0xFF3B82F6),
          );
        },
      );
    } else {
      // Quruq o'yinlar (Clean sheets)
      final cleanSheets = _gameState.topCleanSheets;
      if (cleanSheets.isEmpty) {
        return _buildEmptyStats(
          'Darvozabonlar hali quruq o\'yin o\'tkazishmadi.',
        );
      }
      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: cleanSheets.length,
        itemBuilder: (context, i) {
          final entry = cleanSheets[i];
          final p = entry.player;
          final club = entry.club;
          final rank = i + 1;
          return _buildLeaderboardTile(
            rank: rank,
            player: p,
            club: club,
            primaryMetric: '${p.seasonCleanSheets}',
            primaryLabel: 'Seyv/0',
            secondaryMetric: '${p.seasonMatches} o\'yin',
            highlightColor: const Color(0xFF1769E0),
          );
        },
      );
    }
  }

  Widget _buildEmptyStats(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bar_chart_rounded,
              size: 40,
              color: Color(0xFFD7DEE7),
            ),
            const SizedBox(height: 10),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF778496), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardTile({
    required int rank,
    required dynamic player,
    required Club club,
    required String primaryMetric,
    required String primaryLabel,
    required String secondaryMetric,
    required Color highlightColor,
  }) {
    Color rankColor = Color(0xFF637184);
    if (rank == 1) rankColor = const Color(0xFFF59E0B); // Gold
    if (rank == 2) rankColor = const Color(0xFF94A3B8); // Silver
    if (rank == 3) rankColor = const Color(0xFFB45309); // Bronze
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFF192B42).withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          dense: true,
          onTap: () =>
              PlayerDetailView.show(context, player: player, club: club),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: rankColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ClubCrestWidget(config: club.crestConfig, size: 24),
            ],
          ),
          title: Row(
            children: [
              const Icon(
                Icons.public_outlined,
                size: 14,
                color: Color(0xFF637184),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  player.name,
                  style: const TextStyle(
                    color: Color(0xFF192B42),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Text(
            '${club.shortName} • ${player.mainPosition.code} • $secondaryMetric',
            style: const TextStyle(color: Color(0xFF778496), fontSize: 11),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: highlightColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: highlightColor.withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  primaryMetric,
                  style: TextStyle(
                    color: highlightColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                Text(
                  primaryLabel,
                  style: const TextStyle(
                    color: Color(0xFF778496),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. MAVSUM TAQVIMI (FIXTURES & SCHEDULE)
  // ===========================================================================
  Widget _buildFixturesSchedule() {
    final fixtures = _gameState.fixtures;
    final rounds = List.generate(14, (i) => i + 1);
    final roundFixtures = fixtures
        .where((f) => f.round == _selectedRound)
        .toList();
    final isCurrent = _selectedRound == _gameState.currentRound;
    return Column(
      children: [
        // Tur selector chiplari
        Container(
          height: 48,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: rounds.length,
            itemBuilder: (context, i) {
              final r = rounds[i];
              final isSel = r == _selectedRound;
              final isLive = r == _gameState.currentRound;
              return GestureDetector(
                onTap: () => setState(() => _selectedRound = r),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSel
                        ? const Color(0xFF1769E0)
                        : const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLive
                          ? const Color(0xFF1769E0)
                          : isSel
                          ? const Color(0xFF1769E0)
                          : Color(0xFF192B42).withValues(alpha: 0.06),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$r-Tur',
                      style: TextStyle(
                        color: isSel ? Colors.white : Color(0xFF526174),
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Tanlangan tur o'yinlari
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(14),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_selectedRound-Tur Uchrashuvlari',
                    style: const TextStyle(
                      color: Color(0xFF192B42),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1769E0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'JORIY TUR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ...roundFixtures.map((f) {
                final home = _gameState.getClubById(f.homeClubId);
                final away = _gameState.getClubById(f.awayClubId);
                final isUserMatch =
                    f.homeClubId == _gameState.userClubId ||
                    f.awayClubId == _gameState.userClubId;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUserMatch
                        ? const Color(0xFF1769E0).withValues(alpha: 0.12)
                        : const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isUserMatch
                          ? const Color(0xFF1769E0).withValues(alpha: 0.4)
                          : Color(0xFF192B42).withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (home != null)
                        ClubCrestWidget(config: home.crestConfig, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          home?.name ?? f.homeClubId,
                          style: TextStyle(
                            color: isUserMatch
                                ? const Color(0xFF1769E0)
                                : Color(0xFF192B42),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F5F8),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Color(0xFFE4E9F0)),
                        ),
                        child: Text(
                          f.scoreDisplay,
                          style: TextStyle(
                            color: f.isPlayed
                                ? Color(0xFF192B42)
                                : const Color(0xFFF59E0B),
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          away?.name ?? f.awayClubId,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: isUserMatch
                                ? const Color(0xFF1769E0)
                                : Color(0xFF192B42),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (away != null)
                        ClubCrestWidget(config: away.crestConfig, size: 24),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
