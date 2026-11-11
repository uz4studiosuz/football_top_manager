import 'package:flutter/material.dart';
import '../services/game_state.dart';
import '../services/training_schedule.dart';
import '../services/season_calendar.dart';
import '../ui/widgets.dart';
import '../l10n/l10n.dart';
import 'club_life_screen.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});
  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  int week = 0;
  final game = GameState();

  Future<void> _edit(DateTime date, int slot) async {
    final current = game.life.training.session(
      date,
      slot,
      game.trainingMatchDates,
    );
    final chosen = await showDialog<TrainingSession>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr('Mashg‘ulotni tanlash')),
        children: [
          for (final session in TrainingSession.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, session),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Icon(_icon(session), color: _color(session), size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(session.label)),
                    if (session == current)
                      Icon(Icons.check, color: AppColors.teal),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (chosen != null && mounted) {
      game.setTrainingSession(date.weekday - 1, slot, chosen);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr('Mashg‘ulot markazi')),
      actions: [
        IconButton(
          tooltip: tr('Individual ko‘rsatma'),
          icon: const Icon(Icons.person_outline),
          onPressed: () => ClubLifeScreen.show(context, 1),
        ),
      ],
    ),
    body: ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final start = game.currentDate
            .subtract(Duration(days: game.currentDate.weekday - 1))
            .add(Duration(days: week * 7));
        final plan = game.life.training;
        final matches = game.trainingMatchDates;
        final work = plan.workload(start, 7, matches);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Haftalik reja'), style: AppText.h1),
                    const SizedBox(height: 6),
                    Text(
                      '${SeasonCalendar.short(start)} — ${SeasonCalendar.short(start.add(const Duration(days: 6)))}',
                      style: AppText.small,
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: tr('Oldingi hafta'),
                      onPressed: week == 0
                          ? null
                          : () => setState(() => week--),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    TextButton(
                      onPressed: () => setState(() => week = 0),
                      child: Text(tr('Bugun')),
                    ),
                    IconButton(
                      tooltip: tr('Keyingi hafta'),
                      onPressed: week >= 4
                          ? null
                          : () => setState(() => week++),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            AppCard(
              child: Wrap(
                spacing: 24,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    tr('Mashg‘ulot intensivligi'),
                    style: AppText.bodyStrong,
                  ),
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 1, label: Text(tr('Yengil'))),
                      ButtonSegment(value: 2, label: Text(tr('Normal'))),
                      ButtonSegment(value: 3, label: Text(tr('Yuqori'))),
                    ],
                    selected: {plan.intensity},
                    onSelectionChanged: (v) =>
                        game.setTrainingIntensity(v.first),
                  ),
                  Text(
                    tr(
                      'Reja har hafta takrorlanadi. O‘yin kuni mashg‘ulot o‘rnini egallaydi.',
                    ),
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, box) {
                final cols = box.maxWidth >= 1050
                    ? 7
                    : box.maxWidth >= 680
                    ? 4
                    : box.maxWidth >= 330
                    ? 2
                    : 1;
                final width = (box.maxWidth - (cols - 1) * 10) / cols;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var d = 0; d < 7; d++)
                      SizedBox(
                        width: width,
                        child: _day(start.add(Duration(days: d)), matches),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Wrap(
                spacing: 32,
                runSpacing: 18,
                children: [
                  _metric(
                    tr('Yuklama'),
                    work.dailyLoad.toStringAsFixed(1),
                    work.overloaded ? AppColors.warning : AppColors.teal,
                  ),
                  _metric(
                    tr('Tiklanish'),
                    '${work.recovery.toInt()}',
                    AppColors.win,
                  ),
                  _metric(
                    tr('Taktik mashg‘ulot'),
                    work.tactics.toStringAsFixed(1),
                    AppColors.primary,
                  ),
                  _metric(
                    tr('Rivojlanish'),
                    '${(work.development * 100).round()}%',
                    AppColors.ink,
                  ),
                ],
              ),
            ),
            if (work.overloaded)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: AppCard(
                  color: AppColors.warningSurface,
                  child: Text(
                    tr(
                      'Yuklama baland. Dam olish yoki tiklanish qo‘shing: futbolchilar keyingi o‘yinga charchagan holda kelishi mumkin.',
                    ),
                    style: AppText.small.copyWith(color: AppColors.warning),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const TacticalReadinessPanel(),
          ],
        );
      },
    ),
  );

  Widget _day(DateTime date, List<DateTime> matches) {
    final match = TrainingSchedule.isMatchDay(date, matches);
    final today = TrainingSchedule.sameDay(date, game.currentDate);
    final recovery = TrainingSchedule.isMatchDay(
      date.subtract(const Duration(days: 1)),
      matches,
    );
    final fixture = game
        .fixturesOf(game.userClub.id)
        .where((f) => f.date != null && TrainingSchedule.sameDay(f.date!, date))
        .firstOrNull;
    final opponent = fixture == null
        ? null
        : game.getClubById(
            fixture.homeClubId == game.userClub.id
                ? fixture.awayClubId
                : fixture.homeClubId,
          );
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: today ? AppColors.primarySoft : AppColors.surfaceAlt,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    SeasonCalendar.weekday(date),
                    style: AppText.bodyStrong.copyWith(fontSize: 12),
                  ),
                ),
                Text('${date.day}', style: AppText.number),
              ],
            ),
          ),
          if (match)
            Container(
              height: 180,
              padding: const EdgeInsets.all(12),
              color: AppColors.primarySoft,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports_soccer, color: AppColors.primary, size: 28),
                  const SizedBox(height: 12),
                  Text(tr('O‘yin kuni'), style: AppText.bodyStrong),
                  const SizedBox(height: 6),
                  Text(
                    opponent?.shortName ?? game.cupName,
                    style: AppText.small,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            for (var s = 0; s < 3; s++)
              Builder(
                builder: (context) {
                  final session = game.life.training.session(date, s, matches);
                  final locked = recovery && s == 0;
                  return InkWell(
                    onTap: locked ? null : () => _edit(date, s),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 60),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.line)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 30,
                            color: _color(session),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  [
                                    tr('Ertalab'),
                                    tr('Kunduzi'),
                                    tr('Kechqurun'),
                                  ][s],
                                  style: AppText.caption.copyWith(fontSize: 10),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  session.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.small.copyWith(
                                    color: AppColors.ink,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            locked ? Icons.lock_outline : _icon(session),
                            size: 14,
                            color: _color(session),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color color) => SizedBox(
    width: 160,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption),
        const SizedBox(height: 6),
        Text(value, style: AppText.h1.copyWith(color: color)),
      ],
    ),
  );
  static Color _color(TrainingSession s) => switch (s) {
    TrainingSession.rest => AppColors.ink3,
    TrainingSession.recovery ||
    TrainingSession.conditioning => AppColors.warning,
    TrainingSession.defending => const Color(0xFF6CA6EF),
    TrainingSession.attacking || TrainingSession.setPieces => AppColors.primary,
    _ => AppColors.teal,
  };
  static IconData _icon(TrainingSession s) => switch (s) {
    TrainingSession.rest => Icons.bedtime_outlined,
    TrainingSession.recovery => Icons.favorite_border,
    TrainingSession.conditioning => Icons.directions_run,
    TrainingSession.defending => Icons.shield_outlined,
    TrainingSession.pressing => Icons.compress,
    TrainingSession.tactical => Icons.schema_outlined,
    _ => Icons.sports_soccer,
  };
}

class TacticalReadinessPanel extends StatelessWidget {
  const TacticalReadinessPanel({super.key});
  @override
  Widget build(BuildContext context) {
    final game = GameState(), r = game.tacticalReadiness;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            tr('Taktik samaradorlik'),
            icon: Icons.insights_outlined,
          ),
          Text(
            '${game.userClub.tactics.formation.short} · ${game.userClub.tactics.playstyle.displayName}',
            style: AppText.small,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) => Wrap(
              spacing: 20,
              runSpacing: 16,
              children: [
                for (final item in [
                  (tr('Murakkablik'), r.complexity),
                  (tr('O‘zlashtirish'), r.understanding),
                  (tr('Futbolchilar salohiyati'), r.ability),
                  (tr('Jamoaviy uyg‘unlik'), r.cohesion),
                  (tr('Samaradorlik'), r.effectiveness),
                ])
                  SizedBox(
                    width: box.maxWidth >= 700
                        ? (box.maxWidth - 80) / 5
                        : (box.maxWidth - 20) / 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(item.$1, style: AppText.caption),
                            ),
                            Text(
                              '${item.$2}%',
                              style: AppText.number.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: item.$2 / 100,
                          minHeight: 5,
                          backgroundColor: AppColors.surfaceAlt,
                          color: item.$1 == tr('Murakkablik')
                              ? AppColors.warning
                              : AppColors.teal,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr(
              'Murakkab taktika ko‘proq mashg‘ulot va mos futbolchilarni talab qiladi.',
            ),
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}
