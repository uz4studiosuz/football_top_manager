import 'package:flutter/material.dart';
import 'player.dart';

/// Murabbiy Uslublari (Team Playstyle)
enum TeamPlaystyle {
  outWide(
    'Out Wide',
    'Qanotlarni keng ochish, kross va jarima maydoniga yugurish.',
    Icons.open_in_full,
    Color(0xFF1769E0),
  ),
  longBallCounter(
    'Long Ball Counter',
    'Past blok va tez uzun uzatma.',
    Icons.north_east,
    Color(0xFF1769E0),
  ),
  possession(
    'Possession Game',
    'Tiki-Taka qisqa paslar va maydon nazorati',
    Icons.grain_rounded,
    Color(0xFF1769E0),
  ),
  quickCounter(
    'Quick Counter',
    'Chaqqon qarshi hujum va tezlikka tayanuvchi o\'yin',
    Icons.bolt_rounded,
    Color(0xFF1769E0),
  ),
  highPressing(
    'High Pressing',
    'Gegenpress - raqib jarima maydonida to\'pni olib qo\'yish',
    Icons.local_fire_department_rounded,
    Color(0xFF1769E0),
  ),
  longBall(
    'Long Ball / Park Bus',
    'Mustahkam himoya va uzun paslar bilan qarshi hujum',
    Icons.shield_rounded,
    Color(0xFF1769E0),
  );

  const TeamPlaystyle(
    this.displayName,
    this.description,
    this.icon,
    this.accentColor,
  );
  final String displayName;
  final String description;
  final IconData icon;
  final Color accentColor;
}

/// Taktik slot (11 ta o'yinchi joylashuvi maydonda)
class TacticalSlot {
  final int index; // 0.0.10
  final PlayerPosition defaultPosition;
  final double x; // 0.0 (chap qanot) dan 1.0 (o'ng qanot) gacha
  final double y; // 0.0 (raqib darvozasi) dan 1.0 (o'z darvozamiz) gacha
  final String roleLabel;
  const TacticalSlot({
    required this.index,
    required this.defaultPosition,
    required this.x,
    required this.y,
    required this.roleLabel,
  });
}

/// Taktik sxemalar (Formations)
enum FormationType {
  f433('4-3-3 Attack'),
  f4231('4-2-3-1 Balanced'),
  f442('4-4-2 Classic'),
  f352('3-5-2 Midfield Heavy'),
  f532('5-3-2 Defensive');

  const FormationType(this.label);
  final String label;
  List<TacticalSlot> get slots {
    switch (this) {
      case FormationType.f433:
        return const [
          TacticalSlot(
            index: 0,
            defaultPosition: PlayerPosition.gk,
            x: 0.50,
            y: 0.90,
            roleLabel: 'GK',
          ),
          TacticalSlot(
            index: 1,
            defaultPosition: PlayerPosition.lb,
            x: 0.14,
            y: 0.72,
            roleLabel: 'LB',
          ),
          TacticalSlot(
            index: 2,
            defaultPosition: PlayerPosition.cb,
            x: 0.38,
            y: 0.75,
            roleLabel: 'CB',
          ),
          TacticalSlot(
            index: 3,
            defaultPosition: PlayerPosition.cb,
            x: 0.62,
            y: 0.75,
            roleLabel: 'CB',
          ),
          TacticalSlot(
            index: 4,
            defaultPosition: PlayerPosition.rb,
            x: 0.86,
            y: 0.72,
            roleLabel: 'RB',
          ),
          TacticalSlot(
            index: 5,
            defaultPosition: PlayerPosition.dmf,
            x: 0.50,
            y: 0.58,
            roleLabel: 'DMF',
          ),
          TacticalSlot(
            index: 6,
            defaultPosition: PlayerPosition.cmf,
            x: 0.30,
            y: 0.46,
            roleLabel: 'LCMF',
          ),
          TacticalSlot(
            index: 7,
            defaultPosition: PlayerPosition.amf,
            x: 0.70,
            y: 0.44,
            roleLabel: 'RAMF',
          ),
          TacticalSlot(
            index: 8,
            defaultPosition: PlayerPosition.lwf,
            x: 0.18,
            y: 0.22,
            roleLabel: 'LWF',
          ),
          TacticalSlot(
            index: 9,
            defaultPosition: PlayerPosition.cf,
            x: 0.50,
            y: 0.16,
            roleLabel: 'CF',
          ),
          TacticalSlot(
            index: 10,
            defaultPosition: PlayerPosition.rwf,
            x: 0.82,
            y: 0.22,
            roleLabel: 'RWF',
          ),
        ];
      case FormationType.f4231:
        return const [
          TacticalSlot(
            index: 0,
            defaultPosition: PlayerPosition.gk,
            x: 0.50,
            y: 0.90,
            roleLabel: 'GK',
          ),
          TacticalSlot(
            index: 1,
            defaultPosition: PlayerPosition.lb,
            x: 0.14,
            y: 0.72,
            roleLabel: 'LB',
          ),
          TacticalSlot(
            index: 2,
            defaultPosition: PlayerPosition.cb,
            x: 0.38,
            y: 0.75,
            roleLabel: 'CB',
          ),
          TacticalSlot(
            index: 3,
            defaultPosition: PlayerPosition.cb,
            x: 0.62,
            y: 0.75,
            roleLabel: 'CB',
          ),
          TacticalSlot(
            index: 4,
            defaultPosition: PlayerPosition.rb,
            x: 0.86,
            y: 0.72,
            roleLabel: 'RB',
          ),
          TacticalSlot(
            index: 5,
            defaultPosition: PlayerPosition.dmf,
            x: 0.35,
            y: 0.58,
            roleLabel: 'LDMF',
          ),
          TacticalSlot(
            index: 6,
            defaultPosition: PlayerPosition.dmf,
            x: 0.65,
            y: 0.58,
            roleLabel: 'RDMF',
          ),
          TacticalSlot(
            index: 7,
            defaultPosition: PlayerPosition.lmf,
            x: 0.18,
            y: 0.36,
            roleLabel: 'LAMF',
          ),
          TacticalSlot(
            index: 8,
            defaultPosition: PlayerPosition.amf,
            x: 0.50,
            y: 0.34,
            roleLabel: 'CAMF',
          ),
          TacticalSlot(
            index: 9,
            defaultPosition: PlayerPosition.rmf,
            x: 0.82,
            y: 0.36,
            roleLabel: 'RAMF',
          ),
          TacticalSlot(
            index: 10,
            defaultPosition: PlayerPosition.st,
            x: 0.50,
            y: 0.16,
            roleLabel: 'ST',
          ),
        ];
      case FormationType.f442:
        return const [
          TacticalSlot(
            index: 0,
            defaultPosition: PlayerPosition.gk,
            x: 0.50,
            y: 0.90,
            roleLabel: 'GK',
          ),
          TacticalSlot(
            index: 1,
            defaultPosition: PlayerPosition.lb,
            x: 0.14,
            y: 0.72,
            roleLabel: 'LB',
          ),
          TacticalSlot(
            index: 2,
            defaultPosition: PlayerPosition.cb,
            x: 0.38,
            y: 0.75,
            roleLabel: 'CB',
          ),
          TacticalSlot(
            index: 3,
            defaultPosition: PlayerPosition.cb,
            x: 0.62,
            y: 0.75,
            roleLabel: 'CB',
          ),
          TacticalSlot(
            index: 4,
            defaultPosition: PlayerPosition.rb,
            x: 0.86,
            y: 0.72,
            roleLabel: 'RB',
          ),
          TacticalSlot(
            index: 5,
            defaultPosition: PlayerPosition.lmf,
            x: 0.16,
            y: 0.46,
            roleLabel: 'LMF',
          ),
          TacticalSlot(
            index: 6,
            defaultPosition: PlayerPosition.cmf,
            x: 0.38,
            y: 0.50,
            roleLabel: 'LCMF',
          ),
          TacticalSlot(
            index: 7,
            defaultPosition: PlayerPosition.cmf,
            x: 0.62,
            y: 0.50,
            roleLabel: 'RCMF',
          ),
          TacticalSlot(
            index: 8,
            defaultPosition: PlayerPosition.rmf,
            x: 0.84,
            y: 0.46,
            roleLabel: 'RMF',
          ),
          TacticalSlot(
            index: 9,
            defaultPosition: PlayerPosition.cf,
            x: 0.36,
            y: 0.18,
            roleLabel: 'LCF',
          ),
          TacticalSlot(
            index: 10,
            defaultPosition: PlayerPosition.st,
            x: 0.64,
            y: 0.18,
            roleLabel: 'RST',
          ),
        ];
      case FormationType.f352:
        return const [
          TacticalSlot(
            index: 0,
            defaultPosition: PlayerPosition.gk,
            x: 0.50,
            y: 0.90,
            roleLabel: 'GK',
          ),
          TacticalSlot(
            index: 1,
            defaultPosition: PlayerPosition.cb,
            x: 0.25,
            y: 0.75,
            roleLabel: 'LCB',
          ),
          TacticalSlot(
            index: 2,
            defaultPosition: PlayerPosition.cb,
            x: 0.50,
            y: 0.77,
            roleLabel: 'CB',
          ),
          TacticalSlot(
            index: 3,
            defaultPosition: PlayerPosition.cb,
            x: 0.75,
            y: 0.75,
            roleLabel: 'RCB',
          ),
          TacticalSlot(
            index: 4,
            defaultPosition: PlayerPosition.lmf,
            x: 0.12,
            y: 0.48,
            roleLabel: 'LWB',
          ),
          TacticalSlot(
            index: 5,
            defaultPosition: PlayerPosition.dmf,
            x: 0.38,
            y: 0.58,
            roleLabel: 'LDMF',
          ),
          TacticalSlot(
            index: 6,
            defaultPosition: PlayerPosition.cmf,
            x: 0.62,
            y: 0.58,
            roleLabel: 'RDMF',
          ),
          TacticalSlot(
            index: 7,
            defaultPosition: PlayerPosition.rmf,
            x: 0.88,
            y: 0.48,
            roleLabel: 'RWB',
          ),
          TacticalSlot(
            index: 8,
            defaultPosition: PlayerPosition.amf,
            x: 0.50,
            y: 0.36,
            roleLabel: 'AMF',
          ),
          TacticalSlot(
            index: 9,
            defaultPosition: PlayerPosition.cf,
            x: 0.36,
            y: 0.18,
            roleLabel: 'LCF',
          ),
          TacticalSlot(
            index: 10,
            defaultPosition: PlayerPosition.st,
            x: 0.64,
            y: 0.18,
            roleLabel: 'RST',
          ),
        ];
      case FormationType.f532:
        return const [
          TacticalSlot(
            index: 0,
            defaultPosition: PlayerPosition.gk,
            x: 0.50,
            y: 0.90,
            roleLabel: 'GK',
          ),
          TacticalSlot(
            index: 1,
            defaultPosition: PlayerPosition.lb,
            x: 0.12,
            y: 0.70,
            roleLabel: 'LWB',
          ),
          TacticalSlot(
            index: 2,
            defaultPosition: PlayerPosition.cb,
            x: 0.30,
            y: 0.76,
            roleLabel: 'LCB',
          ),
          TacticalSlot(
            index: 3,
            defaultPosition: PlayerPosition.cb,
            x: 0.50,
            y: 0.78,
            roleLabel: 'CCB',
          ),
          TacticalSlot(
            index: 4,
            defaultPosition: PlayerPosition.cb,
            x: 0.70,
            y: 0.76,
            roleLabel: 'RCB',
          ),
          TacticalSlot(
            index: 5,
            defaultPosition: PlayerPosition.rb,
            x: 0.88,
            y: 0.70,
            roleLabel: 'RWB',
          ),
          TacticalSlot(
            index: 6,
            defaultPosition: PlayerPosition.cmf,
            x: 0.30,
            y: 0.50,
            roleLabel: 'LCMF',
          ),
          TacticalSlot(
            index: 7,
            defaultPosition: PlayerPosition.dmf,
            x: 0.50,
            y: 0.54,
            roleLabel: 'DMF',
          ),
          TacticalSlot(
            index: 8,
            defaultPosition: PlayerPosition.cmf,
            x: 0.70,
            y: 0.50,
            roleLabel: 'RCMF',
          ),
          TacticalSlot(
            index: 9,
            defaultPosition: PlayerPosition.cf,
            x: 0.38,
            y: 0.20,
            roleLabel: 'LCF',
          ),
          TacticalSlot(
            index: 10,
            defaultPosition: PlayerPosition.st,
            x: 0.62,
            y: 0.20,
            roleLabel: 'RST',
          ),
        ];
    }
  }
}

/// Jamoa taktik konfiguratsiyasi
class TeamTactics {
  final FormationType formation;
  final TeamPlaystyle playstyle;
  final int defensiveLine; // 1 (juda past) dan 5 (juda baland) gacha
  final int attackingIntensity; // 1 dan 5 gacha
  final int tempo;
  final int width;
  final bool counterPress;
  final bool playOutFromBack;
  const TeamTactics({
    this.formation = FormationType.f433,
    this.playstyle = TeamPlaystyle.possession,
    this.defensiveLine = 3,
    this.attackingIntensity = 3,
    this.tempo = 3,
    this.width = 3,
    this.counterPress = false,
    this.playOutFromBack = true,
  });
  TeamTactics copyWith({
    FormationType? formation,
    TeamPlaystyle? playstyle,
    int? defensiveLine,
    int? attackingIntensity,
    int? tempo,
    int? width,
    bool? counterPress,
    bool? playOutFromBack,
  }) {
    return TeamTactics(
      formation: formation ?? this.formation,
      playstyle: playstyle ?? this.playstyle,
      defensiveLine: defensiveLine ?? this.defensiveLine,
      attackingIntensity: attackingIntensity ?? this.attackingIntensity,
      tempo: tempo ?? this.tempo,
      width: width ?? this.width,
      counterPress: counterPress ?? this.counterPress,
      playOutFromBack: playOutFromBack ?? this.playOutFromBack,
    );
  }
}

/// Klub Logosi Geometriya va Uslubi (Tashqi PNG rasmlarsiz toza Vektor / CustomPainter)
enum CrestShape { shield, circle, oval, modernShield }

enum CrestPattern { verticalStripes, diagonalSash, halves, solid, quarters }

class ClubCrestConfig {
  final CrestShape shape;
  final CrestPattern pattern;
  final Color primaryColor;
  final Color secondaryColor;
  final Color trimColor;
  final String monogram; // "RM", "MC", "FCB", "BAY", etc.
  final int stars; // Masalan 1.0.5
  const ClubCrestConfig({
    required this.shape,
    required this.pattern,
    required this.primaryColor,
    required this.secondaryColor,
    required this.trimColor,
    required this.monogram,
    this.stars = 0,
  });
}

/// Klub Modeli
class Club {
  final String id;
  final String name;
  final String shortName;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final String stadiumName;
  final int stadiumCapacity;
  int transferBudget; // EUR
  int wageBudget; // Haftalik limit (EUR)
  TeamTactics tactics;
  final ClubCrestConfig crestConfig;
  List<Player> squad;
  List<String> startingLineupIds; // Maydondagi 11 ta o'yinchi IDsi
  List<String> benchIds; // Zaxiradagi o'yinchilar IDsi
  Club({
    required this.id,
    required this.name,
    required this.shortName,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.stadiumName,
    required this.stadiumCapacity,
    required this.transferBudget,
    required this.wageBudget,
    required this.tactics,
    required this.crestConfig,
    required this.squad,
    required this.startingLineupIds,
    required this.benchIds,
  });
  // --- GETTERLAR VA HISOBLASHLAR ---
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'shortName': shortName,
    'primaryColor': primaryColor.toARGB32(),
    'secondaryColor': secondaryColor.toARGB32(),
    'accentColor': accentColor.toARGB32(),
    'stadiumName': stadiumName,
    'stadiumCapacity': stadiumCapacity,
    'transferBudget': transferBudget,
    'wageBudget': wageBudget,
    'tactics': {
      'formation': tactics.formation.name,
      'playstyle': tactics.playstyle.name,
      'defensiveLine': tactics.defensiveLine,
      'attackingIntensity': tactics.attackingIntensity,
      'tempo': tactics.tempo,
      'width': tactics.width,
      'counterPress': tactics.counterPress,
      'playOutFromBack': tactics.playOutFromBack,
    },
    'crest': {
      'shape': crestConfig.shape.name,
      'pattern': crestConfig.pattern.name,
      'primaryColor': crestConfig.primaryColor.toARGB32(),
      'secondaryColor': crestConfig.secondaryColor.toARGB32(),
      'trimColor': crestConfig.trimColor.toARGB32(),
      'monogram': crestConfig.monogram,
      'stars': crestConfig.stars,
    },
    'squad': squad.map((p) => p.toMap()).toList(),
    'startingLineupIds': startingLineupIds,
    'benchIds': benchIds,
  };
  factory Club.fromMap(Map<String, dynamic> m) {
    final t = m['tactics'] as Map;
    final c = m['crest'] as Map;
    return Club(
      id: m['id'],
      name: m['name'],
      shortName: m['shortName'],
      primaryColor: Color(m['primaryColor']),
      secondaryColor: Color(m['secondaryColor']),
      accentColor: Color(m['accentColor']),
      stadiumName: m['stadiumName'],
      stadiumCapacity: m['stadiumCapacity'],
      transferBudget: m['transferBudget'],
      wageBudget: m['wageBudget'],
      tactics: TeamTactics(
        formation: FormationType.values.byName(t['formation']),
        playstyle: TeamPlaystyle.values.byName(t['playstyle']),
        defensiveLine: t['defensiveLine'],
        attackingIntensity: t['attackingIntensity'],
        tempo: t['tempo'] ?? 3,
        width: t['width'] ?? 3,
        counterPress: t['counterPress'] ?? false,
        playOutFromBack: t['playOutFromBack'] ?? true,
      ),
      crestConfig: ClubCrestConfig(
        shape: CrestShape.values.byName(c['shape']),
        pattern: CrestPattern.values.byName(c['pattern']),
        primaryColor: Color(c['primaryColor']),
        secondaryColor: Color(c['secondaryColor']),
        trimColor: Color(c['trimColor']),
        monogram: c['monogram'],
        stars: c['stars'],
      ),
      squad: (m['squad'] as List)
          .map((p) => Player.fromMap(Map<String, dynamic>.from(p)))
          .toList(),
      startingLineupIds: List<String>.from(m['startingLineupIds']),
      benchIds: List<String>.from(m['benchIds']),
    );
  }

  /// Asosiy 11 ta o'yinchi ro'yxati
  List<Player> get startingXI {
    return startingLineupIds
        .map((id) => squad.where((p) => p.id == id).firstOrNull)
        .whereType<Player>()
        .toList();
  }

  /// Zaxiradagi o'yinchilar ro'yxati
  List<Player> get bench {
    return squad.where((p) => benchIds.contains(p.id)).toList();
  }

  /// Jamoaning umumiy OVR ko'rsatkichi (Asosiy 11 talikning amaliy OVR o'rtachasi)
  int get teamOVR {
    if (startingXI.isEmpty) return 70;
    final slots = tactics.formation.slots;
    int sum = 0;
    for (int i = 0; i < startingXI.length; i++) {
      final player = startingXI[i];
      final slotPos = (i < slots.length)
          ? slots[i].defaultPosition
          : player.mainPosition;
      sum += player.getMatchOVR(slotPos);
    }
    return (sum / startingXI.length).round();
  }

  /// Hujum chizig'i reytingi (Attack)
  int get attackRating {
    final attackers = startingXI
        .where((p) => p.mainPosition.isAttacker)
        .toList();
    if (attackers.isEmpty) return 75;
    final sum = attackers.fold<int>(0, (prev, p) => prev + p.ovr);
    return (sum / attackers.length).round();
  }

  /// Yarim himoya chizig'i reytingi (Midfield)
  int get midfieldRating {
    final midfielders = startingXI
        .where((p) => p.mainPosition.isMidfielder)
        .toList();
    if (midfielders.isEmpty) return 75;
    final sum = midfielders.fold<int>(0, (prev, p) => prev + p.ovr);
    return (sum / midfielders.length).round();
  }

  /// Himoya va Darvoza reytingi (Defense)
  int get defenseRating {
    final defenders = startingXI
        .where((p) => p.mainPosition.isDefender || p.mainPosition.isGoalkeeper)
        .toList();
    if (defenders.isEmpty) return 75;
    final sum = defenders.fold<int>(0, (prev, p) => prev + p.ovr);
    return (sum / defenders.length).round();
  }

  /// Barcha o'yinchilarning haftalik umumiy maoshi
  int get totalWeeklyWages {
    return squad.fold<int>(0, (sum, p) => sum + p.contract.weeklyWage);
  }

  /// Qolgan haftalik maosh byudjeti
  int get remainingWageBudget => wageBudget - totalWeeklyWages;

  /// Formatlangan Transfer Byudjeti (€120.0M)
  String get formattedTransferBudget {
    return '€${(transferBudget / 1000000).toStringAsFixed(1)}M';
  }

  /// Formatlangan Haftalik Byudjet
  String get formattedWageBudget {
    return '€${(wageBudget / 1000).toStringAsFixed(0)}K/hft';
  }
}

// =============================================================================
// VECTOR CLUB CREST CUSTOM PAINTER (Tashqi rasm / PNG kerak emas!)
// =============================================================================
class ClubCrestPainter extends CustomPainter {
  final ClubCrestConfig config;
  ClubCrestPainter({required this.config});
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = _getShapePath(config.shape, w, h);
    // 2. Qalqonni qirqib olish (Clip path)
    canvas.save();
    canvas.clipPath(path);
    // 3. Asosiy rang fon (Gradient)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = config.primaryColor,
    );
    // 4. Bezak namunasi (Pattern: chiziqlar, sash yoki qismlar)
    _drawPattern(canvas, w, h);
    canvas.restore();
    // 6. Qalqon hoshiyasi (Outer border)
    final borderPaint = Paint()
      ..color = config.trimColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06;
    canvas.drawPath(path, borderPaint);
    // 7. Ichki nozik hoshiya (Inner trim)
    final innerPath = _getShapePath(config.shape, w * 0.90, h * 0.90);
    canvas.save();
    canvas.translate(w * 0.05, h * 0.05);
    final innerBorderPaint = Paint()
      ..color = config.trimColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02;
    canvas.drawPath(innerPath, innerBorderPaint);
    canvas.restore();
    // 8. Monogram matni yoki emblemasi (Vektor matn)
    _drawMonogram(canvas, w, h);
  }

  Path _getShapePath(CrestShape shape, double w, double h) {
    final path = Path();
    switch (shape) {
      case CrestShape.shield:
        path.moveTo(w * 0.08, h * 0.10);
        path.lineTo(w * 0.92, h * 0.10);
        path.lineTo(w * 0.92, h * 0.58);
        path.quadraticBezierTo(w * 0.88, h * 0.85, w * 0.50, h * 0.98);
        path.quadraticBezierTo(w * 0.12, h * 0.85, w * 0.08, h * 0.58);
        path.close();
        break;
      case CrestShape.modernShield:
        path.moveTo(w * 0.50, h * 0.04);
        path.lineTo(w * 0.92, h * 0.14);
        path.lineTo(w * 0.90, h * 0.65);
        path.quadraticBezierTo(w * 0.75, h * 0.90, w * 0.50, h * 0.98);
        path.quadraticBezierTo(w * 0.25, h * 0.90, w * 0.10, h * 0.65);
        path.lineTo(w * 0.08, h * 0.14);
        path.close();
        break;
      case CrestShape.circle:
        path.addOval(Rect.fromLTWH(w * 0.05, h * 0.05, w * 0.90, h * 0.90));
        break;
      case CrestShape.oval:
        path.addOval(Rect.fromLTWH(w * 0.10, h * 0.04, w * 0.80, h * 0.92));
        break;
    }
    return path;
  }

  void _drawPattern(Canvas canvas, double w, double h) {
    final patternPaint = Paint()
      ..color = config.secondaryColor
      ..style = PaintingStyle.fill;
    switch (config.pattern) {
      case CrestPattern.verticalStripes:
        final stripeWidth = w / 5;
        canvas.drawRect(
          Rect.fromLTWH(stripeWidth * 1, 0, stripeWidth, h),
          patternPaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(stripeWidth * 3, 0, stripeWidth, h),
          patternPaint,
        );
        break;
      case CrestPattern.diagonalSash:
        final sashPath = Path()
          ..moveTo(0, h * 0.40)
          ..lineTo(w * 0.75, 0)
          ..lineTo(w, 0)
          ..lineTo(w, h * 0.15)
          ..lineTo(w * 0.25, h)
          ..lineTo(0, h)
          ..close();
        canvas.drawPath(sashPath, patternPaint);
        break;
      case CrestPattern.halves:
        canvas.drawRect(Rect.fromLTWH(w * 0.5, 0, w * 0.5, h), patternPaint);
        break;
      case CrestPattern.quarters:
        canvas.drawRect(
          Rect.fromLTWH(w * 0.5, 0, w * 0.5, h * 0.5),
          patternPaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(0, h * 0.5, w * 0.5, h * 0.5),
          patternPaint,
        );
        break;
      case CrestPattern.solid:
        // Naqshsiz toza fon
        break;
    }
  }

  void _drawMonogram(Canvas canvas, double w, double h) {
    final textSpan = TextSpan(
      text: config.monogram,
      style: TextStyle(
        color: config.trimColor,
        fontSize: w * 0.32,
        fontFamily: 'Roboto',
        fontWeight: FontWeight.w900,
        letterSpacing: -1.0,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: w);
    textPainter.paint(
      canvas,
      Offset(
        (w - textPainter.width) / 2,
        (h - textPainter.height) / 2 + (h * 0.02),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant ClubCrestPainter oldDelegate) {
    return oldDelegate.config != config;
  }
}

/// Klub logosini ko'rsatuvchi tayyor Flutter Widget
class ClubCrestWidget extends StatelessWidget {
  final ClubCrestConfig config;
  final double size;
  const ClubCrestWidget({super.key, required this.config, this.size = 48.0});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: ClubCrestPainter(config: config)),
    );
  }
}
