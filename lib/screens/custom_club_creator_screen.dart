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
import '../l10n/l10n.dart';
import '../ui/league_picker.dart';
import '../services/coin_wallet.dart';
import '../ui/coin.dart';

/// Foydalanuvchi o'z jamoasini noldan yaratish ekrani
class CustomClubCreatorScreen extends StatefulWidget {
  final ManagerProfile? managerProfile;
  final String league;
  const CustomClubCreatorScreen({super.key, this.managerProfile, this.league = 'super'});
  @override
  State<CustomClubCreatorScreen> createState() => _CustomClubCreatorScreenState();
}

class _CustomClubCreatorScreenState extends State<CustomClubCreatorScreen> {
  final _nameController = TextEditingController(text: tr('Toshkent Stars'));
  final _shortNameController = TextEditingController(text: 'TKS');
  final _stadiumController = TextEditingController(text: tr('Milliy Arena'));
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
    if (!CoinWallet().canAfford(CoinWallet.customClubCost)) {
      showCoinInfo(context);
      return;
    }
    final name = _nameController.text.trim();
    final shortName = _shortNameController.text.trim();
    final stadium = _stadiumController.text.trim();
    if (name.isEmpty || shortName.isEmpty || stadium.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Iltimos, barcha maydonlarni to\'ldiring!'))),
      );
      return;
    }
    CoinWallet().spend(CoinWallet.customClubCost);
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

  /// League choice first: the new club takes the place of that league's
  /// weakest side.
  Widget _leagueCard() {
    final clubs = InitialDatabase.getClubs(_league)..sort((a, b) => a.reputation.compareTo(b.reputation));
    final rounds = (clubs.length - 1) * 2;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(tr('Qaysi ligada o‘ynaysiz?'), icon: Icons.emoji_events_outlined),
          LeaguePicker(selected: _league, onChanged: (id) => setState(() => _league = id)),
          const SizedBox(height: 10),
          Text(
            trf('Klubingiz {0} o‘rnini egallaydi · {1} tur.', [clubs.first.name, rounds]),
            style: AppText.small,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('Yangi Jamoa Yaratish'))),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _leagueCard(),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: [
              ClubCrestWidget(config: _crest, size: 124),
              const SizedBox(height: 12),
              Text(_nameController.text.isEmpty ? tr('Klub nomi') : _nameController.text, style: AppText.h2),
              const SizedBox(height: 2),
              Text('${_shortNameController.text.toUpperCase()} · ${_stadiumController.text}', style: AppText.caption),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _randomLogo,
                icon: const Icon(Icons.casino_outlined),
                label: Text(tr('Tasodifiy logo yaratish')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(tr('1. Jamoa Ma\'lumotlari')),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: tr('Klub nomi'), prefixIcon: Icon(Icons.shield_outlined)),
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
                      decoration: InputDecoration(labelText: tr('Qisqartma'), counterText: '', prefixIcon: Icon(Icons.tag_rounded)),
                      onChanged: (val) => setState(() => _monogram = val.toUpperCase()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _stadiumController,
                      decoration: InputDecoration(labelText: tr('Stadion'), prefixIcon: Icon(Icons.stadium_outlined)),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(trf('Stadion sig‘imi: {0} 000 muxlis', [(_stadiumCapacity / 1000).toStringAsFixed(0)]), style: AppText.small),
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
              SectionHeader(tr('2. Emblem Shakli')),
              _previewGrid<CrestShape>(
                CrestShape.values,
                _shape,
                (v) => _crest.copyWith(shape: v),
                (v) => v.label,
                (v) => setState(() => _shape = v),
              ),
              const SizedBox(height: 16),
              SectionHeader(tr('3. Naqsh')),
              _previewGrid<CrestPattern>(
                CrestPattern.values,
                _pattern,
                (v) => _crest.copyWith(pattern: v),
                (v) => v.label,
                (v) => setState(() => _pattern = v),
              ),
              const SizedBox(height: 16),
              SectionHeader(tr('4. Belgi va bezak')),
              _previewGrid<CrestEmblem>(
                CrestEmblem.values,
                _emblem,
                (v) => _crest.copyWith(emblem: v),
                (v) => v.label,
                (v) => setState(() => _emblem = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Toj')),
                value: _crown,
                onChanged: (v) => setState(() => _crown = v),
              ),
              Row(
                children: [
                  Text(tr('Yulduzlar'), style: AppText.bodyStrong),
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
              SectionHeader(tr('5. Klub ranglari')),
              _colorRow(tr('Asosiy rang'), _primary, (c) => setState(() => _primary = c)),
              _colorRow(tr('Ikkilamchi rang'), _secondary, (c) => setState(() => _secondary = c)),
              _colorRow(tr('Hoshiya rangi'), _trim, (c) => setState(() => _trim = c)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                tr('6. Yulduz futbolchi'),
                action: tr('Boshqa variantlar'),
                onAction: () => setState(() {
                  _candidates = GameState.starCandidates();
                  _star = 0;
                }),
              ),
              Text(
                tr('Tarkib o‘rtacha darajada (64–73). Bitta yulduzni o‘zingiz tanlaysiz.'),
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
                                        trf('{0} yosh · {1}', [_candidates[i].age, _candidates[i].playingStyle.title]),
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
        AppCard(
          color: AppColors.primarySoft,
          child: Row(
            children: [
              Icon(Icons.stars_rounded, color: AppColors.primary, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('Klub yaratilgach, 23 kishilik o‘rtacha tarkib, tanlangan yulduz, €80.0M transfer byudjeti va akademiya ajratiladi.'),
                  style: AppText.small,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: ValueListenableBuilder<int>(
            valueListenable: CoinWallet().balance,
            builder: (context, coins, _) {
              final ok = coins >= CoinWallet.customClubCost;
              return FilledButton(
                onPressed: _createAndStart,
                style: ok ? null : FilledButton.styleFrom(backgroundColor: AppColors.ink3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(child: Text(ok ? tr('KLUBNI YARATISH VA BOSHLASH') : tr('TANGA YETARLI EMAS'))),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.fromLTRB(3, 3, 9, 3),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: const CoinAmount(CoinWallet.customClubCost, size: 18),
                    ),
                  ],
                ),
              );
            },
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
        Text(tr(title), style: AppText.small),
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
