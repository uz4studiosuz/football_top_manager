import 'face.dart';
import 'club.dart';
import 'package:flutter/material.dart';

enum ManagerPhilosophy {
  possession(
    'Possession Game',
    'Qisqa pas, uchburchaklar va to‘p nazorati.',
    Icons.hub_outlined,
  ),
  quickCounter(
    'Quick Counter',
    'To‘p olingach bo‘sh hududga tez hujum.',
    Icons.bolt_outlined,
  ),
  longBallCounter(
    'Long Ball Counter',
    'Past blokdan hujumchiga uzun uzatma.',
    Icons.arrow_outward,
  ),
  outWide(
    'Out Wide',
    'Qanot kengligi, kross va jarima maydoniga yugurish.',
    Icons.open_in_full,
  ),
  longBall(
    'Long Ball',
    'Tayanch hujumchi, ikkinchi to‘p va vertikal uzatmalar.',
    Icons.north_east,
  ),
  overload(
    'Overload',
    'Bir tomonda son ustunligi, keskin pas bilan ochiq tomonga o‘tish.',
    Icons.compare_arrows_rounded,
  );

  const ManagerPhilosophy(this.title, this.description, this.icon);
  final String title, description;
  final IconData icon;
  Color get accentColor => const Color(0xFF1769E0);
  static ManagerPhilosophy forStyle(TeamPlaystyle style) => switch (style) {
    TeamPlaystyle.possession => possession,
    TeamPlaystyle.quickCounter || TeamPlaystyle.highPressing => quickCounter,
    TeamPlaystyle.longBallCounter => longBallCounter,
    TeamPlaystyle.outWide => outWide,
    TeamPlaystyle.longBall => longBall,
    TeamPlaystyle.overload => overload,
  };
}

class ManagerProfile {
  String name, avatarId, nationality, countryFlag;
  int age, matchesManaged, wins, draws, losses, trophies;
  ManagerPhilosophy philosophy;
  FaceConfig face;
  final Map<ManagerPhilosophy, int> proficiency;
  final Map<ManagerPhilosophy, int> experience;
  static const xpPerLevel = 8;
  ManagerProfile({
    required this.name,
    this.avatarId = 'custom',
    this.nationality = 'O‘zbekiston',
    this.countryFlag = '🇺🇿',
    this.age = 35,
    this.philosophy = ManagerPhilosophy.possession,
    this.matchesManaged = 0,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.trophies = 0,
    FaceConfig? face,
    Map<ManagerPhilosophy, int>? proficiency,
    Map<ManagerPhilosophy, int>? experience,
  }) : face = face ?? FaceConfig.seed(name),
       proficiency = {
         for (final p in ManagerPhilosophy.values) p: proficiency?[p] ?? 70,
       },
       experience = {
         for (final p in ManagerPhilosophy.values) p: experience?[p] ?? 0,
       };

  /// Adds experience to a philosophy; every [xpPerLevel] points raise the
  /// rating by one (max 100). Returns the number of levels gained.
  int gainExperience(ManagerPhilosophy style, int xp) {
    var levels = 0;
    experience[style] = (experience[style] ?? 0) + xp;
    while ((experience[style] ?? 0) >= xpPerLevel && (proficiency[style] ?? 70) < 100) {
      experience[style] = experience[style]! - xpPerLevel;
      proficiency[style] = (proficiency[style] ?? 70) + 1;
      levels++;
    }
    return levels;
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'avatarId': avatarId,
    'nationality': nationality,
    'countryFlag': countryFlag,
    'age': age,
    'philosophy': philosophy.name,
    'matchesManaged': matchesManaged,
    'wins': wins,
    'draws': draws,
    'losses': losses,
    'trophies': trophies,
    'face': face.toMap(),
    'proficiency': {for (final e in proficiency.entries) e.key.name: e.value},
    'experience': {for (final e in experience.entries) e.key.name: e.value},
  };

  factory ManagerProfile.fromMap(Map<String, dynamic> m) {
    Map<ManagerPhilosophy, int> read(dynamic raw) => {
      for (final e in Map<String, dynamic>.from(raw ?? {}).entries)
        if (ManagerPhilosophy.values.asNameMap()[e.key] != null)
          ManagerPhilosophy.values.asNameMap()[e.key]!: (e.value as num).toInt(),
    };
    return ManagerProfile(
      name: m['name'],
      avatarId: m['avatarId'] ?? 'custom',
      nationality: m['nationality'] ?? 'O‘zbekiston',
      countryFlag: m['countryFlag'] ?? '🇺🇿',
      age: m['age'] ?? 35,
      philosophy: ManagerPhilosophy.values.asNameMap()[m['philosophy']] ?? ManagerPhilosophy.possession,
      matchesManaged: m['matchesManaged'] ?? 0,
      wins: m['wins'] ?? 0,
      draws: m['draws'] ?? 0,
      losses: m['losses'] ?? 0,
      trophies: m['trophies'] ?? 0,
      face: FaceConfig.fromMap(Map<String, dynamic>.from(m['face'] ?? {})),
      proficiency: read(m['proficiency']),
      experience: read(m['experience']),
    );
  }
  int ratingFor(TeamPlaystyle style) =>
      proficiency[ManagerPhilosophy.forStyle(style)] ?? 70;
  double get winRate => matchesManaged > 0 ? wins / matchesManaged * 100 : 0;
  String get recordString => '$wins-$draws-$losses';
  String get reputationRank => matchesManaged < 10
      ? 'Yangi menejer'
      : winRate >= 60
      ? 'Yetakchi menejer'
      : 'Tajribali menejer';
  ManagerProfile copyWith({
    String? name,
    String? avatarId,
    String? nationality,
    String? countryFlag,
    int? age,
    ManagerPhilosophy? philosophy,
    int? matchesManaged,
    int? wins,
    int? draws,
    int? losses,
    int? trophies,
    FaceConfig? face,
  }) => ManagerProfile(
    name: name ?? this.name,
    avatarId: avatarId ?? this.avatarId,
    nationality: nationality ?? this.nationality,
    countryFlag: countryFlag ?? this.countryFlag,
    age: age ?? this.age,
    philosophy: philosophy ?? this.philosophy,
    matchesManaged: matchesManaged ?? this.matchesManaged,
    wins: wins ?? this.wins,
    draws: draws ?? this.draws,
    losses: losses ?? this.losses,
    trophies: trophies ?? this.trophies,
    face: face ?? this.face,
    proficiency: proficiency,
    experience: experience,
  );
}
