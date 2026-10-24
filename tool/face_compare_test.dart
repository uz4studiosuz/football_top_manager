import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/ui/face_avatar.dart';

/// Line-up size (34, round) next to the profile size (96) for several faces;
/// the small one is scaled up so details can be compared:
///   flutter test tool/face_compare_test.dart
void main() {
  testWidgets('face sizes match', (tester) async {
    final key = GlobalKey();
    final faces = [
      for (final cut in [3, 7, 9, 10])
        for (final skin in [5, 8]) FaceConfig(skin: skin, hair: 0, cut: cut, beardStyle: cut == 10 ? 3 : 0),
    ];
    tester.view.physicalSize = Size(220.0 * 4, 110.0 * (faces.length / 4).ceil());
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: Container(
          color: Colors.white,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Wrap(
              children: [
                for (final f in faces)
                  SizedBox(
                    width: 220,
                    height: 110,
                    child: Row(
                      children: [
                        Transform.scale(
                          scale: 96 / 34,
                          child: FaceAvatar(config: f, size: 34, shirt: Colors.amber, circle: true),
                        ),
                        const SizedBox(width: 30),
                        FaceAvatar(config: f, size: 96, shirt: Colors.amber),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = (await tester.runAsync(() => boundary.toImage()))!;
    final data = await tester.runAsync(() => img.toByteData(format: ui.ImageByteFormat.png));
    await tester.runAsync(() => File('artifacts/qa/face-compare.png').writeAsBytes(data!.buffer.asUint8List()));
  });
}
