import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A country flag drawn from assets/flags (lipis/flag-icons, MIT) instead
/// of an emoji: emoji flags of England, Scotland and Wales show as a black
/// flag on most devices.
class FlagView extends StatelessWidget {
  /// The flag emoji stored in the data ("🇺🇿", "🏴").
  final String flag;

  /// Tells the UK nations apart (they share the black-flag emoji).
  final String? nationality;
  final double height;
  const FlagView(this.flag, {super.key, this.nationality, this.height = 14});

  static const _nations = {
    'Angliya': 'gb-eng',
    'Shotlandiya': 'gb-sct',
    'Uels': 'gb-wls',
    'Shimoliy Irlandiya': 'gb-nir',
  };

  /// flag-icons file name for an emoji (null when unknown).
  static String? code(String flag, [String? nationality]) {
    final nation = _nations[nationality];
    if (nation != null) return nation;
    final runes = flag.runes.toList();
    if (runes.length == 2 && runes.every((r) => r >= 0x1F1E6 && r <= 0x1F1FF)) {
      return String.fromCharCodes(runes.map((r) => r - 0x1F1E6 + 97));
    }
    if (flag.startsWith('🏴')) return 'gb-eng';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = code(flag, nationality);
    if (c == null) return Text(flag, style: TextStyle(fontSize: height));
    return ClipRRect(
      borderRadius: BorderRadius.circular(height * 0.15),
      child: SvgPicture.asset(
        'assets/flags/$c.svg',
        height: height,
        width: height * 4 / 3,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => SizedBox(height: height, width: height * 4 / 3),
      ),
    );
  }
}

/// Flag followed by a label, on one line.
class FlagLabel extends StatelessWidget {
  final String flag, label;
  final String? nationality;
  final TextStyle? style;
  final double height;
  const FlagLabel(this.flag, this.label, {super.key, this.nationality, this.style, this.height = 13});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      FlagView(flag, nationality: nationality, height: height),
      const SizedBox(width: 6),
      Flexible(child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
    ],
  );
}
