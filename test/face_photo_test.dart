import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/ui/face_avatar.dart';
import 'package:football_top_manager/ui/face_from_photo.dart';

/// Draws a simple head shot in the guide's place (300×400 capture).
Future<ui.Image> _portrait({required Color background, required Color hair, required Color skin, bool bald = false}) async {
  final recorder = ui.PictureRecorder();
  final c = Canvas(recorder);
  const w = 300.0, h = 400.0;
  // Guide oval: centre (0.5, 0.47), 0.56 × 0.64 of the capture.
  final oval = Rect.fromCenter(center: const Offset(w * 0.5, h * 0.47), width: w * 0.56, height: h * 0.64);
  c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = background);
  // Hair: a cap from 10% to 30% of the oval height.
  if (!bald) {
    c.drawOval(
      Rect.fromLTRB(oval.left + oval.width * 0.08, oval.top + oval.height * 0.1, oval.right - oval.width * 0.08, oval.top + oval.height * 0.6),
      Paint()..color = hair,
    );
    // Hair texture.
    for (var i = 0; i < 40; i++) {
      c.drawCircle(Offset(oval.left + oval.width * (0.2 + (i % 10) * 0.06), oval.top + oval.height * (0.13 + (i ~/ 10) * 0.035)), 1.5,
          Paint()..color = Color.lerp(hair, Colors.white, 0.25)!);
    }
  }
  // Face from the hairline down to the chin.
  c.drawOval(
    Rect.fromLTRB(oval.left + oval.width * 0.12, oval.top + oval.height * (bald ? 0.08 : 0.28), oval.right - oval.width * 0.12, oval.bottom),
    Paint()..color = skin,
  );
  return recorder.endRecording().toImage(w.toInt(), h.toInt());
}

void main() {
  testWidgets('Short dark hair on a black background is not read as bald', (tester) async {
    final face = await tester.runAsync(() async {
      final img = await _portrait(background: Colors.black, hair: const Color(0xFF1E1A18), skin: const Color(0xFFD9B29A));
      return analyseAligned(img, const FaceConfig());
    });
    expect(face, isNotNull);
    expect(face!.cut, isNot(5), reason: 'not bald');
    expect(face.hair, anyOf(0, 1, 7), reason: 'dark hair');
    expect(face.skin, lessThanOrEqualTo(4), reason: 'light skin, got ${face.skin}');
  });

  testWidgets('A bald head on a light background is read as bald', (tester) async {
    final face = await tester.runAsync(() async {
      final img = await _portrait(background: const Color(0xFFDDE3EA), hair: Colors.black, skin: const Color(0xFF8D5A3B), bald: true);
      return analyseAligned(img, const FaceConfig());
    });
    expect(face!.cut, 5);
    expect(face.skin, greaterThanOrEqualTo(5), reason: 'dark skin, got ${face.skin}');
  });
}
