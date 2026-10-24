import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../models/club.dart';
import '../../services/game_state.dart';
import '../../ui/face_avatar.dart';
import '../../ui/widgets.dart';
import 'player_attributes_view.dart';
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
    final c = club;
    final shirt = c?.primaryColor ?? AppColors.primary;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Futbolchi profili')),
          actions: [
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
        body: TabBarView(
          children: [
            _overview(c),
            PlayerAttributesView(player: p),
            PositionRatingsView(player: p),
            _matches(),
          ],
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
                  Flexible(
                    child: Text(
                      '${p.countryFlag} #${p.number} · ${p.playingStyle.title}',
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
            ValueBadge(p.ovr, size: 46),
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
      padding: const EdgeInsets.all(12),
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
                        ? trf('{0} · {1} tur o‘tkazib yuboradi', [p.injury ?? 'Jarohat', p.injuryRounds])
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
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 16, color: AppColors.ink3),
                  const SizedBox(width: 8),
                  Text(tr('Himoyada:'), style: AppText.small),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${p.defendingStyle.title} (${p.defendingStyle.uzbek})',
                      style: AppText.bodyStrong.copyWith(fontSize: 13),
                    ),
                  ),
                ],
              ),
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
                  Expanded(child: StatTile(p.preferredFoot == PreferredFoot.left ? 'Chap' : 'O‘ng', 'Oyoq')),
                  Expanded(child: StatTile('${p.weakFoot}/5', 'Kuchsiz oyoq')),
                  Expanded(child: StatTile('${p.potential}', 'Salohiyat', color: AppColors.attribute(p.potential))),
                ],
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
                '${p.contract.contractYears} yil',
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
                    final ok = game.sellPlayer(p);
                    message(ok ? trf('{0} sotildi', [p.name]) : game.lastTransferError ?? tr('Sotilmadi'));
                    if (ok) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.sell_outlined),
                  label: Text(tr('Xaridor topish va sotish')),
                ),
              ],
            ],
          ),
        ),
        if (p.history.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(tr('Karyera'), icon: Icons.history_rounded),
                for (final h in p.history)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Text(h, style: AppText.small),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

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

  void _renew() {
    final game = GameState();
    final wage = p.calculatedRenewalWageDemand;
    var years = 3;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(tr('Shartnoma taklifi')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trf('Talab: €{0}K / hafta', [(wage / 1000).toStringAsFixed(0)]), style: AppText.bodyStrong),
              const SizedBox(height: 12),
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
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Bekor qilish'))),
            FilledButton(
              onPressed: () {
                final ok = game.renewContract(p, years, wage);
                Navigator.pop(ctx);
                setState(() {});
                widget.onContractRenewed?.call();
                message(ok ? tr('Shartnoma imzolandi') : tr('Maosh limiti yetarli emas'));
              },
              child: Text(tr('Imzolash')),
            ),
          ],
        ),
      ),
    );
  }
}
