import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'face_avatar.dart';
import 'widgets.dart';

/// Builds a look-alike portrait from a photo: skin tone, hair colour, hair
/// length and facial hair are read from a front-facing head shot. It is an
/// approximation (no face recognition), meant as a starting point to refine
/// in the portrait editor.
Future<FaceConfig?> faceFromPhoto(BuildContext context, FaceConfig base) async {
  final file = await FilePicker.pickFile(type: FileType.image);
  if (file == null || !context.mounted) return null;
  final bytes = await file.readAsBytes();
  final guess = await analysePortrait(bytes, base);
  if (guess == null || !context.mounted) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Rasmni o‘qib bo‘lmadi.'))));
    }
    return null;
  }
  return showDialog<FaceConfig>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('Rasmdan yuz')),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(bytes, width: 120, height: 120, fit: BoxFit.cover),
                ),
                const Icon(Icons.arrow_forward_rounded, color: AppColors.ink3),
                FaceAvatar(config: guess, size: 120),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              tr('Teri rangi, soch rangi va uzunligi hamda soqol rasmdan olindi. Qolgan detallarni portret muharririda sozlang.'),
              style: AppText.small,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Bekor'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, guess), child: Text(tr('Qo‘llash'))),
      ],
    ),
  );
}

/// Reads a portrait photo (head roughly centred) into a [FaceConfig].
Future<FaceConfig?> analysePortrait(Uint8List bytes, FaceConfig base) async {
  final ui.Image image;
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 120);
    image = (await codec.getNextFrame()).image;
  } catch (_) {
    return null;
  }
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) return null;
  final w = image.width, h = image.height;

  /// Average colour of a box given in fractions of the image.
  Color sample(double x0, double y0, double x1, double y1) {
    var r = 0, g = 0, b = 0, n = 0;
    for (var y = (y0 * h).floor(); y < (y1 * h).ceil() && y < h; y++) {
      for (var x = (x0 * w).floor(); x < (x1 * w).ceil() && x < w; x++) {
        final i = (y * w + x) * 4;
        r += data.getUint8(i);
        g += data.getUint8(i + 1);
        b += data.getUint8(i + 2);
        n++;
      }
    }
    if (n == 0) return const Color(0xFF808080);
    return Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n);
  }

  double dist(Color a, Color b) {
    final dr = (a.r - b.r) * 255, dg = (a.g - b.g) * 255, db = (a.b - b.b) * 255;
    return dr * dr * 0.3 + dg * dg * 0.59 + db * db * 0.11;
  }

  int nearest(Color c, List<Color> palette) {
    var best = 0;
    for (var i = 1; i < palette.length; i++) {
      if (dist(c, palette[i]) < dist(c, palette[best])) best = i;
    }
    return best;
  }

  double luma(Color c) => c.r * 0.3 + c.g * 0.59 + c.b * 0.11;

  // Cheeks and forehead give the skin; the crown gives the hair; the band
  // at the sides of the head says whether the hair is long; the chin and
  // upper lip show facial hair.
  final skin = sample(0.38, 0.42, 0.62, 0.58);
  final hairTop = sample(0.36, 0.06, 0.64, 0.16);
  final background = sample(0.02, 0.02, 0.12, 0.12);
  final sides = sample(0.16, 0.45, 0.26, 0.7);
  final chin = sample(0.4, 0.74, 0.6, 0.84);
  final lip = sample(0.42, 0.64, 0.58, 0.69);

  final skinIndex = nearest(skin, FacePainter.skins);
  final bald = dist(hairTop, skin) < dist(hairTop, background) * 0.6 && dist(hairTop, skin) < 900;
  final hairIndex = bald ? base.hair : nearest(hairTop, FacePainter.hairs);
  final longHair = !bald && dist(sides, hairTop) < dist(sides, background) && dist(sides, skin) > 1400;
  final darkChin = luma(chin) < luma(skin) * 0.78;
  final darkLip = luma(lip) < luma(skin) * 0.8;
  final beard = darkChin && darkLip
      ? 3 // full beard
      : darkChin
      ? 2 // short beard
      : darkLip
      ? 5 // moustache
      : luma(chin) < luma(skin) * 0.9
      ? 1 // stubble
      : 0;
  final cut = bald ? 5 : longHair ? 8 : base.cut == 5 || base.cut == 8 ? 0 : base.cut;
  return base
      .change('skin', skinIndex)
      .change('hair', hairIndex)
      .change('cut', cut)
      .change('beardStyle', beard);
}
