import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'squad_screen.dart';
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
  static const labels = [
    'Boshqaruv',
    'Tarkib',
    'Taktika',
    'Jadval',
    'Transfer',
    'Moliya',
  ];
  static const icons = [
    Icons.space_dashboard_outlined,
    Icons.people_outline,
    Icons.tune_outlined,
    Icons.leaderboard_outlined,
    Icons.swap_horiz,
    Icons.account_balance_wallet_outlined,
  ];
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final screens = [
      DashboardScreen(
        onNavigateToTactics: () => setState(() => _index = 2),
        onNavigateToSquad: () => setState(() => _index = 1),
        onNavigateToFinance: () => setState(() => _index = 5),
      ),
      const SquadScreen(),
      const TacticsScreen(),
      const StandingsScreen(),
      const TransferScreen(),
      const FinanceScreen(),
    ];
    final body = IndexedStack(index: _index, children: screens);
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              NavigationRail(
                backgroundColor: Colors.white,
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                leading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Icon(
                    Icons.sports_soccer,
                    size: 30,
                    color: Color(0xFF1769E0),
                  ),
                ),
                destinations: [
                  for (var i = 0; i < labels.length; i++)
                    NavigationRailDestination(
                      icon: Icon(icons[i]),
                      label: Text(labels[i]),
                    ),
                ],
              ),
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
          : NavigationBar(
              height: 68,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFE7F0FF),
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: [
                for (var i = 0; i < labels.length; i++)
                  NavigationDestination(
                    icon: Icon(icons[i], size: 22),
                    label: labels[i],
                  ),
              ],
            ),
    );
  }
}
