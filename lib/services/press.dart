import 'dart:math';
import '../l10n/l10n.dart';
import '../models/club.dart';
import '../models/player.dart';

/// How an answer sounds: fans quote bold ones, mock evasive ones.
enum PressTone { bold, calm, evasive, critical }

/// One answer and what it changes: squad morale, fan mood, board
/// confidence and (optionally) one player's morale.
class PressAnswer {
  final String text;
  final int morale, fans, board;
  final String? playerId;
  final int playerMorale;
  final PressTone tone;
  const PressAnswer(
    this.text, {
    this.morale = 0,
    this.fans = 0,
    this.board = 0,
    this.playerId,
    this.playerMorale = 0,
    this.tone = PressTone.calm,
  });
}

/// A journalist's question (with the outlet asking it).
class PressQuestion {
  final String outlet, question;
  final List<PressAnswer> answers;
  const PressQuestion(this.outlet, this.question, this.answers);
}

/// What the journalists know before a match.
class PreMatchContext {
  final Club user, rival;
  final Player? rivalStar, unhappy, newSigning, youngster;
  final bool derby, home;
  final int position, rivalPosition, clubs, round;
  final int recentWins, recentLosses, injured, board;
  const PreMatchContext({
    required this.user,
    required this.rival,
    this.rivalStar,
    this.unhappy,
    this.newSigning,
    this.youngster,
    required this.derby,
    required this.home,
    required this.position,
    required this.rivalPosition,
    required this.clubs,
    required this.round,
    required this.recentWins,
    required this.recentLosses,
    required this.injured,
    required this.board,
  });
}

/// What the journalists saw in a match.
class PostMatchContext {
  final Club user, rival;
  final int scored, conceded;
  final Player? best, worst;
  final double bestRating, worstRating;
  final bool redCardAgainst, penaltyAgainst, derby;
  const PostMatchContext({
    required this.user,
    required this.rival,
    required this.scored,
    required this.conceded,
    this.best,
    this.worst,
    this.bestRating = 0,
    this.worstRating = 0,
    required this.redCardAgainst,
    required this.penaltyAgainst,
    required this.derby,
  });
}

/// Press conferences: questions picked from what is actually going on.
class Press {
  /// Invented outlets (no real media brands).
  static const outlets = ['Gol Gazetasi', 'Maydon TV', 'Futbol Kuryeri', 'Stadion Xabarlari', 'Sport Radio 24', 'Tribuna Live'];

  static String _outlet(Random rnd) => outlets[rnd.nextInt(outlets.length)];

  /// Three questions before a match (the first is always about the game).
  static List<PressQuestion> preMatch(PreMatchContext c, Random rnd) {
    final pool = <PressQuestion>[];
    final star = c.rivalStar;
    if (star != null) {
      pool.add(PressQuestion(_outlet(rnd), trf('Raqibning eng xavfli o‘yinchisi {0} haqida nima deysiz?', [star.shortName]), [
        PressAnswer(tr('Uni to‘xtatish rejamiz tayyor.'), morale: 4, fans: 2, tone: PressTone.bold),
        PressAnswer(tr('Zo‘r futbolchi, lekin futbol — jamoaviy o‘yin.'), morale: 2, fans: 1),
        PressAnswer(tr('Raqib haqida gapirmayman.'), fans: -2, tone: PressTone.evasive),
      ]));
    }
    if (c.derby) {
      pool.add(PressQuestion(_outlet(rnd), trf('{0} bilan derbi. Muxlislarga nima va’da berasiz?', [c.rival.name]), [
        PressAnswer(tr('G‘alaba – boshqa natijani qabul qilmaymiz!'), morale: 5, fans: 5, tone: PressTone.bold),
        PressAnswer(tr('Derbi – alohida o‘yin, hissiyotni nazorat qilamiz.'), morale: 2, fans: 1, board: 1),
        PressAnswer(tr('Bosim ularda, biz xotirjammiz.'), fans: -1, tone: PressTone.evasive),
      ]));
    }
    if (c.recentLosses >= 2) {
      pool.add(PressQuestion(_outlet(rnd), tr('Ketma-ket mag‘lubiyatlar. O‘rningiz xavf ostidami?'), [
        PressAnswer(tr('Jamoamga ishonaman, natija albatta keladi.'), morale: 4, fans: 1, board: 2),
        PressAnswer(tr('Hammasi uchun men javobgarman.'), morale: 3, fans: 3, board: -1, tone: PressTone.bold),
        PressAnswer(tr('Futbolchilar ko‘proq harakat qilishi kerak.'), morale: -6, fans: 2, tone: PressTone.critical),
      ]));
    }
    if (c.recentWins >= 3) {
      pool.add(PressQuestion(_outlet(rnd), tr('G‘alabali seriya davom etyapti. Chempionlik haqida gapirish vaqti keldimi?'), [
        PressAnswer(tr('Ha, biz chempionlik uchun kurashamiz!'), morale: 5, fans: 4, tone: PressTone.bold),
        PressAnswer(tr('Har bir o‘yin alohida, oyog‘imiz yerda.'), morale: 2, fans: 1, board: 2),
        PressAnswer(tr('Bunday savollarga javob bermayman.'), fans: -2, tone: PressTone.evasive),
      ]));
    }
    if (c.round > 6 && c.position <= 3) {
      pool.add(PressQuestion(_outlet(rnd), tr('Jadval yuqorisidasiz. Bosimni his qilyapsizmi?'), [
        PressAnswer(tr('Bosim – imtiyoz. Biz shu yerda bo‘lishni xohlaymiz.'), morale: 4, fans: 3, tone: PressTone.bold),
        PressAnswer(tr('Mavsum uzun, hali hech narsa hal bo‘lmagan.'), morale: 1, board: 2),
        PressAnswer(tr('Jadvalga qaramayman.'), fans: -1, tone: PressTone.evasive),
      ]));
    }
    if (c.round > 6 && c.position > c.clubs - 4) {
      pool.add(PressQuestion(_outlet(rnd), tr('Tushib ketish zonasi yaqin. Qutulish rejasi bormi?'), [
        PressAnswer(tr('Har bir o‘yin final. Biz bu zonadan chiqamiz.'), morale: 4, fans: 3, tone: PressTone.bold),
        PressAnswer(tr('Ishlayapmiz, natijalar yaxshilanadi.'), morale: 2, board: 1),
        PressAnswer(tr('Tarkib cheklangan, mo‘jiza kutmang.'), morale: -4, fans: -3, board: -2, tone: PressTone.critical),
      ]));
    }
    if (c.board < 40) {
      pool.add(PressQuestion(_outlet(rnd), tr('Kengash sabri tugayapti degan gaplar bor. Izoh bering.'), [
        PressAnswer(tr('Prezident bilan muloqotimiz yaxshi, ishonch bor.'), board: 3),
        PressAnswer(tr('Natija ko‘rsataman, gap kerak emas.'), morale: 3, fans: 2, tone: PressTone.bold),
        PressAnswer(tr('Kengash qarorlari meni qiziqtirmaydi.'), fans: 1, board: -5, tone: PressTone.critical),
      ]));
    }
    final unhappy = c.unhappy;
    if (unhappy != null) {
      pool.add(PressQuestion(_outlet(rnd), trf('{0} klubdan ketmoqchi degan mish-mishlar bor. Izoh?', [unhappy.shortName]), [
        PressAnswer(tr('U bizning muhim o‘yinchimiz va shu yerda qoladi.'), morale: 1, playerId: unhappy.id, playerMorale: 10),
        PressAnswer(tr('Hech kim klubdan katta emas.'), morale: 2, fans: 2, playerId: unhappy.id, playerMorale: -10, tone: PressTone.critical),
        PressAnswer(tr('Ichki masalalarni ommaga olib chiqmaymiz.'), tone: PressTone.evasive),
      ]));
    }
    final signing = c.newSigning;
    if (signing != null) {
      pool.add(PressQuestion(_outlet(rnd), trf('Yangi transfer {0} qanday moslashyapti?', [signing.shortName]), [
        PressAnswer(tr('Ajoyib! U jamoaga aynan kerakli sifatni olib keldi.'), morale: 1, fans: 2, playerId: signing.id, playerMorale: 8, tone: PressTone.bold),
        PressAnswer(tr('Vaqt kerak, unga bosim o‘tkazmaylik.'), playerId: signing.id, playerMorale: 3),
        PressAnswer(tr('Hali u kutganimizdek emas.'), playerId: signing.id, playerMorale: -8, fans: -1, tone: PressTone.critical),
      ]));
    }
    final young = c.youngster;
    if (young != null) {
      pool.add(PressQuestion(_outlet(rnd), trf('{0} kabi yoshlarga ko‘p ishonch bildiryapsiz. Sabab?', [young.shortName]), [
        PressAnswer(tr('Kelajak – akademiyamiz. U bunga loyiq.'), fans: 3, playerId: young.id, playerMorale: 8, tone: PressTone.bold),
        PressAnswer(tr('Raqobat bor, kim yaxshi bo‘lsa o‘ynaydi.'), morale: 2, playerId: young.id, playerMorale: 2),
        PressAnswer(tr('Boshqa iloj yo‘q, tarkib qisqa.'), board: -1, playerId: young.id, playerMorale: -5, tone: PressTone.critical),
      ]));
    }
    if (c.injured >= 3) {
      pool.add(PressQuestion(_outlet(rnd), trf('{0} ta futbolchi jarohatda. Bu bahona bo‘ladimi?', [c.injured]), [
        PressAnswer(tr('Bahona yo‘q. Maydondagi 11 kishi yetarli.'), morale: 4, fans: 2, tone: PressTone.bold),
        PressAnswer(tr('Qiyin davr, lekin tarkibimiz chuqur.'), morale: 2, board: 1),
        PressAnswer(tr('Albatta ta’sir qiladi, hamma buni tushunsin.'), morale: -2, tone: PressTone.evasive),
      ]));
    }
    pool.shuffle(rnd);
    return [
      PressQuestion(_outlet(rnd), trf('{0} bilan uchrashuv oldidan jamoa kayfiyati qanday?', [c.rival.name]), [
        PressAnswer(tr('Biz faqat g‘alaba uchun chiqamiz!'), morale: 6, fans: 3, tone: PressTone.bold),
        PressAnswer(tr('Har bir o‘yin qiyin, raqibni hurmat qilamiz.'), morale: 2),
        PressAnswer(tr('Raqib favorit, bosim ularda.'), morale: -3, fans: -2, tone: PressTone.evasive),
      ]),
      ...pool.take(2),
    ];
  }

  /// Up to three questions after a match.
  static List<PressQuestion> postMatch(PostMatchContext c, Random rnd) {
    final diff = c.scored - c.conceded;
    final out = <PressQuestion>[
      if (diff > 0)
        PressQuestion(_outlet(rnd), trf('{0}:{1} – g‘alaba siri nimada?', [c.scored, c.conceded]), [
          PressAnswer(tr('Reja ishladi, yigitlar ajoyib bajarishdi.'), morale: 4, fans: 2),
          PressAnswer(tr('Bu – boshlanishi xolos. Bundan ham kuchliroq bo‘lamiz!'), morale: 3, fans: 4, tone: PressTone.bold),
          PressAnswer(tr('Ochkolar muhim, o‘yin sifati emas.'), fans: -1, tone: PressTone.evasive),
        ])
      else if (diff == 0)
        PressQuestion(_outlet(rnd), tr('Durang – adolatli natijami?'), [
          PressAnswer(tr('Biz g‘alabaga loyiq edik.'), morale: 2, fans: 2, tone: PressTone.bold),
          PressAnswer(tr('Bir ochko ham ochko. Davom etamiz.'), morale: 1, board: 1),
          PressAnswer(tr('Hujumda o‘tkirlik yetmadi, ishlaymiz.'), morale: -1, board: 1, tone: PressTone.critical),
        ])
      else
        PressQuestion(_outlet(rnd), trf('{0}:{1} mag‘lubiyat. Nima yetishmadi?', [c.scored, c.conceded]), [
          PressAnswer(tr('Mas’uliyat menda. Xatolarni tuzatamiz.'), morale: 3, fans: 2, board: 1),
          PressAnswer(tr('Ba’zi futbolchilar o‘z darajasida o‘ynamadi.'), morale: -5, fans: 1, tone: PressTone.critical),
          PressAnswer(tr('Omad bizdan yuz o‘girdi.'), fans: -3, tone: PressTone.evasive),
        ]),
    ];
    if (c.redCardAgainst || c.penaltyAgainst) {
      out.add(PressQuestion(_outlet(rnd), tr('Hakamlik qarorlari haqida nima deysiz?'), [
        PressAnswer(tr('Hakam o‘yinni buzdi! Bu adolatsizlik.'), morale: 3, fans: 4, board: -3, tone: PressTone.critical),
        PressAnswer(tr('Qarorlarni muhokama qilmayman, o‘zimizga qaraymiz.'), morale: 1, board: 2),
        PressAnswer(tr('VAR bor, savollar u yerga.'), fans: 1, tone: PressTone.evasive),
      ]));
    }
    final best = c.best;
    if (best != null && c.bestRating >= 7.5) {
      out.add(PressQuestion(_outlet(rnd), trf('{0} bugun ajoyib o‘ynadi ({1}). Baholang.', [best.shortName, c.bestRating.toStringAsFixed(1)]), [
        PressAnswer(tr('Jahon darajasidagi o‘yin! Unga faxrlanaman.'), fans: 2, playerId: best.id, playerMorale: 8, tone: PressTone.bold),
        PressAnswer(tr('Yaxshi, lekin bu jamoaviy natija.'), morale: 2, playerId: best.id, playerMorale: 2),
        PressAnswer(tr('Undan doim shuni kutamiz.'), playerId: best.id, playerMorale: -2),
      ]));
    }
    final worst = c.worst;
    if (worst != null && c.worstRating <= 6.0 && worst != best) {
      out.add(PressQuestion(_outlet(rnd), trf('{0} qiyin kun o‘tkazdi. Uni himoya qilasizmi?', [worst.shortName]), [
        PressAnswer(tr('Har kimda yomon kun bo‘ladi, unga ishonaman.'), morale: 1, playerId: worst.id, playerMorale: 6),
        PressAnswer(tr('U yaxshiroq o‘ynashi kerak, tarkib uchun raqobat bor.'), fans: 2, playerId: worst.id, playerMorale: -8, tone: PressTone.critical),
        PressAnswer(tr('Alohida futbolchilarni muhokama qilmayman.'), tone: PressTone.evasive),
      ]));
    }
    if (diff <= -3) {
      out.add(PressQuestion(_outlet(rnd), tr('Muxlislar g‘azabda. Ularga nima deysiz?'), [
        PressAnswer(tr('Kechirim so‘rayman. Keyingi o‘yinda javob beramiz.'), morale: 2, fans: 5),
        PressAnswer(tr('Muxlislar sabr qilsin, jarayon ketyapti.'), fans: -2, board: 1, tone: PressTone.evasive),
        PressAnswer(tr('Tanqidni tushunaman, lekin jamoani bo‘lishmaylik.'), morale: 3, fans: 1, tone: PressTone.bold),
      ]));
    }
    return out.take(3).toList();
  }
}
