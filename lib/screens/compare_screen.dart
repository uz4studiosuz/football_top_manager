import 'dart:math';
import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../services/game_state.dart';
import '../ui/face_avatar.dart';
import '../ui/widgets.dart';
import '../l10n/l10n.dart';

/// Two players side by side: attribute radar and key numbers.
class CompareScreen extends StatefulWidget {
  final Player first;
  final Player? second;
  const CompareScreen({super.key, required this.first, this.second});

  static Future<void> show(BuildContext context, Player first) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => CompareScreen(first: first)));

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  late Player? _second = widget.second;
  static const _colors = (Color(0xFF374DF5), Color(0xFFE5352B));

  /// Average of each attribute group (goalkeeping only for keepers).
  static Map<String, double> _groups(Player p) {
    final stats = p.stats.toMap();
    return {
      for (final g in PlayerStats.groups.entries)
        if (g.key != 'Darvozabon' || p.mainPosition.isGoalkeeper)
          g.key: g.value.map((k) => (stats[k] as int).toDouble()).reduce((a, b) => a + b) / g.value.length,
    };
  }

  Future<void> _pick() async {
    final game = GameState();
    final all = [
      for (final c in game.marketClubs)
        for (final p in c.squad) (p, c as Club?),
      for (final p in game.freeAgents) (p, null),
    ];
    final picked = await showDialog<Player>(
      context: context,
      builder: (ctx) {
        var query = '';
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final hits = query.length < 2
                ? <(Player, Club?)>[]
                : all.where((e) => e.$1.name.toLowerCase().contains(query.toLowerCase())).take(30).toList();
            return AlertDialog(
              title: Text(tr('Futbolchi tanlang')),
              content: SizedBox(
                width: 420,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: tr('Ism bo‘yicha qidirish')),
                      onChanged: (v) => setLocal(() => query = v.trim()),
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final (p, c) in hits)
                            ListTile(
                              dense: true,
                              leading: FaceAvatar(config: p.face, size: 32, shirt: c?.primaryColor ?? AppColors.ink3, circle: true),
                              title: Text(p.name),
                              subtitle: Text('${p.mainPosition.code} · ${c?.name ?? tr('Erkin agent')}'),
                              trailing: game.isScouted(p) ? ValueBadge(p.ovr, size: 26) : null,
                              onTap: () => Navigator.pop(ctx, p),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (picked != null) setState(() => _second = picked);
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette tokens when appearance changes.
    final a = widget.first, b = _second;
    final game = GameState();
    final ga = _groups(a), gb = b == null ? null : _groups(b);
    final keys = ga.keys.where((k) => gb == null || gb.containsKey(k)).toList();
    final hidden = b != null && !game.isScouted(b);
    Widget headBody(Player p, Color color) => Column(
        children: [
          FaceAvatar(config: p.face, size: 64, shirt: color, circle: true),
          const SizedBox(height: 6),
          Text(p.name, textAlign: TextAlign.center, maxLines: 2, style: AppText.bodyStrong),
          Text('${p.mainPosition.code} · ${p.age}', style: AppText.caption),
        ],
      );
    Widget head(Player p, Color color) => Expanded(child: headBody(p, color));
    Widget row(String label, String left, String right, {bool leftBetter = false, bool rightBetter = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(left, style: AppText.bodyStrong.copyWith(color: leftBetter ? _colors.$1 : AppColors.ink))),
          Text(label, style: AppText.small),
          Expanded(
            child: Text(right, textAlign: TextAlign.right, style: AppText.bodyStrong.copyWith(color: rightBetter ? _colors.$2 : AppColors.ink)),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(tr('Solishtirish'))),
      body: PageWidth(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            AppCard(
              child: Row(
                children: [
                  head(a, _colors.$1),
                  Text('VS', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink3)),
                  if (b == null)
                    Expanded(
                      child: OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.person_search), label: Text(tr('Tanlash'))),
                    )
                  else
                    Expanded(child: InkWell(onTap: _pick, child: headBody(b, _colors.$2))),
                ],
              ),
            ),
            if (b != null) ...[
              const SizedBox(height: 12),
              AppCard(
                child: hidden
                    ? Text(tr('Ikkinchi futbolchining atributlari noma’lum: avval skaut yuboring.'), style: AppText.small)
                    : AspectRatio(aspectRatio: 1.2, child: CustomPaint(painter: _RadarPainter(keys, ga, gb!, _colors))),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  children: [
                    row('OVR', '${a.ovr}', hidden ? '?' : '${b.ovr}', leftBetter: hidden || a.ovr > b.ovr, rightBetter: !hidden && b.ovr > a.ovr),
                    row(tr('Salohiyat'), '${a.potential}', hidden ? '?' : '${b.potential}',
                        leftBetter: !hidden && a.potential > b.potential, rightBetter: !hidden && b.potential > a.potential),
                    row(tr('Bozor bahosi'), formatMoney(a.marketValue), formatMoney(b.marketValue)),
                    row(tr('Gollar'), '${a.seasonGoals}', '${b.seasonGoals}', leftBetter: a.seasonGoals > b.seasonGoals, rightBetter: b.seasonGoals > a.seasonGoals),
                    row(tr('Assistlar'), '${a.seasonAssists}', '${b.seasonAssists}',
                        leftBetter: a.seasonAssists > b.seasonAssists, rightBetter: b.seasonAssists > a.seasonAssists),
                    row(tr('O‘rtacha reyting'), a.averageRating?.toStringAsFixed(2) ?? '–', b.averageRating?.toStringAsFixed(2) ?? '–',
                        leftBetter: (a.averageRating ?? 0) > (b.averageRating ?? 0), rightBetter: (b.averageRating ?? 0) > (a.averageRating ?? 0)),
                    row(tr('O‘yin uslubi'), a.playingStyle.title, b.playingStyle.title),
                    if (!hidden)
                      for (final k in keys)
                        row(tr(k), ga[k]!.toStringAsFixed(0), gb![k]!.toStringAsFixed(0),
                            leftBetter: ga[k]! > gb[k]!, rightBetter: gb[k]! > ga[k]!),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<String> keys;
  final Map<String, double> a, b;
  final (Color, Color) colors;
  _RadarPainter(this.keys, this.a, this.b, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = min(size.width, size.height) / 2 - 34;
    final n = keys.length;
    Offset at(int i, double v) {
      final angle = -pi / 2 + i * 2 * pi / n;
      final k = ((v - 40) / 59).clamp(0.0, 1.0);
      return c + Offset(cos(angle), sin(angle)) * r * k;
    }

    final grid = Paint()
      ..color = AppColors.line
      ..style = PaintingStyle.stroke;
    for (final level in [55.0, 70.0, 85.0, 99.0]) {
      canvas.drawPath(Path()..addPolygon([for (var i = 0; i < n; i++) at(i, level)], true), grid);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(c, at(i, 99), grid);
      final tp = TextPainter(
        text: TextSpan(text: tr(keys[i]), style: AppText.caption.copyWith(color: AppColors.ink2)),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = at(i, 112);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
    for (final (values, color) in [(a, colors.$1), (b, colors.$2)]) {
      final path = Path()..addPolygon([for (var i = 0; i < n; i++) at(i, values[keys[i]]!)], true);
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.22));
      canvas.drawPath(path, Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => true;
}
