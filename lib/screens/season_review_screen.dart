import 'package:flutter/material.dart';
import '../models/finance.dart';
import '../models/player.dart';
import '../services/cup.dart';
import '../services/game_state.dart';
import '../ui/face_avatar.dart';
import '../models/crest.dart';
import '../ui/widgets.dart';
import '../l10n/l10n.dart';

/// End-of-season summary: table position, results, best players, money,
/// cup run, trophies and awards.
class SeasonReviewScreen extends StatelessWidget {
  const SeasonReviewScreen({super.key});

  static Future<void> show(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const SeasonReviewScreen()));

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette tokens when appearance changes.
    final game = GameState(), club = game.userClub;
    final s = game.standingOf(club.id);
    final pos = game.positionOf(club.id);
    final squad = club.squad;
    Player? best(int Function(Player) by) =>
        squad.isEmpty ? null : (List.of(squad)..sort((a, b) => by(b).compareTo(by(a)))).first;
    final scorer = best((p) => p.seasonGoals), assister = best((p) => p.seasonAssists);
    final rated = squad.where((p) => p.seasonRated >= 5).toList()
      ..sort((a, b) => (b.averageRating ?? 0).compareTo(a.averageRating ?? 0));
    final mine = game.ledger.where((e) => e.clubId == club.id);
    final income = mine.where((e) => e.amount > 0).fold<int>(0, (a, e) => a + e.amount);
    final spend = mine.where((e) => e.amount < 0).fold<int>(0, (a, e) => a - e.amount);
    final transfersIn = mine.where((e) => e.category == FinanceCategory.transferOut).fold<int>(0, (a, e) => a - e.amount);
    final cup = game.cup;
    final cupRun = cup == null
        ? '—'
        : cup.winner == club.id
        ? tr('G‘olib 🏆')
        : () {
            for (var r = cup.rounds.length - 1; r >= 0; r--) {
              if (cup.rounds[r].any((t) => t.involves(club.id) && !t.isBye)) return Cup.stageName(r, cup.totalRounds);
            }
            return '—';
          }();
    final award = game.life.awards.firstOrNull;
    final trophies = game.life.trophies.where((t) => t.startsWith(game.seasonLabel)).toList();
    Widget player(String label, Player? p, String value) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: p == null ? null : FaceAvatar(config: p.face, size: 40, shirt: club.primaryColor, circle: true),
      title: Text(label, style: AppText.caption),
      subtitle: Text(p?.name ?? '—', style: AppText.bodyStrong),
      trailing: Text(value, style: AppText.h3),
    );
    return Scaffold(
      appBar: AppBar(title: Text(trf('Mavsum sharhi · {0}', [game.seasonLabel]))),
      body: PageWidth(
        maxWidth: 820,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            AppCard(
              child: Column(
                children: [
                  ClubCrestWidget(config: club.crestConfig, size: 72),
                  const SizedBox(height: 8),
                  Text(club.name, style: AppText.h2),
                  Text(trf('{0} · {1}-o‘rin · {2} ochko', [game.leagueName, pos, s.points]), style: AppText.small),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final (label, value) in [
                        (tr('G'), s.won),
                        (tr('D'), s.drawn),
                        (tr('M'), s.lost),
                        (tr('Gollar'), s.goalsFor),
                        (tr('O‘tkazildi'), s.goalsAgainst),
                      ])
                        Expanded(
                          child: Column(
                            children: [
                              Text('$value', style: AppText.h2),
                              Text(label, style: AppText.caption),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (trophies.isNotEmpty) ...[
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  children: [
                    for (final t in trophies)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.emoji_events, color: AppColors.gold),
                        title: Text(t, style: AppText.bodyStrong),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(tr('Mavsum qahramonlari'), icon: Icons.star_outline_rounded),
                  player(tr('Eng ko‘p gol'), scorer, '${scorer?.seasonGoals ?? 0}'),
                  player(tr('Eng ko‘p assist'), assister, '${assister?.seasonAssists ?? 0}'),
                  player(tr('Eng yuqori reyting'), rated.firstOrNull, rated.firstOrNull?.averageRating?.toStringAsFixed(2) ?? '–'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                children: [
                  InfoRow(tr('Kubok'), cupRun),
                  InfoRow(tr('Kengash maqsadi'), game.objective.title),
                  InfoRow(tr('Eng yirik g‘alaba'), game.life.biggestWin.isEmpty ? '—' : game.life.biggestWin),
                  InfoRow(tr('Daromad'), formatMoney(income)),
                  InfoRow(tr('Xarajat'), formatMoney(spend)),
                  InfoRow(tr('Transferlarga sarflandi'), formatMoney(transfersIn)),
                  InfoRow(tr('Muxlislar kayfiyati'), '${club.fanMood}%'),
                ],
              ),
            ),
            if (award != null && award.season == game.seasonLabel) ...[
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(tr('Mavsum mukofotlari'), icon: Icons.workspace_premium_outlined),
                    InfoRow(tr('Oltin to‘p'), award.ballonDor),
                    InfoRow(tr('Oltin butsa'), award.goldenBoot),
                    InfoRow(tr('Eng yaxshi yosh'), award.youngPlayer),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
