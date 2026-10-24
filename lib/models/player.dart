import 'dart:math';
import 'face.dart';
import 'playing_style.dart';
export 'playing_style.dart';
import 'package:flutter/foundation.dart';
import '../l10n/l10n.dart';

/// O'yinchi pozitsiyalari (eFootball / PES standarti)
enum PlayerPosition {
  // Hujum (Attack)
  cf('CF', 'Centre Forward', PositionCategory.attack),
  ss('SS', 'Second Striker', PositionCategory.attack),
  lwf('LWF', 'Left Wing Forward', PositionCategory.attack),
  rwf('RWF', 'Right Wing Forward', PositionCategory.attack),
  // Yarim himoya (Midfield)
  amf('AMF', 'Attacking Midfielder', PositionCategory.midfield),
  lmf('LMF', 'Left Midfielder', PositionCategory.midfield),
  rmf('RMF', 'Right Midfielder', PositionCategory.midfield),
  cmf('CMF', 'Central Midfielder', PositionCategory.midfield),
  dmf('DMF', 'Defensive Midfielder', PositionCategory.midfield),
  // Himoya va Darvoza (Defense & Goalkeeper)
  lb('LB', 'Left Back', PositionCategory.defense),
  rb('RB', 'Right Back', PositionCategory.defense),
  cb('CB', 'Centre Back', PositionCategory.defense),
  gk('GK', 'Goalkeeper', PositionCategory.goalkeeper);

  const PlayerPosition(this.code, this.fullName, this.category);
  final String code;
  final String fullName;
  final PositionCategory category;
  bool get isAttacker => category == PositionCategory.attack;
  bool get isMidfielder => category == PositionCategory.midfield;
  bool get isDefender => category == PositionCategory.defense;
  bool get isGoalkeeper => category == PositionCategory.goalkeeper;
  static PlayerPosition fromCode(String code) {
    // eFootball has no separate "ST": every centre forward is CF.
    if (code.toUpperCase() == 'ST') return PlayerPosition.cf;
    return PlayerPosition.values.firstWhere(
      (pos) => pos.code.toUpperCase() == code.toUpperCase(),
      orElse: () => PlayerPosition.cmf,
    );
  }
}

/// Pozitsiya toifasi
enum PositionCategory {
  attack('Hujum'),
  midfield('Yarim himoya'),
  defense('Himoya'),
  goalkeeper('Darvoza');

  const PositionCategory(this._label);
  final String _label;
  String get label => tr(_label);
}

/// Yetakchi oyoq
enum PreferredFoot {
  right('O\'ng (Right)'),
  left('Chap (Left)');

  const PreferredFoot(this._label);
  final String _label;
  String get label => tr(_label);
}

/// Canonical eFootball-style attributes, each bounded to 40–100.
@immutable
class PlayerStats {
  final int attackingAwareness;
  final int ballControl;
  final int dribbling;
  final int tightPossession;
  final int lowPass;
  final int loftedPass;
  final int finishing;
  final int heading;
  final int setPieceTaking;
  final int curl;
  final int defensiveAwareness;
  final int defensiveEngagement;
  final int tackling;
  final int aggression;
  final int gkAwareness;
  final int gkCatching;
  final int gkParrying;
  final int gkReflexes;
  final int gkReach;
  final int speed;
  final int acceleration;
  final int kickingPower;
  final int jumping;
  final int physicalContact;
  final int balance;
  final int stamina;
  const PlayerStats({
    required this.attackingAwareness,
    required this.ballControl,
    required this.dribbling,
    required this.tightPossession,
    required this.lowPass,
    required this.loftedPass,
    required this.finishing,
    required this.heading,
    required this.setPieceTaking,
    required this.curl,
    required this.defensiveAwareness,
    required this.defensiveEngagement,
    required this.tackling,
    required this.aggression,
    required this.gkAwareness,
    required this.gkCatching,
    required this.gkParrying,
    required this.gkReflexes,
    required this.gkReach,
    required this.speed,
    required this.acceleration,
    required this.kickingPower,
    required this.jumping,
    required this.physicalContact,
    required this.balance,
    required this.stamina,
  }) : assert(attackingAwareness >= 40 && attackingAwareness <= 100),
       assert(ballControl >= 40 && ballControl <= 100),
       assert(dribbling >= 40 && dribbling <= 100),
       assert(tightPossession >= 40 && tightPossession <= 100),
       assert(lowPass >= 40 && lowPass <= 100),
       assert(loftedPass >= 40 && loftedPass <= 100),
       assert(finishing >= 40 && finishing <= 100),
       assert(heading >= 40 && heading <= 100),
       assert(setPieceTaking >= 40 && setPieceTaking <= 100),
       assert(curl >= 40 && curl <= 100),
       assert(defensiveAwareness >= 40 && defensiveAwareness <= 100),
       assert(defensiveEngagement >= 40 && defensiveEngagement <= 100),
       assert(tackling >= 40 && tackling <= 100),
       assert(aggression >= 40 && aggression <= 100),
       assert(gkAwareness >= 40 && gkAwareness <= 100),
       assert(gkCatching >= 40 && gkCatching <= 100),
       assert(gkParrying >= 40 && gkParrying <= 100),
       assert(gkReflexes >= 40 && gkReflexes <= 100),
       assert(gkReach >= 40 && gkReach <= 100),
       assert(speed >= 40 && speed <= 100),
       assert(acceleration >= 40 && acceleration <= 100),
       assert(kickingPower >= 40 && kickingPower <= 100),
       assert(jumping >= 40 && jumping <= 100),
       assert(physicalContact >= 40 && physicalContact <= 100),
       assert(balance >= 40 && balance <= 100),
       assert(stamina >= 40 && stamina <= 100);
  static const labels = {
    'attackingAwareness': 'Attacking Awareness',
    'ballControl': 'Ball Control',
    'dribbling': 'Dribbling',
    'tightPossession': 'Tight Possession',
    'lowPass': 'Low Pass',
    'loftedPass': 'Lofted Pass',
    'finishing': 'Finishing',
    'heading': 'Heading',
    'setPieceTaking': 'Set Piece Taking',
    'curl': 'Curl',
    'defensiveAwareness': 'Defensive Awareness',
    'defensiveEngagement': 'Defensive Engagement',
    'tackling': 'Tackling',
    'aggression': 'Aggression',
    'gkAwareness': 'GK Awareness',
    'gkCatching': 'GK Catching',
    'gkParrying': 'GK Parrying',
    'gkReflexes': 'GK Reflexes',
    'gkReach': 'GK Reach',
    'speed': 'Speed',
    'acceleration': 'Acceleration',
    'kickingPower': 'Kicking Power',
    'jumping': 'Jumping',
    'physicalContact': 'Physical Contact',
    'balance': 'Balance',
    'stamina': 'Stamina',
  };
  static const groups = <String, List<String>>{
    'Hujum': [
      'attackingAwareness',
      'finishing',
      'heading',
      'kickingPower',
      'setPieceTaking',
      'curl',
    ],
    'To‘p bilan': ['ballControl', 'dribbling', 'tightPossession', 'balance'],
    'Pas': ['lowPass', 'loftedPass'],
    'Himoya': [
      'defensiveAwareness',
      'defensiveEngagement',
      'tackling',
      'aggression',
    ],
    'Darvozabon': [
      'gkAwareness',
      'gkCatching',
      'gkParrying',
      'gkReflexes',
      'gkReach',
    ],
    'Jismoniy': [
      'speed',
      'acceleration',
      'jumping',
      'physicalContact',
      'stamina',
    ],
  };
  int weighted(Map<String, double> weights) {
    final values = toMap();
    final sum = weights.entries.fold<double>(
      0,
      (total, e) => total + (values[e.key] as int) * e.value,
    );
    return (sum / weights.values.fold<double>(0, (a, b) => a + b))
        .round()
        .clamp(40, 100);
  }

  int get pace => ((speed + acceleration) / 2).round();
  int get shooting => weighted({
    'attackingAwareness': 0.2,
    'finishing': 0.5,
    'kickingPower': 0.3,
  });
  int get passing => weighted({'lowPass': 0.65, 'loftedPass': 0.35});
  int get dribblingStat => weighted({
    'ballControl': 0.3,
    'dribbling': 0.35,
    'tightPossession': 0.25,
    'balance': 0.1,
  });
  int get defending => weighted({
    'defensiveAwareness': 0.35,
    'defensiveEngagement': 0.25,
    'tackling': 0.4,
  });
  int get physicality => weighted({
    'physicalContact': 0.4,
    'stamina': 0.3,
    'jumping': 0.2,
    'aggression': 0.1,
  });
  int get gkRating => weighted({
    'gkAwareness': 0.25,
    'gkCatching': 0.15,
    'gkParrying': 0.15,
    'gkReflexes': 0.3,
    'gkReach': 0.15,
  });
  Map<String, dynamic> toMap() => {
    'attackingAwareness': attackingAwareness,
    'ballControl': ballControl,
    'dribbling': dribbling,
    'tightPossession': tightPossession,
    'lowPass': lowPass,
    'loftedPass': loftedPass,
    'finishing': finishing,
    'heading': heading,
    'setPieceTaking': setPieceTaking,
    'curl': curl,
    'defensiveAwareness': defensiveAwareness,
    'defensiveEngagement': defensiveEngagement,
    'tackling': tackling,
    'aggression': aggression,
    'gkAwareness': gkAwareness,
    'gkCatching': gkCatching,
    'gkParrying': gkParrying,
    'gkReflexes': gkReflexes,
    'gkReach': gkReach,
    'speed': speed,
    'acceleration': acceleration,
    'kickingPower': kickingPower,
    'jumping': jumping,
    'physicalContact': physicalContact,
    'balance': balance,
    'stamina': stamina,
  };
  factory PlayerStats.fromMap(Map<String, dynamic> m) => PlayerStats(
    attackingAwareness: ((m['attackingAwareness'] as num?)?.round() ?? 70)
        .clamp(40, 100),
    ballControl: ((m['ballControl'] as num?)?.round() ?? 70).clamp(40, 100),
    dribbling: ((m['dribbling'] as num?)?.round() ?? 70).clamp(40, 100),
    tightPossession: ((m['tightPossession'] as num?)?.round() ?? 70).clamp(
      40,
      100,
    ),
    lowPass: ((m['lowPass'] as num?)?.round() ?? 70).clamp(40, 100),
    loftedPass: ((m['loftedPass'] as num?)?.round() ?? 70).clamp(40, 100),
    finishing: ((m['finishing'] as num?)?.round() ?? 70).clamp(40, 100),
    heading: ((m['heading'] as num?)?.round() ?? 70).clamp(40, 100),
    setPieceTaking: ((m['setPieceTaking'] as num?)?.round() ?? 70).clamp(
      40,
      100,
    ),
    curl: ((m['curl'] as num?)?.round() ?? 70).clamp(40, 100),
    defensiveAwareness: ((m['defensiveAwareness'] as num?)?.round() ?? 70)
        .clamp(40, 100),
    defensiveEngagement: ((m['defensiveEngagement'] as num?)?.round() ?? 70)
        .clamp(40, 100),
    tackling: ((m['tackling'] as num?)?.round() ?? 70).clamp(40, 100),
    aggression: ((m['aggression'] as num?)?.round() ?? 70).clamp(40, 100),
    gkAwareness: ((m['gkAwareness'] as num?)?.round() ?? 70).clamp(40, 100),
    gkCatching: ((m['gkCatching'] as num?)?.round() ?? 70).clamp(40, 100),
    gkParrying: ((m['gkParrying'] as num?)?.round() ?? 70).clamp(40, 100),
    gkReflexes: ((m['gkReflexes'] as num?)?.round() ?? 70).clamp(40, 100),
    gkReach: ((m['gkReach'] as num?)?.round() ?? 70).clamp(40, 100),
    speed: ((m['speed'] as num?)?.round() ?? 70).clamp(40, 100),
    acceleration: ((m['acceleration'] as num?)?.round() ?? 70).clamp(40, 100),
    kickingPower: ((m['kickingPower'] as num?)?.round() ?? 70).clamp(40, 100),
    jumping: ((m['jumping'] as num?)?.round() ?? 70).clamp(40, 100),
    physicalContact: ((m['physicalContact'] as num?)?.round() ?? 70).clamp(
      40,
      100,
    ),
    balance: ((m['balance'] as num?)?.round() ?? 70).clamp(40, 100),
    stamina: ((m['stamina'] as num?)?.round() ?? 70).clamp(40, 100),
  );
  PlayerStats copyWith({
    int? attackingAwareness,
    int? ballControl,
    int? dribbling,
    int? tightPossession,
    int? lowPass,
    int? loftedPass,
    int? finishing,
    int? heading,
    int? setPieceTaking,
    int? curl,
    int? defensiveAwareness,
    int? defensiveEngagement,
    int? tackling,
    int? aggression,
    int? gkAwareness,
    int? gkCatching,
    int? gkParrying,
    int? gkReflexes,
    int? gkReach,
    int? speed,
    int? acceleration,
    int? kickingPower,
    int? jumping,
    int? physicalContact,
    int? balance,
    int? stamina,
  }) => PlayerStats.fromMap({
    ...toMap(),
    'attackingAwareness': ?attackingAwareness,
    'ballControl': ?ballControl,
    'dribbling': ?dribbling,
    'tightPossession': ?tightPossession,
    'lowPass': ?lowPass,
    'loftedPass': ?loftedPass,
    'finishing': ?finishing,
    'heading': ?heading,
    'setPieceTaking': ?setPieceTaking,
    'curl': ?curl,
    'defensiveAwareness': ?defensiveAwareness,
    'defensiveEngagement': ?defensiveEngagement,
    'tackling': ?tackling,
    'aggression': ?aggression,
    'gkAwareness': ?gkAwareness,
    'gkCatching': ?gkCatching,
    'gkParrying': ?gkParrying,
    'gkReflexes': ?gkReflexes,
    'gkReach': ?gkReach,
    'speed': ?speed,
    'acceleration': ?acceleration,
    'kickingPower': ?kickingPower,
    'jumping': ?jumping,
    'physicalContact': ?physicalContact,
    'balance': ?balance,
    'stamina': ?stamina,
  });
}

/// Shartnoma ma'lumotlari
@immutable
class PlayerContract {
  final int contractYears; // Qolgan mavsumlar / yillar (1.0.5)
  final int weeklyWage; // Haftalik maosh (EUR)
  final int releaseClause; // To'lov badali (Release clause)
  const PlayerContract({
    required this.contractYears,
    required this.weeklyWage,
    this.releaseClause = 0,
  });
  PlayerContract copyWith({
    int? contractYears,
    int? weeklyWage,
    int? releaseClause,
  }) {
    return PlayerContract(
      contractYears: contractYears ?? this.contractYears,
      weeklyWage: weeklyWage ?? this.weeklyWage,
      releaseClause: releaseClause ?? this.releaseClause,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contractYears': contractYears,
      'weeklyWage': weeklyWage,
      'releaseClause': releaseClause,
    };
  }

  factory PlayerContract.fromMap(Map<String, dynamic> map) {
    return PlayerContract(
      contractYears: map['contractYears'] as int? ?? 2,
      weeklyWage: map['weeklyWage'] as int? ?? 50000,
      releaseClause: map['releaseClause'] as int? ?? 0,
    );
  }
}

/// eFootball-style individual instructions (offence and defence).
enum PlayerInstruction {
  balanced('Muvozanat', 'Sxema va jamoaviy rejaga amal qiladi', true),
  makeRuns('Offensive · Hujumkor', 'Hujumda doim oldinga yuguradi, himoya ortini izlaydi', true),
  stayBack('Defensive · Himoyaviy', 'Hujumda ham orqada qolib sug‘urta qiladi', true),
  anchoring('Anchoring · Tayanch', 'O‘z zonasidan chiqmaydi, markazni yopadi', true),
  holdWidth('Qanotni ushlash', 'Yon chiziq bo‘ylab kenglik yaratadi', true),
  playmaker('Pas markazi', 'To‘pga ochilib sheriklarni bog‘laydi', true),
  counterTarget('Counter Target', 'Himoyaga qaytmaydi, qarshi hujumni kutadi', false),
  pressing('Faol pressing', 'To‘p egasiga birinchi bo‘lib boradi: ko‘proq to‘p qaytarish, lekin tez charchaydi', false),
  trackBack('Himoyaga qaytish', 'Hujumchi yoki vinger to‘p yo‘qotilganda himoyaga yordamga qaytadi', false),
  tightMarking('Tight Marking', 'Yaqin masofadan bosim: ko‘proq Olib qo‘yish va qoidabuzarlik', false),
  deepLine('Deep Line', 'Himoyada chuqurroq turib, orqa zonani sug‘urtalaydi', false);

  const PlayerInstruction(this._label, this._description, this.offence);
  final String _label;
  String get label => tr(_label);
  final String _description;
  String get description => tr(_description);
  final bool offence;
}

/// How well a player suits a position.
enum PositionFit {
  natural('Asosiy pozitsiya'),
  alternative('Muqobil pozitsiya'),
  similar('Yaqin pozitsiya'),
  poor('Begona pozitsiya');

  const PositionFit(this._label);
  final String _label;
  String get label => tr(_label);
}

const _families = <Set<PlayerPosition>>[
  {PlayerPosition.lb, PlayerPosition.rb},
  {PlayerPosition.dmf, PlayerPosition.cmf},
  {PlayerPosition.cmf, PlayerPosition.amf},
  {PlayerPosition.lmf, PlayerPosition.lwf},
  {PlayerPosition.rmf, PlayerPosition.rwf},
  {PlayerPosition.lmf, PlayerPosition.rmf},
  {PlayerPosition.lwf, PlayerPosition.rwf},
  {PlayerPosition.amf, PlayerPosition.ss},
  {PlayerPosition.ss, PlayerPosition.cf},
  {PlayerPosition.dmf, PlayerPosition.cb},
];

/// Futbolchi modeli
class Player {
  FaceConfig face;
  PlayerInstruction instruction;
  final String id;
  final String name;
  final String shortName;
  int age;
  final String nationality;
  final String countryFlag;
  final int number;
  final PlayerPosition mainPosition;
  final List<PlayerPosition> altPositions;
  final PreferredFoot preferredFoot;
  final int weakFoot; // 1 dan 5 yulduzgacha
  PlayerStats stats;
  PlayerContract contract;
  int marketValue; // Bozor bahosi (EUR)
  int potential; // Kelajakdagi eng yuqori OVR
  int? height; // sm
  List<String> traits; // maxsus mahoratlar (masalan "Tezlik", "Havo o‘yini")
  late PlayingStyle playingStyle;
  late DefendingStyle defendingStyle;
  late Set<AiStyle> aiStyles;
  // Real-time o'yin va mavsum holati
  int currentStamina; // 0–100
  int morale; // 0–100
  int injuryRounds; // jarohat: o'tkazib yuboriladigan turlar
  String? injury;
  int suspensionRounds; // diskvalifikatsiya
  // Mavsumiy statistika
  int seasonGoals;
  int seasonAssists;
  int seasonMatches;
  int seasonCleanSheets;
  int seasonYellowCards;
  int seasonRedCards;
  int seasonMinutes = 0;
  double growth = 0; // progress toward the next attribute gain
  int seasonMotm = 0;
  double seasonRatingSum = 0;
  int seasonRated = 0;
  final List<double> recentRatings = [];
  final List<String> history = []; // mavsumlar bo'yicha qisqa yozuvlar
  Player({
    FaceConfig? face,
    this.instruction = PlayerInstruction.balanced,
    required this.id,
    required this.name,
    required this.shortName,
    required this.age,
    required this.nationality,
    required this.countryFlag,
    required this.number,
    required this.mainPosition,
    required this.altPositions,
    required this.preferredFoot,
    required this.weakFoot,
    required this.stats,
    required this.contract,
    required this.marketValue,
    int? potential,
    PlayingStyle? playingStyle,
    this.height,
    List<String>? traits,
    int? currentStamina,
    this.morale = 85,
    this.injuryRounds = 0,
    this.injury,
    this.suspensionRounds = 0,
    this.seasonGoals = 0,
    this.seasonAssists = 0,
    this.seasonMatches = 0,
    this.seasonCleanSheets = 0,
    this.seasonYellowCards = 0,
    this.seasonRedCards = 0,
  }) : face = face ?? FaceConfig.forPlayer(id, nationality, age),
       currentStamina = currentStamina ?? 100,
       traits = traits ?? [],
       potential = potential ?? 0 {
    final profile = PlayingProfile.derive(mainPosition.code, stats.toMap());
    this.playingStyle = playingStyle ?? profile.style;
    defendingStyle = profile.defending;
    aiStyles = profile.ai;
    if (this.potential == 0) {
      final base = ovr;
      this.potential = (base +
              (age <= 19
                  ? 10
                  : age <= 21
                  ? 7
                  : age <= 23
                  ? 4
                  : age <= 26
                  ? 1
                  : 0))
          .clamp(min(base, 97), 97);
      if (this.potential < base) this.potential = base;
    }
  }
  double get goalsPerMatch =>
      seasonMatches > 0 ? (seasonGoals / seasonMatches) : 0.0;
  int get goalContributions => seasonGoals + seasonAssists;
  bool get isInjured => injuryRounds > 0;
  bool get isSuspended => suspensionRounds > 0;
  bool get isAvailable => !isInjured && !isSuspended;

  /// SofaScore-style season average rating (null before the first rating).
  double? get averageRating =>
      seasonRated == 0 ? null : seasonRatingSum / seasonRated;

  void recordRating(double rating) {
    seasonRatingSum += rating;
    seasonRated++;
    recentRatings.add(rating);
    if (recentRatings.length > 5) recentRatings.removeAt(0);
  }

  void resetSeasonStats() {
    seasonGoals = 0;
    seasonAssists = 0;
    seasonMatches = 0;
    seasonCleanSheets = 0;
    seasonYellowCards = 0;
    seasonRedCards = 0;
    seasonMinutes = 0;
    seasonMotm = 0;
    seasonRatingSum = 0;
    seasonRated = 0;
    recentRatings.clear();
  }

  /// Market value from ability, age and potential.
  static int valuation(int ovr, int age, int potential) {
    final base = pow(max(0, ovr - 55) / 10, 3.4) * 1600000;
    final ageFactor = age <= 21
        ? 1.45
        : age <= 24
        ? 1.25
        : age <= 27
        ? 1.05
        : age <= 29
        ? 0.88
        : age <= 31
        ? 0.66
        : age <= 33
        ? 0.42
        : 0.22;
    final growth = 1 + max(0, potential - ovr) * 0.035;
    final v = (base * ageFactor * growth).round();
    final step = v >= 10000000 ? 500000 : 100000;
    return max(250000, (v / step).round() * step);
  }
  Map<String, dynamic> toMap() => {
    'face': face.toMap(),
    'instruction': instruction.name,
    'id': id,
    'name': name,
    'shortName': shortName,
    'age': age,
    'nationality': nationality,
    'countryFlag': countryFlag,
    'number': number,
    'mainPosition': mainPosition.code,
    'altPositions': altPositions.map((p) => p.code).toList(),
    'preferredFoot': preferredFoot.name,
    'weakFoot': weakFoot,
    'stats': stats.toMap(),
    'contract': contract.toMap(),
    'marketValue': marketValue,
    'potential': potential,
    'playingStyle': playingStyle.name,
    'height': ?height,
    if (traits.isNotEmpty) 'traits': traits,
  };
  factory Player.fromMap(Map<String, dynamic> m) => Player(
    // Data may carry partial look-alike hints; the rest stays procedural.
    face: m['face'] == null
        ? null
        : FaceConfig.fromMap({
            ...FaceConfig.forPlayer(m['id'], m['nationality'], m['age']).toMap(),
            ...Map<String, dynamic>.from(m['face']),
          }),
    // "manMarking" was retired: old saves get the closest instruction.
    instruction: PlayerInstruction.values.asNameMap()[m['instruction']] ??
        (m['instruction'] == 'manMarking' ? PlayerInstruction.tightMarking : PlayerInstruction.balanced),
    id: m['id'],
    name: m['name'],
    shortName: m['shortName'],
    age: m['age'],
    nationality: m['nationality'],
    countryFlag: m['countryFlag'],
    number: m['number'],
    mainPosition: PlayerPosition.fromCode(m['mainPosition']),
    altPositions: (m['altPositions'] as List)
        .map((p) => PlayerPosition.fromCode(p))
        .toList(),
    preferredFoot: PreferredFoot.values.byName(m['preferredFoot']),
    weakFoot: m['weakFoot'],
    stats: PlayerStats.fromMap(Map<String, dynamic>.from(m['stats'])),
    contract: PlayerContract.fromMap(Map<String, dynamic>.from(m['contract'])),
    marketValue: m['marketValue'],
    potential: m['potential'],
    playingStyle: PlayingStyle.values.asNameMap()[m['playingStyle']],
    height: m['height'],
    traits: m['traits'] == null ? null : List<String>.from(m['traits']),
  );
  // ===========================================================================
  // OVR (Overall) HISOBLASH ALGORITMI (PRD 3.4)
  // ===========================================================================
  /// O'yinchining berilgan pozitsiyadagi asosiy raw OVR balli
  int calculateRawOVR(PlayerPosition pos) {
    final weights = switch (pos) {
      PlayerPosition.cf => {
        'finishing': 0.27,
        'attackingAwareness': 0.22,
        'kickingPower': 0.12,
        'heading': 0.10,
        'ballControl': 0.10,
        'physicalContact': 0.08,
        'speed': 0.06,
        'acceleration': 0.05,
      },
      PlayerPosition.ss => {
        'attackingAwareness': 0.18,
        'tightPossession': 0.18,
        'dribbling': 0.16,
        'ballControl': 0.16,
        'lowPass': 0.14,
        'finishing': 0.12,
        'acceleration': 0.06,
      },
      PlayerPosition.lwf || PlayerPosition.rwf => {
        'speed': 0.18,
        'acceleration': 0.17,
        'dribbling': 0.18,
        'ballControl': 0.14,
        'tightPossession': 0.10,
        'lowPass': 0.08,
        'loftedPass': 0.07,
        'attackingAwareness': 0.08,
      },
      PlayerPosition.lmf || PlayerPosition.rmf => {
        'lowPass': 0.16,
        'loftedPass': 0.18,
        'dribbling': 0.14,
        'speed': 0.14,
        'acceleration': 0.10,
        'stamina': 0.12,
        'tightPossession': 0.08,
        'attackingAwareness': 0.08,
      },
      PlayerPosition.amf => {
        'lowPass': 0.23,
        'tightPossession': 0.18,
        'ballControl': 0.18,
        'attackingAwareness': 0.14,
        'dribbling': 0.12,
        'finishing': 0.08,
        'curl': 0.07,
      },
      PlayerPosition.cmf => {
        'lowPass': 0.25,
        'loftedPass': 0.18,
        'tightPossession': 0.15,
        'ballControl': 0.12,
        'defensiveEngagement': 0.10,
        'stamina': 0.12,
        'balance': 0.08,
      },
      PlayerPosition.dmf => {
        'defensiveAwareness': 0.20,
        'defensiveEngagement': 0.18,
        'tackling': 0.20,
        'lowPass': 0.18,
        'physicalContact': 0.14,
        'stamina': 0.10,
      },
      PlayerPosition.cb => {
        'defensiveAwareness': 0.25,
        'defensiveEngagement': 0.19,
        'tackling': 0.23,
        'heading': 0.12,
        'physicalContact': 0.14,
        'jumping': 0.07,
      },
      PlayerPosition.lb || PlayerPosition.rb => {
        'speed': 0.14,
        'acceleration': 0.10,
        'stamina': 0.15,
        'defensiveAwareness': 0.15,
        'tackling': 0.14,
        'defensiveEngagement': 0.12,
        'loftedPass': 0.12,
        'lowPass': 0.08,
      },
      PlayerPosition.gk => {
        'gkAwareness': 0.25,
        'gkCatching': 0.15,
        'gkParrying': 0.15,
        'gkReflexes': 0.30,
        'gkReach': 0.15,
      },
    };
    return stats.weighted(weights);
  }

  /// Maydondagi amaldagi (effective) OVR ko'rsatkichi.
  /// Agar o'yinchi taktikada o'zining mainPosition yoki altPositions idan
  /// boshqa joyga qo'yilsa, uning amaliy OVR ko'rsatkichi -15% ga tushadi.
  int getEffectiveOVR([PlayerPosition? playingPosition]) {
    final pos = playingPosition ?? mainPosition;
    final raw = calculateRawOVR(pos);
    double familiarity = 1;
    if (pos != mainPosition && !altPositions.contains(pos)) {
      familiarity = pos.isGoalkeeper || mainPosition.isGoalkeeper
          ? 0.45
          : pos.category == mainPosition.category
          ? 0.94
          : 0.85;
    }
    return (raw * familiarity).round().clamp(40, 100);
  }

  PositionFit fitFor(PlayerPosition pos) {
    if (pos == mainPosition) return PositionFit.natural;
    if (altPositions.contains(pos)) return PositionFit.alternative;
    if (_families.any((f) => f.contains(pos) && f.contains(mainPosition))) {
      return PositionFit.similar;
    }
    return PositionFit.poor;
  }

  /// Positions sorted by how well he plays them (best first).
  List<PlayerPosition> get bestPositions =>
      List.of(PlayerPosition.values)
        ..sort((a, b) => getEffectiveOVR(b).compareTo(getEffectiveOVR(a)));

  /// Natural ability is stable; fitness and morale affect match strength only.
  int get ovr => getEffectiveOVR(mainPosition);
  int getMatchOVR([PlayerPosition? pos]) =>
      (getEffectiveOVR(pos) *
              (0.82 + currentStamina / 100 * 0.18) *
              (0.95 + morale / 100 * 0.05))
          .round()
          .clamp(40, 100);

  /// Shartnoma yangilash bo'yicha talab qilinadigan maosh
  int get calculatedRenewalWageDemand {
    final base = (ovr >= 91)
        ? (ovr * 4500)
        : (ovr >= 87)
        ? (ovr * 3200)
        : (ovr >= 82)
        ? (ovr * 2000)
        : (ovr * 1100);
    // Yosh faktori (yosh iqtidorlar kelajak uchun, keksalar kamroq talab qiladi)
    final ageFactor = (age <= 23)
        ? 1.15
        : (age >= 32)
        ? 0.85
        : 1.0;
    return (base * ageFactor).round();
  }

  /// Formatlangan bozor narxi (€90.0M yoki €850K)
  String get formattedMarketValue {
    if (marketValue >= 1000000) {
      return '€${(marketValue / 1000000).toStringAsFixed(1)}M';
    }
    return '€${(marketValue / 1000).toStringAsFixed(0)}K';
  }

  /// Formatlangan haftalik maosh
  String get formattedWeeklyWage {
    if (contract.weeklyWage >= 1000) {
      return '€${(contract.weeklyWage / 1000).toStringAsFixed(0)}K/hft';
    }
    return '€${contract.weeklyWage}/hft';
  }

  Player copyWith({
    String? id,
    String? name,
    String? shortName,
    int? age,
    String? nationality,
    String? countryFlag,
    int? number,
    PlayerPosition? mainPosition,
    List<PlayerPosition>? altPositions,
    PreferredFoot? preferredFoot,
    int? weakFoot,
    PlayerStats? stats,
    PlayerContract? contract,
    int? marketValue,
    int? currentStamina,
    int? morale,
    int? seasonGoals,
    int? seasonAssists,
    int? seasonMatches,
    int? seasonCleanSheets,
    int? seasonYellowCards,
    int? seasonRedCards,
  }) {
    return Player(
      face: face,
      instruction: instruction,
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      age: age ?? this.age,
      nationality: nationality ?? this.nationality,
      countryFlag: countryFlag ?? this.countryFlag,
      number: number ?? this.number,
      mainPosition: mainPosition ?? this.mainPosition,
      altPositions: altPositions ?? this.altPositions,
      preferredFoot: preferredFoot ?? this.preferredFoot,
      weakFoot: weakFoot ?? this.weakFoot,
      stats: stats ?? this.stats,
      contract: contract ?? this.contract,
      marketValue: marketValue ?? this.marketValue,
      currentStamina: currentStamina ?? this.currentStamina,
      morale: morale ?? this.morale,
      seasonGoals: seasonGoals ?? this.seasonGoals,
      seasonAssists: seasonAssists ?? this.seasonAssists,
      seasonMatches: seasonMatches ?? this.seasonMatches,
      seasonCleanSheets: seasonCleanSheets ?? this.seasonCleanSheets,
      seasonYellowCards: seasonYellowCards ?? this.seasonYellowCards,
      seasonRedCards: seasonRedCards ?? this.seasonRedCards,
    );
  }
}
