# Ma’lumotlar bazasini tahrirlash

Baza `assets/data/` dagi JSON fayllardan iborat:

| Fayl | Nima |
|---|---|
| `league.json` | Barcha ligalar ro‘yxati: nomi, davlati, bayrog‘i, darajasi, iqtisodiyoti, ko‘tarilish/tushish, fayl yo‘llari |
| `clubs.json` + `players.json` | Super League |
| `clubs_epl.json` + `players_epl.json` | Premier League (`tool/epl_data.py`) |
| `clubs_ch.json`, `clubs_l1.json`, `clubs_uzb.json` (+ players) | Championship, League One, O‘zbekiston (`tool/efl_data.py`) |
| `world/<id>.json` | Qolgan 122 liga, har biri bitta faylda (`clubs` + `players`) (`tool/world_data.py`) |
| `world/index.json` | Barcha dunyo klublari ro‘yxati (ish takliflari va qidiruv uchun) |
| `names.json` | Yangi futbolchilar uchun ismlar havzalari (`tool/names_data.py`) |

Dunyo liga identifikatorlari “davlat kodi + daraja (+ guruh)” ko‘rinishida: `it1` — Serie A, `es2` — LaLiga2, `it3b` — Serie C, B guruhi.

## 1-usul: o‘yin ichidagi muharrir (eng oson)

Ilovada: yuqori o‘ngdagi profil rasmi → **Baza muharriri**. Web’da to‘g‘ridan-to‘g‘ri `…/#/editor` manzili. Kompyuterda katta tahrirlar uchun `tool/db_studio/index.html` ham bor (CSV eksport/import bilan, `docs/DATABASE.md`).

**Masalan, Juventusni o‘zgartirish:**
1. Chapdagi qidiruvga `Juventus` deb yozing. Natijalarda klub va uning ligasi (🇮🇹 Serie A) chiqadi.
2. Klubni bosing: liga yuklanadi (bir soniya) va tarkib ochiladi.
3. Klub ma’lumotlarini tahrirlang: nomi, ranglari, stadion, byudjet, obro‘, gerb.
4. Futbolchini tanlang: ismi, yoshi, pozitsiyasi, atributlari, yuzi (rasmdan ham bo‘ladi). Futbolchini boshqa klubga ko‘chirish yoki yangi futbolchi qo‘shish ham mumkin.
5. **Saqlash**: o‘zgarishlar shu qurilmada saqlanadi va **yangi karyeralarda** ishlatiladi. Joriy karyera o‘zgarmaydi.
6. **Eksport (ZIP)**: o‘zgargan fayllar ZIP’ga yoziladi. Uni loyihaning `assets/data/` papkasiga ochsangiz, o‘zgarishlar ilovaning o‘ziga kiradi (barcha foydalanuvchilar uchun).

Ro‘yxatda faqat ochilgan ligalar ko‘rinadi. Boshqa davlatlar uchun qidiruvdan yoki “Dunyo ligasini ochish” tugmasidan foydalaning.

## 2-usul: dasturchi sifatida fayllarni to‘g‘ridan-to‘g‘ri tahrirlash

1. Kerakli faylni oching. Masalan, Juventus `assets/data/world/it1.json` da.
2. `clubs` ro‘yxatida klubni toping (`"name": "Juventus"`). `squadIds`, `startingLineupIds` (11 ta) va `benchIds` dagi id’lar `players` ro‘yxatidagi o‘yinchilarga ishora qiladi.
3. Dunyo fayllarida `stats` hajmni tejash uchun **massiv** ko‘rinishida (26 ta son). Tartibi `lib/data/initial_database.dart` dagi `statKeys` da. Odatiy `{"finishing": 85, …}` obyekt ko‘rinishi ham qabul qilinadi. Muharrir eksport qilgan fayllar shu ko‘rinishda bo‘ladi.
4. Tahrirlangan liga id’sini `tool/world_keep.txt` ga yozing (masalan `it1`). Aks holda `python -I tool/world_data.py` qayta ishga tushirilganda fayl bazadan qayta yaratiladi va o‘zgarishlaringiz yo‘qoladi.
5. Tekshiring: `flutter test test/world_leagues_test.dart` barcha ligalarni yuklab, tarkiblarni tekshiradi. Takror id’lar, 11 tadan kam asosiy tarkib yoki egasiz futbolchi bo‘lsa, xato beradi.

**Qoidalar:**
- Klub va o‘yinchi id’lari butun baza bo‘yicha noyob bo‘lishi kerak.
- Ligada juft sonli va kamida 4 ta klub bo‘lishi kerak, aks holda liga o‘yinda ko‘rinmaydi.
- Har bir klubda kamida 2 ta darvozabon va 16 ta o‘yinchi tavsiya etiladi.

## Yangi liga qo‘shish

- **Muharrirda:** “+ Liga” tugmasi, keyin “+ Klub”.
- **Fayl bilan:** `world/` ga yangi fayl qo‘shing va `league.json` ga yozuv kiriting (`id`, `name`, `country`, `flag`, `tier`, `economy`, `clubsFile`, `playersFile`, `lazy: true`). Bir davlatning darajalari bitta piramida bo‘lishi uchun `pyramid`, `promote`, `relegate` maydonlarini bering.

## Bazani 2026.db’dan qayta yaratish

```bash
python -I tool/world_data.py
```

```bash
python -I tool/names_data.py
```

`world_keep.txt` dagi ligalar o‘zgarmaydi. Qolganlari bazadan qayta yoziladi.

## Play build uchun uydirma ismlar

`python -I tool/build_play.py` yig‘ish paytida barcha ismlarni vaqtincha uydirmaga almashtiradi, keyin asl fayllarni qaytaradi. Batafsil: `docs/PLAY_STORE.md`, `docs/LEGAL_AUDIT.md`.
