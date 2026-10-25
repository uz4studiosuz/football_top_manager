import 'dart:math';
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../services/coin_wallet.dart';
import 'widgets.dart';

/// The FTM Coin: minted gold with a reeded rim and the game's ball logo
/// embossed in the centre.
class CoinIcon extends StatelessWidget {
  final double size;
  const CoinIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: size, child: CustomPaint(painter: _CoinPainter()));
}

class _CoinPainter extends CustomPainter {
  static const _light = Color(0xFFFFF1A8), _gold = Color(0xFFF7C531), _deep = Color(0xFFC98A00), _dark = Color(0xFF8A5A00);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    // Drop shadow and rim.
    canvas.drawCircle(c + Offset(0, r * 0.06), r * 0.98, Paint()..color = const Color(0x33000000));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_light, _gold, _deep, _dark],
          stops: [0, 0.35, 0.75, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Reeded edge.
    if (r > 14) {
      final reed = Paint()
        ..color = _dark.withValues(alpha: 0.35)
        ..strokeWidth = max(0.6, r * 0.025);
      for (var i = 0; i < 60; i++) {
        final a = i * pi / 30;
        final d = Offset(cos(a), sin(a));
        canvas.drawLine(c + d * r * 0.9, c + d * r * 0.985, reed);
      }
    }
    // Recessed face.
    final face = r * 0.8;
    canvas.drawCircle(
      c,
      face,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
          colors: [_light, _gold, _deep],
          stops: [0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: c, radius: face)),
    );
    canvas.drawCircle(
      c,
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, r * 0.05)
        ..color = _dark.withValues(alpha: 0.55),
    );
    if (r > 14) {
      canvas.drawCircle(
        c,
        face * 0.86,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(0.5, r * 0.018)
          ..color = _dark.withValues(alpha: 0.3),
      );
    }
    // Embossed logo: light offset first, then the dark glyph.
    final big = r > 28;
    final glyph = r * (big ? 0.82 : 1.0);
    final logoCentre = c - Offset(0, big ? r * 0.1 : 0);
    _icon(canvas, logoCentre + Offset(glyph * 0.03, glyph * 0.04), glyph, _light.withValues(alpha: 0.9));
    _icon(canvas, logoCentre, glyph, _dark);
    if (big) {
      final label = TextPainter(
        text: TextSpan(
          text: 'FTM',
          style: TextStyle(fontSize: r * 0.2, fontWeight: FontWeight.w900, letterSpacing: r * 0.03, color: _dark),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, c + Offset(-label.width / 2, r * 0.4));
    }
    // Shine.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - r, c.dy - r * 0.2)
        ..quadraticBezierTo(c.dx - r * 0.2, c.dy - r * 0.55, c.dx + r * 0.25, c.dy - r)
        ..lineTo(c.dx - r, c.dy - r)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
    canvas.restore();
  }

  void _icon(Canvas canvas, Offset centre, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.sports_soccer.codePoint),
        style: TextStyle(fontSize: size, fontFamily: Icons.sports_soccer.fontFamily, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Coin + number, e.g. a price tag.
class CoinAmount extends StatelessWidget {
  final int amount;
  final double size;
  final Color? color;
  const CoinAmount(this.amount, {super.key, this.size = 16, this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CoinIcon(size: size),
      SizedBox(width: size * 0.3),
      Text(
        '$amount',
        style: TextStyle(
          fontSize: size * 0.85,
          fontWeight: FontWeight.w800,
          color: color ?? const Color(0xFF9A6A00),
          fontFeatures: AppText.tabular,
        ),
      ),
    ],
  );
}

/// The live balance pill for app bars.
class CoinBalance extends StatelessWidget {
  const CoinBalance({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: CoinWallet().balance,
    builder: (context, value, _) => Tooltip(
      message: tr('FTM tangalari'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6D6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF2D27A)),
        ),
        child: CoinAmount(value, size: 22),
      ),
    ),
  );
}

/// Shown once on first launch.
Future<void> showWelcomeCoins(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CoinIcon(size: 120),
        const SizedBox(height: 18),
        Text(tr('Xush kelibsiz!'), style: AppText.h1),
        const SizedBox(height: 8),
        CoinAmount(CoinWallet.welcomeBonus, size: 28),
        const SizedBox(height: 12),
        Text(
          trf('Sizga {0} FTM tanga sovg‘a qilindi. Tangalar mavjud klubni boshqarish yoki o‘z klubingizni yaratish uchun sarflanadi, g‘alabalar, chempionlik va ko‘tarilish uchun esa qaytib keladi.', [CoinWallet.welcomeBonus]),
          textAlign: TextAlign.center,
          style: AppText.small,
        ),
      ],
    ),
    actions: [
      FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr('Boshladik'))),
    ],
  ),
);

/// Prices and how to earn coins.
Future<void> showCoinInfo(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        Row(
          children: [
            const CoinIcon(size: 44),
            const SizedBox(width: 12),
            Expanded(child: Text(tr('FTM tangalari'), style: AppText.h2)),
            const CoinBalance(),
          ],
        ),
        const SizedBox(height: 14),
        Text(tr('Narxlar'), style: AppText.bodyStrong),
        for (final (label, cost) in [
          (tr('Klub OVR 85+'), 900),
          (tr('Klub OVR 80–84'), 600),
          (tr('Klub OVR 75–79'), 350),
          (tr('Klub OVR 70–74'), 200),
          (tr('Klub OVR 70 dan past'), 100),
          (tr('Yangi klub yaratish'), CoinWallet.customClubCost),
        ])
          _row(label, cost),
        const Divider(height: 24),
        Text(tr('Qanday topiladi'), style: AppText.bodyStrong),
        for (final (label, value) in [
          (tr('G‘alaba'), CoinWallet.winReward),
          (tr('Durang'), CoinWallet.drawReward),
          (tr('Kengash maqsadi bajarildi'), CoinWallet.objectiveReward),
          (tr('Yuqori ligaga ko‘tarilish'), CoinWallet.promotionReward),
          (tr('Chempionlik'), CoinWallet.titleReward),
        ])
          _row(label, value, plus: true),
      ],
    ),
  ),
);

Widget _row(String label, int amount, {bool plus = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(
    children: [
      Expanded(child: Text(label, style: AppText.body)),
      if (plus) const Text('+ ', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.win)),
      CoinAmount(amount),
    ],
  ),
);
