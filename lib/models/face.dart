class FaceConfig {
  final int skin, hair, cut, shape, eyes, nose, mouth, brow, age, eyeColor;
  final bool beard, glasses, freckles;
  const FaceConfig({
    this.skin = 1,
    this.hair = 0,
    this.cut = 0,
    this.shape = 0,
    this.eyes = 0,
    this.nose = 1,
    this.mouth = 1,
    this.brow = 0,
    this.age = 0,
    this.eyeColor = 0,
    this.beard = false,
    this.glasses = false,
    this.freckles = false,
  });
  factory FaceConfig.seed(String id) {
    final n = id.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    return FaceConfig(
      skin: n % 7,
      hair: (n ~/ 7) % 6,
      cut: (n ~/ 19) % 8,
      shape: (n ~/ 31) % 4,
      eyes: (n ~/ 43) % 4,
      nose: (n ~/ 59) % 4,
      mouth: (n ~/ 67) % 4,
      brow: (n ~/ 83) % 4,
      age: (n ~/ 103) % 3,
      eyeColor: (n ~/ 127) % 4,
      beard: n % 3 == 0,
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
    'beard': beard,
    'glasses': glasses,
    'freckles': freckles,
  };
  factory FaceConfig.fromMap(Map<String, dynamic> m) {
    int v(String k, int max, int fallback) =>
        (m[k] as int? ?? fallback).clamp(0, max);
    return FaceConfig(
      skin: v('skin', 6, 1),
      hair: v('hair', 5, 0),
      cut: v('cut', 7, 0),
      shape: v('shape', 3, 0),
      eyes: v('eyes', 3, 0),
      nose: v('nose', 3, 1),
      mouth: v('mouth', 3, 1),
      brow: v('brow', 3, 0),
      age: v('age', 2, 0),
      eyeColor: v('eyeColor', 3, 0),
      beard: m['beard'] == true,
      glasses: m['glasses'] == true,
      freckles: m['freckles'] == true,
    );
  }
  FaceConfig change(String key, dynamic value) =>
      FaceConfig.fromMap({...toMap(), key: value});
}
