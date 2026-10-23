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
  };
}

class ManagerProfile {
  String name, avatarId, nationality, countryFlag;
  int age, matchesManaged, wins, draws, losses, trophies;
  ManagerPhilosophy philosophy;
  FaceConfig face;
  final Map<ManagerPhilosophy, int> proficiency;
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
  }) : face = face ?? FaceConfig.seed(name),
       proficiency = {
         for (final p in ManagerPhilosophy.values) p: proficiency?[p] ?? 70,
       };
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
  );
}
