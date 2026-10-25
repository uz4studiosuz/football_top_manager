import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../ui/widgets.dart';
import '../services/game_state.dart';
import 'club_life_screen.dart';
import 'finance_screen.dart';
import 'transfer_screen.dart';

/// Transfers, scouting and finances in one bottom-bar section: scouts find
/// players, the market buys them, the budget pays.
class MarketFinanceScreen extends StatefulWidget {
  const MarketFinanceScreen({super.key});
  @override
  State<MarketFinanceScreen> createState() => _MarketFinanceScreenState();
}

class _MarketFinanceScreenState extends State<MarketFinanceScreen> {
  int _view = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, icon: const Icon(Icons.swap_horiz_rounded, size: 18), label: Text(tr('Transfer'))),
              ButtonSegment(value: 1, icon: const Icon(Icons.travel_explore_outlined, size: 18), label: Text(tr('Skautlar'))),
              ButtonSegment(value: 2, icon: const Icon(Icons.account_balance_outlined, size: 18), label: Text(tr('Moliya'))),
            ],
            selected: {_view},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _view = v.first),
          ),
        ),
      ),
      Expanded(
        child: IndexedStack(
          index: _view,
          children: [
            const TransferScreen(),
            // Scouting feeds the market, so it sits beside it.
            ListenableBuilder(
              listenable: GameState(),
              // ignore: prefer_const_constructors
              builder: (context, _) => Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: ScoutsView())),
            ),
            const FinanceScreen(),
          ],
        ),
      ),
    ],
  );
}
