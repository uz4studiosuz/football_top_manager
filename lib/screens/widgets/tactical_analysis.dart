import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../models/league.dart';
import '../../ui/widgets.dart';
import '../../l10n/l10n.dart';

/// Only events recorded by the match engine are counted; old saves can be empty.
class TacticalAnalysis extends StatefulWidget {
  final Fixture fixture;
  final Club home, away;
  const TacticalAnalysis({super.key, required this.fixture, required this.home, required this.away});
  @override
  State<TacticalAnalysis> createState() => _TacticalAnalysisState();
}

class _TacticalAnalysisState extends State<TacticalAnalysis> {
  int half = 0;
  bool includes(int minute) => half == 0 || (half == 1 ? minute <= 45 : minute > 45);
  List<int> metrics(bool home) {
    final f = widget.fixture, club = home ? widget.home : widget.away;
    final recorded = {...(home ? f.homeLineup : f.awayLineup), ...(home ? f.homeBench : f.awayBench)};
    final ids = recorded.isEmpty ? club.squad.map((p) => p.id).toSet() : recorded;
    final totals = [0, 0, 0, 0];
    for (final entry in f.actions.entries) {
      if (!ids.contains(entry.key)) continue;
      for (final a in PlayerAction.decodeAll(entry.value)) {
        if (!includes(a.minute)) continue;
        if ((a.kind == ActionKind.tackle || a.kind == ActionKind.interception) && a.ok && a.from.dx >= 0.5) totals[3]++;
        if ((a.kind == ActionKind.pass || a.kind == ActionKind.cross) && a.ok && a.to.dx > a.from.dx && a.to.dx > 0.67) {
          totals[a.to.dy < 1 / 3 ? 0 : a.to.dy > 2 / 3 ? 2 : 1]++;
        }
      }
    }
    for (final s in f.shots) {
      if (s.home != home || !includes(s.minute)) continue;
      final y = home ? s.origin.dy : 1 - s.origin.dy;
      totals[y < 1 / 3 ? 0 : y > 2 / 3 ? 2 : 1]++;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final h = metrics(true), a = metrics(false);
    final labels = [tr('Chap qanot'), tr('Markaz'), tr('O‘ng qanot'), tr('Raqib maydonida to‘p olish')];
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(tr('Taktik tahlil'), icon: Icons.analytics_outlined),
      Text(tr('Zarbalar va oldinga aniq paslar hududi; pressing raqib maydonidagi muvaffaqiyatli to‘p olishlar bilan ko‘rsatiladi.'), style: AppText.caption),
      const SizedBox(height: 8),
      Wrap(spacing: 6, children: [for (var i = 0; i < 3; i++) ChoiceChip(
        label: Text([tr('Barcha'), tr('1-bo‘lim'), tr('2-bo‘lim')][i]), selected: half == i,
        onSelected: (_) => setState(() => half = i),
      )]),
      if (widget.fixture.actions.isEmpty && widget.fixture.shots.isEmpty)
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr('Bu o‘yin uchun batafsil harakatlar saqlanmagan.'), style: AppText.caption))
      else for (var i = 0; i < labels.length; i++) StatCompareRow(label: labels[i], homeText: '${h[i]}', awayText: '${a[i]}', home: h[i].toDouble(), away: a[i].toDouble()),
    ]));
  }
}
