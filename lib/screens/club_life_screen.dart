import 'package:flutter/material.dart';
import '../models/player.dart';
import '../services/club_life.dart';
import '../services/game_state.dart';
import '../ui/face_avatar.dart';
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
    length: 5,
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
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: GameState(),
        builder: (context, _) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: const TabBarView(
              children: [_Facilities(), _Training(), _Academy(), _Fans(), _HallOfFame()],
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: post.positive ? AppColors.win.withValues(alpha: 0.15) : AppColors.live.withValues(alpha: 0.15),
            child: Icon(post.positive ? Icons.sentiment_satisfied_alt : Icons.sentiment_dissatisfied, color: post.positive ? AppColors.win : AppColors.live, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(post.author, style: AppText.bodyStrong.copyWith(fontSize: 13))),
                    const SizedBox(width: 6),
                    Text(post.when, style: AppText.caption),
                  ],
                ),
                const SizedBox(height: 4),
                Text(post.text, style: AppText.body),
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
