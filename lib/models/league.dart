import 'package:flutter/material.dart';

/// O'yindagi voqea turlari (Match Events)
enum MatchEventType {
  kickoff('O\'yin boshlandi'),
  pass('Xavfli pas'),
  shot('Zarba'),
  save('Seyv'),
  goal('GOL!'),
  foul('Qoidabuzarlik'),
  yellowCard('Sariq kartochka'),
  redCard('Qizil kartochka'),
  halfTime('Tanaffus'),
  fullTime('O\'yin yakunlandi'),
  substitution('O\'yinchi almashtirish');

  const MatchEventType(this.label);
  final String label;
  IconData get iconData => switch (this) {
    kickoff => Icons.sports_outlined,
    pass => Icons.near_me_outlined,
    shot => Icons.gps_fixed,
    save => Icons.pan_tool_outlined,
    goal => Icons.sports_soccer,
    foul => Icons.front_hand_outlined,
    yellowCard || redCard => Icons.style_outlined,
    halfTime => Icons.pause_circle_outline,
    fullTime => Icons.flag_outlined,
    substitution => Icons.swap_horiz,
  };
}

/// O'yin simulyatsiyasi voqeasi
class MatchEvent {
  final int minute;
  final MatchEventType type;
  final String description;
  final String clubId;
  final String? playerName;
  final bool isHomeTeam;
  final String? assistPlayerId;
  const MatchEvent({
    required this.minute,
    required this.type,
    required this.description,
    required this.clubId,
    this.playerName,
    required this.isHomeTeam,
    this.assistPlayerId,
  });
}

/// Uchrashuv taqvimi (Fixture)
class Fixture {
  final String id;
  final int round; // Tur raqami (1.0.14)
  final String homeClubId;
  final String awayClubId;
  int? homeScore;
  int? awayScore;
  bool isPlayed;
  List<MatchEvent> events;
  // Realistik statistikalar
  int homePasses, awayPasses, homeCompletedPasses, awayCompletedPasses;
  int homeShots;
  int awayShots;
  int homeShotsOnTarget;
  int awayShotsOnTarget;
  int homePossession; // Masalan: 56 (%)
  int awayPossession; // Masalan: 44 (%)
  int homeCorners;
  int awayCorners;
  int homeFouls;
  int awayFouls;
  double homeXG;
  double awayXG;
  Fixture({
    required this.id,
    required this.round,
    required this.homeClubId,
    required this.awayClubId,
    this.homeScore,
    this.awayScore,
    this.isPlayed = false,
    List<MatchEvent>? events,
    this.homePasses = 0,
    this.awayPasses = 0,
    this.homeCompletedPasses = 0,
    this.awayCompletedPasses = 0,
    this.homeShots = 0,
    this.awayShots = 0,
    this.homeShotsOnTarget = 0,
    this.awayShotsOnTarget = 0,
    this.homePossession = 50,
    this.awayPossession = 50,
    this.homeCorners = 0,
    this.awayCorners = 0,
    this.homeFouls = 0,
    this.awayFouls = 0,
    this.homeXG = 0.0,
    this.awayXG = 0.0,
  }) : events = events ?? [];
  bool get hasResult => isPlayed && homeScore != null && awayScore != null;
  String get scoreDisplay => hasResult ? '$homeScore - $awayScore' : 'VS';
}

/// Liga turnir jadvali qatori (Standings Row)
class LeagueStanding {
  final String clubId;
  int played;
  int won;
  int drawn;
  int lost;
  int goalsFor;
  int goalsAgainst;
  List<String> formGuide; // 'W', 'D', 'L' (oxirgi 5 ta o'yin)
  LeagueStanding({
    required this.clubId,
    this.played = 0,
    this.won = 0,
    this.drawn = 0,
    this.lost = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
    List<String>? formGuide,
  }) : formGuide = formGuide ?? [];
  int get goalDifference => goalsFor - goalsAgainst;
  int get points => (won * 3) + drawn;
  void recordMatch({required int myGoals, required int opponentGoals}) {
    played++;
    goalsFor += myGoals;
    goalsAgainst += opponentGoals;
    if (myGoals > opponentGoals) {
      won++;
      _addForm('W');
    } else if (myGoals == opponentGoals) {
      drawn++;
      _addForm('D');
    } else {
      lost++;
      _addForm('L');
    }
  }

  void _addForm(String result) {
    formGuide.add(result);
    if (formGuide.length > 5) {
      formGuide.removeAt(0);
    }
  }

  LeagueStanding copy() {
    return LeagueStanding(
      clubId: clubId,
      played: played,
      won: won,
      drawn: drawn,
      lost: lost,
      goalsFor: goalsFor,
      goalsAgainst: goalsAgainst,
      formGuide: List<String>.from(formGuide),
    );
  }
}
