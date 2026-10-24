import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import '../l10n/l10n.dart';

export 'app_theme.dart';

/// White rounded card – the basic building block of every screen.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color color;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.color = AppColors.surface,
  });
  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    return Container(
      margin: margin,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? body : InkWell(onTap: onTap, child: body),
      ),
    );
  }
}

/// Card title row with an optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final IconData? icon;
  final EdgeInsetsGeometry padding;
  const SectionHeader(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.icon,
    this.padding = const EdgeInsets.only(bottom: 12),
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
        ],
        Expanded(child: Text(tr(title), style: AppText.h3)),
        if (action != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                action!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// SofaScore-like coloured rating pill (e.g. 7.4).
class RatingBadge extends StatelessWidget {
  final double? rating;
  final double size;
  final bool star;
  const RatingBadge(this.rating, {super.key, this.size = 13, this.star = false});
  @override
  Widget build(BuildContext context) {
    final color = AppColors.rating(rating);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.42,
        vertical: size * 0.16,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.38),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (star) ...[
            Icon(Icons.star_rounded, size: size, color: Colors.white),
            SizedBox(width: size * 0.15),
          ],
          Text(
            rating == null ? '–' : rating!.toStringAsFixed(1),
            style: TextStyle(
              fontSize: size,
              height: 1.15,
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontFeatures: AppText.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// Square OVR / attribute value tile tinted by quality.
class ValueBadge extends StatelessWidget {
  final int value;
  final double size;
  final bool filled;
  const ValueBadge(this.value, {super.key, this.size = 30, this.filled = true});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.attribute(value);
    return Container(
      width: size,
      height: size * 0.82,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? c : c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Text(
        '$value',
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w800,
          color: filled ? Colors.white : c,
          fontFeatures: AppText.tabular,
        ),
      ),
    );
  }
}

/// Coloured position code chip (GK amber, DEF blue, MID green, ATT red).
class PositionChip extends StatelessWidget {
  final String code;
  final double fontSize;
  const PositionChip(this.code, {super.key, this.fontSize = 10});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.position(code);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.5,
        vertical: fontSize * 0.18,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: c,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// W / D / L form square, labelled in Uzbek (G / D / M).
class FormChip extends StatelessWidget {
  final String result;
  final double size;
  const FormChip(this.result, {super.key, this.size = 20});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    margin: EdgeInsets.only(right: 3),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.result(result),
      borderRadius: BorderRadius.circular(size * 0.24),
    ),
    child: Text(
      switch (result) {
        'W' => 'G',
        'L' => 'M',
        _ => 'D',
      },
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: size * 0.52,
      ),
    ),
  );
}

/// Label/value row used in summaries.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;
  const InfoRow(
    this.label,
    this.value, {
    super.key,
    this.valueColor,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(tr(label), style: AppText.small)),
        SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: AppText.number.copyWith(
              fontSize: 13,
              color: valueColor ?? AppColors.ink,
            ),
          ),
        ),
        if (trailing != null) ...[SizedBox(width: 6), trailing!],
      ],
    ),
  );
}

/// Two-sided statistic in the SofaScore style: the leading side's value is
/// highlighted and both bars grow outward from the middle.
class StatCompareRow extends StatelessWidget {
  final String label;
  final String homeText, awayText;
  final double home, away;
  final bool higherIsBetter;
  final Color homeColor, awayColor;
  const StatCompareRow({
    super.key,
    required this.label,
    required this.homeText,
    required this.awayText,
    required this.home,
    required this.away,
    this.higherIsBetter = true,
    this.homeColor = AppColors.primary,
    this.awayColor = const Color(0xFF16A6A0),
  });
  @override
  Widget build(BuildContext context) {
    final total = home + away;
    final hs = total <= 0 ? 0.0 : home / total;
    final as = total <= 0 ? 0.0 : away / total;
    final homeLeads = higherIsBetter ? home > away : home < away;
    final awayLeads = higherIsBetter ? away > home : away < home;
    Widget value(String t, bool lead, Color c) => Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: lead ? c : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        t,
        style: AppText.number.copyWith(
          fontSize: 13,
          color: lead ? Colors.white : AppColors.ink,
        ),
      ),
    );
    Widget bar(double share, bool lead, Color c, bool left) => Expanded(
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(3),
        ),
        alignment: left ? Alignment.centerRight : Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: share.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: lead ? c : c.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              value(homeText, homeLeads, homeColor),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              value(awayText, awayLeads, awayColor),
            ],
          ),
          SizedBox(height: 6),
          Row(
            children: [
              bar(hs, homeLeads, homeColor, true),
              SizedBox(width: 6),
              bar(as, awayLeads, awayColor, false),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pill segmented control used for in-card filters.
class PillTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const PillTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: Material(
              color: i == index ? AppColors.primary : AppColors.surface,
              shape: StadiumBorder(
                side: BorderSide(
                  color: i == index ? AppColors.primary : AppColors.line,
                ),
              ),
              child: InkWell(
                customBorder: StadiumBorder(),
                onTap: () => onChanged(i),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  child: Text(
                    tr(labels[i]),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: i == index ? Colors.white : AppColors.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class LiveDot extends StatefulWidget {
  final Color color;
  const LiveDot({super.key, this.color = AppColors.live});
  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 900),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
    child: Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    ),
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({super.key, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 28, horizontal: 16),
    child: Column(
      children: [
        Icon(icon, size: 34, color: AppColors.ink3),
        SizedBox(height: 10),
        Text(tr(text), textAlign: TextAlign.center, style: AppText.small),
      ],
    ),
  );
}

/// Thin progress meter with label and value.
class MeterRow extends StatelessWidget {
  final String label;
  final double value; // 0–1
  final String trailing;
  final Color? color;
  const MeterRow({
    super.key,
    required this.label,
    required this.value,
    required this.trailing,
    this.color,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 7),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(tr(label), style: AppText.small)),
            Text(trailing, style: AppText.number.copyWith(fontSize: 13)),
          ],
        ),
        SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 6,
            color: color ?? AppColors.primary,
            backgroundColor: AppColors.surfaceAlt,
          ),
        ),
      ],
    ),
  );
}

/// Stat tile: big number over a caption.
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  const StatTile(this.value, this.label, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          value,
          style: AppText.number.copyWith(
            fontSize: 20,
            color: color ?? AppColors.ink,
          ),
        ),
      ),
      SizedBox(height: 2),
      Text(tr(label), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
    ],
  );
}

/// Sparkline / area chart for balances and trends.
class TrendChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;
  const TrendChart({
    super.key,
    required this.values,
    this.color = AppColors.primary,
    this.height = 120,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _TrendPainter(values, color)),
  );
}

class _TrendPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _TrendPainter(this.values, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (values.length < 2) {
      final tp = TextPainter(
        text: TextSpan(
          text: tr('Grafik birinchi turdan keyin paydo bo‘ladi'),
          style: TextStyle(fontSize: 12, color: AppColors.ink3),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height / 2 - tp.height / 2));
      return;
    }
    final lo = values.reduce(min), hi = values.reduce(max);
    final span = (hi - lo).abs() < 1e-9 ? 1.0 : hi - lo;
    Offset at(int i) => Offset(
      size.width * i / (values.length - 1),
      size.height - 6 - (values[i] - lo) / span * (size.height - 12),
    );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      final a = at(i - 1), b = at(i);
      final mid = (a.dx + b.dx) / 2;
      path.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(at(values.length - 1), 4, Paint()..color = color);
    canvas.drawCircle(
      at(values.length - 1),
      2,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.values != values || old.color != color;
}

String formatMoney(num n, {int digits = 1}) {
  final sign = n < 0 ? '-' : '';
  final a = n.abs();
  if (a >= 1000000000) {
    return '$sign€${(a / 1000000000).toStringAsFixed(2)}B';
  }
  if (a >= 1000000) return '$sign€${(a / 1000000).toStringAsFixed(digits)}M';
  if (a >= 1000) return '$sign€${(a / 1000).toStringAsFixed(0)}K';
  return '$sign€${a.round()}';
}

/// Shows a blocking loader while [action] runs (after one frame so the
/// spinner is visible even for synchronous simulations).
Future<T> runWithLoading<T>(
  BuildContext context,
  String message,
  FutureOr<T> Function() action,
) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Material(
                color: Colors.transparent,
                child: Text(message, style: AppText.bodyStrong),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await Future<void>.delayed(Duration(milliseconds: 60));
  try {
    return await action();
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

/// Full-screen branded loader.
class LoadingView extends StatelessWidget {
  final String message;
  const LoadingView({super.key, this.message = 'Yuklanmoqda…'});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.sports_soccer, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          Text(tr('FOOTBALL TOP MANAGER 2027'), style: AppText.overline),
          const SizedBox(height: 20),
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: 12),
          Text(tr(message), style: AppText.small),
        ],
      ),
    ),
  );
}
