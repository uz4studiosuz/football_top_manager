import 'dart:math';
import 'package:flutter/material.dart';
import '../models/club.dart';
import '../data/initial_database.dart';
import '../models/player.dart';
import '../ui/face_avatar.dart';
import '../services/game_state.dart';
import '../ui/widgets.dart';
import 'main_navigation_screen.dart';
import '../models/manager_profile.dart';

/// Foydalanuvchi o'z jamoasini noldan yaratish ekrani
class CustomClubCreatorScreen extends StatefulWidget {
  final ManagerProfile? managerProfile;
  final String league;
  const CustomClubCreatorScreen({super.key, this.managerProfile, this.league = 'super'});
  @override
  State<CustomClubCreatorScreen> createState() => _CustomClubCreatorScreenState();
}

class _CustomClubCreatorScreenState extends State<CustomClubCreatorScreen> {
  final _nameController = TextEditingController(text: 'Toshkent Stars');
  final _shortNameController = TextEditingController(text: 'TKS');
  final _stadiumController = TextEditingController(text: 'Milliy Arena');
  int _stadiumCapacity = 45000;
  CrestShape _shape = CrestShape.modernShield;
  CrestPattern _pattern = CrestPattern.verticalStripes;
  CrestEmblem _emblem = CrestEmblem.monogram;
  bool _crown = false;
  int _stars = 1;
  Color _primary = const Color(0xFF374DF5);
  Color _secondary = const Color(0xFF0F172A);
  Color _trim = const Color(0xFFF2C14E);
  String _monogram = 'TS';
  late String _league = widget.league;
  late List<Player> _candidates = GameState.starCandidates();
  int _star = 0;
  static const _colors = [
    Color(0xFF374DF5),
    Color(0xFF1C2C5B),
    Color(0xFF6CABDD),
    Color(0xFF0EA5E9),
    Color(0xFF004D98),
    Color(0xFFDB0007),
    Color(0xFFA50044),
    Color(0xFF8B1D41),
    Color(0xFFF97316),
    Color(0xFFF2C14E),
    Color(0xFF12A150),
    Color(0xFF0F766E),
    Color(0xFF7C3AED),
    Color(0xFFEC4899),
    Color(0xFF0F172A),
    Color(0xFF6B7280),
    Color(0xFFFFFFFF),
    Color(0xFF000000),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _shortNameController.dispose();
    _stadiumController.dispose();
    super.dispose();
  }

  ClubCrestConfig get _crest => ClubCrestConfig(
    shape: _shape,
    pattern: _pattern,
    primaryColor: _primary,
    secondaryColor: _secondary,
    trimColor: _trim,
    monogram: _monogram.isNotEmpty ? _monogram : 'FC',
    stars: _stars,
    emblem: _emblem,
    crown: _crown,
    ringText: _nameController.text.toUpperCase(),
    ringColor: _secondary,
  );

  void _createAndStart() {
    final name = _nameController.text.trim();
    final shortName = _shortNameController.text.trim();
    final stadium = _stadiumController.text.trim();
    if (name.isEmpty || shortName.isEmpty || stadium.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iltimos, barcha maydonlarni to\'ldiring!')),
      );
      return;
    }
    GameState().startCareerWithCustomClub(
      name: name,
      shortName: shortName,
      stadiumName: stadium,
      stadiumCapacity: _stadiumCapacity,
      crestConfig: _crest,
      managerProfile: widget.managerProfile,
      star: _candidates[_star],
      league: _league,
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  void _randomLogo() {
    final r = Random();
    setState(() {
      _shape = CrestShape.values[r.nextInt(CrestShape.values.length)];
      _pattern = CrestPattern.values[r.nextInt(CrestPattern.values.length)];
      _emblem = CrestEmblem.values[r.nextInt(CrestEmblem.values.length)];
      _crown = r.nextInt(5) == 0;
      _stars = r.nextInt(4);
      final colors = List<Color>.of(_colors)..shuffle(r);
      _primary = colors[0];
      _secondary = colors.firstWhere((c) => c != _primary);
      _trim = _primary.computeLuminance() > 0.45 ? const Color(0xFF14213D) : const Color(0xFFF2C14E);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yangi Jamoa Yaratish')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            children: [
              ClubCrestWidget(config: _crest, size: 124),
              const SizedBox(height: 12),
              Text(_nameController.text.isEmpty ? 'Klub nomi' : _nameController.text, style: AppText.h2),
              const SizedBox(height: 2),
              Text('${_shortNameController.text.toUpperCase()} · ${_stadiumController.text}', style: AppText.caption),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _randomLogo,
                icon: const Icon(Icons.casino_outlined),
                label: const Text('Tasodifiy logo yaratish'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('1. Jamoa Ma\'lumotlari'),
              const Text('Qaysi ligada o‘ynaysiz?', style: AppText.small),
              const SizedBox(height: 8),
              PillTabs(
                labels: [for (final l in InitialDatabase.leagues) l.name],
                index: InitialDatabase.leagues.indexWhere((l) => l.id == _league),
                onChanged: (i) => setState(() => _league = InitialDatabase.leagues[i].id),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Klub nomi', prefixIcon: Icon(Icons.shield_outlined)),
                onChanged: (val) => setState(() {
                  if (val.length >= 2 && _monogram.length <= 2) _monogram = val.substring(0, 2).toUpperCase();
                }),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _shortNameController,
                      maxLength: 3,
                      decoration: const InputDecoration(labelText: 'Qisqartma', counterText: '', prefixIcon: Icon(Icons.tag_rounded)),
                      onChanged: (val) => setState(() => _monogram = val.toUpperCase()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _stadiumController,
                      decoration: const InputDecoration(labelText: 'Stadion', prefixIcon: Icon(Icons.stadium_outlined)),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Stadion sig‘imi: ${(_stadiumCapacity / 1000).toStringAsFixed(0)} 000 muxlis', style: AppText.small),
              Slider(
                value: _stadiumCapacity.toDouble(),
                min: 25000,
                max: 90000,
                divisions: 13,
                onChanged: (val) => setState(() => _stadiumCapacity = val.round()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('2. Emblem Shakli'),
              _previewGrid<CrestShape>(
                CrestShape.values,
                _shape,
                (v) => _crest.copyWith(shape: v),
                (v) => v.label,
                (v) => setState(() => _shape = v),
              ),
              const SizedBox(height: 16),
              const SectionHeader('3. Naqsh'),
              _previewGrid<CrestPattern>(
                CrestPattern.values,
                _pattern,
                (v) => _crest.copyWith(pattern: v),
                (v) => v.label,
                (v) => setState(() => _pattern = v),
              ),
              const SizedBox(height: 16),
              const SectionHeader('4. Belgi va bezak'),
              _previewGrid<CrestEmblem>(
                CrestEmblem.values,
                _emblem,
                (v) => _crest.copyWith(emblem: v),
                (v) => v.label,
                (v) => setState(() => _emblem = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Toj'),
                value: _crown,
                onChanged: (v) => setState(() => _crown = v),
              ),
              Row(
                children: [
                  const Text('Yulduzlar', style: AppText.bodyStrong),
                  Expanded(
                    child: Slider(
                      value: _stars.toDouble(),
                      min: 0,
                      max: 5,
                      divisions: 5,
                      label: '$_stars',
                      onChanged: _crown ? null : (v) => setState(() => _stars = v.round()),
                    ),
                  ),
                  Text('$_stars', style: AppText.number),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('5. Klub ranglari'),
              _colorRow('Asosiy rang', _primary, (c) => setState(() => _primary = c)),
              _colorRow('Ikkilamchi rang', _secondary, (c) => setState(() => _secondary = c)),
              _colorRow('Hoshiya rangi', _trim, (c) => setState(() => _trim = c)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                '6. Yulduz futbolchi',
                action: 'Boshqa variantlar',
                onAction: () => setState(() {
                  _candidates = GameState.starCandidates();
                  _star = 0;
                }),
              ),
              const Text(
                'Tarkib o‘rtacha darajada (64–73). Bitta yulduzni o‘zingiz tanlaysiz.',
                style: AppText.caption,
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _candidates.length; i++)
                Material(
                  color: i == _star ? AppColors.primarySoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _star = i),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          FaceAvatar(config: _candidates[i].face, size: 42, shirt: _primary, circle: true),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_candidates[i].name, style: AppText.bodyStrong),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    PositionChip(_candidates[i].mainPosition.code),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '${_candidates[i].age} yosh · ${_candidates[i].playingStyle.title}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.caption,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          ValueBadge(_candidates[i].ovr, size: 34),
                          const SizedBox(width: 6),
                          Icon(
                            i == _star ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: i == _star ? AppColors.primary : AppColors.ink3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const AppCard(
          color: AppColors.primarySoft,
          child: Row(
            children: [
              Icon(Icons.stars_rounded, color: AppColors.primary, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Klub yaratilgach, 23 kishilik o‘rtacha tarkib, tanlangan yulduz, €80.0M transfer byudjeti va akademiya ajratiladi.',
                  style: AppText.small,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _createAndStart,
            icon: const Icon(Icons.rocket_launch_rounded),
            label: const FittedBox(child: Text('KLUBNI YARATISH VA BOSHLASH')),
          ),
        ),
        const SizedBox(height: 20),
      ],
    ),
    ),
  );

  Widget _previewGrid<T>(
    List<T> values,
    T selected,
    ClubCrestConfig Function(T) preview,
    String Function(T) label,
    ValueChanged<T> onTap,
  ) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final v in values)
        InkWell(
          onTap: () => onTap(v),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 74,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: v == selected ? AppColors.primarySoft : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: v == selected ? AppColors.primary : Colors.transparent, width: 2),
            ),
            child: Column(
              children: [
                ClubCrestWidget(config: preview(v), size: 40),
                const SizedBox(height: 4),
                Text(
                  label(v),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: v == selected ? FontWeight.w700 : FontWeight.w500,
                    color: v == selected ? AppColors.primary : AppColors.ink2,
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _colorRow(String title, Color selected, ValueChanged<Color> onSelect) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.small),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _colors.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final c = _colors[i];
              final chosen = c.toARGB32() == selected.toARGB32();
              return GestureDetector(
                onTap: () => onSelect(c),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: chosen ? AppColors.primary : AppColors.line, width: chosen ? 3 : 1),
                  ),
                  child: chosen
                      ? Icon(Icons.check, size: 16, color: c.computeLuminance() > 0.5 ? AppColors.ink : Colors.white)
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
