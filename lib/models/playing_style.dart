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

  const PlayingStyle(this.title, this.uzbek, this.description);
  final String title, uzbek, description;
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

  const DefendingStyle(this.title, this.uzbek);
  final String title, uzbek;
}

enum AiStyle {
  trickster('Trickster', 'Fintchi'),
  mazingRun('Mazing Run', 'Ajoyib dribling'),
  speedingBullet('Speeding Bullet', 'Tezkor o‘q'),
  incisiveRun('Incisive Run', 'Keskin yorib kirish'),
  longBallExpert('Long Ball Expert', 'Uzun pas ustasi'),
  earlyCrosser('Early Crosser', 'Erta kross'),
  longRanger('Long Ranger', 'Uzoqdan zarba');

  const AiStyle(this.title, this.uzbek);
  final String title, uzbek;
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
    final passing = (v('lowPass') + v('loftedPass')) / 2;
    final defence = (v('defensiveAwareness') + v('tackling') + v('defensiveEngagement')) / 3;
    final physical = (v('physicalContact') + v('heading') + v('jumping')) / 3;
    PlayingStyle style;
    switch (position) {
      case 'GK':
        style = v('speed') >= 58 || v('lowPass') >= 70 ? PlayingStyle.attackingGoalkeeper : PlayingStyle.defensiveGoalkeeper;
      case 'ST':
      case 'CF':
        if (physical >= 82 && v('physicalContact') >= 82) {
          style = PlayingStyle.targetMan;
        } else if (passing >= 80 && v('tightPossession') >= 84) {
          style = PlayingStyle.deepLyingForward;
        } else if (pace >= 88 && v('finishing') >= 84) {
          style = PlayingStyle.goalPoacher;
        } else if (v('finishing') >= 86 && pace < 80) {
          style = PlayingStyle.foxInTheBox;
        } else if (v('attackingAwareness') >= 84 && v('lowPass') >= 78) {
          style = PlayingStyle.dummyRunner;
        } else {
          style = PlayingStyle.advancedStriker;
        }
      case 'SS':
        style = passing >= 80 ? PlayingStyle.deepLyingForward : PlayingStyle.holePlayer;
      case 'LWF':
      case 'RWF':
        if (v('finishing') >= 82) {
          style = PlayingStyle.prolificWinger;
        } else if (v('loftedPass') >= 80 && v('curl') >= 78) {
          style = PlayingStyle.crossSpecialist;
        } else {
          style = PlayingStyle.roamingFlank;
        }
      case 'LMF':
      case 'RMF':
        style = v('loftedPass') >= 78 ? PlayingStyle.crossSpecialist : v('stamina') >= 84 ? PlayingStyle.boxToBox : PlayingStyle.roamingFlank;
      case 'AMF':
        if (v('lowPass') >= 86) {
          style = PlayingStyle.creativePlaymaker;
        } else if (v('finishing') >= 80 || v('attackingAwareness') >= 84) {
          style = PlayingStyle.holePlayer;
        } else if (pace < 78) {
          style = PlayingStyle.classicNo10;
        } else {
          style = PlayingStyle.creativePlaymaker;
        }
      case 'CMF':
        if (v('loftedPass') >= 84 && v('lowPass') >= 84) {
          style = PlayingStyle.orchestrator;
        } else if (v('tackling') >= 80 && v('aggression') >= 78) {
          style = PlayingStyle.destroyer;
        } else if (v('stamina') >= 84 && defence >= 70) {
          style = PlayingStyle.boxToBox;
        } else if (v('attackingAwareness') >= 80) {
          style = PlayingStyle.holePlayer;
        } else {
          style = PlayingStyle.creativePlaymaker;
        }
      case 'DMF':
        if (passing >= 84) {
          style = PlayingStyle.orchestrator;
        } else if (v('aggression') >= 80 || v('tackling') >= 86) {
          style = PlayingStyle.destroyer;
        } else if (v('stamina') >= 86) {
          style = PlayingStyle.boxToBox;
        } else {
          style = PlayingStyle.anchorMan;
        }
      case 'CB':
        if (v('lowPass') >= 80 || v('loftedPass') >= 82) {
          style = PlayingStyle.buildUp;
        } else if (v('heading') >= 84 && v('attackingAwareness') >= 60) {
          style = PlayingStyle.extraFrontman;
        } else if (v('aggression') >= 84) {
          style = PlayingStyle.destroyer;
        } else {
          style = PlayingStyle.buildUp;
        }
      default: // LB, RB
        if (v('finishing') >= 72) {
          style = PlayingStyle.fullBackFinisher;
        } else if (pace >= 84 || v('attackingAwareness') >= 76) {
          style = PlayingStyle.attackingFullBack;
        } else {
          style = PlayingStyle.defensiveFullBack;
        }
    }
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
}
