# Google Play’ga chiqarish: qadamma-qadam

Avval `docs/LEGAL_AUDIT.md` ni o‘qing. Ma’lumotlar bazasi va ismlar masalasi hal bo‘lmaguncha ilovani chiqarmang.

## 0. Bir martalik sozlamalar (qilingan)

- `applicationId` = **`uz.uz4studios.ftm27`** (`android/app/build.gradle.kts`). Birinchi yuklashdan keyin uni **hech qachon o‘zgartirib bo‘lmaydi**. Boshqa identifikator kerak bo‘lsa, hozir o‘zgartiring: `applicationId`, `namespace` va `MainActivity.kt` papkasi/paketi.
- Ilova nomi: `android/app/src/main/AndroidManifest.xml` → `android:label`.
- Ikonka va banner: `python -I tool/make_icons.py` (android mipmap’lari, web ikonkalari, `store/`).
- `targetSdk` 36, `minSdk` 24 (Flutter standarti), INTERNET ruxsati yo‘q.

## 1. Imzolash kaliti (upload key)

Bir marta yarating va **xavfsiz joyda, zaxira nusxasi bilan** saqlang. Kalit yo‘qolsa, Play Console orqali kalitni almashtirish so‘raladi.

```bash
keytool -genkey -v -keystore C:/Users/user/keys/ftm27-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias ftm27
```

Keyin `android/key.properties` faylini yarating. U `.gitignore`da bor, gitga tushmaydi:

```properties
storePassword=PAROL
keyPassword=PAROL
keyAlias=ftm27
storeFile=C:/Users/user/keys/ftm27-upload.jks
```

`build.gradle.kts` bu faylni o‘zi topadi. Fayl yo‘q bo‘lsa, release build debug kalit bilan imzolanadi va Play uni qabul qilmaydi.

## 2. Versiya

`pubspec.yaml` → `version: 1.0.0+1`. Har bir yangi yuklashda `+` dan keyingi raqamni (versionCode) oshiring: `1.0.1+2`, `1.1.0+3`…

## 3. Play build (uydirma ismlar bilan)

```bash
python -I tool/build_play.py
```

Skript nima qiladi:
1. `assets/data` ni vaqtinchalik papkaga nusxalaydi.
2. `tool/fictionalize.py` bilan barcha klub, futbolchi, murabbiy, stadion va liga nomlarini uydirmaga almashtiradi, o‘xshatilgan yuzlarni o‘chiradi, reytinglarni ±2 ga o‘zgartiradi.
3. `flutter build appbundle --release` ni ishga tushiradi.
4. Har qanday holatda asl ma’lumotlarni qaytaradi.

Natija: `build/app/outputs/bundle/release/app-release.aab`.

> Oddiy `flutter build appbundle` haqiqiy ismlar bilan yig‘adi. Uni do‘konga yuklamang.

Yuklashdan oldin telefonda sinab ko‘ring:

```bash
flutter build apk --release
```

```bash
flutter install
```

## 4. Play Console

1. https://play.google.com/console → *Create app* (dasturchi akkaunti: bir martalik $25).
2. **App content** bo‘limi (`docs/STORE_LISTING.md` dagi javoblar):
   - Privacy policy URL: `docs/PRIVACY_POLICY.md` ni GitHub Pages yoki Google Sites’ga joylang va havolasini kiriting.
   - Ads: No. Content rating: IARC anketasi. Target audience: 13+. Data safety: no data collected.
3. **Main store listing**: nom, qisqa va to‘liq tavsif (uz/en/ru), `store/icon-512.png`, `store/feature-graphic.png`, kamida 2 ta telefon skrinshoti (uydirma ismli build’dan).
4. **Testing → Internal testing**: `app-release.aab` ni yuklang, o‘zingizni tester qilib qo‘shing, telefonda o‘rnatib tekshiring.
5. Yangi shaxsiy akkauntlar uchun Google talabi: **Closed testing**da kamida 12 ta tester 14 kun davomida sinashi kerak. Shundan keyingina Production’ga chiqarish ochiladi.
6. **Production → Create release** → AAB → *Review and roll out*.

## 5. Har bir yangilanishda

- [ ] `pubspec.yaml` da versionCode oshirildi
- [ ] `flutter analyze` va `flutter test` toza
- [ ] `python -I tool/build_play.py`
- [ ] Release notes (uz/en/ru)
- [ ] Internal testing’da tekshirildi, keyin Production
