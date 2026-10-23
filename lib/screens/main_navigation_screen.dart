import 'package:flutter/material.dart';
import '../services/game_state.dart';
import '../ui/widgets.dart';
import 'dashboard_screen.dart';
import 'finance_screen.dart';
import 'tactics_screen.dart';
import 'standings_screen.dart';
import 'transfer_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _index = 0;
  static const labels = ['Boshqaruv', 'Jamoa', 'Jadval', 'Transfer', 'Moliya'];
  static const icons = [
    Icons.home_outlined,
    Icons.groups_outlined,
    Icons.emoji_events_outlined,
    Icons.swap_horiz_rounded,
    Icons.account_balance_outlined,
  ];
  static const activeIcons = [
    Icons.home_rounded,
    Icons.groups_rounded,
    Icons.emoji_events_rounded,
    Icons.swap_horiz_rounded,
    Icons.account_balance_rounded,
  ];

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final game = GameState();
    if (!game.isInitialized) return const Scaffold();
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final screens = [
      DashboardScreen(
        onNavigateToTactics: () => _go(1),
        onNavigateToSquad: () => _go(1),
        onNavigateToFinance: () => _go(4),
        onNavigateToTable: () => _go(2),
        onNavigateToTransfers: () => _go(3),
      ),
      const TacticsScreen(),
      const StandingsScreen(),
      const TransferScreen(),
      const FinanceScreen(),
    ];
    final body = IndexedStack(index: _index, children: screens);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (wide)
              Container(
                width: 92,
                color: AppColors.surface,
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.sports_soccer, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    const Text('FTM27', style: AppText.overline),
                    const SizedBox(height: 18),
                    for (var i = 0; i < labels.length; i++)
                      _RailItem(
                        icon: i == _index ? activeIcons[i] : icons[i],
                        label: labels[i],
                        selected: i == _index,
                        onTap: () => _go(i),
                      ),
                  ],
                ),
              ),
            if (wide) const VerticalDivider(width: 1),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: body,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 62,
                  child: Row(
                    children: [
                      for (var i = 0; i < labels.length; i++)
                        Expanded(
                          child: _BarItem(
                            icon: i == _index ? activeIcons[i] : icons[i],
                            label: labels[i],
                            selected: i == _index,
                            onTap: () => _go(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _BarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _BarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.ink3;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 3 * 8,
            height: 3,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    child: Material(
      color: selected ? AppColors.primarySoft : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(icon, color: selected ? AppColors.primary : AppColors.ink2),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primary : AppColors.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
