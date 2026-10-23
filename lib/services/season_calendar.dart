/// Real-date season calendar: 14 Saturday match days from mid-August to May
/// with a winter break, plus FIFA-style summer and winter transfer windows.
class SeasonCalendar {
  final int year; // season start year, e.g. 2026 → 2026/27
  const SeasonCalendar(this.year);

  static const _offsets = [
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

  DateTime dateOfRound(int round) =>
      firstMatchDay.add(Duration(days: _offsets[(round - 1).clamp(0, 13)]));

  DateTime get seasonEnd => dateOfRound(14).add(const Duration(days: 14));
  DateTime get summerOpen => DateTime(year, 6, 16);
  DateTime get summerClose => DateTime(year, 9, 1, 23, 59);
  DateTime get winterOpen => DateTime(year + 1, 1, 1);
  DateTime get winterClose => DateTime(year + 1, 2, 2, 23, 59);

  bool windowOpenOn(DateTime d) =>
      (!d.isBefore(summerOpen) && !d.isAfter(summerClose)) ||
      (!d.isBefore(winterOpen) && !d.isAfter(winterClose));

  /// Whole weeks covered by a round (until the next match day).
  int weeksAfterRound(int round) => round >= 14
      ? 2
      : (dateOfRound(round + 1).difference(dateOfRound(round)).inDays / 7)
            .round()
            .clamp(1, 6);

  static String format(DateTime d, {bool year = false}) =>
      '${d.day} ${months[d.month - 1]}${year ? ' ${d.year}' : ''}';
  static String short(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
  static String weekday(DateTime d) => weekdays[d.weekday - 1];
}
