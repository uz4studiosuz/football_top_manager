import 'dart:math';
import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/league.dart';
import '../models/player.dart';
import '../l10n/l10n.dart';

/// Club buildings the manager can upgrade (levels 0–5).
enum Facility {
  stadium('Stadion', 'Har bir bosqich o‘rindiqlar qo‘shadi (80 000 gacha): chipta tushumi oshadi.', Icons.stadium_outlined),
  medical('Tibbiyot markazi', 'Jarohat muddati har bosqichda 10% qisqaradi (50% gacha).', Icons.medical_services_outlined),
  training('Mashg‘ulot bazasi', 'Futbolchilar, ayniqsa yoshlar, tezroq rivojlanadi.', Icons.fitness_center_outlined),
  academy('Yoshlar akademiyasi', 'Ko‘proq va iste’dodliroq yoshlar; “Oltin avlod” ehtimoli oshadi.', Icons.school_outlined);

  const Facility(this._label, this._effect, this.icon);
  final String _label, _effect;
  final IconData icon;
  String get label => tr(_label);
  String get effect => tr(_effect);
  static const maxLevel = 5;
}

/// Backroom staff (levels 0–5); each costs a weekly wage.
enum StaffRole {
  assistant('Taktik yordamchi', 'Har darajada jamoaning taktik uyg‘unligi oshadi.', Icons.psychology_outlined),
  fitness('Fitnes murabbiyi', 'Chidamlilik tezroq tiklanadi, jarohatlar kamayadi.', Icons.monitor_heart_outlined),
  goalkeeping('Darvozabonlar murabbiyi', 'Darvozabonlar tezroq rivojlanadi.', Icons.sports_handball_outlined),
  scouting('Bosh skaut', 'Skautlar tezroq va aniqroq ishlaydi, ko‘proq topshiriq oladi.', Icons.travel_explore_outlined);

  const StaffRole(this._label, this._effect, this.icon);
  final String _label, _effect;
  final IconData icon;
  String get label => tr(_label);
  String get effect => tr(_effect);
}

/// Weekly team training emphasis.
enum TrainingFocus {
  balanced('Muvozanatli', 'Hamma yo‘nalish teng.', Icons.balance_outlined),
  attacking('Hujum', 'Hujum atributlari tezroq o‘sadi; o‘yinda hujum biroz kuchliroq.', Icons.sports_soccer),
  defensive('Himoya', 'Himoya atributlari tezroq o‘sadi; raqib imkoniyatlari biroz kamayadi.', Icons.shield_outlined),
  fitness('Jismoniy holat', 'Chidamlilik tez tiklanadi, o‘yinda kamroq charchaydi.', Icons.directions_run),
  tactical('Taktik uyg‘unlik', 'Paslar va jamoaviy harakat aniqroq.', Icons.schema_outlined);

  const TrainingFocus(this._label, this._effect, this.icon);
  final String _label, _effect;
  final IconData icon;
  String get label => tr(_label);
  String get effect => tr(_effect);
}

/// A fan's post in the social feed.
class FanPost {
  final String author, text;
  final int likes;
  final bool positive;
  final String when;
  const FanPost(this.author, this.text, this.likes, this.positive, this.when);
  Map<String, dynamic> toMap() => {'a': author, 't': text, 'l': likes, 'p': positive ? 1 : 0, 'w': when};
  factory FanPost.fromMap(Map<String, dynamic> m) => FanPost(m['a'], m['t'], m['l'] ?? 0, m['p'] == 1, m['w'] ?? '');
}

/// End-of-season honours.
class SeasonAwards {
  final String season, ballonDor, goldenBoot, youngPlayer;
  final List<String> teamOfSeason; // "POS · Name · Club"
  const SeasonAwards(this.season, this.ballonDor, this.goldenBoot, this.youngPlayer, this.teamOfSeason);
  Map<String, dynamic> toMap() => {'s': season, 'b': ballonDor, 'g': goldenBoot, 'y': youngPlayer, 't': teamOfSeason};
  factory SeasonAwards.fromMap(Map<String, dynamic> m) =>
      SeasonAwards(m['s'], m['b'], m['g'], m['y'], List<String>.from(m['t'] ?? const []));
}

/// A press-conference question with three answers (morale, fan mood effects).
class PressQuestion {
  final String question;
  final List<(String answer, int morale, int fans)> answers;
  const PressQuestion(this.question, this.answers);
}

/// Everything about running the club beyond the first team: facilities,
/// training, academy, fans, press and the club's history.
class ClubLife {
  final Map<Facility, int> levels = {for (final f in Facility.values) f: 0};

  /// Upgrades under construction: facility → round it opens.
  final Map<Facility, int> building = {};
  TrainingFocus focus = TrainingFocus.balanced;

  /// Individual training: player id → attribute key or `style:<name>`.
  final Map<String, String> targets = {};
  final Map<String, double> progress = {};
  final List<FanPost> feed = [];
  final List<SeasonAwards> awards = [];
  final Set<String> pressDone = {};

  /// The latest academy intake (player ids), shown in the academy tab.
  final List<String> lastIntake = [];

  /// Dressing room: user matches each player has missed in a row, players
  /// who asked to leave, and promises of playing time (id → deadline round).
  final Map<String, int> benchRounds = {};

  /// Staff levels, scouted players, scouting assignments (id → due round)
  /// and the current youth search (nationality, due round).
  final Map<StaffRole, int> staff = {};

  /// Players out on loan (id → club id), job offers (club ids) and whether
  /// the board has sacked the manager.
  final Map<String, String> loans = {};

  /// Sponsor offers on the table and the signed deal: name, type
  /// ('fixed', 'wins', 'target'), money per round and the bonus.
  final List<Map<String, dynamic>> sponsorOffers = [];
  Map<String, dynamic>? sponsor;
  final List<String> jobOffers = [];
  bool sacked = false;
  final Set<String> scouted = {};
  final Map<String, int> scoutQueue = {};
  String? youthMission;
  int youthMissionDue = 0;

  int staffLevel(StaffRole r) => staff[r] ?? 0;

  /// Weekly wage of a staff member at [level].
  static int staffWage(int level, double economy) =>
      level == 0 ? 0 : ((3000 * pow(level, 1.6) * max(0.15, economy)) / 500).round() * 500;
  final Set<String> wantsOut = {};
  final Map<String, int> promises = {};

  // Club records.
  String biggestWin = '';
  int biggestMargin = 0;
  String bestSeasonScorer = '';
  int bestSeasonGoals = 0;
  final Map<String, (String, int)> allTimeScorers = {};

  /// Manager records: results, streaks, best season.
  int wins = 0, draws = 0, losses = 0;
  int winStreak = 0, bestWinStreak = 0, unbeaten = 0, bestUnbeaten = 0;
  int bestPoints = 0, bestFinish = 0;
  String bestPointsSeason = '', bestFinishSeason = '';
  final List<String> trophies = [];

  int level(Facility f) => levels[f] ?? 0;
  double get injuryFactor => 1 - 0.1 * level(Facility.medical);
  double get growthFactor => 1 + 0.18 * level(Facility.training);

  /// Upgrade price, scaled by the league's economy.
  static int upgradeCost(Facility f, int currentLevel, double economy) {
    final base = switch (f) {
      Facility.stadium => 14000000 + currentLevel * 9000000,
      Facility.medical => 4000000 + currentLevel * 3000000,
      Facility.training => 5000000 + currentLevel * 4000000,
      Facility.academy => 5000000 + currentLevel * 3500000,
    };
    return ((base * max(0.25, economy)) / 100000).round() * 100000;
  }

  /// Rounds a construction takes.
  static int buildRounds(Facility f) => f == Facility.stadium ? 6 : 3;

  /// Seats added by the next stadium stage.
  static int seatsAdded(int capacity) => min(80000 - capacity, max(4000, (capacity * 0.18).round()));

  void reset() {
    for (final f in Facility.values) {
      levels[f] = 0;
    }
    building.clear();
    focus = TrainingFocus.balanced;
    targets.clear();
    progress.clear();
    feed.clear();
    awards.clear();
    pressDone.clear();
    lastIntake.clear();
    benchRounds.clear();
    staff.clear();
    loans.clear();
    sponsorOffers.clear();
    sponsor = null;
    jobOffers.clear();
    sacked = false;
    scouted.clear();
    scoutQueue.clear();
    youthMission = null;
    youthMissionDue = 0;
    wantsOut.clear();
    promises.clear();
    biggestWin = '';
    biggestMargin = 0;
    bestSeasonScorer = '';
    bestSeasonGoals = 0;
    allTimeScorers.clear();
    wins = draws = losses = winStreak = bestWinStreak = unbeaten = bestUnbeaten = bestPoints = bestFinish = 0;
    bestPointsSeason = bestFinishSeason = '';
    trophies.clear();
  }

  void post(FanPost p) {
    feed.insert(0, p);
    if (feed.length > 60) feed.removeRange(60, feed.length);
  }

  // ------------------------------------------------------------ fans
  static const _handles = [
    'ultra', 'fanat', 'tribuna', 'kapo', 'derbi', 'gol', 'oyin', 'muxlis', 'stadion', 'jonkuyar',
  ];

  static String _author(Club c, Random rnd) =>
      '@${c.shortName.toLowerCase()}_${_handles[rnd.nextInt(_handles.length)]}${rnd.nextInt(99)}';

  /// Fan reactions to one of the user's matches.
  List<FanPost> matchPosts({
    required Club user,
    required Club rival,
    required int scored,
    required int conceded,
    required Map<String, int> userGoals,
    required List<(Player, double)> ratings,
    required int? firstSubMinute,
    required String when,
    required Random rnd,
  }) {
    final out = <FanPost>[];
    void add(String text, bool positive) =>
        out.add(FanPost(_author(user, rnd), text, 20 + rnd.nextInt(positive ? 900 : 500), positive, when));
    final diff = scored - conceded;
    for (final e in userGoals.entries) {
      if (e.value >= 3) {
        add(trf('{0} yana xet-trik qildi! Bu mavsum chempionmiz! 🔥', [e.key]), true);
      }
    }
    if (diff >= 3) {
      add(trf('{0}:{1}! {2}ni tor-mor qildik. Bugun hammasi zo‘r edi! 🔥', [scored, conceded, rival.name]), true);
    } else if (diff > 0) {
      add(trf('Muhim 3 ochko! {0}ga qarshi g‘alaba 👏', [rival.name]), true);
    } else if (diff == 0) {
      add(tr('Durang... Bundan yaxshiroq o‘ynash mumkin edi.'), false);
    } else if (diff <= -3) {
      add(trf('Uyat! {0}:{1}. Murabbiy javob bersin! #Out', [scored, conceded]), false);
    } else {
      add(tr('Yomon kun. Keyingi o‘yinda qaytamiz 💪'), false);
    }
    if (diff <= 0 && (firstSubMinute == null || firstSubMinute >= 78)) {
      add(
        firstSubMinute == null
            ? tr('Murabbiy nimaga umuman almashtirish qilmadi?! #Out')
            : trf('Murabbiy nimaga {0}-daqiqagacha almashtirish qilmadi?! #Out', [firstSubMinute]),
        false,
      );
    }
    if (ratings.isNotEmpty) {
      final sorted = List.of(ratings)..sort((a, b) => b.$2.compareTo(a.$2));
      final best = sorted.first, worst = sorted.last;
      if (best.$2 >= 7.8) add(trf('{0} bugun boshqa sayyoradan edi ({1}) ⭐', [best.$1.shortName, best.$2.toStringAsFixed(1)]), true);
      if (worst.$2 <= 5.9) {
        add(trf('{0} bugun juda yomon o‘ynadi ({1}). Tarkibdan chiqarish kerak!', [worst.$1.shortName, worst.$2.toStringAsFixed(1)]), false);
      }
    }
    return out;
  }

  /// Fan reaction to a big transfer.
  FanPost transferPost(Club user, Player p, int fee, bool signed, String when, Random rnd) {
    final big = fee >= 30000000;
    final text = signed
        ? big && p.ovr < 82
            ? trf('{0}ga {1} sarflash xato bo‘lmadimikan... 🤔', [p.shortName, _money(fee)])
            : trf('{0} keldi! Yulduzni kutib oling! ⭐', [p.shortName])
        : p.ovr >= 80
        ? trf('{0}ni sotish xato edi...', [p.shortName])
        : trf('{0} uchun {1} — yaxshi savdo 👍', [p.shortName, _money(fee)]);
    final positive = signed ? !(big && p.ovr < 82) : p.ovr < 80;
    return FanPost(_author(user, rnd), text, 50 + rnd.nextInt(1500), positive, when);
  }

  static String _money(int v) =>
      v >= 1000000 ? '€${(v / 1000000).toStringAsFixed(1)}M' : '€${(v / 1000).round()}K';

  // ------------------------------------------------------------ press
  static List<PressQuestion> pressQuestions(Club rival, Player? star) => [
    PressQuestion(trf('{0} bilan uchrashuv oldidan jamoa kayfiyati qanday?', [rival.name]), [
      (tr('Biz faqat g‘alaba uchun chiqamiz!'), 6, 3),
      (tr('Har bir o‘yin qiyin, raqibni hurmat qilamiz.'), 2, 0),
      (tr('Raqib favorit, bosim ularda.'), -3, -2),
    ]),
    PressQuestion(
      star == null
          ? tr('Raqibning eng kuchli tomoni nima?')
          : trf('Raqibning eng xavfli o‘yinchisi {0} haqida nima deysiz?', [star.shortName]),
      [
        (tr('Uni to‘xtatish rejamiz tayyor.'), 4, 2),
        (tr('Zo‘r futbolchi, lekin futbol — jamoaviy o‘yin.'), 2, 1),
        (tr('Raqib haqida gapirmayman.'), 0, -2),
      ],
    ),
  ];

  // ------------------------------------------------------------ records
  void recordMatch(Club user, Club rival, int scored, int conceded, String season, List<MatchEvent> events) {
    final margin = scored - conceded;
    if (margin > 0) {
      wins++;
      winStreak++;
      unbeaten++;
    } else if (margin == 0) {
      draws++;
      winStreak = 0;
      unbeaten++;
    } else {
      losses++;
      winStreak = 0;
      unbeaten = 0;
    }
    bestWinStreak = max(bestWinStreak, winStreak);
    bestUnbeaten = max(bestUnbeaten, unbeaten);
    if (margin > biggestMargin) {
      biggestMargin = margin;
      biggestWin = '$scored:$conceded · ${rival.name} · $season';
    }
    for (final e in events) {
      if (e.type != MatchEventType.goal || e.playerId == null) continue;
      final p = user.playerById(e.playerId!);
      if (p == null) continue;
      final prev = allTimeScorers[p.id];
      allTimeScorers[p.id] = (p.name, (prev?.$2 ?? 0) + 1);
    }
  }

  // ------------------------------------------------------------ save
  Map<String, dynamic> toMap() => {
    'lv': {for (final e in levels.entries) e.key.name: e.value},
    'bd': {for (final e in building.entries) e.key.name: e.value},
    'fo': focus.name,
    'tg': targets,
    'pr': {for (final e in progress.entries) e.key: double.parse(e.value.toStringAsFixed(3))},
    'fd': feed.map((p) => p.toMap()).toList(),
    'aw': awards.map((a) => a.toMap()).toList(),
    'pd': pressDone.toList(),
    'in': lastIntake,
    'br': benchRounds,
    'sf': {for (final e in staff.entries) e.key.name: e.value},
    'ln': loans,
    'so': sponsorOffers,
    if (sponsor != null) 'sp': sponsor,
    'jo': jobOffers,
    'sk': sacked,
    'sc2': scouted.toList(),
    'sq': scoutQueue,
    if (youthMission != null) 'ym': [youthMission, youthMissionDue],
    'wo': wantsOut.toList(),
    'pm': promises,
    'bw': [biggestWin, biggestMargin],
    'bs': [bestSeasonScorer, bestSeasonGoals],
    'sc': {for (final e in allTimeScorers.entries) e.key: [e.value.$1, e.value.$2]},
    'tr': trophies,
    'rec': [wins, draws, losses, winStreak, bestWinStreak, unbeaten, bestUnbeaten, bestPoints, bestFinish, bestPointsSeason, bestFinishSeason],
  };

  void restore(Map<String, dynamic>? m) {
    reset();
    if (m == null) return;
    final facility = Facility.values.asNameMap();
    (m['lv'] as Map? ?? {}).forEach((k, v) {
      if (facility[k] != null) levels[facility[k]!] = v as int;
    });
    (m['bd'] as Map? ?? {}).forEach((k, v) {
      if (facility[k] != null) building[facility[k]!] = v as int;
    });
    focus = TrainingFocus.values.asNameMap()[m['fo']] ?? TrainingFocus.balanced;
    targets.addAll(Map<String, String>.from(m['tg'] ?? {}));
    (m['pr'] as Map? ?? {}).forEach((k, v) => progress[k as String] = (v as num).toDouble());
    feed.addAll([for (final p in (m['fd'] as List? ?? [])) FanPost.fromMap(Map<String, dynamic>.from(p))]);
    awards.addAll([for (final a in (m['aw'] as List? ?? [])) SeasonAwards.fromMap(Map<String, dynamic>.from(a))]);
    pressDone.addAll(List<String>.from(m['pd'] ?? const []));
    lastIntake.addAll(List<String>.from(m['in'] ?? const []));
    benchRounds.addAll(Map<String, int>.from(m['br'] ?? {}));
    loans.addAll(Map<String, String>.from(m['ln'] ?? {}));
    sponsorOffers.addAll([for (final o in (m['so'] as List? ?? [])) Map<String, dynamic>.from(o)]);
    sponsor = m['sp'] == null ? null : Map<String, dynamic>.from(m['sp']);
    jobOffers.addAll(List<String>.from(m['jo'] ?? const []));
    sacked = m['sk'] == true;
    final roles = StaffRole.values.asNameMap();
    (m['sf'] as Map? ?? {}).forEach((k, v) {
      if (roles[k] != null) staff[roles[k]!] = v as int;
    });
    scouted.addAll(List<String>.from(m['sc2'] ?? const []));
    scoutQueue.addAll(Map<String, int>.from(m['sq'] ?? {}));
    final ym = m['ym'] as List?;
    if (ym != null) {
      youthMission = ym[0] as String;
      youthMissionDue = ym[1] as int;
    }
    wantsOut.addAll(List<String>.from(m['wo'] ?? const []));
    promises.addAll(Map<String, int>.from(m['pm'] ?? {}));
    final bw = m['bw'] as List? ?? const ['', 0];
    biggestWin = bw[0];
    biggestMargin = bw[1];
    final bs = m['bs'] as List? ?? const ['', 0];
    bestSeasonScorer = bs[0];
    bestSeasonGoals = bs[1];
    (m['sc'] as Map? ?? {}).forEach((k, v) => allTimeScorers[k as String] = ((v as List)[0] as String, v[1] as int));
    trophies.addAll(List<String>.from(m['tr'] ?? const []));
    final rec = m['rec'] as List?;
    if (rec != null && rec.length == 11) {
      wins = rec[0];
      draws = rec[1];
      losses = rec[2];
      winStreak = rec[3];
      bestWinStreak = rec[4];
      unbeaten = rec[5];
      bestUnbeaten = rec[6];
      bestPoints = rec[7];
      bestFinish = rec[8];
      bestPointsSeason = rec[9];
      bestFinishSeason = rec[10];
    }
  }
}
