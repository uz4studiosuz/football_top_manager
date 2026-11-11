import 'dart:math';
import '../models/club.dart';
import '../models/player.dart';
import '../l10n/l10n.dart';

enum TrainingSession {
  rest('Dam olish', 0),
  recovery('Tiklanish', -1),
  possession('To‘p nazorati', 1.0),
  attacking('Hujum kombinatsiyalari', 1.3),
  defending('Himoya shakli', 1.1),
  pressing('Pressing mashqi', 1.8),
  conditioning('Jismoniy tayyorgarlik', 2.0),
  tactical('Taktik mashg‘ulot', 0.7),
  setPieces('Standart vaziyatlar', 0.6),
  matchPrep('O‘yinga tayyorgarlik', 0.4);

  const TrainingSession(this.text, this.load);
  final String text;
  final double load;
  String get label => tr(text);
}

/// A repeating Monday–Sunday microcycle. Match days override all three
/// sessions; the day after a match starts with compulsory recovery.
class TrainingSchedule {
  List<TrainingSession> sessions = balanced();
  int intensity = 2;
  final Map<String, double> familiarity = {};
  static List<TrainingSession> balanced() => [
    TrainingSession.recovery,
    TrainingSession.tactical,
    TrainingSession.rest,
    TrainingSession.possession,
    TrainingSession.attacking,
    TrainingSession.rest,
    TrainingSession.conditioning,
    TrainingSession.defending,
    TrainingSession.rest,
    TrainingSession.tactical,
    TrainingSession.pressing,
    TrainingSession.rest,
    TrainingSession.setPieces,
    TrainingSession.matchPrep,
    TrainingSession.rest,
    TrainingSession.matchPrep,
    TrainingSession.rest,
    TrainingSession.rest,
    TrainingSession.recovery,
    TrainingSession.rest,
    TrainingSession.rest,
  ];

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  static bool isMatchDay(DateTime date, Iterable<DateTime> matches) =>
      matches.any((m) => sameDay(date, m));

  TrainingSession session(DateTime date, int slot, Iterable<DateTime> matches) {
    if (isMatchDay(date, matches)) return TrainingSession.rest;
    if (slot == 0 &&
        isMatchDay(date.subtract(const Duration(days: 1)), matches)) {
      return TrainingSession.recovery;
    }
    return sessions[(date.weekday - 1) * 3 + slot];
  }

  TrainingWorkload workload(
    DateTime start,
    int days,
    Iterable<DateTime> matches,
  ) {
    var load = 0.0, work = 0.0, tactics = 0.0, recovery = 0.0;
    final drills = <TrainingSession, double>{};
    final multiplier = [0.0, 0.7, 1.0, 1.35][intensity.clamp(1, 3)];
    for (var d = 0; d < days; d++) {
      final date = start.add(Duration(days: d));
      for (var slot = 0; slot < 3; slot++) {
        final s = session(date, slot, matches);
        if (s == TrainingSession.recovery) {
          recovery += 1;
          continue;
        }
        if (s == TrainingSession.rest) continue;
        load += s.load * multiplier;
        work += multiplier;
        drills[s] = (drills[s] ?? 0) + multiplier;
        if (s == TrainingSession.tactical ||
            s == TrainingSession.matchPrep ||
            s == TrainingSession.possession) {
          tactics += multiplier;
        }
      }
    }
    return TrainingWorkload(load, work, tactics, recovery, days, drills);
  }

  double understanding(TeamTactics t) =>
      familiarity['${t.formation.name}:${t.playstyle.name}'] ?? 45;

  void complete(TeamTactics t, TrainingWorkload work) {
    final key = '${t.formation.name}:${t.playstyle.name}';
    for (final other in familiarity.keys.toList()) {
      if (other != key) {
        familiarity[other] = max(25, familiarity[other]! - work.days * 0.08);
      }
    }
    familiarity[key] =
        (understanding(t) + work.tactics * 0.65 + work.days * 0.12).clamp(
          25,
          100,
        );
  }

  void reset() {
    sessions = balanced();
    intensity = 2;
    familiarity.clear();
  }

  Map<String, dynamic> toMap() => {
    'sessions': sessions.map((s) => s.name).toList(),
    'intensity': intensity,
    'familiarity': Map<String, double>.from(familiarity),
  };
  void restore(Map? map) {
    reset();
    if (map == null) return;
    final list = map['sessions'];
    if (list is List && list.length == 21) {
      sessions = [
        for (final s in list)
          TrainingSession.values.asNameMap()[s] ?? TrainingSession.rest,
      ];
    }
    intensity = ((map['intensity'] as num?)?.toInt() ?? 2).clamp(1, 3);
    (map['familiarity'] as Map? ?? {}).forEach((k, v) {
      if (k is String && v is num) familiarity[k] = v.toDouble().clamp(0, 100);
    });
  }
}

class TrainingWorkload {
  final Map<TrainingSession, double> drills;
  final double load, work, tactics, recovery;
  final int days;
  const TrainingWorkload(
    this.load,
    this.work,
    this.tactics,
    this.recovery,
    this.days, [
    this.drills = const {},
  ]);
  static const _skills = <TrainingSession, Set<String>>{
    TrainingSession.possession: {
      'lowPass',
      'loftedPass',
      'ballControl',
      'tightPossession',
      'dribbling',
    },
    TrainingSession.attacking: {
      'finishing',
      'attackingAwareness',
      'heading',
      'kickingPower',
      'curl',
    },
    TrainingSession.defending: {
      'defensiveAwareness',
      'defensiveEngagement',
      'tackling',
      'gkAwareness',
      'gkCatching',
      'gkParrying',
    },
    TrainingSession.pressing: {
      'defensiveEngagement',
      'aggression',
      'stamina',
      'acceleration',
    },
    TrainingSession.conditioning: {
      'stamina',
      'speed',
      'acceleration',
      'physicalContact',
      'jumping',
      'balance',
      'gkReach',
      'gkReflexes',
    },
    TrainingSession.tactical: {
      'lowPass',
      'defensiveAwareness',
      'attackingAwareness',
      'gkAwareness',
    },
    TrainingSession.setPieces: {
      'setPieceTaking',
      'curl',
      'heading',
      'jumping',
      'gkCatching',
      'gkReach',
    },
    TrainingSession.matchPrep: {
      'ballControl',
      'lowPass',
      'defensiveAwareness',
      'gkAwareness',
    },
  };
  double practice(String key) => drills.entries.fold<double>(
    0,
    (sum, e) => sum + ((_skills[e.key]?.contains(key) ?? false) ? e.value : 0),
  );
  String chooseAttribute(List<String> keys, Random random) {
    final weights = [for (final key in keys) .25 + practice(key)];
    var roll = random.nextDouble() * weights.fold<double>(0, (a, b) => a + b);
    for (var i = 0; i < keys.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return keys[i];
    }
    return keys.last;
  }

  double get dailyLoad => load / max(1, days);

  /// Costs fitness after natural between-match recovery; recovery sessions
  /// trade development time for freshness rather than granting free growth.
  int get fitnessCost => max(0, (load * 1.15 - recovery * 2).round());
  double get development =>
      work == 0 ? 0 : (work / max(1, days) * 0.7).clamp(0.15, 1.4);
  bool get overloaded => dailyLoad > 2.7;
}

class TacticalReadiness {
  final int complexity, understanding, ability, cohesion, effectiveness;
  const TacticalReadiness(
    this.complexity,
    this.understanding,
    this.ability,
    this.cohesion,
    this.effectiveness,
  );

  factory TacticalReadiness.evaluate(
    Club club,
    TrainingSchedule training,
    int cohesion,
  ) {
    final t = club.tactics;
    final instructions = club.startingXI
        .where((p) => p.instruction != PlayerInstruction.balanced)
        .length;
    final complexity =
        (24 +
                instructions * 3 +
                (t.counterPress ? 12 : 0) +
                (t.offsideTrap ? 10 : 0) +
                (t.flexiblePositioning ? 10 : 0) +
                (t.tempo - 3).abs() * 4 +
                (t.pressing - 3).abs() * 3)
            .clamp(0, 100);
    final xi = club.startingXI;
    final ability = xi.isEmpty
        ? 50
        : (xi.fold<double>(
                    0,
                    (sum, p) =>
                        sum +
                        (p.stats.lowPass +
                                p.stats.ballControl +
                                p.stats.defensiveAwareness) /
                            3,
                  ) /
                  xi.length)
              .round();
    final understanding = training.understanding(t).round();
    final effectiveness =
        (ability * 0.45 +
                understanding * 0.35 +
                cohesion * 0.2 -
                max(0, complexity - ability) * 0.35)
            .round()
            .clamp(0, 100);
    return TacticalReadiness(
      complexity,
      understanding,
      ability,
      cohesion,
      effectiveness,
    );
  }
}
