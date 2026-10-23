import 'package:flutter/material.dart';
import '../data/initial_database.dart';
import '../models/club.dart';
import '../services/game_state.dart';
import 'custom_club_creator_screen.dart';
import 'main_navigation_screen.dart';
import '../models/manager_profile.dart';

/// O'yinga kirganda klub tanlash yoki yangi jamoa yaratish ekrani
class ClubSelectionScreen extends StatefulWidget {
  final ManagerProfile? managerProfile;
  const ClubSelectionScreen({super.key, this.managerProfile});
  @override
  State<ClubSelectionScreen> createState() => _ClubSelectionScreenState();
}

class _ClubSelectionScreenState extends State<ClubSelectionScreen> {
  late List<Club> _clubs;
  int _selectedClubIndex = 0;
  @override
  void initState() {
    super.initState();
    _clubs = InitialDatabase.getSuperLeagueClubs();
  }

  Club get _currentClub => _clubs[_selectedClubIndex];
  void _chooseClubAndStart(Club club) {
    GameState().startCareerWithExistingClub(
      club,
      managerProfile: widget.managerProfile,
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final club = _currentClub;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      body: SafeArea(
        child: Column(
          children: [
            // Sarlavha (Header)
            _buildAppHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // O'Z JAMOANGNI YARATISH BANNERI
                    _buildCreateCustomClubBanner(),
                    const SizedBox(height: 24),
                    // YOKI MAVJUD TOP KLUBNI TANLANG
                    const Row(
                      children: [
                        Expanded(child: Divider(color: Color(0xFFE4E9F0))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'YOKI SUPER LEAGUE KLUBLARIDAN TANLANG',
                            style: TextStyle(
                              color: Color(0xFF778496),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Color(0xFFE4E9F0))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 8 ta Klub Navigatsiya Selectori
                    _buildClubHorizontalSelector(),
                    const SizedBox(height: 16),
                    // Tanlangan Klub Katta Kartasi
                    _buildClubHeroCard(club),
                    const SizedBox(height: 20),
                    // Boshqaruvni qabul qilish tugmasi
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => _chooseClubAndStart(club),
                        icon: const Icon(
                          Icons.sports_soccer_rounded,
                          color: Colors.white,
                        ),
                        label: Text(
                          '${club.name.toUpperCase()}NI BOSHQARISH',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1769E0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        border: Border(
          bottom: BorderSide(color: Color(0xFF192B42).withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1769E0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'FTM 27',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Football Top Manager',
                style: TextStyle(
                  color: Color(0xFF192B42),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Icon(Icons.sports_rounded, color: Color(0xFF1769E0), size: 22),
        ],
      ),
    );
  }

  Widget _buildCreateCustomClubBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF1769E0).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1769E0).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1769E0)),
                ),
                child: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: Color(0xFF1769E0),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'O\'zingizning Yangi Klubingiz',
                      style: TextStyle(
                        color: Color(0xFF192B42),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Nomi, ranglari, original logosini tanlang va o\'z jamoangizni yarating!',
                      style: TextStyle(color: Color(0xFF526174), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CustomClubCreatorScreen(
                      managerProfile: widget.managerProfile,
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.draw_rounded,
                color: Color(0xFF1769E0),
                size: 18,
              ),
              label: const Text(
                'YANGI JAMOA YARATISH',
                style: TextStyle(
                  color: Color(0xFF1769E0),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1769E0), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClubHorizontalSelector() {
    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _clubs.length,
        itemBuilder: (context, index) {
          final c = _clubs[index];
          final isSelected = index == _selectedClubIndex;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedClubIndex = index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1769E0).withValues(alpha: 0.18)
                    : const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1769E0)
                      : Color(0xFFE4E9F0),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  ClubCrestWidget(config: c.crestConfig, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    c.shortName,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF1769E0)
                          : Color(0xFF526174),
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildClubHeroCard(Club club) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Color(0xFF192B42).withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClubCrestWidget(config: club.crestConfig, size: 68),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.name,
                      style: const TextStyle(
                        color: Color(0xFF192B42),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${club.stadiumName} • ${(club.stadiumCapacity / 1000).toStringAsFixed(0)}K muxlis',
                      style: const TextStyle(
                        color: Color(0xFF637184),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Team OVR Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'OVR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${club.teamOVR}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Ratinglar va Byudjet paneli
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5F8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Color(0xFF192B42).withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricCol(
                  'HUJUM',
                  '${club.attackRating}',
                  const Color(0xFFEF4444),
                ),
                _buildMetricCol(
                  'YARIM H.',
                  '${club.midfieldRating}',
                  const Color(0xFFF59E0B),
                ),
                _buildMetricCol(
                  'HIMOYA',
                  '${club.defenseRating}',
                  const Color(0xFF3B82F6),
                ),
                Container(width: 1, height: 32, color: Color(0xFFE4E9F0)),
                _buildMetricCol(
                  'TRANSFER',
                  club.formattedTransferBudget,
                  const Color(0xFF1769E0),
                ),
                _buildMetricCol(
                  'MAOSH',
                  club.formattedWageBudget,
                  Color(0xFF526174),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Yetakchi futbolchilar ko'rgazmasi
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Asosiy Yulduzlar',
                    style: TextStyle(
                      color: Color(0xFF526174),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: club.squad.take(4).map((p) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EDF3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFFE9EDF3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.public_outlined,
                          size: 14,
                          color: Color(0xFF637184),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          p.shortName,
                          style: const TextStyle(
                            color: Color(0xFF192B42),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1769E0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${p.ovr}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF778496),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
