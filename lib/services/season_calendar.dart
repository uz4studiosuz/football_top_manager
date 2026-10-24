/// Real-date season calendar from mid-August to May with FIFA-style
/// summer and winter transfer windows.
///
/// The 8-club Super League plays 14 Saturdays with a winter break; larger
/// leagues (e.g. 38-round Premier League) play weekly, skip international
/// breaks and squeeze midweek rounds into the festive period.
class SeasonCalendar {
  final int year; // season start year, e.g. 2026 → 2026/27
  final int rounds;
  const SeasonCalendar(this.year, [this.rounds = 14]);

  static const _superOffsets = [
    0, 14, 35, 49, 70, 84, 105, 126, 154, 168, 189, 210, 238, 266, //
  ];
  static const months = [
    'Yanvar',
    'Fevral',
    'Mart',
    'Aprel',
    'May',
    'Iyun',
    'Iyul',
    'Avgust',
    'Sentabr',
    'Oktabr',
    'Noyabr',
    'Dekabr',
  ];
  static const weekdays = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

  String get label => '$year/${(year + 1) % 100}';

  DateTime get firstMatchDay {
    var d = DateTime(year, 8, 15);
    while (d.weekday != DateTime.saturday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  static bool _internationalBreak(DateTime d) =>
      ((d.month == 9 || d.month == 10 || d.month == 11) && d.day >= 8 && d.day <= 14) ||
      (d.month == 3 && d.day >= 22 && d.day <= 28);

  static bool _festive(DateTime d) => (d.month == 12 && d.day >= 20) || (d.month == 1 && d.day <= 6);

  List<DateTime> get _weekly {
    final dates = <DateTime>[];
    var d = firstMatchDay;
    while (dates.length < rounds) {
      if (!_internationalBreak(d)) {
        dates.add(d);
        if (_festive(d) && dates.length < rounds) dates.add(d.add(const Duration(days: 3)));
      }
      d = d.add(const Duration(days: 7));
    }
    final lastDay = DateTime(year + 1, 5, 24);
    if (!dates.last.isAfter(lastDay)) return dates;
    // Not enough weekends (46-round Championship): Tuesday rounds are
    // spread evenly through the season, on top of the festive ones.
    final weekends = <DateTime>[
      for (var s = firstMatchDay; !s.isAfter(lastDay); s = s.add(const Duration(days: 7)))
        if (!_internationalBreak(s)) s,
    ];
    final plain = [for (var i = 0; i < weekends.length; i++) if (!_festive(weekends[i])) i];
    final festive = weekends.length - plain.length;
    final need = (rounds - weekends.length - festive).clamp(0, plain.length);
    final midweek = {for (var k = 0; k < need; k++) plain[((k + 0.5) * plain.length / need).floor()]};
    final dense = <DateTime>[];
    for (var i = 0; i < weekends.length; i++) {
      dense.add(weekends[i]);
      if (_festive(weekends[i]) || midweek.contains(i)) dense.add(weekends[i].add(const Duration(days: 3)));
    }
    return dense.take(rounds).toList();
  }

  DateTime dateOfRound(int round) {
    final r = (round - 1).clamp(0, rounds - 1);
    if (rounds == 14) return firstMatchDay.add(Duration(days: _superOffsets[r]));
    return _weekly[r];
  }

  DateTime get seasonEnd => dateOfRound(rounds).add(const Duration(days: 14));
  DateTime get summerOpen => DateTime(year, 6, 16);
  DateTime get summerClose => DateTime(year, 9, 1, 23, 59);
  DateTime get winterOpen => DateTime(year + 1, 1, 1);
  DateTime get winterClose => DateTime(year + 1, 2, 2, 23, 59);

  bool windowOpenOn(DateTime d) =>
      (!d.isBefore(summerOpen) && !d.isAfter(summerClose)) ||
      (!d.isBefore(winterOpen) && !d.isAfter(winterClose));

  /// Days covered by a round (until the next match day); finance is charged
  /// per day so midweek rounds cost proportionally less.
  int daysAfterRound(int round) => round >= rounds
      ? 14
      : dateOfRound(round + 1).difference(dateOfRound(round)).inDays.clamp(1, 42);

  /// Whole weeks covered by a round (at least one).
  int weeksAfterRound(int round) => (daysAfterRound(round) / 7).round().clamp(1, 6);

  static String format(DateTime d, {bool year = false}) =>
      '${d.day} ${months[d.month - 1]}${year ? ' ${d.year}' : ''}';
  static String short(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
  static String weekday(DateTime d) => weekdays[d.weekday - 1];
}
