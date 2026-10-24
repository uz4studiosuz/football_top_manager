import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'browser_files_stub.dart' if (dart.library.js_interop) 'browser_files_web.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/l10n.dart';
import 'face_avatar.dart';
import 'widgets.dart';

/// Builds a look-alike portrait from a photo. The user takes or picks a
/// photo and fits the face into an outline (eyes on the line, chin at the
/// bottom); because the face is then in a known place, skin, hair colour,
/// hair shape, brows, eye colour, facial hair, glasses and face shape are
/// read from the right spots. An approximation, refined in the editor.
Future<FaceConfig?> faceFromPhoto(BuildContext context, FaceConfig base) async {
  Uint8List? bytes;
  if (kIsWeb) {
    // Browsers only open the file dialog during the click itself, so pick
    // straight away; phone browsers offer the camera in the same dialog.
    try {
      bytes = await pickImageBytes();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trf('Rasmni o‘qib bo‘lmadi: {0}', [e]))));
      }
      return null;
    }
    if (bytes == null || !context.mounted) return null;
    return Navigator.push<FaceConfig>(
      context,
      MaterialPageRoute(builder: (_) => _FitFaceScreen(bytes: bytes!, base: base)),
    );
  }
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(tr('Kamera bilan rasmga olish')),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(tr('Galereyadan tanlash')),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return null;
  try {
    final shot = await ImagePicker().pickImage(source: source, preferredCameraDevice: CameraDevice.front, maxWidth: 1400);
    bytes = await shot?.readAsBytes();
  } catch (_) {
    // No camera on this device (e.g. desktop): fall back to a file.
    bytes = await pickImageBytes();
  }
  if (bytes == null || !context.mounted) return null;
  return Navigator.push<FaceConfig>(
    context,
    MaterialPageRoute(builder: (_) => _FitFaceScreen(bytes: bytes!, base: base)),
  );
}

/// Where the face outline sits in the capture box (fractions of its size).
const _ovalCx = 0.5, _ovalCy = 0.47, _ovalW = 0.56, _ovalH = 0.64;

class _FitFaceScreen extends StatefulWidget {
  final Uint8List bytes;
  final FaceConfig base;
  const _FitFaceScreen({required this.bytes, required this.base});
  @override
  State<_FitFaceScreen> createState() => _FitFaceScreenState();
}

class _FitFaceScreenState extends State<_FitFaceScreen> {
  final _capture = GlobalKey();
  FaceConfig? _result;
  bool _busy = false;

  Future<void> _analyse() async {
    setState(() => _busy = true);
    final boundary = _capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final result = await analyseAligned(image, widget.base);
    image.dispose();
    if (mounted) {
      setState(() {
        _busy = false;
        _result = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF111418),
    appBar: AppBar(
      backgroundColor: const Color(0xFF111418),
      foregroundColor: Colors.white,
      title: Text(tr('Yuzni shaklga joylang'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Text(
              tr('Rasmni suring va kattalashtiring: ko‘zlar chiziqda, iyak pastki belgida, yuz shakl ichida bo‘lsin.'),
              textAlign: TextAlign.center,
              style: AppText.small.copyWith(color: Colors.white70),
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: LayoutBuilder(
                  builder: (context, box) => ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RepaintBoundary(
                          key: _capture,
                          child: ColoredBox(
                            color: Colors.black,
                            child: InteractiveViewer(
                              minScale: 0.5,
                              maxScale: 6,
                              boundaryMargin: const EdgeInsets.all(400),
                              onInteractionEnd: (_) => setState(() => _result = null),
                              child: SizedBox(
                                width: box.maxWidth,
                                height: box.maxHeight,
                                child: Image.memory(widget.bytes, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ),
                        const IgnorePointer(child: CustomPaint(painter: _GuidePainter())),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                if (_result != null) ...[
                  FaceAvatar(config: _result!, size: 72),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: _result == null
                      ? FilledButton.icon(
                          onPressed: _busy ? null : _analyse,
                          icon: _busy
                              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.face_retouching_natural),
                          label: Text(tr('Yuzni yaratish')),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                                onPressed: () => setState(() => _result = null),
                                child: Text(tr('Qayta joylash')),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => Navigator.pop(context, _result),
                                child: Text(tr('Qo‘llash')),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Dims everything outside the face outline and marks the eye and chin lines.
class _GuidePainter extends CustomPainter {
  const _GuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final oval = Rect.fromCenter(
      center: Offset(size.width * _ovalCx, size.height * _ovalCy),
      width: size.width * _ovalW,
      height: size.height * _ovalH,
    );
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addOval(oval),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawOval(oval, line);
    final dashed = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.2;
    final eyeY = oval.top + oval.height * 0.42;
    for (var x = oval.left + 8; x < oval.right - 8; x += 10) {
      canvas.drawLine(Offset(x, eyeY), Offset(x + 5, eyeY), dashed);
    }
    final midX = oval.center.dx;
    canvas.drawLine(Offset(midX, oval.top + oval.height * 0.5), Offset(midX, oval.top + oval.height * 0.7), dashed);
    canvas.drawLine(Offset(midX - 14, oval.bottom), Offset(midX + 14, oval.bottom), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Reads a captured, aligned head shot (face inside the guide oval).
Future<FaceConfig?> analyseAligned(ui.Image image, FaceConfig base) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) return null;
  final w = image.width, h = image.height;
  final ox = w * (_ovalCx - _ovalW / 2), oy = h * (_ovalCy - _ovalH / 2);
  final ow = w * _ovalW, oh = h * _ovalH;

  Color px(int x, int y) {
    final i = (y.clamp(0, h - 1) * w + x.clamp(0, w - 1)) * 4;
    return Color.fromARGB(255, data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
  }

  /// Average colour of a box in oval-relative fractions.
  Color box(double x0, double y0, double x1, double y1) {
    var r = 0.0, g = 0.0, b = 0.0, n = 0;
    final ax = (ox + x0 * ow).round(), bx = (ox + x1 * ow).round();
    final ay = (oy + y0 * oh).round(), by = (oy + y1 * oh).round();
    for (var y = ay; y <= by; y += 1) {
      for (var x = ax; x <= bx; x += 1) {
        final c = px(x, y);
        r += c.r;
        g += c.g;
        b += c.b;
        n++;
      }
    }
    return n == 0 ? const Color(0xFF808080) : Color.from(alpha: 1, red: r / n, green: g / n, blue: b / n);
  }

  /// Brightness spread inside a box (hair texture).
  double texture(double x0, double y0, double x1, double y1) {
    final values = <double>[];
    for (var y = (oy + y0 * oh).round(); y <= (oy + y1 * oh).round(); y += 2) {
      for (var x = (ox + x0 * ow).round(); x <= (ox + x1 * ow).round(); x += 2) {
        values.add(luma(px(x, y)));
      }
    }
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    return sqrt(values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length);
  }

  final skin = mix([box(0.2, 0.52, 0.32, 0.62), box(0.68, 0.52, 0.8, 0.62), box(0.38, 0.18, 0.62, 0.26)]);
  final background = mix([box(-0.42, -0.05, -0.32, 0.05), box(1.32, -0.05, 1.42, 0.05)]);
  final hairTop = box(0.38, -0.02, 0.62, 0.06);
  bool isSkin(Color c) => dist(c, skin) < 900;
  bool isBackground(Color c) => dist(c, background) < 700;
  bool isHair(Color c) => !isSkin(c) && !isBackground(c);

  // Hair volume: how far hair rises above the head and spreads at the temples.
  var height = 0.0;
  for (var f = -0.02; f > -0.4; f -= 0.01) {
    if (!isHair(box(0.45, f - 0.01, 0.55, f))) break;
    height = -f;
  }
  var spread = 0.0;
  for (var f = 0.02; f < 0.4; f += 0.01) {
    if (!isHair(box(-f - 0.01, 0.2, -f, 0.28)) || !isHair(box(1 + f, 0.2, 1 + f + 0.01, 0.28))) break;
    spread = f;
  }
  final longSides = isHair(box(-0.06, 0.7, 0.02, 0.9)) && isHair(box(0.98, 0.7, 1.06, 0.9));
  final bald = isSkin(hairTop) || (!isHair(hairTop) && height < 0.02);
  final curly = texture(0.3, -0.06, 0.7, 0.04) > 0.11;
  final cut = bald
      ? 5 // bald
      : longSides
      ? (curly ? 10 : 8) // dreads / long
      : spread > 0.1 && height > 0.12
      ? 7 // afro
      : curly
      ? 3 // curly
      : height > 0.11
      ? 2 // quiff
      : height < 0.035
      ? 4 // buzz cut
      : spread < 0.02
      ? 15 // fade
      : 0; // short

  // Facial hair: darker than the skin on the chin, jaw or upper lip.
  final skinL = luma(skin);
  final chin = luma(box(0.4, 0.86, 0.6, 0.95)) / skinL;
  final jaw = luma(mix([box(0.14, 0.74, 0.24, 0.86), box(0.76, 0.74, 0.86, 0.86)])) / skinL;
  final lip = luma(box(0.42, 0.71, 0.58, 0.75)) / skinL;
  final beard = chin < 0.72 && jaw < 0.75
      ? (chin < 0.55 ? 7 : 3) // long / full
      : chin < 0.72 && jaw >= 0.8
      ? 4 // goatee
      : jaw < 0.75 && chin >= 0.72
      ? 6 // chinstrap
      : lip < 0.72 && chin >= 0.8
      ? 5 // moustache
      : chin < 0.86 || jaw < 0.86
      ? (chin < 0.8 ? 2 : 1) // short / stubble
      : 0;

  // Brows: how dark the brow band is against the forehead.
  final brow = luma(mix([box(0.24, 0.33, 0.42, 0.37), box(0.58, 0.33, 0.76, 0.37)])) / skinL;
  final browIndex = brow < 0.55 ? 2 : brow < 0.75 ? 1 : 0;

  // Eye colour from the iris spots.
  final iris = mix([box(0.31, 0.415, 0.35, 0.445), box(0.65, 0.415, 0.69, 0.445)]);
  final r = iris.r, g = iris.g, b = iris.b;
  final eyeColor = b > r + 0.06 && b > g
      ? 1 // blue
      : g > r && g > b
      ? 2 // green
      : luma(iris) < 0.18
      ? 3 // dark
      : r > 0.45 && g > 0.35
      ? 4 // hazel
      : 0; // brown

  // Glasses: a dark bridge between the eyes where skin should be.
  final glasses = luma(box(0.46, 0.4, 0.54, 0.44)) / skinL < 0.6;

  // Face shape: skin width at the jaw compared with the cheekbones.
  double skinWidth(double y) {
    var left = 0.5, right = 0.5;
    for (var f = 0.5; f > -0.1; f -= 0.01) {
      if (!isSkin(box(f - 0.01, y, f, y + 0.02))) break;
      left = f;
    }
    for (var f = 0.5; f < 1.1; f += 0.01) {
      if (!isSkin(box(f, y, f + 0.01, y + 0.02))) break;
      right = f;
    }
    return right - left;
  }

  final cheeks = skinWidth(0.5), jawW = skinWidth(0.8);
  final ratio = cheeks <= 0 ? 0.75 : jawW / cheeks;
  final shape = ratio > 0.88
      ? 1 // square
      : ratio < 0.6
      ? 4 // heart
      : cheeks > 0.98
      ? 2 // round
      : cheeks < 0.78
      ? 3 // long
      : 0; // oval

  return base
      .change('skin', nearest(skin, FacePainter.skins))
      .change('hair', bald ? base.hair : nearest(hairTop, FacePainter.hairs))
      .change('cut', cut)
      .change('beardStyle', beard)
      .change('brow', browIndex)
      .change('eyeColor', eyeColor)
      .change('glasses', glasses)
      .change('shape', shape);
}

double luma(Color c) => c.r * 0.3 + c.g * 0.59 + c.b * 0.11;

Color mix(List<Color> colors) => Color.from(
  alpha: 1,
  red: colors.map((c) => c.r).reduce((a, b) => a + b) / colors.length,
  green: colors.map((c) => c.g).reduce((a, b) => a + b) / colors.length,
  blue: colors.map((c) => c.b).reduce((a, b) => a + b) / colors.length,
);

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
