import 'dart:math';
import '../../ui/flag.dart';
import '../transfer_screen.dart';
import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../models/club.dart';
import '../../services/game_state.dart';
import '../../ui/face_avatar.dart';
import '../../ui/widgets.dart';
import 'player_attributes_view.dart';
import '../../ui/scout_badge.dart';
import '../compare_screen.dart';
import '../../models/league.dart';
import '../../services/season_calendar.dart';
import '../match_report_screen.dart';
import '../../l10n/l10n.dart';

/// SofaScore-like player page: header card, season numbers, rating form,
/// attributes, positional map and contract actions.
class PlayerDetailView extends StatefulWidget {
  final Player player;
  final Club? club;
  final VoidCallback? onContractRenewed;
  const PlayerDetailView({
    super.key,
    required this.player,
    this.club,
    this.onContractRenewed,
  });
  static Future<void> show(
    BuildContext context, {
    required Player player,
    Club? club,
    VoidCallback? onContractRenewed,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlayerDetailView(
        player: player,
        club: club,
        onContractRenewed: onContractRenewed,
      ),
    ),
  );
  @override
  State<PlayerDetailView> createState() => _PlayerDetailViewState();
}

class _PlayerDetailViewState extends State<PlayerDetailView> {
  Player get p => widget.player;
  Club? get club => widget.club ?? (GameState().isInitialized ? GameState().clubOfPlayer(p) : null);
  bool get owned =>
      GameState().isInitialized && GameState().userClub.squad.any((q) => identical(p, q));
  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(text))));

  @override
  Widget build(BuildContext context) {
    final game = GameState();
    final c = club ?? game.clubOfPlayer(p);
    final shirt = c?.primaryColor ?? AppColors.primary;
    final buyable = c != null && c.id != game.userClubId && game.marketClubs.any((m) => m.id == c.id);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        // The offer button stays in reach on every tab.
        floatingActionButton: buyable
            ? FloatingActionButton.extended(
                onPressed: () => showTransferOffer(context, p, c).then((_) {
                  if (mounted) setState(() {});
                }),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: Text(tr('Taklif yuborish')),
              )
            : null,
        appBar: AppBar(
          title: Text(tr('Futbolchi profili')),
          actions: [
            IconButton(
              tooltip: tr('Solishtirish'),
              icon: const Icon(Icons.compare_arrows_rounded),
              onPressed: () => CompareScreen.show(context, p),
            ),
            if (owned)
              IconButton(
                tooltip: tr('Portretni tahrirlash'),
                icon: const Icon(Icons.face_retouching_natural_outlined),
                onPressed: () async {
                  final face = await editFace(context, p.face, shirt: shirt, nationality: p.nationality, age: p.age);
                  if (face != null && mounted) {
                    setState(() => p.face = face);
                    GameState().touch();
                  }
                },
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(170),
            child: Column(
              children: [
                _header(c, shirt),
                TabBar(
                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  tabs: [
                    Tab(text: tr('Umumiy')),
                    Tab(text: tr('Atributlar')),
                    Tab(text: tr('Pozitsiyalar')),
                    Tab(text: tr('O‘yinlar')),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: PageWidth(
      maxWidth: 960,
      child: TabBarView(
          children: [
            _overview(c),
            if (GameState().isScouted(p)) PlayerAttributesView(player: p) else _scoutPrompt(),
            PositionRatingsView(player: p),
            _matches(),
          ],
        ),
    ),
      ),
    );
  }

  Widget _header(Club? c, Color shirt) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Row(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: FaceAvatar(config: p.face, size: 96, shirt: shirt, trim: c?.secondaryColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.h2),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (c != null) ...[
                    ClubCrestWidget(config: c.crestConfig, size: 18),
                    const SizedBox(width: 6),
                    Flexible(child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small)),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  PositionChip(p.mainPosition.code, fontSize: 11),
                  const SizedBox(width: 6),
                  FlagView(p.countryFlag, nationality: p.nationality, height: 12),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '#${p.number} · ${p.playingStyle.title}',
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
        Column(
          children: [
            ScoutedOvr(p, size: 46),
            const SizedBox(height: 6),
            RatingBadge(p.averageRating, size: 12),
          ],
        ),
      ],
    ),
  );

  Widget _overview(Club? c) {
    final game = GameState();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      children: [
        if (!p.isAvailable)
          AppCard(
            color: const Color(0xFFFFF4F2),
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Icon(Icons.local_hospital_outlined, color: AppColors.live),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.isInjured
                        ? trf('{0} · {1} tur o‘tkazib yuboradi', [tr(p.injury ?? 'Jarohat'), p.injuryRounds])
                        : trf('Diskvalifikatsiya · {0} tur', [p.suspensionRounds]),
                    style: AppText.bodyStrong,
                  ),
                ),
              ],
            ),
          ),
        AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(tr('O‘yin uslubi'), icon: Icons.style_outlined),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      p.playingStyle.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p.playingStyle.uzbek, style: AppText.bodyStrong)),
                ],
              ),
              const SizedBox(height: 8),
              Text(p.playingStyle.description, style: AppText.small.copyWith(height: 1.4)),
              if (p.aiStyles.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in p.aiStyles)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.gold),
                        label: Text('${a.title} · ${a.uzbek}', style: const TextStyle(fontSize: 11.5)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(tr('Ma’lumot'), icon: Icons.badge_outlined),
              Row(
                children: [
                  Expanded(child: StatTile('${p.age}', 'Yosh')),
                  Expanded(child: StatTile(p.preferredFoot == PreferredFoot.left ? tr('Chap') : tr('O‘ng'), 'Oyoq')),
                  Expanded(child: StatTile('${p.weakFoot}/5', 'Kuchsiz oyoq')),
                  Expanded(child: StatTile('${p.potential}', 'Salohiyat', color: AppColors.attribute(p.potential))),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                tr('Salohiyat: futbolchi kelajakda yetishi mumkin bo‘lgan eng yuqori OVR. Yosh futbolchi o‘ynab, mashq qilib shunga yaqinlashadi; keksa futbolchida u hozirgi OVRga teng.'),
                style: AppText.caption,
              ),
              const SizedBox(height: 10),
              MeterRow(
                label: tr('Jismoniy tayyorgarlik'),
                value: p.currentStamina / 100,
                trailing: '${p.currentStamina}%',
                color: p.currentStamina > 75 ? AppColors.win : p.currentStamina > 55 ? AppColors.warning : AppColors.loss,
              ),
              MeterRow(label: tr('Kayfiyat'), value: p.morale / 100, trailing: '${p.morale}%'),
              if (p.altPositions.isNotEmpty)
                InfoRow(tr('Muqobil pozitsiyalar'), p.altPositions.map((e) => e.code).join(', ')),
              InfoRow(tr('Ko‘rsatma'), p.instruction.label),
              Tooltip(message: p.personality.hint, child: InfoRow(tr('Xarakter'), p.personality.label)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(trf('Mavsum {0}', [game.isInitialized ? game.seasonLabel : '']), icon: Icons.query_stats_rounded),
              Row(
                children: [
                  Expanded(child: StatTile('${p.seasonMatches}', tr('O‘yin'))),
                  Expanded(child: StatTile('${p.seasonGoals}', tr('Gol'))),
                  Expanded(child: StatTile('${p.seasonAssists}', 'Assist')),
                  Expanded(child: StatTile('${p.seasonMinutes}′', tr('Daqiqa'))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: p.mainPosition.isGoalkeeper
                        ? StatTile('${p.seasonCleanSheets}', tr('Quruq o‘yin'))
                        : StatTile(p.goalsPerMatch.toStringAsFixed(2), tr('Gol/o‘yin')),
                  ),
                  Expanded(child: StatTile('${p.seasonMotm}', tr('O‘yin qahramoni'))),
                  Expanded(child: StatTile('${p.seasonYellowCards}', 'Sariq')),
                  Expanded(child: StatTile('${p.seasonRedCards}', 'Qizil')),
                ],
              ),
              const Divider(height: 26),
              Row(
                children: [
                  Expanded(child: Text(tr('Oxirgi reytinglar'), style: AppText.small)),
                  if (p.recentRatings.isEmpty) const Text('—', style: AppText.caption),
                  for (final r in p.recentRatings)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: RatingBadge(r, size: 11),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text(tr('O‘rtacha reyting'), style: AppText.small)),
                  RatingBadge(p.averageRating, size: 14),
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
              SectionHeader(tr('Shartnoma va qiymat'), icon: Icons.description_outlined),
              InfoRow(tr('Bozor bahosi'), p.formattedMarketValue),
              InfoRow(tr('Haftalik maosh'), formatMoney(p.contract.weeklyWage)),
              InfoRow(
                tr('Qolgan muddat'),
                trf('{0} yil', [p.contract.contractYears]),
                valueColor: p.contract.contractYears <= 1 ? AppColors.live : null,
              ),
              if (p.contract.releaseClause > 0) InfoRow(tr('Tovon puli'), formatMoney(p.contract.releaseClause)),
              if (owned) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _renew,
                  icon: const Icon(Icons.edit_document),
                  label: Text(tr('Yangi shartnoma taklif qilish')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    final dest = game.loanDestination(p);
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(tr('Ijaraga berish')),
                        content: Text(
                          dest == null
                              ? tr('Mos klub topilmadi.')
                              : trf('{0} mavsum oxirigacha {1} safida o‘ynaydi va yozda rivojlanib qaytadi.', [p.shortName, dest.name]),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Bekor qilish'))),
                          if (dest != null)
                            FilledButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                final error = game.loanOut(p);
                                message(error ?? tr('Ijara kelishildi.'));
                                if (error == null) Navigator.of(context).maybePop();
                              },
                              child: Text(tr('Kelishish')),
                            ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.flight_takeoff_rounded),
                  label: Text(tr('Ijaraga berish')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    game.toggleTransferList(p);
                    setState(() {});
                    message(game.transferListed.contains(p.id)
                        ? tr('Sotuvga qo‘yildi: transfer oynasida klublar taklif yuboradi.')
                        : tr('Sotuv ro‘yxatidan olindi.'));
                  },
                  icon: Icon(game.transferListed.contains(p.id) ? Icons.remove_shopping_cart_outlined : Icons.sell_outlined),
                  label: Text(game.transferListed.contains(p.id) ? tr('Sotuv ro‘yxatidan olish') : tr('Sotuvga qo‘yish')),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _careerTable(c),
        const SizedBox(height: 12),
        _transferTimeline(c),
      ],
    );
  }

  /// Unscouted players: attributes stay hidden until a scout reports.
  Widget _scoutPrompt() {
    final game = GameState();
    final due = game.life.scoutQueue[p.id];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            children: [
              const Icon(Icons.travel_explore_outlined, size: 40, color: AppColors.primary),
              const SizedBox(height: 10),
              Text(tr('Atributlar noma’lum'), style: AppText.h3),
              const SizedBox(height: 6),
              Text(
                due == null
                    ? tr('Futbolchining aniq ko‘rsatkichlarini bilish uchun skaut yuboring.')
                    : trf('Skaut kuzatmoqda: hisobot {0} kuni tayyor bo‘ladi.', [GameState().roundDate(due)]),
                textAlign: TextAlign.center,
                style: AppText.small,
              ),
              const SizedBox(height: 12),
              if (due == null)
                FilledButton.icon(
                  onPressed: () {
                    final error = game.scoutPlayer(p);
                    setState(() {});
                    message(error ?? tr('Skaut yuborildi.'));
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: Text(tr('Skaut yuborish')),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _crest(String? clubId, String name, {double size = 26}) {
    final club = clubId == null || clubId.isEmpty ? null : GameState().getClubById(clubId);
    if (club != null) return ClubCrestWidget(config: club.crestConfig, size: size);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.surfaceAlt,
      child: Text(name.isEmpty || name == '-' ? '?' : name.characters.first, style: AppText.caption),
    );
  }

  /// SofaScore-style season table: club, apps, goals, assists, rating.
  Widget _careerTable(Club? c) {
    final rows = <List<String>>[
      if (c != null)
        [
          GameState().seasonLabel,
          c.id,
          c.name,
          '${p.seasonMatches}',
          '${p.seasonGoals}',
          '${p.seasonAssists}',
          p.averageRating?.toStringAsFixed(2) ?? '',
        ],
      for (final line in p.careerSeasons) line.split('|'),
    ];
    Widget head(String t) => SizedBox(width: 40, child: Text(t, textAlign: TextAlign.center, style: AppText.overline.copyWith(fontSize: 10)));
    Widget cell(String t) => SizedBox(width: 40, child: Text(t, textAlign: TextAlign.center, style: AppText.small.copyWith(color: AppColors.ink)));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(tr('Karyera'), icon: Icons.history_rounded),
          Row(
            children: [
              const SizedBox(width: 64),
              const Expanded(child: SizedBox()),
              head(tr('O')),
              head(tr('Gol')),
              head(tr('As')),
              head(tr('Reyt.')),
            ],
          ),
          const Divider(height: 12),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(width: 64, child: Text(r[0], style: AppText.caption)),
                  _crest(r[1], r[2]),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r[2], maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small.copyWith(color: AppColors.ink))),
                  cell(r[3]),
                  cell(r[4]),
                  cell(r[5]),
                  SizedBox(
                    width: 40,
                    child: r[6].isEmpty ? cell('–') : Center(child: RatingBadge(double.tryParse(r[6]), size: 11)),
                  ),
                ],
              ),
            ),
          if (p.careerSeasons.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(tr('Oldingi mavsumlar karyera davomida shu yerga yoziladi.'), style: AppText.caption),
            ),
        ],
      ),
    );
  }

  /// Transfers like SofaScore: from-club → to-club with crests, season and fee.
  Widget _transferTimeline(Club? c) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(tr('Transferlar tarixi'), icon: Icons.swap_horiz_rounded),
        if (p.transfers.isEmpty)
          Row(
            children: [
              if (c != null) _crest(c.id, c.name, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  trf('{0} · karyera davomida hali transfer bo‘lmagan.', [c?.name ?? tr('Erkin agent')]),
                  style: AppText.small,
                ),
              ),
            ],
          )
        else
          for (final t in p.transfers)
            Builder(
              builder: (context) {
                final f = t.split('|');
                final fee = int.tryParse(f.length > 3 ? f[3] : '') ?? 0;
                final fromId = f.length > 4 ? f[4] : null, toId = f.length > 5 ? f[5] : null;
                final from = f[1] == '-' ? tr('Erkin agent') : f[1];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(width: 64, child: Text(f[0], style: AppText.caption)),
                      _crest(fromId, from),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.ink3),
                      ),
                      _crest(toId, f[2]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$from → ${f[2]}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.small.copyWith(color: AppColors.ink),
                        ),
                      ),
                      Text(fee == 0 ? tr('Bepul') : formatMoney(fee), style: AppText.bodyStrong),
                    ],
                  ),
                );
              },
            ),
      ],
    ),
  );

  /// Every fixture this season in which the player took the field.
  Widget _matches() {
    final game = GameState();
    if (!game.isInitialized) return const SizedBox();
    final games = game.fixtures
        .where((f) => f.isPlayed && (f.playerStats[p.id]?.minutes ?? 0) > 0)
        .toList()
        .reversed
        .toList();
    if (games.isEmpty) {
      return EmptyState(icon: Icons.event_busy_outlined, text: tr('Bu mavsumda hali maydonga tushmagan'));
    }
    var goals = 0, assists = 0, minutes = 0;
    for (final f in games) {
      final l = f.playerStats[p.id]!;
      goals += l.goals;
      assists += l.assists;
      minutes += l.minutes.round();
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        AppCard(
          child: Row(
            children: [
              Expanded(child: StatTile('${games.length}', tr('O‘yin'))),
              Expanded(child: StatTile('$goals', tr('Gol'))),
              Expanded(child: StatTile('$assists', 'Assist')),
              Expanded(child: StatTile('$minutes′', tr('Daqiqa'))),
              RatingBadge(p.averageRating, size: 14),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [for (final f in games) _matchRow(game, f)]),
        ),
      ],
    );
  }

  Widget _matchRow(GameState game, Fixture f) {
    final l = f.playerStats[p.id]!;
    // Line-ups record the side he played for, even after a later transfer.
    final inLineups = f.homeLineup.isNotEmpty || f.awayLineup.isNotEmpty;
    final playedHome = inLineups
        ? f.homeLineup.contains(p.id) || f.homeBench.contains(p.id)
        : game.getClubById(f.homeClubId)!.playerById(p.id) != null;
    final mine = playedHome ? f.homeClubId : f.awayClubId;
    final home = mine == f.homeClubId;
    final opp = game.getClubById(home ? f.awayClubId : f.homeClubId)!;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => MatchReportScreen(fixture: f)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Text(f.date == null ? trf('{0}-tur', [f.round]) : SeasonCalendar.short(f.date!), style: AppText.caption),
                  Text(home ? tr('Uyda') : tr('Safarda'), style: AppText.caption.copyWith(fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            ClubCrestWidget(config: opp.crestConfig, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(opp.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong.copyWith(fontSize: 13)),
                  Row(
                    children: [
                      Text('${min(90, l.minutes.round())}′', style: AppText.caption),
                      if (l.subOnMinute != null || l.subOffMinute != null) ...[
                        const SizedBox(width: 6),
                        _subMark(l),
                      ],
                      for (var i = 0; i < l.goals; i++)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.sports_soccer, size: 13, color: AppColors.ink),
                        ),
                      if (l.assists > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text('${l.assists} A', style: AppText.caption.copyWith(fontWeight: FontWeight.w700)),
                        ),
                      if (l.yellow > 0)
                        Container(
                          width: 8,
                          height: 11,
                          margin: const EdgeInsets.only(left: 6),
                          color: const Color(0xFFF5C518),
                        ),
                      if (l.red > 0)
                        Container(width: 8, height: 11, margin: const EdgeInsets.only(left: 4), color: AppColors.live),
                    ],
                  ),
                ],
              ),
            ),
            Text('${f.homeScore}–${f.awayScore}', style: AppText.number.copyWith(fontSize: 13)),
            const SizedBox(width: 6),
            FormChip(f.resultFor(mine), size: 20),
            const SizedBox(width: 6),
            RatingBadge(f.ratings[p.id], size: 12),
          ],
        ),
      ),
    );
  }

  Widget _subMark(PlayerMatchStats l) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (l.subOnMinute != null) const Icon(Icons.arrow_upward_rounded, size: 12, color: AppColors.win),
      if (l.subOffMinute != null) const Icon(Icons.arrow_downward_rounded, size: 12, color: AppColors.live),
    ],
  );

  /// Contract talks: the manager offers a wage and length; the player
  /// accepts, counters or refuses according to his demand and character.
  void _renew() {
    final game = GameState();
    final demand = game.renewalDemand(p);
    var years = 3;
    var wage = demand.toDouble();
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(tr('Shartnoma taklifi')),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trf('Agent mo‘ljali: taxminan €{0}K / hafta', [(demand / 1000).toStringAsFixed(0)]), style: AppText.small),
                Text(trf('Xarakter: {0}', [p.personality.label]), style: AppText.caption),
                const SizedBox(height: 12),
                Text(trf('Taklif: {0} / hafta', [formatMoney(wage.round())]), style: AppText.bodyStrong),
                Slider(
                  value: wage,
                  min: demand * 0.6,
                  max: demand * 1.5,
                  divisions: 36,
                  onChanged: (v) => update(() => wage = (v / 1000).round() * 1000.0),
                ),
                Text(tr('Yangi umumiy muddat'), style: AppText.small),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final y in [1, 2, 3, 4, 5])
                      ChoiceChip(
                        label: Text(trf('{0} yil', [y])),
                        selected: years == y,
                        onSelected: (_) => update(() => years = y),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  trf('Bo‘sh maosh limiti: {0}/hafta', [formatMoney(game.userClub.remainingWageBudget + p.contract.weeklyWage)]),
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Bekor qilish'))),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _answer(game.proposeRenewal(p, years, wage.round()));
              },
              child: Text(tr('Taklif qilish')),
            ),
          ],
        ),
      ),
    );
  }

  void _answer(({String status, int wage, int years, String message}) reply) {
    final game = GameState();
    setState(() {});
    widget.onContractRenewed?.call();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          switch (reply.status) {
            'accepted' => Icons.handshake_outlined,
            'counter' => Icons.forum_outlined,
            _ => Icons.block,
          },
          color: switch (reply.status) {
            'accepted' => AppColors.win,
            'counter' => AppColors.warning,
            _ => AppColors.live,
          },
        ),
        title: Text(p.name),
        content: Text('“${reply.message}”'),
        actions: [
          if (reply.status == 'counter') ...[
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Rad etish'))),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _answer(game.proposeRenewal(p, reply.years, reply.wage));
              },
              child: Text(tr('Qabul qilish')),
            ),
          ] else
            FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Yopish'))),
        ],
      ),
    );
  }
}
