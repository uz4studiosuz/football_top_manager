import 'dart:math';
import 'package:flutter/material.dart';
import '../models/face.dart';
export '../models/face.dart';

class FaceAvatar extends StatelessWidget {
  final FaceConfig config;
  final double size;
  final Color shirt;
  const FaceAvatar({
    super.key,
    required this.config,
    this.size = 52,
    this.shirt = const Color(0xFF1769E0),
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Shaxsiy portret',
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _FacePainter(config, shirt)),
    ),
  );
}

class _FacePainter extends CustomPainter {
  final FaceConfig c;
  final Color shirt;
  _FacePainter(this.c, this.shirt);
  static const skins = [
    Color(0xFFF2D5BF),
    Color(0xFFE3B794),
    Color(0xFFD19A70),
    Color(0xFFB67F57),
    Color(0xFF956345),
    Color(0xFF754D36),
    Color(0xFF50382A),
  ];
  static const hairs = [
    Color(0xFF262323),
    Color(0xFF51372B),
    Color(0xFF88613F),
    Color(0xFFC5A36A),
    Color(0xFFA8A49B),
    Color(0xFF9B4F30),
  ];
  static const eyeColors = [
    Color(0xFF4B3424),
    Color(0xFF657B85),
    Color(0xFF6B7954),
    Color(0xFF302B28),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final p = Paint()..isAntiAlias = true;
    final skin = skins[c.skin];
    final hair = hairs[c.hair];
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 100, 100),
        const Radius.circular(12),
      ),
      p..color = const Color(0xFFEDF2F7),
    );
    canvas.drawPath(
      Path()
        ..moveTo(7, 100)
        ..quadraticBezierTo(9, 82, 39, 77)
        ..lineTo(61, 77)
        ..quadraticBezierTo(91, 82, 93, 100)
        ..close(),
      p..color = shirt,
    );
    canvas.drawPath(
      Path()
        ..moveTo(40, 68)
        ..lineTo(60, 68)
        ..lineTo(61, 80)
        ..quadraticBezierTo(50, 91, 39, 80)
        ..close(),
      p..color = skin,
    );
    canvas.drawPath(
      Path()
        ..moveTo(39, 78)
        ..lineTo(50, 86)
        ..lineTo(42, 91)
        ..lineTo(34, 81)
        ..close(),
      p..color = Color.lerp(shirt, Colors.white, 0.25)!,
    );
    canvas.drawPath(
      Path()
        ..moveTo(61, 78)
        ..lineTo(50, 86)
        ..lineTo(58, 91)
        ..lineTo(66, 81)
        ..close(),
      p,
    );
    final jaw = c.shape == 0
        ? 15.0
        : c.shape == 1
        ? 22.0
        : c.shape == 2
        ? 18.0
        : 12.0;
    final top = c.shape == 2 ? 16.0 : 19.0;
    final face = Path()
      ..moveTo(28, 35)
      ..quadraticBezierTo(28, top, 50, top)
      ..quadraticBezierTo(72, top, 72, 35)
      ..lineTo(70, 58)
      ..quadraticBezierTo(68, 70, 50 + jaw / 3, 75)
      ..quadraticBezierTo(50, 79, 50 - jaw / 3, 75)
      ..quadraticBezierTo(32, 70, 30, 58)
      ..close();
    for (final x in [27.0, 73.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 47), width: 8, height: 15),
        p..color = skin,
      );
      canvas.drawArc(
        Rect.fromCenter(center: Offset(x, 47), width: 4, height: 9),
        -1,
        2,
        false,
        p
          ..color = Color.lerp(skin, Colors.black, 0.15)!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      p.style = PaintingStyle.fill;
    }
    canvas.drawPath(face, p..color = skin);
    // Cheek and jaw planes are flat colour shapes, not glow or shadow effects.
    canvas.drawPath(
      Path()
        ..moveTo(65, 48)
        ..lineTo(69, 45)
        ..lineTo(67, 62)
        ..quadraticBezierTo(63, 70, 57, 72)
        ..lineTo(62, 62)
        ..close(),
      p..color = Color.lerp(skin, Colors.black, 0.06)!,
    );
    final spacing = c.eyes == 2 ? 11.5 : 9.5;
    final eyeH = c.eyes == 1
        ? 2.2
        : c.eyes == 3
        ? 3.7
        : 3.0;
    for (final sign in [-1.0, 1.0]) {
      final x = 50 + spacing * sign;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 45.5), width: 10.5, height: eyeH * 2),
        p..color = const Color(0xFFF8F7F3),
      );
      canvas.drawCircle(Offset(x, 45.5), 2.6, p..color = eyeColors[c.eyeColor]);
      canvas.drawCircle(
        Offset(x, 45.5),
        1.25,
        p..color = const Color(0xFF211E1C),
      );
      canvas.drawCircle(Offset(x - 0.7, 44.7), 0.65, p..color = Colors.white);
      canvas.drawArc(
        Rect.fromCenter(center: Offset(x, 45.5), width: 11, height: eyeH * 2),
        pi,
        pi,
        false,
        p
          ..color = Color.lerp(skin, Colors.black, 0.45)!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
      p.style = PaintingStyle.fill;
      final slope = (c.brow - 1.5) * 0.7 * sign;
      canvas.drawLine(
        Offset(x - 5, 39 + slope),
        Offset(x + 5, 39 - slope),
        p
          ..color = hair
          ..strokeWidth = (c.brow == 3 ? 2.4 : 1.7)
          ..strokeCap = StrokeCap.round,
      );
    }
    final noseW = 2.5 + c.nose * 0.7;
    canvas.drawPath(
      Path()
        ..moveTo(50, 46)
        ..lineTo(50 - noseW, 56)
        ..quadraticBezierTo(50, 58, 50 + noseW, 56),
      p
        ..color = Color.lerp(skin, Colors.black, 0.25)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
    p.style = PaintingStyle.fill;
    if (c.beard) {
      final b = Path()
        ..moveTo(30, 53)
        ..lineTo(35, 60)
        ..quadraticBezierTo(50, 70, 65, 60)
        ..lineTo(70, 53)
        ..lineTo(67, 68)
        ..quadraticBezierTo(50, 86, 33, 68)
        ..close();
      canvas.drawPath(b, p..color = Color.lerp(hair, skin, 0.12)!);
    }
    final mouthW = 9.0 + c.mouth * 1.8;
    canvas.drawPath(
      Path()
        ..moveTo(50 - mouthW / 2, 63)
        ..quadraticBezierTo(50, 62 + c.mouth * 0.7, 50 + mouthW / 2, 63),
      p
        ..color = Color.lerp(skin, const Color(0xFF7D3C38), 0.6)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = c.mouth == 3 ? 2 : 1.4,
    );
    p.style = PaintingStyle.fill;
    if (c.freckles) {
      for (final pt in [
        const Offset(35, 52),
        const Offset(38, 54),
        const Offset(33, 55),
        const Offset(62, 54),
        const Offset(66, 52),
        const Offset(68, 55),
      ]) {
        canvas.drawCircle(
          pt,
          0.6,
          p..color = Color.lerp(skin, Colors.black, 0.3)!,
        );
      }
    }
    if (c.age > 0) {
      p
        ..color = Color.lerp(skin, Colors.black, 0.2)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6;
      for (final y in [30.0, 33.0]) {
        canvas.drawLine(Offset(41, y), Offset(59, y), p);
      }
      for (final x in [34.0, 62.0]) {
        canvas.drawLine(Offset(x, 51), Offset(x + 4, 52), p);
      }
      p.style = PaintingStyle.fill;
    }
    if (c.cut != 5) {
      final hp = Path()
        ..moveTo(28, 44)
        ..lineTo(26, 31)
        ..quadraticBezierTo(25, 12, 49, 12)
        ..quadraticBezierTo(76, 10, 74, 36)
        ..lineTo(71, 45)
        ..lineTo(67, 31);
      switch (c.cut) {
        case 0:
          hp.lineTo(63, 24);
          hp.quadraticBezierTo(48, 33, 31, 28);
        case 1:
          hp.lineTo(65, 22);
          hp.quadraticBezierTo(45, 39, 30, 30);
        case 2:
          hp.lineTo(65, 19);
          hp.lineTo(35, 20);
          hp.lineTo(30, 31);
        case 3:
          hp.lineTo(65, 29);
          hp.lineTo(57, 23);
          hp.lineTo(50, 30);
          hp.lineTo(42, 22);
          hp.lineTo(31, 31);
        case 4:
          hp.lineTo(66, 23);
          hp.lineTo(35, 23);
          hp.lineTo(30, 36);
        case 6:
          hp.lineTo(62, 29);
          hp.lineTo(51, 21);
          hp.lineTo(39, 31);
          hp.lineTo(30, 35);
        case 7:
          hp.lineTo(67, 24);
          hp.lineTo(59, 27);
          hp.lineTo(53, 22);
          hp.lineTo(45, 29);
          hp.lineTo(36, 24);
          hp.lineTo(30, 41);
        default:
          break;
      }
      hp.lineTo(29, 45);
      hp.close();
      canvas.drawPath(hp, p..color = hair);
      if (c.cut == 3 || c.cut == 7) {
        for (var i = 0; i < 8; i++) {
          canvas.drawCircle(
            Offset(31 + i * 5.4, 20 + sin(i * 2) * 3),
            4.8,
            p..color = hair,
          );
        }
      }
      if (c.cut == 2) {
        canvas.drawPath(
          Path()
            ..moveTo(29, 29)
            ..lineTo(34, 13)
            ..lineTo(49, 7)
            ..lineTo(65, 12)
            ..lineTo(70, 25)
            ..close(),
          p..color = hair,
        );
      }
    }
    if (c.glasses) {
      p
        ..color = const Color(0xFF283444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3;
      for (final x in [39.0, 61.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, 46), width: 17, height: 11),
            const Radius.circular(3),
          ),
          p,
        );
      }
      canvas.drawLine(const Offset(47.5, 45), const Offset(52.5, 45), p);
      p.style = PaintingStyle.fill;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FacePainter old) =>
      old.c != c || old.shirt != shirt;
}

class FaceStudio extends StatelessWidget {
  final FaceConfig value;
  final ValueChanged<FaceConfig> onChanged;
  const FaceStudio({super.key, required this.value, required this.onChanged});
  Widget _choices(String key, String label, int count) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(count, (i) {
          final selected = value.toMap()[key] == i;
          return InkWell(
            onTap: () => onChanged(value.change(key, i)),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF1769E0)
                      : const Color(0xFFE1E7EF),
                  width: selected ? 2 : 1,
                ),
              ),
              child: FaceAvatar(config: value.change(key, i), size: 44),
            ),
          );
        }),
      ),
      const SizedBox(height: 22),
    ],
  );
  Widget _toggle(String key, String label) => Material(
    color: Colors.transparent,
    child: SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value.toMap()[key] as bool,
      onChanged: (v) => onChanged(value.change(key, v)),
    ),
  );
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: FaceAvatar(
            config: value,
            size: 130,
            shirt: const Color(0xFF34475E),
          ),
        ),
        const Text(
          'Yuzingizga mos shakl va detallarni tanlang',
          style: TextStyle(color: Color(0xFF637184), fontSize: 12),
        ),
        const SizedBox(height: 10),
        const TabBar(
          tabs: [
            Tab(text: 'Yuz'),
            Tab(text: 'Soch'),
            Tab(text: 'Detallar'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _choices('skin', 'Teri rangi', 7),
                  _choices('shape', 'Yuz va jag‘ shakli', 4),
                  _choices('eyes', 'Ko‘z shakli', 4),
                  _choices('nose', 'Burun', 4),
                  _choices('mouth', 'Lab shakli', 4),
                ],
              ),
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _choices('cut', 'Soch shabloni', 8),
                  _choices('hair', 'Soch rangi', 6),
                  _choices('brow', 'Qosh shakli', 4),
                  _toggle('beard', 'Soqol'),
                ],
              ),
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _choices('eyeColor', 'Ko‘z rangi', 4),
                  _choices('age', 'Yosh chiziqlari', 3),
                  _toggle('glasses', 'Ko‘zoynak'),
                  _toggle('freckles', 'Sepkil'),
                  OutlinedButton.icon(
                    onPressed: () => onChanged(
                      FaceConfig.seed(
                        DateTime.now().microsecondsSinceEpoch.toString(),
                      ),
                    ),
                    icon: const Icon(Icons.casino_outlined),
                    label: const Text('Tasodifiy yuz'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Future<FaceConfig?> editFace(BuildContext context, FaceConfig initial) =>
    Navigator.push<FaceConfig>(
      context,
      MaterialPageRoute(builder: (_) => _FaceEditor(initial)),
    );

class _FaceEditor extends StatefulWidget {
  final FaceConfig initial;
  const _FaceEditor(this.initial);
  @override
  State<_FaceEditor> createState() => _FaceEditorState();
}

class _FaceEditorState extends State<_FaceEditor> {
  late FaceConfig current = widget.initial;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Portret yaratish'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, current),
          child: const Text('Saqlash'),
        ),
      ],
    ),
    body: FaceStudio(
      value: current,
      onChanged: (v) => setState(() => current = v),
    ),
  );
}
