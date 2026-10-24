import '../l10n/l10n.dart';
/// eFootball-style player roles (see PlayerPlayingStyles.md). Every player
/// has one main playing style, one defending style and up to three AI
/// styles; the match engine reads them to shape runs, passes and duels.
enum PlayingStyle {
  goalPoacher('Goal Poacher', 'Gollarni hidlovchi', 'Oxirgi himoyachi yelkasida yurib, bir tegishda yakunlaydi.'),
  advancedStriker('Advanced Striker', 'Ilg‘or hujumchi', 'Jarima maydonida imkoniyat topib, to‘g‘ridan-to‘g‘ri zarba beradi.'),
  dummyRunner('Dummy Runner', 'Joy ochuvchi', 'Himoyachilarni o‘ziga tortib sheriklarga bo‘shliq yaratadi.'),
  foxInTheBox('Fox in the Box', 'Jarima yirtqichi', 'Jarima maydonida kutib, yakuniy zarbani beradi.'),
  targetMan('Target Man', 'Tayanch hujumchi', 'Jismoniy kuch bilan to‘pni ushlab, havoda ustun keladi.'),
  deepLyingForward('Deep-lying Forward', 'Soxta 9-raqam', 'Hujumni tashkil etish uchun orqaroqqa tushadi.'),
  prolificWinger('Prolific Winger', 'Unumdor vinger', 'Qanotdan markazga kirib gol uradi.'),
  roamingFlank('Roaming Flank', 'Erkin qanot', 'Qanotdan ichkariga erkin o‘tib pas almashadi.'),
  crossSpecialist('Cross Specialist', 'Kross ustasi', 'Yon chiziqdan aniq havo uzatmalari beradi.'),
  creativePlaymaker('Creative Playmaker', 'Ijodkor', 'Himoyani kesib o‘tuvchi aniq paslar beradi.'),
  classicNo10('Classic No. 10', 'Klassik 10', 'Joyida turib o‘yin ritmini boshqaradi.'),
  holePlayer('Hole Player', 'Bo‘shliq ovchisi', 'Yarim himoyadan jarima maydoniga yashirin yuguradi.'),
  boxToBox('Box-to-Box', 'Maydon motori', 'Hujum va himoyada butun maydon bo‘ylab yuguradi.'),
  anchorMan('Anchor Man', 'Tayanch', 'Himoya oldida qoladi, oldinga chiqmaydi.'),
  destroyer('The Destroyer', 'Buzg‘unchi', 'Agressiv kurash bilan raqib hujumini buzadi.'),
  orchestrator('Orchestrator', 'Dirijyor', 'Chuqurdan uzun va aniq paslar bilan boshqaradi.'),
  buildUp('Build Up', 'Hujum quruvchi', 'Orqadan xotirjam pas bilan hujumni boshlaydi.'),
  extraFrontman('Extra Frontman', 'Hujumchi himoyachi', 'Markaziy himoyachi bo‘lsa ham hujumga qo‘shiladi.'),
  attackingFullBack('Attacking Full-back', 'Hujumkor qanot himoyachisi', 'Muntazam oldinga chiqib kross beradi.'),
  defensiveFullBack('Defensive Full-back', 'Himoyaviy qanot himoyachisi', 'Orqada qolib raqib vingerini to‘xtatadi.'),
  fullBackFinisher('Full-back Finisher', 'Yakunlovchi qanot himoyachisi', 'Ichkariga kirib zarba beradi.'),
  attackingGoalkeeper('Attacking Goalkeeper', 'Hujumkor darvozabon', 'Himoya ortini tozalash uchun oldinga chiqadi.'),
  defensiveGoalkeeper('Defensive Goalkeeper', 'Himoyaviy darvozabon', 'Chiziqda qolib refleks bilan qaytaradi.');

  const PlayingStyle(this.title, this._uzbek, this._description);
  final String title;
  final String _uzbek;
  String get uzbek => tr(_uzbek);
  final String _description;
  String get description => tr(_description);
}

enum DefendingStyle {
  frontLinePressure('Front Line Pressure', 'Old chiziqda pressing'),
  frontLinePoacher('Front Line Poacher', 'Qarshi hujumga tayyor'),
  attackOutlet('Attack Outlet', 'Qanotdan chiqish nuqtasi'),
  allActionDefender('All-action Defender', 'Universal himoyachi'),
  passDisruptor('Pass Disruptor', 'Pas buzuvchi'),
  highLineMaster('High Line Master', 'Baland chiziq ustasi'),
  sweeperGk('Sweeper GK', 'Chiquvchi darvozabon'),
  basic('Basic', 'Muvozanatli');

  const DefendingStyle(this.title, this._uzbek);
  final String title;
  final String _uzbek;
  String get uzbek => tr(_uzbek);
}

enum AiStyle {
  trickster('Trickster', 'Fintchi'),
  mazingRun('Mazing Run', 'Ajoyib dribling'),
  speedingBullet('Speeding Bullet', 'Tezkor o‘q'),
  incisiveRun('Incisive Run', 'Keskin yorib kirish'),
  longBallExpert('Long Ball Expert', 'Uzun pas ustasi'),
  earlyCrosser('Early Crosser', 'Erta kross'),
  longRanger('Long Ranger', 'Uzoqdan zarba');

  const AiStyle(this.title, this._uzbek);
  final String title;
  final String _uzbek;
  String get uzbek => tr(_uzbek);
}

/// Attribute-driven assignment so imported or generated players always get a
/// believable role without hand tagging.
class PlayingProfile {
  final PlayingStyle style;
  final DefendingStyle defending;
  final Set<AiStyle> ai;
  const PlayingProfile(this.style, this.defending, this.ai);

  static PlayingProfile derive(String position, Map<String, dynamic> s) {
    int v(String k) => (s[k] as int?) ?? 60;
    final pace = (v('speed') + v('acceleration')) / 2;
    final style = _pickStyle(position, v);
    final forward = {'ST', 'CF', 'SS'}.contains(position);
    final wide = {'LWF', 'RWF', 'LMF', 'RMF'}.contains(position);
    DefendingStyle defending;
    if (position == 'GK') {
      defending = v('speed') >= 55 ? DefendingStyle.sweeperGk : DefendingStyle.basic;
    } else if (forward) {
      defending = v('defensiveEngagement') >= 58 || v('stamina') >= 86
          ? DefendingStyle.frontLinePressure
          : DefendingStyle.frontLinePoacher;
    } else if (wide) {
      defending = v('stamina') >= 86 ? DefendingStyle.frontLinePressure : DefendingStyle.attackOutlet;
    } else if (position == 'CB') {
      defending = pace >= 80 && v('defensiveAwareness') >= 84
          ? DefendingStyle.highLineMaster
          : v('defensiveAwareness') >= 86
          ? DefendingStyle.passDisruptor
          : DefendingStyle.allActionDefender;
    } else if (position == 'DMF' || position == 'CMF') {
      defending = v('defensiveAwareness') >= 80 ? DefendingStyle.passDisruptor : DefendingStyle.basic;
    } else if (position == 'LB' || position == 'RB') {
      defending = v('stamina') >= 84 ? DefendingStyle.allActionDefender : DefendingStyle.basic;
    } else {
      defending = DefendingStyle.basic;
    }
    final ai = <AiStyle>{};
    if (position != 'GK') {
      if (v('dribbling') >= 88 && v('balance') >= 82) ai.add(AiStyle.trickster);
      if (v('dribbling') >= 85 && v('tightPossession') >= 86) ai.add(AiStyle.mazingRun);
      if (pace >= 91) ai.add(AiStyle.speedingBullet);
      if ((position == 'LWF' || position == 'RWF') && v('finishing') >= 80 && pace >= 85) ai.add(AiStyle.incisiveRun);
      if (v('loftedPass') >= 86) ai.add(AiStyle.longBallExpert);
      if ((wide || position == 'LB' || position == 'RB') && v('loftedPass') >= 80 && v('curl') >= 80) {
        ai.add(AiStyle.earlyCrosser);
      }
      if (!forward && v('kickingPower') >= 84 && v('finishing') >= 76) ai.add(AiStyle.longRanger);
    }
    return PlayingProfile(style, defending, ai.take(3).toSet());
  }

  /// Weights per candidate style. Attributes are read relative to the
  /// player's own average, so a modest player still gets the role his
  /// strengths point to instead of everyone landing on a fallback role.
  /// '_' is a fixed bias that sets how common the role is.
  static const _candidates = <String, Map<PlayingStyle, Map<String, double>>>{
    'GK': {
      PlayingStyle.attackingGoalkeeper: {'speed': 1, 'acceleration': 0.5, 'lowPass': 1, 'loftedPass': 0.5, '_': -0.5},
      PlayingStyle.defensiveGoalkeeper: {'gkReflexes': 1, 'gkCatching': 0.5, 'gkParrying': 0.5, '_': 2},
    },
    'CF': {
      PlayingStyle.goalPoacher: {'speed': 1, 'acceleration': 1, 'finishing': 0.8, 'attackingAwareness': 0.6, 'lowPass': -0.5},
      PlayingStyle.advancedStriker: {'finishing': 0.8, 'dribbling': 0.5, 'kickingPower': 0.4, 'attackingAwareness': 0.3, '_': 2},
      PlayingStyle.foxInTheBox: {'finishing': 1.2, 'attackingAwareness': 0.8, 'speed': -0.7, 'acceleration': -0.3},
      PlayingStyle.targetMan: {'physicalContact': 1, 'heading': 1, 'jumping': 0.6, 'speed': -0.6, 'dribbling': -0.3},
      PlayingStyle.deepLyingForward: {'lowPass': 1, 'tightPossession': 0.8, 'ballControl': 0.4, 'finishing': -0.6},
      PlayingStyle.dummyRunner: {'attackingAwareness': 1, 'lowPass': 0.4, 'stamina': 0.4, 'finishing': -0.5, '_': -1},
    },
    'SS': {
      PlayingStyle.deepLyingForward: {'lowPass': 1, 'tightPossession': 0.8, 'finishing': -0.5},
      PlayingStyle.holePlayer: {'attackingAwareness': 1, 'finishing': 0.6, 'acceleration': 0.4},
      PlayingStyle.creativePlaymaker: {'lowPass': 0.8, 'dribbling': 0.6, 'loftedPass': 0.4, 'finishing': -0.4},
      PlayingStyle.advancedStriker: {'finishing': 1, 'kickingPower': 0.4, '_': 1},
    },
    'WF': {
      PlayingStyle.prolificWinger: {'finishing': 1, 'dribbling': 0.5, 'acceleration': 0.4, 'loftedPass': -0.4},
      PlayingStyle.roamingFlank: {'dribbling': 0.8, 'tightPossession': 0.6, 'lowPass': 0.5, 'finishing': -0.2, '_': 1},
      PlayingStyle.crossSpecialist: {'loftedPass': 1, 'curl': 1, 'finishing': -0.6, 'dribbling': -0.2},
    },
    'MF': {
      PlayingStyle.crossSpecialist: {'loftedPass': 1, 'curl': 0.8, 'finishing': -0.4},
      PlayingStyle.boxToBox: {'stamina': 1, 'defensiveEngagement': 0.6, 'tackling': 0.3},
      PlayingStyle.roamingFlank: {'dribbling': 0.8, 'tightPossession': 0.5, 'lowPass': 0.3, '_': 1},
      PlayingStyle.prolificWinger: {'finishing': 1, 'acceleration': 0.5, '_': -1},
    },
    'AMF': {
      PlayingStyle.creativePlaymaker: {'lowPass': 1, 'dribbling': 0.5, 'tightPossession': 0.4, '_': 1},
      PlayingStyle.holePlayer: {'finishing': 0.8, 'attackingAwareness': 0.8, 'acceleration': 0.3},
      PlayingStyle.classicNo10: {'lowPass': 0.8, 'loftedPass': 0.6, 'tightPossession': 0.5, 'speed': -0.8},
    },
    'CMF': {
      PlayingStyle.orchestrator: {'lowPass': 0.8, 'loftedPass': 1, 'tightPossession': 0.3, 'speed': -0.3},
      PlayingStyle.destroyer: {'tackling': 1, 'aggression': 1, 'defensiveEngagement': 0.6, 'physicalContact': 0.4, 'lowPass': -0.4},
      PlayingStyle.boxToBox: {'stamina': 1, 'defensiveEngagement': 0.4, 'attackingAwareness': 0.4, '_': 1},
      PlayingStyle.holePlayer: {'attackingAwareness': 1, 'finishing': 0.8, 'tackling': -0.5},
      PlayingStyle.creativePlaymaker: {'lowPass': 1, 'dribbling': 0.6, 'tackling': -0.4},
    },
    'DMF': {
      PlayingStyle.orchestrator: {'lowPass': 0.8, 'loftedPass': 1, 'tackling': -0.3},
      PlayingStyle.destroyer: {'tackling': 1, 'aggression': 1, 'physicalContact': 0.5, 'lowPass': -0.3},
      PlayingStyle.anchorMan: {'defensiveAwareness': 1.2, 'defensiveEngagement': 0.4, 'aggression': -0.3, 'stamina': -0.2, '_': 1},
      PlayingStyle.boxToBox: {'stamina': 1, 'speed': 0.4, 'attackingAwareness': 0.4},
    },
    'CB': {
      PlayingStyle.buildUp: {'lowPass': 1, 'loftedPass': 0.8, 'ballControl': 0.4, 'aggression': -0.3, '_': 3},
      PlayingStyle.destroyer: {'aggression': 1, 'tackling': 0.8, 'physicalContact': 0.8, 'lowPass': -0.4},
      PlayingStyle.extraFrontman: {'heading': 0.8, 'attackingAwareness': 1, 'finishing': 0.6, 'defensiveAwareness': -0.4, '_': -3},
    },
    'FB': {
      PlayingStyle.attackingFullBack: {
        'speed': 0.6, 'stamina': 0.6, 'loftedPass': 0.5, 'attackingAwareness': 0.5, 'dribbling': 0.3,
        'defensiveAwareness': -0.4, '_': 1,
      },
      PlayingStyle.defensiveFullBack: {'defensiveAwareness': 1, 'tackling': 0.8, 'attackingAwareness': -0.4, 'loftedPass': -0.3},
      PlayingStyle.fullBackFinisher: {'finishing': 1, 'attackingAwareness': 0.6, 'dribbling': 0.4, '_': -3},
    },
  };

  /// Typical attribute shape per position (relative to the player's
  /// own average), measured over the bundled leagues.
  static const _norms = <String, Map<String, double>>{
    'AMF': {'attackingAwareness': 6.5, 'ballControl': 7.2, 'dribbling': 6.2, 'tightPossession': 6.6, 'lowPass': 6.8, 'loftedPass': 3.8, 'finishing': 6.2, 'heading': -12.5, 'curl': 6.5, 'defensiveAwareness': -19.0, 'defensiveEngagement': -16.6, 'tackling': -20.6, 'aggression': 3.2, 'speed': 3.6, 'acceleration': 4.1, 'kickingPower': 3.8, 'jumping': 2.2, 'physicalContact': -5.5, 'balance': 3.7, 'stamina': 3.9},
    'CB': {'attackingAwareness': -22.1, 'ballControl': 5.9, 'dribbling': -13.2, 'tightPossession': -9.3, 'lowPass': 0.6, 'loftedPass': -1.7, 'finishing': -23.4, 'heading': 9.7, 'curl': -18.7, 'defensiveAwareness': 8.5, 'defensiveEngagement': 8.0, 'tackling': 7.7, 'aggression': 5.7, 'speed': 5.0, 'acceleration': 5.2, 'kickingPower': 4.8, 'jumping': 9.1, 'physicalContact': 8.4, 'balance': 4.6, 'stamina': 5.1},
    'CF': {'attackingAwareness': 7.6, 'ballControl': 7.4, 'dribbling': 4.2, 'tightPossession': 4.3, 'lowPass': -0.9, 'loftedPass': -4.9, 'finishing': 6.8, 'heading': 7.2, 'curl': 3.8, 'defensiveAwareness': -25.4, 'defensiveEngagement': -25.2, 'tackling': -25.6, 'aggression': 3.7, 'speed': 6.2, 'acceleration': 7.1, 'kickingPower': 6.8, 'jumping': 4.6, 'physicalContact': 6.8, 'balance': 4.3, 'stamina': 1.3},
    'CMF': {'attackingAwareness': 1.2, 'ballControl': 5.1, 'dribbling': 1.7, 'tightPossession': 3.7, 'lowPass': 4.7, 'loftedPass': 3.8, 'finishing': -9.1, 'heading': -11.0, 'curl': 0.8, 'defensiveAwareness': -5.3, 'defensiveEngagement': 3.4, 'tackling': -4.6, 'aggression': 0.9, 'speed': -4.1, 'acceleration': 0.5, 'kickingPower': 0.6, 'jumping': -0.2, 'physicalContact': 0.2, 'balance': 3.6, 'stamina': 4.4},
    'DMF': {'attackingAwareness': -12.4, 'ballControl': 2.9, 'dribbling': -4.8, 'tightPossession': 1.9, 'lowPass': 5.3, 'loftedPass': 2.1, 'finishing': -16.3, 'heading': 1.4, 'curl': -8.5, 'defensiveAwareness': 5.0, 'defensiveEngagement': 4.9, 'tackling': 4.7, 'aggression': 2.0, 'speed': -3.2, 'acceleration': 1.7, 'kickingPower': 1.7, 'jumping': 1.1, 'physicalContact': 4.5, 'balance': 1.4, 'stamina': 4.7},
    'FB': {'attackingAwareness': -14.2, 'ballControl': 2.3, 'dribbling': 1.8, 'tightPossession': 2.0, 'lowPass': 5.3, 'loftedPass': 4.5, 'finishing': -22.6, 'heading': -7.3, 'curl': -8.9, 'defensiveAwareness': 4.6, 'defensiveEngagement': 4.7, 'tackling': 4.4, 'aggression': 2.0, 'speed': 4.6, 'acceleration': 5.2, 'kickingPower': 1.5, 'jumping': 1.4, 'physicalContact': 1.5, 'balance': 2.1, 'stamina': 5.0},
    'MF': {'attackingAwareness': 4.4, 'ballControl': 1.9, 'dribbling': 4.2, 'tightPossession': 3.4, 'lowPass': 4.0, 'loftedPass': 4.4, 'finishing': -5.9, 'heading': -11.6, 'curl': 1.2, 'defensiveAwareness': -13.0, 'defensiveEngagement': 1.0, 'tackling': -13.6, 'aggression': 2.0, 'speed': 4.0, 'acceleration': 3.9, 'kickingPower': 1.1, 'jumping': 0.6, 'physicalContact': 1.2, 'balance': 2.3, 'stamina': 4.5},
    'SS': {'attackingAwareness': 5.9, 'ballControl': 6.4, 'dribbling': 6.4, 'tightPossession': 5.5, 'lowPass': 5.7, 'loftedPass': 2.6, 'finishing': 6.1, 'heading': -6.3, 'curl': 3.1, 'defensiveAwareness': -22.0, 'defensiveEngagement': -20.6, 'tackling': -22.2, 'aggression': 3.6, 'speed': 3.0, 'acceleration': 6.2, 'kickingPower': 3.1, 'jumping': 3.5, 'physicalContact': 3.0, 'balance': 3.7, 'stamina': 3.1},
    'WF': {'attackingAwareness': 7.2, 'ballControl': 7.5, 'dribbling': 7.4, 'tightPossession': 7.4, 'lowPass': 6.6, 'loftedPass': 6.6, 'finishing': 3.6, 'heading': -11.3, 'curl': 4.1, 'defensiveAwareness': -23.1, 'defensiveEngagement': -21.3, 'tackling': -23.4, 'aggression': 3.6, 'speed': 7.2, 'acceleration': 7.5, 'kickingPower': 4.1, 'jumping': 3.3, 'physicalContact': -6.4, 'balance': 4.9, 'stamina': 4.4},
  };

  static const _outfieldKeys = [
    'attackingAwareness', 'ballControl', 'dribbling', 'tightPossession', 'lowPass', 'loftedPass', 'finishing',
    'heading', 'curl', 'defensiveAwareness', 'defensiveEngagement', 'tackling', 'aggression', 'speed',
    'acceleration', 'kickingPower', 'jumping', 'physicalContact', 'balance', 'stamina',
  ];

  static PlayingStyle _pickStyle(String position, int Function(String) v) {
    final group = switch (position) {
      'ST' => 'CF',
      'LWF' || 'RWF' => 'WF',
      'LMF' || 'RMF' => 'MF',
      'LB' || 'RB' => 'FB',
      _ => position,
    };
    final candidates = _candidates[group] ?? _candidates['CMF']!;
    final mean = group == 'GK'
        ? (v('gkReflexes') + v('gkCatching') + v('gkParrying') + v('speed') + v('lowPass')) / 5
        : _outfieldKeys.map(v).reduce((a, b) => a + b) / _outfieldKeys.length;
    var best = candidates.keys.first;
    var bestScore = double.negativeInfinity;
    for (final e in candidates.entries) {
      var score = 0.0;
      final norm = _norms[group] ?? const <String, double>{};
      e.value.forEach((k, w) => score += k == '_' ? w : w * (v(k) - mean - (norm[k] ?? 0)) / 4);
      if (score > bestScore) {
        bestScore = score;
        best = e.key;
      }
    }
    return best;
  }
}
