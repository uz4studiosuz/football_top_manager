import 'package:flutter/material.dart';
import '../models/player.dart';
import '../data/countries.dart';
import '../data/initial_database.dart';
import '../services/club_life.dart';
import '../services/world.dart';
import '../services/game_state.dart';
import '../ui/face_avatar.dart';
import '../ui/flag.dart';
import '../ui/widgets.dart';
import '../l10n/l10n.dart';
import 'widgets/player_detail_view.dart';

/// Running the club: facilities, training, academy, fans and history.
class ClubLifeScreen extends StatelessWidget {
  final int initialTab;
  const ClubLifeScreen({super.key, this.initialTab = 0});

  static Future<void> show(BuildContext context, [int tab = 0]) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => ClubLifeScreen(initialTab: tab)),
  );

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 8,
    initialIndex: initialTab,
    child: Scaffold(
      appBar: AppBar(
        title: Text(tr('Klub boshqaruvi')),
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: tr('Inshootlar')),
            Tab(text: tr('Mashg‘ulot')),
            Tab(text: tr('Akademiya')),
            Tab(text: tr('Muxlislar')),
            Tab(text: tr('Shon-sharaf')),
            Tab(text: tr('Kiyinish xonasi')),
            Tab(text: tr('Shtab')),
            Tab(text: tr('Skautlar')),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: GameState(),
        builder: (context, _) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            // Fresh tab widgets on every change so each tab redraws.
            child: TabBarView(
              children: [
                // ignore: prefer_const_constructors
                _Facilities(),
                // ignore: prefer_const_constructors
                _Training(),
                // ignore: prefer_const_constructors
                _Academy(),
                // ignore: prefer_const_constructors
                _Fans(),
                // ignore: prefer_const_constructors
                _HallOfFame(),
                // ignore: prefer_const_constructors
                _DressingRoom(),
                // ignore: prefer_const_constructors
                _Staff(),
                // ignore: prefer_const_constructors
                _Scouts(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Facilities extends StatelessWidget {
  const _Facilities();
  @override
  Widget build(BuildContext context) {
    final game = GameState(), life = game.life, club = game.userClub;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        AppCard(
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('Transfer byudjeti'), style: AppText.bodyStrong)),
              Text(club.formattedTransferBudget, style: AppText.h3),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _sponsorCard(context, game),
        const SizedBox(height: 10),
        for (final f in Facility.values) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(f.icon, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(f.label, style: AppText.h3)),
                    for (var i = 0; i < Facility.maxLevel; i++)
                      Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: Icon(
                          i < life.level(f) ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 18,
                          color: AppColors.gold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(f.effect, style: AppText.small),
                if (f == Facility.stadium)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(trf('Hozirgi sig‘im: {0}', [club.stadiumCapacity]), style: AppText.caption),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        life.building.containsKey(f)
                            ? trf('Qurilmoqda · {0}-turda tayyor', [life.building[f]])
                            : life.level(f) >= Facility.maxLevel
                            ? tr('Eng yuqori daraja')
                            : trf('Keyingi bosqich: {0}', [formatMoney(game.facilityCost(f))]),
                        style: AppText.caption.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: life.building.containsKey(f) || life.level(f) >= Facility.maxLevel
                          ? null
                          : () {
                              final error = game.upgradeFacility(f);
                              if (error != null) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                              }
                            },
                      child: Text(tr('Yangilash')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Sponsor deal: three offers each season, one signed until the summer.
Widget _sponsorCard(BuildContext context, GameState game) {
  final life = game.life, deal = life.sponsor;
  String terms(Map<String, dynamic> o) => switch (o['type']) {
    'fixed' => trf('Har turda {0}', [formatMoney(o['perRound'] as int)]),
    'wins' => trf('Har turda {0} + har g‘alabaga {1}', [formatMoney(o['perRound'] as int), formatMoney(o['bonus'] as int)]),
    _ => trf('Har turda {0} + kengash maqsadi bajarilsa {1} (chempionlikda ×2)', [formatMoney(o['perRound'] as int), formatMoney(o['bonus'] as int)]),
  };
  return AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(tr('Homiylar'), icon: Icons.handshake_outlined),
        if (deal != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.verified_outlined, color: AppColors.win),
            title: Text('${deal['name']}', style: AppText.bodyStrong),
            subtitle: Text(terms(deal), style: AppText.caption),
          )
        else if (life.sponsorOffers.isEmpty)
          Text(tr('Yangi takliflar keyingi mavsum boshida keladi.'), style: AppText.small)
        else
          for (final o in life.sponsorOffers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${o['name']}', style: AppText.bodyStrong),
              subtitle: Text(terms(o), style: AppText.caption),
              trailing: FilledButton.tonal(onPressed: () => game.signSponsor(o), child: Text(tr('Imzolash'))),
            ),
      ],
    ),
  );
}

class _Training extends StatelessWidget {
  const _Training();

  static String _targetLabel(String? t) {
    if (t == null) return tr('Jamoa rejasi');
    if (t.startsWith('style:')) {
      final s = PlayingStyle.values.asNameMap()[t.substring(6)];
      return trf('Uslub: {0}', [s?.title ?? '?']);
    }
    return PlayerStats.labels[t] ?? t;
  }

  Future<void> _pick(BuildContext context, Player p) async {
    final game = GameState();
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.7,
          child: ListView(
            children: [
              ListTile(title: Text(p.name, style: AppText.h3), subtitle: Text(tr('Individual mashg‘ulot'))),
              ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: Text(tr('Jamoa rejasi bo‘yicha')),
                onTap: () => Navigator.pop(ctx, ''),
              ),
              const Divider(),
              Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 4), child: Text(tr('Atributni oshirish'), style: AppText.bodyStrong)),
              for (final e in PlayerStats.labels.entries)
                if (e.key.startsWith('gk') == p.mainPosition.isGoalkeeper)
                  ListTile(
                    dense: true,
                    title: Text(e.value),
                    trailing: ValueBadge(p.stats.toMap()[e.key] as int, size: 26),
                    onTap: () => Navigator.pop(ctx, e.key),
                  ),
              const Divider(),
              Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 4), child: Text(tr('Yangi uslub o‘rgatish'), style: AppText.bodyStrong)),
              for (final s in PlayingStyle.values)
                if (s != p.playingStyle && s.name.contains('Goalkeeper') == p.mainPosition.isGoalkeeper)
                  ListTile(dense: true, title: Text(s.title), subtitle: Text(s.description), onTap: () => Navigator.pop(ctx, 'style:${s.name}')),
            ],
          ),
        ),
      ),
    );
    if (choice != null) game.setTrainingTarget(p, choice.isEmpty ? null : choice);
  }

  @override
  Widget build(BuildContext context) {
    final game = GameState(), life = game.life;
    final squad = List.of(game.userClub.squad)..sort((a, b) => a.mainPosition.index.compareTo(b.mainPosition.index));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionHeader(tr('Jamoaviy mashg‘ulot'), icon: Icons.fitness_center_outlined),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: RadioGroup<TrainingFocus>(
            groupValue: life.focus,
            onChanged: (v) => game.setTrainingFocus(v!),
            child: Column(
              children: [
                for (final f in TrainingFocus.values)
                  RadioListTile<TrainingFocus>(
                    value: f,
                    secondary: Icon(f.icon),
                    title: Text(f.label, style: AppText.bodyStrong),
                    subtitle: Text(f.effect, style: AppText.caption),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SectionHeader(trf('Jamoa rejasi: atributlar ({0}/3)', [life.teamAttributes.length]), icon: Icons.checklist_rounded),
        Text(
          life.teamAttributes.isEmpty
              ? trf('Tanlanmagan: yo‘nalish bo‘yicha avtomatik – {0}.', [game.teamTrainingAttributes.map((k) => tr(PlayerStats.labels[k] ?? k)).join(', ')])
              : tr('Butun jamoa shu atributlar ustida ishlaydi.'),
          style: AppText.caption,
        ),
        const SizedBox(height: 6),
        AppCard(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final k in PlayerStats.labels.keys.where((k) => !k.startsWith('gk')))
                FilterChip(
                  label: Text(tr(PlayerStats.labels[k]!), style: const TextStyle(fontSize: 12)),
                  selected: life.teamAttributes.contains(k),
                  onSelected: life.teamAttributes.contains(k) || life.teamAttributes.length < 3
                      ? (_) => game.toggleTeamAttribute(k)
                      : null,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionHeader(tr('Individual mashg‘ulot'), icon: Icons.person_outline),
        Text(
          trf('Yoshlar tezroq o‘sadi. Mashg‘ulot bazasi: {0}-daraja.', [life.level(Facility.training)]),
          style: AppText.caption,
        ),
        const SizedBox(height: 6),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final p in squad)
                ListTile(
                  leading: FaceAvatar(config: p.face, size: 36, shirt: game.userClub.primaryColor, circle: true),
                  title: Text(p.name, style: AppText.bodyStrong.copyWith(fontSize: 13)),
                  subtitle: Row(
                    children: [
                      PositionChip(p.mainPosition.code),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${p.age} · ${_targetLabel(life.targets[p.id])}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption,
                        ),
                      ),
                    ],
                  ),
                  trailing: life.targets.containsKey(p.id)
                      ? SizedBox(
                          width: 46,
                          child: LinearProgressIndicator(
                            value: ((life.progress[p.id] ?? 0) / (life.targets[p.id]!.startsWith('style:') ? 4 : 1)).clamp(0.0, 1.0),
                          ),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pick(context, p),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Academy extends StatelessWidget {
  const _Academy();
  @override
  Widget build(BuildContext context) {
    final game = GameState(), club = game.userClub, life = game.life;
    final youngsters = club.squad.where((p) => p.age <= 19).toList()..sort((a, b) => b.potential.compareTo(a.potential));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        AppCard(
          child: Row(
            children: [
              const Icon(Icons.school_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  trf('Akademiya {0}-daraja. Har yozda 2–4 yosh futbolchi chiqadi; ⭐ – “Oltin avlod” (salohiyat 85–92).', [life.level(Facility.academy)]),
                  style: AppText.small,
                ),
              ),
            ],
          ),
        ),
        if (life.loans.isNotEmpty) ...[
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(tr('Ijaradagi futbolchilar'), icon: Icons.flight_takeoff_rounded),
                for (final e in life.loans.entries)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(game.findPlayerById(e.key)?.name ?? e.key),
                    subtitle: Text(game.marketClubs.where((c) => c.id == e.value).firstOrNull?.name ?? e.value, style: AppText.caption),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (youngsters.isEmpty)
          EmptyState(icon: Icons.child_care_outlined, text: tr('Hozircha yosh futbolchilar yo‘q. Yangi avlod yozda chiqadi.'))
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final p in youngsters)
                  ListTile(
                    leading: FaceAvatar(config: p.face, size: 38, shirt: club.primaryColor, circle: true),
                    title: Row(
                      children: [
                        if (p.potential >= 85) const Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
                        Flexible(child: Text(p.name, style: AppText.bodyStrong.copyWith(fontSize: 13))),
                        if (life.lastIntake.contains(p.id))
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(tr('yangi'), style: AppText.caption.copyWith(color: AppColors.win, fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                    subtitle: Text(trf('{0} yosh · {1}', [p.age, p.mainPosition.code]), style: AppText.caption),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValueBadge(p.ovr, size: 28),
                        const Icon(Icons.arrow_right_alt, color: AppColors.ink3),
                        ValueBadge(p.potential, size: 28, filled: false),
                      ],
                    ),
                    onTap: () => PlayerDetailView.show(context, player: p, club: club),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Fans extends StatelessWidget {
  const _Fans();
  @override
  Widget build(BuildContext context) {
    final game = GameState(), feed = game.life.feed, club = game.userClub;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        AppCard(
          child: Row(
            children: [
              const Icon(Icons.favorite_outline, color: AppColors.live),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('Muxlislar kayfiyati'), style: AppText.bodyStrong)),
              Text('${club.fanMood}%', style: AppText.h3),
            ],
          ),
        ),
        if (game.life.trending.isNotEmpty) ...[
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(tr('Trendda'), icon: Icons.trending_up_rounded),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (tag, n) in game.life.trending.take(6))
                      Chip(
                        label: Text('$tag · $n'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: tag.endsWith('Out') ? AppColors.live.withValues(alpha: 0.1) : AppColors.primarySoft,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (feed.isEmpty)
          EmptyState(icon: Icons.forum_outlined, text: tr('Muxlislar birinchi o‘yinni kutmoqda.'))
        else
          for (final p in feed) FanPostTile(post: p),
      ],
    );
  }
}

/// One fan post (Twitter-style).
class FanPostTile extends StatelessWidget {
  final FanPost post;
  const FanPostTile({super.key, required this.post});
  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (post.kind) {
      PostKind.journalist => (Icons.newspaper_rounded, AppColors.primary),
      PostKind.player => (Icons.sports_soccer, AppColors.gold),
      PostKind.club => (Icons.shield_outlined, AppColors.primary),
      PostKind.rivalFan => (Icons.sports_kabaddi_outlined, AppColors.ink3),
      PostKind.fan => post.positive ? (Icons.sentiment_satisfied_alt, AppColors.win) : (Icons.sentiment_dissatisfied, AppColors.live),
    };
    final verified = post.kind == PostKind.journalist || post.kind == PostKind.player || post.kind == PostKind.club;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(post.author, style: AppText.bodyStrong.copyWith(fontSize: 13))),
                      if (verified) ...[
                        const SizedBox(width: 3),
                        const Icon(Icons.verified_rounded, size: 14, color: AppColors.primary),
                      ],
                      if (post.kind == PostKind.rivalFan) ...[
                        const SizedBox(width: 6),
                        Text(tr('raqib muxlisi'), style: AppText.caption.copyWith(color: AppColors.live)),
                      ],
                      const SizedBox(width: 6),
                      Flexible(child: Text(post.when, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(post.text, style: AppText.body),
                  if (post.tag != null && !post.text.contains(post.tag!))
                    Text(post.tag!, style: AppText.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.favorite_border, size: 14, color: AppColors.ink3),
                      const SizedBox(width: 4),
                      Text('${post.likes}', style: AppText.caption),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HallOfFame extends StatelessWidget {
  const _HallOfFame();
  @override
  Widget build(BuildContext context) {
    final game = GameState(), life = game.life;
    final scorers = life.allTimeScorers.values.toList()..sort((a, b) => b.$2.compareTo(a.$2));
    Widget row(String label, String value) => InfoRow(label, value.isEmpty ? '—' : value);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionHeader(tr('Kuboklar xonasi'), icon: Icons.emoji_events_outlined),
        AppCard(
          child: life.trophies.isEmpty
              ? Text(tr('Hali kubok yo‘q. Birinchisini yutib oling!'), style: AppText.small)
              : Column(
                  children: [
                    for (final t in life.trophies)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.emoji_events, color: AppColors.gold),
                        title: Text(t, style: AppText.bodyStrong),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        SectionHeader(tr('Menejer rekordlari'), icon: Icons.insights_outlined),
        AppCard(
          child: Column(
            children: [
              row(tr('G‘alaba / durang / mag‘lubiyat'), '${life.wins} / ${life.draws} / ${life.losses}'),
              row(
                tr('G‘alabalar foizi'),
                life.wins + life.draws + life.losses == 0 ? '' : '${(life.wins * 100 / (life.wins + life.draws + life.losses)).round()}%',
              ),
              row(tr('Eng uzun g‘alaba seriyasi'), life.bestWinStreak == 0 ? '' : '${life.bestWinStreak}'),
              row(tr('Eng uzun mag‘lubiyatsiz seriya'), life.bestUnbeaten == 0 ? '' : '${life.bestUnbeaten}'),
              row(tr('Eng ko‘p ochko (mavsum)'), life.bestPoints == 0 ? '' : '${life.bestPoints} · ${life.bestPointsSeason}'),
              row(tr('Eng yaxshi o‘rin'), life.bestFinish == 0 ? '' : trf('{0}-o‘rin · {1}', [life.bestFinish, life.bestFinishSeason])),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionHeader(tr('Klub rekordlari'), icon: Icons.military_tech_outlined),
        AppCard(
          child: Column(
            children: [
              row(tr('Eng yirik g‘alaba'), life.biggestWin),
              row(tr('Mavsumdagi eng ko‘p gol'), life.bestSeasonGoals == 0 ? '' : '${life.bestSeasonScorer} · ${life.bestSeasonGoals}'),
              row(tr('Barcha davrlar to‘purari'), scorers.isEmpty ? '' : '${scorers.first.$1} · ${scorers.first.$2}'),
            ],
          ),
        ),
        if (scorers.length > 1) ...[
          const SizedBox(height: 12),
          SectionHeader(tr('To‘purarlar (klub tarixida)'), icon: Icons.sports_soccer),
          AppCard(
            child: Column(
              children: [for (final (i, s) in scorers.take(10).indexed) row('${i + 1}. ${s.$1}', '${s.$2}')],
            ),
          ),
        ],
        const SizedBox(height: 12),
        SectionHeader(tr('Mavsum mukofotlari'), icon: Icons.workspace_premium_outlined),
        if (life.awards.isEmpty)
          Text(tr('Mukofotlar mavsum oxirida topshiriladi: Oltin to‘p, Oltin butsa, eng yaxshi yosh futbolchi va ramziy jamoa.'), style: AppText.small)
        else
          for (final a in life.awards)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.season, style: AppText.h3),
                    const SizedBox(height: 6),
                    row(tr('Oltin to‘p'), a.ballonDor),
                    row(tr('Oltin butsa'), a.goldenBoot),
                    row(tr('Eng yaxshi yosh'), a.youngPlayer),
                    const SizedBox(height: 8),
                    Text(tr('Mavsum ramziy jamoasi'), style: AppText.bodyStrong),
                    const SizedBox(height: 4),
                    for (final line in a.teamOfSeason) Text(line, style: AppText.small),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

/// Mood of every player: character, playing time, transfer requests.
class _DressingRoom extends StatelessWidget {
  const _DressingRoom();
  @override
  Widget build(BuildContext context) {
    final game = GameState(), life = game.life, club = game.userClub;
    final squad = List.of(club.squad)..sort((a, b) => a.morale.compareTo(b.morale));
    final avg = squad.isEmpty ? 0 : squad.map((p) => p.morale).reduce((a, b) => a + b) ~/ squad.length;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        AppCard(
          child: Row(
            children: [
              Icon(avg >= 70 ? Icons.sentiment_satisfied_alt : Icons.sentiment_neutral, color: avg >= 70 ? AppColors.win : AppColors.warning),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('Jamoa kayfiyati'), style: AppText.bodyStrong)),
              Text('$avg%', style: AppText.h3),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final p in squad)
                ListTile(
                  leading: FaceAvatar(config: p.face, size: 38, shirt: club.primaryColor, circle: true),
                  title: Row(
                    children: [
                      if (life.wantsOut.contains(p.id)) const Icon(Icons.logout_rounded, size: 16, color: AppColors.live),
                      Flexible(child: Text(p.name, style: AppText.bodyStrong.copyWith(fontSize: 13))),
                    ],
                  ),
                  subtitle: Text(
                    [
                      p.personality.label,
                      if ((life.benchRounds[p.id] ?? 0) >= 2) trf('{0} o‘yin o‘ynamadi', [life.benchRounds[p.id]]),
                      if (life.promises.containsKey(p.id)) trf('va’da: {0}-turgacha', [life.promises[p.id]]),
                      if (life.wantsOut.contains(p.id)) tr('ketishni so‘ramoqda'),
                    ].join(' · '),
                    style: AppText.caption,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${p.morale}%', style: AppText.bodyStrong.copyWith(color: p.morale >= 70 ? AppColors.win : p.morale >= 45 ? AppColors.warning : AppColors.live)),
                      IconButton(
                        tooltip: tr('O‘yin vaqti va’da qilish'),
                        icon: const Icon(Icons.record_voice_over_outlined),
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(game.promisePlayingTime(p))),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Backroom staff: hire or upgrade each role.
class _Staff extends StatelessWidget {
  const _Staff();
  @override
  Widget build(BuildContext context) {
    final game = GameState(), life = game.life;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final r in StaffRole.values) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(r.icon, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(r.label, style: AppText.h3)),
                    for (var i = 0; i < 5; i++)
                      Icon(i < life.staffLevel(r) ? Icons.star_rounded : Icons.star_outline_rounded, size: 18, color: AppColors.gold),
                  ],
                ),
                const SizedBox(height: 6),
                Text(r.effect, style: AppText.small),
                const SizedBox(height: 8),
                Text(
                  life.staffLevel(r) == 0
                      ? tr('Yollanmagan')
                      : trf('Maosh: {0}/hafta', [formatMoney(game.staffWage(r, life.staffLevel(r)))]),
                  style: AppText.caption.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (life.staffLevel(r) > 0)
                      TextButton(onPressed: () => game.setStaff(r, 0), child: Text(tr('Bo‘shatish'))),
                    const Spacer(),
                    if (life.staffLevel(r) < 5)
                      FilledButton.tonal(
                        onPressed: () {
                          final error = game.setStaff(r, life.staffLevel(r) + 1);
                          if (error != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                        },
                        child: Text(trf('{0}-daraja · {1}/hafta', [life.staffLevel(r) + 1, formatMoney(game.staffWage(r, life.staffLevel(r) + 1))])),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Scouting: trips abroad (the world market), player reports in progress
/// and youth searches.
class _Scouts extends StatelessWidget {
  const _Scouts();

  static String _flagOf(String country) =>
      InitialDatabase.leagues.where((l) => l.country == country && l.flag.isNotEmpty).firstOrNull?.flag ??
      countryFlags[country] ??
      '🏳️';

  /// Picks a country, loads its leagues and sends the scouts.
  Future<void> _sendAbroad(BuildContext context) async {
    final game = GameState();
    final open = {...game.world.countries, ...game.world.missions.keys};
    final countries = [for (final c in game.scoutDestinations) if (!open.contains(c)) c];
    var query = '';
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: StatefulBuilder(
          builder: (ctx, update) {
            final shown = [
              for (final c in countries)
                if (query.isEmpty || tr(c).toLowerCase().contains(query.toLowerCase())) c,
            ];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: tr('Davlat'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => update(() => query = v.trim()),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final c in shown)
                        ListTile(
                          leading: FlagView(_flagOf(c), nationality: c, height: 20),
                          title: Text(tr(c)),
                          subtitle: Text(
                            WorldMarket.leaguesOf(c, const {}).map((l) => l.name).take(3).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(formatMoney(game.worldScoutCost(c)), style: AppText.caption),
                          onTap: () => Navigator.pop(ctx, c),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    String? error;
    try {
      error = await game.sendScouts(picked);
    } finally {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? trf('Skautlar {0}ga jo‘nadi.', [tr(picked)]))),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final game = GameState(), life = game.life;
    final nations = {for (final p in InitialDatabase.namePools) p['nationality'] as String}.toList()..sort();
    final world = game.world;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                trf('Dunyo skautligi ({0}/{1})', [world.missions.length, game.worldScoutCapacity]),
                icon: Icons.public_rounded,
              ),
              Text(
                trf('Skautlarni davlatga yuboring: {0} turdan keyin hisobot keladi va u yerdagi klublar transfer bozorida paydo bo‘ladi.', [game.worldScoutRounds]),
                style: AppText.small,
              ),
              const SizedBox(height: 8),
              for (final e in world.missions.entries)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: FlagView(_flagOf(e.key), nationality: e.key, height: 18),
                  title: Text(tr(e.key), style: AppText.bodyStrong),
                  subtitle: Text(trf('Hisobot {0}-turda', [e.value]), style: AppText.caption),
                  trailing: const Icon(Icons.hourglass_top_rounded),
                ),
              if (world.countries.isNotEmpty) ...[
                Text(tr('O‘rganilgan davlatlar'), style: AppText.caption.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in world.countries.toList()..sort())
                      Chip(label: FlagLabel(_flagOf(c), tr(c), nationality: c), visualDensity: VisualDensity.compact),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: world.missions.length >= game.worldScoutCapacity ? null : () => _sendAbroad(context),
                  icon: const Icon(Icons.flight_takeoff_rounded, size: 18),
                  label: Text(tr('Skaut yuborish')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(tr('Yosh iste’dodlarni qidirish'), icon: Icons.travel_explore_outlined),
              Text(tr('Davlatni tanlang: 3 turdan keyin skautlar 2–3 yosh futbolchini topadi (ba’zan ⭐ wonderkid).'), style: AppText.small),
              const SizedBox(height: 10),
              if (life.youthMission != null)
                Text(trf('Qidiruv: {0} · {1}-turda tugaydi', [tr(life.youthMission!), life.youthMissionDue]), style: AppText.bodyStrong)
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final n in nations)
                      ActionChip(
                        label: Text(tr(n)),
                        onPressed: () {
                          final error = game.startYouthMission(n);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? tr('Skautlar yo‘lga chiqdi.'))));
                        },
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(trf('Kuzatuvlar ({0}/{1})', [life.scoutQueue.length, game.scoutCapacity]), icon: Icons.visibility_outlined),
              if (life.scoutQueue.isEmpty)
                Text(tr('Boshqa ligalardagi futbolchilarni profilidan “Skaut yuborish” orqali o‘rganing.'), style: AppText.small)
              else
                for (final e in life.scoutQueue.entries)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.hourglass_top_rounded),
                    title: Text(game.findPlayerById(e.key)?.name ?? e.key),
                    trailing: Text(trf('{0}-tur', [e.value]), style: AppText.caption),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
