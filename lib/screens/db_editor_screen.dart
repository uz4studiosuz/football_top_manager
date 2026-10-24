import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/player.dart';
import '../data/initial_database.dart';
import '../services/db_editor.dart';
import '../ui/face_avatar.dart';
import '../ui/face_from_photo.dart';
import '../ui/widgets.dart';
import '../l10n/l10n.dart';

/// Creator tool (/editor): edit, add, move and delete players and clubs,
/// save the result on this device and export the JSON data files.
class DbEditorScreen extends StatefulWidget {
  const DbEditorScreen({super.key});
  @override
  State<DbEditorScreen> createState() => _DbEditorScreenState();
}

class _DbEditorScreenState extends State<DbEditorScreen> {
  final db = DbEditor();
  String? _league, _club, _player;
  String _query = '';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    db.load().then((_) {
      if (mounted) setState(() => _league = db.leagues.first['id']);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    db.dispose();
    super.dispose();
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save() async {
    await db.saveLocally();
    _snack(tr('Saqlandi. Yangi karyeralar tahrirlangan bazadan foydalanadi.'));
  }

  Future<void> _export() async {
    final files = db.editedFiles;
    if (files.isEmpty) {
      _snack(tr('Hali hech narsa tahrirlanmadi.'));
      return;
    }
    for (final f in files) {
      await FilePicker.saveFile(
        fileName: f,
        bytes: Uint8List.fromList(utf8.encode(db.fileJson(f))),
        mimeType: 'application/json',
      );
    }
    _snack(trf('{0} ta fayl eksport qilindi: ularni assets/data papkasiga qo‘ying.', [files.length]));
  }

  Future<void> _discard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Barcha tahrirlarni bekor qilish?')),
        content: Text(tr('Qurilmadagi o‘zgarishlar o‘chadi va asl baza qaytadi.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Yo‘q'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Ha, bekor qilish'))),
        ],
      ),
    );
    if (ok != true) return;
    await db.discardAll();
    setState(() {
      _club = _player = null;
      _league = db.leagues.first['id'];
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: db,
    builder: (context, _) {
      if (!db.loaded || _league == null) return LoadingView(message: tr('Baza yuklanmoqda…'));
      return LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 1100;
          final pane = !wide && _player != null
              ? _playerPane()
              : !wide && _club != null
              ? _squadPane()
              : null;
          return PopScope(
            canPop: wide || (_club == null && _player == null),
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) setState(() => _player != null ? _player = null : _club = null);
            },
            child: Scaffold(
              appBar: AppBar(
                title: Text(tr('Baza muharriri')),
                actions: [
                  if (db.dirty.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Center(
                        child: Text(trf('{0} fayl o‘zgargan', [db.dirty.length]), style: AppText.caption),
                      ),
                    ),
                  IconButton(tooltip: tr('Saqlash'), onPressed: db.dirty.isEmpty ? null : _save, icon: const Icon(Icons.save_rounded)),
                  IconButton(tooltip: tr('JSON eksport'), onPressed: _export, icon: const Icon(Icons.download_rounded)),
                  IconButton(tooltip: tr('Bekor qilish'), onPressed: _discard, icon: const Icon(Icons.restore_rounded)),
                ],
              ),
              body: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 300, child: _clubsPane()),
                        const VerticalDivider(width: 1),
                        SizedBox(width: 360, child: _club == null ? _hint(tr('Klubni tanlang')) : _squadPane()),
                        const VerticalDivider(width: 1),
                        Expanded(child: _player == null ? _hint(tr('Futbolchini tanlang')) : _playerPane()),
                      ],
                    )
                  : pane ?? _clubsPane(),
            ),
          );
        },
      );
    },
  );

  Widget _hint(String text) => Center(child: Text(text, style: AppText.caption));

  Widget _clubsPane() {
    final results = _query.length < 2
        ? const <(String, Map<String, dynamic>, Map<String, dynamic>)>[]
        : db
              .allPlayers()
              .where((r) => '${r.$3['name']}'.toLowerCase().contains(_query.toLowerCase()))
              .take(30)
              .toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        TextField(
          controller: _search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: tr('Futbolchi qidirish'),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _query = v.trim()),
        ),
        for (final (league, club, p) in results)
          ListTile(
            dense: true,
            title: Text('${p['name']}'),
            subtitle: Text('${club['name']} · ${p['mainPosition']}'),
            onTap: () => setState(() {
              _league = league;
              _club = club['id'];
              _player = p['id'];
            }),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _league,
          decoration: InputDecoration(labelText: tr('Liga'), border: const OutlineInputBorder(), isDense: true),
          items: [
            for (final l in db.leagues) DropdownMenuItem(value: l['id'] as String, child: Text(InitialDatabase.info(l['id'] as String).name)),
          ],
          onChanged: (v) => setState(() {
            _league = v;
            _club = _player = null;
          }),
        ),
        const SizedBox(height: 8),
        for (final c in db.clubs(_league!))
          ListTile(
            dense: true,
            selected: c['id'] == _club,
            selectedTileColor: AppColors.primarySoft,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: CircleAvatar(radius: 14, backgroundColor: Color(c['primaryColor'] as int)),
            title: Text('${c['name']}'),
            subtitle: Text(trf('{0} futbolchi', [(c['squadIds'] as List).length])),
            trailing: IconButton(
              tooltip: tr('Klubni tahrirlash'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _editClub(c),
            ),
            onTap: () => setState(() {
              _club = c['id'];
              _player = null;
            }),
          ),
      ],
    );
  }

  Widget _squadPane() {
    final club = db.club(_club!);
    final squad = db.squad(_club!);
    final xi = (club['startingLineupIds'] as List).toSet(), bench = (club['benchIds'] as List).toSet();
    return Column(
      children: [
        ListTile(
          title: Text('${club['name']}', style: AppText.h3),
          subtitle: Text(trf('{0} futbolchi', [squad.length])),
          trailing: FilledButton.icon(
            onPressed: () => _addPlayer(squad),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: Text(tr('Qo‘shish')),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            children: [
              for (final p in squad)
                ListTile(
                  dense: true,
                  selected: p['id'] == _player,
                  selectedTileColor: AppColors.primarySoft,
                  leading: SizedBox(width: 40, child: PositionChip('${p['mainPosition']}')),
                  title: Text('${p['name']}'),
                  subtitle: Text(
                    trf('{0} yosh · {1}', [
                      p['age'],
                      xi.contains(p['id']) ? tr('Asosiy') : bench.contains(p['id']) ? tr('Zaxira') : tr('Rezerv'),
                    ]),
                  ),
                  trailing: ValueBadge(_ovr(p), size: 26),
                  onTap: () => setState(() => _player = p['id']),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static int _ovr(Map<String, dynamic> p) {
    try {
      return Player.fromMap(p).ovr;
    } catch (_) {
      return 0;
    }
  }

  Map<String, dynamic> _copy(Map<String, dynamic> m) => jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  void _addPlayer(List<Map<String, dynamic>> squad) {
    if (squad.isEmpty) return;
    final p = _copy(squad.firstWhere((x) => x['mainPosition'] != 'GK', orElse: () => squad.first))
      ..remove('face')
      ..remove('playingStyle')
      ..['name'] = tr('Yangi futbolchi')
      ..['shortName'] = tr('Yangi')
      ..['age'] = 21
      ..['number'] = 99
      ..['marketValue'] = 500000
      ..['stats'] = {for (final k in PlayerStats.labels.keys) k: k.startsWith('gk') ? 40 : 60};
    final added = db.addPlayer(_club!, p);
    setState(() => _player = added['id']);
  }

  Future<void> _editClub(Map<String, dynamic> club) async {
    final c = _copy(club);
    final fields = <String, TextEditingController>{
      for (final k in ['name', 'shortName', 'nickname', 'city', 'stadiumName', 'stadiumCapacity', 'founded', 'reputation', 'transferBudget', 'wageBudget', 'managerName'])
        k: TextEditingController(text: '${c[k] ?? ''}'),
    };
    const numeric = {'stadiumCapacity', 'founded', 'reputation', 'transferBudget', 'wageBudget'};
    final labels = {
      'name': tr('Nomi'),
      'shortName': tr('Qisqa nomi'),
      'nickname': tr('Laqabi'),
      'city': tr('Shahar'),
      'stadiumName': tr('Stadion'),
      'stadiumCapacity': tr('Sig‘imi'),
      'founded': tr('Tashkil topgan'),
      'reputation': tr('Obro‘ (1–100)'),
      'transferBudget': tr('Transfer byudjeti'),
      'wageBudget': tr('Maosh limiti'),
      'managerName': tr('Bosh murabbiy'),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Klubni tahrirlash')),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final e in fields.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: e.value,
                      keyboardType: numeric.contains(e.key) ? TextInputType.number : null,
                      inputFormatters: numeric.contains(e.key) ? [FilteringTextInputFormatter.digitsOnly] : null,
                      decoration: InputDecoration(labelText: labels[e.key], isDense: true, border: const OutlineInputBorder()),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Bekor'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Qo‘llash'))),
        ],
      ),
    );
    if (ok == true) {
      for (final e in fields.entries) {
        c[e.key] = numeric.contains(e.key) ? int.tryParse(e.value.text) ?? c[e.key] : e.value.text.trim();
      }
      db.updateClub(c);
    }
    for (final t in fields.values) {
      t.dispose();
    }
  }

  Widget _playerPane() {
    final p = db.squad(_club!).where((x) => x['id'] == _player).firstOrNull;
    if (p == null) return _hint(tr('Futbolchini tanlang'));
    return _PlayerForm(
      key: ValueKey(p['id']),
      db: db,
      clubId: _club!,
      initial: _copy(p),
      onApply: (m) {
        db.updatePlayer(_club!, m);
        _snack(tr('O‘zgarishlar qo‘llandi. Saqlashni unutmang.'));
      },
      onMoved: (toClub) => setState(() {
        _club = toClub;
        _league = db.leagueOfClub(toClub);
      }),
      onDeleted: () => setState(() => _player = null),
    );
  }
}

class _PlayerForm extends StatefulWidget {
  final DbEditor db;
  final String clubId;
  final Map<String, dynamic> initial;
  final void Function(Map<String, dynamic>) onApply;
  final void Function(String toClub) onMoved;
  final VoidCallback onDeleted;
  const _PlayerForm({
    super.key,
    required this.db,
    required this.clubId,
    required this.initial,
    required this.onApply,
    required this.onMoved,
    required this.onDeleted,
  });
  @override
  State<_PlayerForm> createState() => _PlayerFormState();
}

class _PlayerFormState extends State<_PlayerForm> {
  late final Map<String, dynamic> m = widget.initial;
  late final _name = TextEditingController(text: '${m['name']}');
  late final _short = TextEditingController(text: '${m['shortName']}');
  late final _nation = TextEditingController(text: '${m['nationality']}');
  late final _flag = TextEditingController(text: '${m['countryFlag'] ?? ''}');
  late final _value = TextEditingController(text: '${m['marketValue']}');
  bool _changed = false;

  @override
  void dispose() {
    for (final c in [_name, _short, _nation, _flag, _value]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _stats => m['stats'] as Map<String, dynamic>;

  void _set(String key, Object? value) => setState(() {
    m[key] = value;
    _changed = true;
  });

  Player? get _preview {
    try {
      return Player.fromMap({
        ...m,
        'name': _name.text,
        'shortName': _short.text,
        'nationality': _nation.text,
      });
    } catch (_) {
      return null;
    }
  }

  FaceConfig get _face => m['face'] == null
      ? FaceConfig.forPlayer('${m['id']}', '${m['nationality']}', (m['age'] as num).toInt())
      : FaceConfig.fromMap({
          ...FaceConfig.forPlayer('${m['id']}', '${m['nationality']}', (m['age'] as num).toInt()).toMap(),
          ...Map<String, dynamic>.from(m['face']),
        });

  void _apply() {
    m['name'] = _name.text.trim();
    m['shortName'] = _short.text.trim();
    m['nationality'] = _nation.text.trim();
    m['countryFlag'] = _flag.text.trim();
    m['marketValue'] = int.tryParse(_value.text) ?? m['marketValue'];
    widget.onApply(jsonDecode(jsonEncode(m)) as Map<String, dynamic>);
    setState(() => _changed = false);
  }

  Future<void> _transfer() async {
    final db = widget.db;
    if (db.leaveBlocker(widget.clubId) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Klubda kamida 18 futbolchi qolishi kerak.'))),
      );
      return;
    }
    var league = db.leagueOfClub(widget.clubId);
    final to = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(tr('Boshqa klubga o‘tkazish')),
          content: SizedBox(
            width: 380,
            height: 420,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: league,
                  items: [
                    for (final l in db.leagues) DropdownMenuItem(value: l['id'] as String, child: Text(InitialDatabase.info(l['id'] as String).name)),
                  ],
                  onChanged: (v) => setLocal(() => league = v!),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final c in db.clubs(league))
                        if (c['id'] != widget.clubId)
                          ListTile(
                            dense: true,
                            leading: CircleAvatar(radius: 12, backgroundColor: Color(c['primaryColor'] as int)),
                            title: Text('${c['name']}'),
                            onTap: () => Navigator.pop(ctx, c['id'] as String),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (to == null) return;
    if (_changed) _apply();
    db.transfer('${m['id']}', widget.clubId, to);
    widget.onMoved(to);
  }

  Future<void> _delete() async {
    if (widget.db.leaveBlocker(widget.clubId) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Klubda kamida 18 futbolchi qolishi kerak.'))),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trf('{0} o‘chirilsinmi?', [m['name']])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Yo‘q'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('O‘chirish'))),
        ],
      ),
    );
    if (ok != true) return;
    widget.db.deletePlayer('${m['id']}', widget.clubId);
    widget.onDeleted();
  }

  Future<void> _editFace() async {
    final face = await editFace(context, _face, nationality: '${m['nationality']}', age: (m['age'] as num).toInt());
    if (face != null) _set('face', face.toMap());
  }

  Future<void> _faceFromPhoto() async {
    final face = await faceFromPhoto(context, _face);
    if (face != null) _set('face', face.toMap());
  }

  Widget _field(TextEditingController c, String label, {bool number = false}) => TextField(
    controller: c,
    keyboardType: number ? TextInputType.number : null,
    inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
    decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
    onChanged: (_) => setState(() => _changed = true),
  );

  Widget _stepper(String label, int value, int lo, int hi, void Function(int) onChanged) => InputDecorator(
    decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
    child: Row(
      children: [
        InkWell(onTap: value > lo ? () => onChanged(value - 1) : null, child: const Icon(Icons.remove, size: 18)),
        Expanded(child: Text('$value', textAlign: TextAlign.center, style: AppText.bodyStrong)),
        InkWell(onTap: value < hi ? () => onChanged(value + 1) : null, child: const Icon(Icons.add, size: 18)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final positions = PlayerPosition.values.map((p) => p.code).toList();
    final alt = (m['altPositions'] as List).cast<String>().toSet();
    Widget wrap(List<Widget> children) => LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 640 ? 3 : 2;
        final w = (box.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(spacing: 8, runSpacing: 8, children: [for (final c in children) SizedBox(width: w, child: c)]);
      },
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            FaceAvatar(config: _face, size: 84),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_name.text, style: AppText.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    preview == null
                        ? '—'
                        : '${preview.mainPosition.code} · OVR ${preview.ovr} · ${preview.playingStyle.title} · ${preview.formattedMarketValue}',
                    style: AppText.small,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(onPressed: _editFace, icon: const Icon(Icons.face_retouching_natural, size: 18), label: Text(tr('Yuz'))),
                      OutlinedButton.icon(onPressed: _faceFromPhoto, icon: const Icon(Icons.photo_camera_outlined, size: 18), label: Text(tr('Rasmdan yuz'))),
                      OutlinedButton.icon(onPressed: _transfer, icon: const Icon(Icons.swap_horiz_rounded, size: 18), label: Text(tr('O‘tkazish'))),
                      OutlinedButton.icon(
                        onPressed: _delete,
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.live),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: Text(tr('O‘chirish')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        wrap([
          _field(_name, tr('To‘liq ism')),
          _field(_short, tr('Qisqa ism')),
          _field(_nation, tr('Millati')),
          _field(_flag, tr('Bayroq (emoji)')),
          _field(_value, tr('Bozor bahosi (EUR)'), number: true),
          _stepper(tr('Yosh'), (m['age'] as num).toInt(), 15, 45, (v) => _set('age', v)),
          _stepper(tr('Raqam'), (m['number'] as num).toInt(), 1, 99, (v) => _set('number', v)),
          _stepper(tr('Kuchsiz oyoq'), (m['weakFoot'] as num).toInt(), 1, 5, (v) => _set('weakFoot', v)),
          DropdownButtonFormField<String>(
            initialValue: '${m['mainPosition']}',
            decoration: InputDecoration(labelText: tr('Asosiy pozitsiya'), isDense: true, border: const OutlineInputBorder()),
            items: [for (final p in positions) DropdownMenuItem(value: p, child: Text(p))],
            onChanged: (v) => _set('mainPosition', v),
          ),
          DropdownButtonFormField<String>(
            initialValue: '${m['preferredFoot']}',
            decoration: InputDecoration(labelText: tr('Oyoq'), isDense: true, border: const OutlineInputBorder()),
            items: [
              DropdownMenuItem(value: 'right', child: Text(tr('O‘ng'))),
              DropdownMenuItem(value: 'left', child: Text(tr('Chap'))),
            ],
            onChanged: (v) => _set('preferredFoot', v),
          ),
          DropdownButtonFormField<String>(
            initialValue: m['playingStyle'] as String? ?? '',
            decoration: InputDecoration(labelText: tr('O‘yin uslubi'), isDense: true, border: const OutlineInputBorder()),
            items: [
              DropdownMenuItem(value: '', child: Text(tr('Avto (atributlardan)'))),
              for (final s in PlayingStyle.values) DropdownMenuItem(value: s.name, child: Text(s.title)),
            ],
            onChanged: (v) => setState(() {
              if (v == null || v.isEmpty) {
                m.remove('playingStyle');
              } else {
                m['playingStyle'] = v;
              }
              _changed = true;
            }),
          ),
        ]),
        const SizedBox(height: 12),
        Text(tr('Muqobil pozitsiyalar'), style: AppText.bodyStrong),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in positions)
              if (p != m['mainPosition'])
                FilterChip(
                  label: Text(p),
                  selected: alt.contains(p),
                  visualDensity: VisualDensity.compact,
                  onSelected: (on) => _set('altPositions', on ? [...alt, p] : alt.where((x) => x != p).toList()),
                ),
          ],
        ),
        for (final g in PlayerStats.groups.entries) ...[
          const SizedBox(height: 16),
          Text(tr(g.key), style: AppText.bodyStrong),
          for (final k in g.value)
            Row(
              children: [
                SizedBox(width: 170, child: Text(PlayerStats.labels[k]!, style: AppText.small.copyWith(color: AppColors.ink))),
                Expanded(
                  child: Slider(
                    value: (_stats[k] as num).toDouble().clamp(40, 99),
                    min: 40,
                    max: 99,
                    divisions: 59,
                    onChanged: (v) => setState(() {
                      _stats[k] = v.round();
                      _changed = true;
                    }),
                  ),
                ),
                SizedBox(width: 34, child: ValueBadge((_stats[k] as num).toInt(), size: 26)),
              ],
            ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _changed ? _apply : null,
          icon: const Icon(Icons.check_rounded),
          label: Text(tr('O‘zgarishlarni qo‘llash')),
        ),
      ],
    );
  }
}
