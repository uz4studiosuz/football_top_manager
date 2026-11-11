import 'package:flutter/material.dart';
import '../models/club.dart';
import '../l10n/l10n.dart';

enum TouchlineOrder {
  breather(
    'breather',
    'Nafas rostlash',
    'Temp va pressing pasayadi; kuch tejaladi, raqibga ko‘proq vaqt beriladi.',
    'pace',
    Icons.spa_outlined,
  ),
  back(
    'back',
    'Himoyadan pas bilan chiqish',
    'Qisqa uzatmalar bilan hujum quriladi; orqadagi pressing xavf tug‘dirishi mumkin.',
    'build',
    Icons.outbox_outlined,
  ),
  overload(
    'overload',
    'Bor kuch bilan hujum',
    'Ko‘proq futbolchi oldinga chiqadi; qarshi hujum uchun bo‘shliq qoladi.',
    'shape',
    Icons.keyboard_double_arrow_up,
  ),
  shut(
    'shut',
    'Natijani saqlash',
    'Past, ixcham blok va ehtiyotkor hujum; raqib bosimi ortishi mumkin.',
    'shape',
    Icons.lock_outline,
  ),
  keeper(
    'keeper',
    'Darvozabon standartga chiqsin',
    '85-daqiqadan keyin hisobda ortda bo‘lsak, darvozabon burchak to‘piga boradi.',
    'keeper',
    Icons.sports_handball_outlined,
  ),
  long(
    'long',
    'Uzun to‘plar',
    'Uzoq uzatmalar oldingi chiziqqa yo‘naltiriladi; to‘pni yo‘qotish xavfi oshadi.',
    'build',
    Icons.north_east,
  ),
  fast(
    'fast',
    'Tezkor o‘yin',
    'Qarorlar tezlashadi va hujum intensivligi oshadi; futbolchilar tezroq charchaydi.',
    'pace',
    Icons.bolt,
  ),
  patient(
    'patient',
    'Sabr bilan o‘ynash',
    'Sekinroq temp, qisqa pas va nazorat; raqib himoyaga joylashishga ulguradi.',
    'pace',
    Icons.psychology_outlined,
  ),
  physical(
    'physical',
    'Jismoniy kurash',
    'Olib qo‘yishga dadilroq kirishiladi; qoidabuzarlik va kartochka xavfi oshadi.',
    'duel',
    Icons.fitness_center,
  ),
  wings(
    'wings',
    'Qanotdan hujum',
    'Jamoa kengroq joylashadi va qanotdagi sheriklarni izlaydi.',
    'width',
    Icons.unfold_more,
  ),
  centre(
    'centre',
    'Markazdan hujum',
    'Jamoa torroq joylashadi; markaziy kombinatsiyalar ustun bo‘ladi.',
    'width',
    Icons.unfold_less,
  ),
  disrupt(
    'disrupt',
    'Raqib ritmini buzish',
    'Faol bosim va keskin kurash; kuch sarfi va qoida buzish ehtimoli ortadi.',
    'duel',
    Icons.sports_kabaddi,
  ),
  ease(
    'ease',
    'Pressingni kamaytirish',
    'Blok saqlanadi va kuch tejaladi; raqib bemalolroq pas beradi.',
    'press',
    Icons.keyboard_arrow_down,
  ),
  press(
    'press',
    'Yuqori pressing',
    'To‘pni tez qaytarish uchun ikki futbolchi bosim qiladi; ortda bo‘shliq ochiladi.',
    'press',
    Icons.keyboard_arrow_up,
  ),
  swap(
    'swap',
    'Qanotlarni almashtirish',
    'Keng hujumchilarning maydondagi qanotlari almashadi; tarkib o‘zgarmaydi.',
    'swap',
    Icons.sync,
  ),
  slow(
    'slow',
    'Vaqtni cho‘zish',
    'Temp pasayadi va to‘p xavfsizroq saqlanadi.',
    'pace',
    Icons.hourglass_bottom,
  );

  const TouchlineOrder(this.id, this.text, this.hint, this.group, this.icon);
  final String id, text, hint, group;
  final IconData icon;
  String get label => tr(text);
  String get description => tr(hint);
  static TouchlineOrder? byId(String id) =>
      values.where((o) => o.id == id).firstOrNull;
}

abstract final class TouchlineOrders {
  static void toggle(Set<String> selected, String id) {
    if (selected.remove(id)) return;
    final order = TouchlineOrder.byId(id);
    if (order == null) return;
    selected.removeWhere(
      (other) => TouchlineOrder.byId(other)?.group == order.group,
    );
    // A breather and a hard press are contradictory energy instructions.
    if (id == 'breather') selected.removeAll({'press', 'disrupt'});
    if (id == 'press' || id == 'disrupt') selected.remove('breather');
    selected.add(id);
  }

  static TeamTactics apply(TeamTactics base, Set<String> selected) {
    var t = base;
    if (selected.contains('wings')) {
      t = t.copyWith(attackingArea: AttackingArea.wide, width: 5);
    }
    if (selected.contains('centre')) {
      t = t.copyWith(attackingArea: AttackingArea.centre, width: 2);
    }
    if (selected.contains('back')) {
      t = t.copyWith(buildUp: BuildUpStyle.short, playOutFromBack: true);
    }
    if (selected.contains('long')) {
      t = t.copyWith(buildUp: BuildUpStyle.long, playOutFromBack: false);
    }
    if (selected.contains('overload')) {
      t = t.copyWith(
        attackingIntensity: 5,
        defensiveLine: 4,
        flexiblePositioning: true,
      );
    }
    if (selected.contains('shut')) {
      t = t.copyWith(
        attackingIntensity: 1,
        defensiveLine: 1,
        compactness: 5,
        defensiveApproach: DefensiveApproach.allOutDefence,
      );
    }
    if (selected.contains('breather')) {
      t = t.copyWith(
        tempo: 1,
        pressing: 1,
        counterPress: false,
        attackingIntensity: 2,
        timeWasting: false,
      );
    }
    if (selected.contains('fast')) t = t.copyWith(tempo: 5, timeWasting: false);
    if (selected.contains('patient')) {
      t = t.copyWith(tempo: 2, timeWasting: false);
    }
    if (selected.contains('slow')) t = t.copyWith(tempo: 1, timeWasting: true);
    if (selected.contains('physical')) t = t.copyWith(tacklingIntensity: 5);
    if (selected.contains('disrupt')) {
      t = t.copyWith(tacklingIntensity: 5, pressing: 4);
    }
    if (selected.contains('ease')) {
      t = t.copyWith(pressing: 1, counterPress: false);
    }
    if (selected.contains('press')) {
      t = t.copyWith(pressing: 5, counterPress: true);
    }
    if (selected.contains('keeper')) t = t.copyWith(keeperUpForCorners: true);
    if (selected.contains('swap')) t = t.copyWith(swapWings: !base.swapWings);
    return t;
  }
}
