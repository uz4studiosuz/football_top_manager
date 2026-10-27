import '../models/club.dart';

/// Evaluates one saved match-day rule. Null means the rule has not triggered.
TeamTactics? automaticTactics(Map<String, dynamic> rule, {
  required int minute,
  required int goalsFor,
  required int goalsAgainst,
  required TeamPlaystyle opponentStyle,
  required TeamTactics current,
}) {
  if (rule['enabled'] != true || minute < ((rule['minute'] as num?)?.toInt() ?? 60)) return null;
  final score = rule['score'] ?? 'any';
  if (score == 'losing' && goalsFor >= goalsAgainst ||
      score == 'winning' && goalsFor <= goalsAgainst ||
      score == 'drawing' && goalsFor != goalsAgainst) {
    return null;
  }
  final opponent = rule['opponent'] ?? 'any';
  if (opponent != 'any' && opponent != opponentStyle.name) return null;
  return switch (rule['action'] ?? 'press') {
    'press' => current.copyWith(pressing: 5, counterPress: true),
    'attack' => current.copyWith(attackingIntensity: 5, tempo: 4, timeWasting: false),
    'defend' => current.copyWith(defensiveLine: 2, attackingIntensity: 2, compactness: 5),
    'wide' => current.copyWith(attackingArea: AttackingArea.wide, width: 5),
    _ => null,
  };
}
