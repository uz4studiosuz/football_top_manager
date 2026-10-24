/// Parametric portrait. Every value is an index into a style table drawn by
/// `FaceAvatar`, so a face is a tiny serialisable record.
class FaceConfig {
  static const skinCount = 10,
      hairColorCount = 9,
      cutCount = 14,
      shapeCount = 5,
      eyesCount = 4,
      eyeColorCount = 5,
      noseCount = 4,
      mouthCount = 4,
      browCount = 4,
      ageCount = 3,
      beardCount = 6;

  static const cutLabels = [
    'Qisqa',
    'Yon farq',
    'Kok',
    'Jingalak',
    'Nol',
    'Kal',
    'To‘lqin',
    'Afro',
    'Uzun',
    'Tugun',
    'Dredlar',
    'Irokez',
    'Orqaga',
    'Chakka',
  ];
  static const beardLabels = [
    'Yo‘q',
    'Tuk',
    'Qisqa',
    'To‘liq',
    'Echkisoqol',
    'Mo‘ylov',
  ];
  static const shapeLabels = ['Oval', 'Kvadrat', 'Dumaloq', 'Uzun', 'Yurak'];

  final int skin, hair, cut, shape, eyes, nose, mouth, brow, age, eyeColor;
  final int beardStyle;
  final bool glasses, freckles;
  const FaceConfig({
    this.skin = 2,
    this.hair = 0,
    this.cut = 0,
    this.shape = 0,
    this.eyes = 0,
    this.nose = 1,
    this.mouth = 1,
    this.brow = 1,
    this.age = 0,
    this.eyeColor = 0,
    this.beardStyle = 0,
    this.glasses = false,
    this.freckles = false,
  });

  bool get beard => beardStyle > 0;

  static int _hash(String s) =>
      s.codeUnits.fold<int>(17, (a, b) => (a * 31 + b) & 0x7fffffff);

  factory FaceConfig.seed(String id) {
    var n = _hash(id);
    int next(int mod) {
      n = (n * 1103515245 + 12345) & 0x7fffffff;
      return (n >> 8) % mod;
    }

    return FaceConfig(
      skin: next(skinCount),
      hair: next(6),
      cut: next(cutCount),
      shape: next(shapeCount),
      eyes: next(eyesCount),
      nose: next(noseCount),
      mouth: next(mouthCount),
      brow: next(browCount),
      age: next(ageCount),
      eyeColor: next(eyeColorCount),
      beardStyle: next(10) < 5 ? 0 : next(beardCount),
    );
  }

  /// Deterministic portrait that respects the player's region and age.
  factory FaceConfig.forPlayer(String id, String nationality, int age) {
    var n = _hash('$id|$nationality');
    int next(int mod) {
      n = (n * 1103515245 + 12345) & 0x7fffffff;
      return (n >> 8) % mod;
    }

    int pick(List<int> options) => options[next(options.length)];
    final region = _region(nationality);
    final skin = switch (region) {
      _Region.north => pick([0, 0, 1, 1, 2, 3, 7]),
      _Region.south => pick([1, 2, 2, 3, 3, 4, 7, 8]),
      _Region.latin => pick([2, 3, 4, 4, 5, 6, 7, 8, 9]),
      _Region.african => pick([6, 7, 8, 8, 9, 9]),
      _Region.mena => pick([3, 4, 4, 5, 5]),
      _Region.asian => pick([1, 2, 2, 3, 3]),
      _Region.mixed => pick([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]),
    };
    final dark = skin >= 6;
    final hair = region == _Region.north && next(3) == 0
        ? pick([2, 3, 5])
        : pick([0, 0, 1, 1, 2]);
    final cut = dark
        ? pick([4, 6, 6, 3, 7, 10, 0, 5, 11])
        : region == _Region.asian
        ? pick([0, 1, 13, 2, 12])
        : pick([0, 1, 2, 3, 8, 9, 12, 13, 4, 6]);
    final ageLines = age >= 33 ? 2 : (age >= 28 ? 1 : 0);
    return FaceConfig(
      skin: skin,
      hair: age >= 36 && next(2) == 0 ? 4 : hair,
      cut: age >= 34 && next(3) == 0 ? pick([4, 5, 12]) : cut,
      shape: next(shapeCount),
      eyes: next(eyesCount),
      nose: next(noseCount),
      mouth: next(mouthCount),
      brow: next(browCount),
      age: ageLines,
      eyeColor: dark || region == _Region.asian
          ? pick([0, 3])
          : region == _Region.north
          ? pick([0, 1, 2, 4, 1])
          : pick([0, 0, 3, 2]),
      beardStyle: age < 20 ? 0 : (next(10) < 5 ? 0 : 1 + next(beardCount - 1)),
      freckles: region == _Region.north && next(9) == 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'skin': skin,
    'hair': hair,
    'cut': cut,
    'shape': shape,
    'eyes': eyes,
    'nose': nose,
    'mouth': mouth,
    'brow': brow,
    'age': age,
    'eyeColor': eyeColor,
    'beardStyle': beardStyle,
    'glasses': glasses,
    'freckles': freckles,
  };

  factory FaceConfig.fromMap(Map<String, dynamic> m) {
    int v(String k, int count, int fallback) =>
        ((m[k] as num?)?.toInt() ?? fallback).clamp(0, count - 1);
    final legacyBeard = m['beard'] == true ? 2 : 0;
    return FaceConfig(
      skin: v('skin', skinCount, 2),
      hair: v('hair', hairColorCount, 0),
      cut: v('cut', cutCount, 0),
      shape: v('shape', shapeCount, 0),
      eyes: v('eyes', eyesCount, 0),
      nose: v('nose', noseCount, 1),
      mouth: v('mouth', mouthCount, 1),
      brow: v('brow', browCount, 1),
      age: v('age', ageCount, 0),
      eyeColor: v('eyeColor', eyeColorCount, 0),
      beardStyle: v('beardStyle', beardCount, legacyBeard),
      glasses: m['glasses'] == true,
      freckles: m['freckles'] == true,
    );
  }

  FaceConfig change(String key, dynamic value) =>
      FaceConfig.fromMap({...toMap(), key: value});

  @override
  bool operator ==(Object other) =>
      other is FaceConfig && other.toMap().toString() == toMap().toString();
  @override
  int get hashCode => toMap().toString().hashCode;
}

enum _Region { north, south, latin, african, mena, asian, mixed }

_Region _region(String nationality) {
  const north = {
    'Germaniya',
    'Norvegiya',
    'Daniya',
    'Niderlandiya',
    'Polsha',
    'Shotlandiya',
    'Irlandiya',
    'Shveysariya',
    'Rossiya',
    'Ukraina',
    'Vengriya',
    'Xorvatiya',
    'Avstriya',
    'Shvetsiya',
    'Shimoliy Irlandiya',
    'Gruziya',
    'Uels',
    'Serbiya',
    'Chexiya',
    'Slovakiya',
    'Sloveniya',
    'Bosniya',
    'Islandiya',
    'Finlandiya',
    'Kosovo',
  };
  const south = {
    'Ispaniya',
    'Italiya',
    'Portugaliya',
    'Turkiya',
    'Armaniston',
    'Albaniya',
    'Gretsiya',
    'O‘zbekiston',
  };
  const latin = {'Argentina', 'Urugvay', 'Kolumbiya', 'Ekvador', 'Braziliya', 'Meksika', 'Paragvay', 'Venesuela', 'Chili'};
  const african = {
    'Gana', 'Senegal', 'Nigeriya', 'Kamerun', 'Kot-d’Ivuar', 'Mali', 'Gvineya', 'KDR',
    'Burkina-Faso', 'Zimbabve', 'Gaiti', 'Yamayka', 'Gabon', 'Zambiya',
  };
  const mena = {'Marokash', 'Misr', 'Eron', 'Jazoir', 'Tunis', 'Isroil'};
  const asian = {'Janubiy Koreya', 'Yaponiya'};
  if (north.contains(nationality)) return _Region.north;
  if (south.contains(nationality)) return _Region.south;
  if (latin.contains(nationality)) return _Region.latin;
  if (african.contains(nationality)) return _Region.african;
  if (mena.contains(nationality)) return _Region.mena;
  if (asian.contains(nationality)) return _Region.asian;
  return _Region.mixed;
}
