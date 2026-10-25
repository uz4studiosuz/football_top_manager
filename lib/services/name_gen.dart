import 'dart:math';

/// Invented names that sound real but belong to nobody: managers, squads
/// of new clubs, club and stadium names.
class NameGen {
  static const _firstStart = [
    'Al', 'Bran', 'Cael', 'Da', 'El', 'Fa', 'Ga', 'Hen', 'Is', 'Jo', 'Ka', 'Le', 'Ma', 'Ni', 'Or', 'Pa',
    'Ra', 'Se', 'Ta', 'Va', 'Zo', 'Lu', 'Mi', 'Ro', 'Ti', 'An', 'Bel', 'Ce', 'Dor', 'Er', 'Fi', 'Gil',
  ];
  static const _firstMid = ['', '', '', 'ri', 'lo', 'ma', 've', 'ni', 'ta', 'de', 'si'];
  static const _firstEnd = ['n', 's', 'r', 'o', 'an', 'el', 'io', 'ar', 'en', 'is', 'us', 'ik', 'on', 'em', 'ai'];
  static const _lastStart = [
    'Bel', 'Cor', 'Dar', 'Fen', 'Gal', 'Har', 'Kes', 'Lor', 'Mar', 'Nor', 'Pel', 'Ros', 'Sal', 'Tor', 'Val',
    'Wen', 'Zar', 'Bran', 'Cal', 'Del', 'Est', 'Fal', 'Gor', 'Hal', 'Ivan', 'Kor', 'Lem', 'Mor', 'Ost', 'Ren',
  ];
  static const _lastMid = ['', '', 'a', 'e', 'i', 'o', 'an', 'er', 'el', 'ov'];
  static const _lastEnd = [
    'ton', 'ley', 'ford', 'ini', 'ez', 'son', 'ov', 'ard', 'elli', 'ers', 'mann', 'ic', 'os', 'ard', 'ane', 'ek',
  ];
  static const _townEnd = ['by', 'ford', 'ham', 'ville', 'ton', 'burg', 'ia', 'ora', 'mont', 'dale', 'port', 'field'];
  static const _clubWord = ['FC', 'United', 'Athletic', 'Rovers', 'City', 'Sporting', 'Wanderers', 'Albion', 'Olympic', 'Town'];

  static String first(Random rnd) =>
      '${_firstStart[rnd.nextInt(_firstStart.length)]}${_firstMid[rnd.nextInt(_firstMid.length)]}${_firstEnd[rnd.nextInt(_firstEnd.length)]}';

  static String last(Random rnd) =>
      '${_lastStart[rnd.nextInt(_lastStart.length)]}${_lastMid[rnd.nextInt(_lastMid.length)]}${_lastEnd[rnd.nextInt(_lastEnd.length)]}';

  static String person(Random rnd) => '${first(rnd)} ${last(rnd)}';

  static String town(Random rnd) => '${_lastStart[rnd.nextInt(_lastStart.length)]}${_townEnd[rnd.nextInt(_townEnd.length)]}';

  static String club(Random rnd) {
    final t = town(rnd), w = _clubWord[rnd.nextInt(_clubWord.length)];
    return rnd.nextBool() ? '$t $w' : (w == 'FC' ? 'FC $t' : '$t $w');
  }

  static String stadium(Random rnd, [String? club]) {
    final base = club?.split(' ').firstWhere((w) => w.length > 2, orElse: () => town(rnd)) ?? town(rnd);
    return switch (rnd.nextInt(4)) {
      0 => '$base Arena',
      1 => '$base Park',
      2 => '${last(rnd)} Stadium',
      _ => '$base Ground',
    };
  }

  /// "F. Last" from a full name.
  static String short(String name) {
    final parts = name.split(' ');
    return parts.length < 2 ? name : '${parts.first[0]}. ${parts.sublist(1).join(' ')}';
  }
}
