import 'dart:math';

/// Uzbek match commentary with several phrasings per moment, so the live
/// log reads like a broadcast instead of repeating one template.
/// Placeholders: {p} actor, {a} second player, {t} team, {o} opponent,
/// {s} score line.
class Commentary {
  final Random random;
  Commentary(this.random);

  static const _bank = <String, List<String>>{
    'kickoff': [
      'Hakam hushtak chaldi – uchrashuv boshlandi!',
      'O‘yin boshlandi. {t} markazdan to‘pni harakatga keltirdi.',
      'Stadionda shovqin – birinchi bo‘lim start oldi!',
    ],
    'secondHalf': [
      'Ikkinchi bo‘lim boshlandi. {t} to‘pni markazdan surdi.',
      'Jamoalar maydonga qaytdi – ikkinchi bo‘lim ketdi!',
    ],
    'goal': [
      'GOL! {p} to‘rni silkitdi! {s}',
      'GOOOL! {p} darvozabonga imkon qoldirmadi! {s}',
      'GOL! {p} aniq zarba bilan hisobni o‘zgartirdi. {s}',
      '{p} — GOL! {t} muxlislari o‘rnidan turib ketdi! {s}',
    ],
    'goalAssist': [
      'GOL! {a} uzatmasidan so‘ng {p} to‘pni darvozaga joyladi! {s}',
      'GOOOL! {a} ajoyib pas berdi, {p} xato qilmadi! {s}',
      '{a} → {p}: chiroyli kombinatsiya va GOL! {s}',
    ],
    'header': [
      'GOL! {p} bosh bilan zarbani darvozaga yo‘lladi! {s}',
      'Havodagi kurashda {p} ustun keldi – GOL! {s}',
    ],
    'penaltyGoal': [
      'GOL! {p} penaltini ishonch bilan amalga oshirdi. {s}',
      '{p} 11 metrlikdan xato qilmadi – GOL! {s}',
    ],
    'freeKickGoal': [
      'Ajoyib! {p} jarima zarbasini to‘g‘ridan-to‘g‘ri darvozaga kiritdi! {s}',
      'GOL! {p} devor ustidan to‘pni burchakka yo‘lladi! {s}',
    ],
    'save': [
      '{p} zarbani ajoyib tarzda qaytardi!',
      'Darvozabon {p} jamoasini qutqarib qoldi.',
      '{p} sakrab to‘pni qaytardi.',
      'Aniq zarba, ammo {p} joyida edi.',
    ],
    'saveCorner': [
      '{p} to‘pni burchakka chiqarib yubordi.',
      '{p} zarbani qaytardi, burchak to‘pi tayinlandi.',
    ],
    'miss': [
      '{p} zarbasi darvoza yonidan o‘tib ketdi.',
      '{p} nishonga tegmadi – to‘p tribunaga uchdi.',
      '{p} zarba berdi, ammo to‘p darvozadan ancha uzoqda.',
    ],
    'bigChanceMiss': [
      'Qanday imkoniyat! {p} bo‘sh darvozaga ham kirita olmadi!',
      '{p} 100 foizlik vaziyatni boy berdi!',
      'Katta imkoniyat – {p} uni amalga oshira olmadi.',
    ],
    'woodwork': [
      'USTUN! {p} zarbasi darvoza ustuniga tegdi!',
      'To‘sin! {p} omadsizlik qildi.',
    ],
    'block': [
      '{a} zarbani tanasi bilan to‘sib qoldi.',
      '{p} zarbasini {a} blokladi.',
    ],
    'shot': [
      '{p} uzoqdan zarba berishga qaror qildi.',
      '{p} darvozani nishonga oldi.',
      '{p} jarima maydoni chetidan zarba yo‘lladi.',
    ],
    'headerShot': [
      '{p} bosh bilan zarba berdi.',
      '{p} krossni bosh bilan yo‘naltirdi.',
    ],
    'tackle': [
      '{p} ajoyib Olib qo'yish bilan to‘pni oldi.',
      '{p} o‘z vaqtida to‘pni tortib oldi.',
      '{p} kurashda ustun keldi.',
    ],
    'interception': [
      '{p} uzatmani kesib qoldi.',
      '{p} pas yo‘lini to‘sib, to‘pni egalladi.',
    ],
    'dribble': [
      '{p} raqibini aldab o‘tdi!',
      '{p} chiroyli finti bilan {a}ni ortda qoldirdi.',
      '{p} dribling bilan oldinga yorib o‘tdi.',
    ],
    'cross': [
      '{p} jarima maydoniga kross oshirdi.',
      '{p} qanotdan to‘pni markazga yubordi.',
    ],
    'clearance': [
      '{p} to‘pni xavfli hududdan chiqarib tashladi.',
      '{p} havoda ustun kelib, krossni qaytardi.',
    ],
    'foul': [
      '{p} qoidani buzdi. Jarima zarbasi.',
      'Hakam {p}ning qo‘pol harakatini qayd etdi.',
      '{p} raqibni ushlab qoldi – hushtak.',
    ],
    'yellow': [
      '{p} sariq kartochka oldi.',
      'Hakam {p}ga sariq kartochka ko‘rsatdi.',
      '{p} qo‘pollik uchun ogohlantirildi.',
    ],
    'secondYellow': [
      '{p} ikkinchi sariq kartochkani oldi va maydondan chetlatildi!',
    ],
    'red': [
      'QIZIL KARTOCHKA! {p} maydonni tark etadi!',
    ],
    'penaltyAwarded': [
      'PENALTI! {a} jarima maydonida {p}ni yiqitdi!',
      'Hakam 11 metrlik nuqtani ko‘rsatdi! {p} qulatildi.',
    ],
    'penaltySaved': [
      '{a} penaltini qaytardi! {p} uddalay olmadi!',
      'Qaytardi! {a} penaltini to‘xtatib qoldi!',
    ],
    'penaltyMissed': [
      '{p} penaltini darvoza yonidan o‘tkazib yubordi!',
    ],
    'freeKick': [
      '{p} jarima zarbasini to‘g‘ridan-to‘g‘ri darvozaga yo‘lladi.',
      'Standart vaziyat: {p} zarbaga tayyorlanmoqda.',
    ],
    'corner': [
      'Burchak to‘pi: {t}.',
      '{t} burchak to‘pi ijro etmoqda.',
    ],
    'offside': [
      'Ofsayd: {p}.',
      'Ofsayd: {p} erta harakat qildi.',
    ],
    'injury': [
      '{p} jarohat oldi va yordam so‘ramoqda.',
      '{p} oqsoqlanib qoldi – shifokorlar maydonda.',
    ],
    'sub': [
      'Almashtirish ({t}): {p} maydonga tushdi, {a} chiqdi.',
      '{t}da o‘zgarish: {a} o‘rniga {p}.',
    ],
    'halfTime': [
      'Birinchi bo‘lim yakunlandi. {s}',
      'Tanaffus. Hisob: {s}',
    ],
    'fullTime': [
      'Final hushtagi! Uchrashuv yakunlandi. {s}',
      'O‘yin tugadi. Yakuniy hisob: {s}',
    ],
    'addedTime': [
      'Qo‘shimcha vaqt: {p} daqiqa.',
    ],
    'tactic': [
      '{t} murabbiyi jamoani "{p}" rejimiga o‘tkazdi.',
    ],
  };

  String say(
    String key, {
    String p = '',
    String a = '',
    String t = '',
    String o = '',
    String s = '',
  }) {
    final options = _bank[key] ?? const ['{p}'];
    return options[random.nextInt(options.length)]
        .replaceAll('{p}', p)
        .replaceAll('{a}', a)
        .replaceAll('{t}', t)
        .replaceAll('{o}', o)
        .replaceAll('{s}', s);
  }
}
