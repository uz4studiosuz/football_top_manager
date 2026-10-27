import 'dart:math';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../services/game_state.dart';
import '../services/name_gen.dart';
import '../ui/face_avatar.dart';
import '../ui/flag.dart';
import '../ui/widgets.dart';
import 'widgets/player_detail_view.dart';
import '../l10n/l10n.dart';
import '../data/countries.dart';

/// Build a player completely from scratch and sign him to your club.
class PlayerCreatorScreen extends StatefulWidget {
  final Player? player;
  const PlayerCreatorScreen({super.key, this.player});
  @override
  State<PlayerCreatorScreen> createState() => _PlayerCreatorScreenState();
}

class _PlayerCreatorScreenState extends State<PlayerCreatorScreen> {
  static const countries = countryFlags;

  /// Positions each playing style suits (PlayerPlayingStyles.md).
  static const styleFits = <PlayingStyle, Set<String>>{
    PlayingStyle.goalPoacher: {'CF'},
    PlayingStyle.advancedStriker: {'CF'},
    PlayingStyle.dummyRunner: {'CF', 'SS', 'AMF'},
    PlayingStyle.foxInTheBox: {'CF'},
    PlayingStyle.targetMan: {'CF'},
    PlayingStyle.deepLyingForward: {'CF', 'SS'},
    PlayingStyle.prolificWinger: {'LWF', 'RWF'},
    PlayingStyle.roamingFlank: {'LWF', 'RWF', 'LMF', 'RMF'},
    PlayingStyle.crossSpecialist: {'LWF', 'RWF', 'LMF', 'RMF'},
    PlayingStyle.creativePlaymaker: {'AMF', 'SS', 'CMF', 'LWF', 'RWF', 'LMF', 'RMF'},
    PlayingStyle.classicNo10: {'AMF', 'SS'},
    PlayingStyle.holePlayer: {'AMF', 'SS', 'CMF', 'LMF', 'RMF'},
    PlayingStyle.boxToBox: {'CMF', 'DMF', 'LMF', 'RMF'},
    PlayingStyle.anchorMan: {'DMF'},
    PlayingStyle.destroyer: {'DMF', 'CMF', 'CB'},
    PlayingStyle.orchestrator: {'CMF', 'DMF'},
    PlayingStyle.buildUp: {'CB'},
    PlayingStyle.extraFrontman: {'CB'},
    PlayingStyle.attackingFullBack: {'LB', 'RB'},
    PlayingStyle.defensiveFullBack: {'LB', 'RB'},
    PlayingStyle.fullBackFinisher: {'LB', 'RB'},
    PlayingStyle.attackingGoalkeeper: {'GK'},
    PlayingStyle.defensiveGoalkeeper: {'GK'},
  };

  final _name = TextEditingController(text: tr('Yangi Futbolchi'));
  final _random = Random();
  int age = 20;
  String nationality = 'O‘zbekiston';
  int number = 27;
  PlayerPosition position = PlayerPosition.cf;
  final Set<PlayerPosition> alt = {};
  PreferredFoot foot = PreferredFoot.right;
  int weakFoot = 3;
  PlayingStyle? style; // null = derived from attributes
  int target = 72;
  int potential = 85;
  late Map<String, int> attrs = _template();
  late FaceConfig face = const FaceConfig();

  @override
  void initState() {
    super.initState();
    final p = widget.player;
    if (p == null) return;
    _name.text = p.name;
    age = p.age;
    nationality = countries.containsKey(p.nationality) ? p.nationality : 'O‘zbekiston';
    number = p.number;
    position = p.mainPosition;
    alt.addAll(p.altPositions);
    foot = p.preferredFoot;
    weakFoot = p.weakFoot;
    attrs = p.stats.toMap().map((k, v) => MapEntry(k, v as int));
    potential = p.potential;
    target = p.ovr;
    face = p.face;
    style = styleFits[p.playingStyle]?.contains(position.code) == true ? p.playingStyle : null;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Map<String, int> _template() => GameState.statsTemplate(position, target, _random.nextInt(1 << 20))
      .toMap()
      .map((k, v) => MapEntry(k, v as int));

  Player get _preview => Player(
    id: 'creator_preview',
    name: _name.text.trim().isEmpty ? tr('Futbolchi') : _name.text.trim(),
    shortName: _name.text.trim(),
    age: age,
    nationality: nationality,
    countryFlag: countries[nationality]!,
    number: number,
    mainPosition: position,
    altPositions: alt.toList(),
    preferredFoot: foot,
    weakFoot: weakFoot,
    stats: PlayerStats.fromMap(attrs),
    contract: PlayerContract(contractYears: 3, weeklyWage: 10000),
    marketValue: 0,
    potential: potential,
    playingStyle: style,
    face: face,
  );

  void _randomize() {
    setState(() {
      _name.text = NameGen.person(_random);
      age = 17 + _random.nextInt(16);
      nationality = countries.keys.elementAt(_random.nextInt(countries.length));
      position = PlayerPosition.values[_random.nextInt(PlayerPosition.values.length)];
      alt.clear();
      foot = _random.nextInt(4) == 0 ? PreferredFoot.left : PreferredFoot.right;
      weakFoot = 2 + _random.nextInt(4);
      target = 62 + _random.nextInt(24);
      attrs = _template();
      style = null;
      face = FaceConfig.forPlayer('${_random.nextInt(1 << 30)}', nationality, age);
      number = 2 + _random.nextInt(90);
      potential = (target + _random.nextInt(14)).clamp(target, 97);
    });
  }

  Future<void> _create() async {
    final game = GameState();
    if (_name.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Ismni kiriting (kamida 2 belgi)'))));
      return;
    }
    final existing = widget.player;
    if (existing != null) {
      final used = game.userClub.squad.any((p) => p.id != existing.id && p.number == number);
      if (used) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Bu raqam band'))));
        return;
      }
      existing.name = _name.text.trim();
      existing.shortName = NameGen.short(existing.name);
      existing.age = age;
      existing.nationality = nationality;
      existing.countryFlag = countries[nationality]!;
      existing.number = number;
      existing.mainPosition = position;
      existing.altPositions = alt.toList();
      existing.preferredFoot = foot;
      existing.weakFoot = weakFoot;
      existing.stats = PlayerStats.fromMap(attrs);
      existing.potential = max(potential, existing.ovr);
      existing.face = face;
      final profile = PlayingProfile.derive(position.code, attrs);
      existing.playingStyle = style ?? profile.style;
      existing.defendingStyle = profile.defending;
      existing.aiStyles = profile.ai;
      game.touch();
      Navigator.pop(context);
      return;
    }
    final p = game.addCreatedPlayer(
      name: _name.text,
      age: age,
      nationality: nationality,
      countryFlag: countries[nationality]!,
      number: number,
      position: position,
      altPositions: alt.toList(),
      foot: foot,
      weakFoot: weakFoot,
      stats: PlayerStats.fromMap(attrs),
      potential: potential,
      face: face,
      style: style,
    );
    if (!mounted) return;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(game.lastTransferError ?? tr('Qo‘shib bo‘lmadi'))));
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trf('{0} zaxiraga qo‘shildi (OVR {1}). Jamoa → Sxema va tarkib → Zaxira', [p.name, p.ovr]))));
    PlayerDetailView.show(context, player: p, club: game.userClub);
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette tokens when appearance changes.
    final game = GameState();
    final club = game.isInitialized ? game.userClub : null;
    final shirt = club?.primaryColor ?? AppColors.primary;
    final preview = _preview;
    final ovr = preview.ovr;
    final fits = PlayingStyle.values.where((s) => styleFits[s]!.contains(position.code)).toList();
    final issue = game.isInitialized && widget.player == null ? game.createdPlayerIssue() : null;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: issue == null && game.isInitialized ? _create : null,
        icon: Icon(widget.player == null ? Icons.person_add_alt_1_rounded : Icons.save_outlined),
        label: Text(widget.player == null ? trf('Jamoaga qo‘shish · OVR {0}', [ovr]) : tr('Saqlash')),
      ),
      appBar: AppBar(
        title: Text(tr(widget.player == null ? 'Futbolchi yaratish' : 'Futbolchini tahrirlash')),
        actions: [
          TextButton.icon(
            onPressed: _randomize,
            icon: const Icon(Icons.casino_outlined, size: 18),
            label: Text(tr('Tasodifiy')),
          ),
        ],
      ),
      body: PageWidth(
      maxWidth: 900,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        children: [
          // --------------------------------------------------- live preview
          AppCard(
            child: Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    final f = await editFace(context, face, shirt: shirt, nationality: nationality, age: age);
                    if (f != null && mounted) setState(() => face = f);
                  },
                  child: Stack(
                    children: [
                      FaceAvatar(config: face, size: 92, shirt: shirt, trim: club?.secondaryColor),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(preview.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.h2),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          PositionChip(position.code, fontSize: 11),
                          const SizedBox(width: 6),
                          Flexible(
                            child: FlagLabel(
                              countries[nationality]!,
                              trf('{0} {1} yosh · #{2}', ['', age, number]).trim(),
                              nationality: nationality,
                              style: AppText.caption,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(preview.playingStyle.title, style: AppText.small.copyWith(color: AppColors.primary)),
                    ],
                  ),
                ),
                Column(
                  children: [
                    ValueBadge(ovr, size: 48),
                    const SizedBox(height: 4),
                    Text('OVR', style: AppText.overline),
                    const SizedBox(height: 4),
                    ValueBadge(max(potential, ovr), size: 30, filled: false),
                    Text(tr('Salohiyat'), style: AppText.caption),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ------------------------------------------------------- identity
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(tr('Shaxsiy ma’lumot'), icon: Icons.badge_outlined),
                TextField(
                  controller: _name,
                  decoration: InputDecoration(labelText: tr('Ism va familiya'), prefixIcon: const Icon(Icons.person_outline), suffixIcon: IconButton(
                    tooltip: tr('Tasodifiy'), icon: const Icon(Icons.casino_outlined),
                    onPressed: () => setState(() => _name.text = NameGen.person(_random)),
                  )),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: nationality,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: tr('Millati'), prefixIcon: Icon(Icons.flag_outlined)),
                  items: [
                    for (final c in countries.keys)
                      DropdownMenuItem(value: c, child: FlagLabel(countries[c]!, tr(c), nationality: c)),
                  ],
                  onChanged: (v) => setState(() => nationality = v!),
                ),
                const SizedBox(height: 8),
                _slider(tr('Yosh'), age, 16, 40, (v) => setState(() => age = v)),
                _slider(tr('Futbolka raqami'), number, 1, 99, (v) => setState(() => number = v)),
                Text(tr('Asosiy oyoq'), style: AppText.bodyStrong),
                SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<PreferredFoot>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: PreferredFoot.right, label: Text(tr('O‘ng'))),
                      ButtonSegment(value: PreferredFoot.left, label: Text(tr('Chap'))),
                    ],
                    selected: {foot},
                    onSelectionChanged: (s) => setState(() => foot = s.first),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text(tr('Kuchsiz oyoq'), style: AppText.bodyStrong)),
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => weakFoot = i),
                        icon: Icon(
                          i <= weakFoot ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: i <= weakFoot ? AppColors.gold : AppColors.ink3,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // -------------------------------------------------------- position
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(tr('Pozitsiya va uslub'), icon: Icons.sports_soccer),
                Text(tr('Asosiy pozitsiya'), style: AppText.small),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final pos in PlayerPosition.values)
                      ChoiceChip(
                        label: Text(pos.code),
                        selected: position == pos,
                        showCheckmark: false,
                        onSelected: (_) => setState(() {
                          position = pos;
                          alt.remove(pos);
                          if (style != null && !styleFits[style]!.contains(pos.code)) style = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(tr('Muqobil pozitsiyalar (jarimasiz o‘ynaydi)'), style: AppText.small),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final pos in PlayerPosition.values.where((p) => p != position))
                      FilterChip(
                        label: Text(pos.code),
                        selected: alt.contains(pos),
                        onSelected: (v) => setState(() => v ? alt.add(pos) : alt.remove(pos)),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<PlayingStyle?>(
                  initialValue: style,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: tr('O‘yin uslubi'), prefixIcon: Icon(Icons.style_outlined)),
                  items: [
                    DropdownMenuItem<PlayingStyle?>(
                      value: null,
                      child: Text(trf('Avtomatik (atributlarga qarab) · {0}', [PlayingProfile.derive(position.code, attrs).style.title])),
                    ),
                    for (final s in fits) DropdownMenuItem<PlayingStyle?>(value: s, child: Text('${s.title} · ${s.uzbek}')),
                  ],
                  onChanged: (v) => setState(() => style = v),
                ),
                const SizedBox(height: 6),
                Text(preview.playingStyle.description, style: AppText.caption),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ------------------------------------------------------ attributes
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(tr('Tez shablon'), icon: Icons.auto_fix_high_rounded),
                Text(
                  tr('Pozitsiyaga mos atributlarni tanlangan darajada avtomatik to‘ldiradi. Keyin har birini qo‘lda sozlashingiz mumkin.'),
                  style: AppText.caption,
                ),
                _slider(tr('Daraja (taxminiy OVR)'), target, 50, 95, (v) => setState(() => target = v)),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => setState(() {
                      attrs = _template();
                      potential = max(potential, target);
                    }),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(trf('{0} shablonini qo‘llash', [position.code])),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final group in PlayerStats.groups.entries)
            AppCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.key, style: AppText.h3),
                  const SizedBox(height: 4),
                  for (final key in group.value) _attribute(key),
                ],
              ),
            ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(tr('Salohiyat'), icon: Icons.trending_up_rounded),
                Text(
                  tr('Futbolchi yaxshi o‘ynasa va yosh bo‘lsa, OVR shu chegaragacha o‘sadi.'),
                  style: AppText.caption,
                ),
                _slider(tr('Eng yuqori OVR'), max(potential, ovr), ovr, 99, (v) => setState(() => potential = v)),
                InfoRow(tr('Bozor bahosi'), formatMoney(Player.valuation(ovr, age, max(potential, ovr)))),
                InfoRow(tr('Haftalik maosh (talab)'), formatMoney(preview.calculatedRenewalWageDemand)),
                if (club != null) InfoRow(tr('Bo‘sh maosh limiti'), formatMoney(club.remainingWageBudget)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (issue != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(issue, style: const TextStyle(color: AppColors.live)),
            ),
        ],
      ),
    ),
    );
  }

  Widget _attribute(String key) {
    final v = attrs[key]!;
    final c = AppColors.attribute(v);
    return Row(
      children: [
        Expanded(flex: 5, child: Text(PlayerStats.labels[key]!, style: AppText.small.copyWith(color: AppColors.ink))),
        Expanded(
          flex: 6,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(activeTrackColor: c, thumbColor: c),
            child: Slider(
              min: 40,
              max: 99,
              value: v.toDouble(),
              onChanged: (x) => setState(() => attrs[key] = x.round()),
            ),
          ),
        ),
        SizedBox(
          width: 30,
          child: Text('$v', textAlign: TextAlign.right, style: AppText.number.copyWith(color: c)),
        ),
      ],
    );
  }

  Widget _slider(String label, int value, int lo, int hi, ValueChanged<int> onChanged) => hi <= lo
      ? InfoRow(label, '$value')
      : Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(tr(label), style: AppText.bodyStrong)),
            Text('$value', style: AppText.number.copyWith(color: AppColors.primary)),
          ],
        ),
        Slider(
          min: lo.toDouble(),
          max: hi.toDouble(),
          divisions: hi - lo,
          value: value.clamp(lo, hi).toDouble(),
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    ),
  );
}
