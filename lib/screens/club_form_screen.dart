import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/crest.dart';
import '../ui/widgets.dart';
import '../l10n/l10n.dart';

/// Edit (or create) a club for the database editor: details, colours and
/// the crest. Club crests are not image files: they are drawn from the
/// `crest` settings stored with each club in clubs_*.json.
class ClubFormScreen extends StatefulWidget {
  final Map<String, dynamic> club;

  /// Creating a new club: also asks for the squad strength.
  final bool isNew;
  const ClubFormScreen({super.key, required this.club, this.isNew = false});

  /// Returns the edited club map (and `_strength` for a new club).
  static Future<Map<String, dynamic>?> open(BuildContext context, Map<String, dynamic> club, {bool isNew = false}) =>
      Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => ClubFormScreen(club: club, isNew: isNew)),
      );

  @override
  State<ClubFormScreen> createState() => _ClubFormScreenState();
}

class _ClubFormScreenState extends State<ClubFormScreen> {
  late final Map<String, dynamic> c = widget.club;
  static const _textKeys = ['name', 'shortName', 'nickname', 'city', 'stadiumName', 'managerName'];
  static const _numberKeys = ['stadiumCapacity', 'founded', 'reputation', 'transferBudget', 'wageBudget', 'ticketPrice'];
  late final Map<String, TextEditingController> _fields = {
    for (final k in [..._textKeys, ..._numberKeys]) k: TextEditingController(text: '${c[k] ?? ''}'),
  };
  late ClubCrestConfig _crest = c['crest'] == null
      ? ClubCrestConfig(
          shape: CrestShape.shield,
          pattern: CrestPattern.solid,
          primaryColor: const Color(0xFF1F4FA3),
          secondaryColor: Colors.white,
          trimColor: const Color(0xFFF5C518),
          monogram: 'FC',
        )
      : ClubCrestConfig.fromMap(c['crest'] as Map);
  double _strength = 70;

  static const _palette = [
    Color(0xFFD32F2F), Color(0xFFB71C1C), Color(0xFF6A1B9A), Color(0xFF1F4FA3), Color(0xFF0D47A1),
    Color(0xFF64B5F6), Color(0xFF00897B), Color(0xFF2E7D32), Color(0xFF9E9D24), Color(0xFFF5C518),
    Color(0xFFEF6C00), Color(0xFF5D4037), Color(0xFF212121), Color(0xFF9E9E9E), Color(0xFFFFFFFF),
  ];

  @override
  void dispose() {
    for (final t in _fields.values) {
      t.dispose();
    }
    super.dispose();
  }

  static String _labelOf(String k) => switch (k) {
    'name' => tr('Nomi'),
    'shortName' => tr('Qisqa nomi'),
    'nickname' => tr('Laqabi'),
    'city' => tr('Shahar'),
    'stadiumName' => tr('Stadion'),
    'managerName' => tr('Bosh murabbiy'),
    'stadiumCapacity' => tr('Sig‘imi'),
    'founded' => tr('Tashkil topgan'),
    'reputation' => tr('Obro‘ (1–100)'),
    'transferBudget' => tr('Transfer byudjeti'),
    'wageBudget' => tr('Maosh limiti'),
    _ => tr('Chipta narxi'),
  };

  void _save() {
    final name = _fields['name']!.text.trim(), short = _fields['shortName']!.text.trim();
    if (name.isEmpty || short.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Nom va qisqa nomni kiriting.'))));
      return;
    }
    for (final k in _textKeys) {
      c[k] = _fields[k]!.text.trim();
    }
    for (final k in _numberKeys) {
      c[k] = int.tryParse(_fields[k]!.text) ?? c[k] ?? 0;
    }
    c['shortName'] = short.toUpperCase();
    c['primaryColor'] = _crest.primaryColor.toARGB32();
    c['secondaryColor'] = _crest.secondaryColor.toARGB32();
    c['accentColor'] = _crest.trimColor.toARGB32();
    c['crest'] = _crest.toMap();
    if (widget.isNew) c['_strength'] = _strength.round();
    Navigator.pop(context, c);
  }

  Widget _colors(String label, Color value, ValueChanged<Color> onPick) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppText.bodyStrong),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final color in _palette)
            InkWell(
              onTap: () => onPick(color),
              customBorder: const CircleBorder(),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: value.toARGB32() == color.toARGB32() ? AppColors.primary : AppColors.line,
                    width: value.toARGB32() == color.toARGB32() ? 3 : 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );

  Widget _chips<T>(String label, List<T> values, T selected, String Function(T) name, ValueChanged<T> onPick) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppText.bodyStrong),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final v in values)
            ChoiceChip(label: Text(name(v)), selected: v == selected, onSelected: (_) => onPick(v)),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette tokens when appearance changes.
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? tr('Yangi klub') : tr('Klubni tahrirlash')),
        actions: [TextButton(onPressed: _save, child: Text(tr('Saqlash')))],
      ),
      body: PageWidth(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: ClubCrestWidget(config: _crest, size: 120)),
            const SizedBox(height: 6),
            Center(
              child: Text(
                tr('Logotip rasm emas: u shu sozlamalardan chiziladi va klub bilan birga clubs_*.json faylida saqlanadi.'),
                textAlign: TextAlign.center,
                style: AppText.caption,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, box) {
                final cols = box.maxWidth >= 640 ? 3 : 2;
                final w = (box.maxWidth - (cols - 1) * 8) / cols;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final k in [..._textKeys, ..._numberKeys])
                      SizedBox(
                        width: w,
                        child: TextField(
                          controller: _fields[k],
                          keyboardType: _numberKeys.contains(k) ? TextInputType.number : null,
                          inputFormatters: _numberKeys.contains(k) ? [FilteringTextInputFormatter.digitsOnly] : null,
                          decoration: InputDecoration(labelText: _labelOf(k), isDense: true, border: const OutlineInputBorder()),
                          onChanged: k == 'shortName'
                              ? (v) => setState(() => _crest = _crest.copyWith(monogram: v.trim().toUpperCase().characters.take(3).toString()))
                              : null,
                        ),
                      ),
                  ],
                );
              },
            ),
            if (widget.isNew) ...[
              const SizedBox(height: 16),
              Text(trf('Tarkib kuchi: OVR ≈ {0}', [_strength.round()]), style: AppText.bodyStrong),
              Slider(value: _strength, min: 50, max: 88, divisions: 38, onChanged: (v) => setState(() => _strength = v)),
              Text(tr('23 kishilik tarkib avtomatik yaratiladi; keyin har bir futbolchini tahrirlash mumkin.'), style: AppText.caption),
            ],
            const SizedBox(height: 20),
            Text(tr('Logotip'), style: AppText.h3),
            const SizedBox(height: 10),
            _chips(tr('Shakl'), CrestShape.values, _crest.shape, (v) => v.label, (v) => setState(() => _crest = _crest.copyWith(shape: v))),
            const SizedBox(height: 12),
            _chips(tr('Naqsh'), CrestPattern.values, _crest.pattern, (v) => v.label, (v) => setState(() => _crest = _crest.copyWith(pattern: v))),
            const SizedBox(height: 12),
            _chips(tr('Belgi'), CrestEmblem.values, _crest.emblem, (v) => v.label, (v) => setState(() => _crest = _crest.copyWith(emblem: v))),
            const SizedBox(height: 12),
            _colors(tr('Asosiy rang'), _crest.primaryColor, (v) => setState(() => _crest = _crest.copyWith(primaryColor: v))),
            const SizedBox(height: 12),
            _colors(tr('Ikkinchi rang'), _crest.secondaryColor, (v) => setState(() => _crest = _crest.copyWith(secondaryColor: v))),
            const SizedBox(height: 12),
            _colors(tr('Hoshiya rangi'), _crest.trimColor, (v) => setState(() => _crest = _crest.copyWith(trimColor: v))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(trf('Yulduzlar: {0}', [_crest.stars]), style: AppText.bodyStrong)),
                IconButton(
                  onPressed: _crest.stars > 0 ? () => setState(() => _crest = _crest.copyWith(stars: _crest.stars - 1)) : null,
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  onPressed: _crest.stars < 5 ? () => setState(() => _crest = _crest.copyWith(stars: _crest.stars + 1)) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Toj'), style: AppText.bodyStrong),
              value: _crest.crown,
              onChanged: (v) => setState(() => _crest = _crest.copyWith(crown: v)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: Text(tr('Saqlash'))),
          ],
        ),
      ),
    );
  }
}
