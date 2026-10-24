import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/ui/face_avatar.dart';

/// Renders portrait contact sheets for visual QA:
///   flutter test tool/face_sheet_test.dart --dart-define=OUT=path/to/dir
void main() {
  test('face contact sheet', () async {
    const out = String.fromEnvironment('OUT', defaultValue: 'artifacts/qa');
    Directory(out).createSync(recursive: true);
    const cell = 160.0;
    Future<void> sheet(String name, List<FaceConfig> faces, {int perRow = 8}) async {
      final rows = (faces.length / perRow).ceil();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(Rect.fromLTWH(0, 0, perRow * cell, rows * cell), Paint()..color = Colors.white);
      for (var i = 0; i < faces.length; i++) {
        canvas.save();
        canvas.translate((i % perRow) * cell + 5, (i ~/ perRow) * cell + 5);
        FacePainter(faces[i], const Color(0xFF6CABDD), null).paint(canvas, const Size(cell - 10, cell - 10));
        canvas.restore();
      }
      final image = await recorder.endRecording().toImage((perRow * cell).round(), (rows * cell).round());
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    }

    const base = FaceConfig(skin: 3, hair: 0, cut: 0, shape: 0, brow: 2);
    await sheet('beards', [
      for (var shape = 0; shape < 5; shape++)
        for (var b = 0; b < FaceConfig.beardCount; b++) base.change('shape', shape).change('beardStyle', b),
    ]);
    await sheet('cuts', [
      for (var cut = 0; cut < FaceConfig.cutCount; cut++) base.change('cut', cut),
      for (var cut = 0; cut < FaceConfig.cutCount; cut++)
        base.change('cut', cut).change('hair', 3).change('skin', 0),
    ]);
    await sheet('khusanov', [
      const FaceConfig(skin: 2, hair: 0, cut: 14, shape: 0, eyes: 4, eyeColor: 0, brow: 2, nose: 1, mouth: 0),
      for (var e = 0; e < FaceConfig.eyesCount; e++)
        const FaceConfig(skin: 2, hair: 0, cut: 14, shape: 0, brow: 2, nose: 1, mouth: 0).change('eyes', e),
      for (final id in ['a', 'b', 'c', 'd', 'e', 'f']) FaceConfig.forPlayer('uz_$id', 'O‘zbekiston', 22),
      for (final id in ['a', 'b', 'c', 'd', 'e', 'f']) FaceConfig.forPlayer('eng_$id', 'Angliya', 29),
    ], perRow: 6);
  });
}
