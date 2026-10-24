"""One-off patch: info buttons for team tactics settings."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
p = ROOT / 'lib/screens/widgets/team_instructions_view.dart'
s = p.read_text(encoding='utf8')


def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:70])
    s = s.replace(a, b, 1)


rep("""            Text(tr(label), style: AppText.bodyStrong),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<T>(""", """            Row(
              children: [
                Expanded(child: Text(tr(label), style: AppText.bodyStrong)),
                _Info(label),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<T>(""")
rep("""            Expanded(child: Text(tr(label), style: AppText.bodyStrong)),
            Text('$value / 5', style: AppText.number.copyWith(fontSize: 13, color: AppColors.primary)),""",
    """            Expanded(child: Text(tr(label), style: AppText.bodyStrong)),
            _Info(label),
            Text('$value / 5', style: AppText.number.copyWith(fontSize: 13, color: AppColors.primary)),""")
rep("""            Expanded(child: Text(low, style: AppText.caption)),
            Text(high, style: AppText.caption),""", """            Expanded(child: Text(tr(low), style: AppText.caption)),
            Text(tr(high), style: AppText.caption),""")
rep("""  Widget _switch(String title, String subtitle, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(tr(title), style: AppText.bodyStrong),""", """  Widget _switch(String title, String subtitle, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Row(
      children: [
        Flexible(child: Text(tr(title), style: AppText.bodyStrong)),
        _Info(title),
      ],
    ),""")
rep("""/// Captain, set-piece takers and per-player instructions for the XI.""", '''/// What each team setting does, for players new to tactics. Keys are the
/// Uzbek setting names (translated labels are looked up the same way).
const _help = <String, String>{
  'Hujum qurilishi': 'Qisqa – himoyadan pas bilan chiqish: to‘p nazorati yuqori, lekin o‘z yarmingizda to‘p yo‘qotish xavfi bor. Uzun – to‘p tezda oldinga uzatiladi: xavf kam, lekin to‘p tez-tez yo‘qotiladi. Aralash – vaziyatga qarab.',
  'Hujum hududi': 'Qanotlar – hujum qanotdan, krosslar ko‘payadi. Markaz – qisqa paslar va markazdan yorib kirish. Muvozanatli – ikkalasi aralash.',
  'Hujum intensivligi': 'Hujumga nechta futbolchi qo‘shilishi. Yuqori qiymat – ko‘proq zarba va imkoniyat, lekin orqada bo‘shliq qoladi va raqib qarshi hujumiga zaif bo‘lasiz.',
  'Temp': 'Jamoa qanchalik tez qaror qabul qiladi. Tez – ko‘proq hujum, lekin paslar aniqligi pasayadi va futbolchilar tezroq charchaydi. Sekin – to‘p nazorati va aniq paslar.',
  'Qanot kengligi': 'Hujumda futbolchilar qanchalik keng joylashadi. Keng – raqib himoyasi cho‘ziladi, qanotdan kross ko‘p. Tor – markazda ko‘proq odam, qisqa paslar.',
  'Erkin pozitsiyalash': 'Yoqilsa futbolchilar o‘z joyidan chiqib bo‘sh joy qidiradi: raqib uchun kutilmagan, lekin himoyaga qaytish sekinlashadi.',
  'Himoyadan qisqa pas': 'Darvozabon to‘pni himoyachiga beradi va hujum orqadan quriladi. O‘chirilsa darvozabon uzun uradi – xavfsizroq, lekin to‘p ko‘pincha yo‘qotiladi.',
  'Himoya yondashuvi': 'Frontline Pressure – raqibni yuqorida siqish. Muvozanat – o‘rtacha. All-out Defence – hamma orqada, gol o‘tkazish qiyin, lekin hujum sust.',
  'Qamal hududi': 'Raqibni qayerga yo‘naltirish. Markazni yopish – raqib qanotga chiqishga majbur. Qanotlarni yopish – raqib markazdan o‘ynaydi.',
  'Himoya chizig‘i': 'Himoyachilar qanchalik yuqorida turadi. Baland chiziq – jamoa ixcham, raqib ofsaydga ko‘p tushadi, lekin himoya ortiga uzun pasga zaif. Past blok – orqada xavfsiz, lekin raqib ko‘proq to‘p nazorat qiladi.',
  'Ixchamlik': 'Futbolchilar orasidagi masofa. Zich – markazda bo‘shliq kam, lekin qanotlar ochiladi. Keng – maydonni ko‘proq yopadi, lekin chiziqlar orasida bo‘shliq qoladi.',
  'Pressing': 'To‘p egasiga qanchalik tez va ko‘p bosim qilinadi. Agressiv – to‘pni yuqorida qaytarib olish ko‘payadi, lekin charchoq va qoidabuzarlik ham ko‘payadi.',
  'Yo‘qotishdan keyin pressing': 'To‘p yo‘qotilgan zahoti uni qaytarib olishga urinish (gegenpress). Raqib qarshi hujumi qiyinlashadi, lekin futbolchilar tez charchaydi.',
  'Ofsayd tuzog‘i': 'Himoyachilar bir chiziqda oldinga chiqib hujumchini ofsaydda qoldiradi. Ko‘p ofsayd beradi, lekin xato bo‘lsa raqib darvozabon bilan yakkama-yakka qoladi.',
  'Vaqtni cho‘zish': 'Hisobda oldinda bo‘lsangiz 75-daqiqadan keyin jamoa o‘yinni sekinlashtiradi: kamroq xavf, lekin sariq kartochka ehtimoli oshadi.',
};

class _Info extends StatelessWidget {
  final String label;
  const _Info(this.label);
  @override
  Widget build(BuildContext context) {
    final text = _help[label];
    if (text == null) return const SizedBox.shrink();
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: tr('Bu nima?'),
      icon: const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.ink3),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tr(label), style: AppText.h3)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(tr(text), style: AppText.body.copyWith(height: 1.45)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Captain, set-piece takers and per-player instructions for the XI.''')
p.write_text(s, encoding='utf8')
print('ok')
