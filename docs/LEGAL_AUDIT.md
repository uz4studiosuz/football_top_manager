# Mualliflik huquqi va Google Play qoidalari bo‘yicha tekshiruv

Tekshiruv sanasi: 2026-yil 25-oktabr. Bu huquqiy maslahat emas. Men advokat emasman. Pastdagilar kod va ma’lumotlarni ko‘rib chiqish natijasi. Ilovani chiqarishdan oldin intellektual mulk bo‘yicha yurist bilan maslahatlashing.

## Qisqa xulosa

| Xavf | Daraja | Holat |
|---|---|---|
| Boshqa o‘yindan olingan ma’lumotlar bazasi (2026.db) | **Yuqori** | Play build’da ismlar uydirmaga almashtiriladi, reytinglar ±2 ga o‘zgartiriladi, lekin baza tuzilmasi baribir o‘sha manbadan |
| Haqiqiy futbolchilar ismlari va o‘xshatilgan yuzlari | **Yuqori** | `tool/build_play.py` ismlarni almashtiradi, yuz ishoralarini o‘chiradi |
| Klub, liga va musobaqa nomlari (savdo belgilari) | **Yuqori** | Play build’da uydirma nomlar; koddagi UEFA nomlari umumiy nomlarga almashtirildi |
| “Football Top Manager” nomi ↔ SEGA’ning “Football Manager” savdo belgisi | **O‘rta** | Nomni o‘zgartirish tavsiya etiladi (pastda) |
| Klub gerblari | Past | Kodda chiziladigan umumiy shakllar, haqiqiy logotip yo‘q |
| Shriftlar, paketlar | Past | Roboto — Apache 2.0, Flutter paketlari — BSD/MIT |
| Shaxsiy ma’lumotlar | Past | Hech narsa yig‘ilmaydi, tarmoq ishlatilmaydi |
| Reklama, xaridlar, qimor | Yo‘q | FTM tangalari faqat o‘yinda topiladi, pulga sotilmaydi |

## 1. Ma’lumotlar bazasi (eng katta xavf)

`2026.db` (shuningdek `superkickoff.db`) Telegram orqali kelgan, boshqa futbol menejeri ilovasining ichki bazasiga o‘xshaydi (ispancha jadval nomlari: `jug_jugadores`, `eq_equipos`…). Undagi tanlangan tarkiblar, reytinglar va ko‘nikmalar o‘sha ilova mualliflarining mehnati. Ko‘p mamlakatlarda bu mualliflik huquqi yoki baza huquqi bilan himoyalangan.

- `assets/data/world/*` va Championship, League One, O‘zbekiston fayllari shu bazadan yaratilgan (`tool/world_data.py`, `tool/efl_data.py`).
- Ismlarni almashtirish va reytinglarni ±2 ga o‘zgartirish xavfni kamaytiradi, lekin yo‘qotmaydi: tarkiblar, yoshlar va kuch nisbatlari baribir o‘sha manbadan.

**Tavsiya:**
- Yo baza egasidan ruxsat oling.
- Yoki Play versiyasini to‘liq o‘zingizning ma’lumotlaringiz bilan chiqaring: tasodifiy generator (`tool/expand_squads.py` uslubida) yoki ochiq litsenziyali manba.
- Haqiqiy baza o‘yinchining o‘zi import qiladigan fayl bo‘lib qolishi mumkin (muharrirdagi ZIP import). Ilova bilan birga tarqatilmaydi.

## 2. Haqiqiy shaxslar (futbolchilar, murabbiylar)

Haqiqiy futbolchilar ismlari, yoshi, millati va “o‘xshatilgan yuzlari” (`tool/epl_faces.py`, `face` maydonlari) shaxsiy va tasvir huquqlariga tegadi. Futbolchilar ismlari odatda FIFPRO yoki klublar orqali litsenziyalanadi. Google Play’ning *Impersonation* va *Intellectual Property* siyosatlari bo‘yicha shikoyat tushsa, ilova o‘chiriladi.

**Qilingan ish:** `tool/build_play.py` Play build uchun:
- har bir o‘yinchiga o‘z millatidagi ismlar havzasidan uydirma ism beradi;
- murabbiy ismlarini almashtiradi;
- `face` (o‘xshatish) ma’lumotlarini o‘chiradi;
- reytinglarni ±2 ga o‘zgartiradi.

## 3. Savdo belgilari: klublar, ligalar, musobaqalar

“Real Madrid”, “Juventus”, “Premier League”, “LaLiga”, “Bundesliga”, “Serie A” va boshqalar ro‘yxatdan o‘tgan savdo belgilari. UEFA nomlari (“Chempionlar ligasi”, “Yevropa ligasi”, “Konferensiya ligasi”) ham shunday.

**Qilingan ish:**
- Kodda “Kontinental kubok”, “Ikkinchi kontinental kubok”, “Kontinental saralash” ishlatiladi.
- Play build’da klublar “<shahar> FK / Atletik / Sporting…”, stadionlar “<shahar> Arena”, ligalar “Birinchi / Ikkinchi / Uchinchi divizion” bo‘ladi.
- Klub ranglari saqlanadi. Ranglar o‘zi himoyalanmaydi, lekin nom va gerb bilan birga “aldovchi o‘xshashlik” bo‘lmasligi kerak, shuning uchun gerb monogrammasi ham yangi nomdan olinadi.

**Qolgan ish:** “Super League” nomini ham neytral nomga (masalan, “Gigantlar ligasi”) almashtirish mumkin.

## 4. Ilova nomi

SEGA / Sports Interactive “Football Manager” savdo belgisiga ega. “Football Top Manager” ichida shu ibora bor, shuning uchun do‘konda chalkashtirish shikoyati ehtimoli bor.

**Tavsiya:** o‘ziga xos nom tanlang, masalan “Tribuna Boss”, “Maydon Menejeri”, “FTM 27: Football Tactics”. Nomni o‘zgartirsangiz, `android:label`, `web/manifest.json`, `lib/main.dart` dagi `title` va `store/` grafikalarini yangilang (`python -I tool/make_icons.py`).

## 5. Gerblar, shriftlar, ikonka

- Gerblar `lib/models/crest.dart` dagi umumiy shakllar (qalqon, doira, hayvon emblemalari) va ranglardan chiziladi. Haqiqiy logotip fayllari yo‘q.
- Shrift: Roboto (Apache 2.0, `assets/fonts/LICENSE.txt`).
- Ilova ikonkasi va banner kodda chizilgan (`tool/make_icons.py`), begona grafika yo‘q.
- Bayroqlar Unicode emoji.
- Paketlar: `shared_preferences`, `file_picker`, `image_picker`, `web`, `cupertino_icons` — BSD yoki MIT. Flutter’ning litsenziyalar sahifasi (`showLicensePage`) ularni avtomatik ko‘rsatadi. Sozlamalarga “Litsenziyalar” tugmasini qo‘shish tavsiya etiladi.

## 6. Google Play siyosatlari bo‘yicha boshqa bandlar

- **Ma’lumotlar xavfsizligi (Data safety):** ilova hech qanday ma’lumot yig‘maydi va uzatmaydi (INTERNET ruxsati yo‘q). Rasmdan yuz yaratishda rasm faqat qurilmada qayta ishlanadi va hech qayerga yuborilmaydi. Batafsil: `docs/PRIVACY_POLICY.md`.
- **Maxfiylik siyosati URL:** baribir talab qilinadi. Faylni ochiq saytga (GitHub Pages, Google Sites) joylang.
- **O‘yin ichidagi valyuta:** FTM tangalari pulga sotilmaydi, shuning uchun “In-app purchases” yo‘q. Kelajakda sotilsa, Google Play Billing majburiy bo‘ladi.
- **Kontent reytingi (IARC):** zo‘ravonlik, qimor, foydalanuvchilar muloqoti yo‘q. Taxminan PEGI 3 / Everyone.
- **Maqsadli auditoriya:** 13+ ni tanlang. “Bolalar uchun” deb belgilasangiz, *Families* siyosatining qo‘shimcha talablari qo‘llanadi.
- **Texnik talablar:** `targetSdk` = 36 (Flutter 3.44 standarti), 64-bit, AAB format, `applicationId` = `uz.uz4studios.ftm27`.

## Chiqarishdan oldingi ro‘yxat

- [ ] Ma’lumotlar bazasi masalasi hal qilindi (ruxsat yoki o‘z ma’lumotlari)
- [ ] Play build faqat `python -I tool/build_play.py` bilan yig‘ildi (uydirma ismlar)
- [ ] Ilova nomi tanlandi va savdo belgilari bazasida tekshirildi (WIPO Global Brand Database)
- [ ] Maxfiylik siyosati ochiq URL’da
- [ ] Yurist bilan maslahat qilindi
