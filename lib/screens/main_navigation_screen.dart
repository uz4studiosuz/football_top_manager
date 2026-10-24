import 'dart:async';
import 'package:flutter/material.dart';
import '../models/finance.dart';
import '../services/game_state.dart';
import '../ui/widgets.dart';
import 'dashboard_screen.dart';
import 'finance_screen.dart';
import 'tactics_screen.dart';
import 'standings_screen.dart';
import 'transfer_screen.dart';
import '../l10n/l10n.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _index = 0;
  static List<String> get labels => [tr('Boshqaruv'), tr('Jamoa'), tr('Jadval'), tr('Transfer'), tr('Moliya')];
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

  // ------------------------------------------------------------ alerts
  NewsItem? _alert;
  bool _alertVisible = false;
  Timer? _poll, _hide;

  @override
  void initState() {
    super.initState();
    // Polling keeps banners queued while a match or sheet covers this screen.
    _poll = Timer.periodic(const Duration(milliseconds: 700), (_) => _pump());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _hide?.cancel();
    super.dispose();
  }

  void _pump() {
    if (!mounted || _alert != null) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final next = GameState().takeAlert();
    if (next == null) return;
    setState(() {
      _alert = next;
      _alertVisible = true;
    });
    _hide = Timer(const Duration(milliseconds: 4200), _dismiss);
  }

  void _dismiss() {
    _hide?.cancel();
    if (!mounted || _alert == null) return;
    setState(() => _alertVisible = false);
    Timer(const Duration(milliseconds: 260), () {
      if (mounted) setState(() => _alert = null);
    });
  }

  void _openAlert(NewsItem n) {
    n.read = true;
    _dismiss();
    _go(switch (n.kind) {
      NewsKind.transfer || NewsKind.window => 3,
      NewsKind.injury || NewsKind.award || NewsKind.contract => 1,
      NewsKind.finance => 4,
      _ => 0,
    });
  }

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
    final alert = _alert;
    final body = Stack(
      children: [
        IndexedStack(index: _index, children: screens),
        if (alert != null)
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: AnimatedSlide(
              offset: _alertVisible ? Offset.zero : const Offset(0, -1.4),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: AlertBanner(
                    item: alert,
                    pending: GameState().alerts.length,
                    onTap: () => _openAlert(alert),
                    onClose: _dismiss,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
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
                    Text(tr('FTM27'), style: AppText.overline),
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

/// Pop-up card for important news (offer, injury, OVR growth...).
class AlertBanner extends StatelessWidget {
  final NewsItem item;
  final int pending;
  final VoidCallback onTap, onClose;
  const AlertBanner({
    super.key,
    required this.item,
    required this.pending,
    required this.onTap,
    required this.onClose,
  });

  String get _label => switch (item.kind) {
    NewsKind.transfer => tr('TRANSFER TAKLIFI'),
    NewsKind.injury => tr('JAROHAT'),
    NewsKind.award => tr('RIVOJLANISH'),
    NewsKind.contract => tr('SHARTNOMA'),
    NewsKind.window => tr('TRANSFER OYNASI'),
    NewsKind.board => tr('KENGASH'),
    NewsKind.finance => tr('MOLIYA'),
    NewsKind.match => tr('O‘YIN'),
  };

  @override
  Widget build(BuildContext context) {
    final c = item.kind.color;
    return Material(
      color: AppColors.surface,
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(border: Border(left: BorderSide(color: c, width: 4))),
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: c.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(item.kind.icon, color: c, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pending > 0 ? trf('{0} · yana {1}', [_label, pending]) : _label,
                      style: AppText.overline.copyWith(color: c, fontSize: 10),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(item.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.small),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.ink3),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
