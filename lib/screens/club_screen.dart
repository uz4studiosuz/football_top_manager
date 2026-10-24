import 'dart:math';
import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/finance.dart';
import '../services/game_state.dart';
import '../services/season_calendar.dart';
import '../ui/team_widgets.dart';
import '../ui/widgets.dart';
import 'match_report_screen.dart';
import '../l10n/l10n.dart';

/// Club hub: finances, real-date calendar, inbox and club profile.
class ClubScreen extends StatelessWidget {
  const ClubScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: Text(tr('Klub')),
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: tr('Moliya')),
            Tab(text: tr('Kalendar')),
            Tab(text: tr('Yangiliklar')),
            Tab(text: tr('Klub profili')),
          ],
        ),
      ),
      body: const TabBarView(
        children: [FinanceView(), CalendarView(), NewsView(), ClubProfileView()],
      ),
    ),
  );
}

// =========================================================================
// Finance
// =========================================================================
class FinanceView extends StatelessWidget {
  const FinanceView({super.key});
  @override
  Widget build(BuildContext context) {
    final game = GameState();
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final c = game.userClub;
        final entries = game.ledger.where((e) => e.clubId == c.id).toList();
        final income = entries.where((e) => e.amount > 0).fold<int>(0, (s, e) => s + e.amount);
        final spend = entries.where((e) => e.amount < 0).fold<int>(0, (s, e) => s + e.amount);
        final byCategory = <FinanceCategory, int>{};
        for (final e in entries) {
          byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
        }
        final weeklyCommercial = game.weeklyCommercial(c);
        final wagePct = c.totalWeeklyWages / c.wageBudget;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Transfer byudjeti (bank)'), style: AppText.small),
                  const SizedBox(height: 4),
                  Text(
                    formatMoney(c.transferBudget, digits: 2),
                    style: AppText.number.copyWith(fontSize: 32, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trf('Mavsum: +{0}  ·  {1}', [formatMoney(income), formatMoney(spend)]),
                    style: AppText.caption,
                  ),
                  const SizedBox(height: 14),
                  TrendChart(
                    values: game.balanceHistory.map((v) => v.toDouble()).toList(),
                    color: (game.balanceHistory.isNotEmpty &&
                            c.transferBudget < game.balanceHistory.first)
                        ? AppColors.loss
                        : AppColors.primary,
                  ),
                  const SizedBox(height: 6),
                  Text(tr('Balans dinamikasi (har tur)'), style: AppText.caption),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(tr('Maosh fondi'), icon: Icons.payments_outlined),
                  MeterRow(
                    label: tr('Haftalik maoshlar / limit'),
                    value: wagePct,
                    trailing: '${formatMoney(c.totalWeeklyWages)} / ${formatMoney(c.wageBudget)}',
                    color: wagePct > 0.95 ? AppColors.loss : wagePct > 0.85 ? AppColors.warning : AppColors.win,
                  ),
                  InfoRow(tr('Bo‘sh maosh imkoniyati'), trf('{0}/hafta', [formatMoney(c.remainingWageBudget)])),
                  InfoRow(tr('Homiylik va savdo'), trf('{0}/hafta', [formatMoney(weeklyCommercial)])),
                  InfoRow(tr('Tarkib qiymati'), formatMoney(c.squadValue)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _TicketCard(club: c),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(tr('Daromad va xarajat tarkibi'), icon: Icons.donut_small_outlined),
                  if (byCategory.isEmpty)
                    EmptyState(icon: Icons.receipt_long_outlined, text: tr('Birinchi turdan keyin moliyaviy hisobot shakllanadi.')),
                  for (final cat in FinanceCategory.values)
                    if (byCategory.containsKey(cat))
                      _CategoryRow(
                        category: cat,
                        amount: byCategory[cat]!,
                        share: byCategory[cat]!.abs() / max(1, cat.income ? income : -spend),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SectionHeader(tr('Operatsiyalar'), icon: Icons.receipt_long_outlined),
                  ),
                  if (entries.isEmpty)
                    EmptyState(icon: Icons.hourglass_empty_rounded, text: tr('Hali operatsiyalar yo‘q')),
                  for (final e in entries.reversed.take(40))
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: (e.amount >= 0 ? AppColors.win : AppColors.loss).withValues(alpha: 0.1),
                        child: Icon(e.category.icon, size: 16, color: e.amount >= 0 ? AppColors.win : AppColors.loss),
                      ),
                      title: Text(e.label, style: AppText.bodyStrong.copyWith(fontSize: 13)),
                      subtitle: Text(
                        trf('{0}{1}-tur', [e.date == null ? '' : '${SeasonCalendar.format(e.date!)} · ', e.round]),
                        style: AppText.caption,
                      ),
                      trailing: Text(
                        '${e.amount >= 0 ? '+' : ''}${formatMoney(e.amount, digits: 2)}',
                        style: AppText.number.copyWith(
                          fontSize: 13,
                          color: e.amount >= 0 ? AppColors.win : AppColors.ink,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final FinanceCategory category;
  final int amount;
  final double share;
  const _CategoryRow({required this.category, required this.amount, required this.share});
  @override
  Widget build(BuildContext context) {
    final color = amount >= 0 ? AppColors.win : AppColors.loss;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(category.icon, size: 18, color: AppColors.ink2),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(category.label, style: AppText.small.copyWith(color: AppColors.ink))),
                    Text(formatMoney(amount), style: AppText.number.copyWith(fontSize: 13, color: color)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: share.clamp(0.0, 1.0),
                    minHeight: 5,
                    color: color.withValues(alpha: 0.75),
                    backgroundColor: AppColors.surfaceAlt,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Club club;
  const _TicketCard({required this.club});
  @override
  Widget build(BuildContext context) {
    final game = GameState();
    final base = game.baseTicketPrice(club);
    final attendance = game.projectedAttendance(club);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(tr('Chipta narxi'), icon: Icons.confirmation_number_outlined),
          Row(
            children: [
              Text('€${club.ticketPrice}', style: AppText.number.copyWith(fontSize: 24)),
              const SizedBox(width: 8),
              Text(trf('tavsiya: €{0}', [base]), style: AppText.caption),
            ],
          ),
          Slider(
            min: 20,
            max: 200,
            divisions: 36,
            value: club.ticketPrice.toDouble().clamp(20, 200),
            label: '€${club.ticketPrice}',
            onChanged: (v) => game.setTicketPrice(v.round()),
          ),
          InfoRow(tr('Kutilayotgan tomoshabinlar'), '$attendance / ${club.stadiumCapacity}'),
          InfoRow(tr('Bir uy o‘yini tushumi'), formatMoney(game.projectedGate(club))),
          Text(
            tr('Yuqori narx tushumni oshiradi, lekin tribunalar bo‘shaydi va muxlislar kayfiyati pasayadi.'),
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// Calendar
// =========================================================================
class CalendarView extends StatefulWidget {
  const CalendarView({super.key});
  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime month;
  @override
  void initState() {
    super.initState();
    final d = GameState().currentDate;
    month = DateTime(d.year, d.month);
  }

  @override
  Widget build(BuildContext context) {
    final game = GameState();
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final cal = game.calendar;
        final userId = game.userClubId!;
        final matches = {
          for (final f in game.fixturesOf(userId))
            if (f.date != null) DateTime(f.date!.year, f.date!.month, f.date!.day): f,
        };
        final first = DateTime(month.year, month.month);
        final days = DateTime(month.year, month.month + 1, 0).day;
        final lead = first.weekday - 1;
        final today = game.currentDate;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Text(
                          '${SeasonCalendar.months[month.month - 1]} ${month.year}',
                          textAlign: TextAlign.center,
                          style: AppText.h3,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (final w in SeasonCalendar.weekdays)
                        Expanded(child: Center(child: Text(w, style: AppText.caption))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 0.9,
                    children: [
                      for (var i = 0; i < lead; i++) const SizedBox(),
                      for (var d = 1; d <= days; d++)
                        Builder(
                          builder: (context) {
                            final date = DateTime(month.year, month.month, d);
                            final f = matches[date];
                            final window = cal.windowOpenOn(date);
                            final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
                            final opp = f == null
                                ? null
                                : game.getClubById(f.homeClubId == userId ? f.awayClubId : f.homeClubId);
                            return Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: window ? const Color(0xFFEFF8FF) : null,
                                borderRadius: BorderRadius.circular(8),
                                border: isToday ? Border.all(color: AppColors.primary, width: 1.6) : null,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: f == null || !f.isPlayed
                                    ? null
                                    : () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(builder: (_) => MatchReportScreen(fixture: f)),
                                      ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$d',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                                        color: date.weekday >= 6 ? AppColors.ink : AppColors.ink2,
                                      ),
                                    ),
                                    if (opp != null) ...[
                                      const SizedBox(height: 2),
                                      ClubCrestWidget(config: opp.crestConfig, size: 18),
                                      if (f!.isPlayed)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 1),
                                          child: Container(
                                            width: 14,
                                            height: 3,
                                            decoration: BoxDecoration(
                                              color: AppColors.result(f.resultFor(userId)),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      _legend(const Color(0xFFEFF8FF), 'Transfer oynasi'),
                      _legend(AppColors.primary, 'Bugun', outline: true),
                      _legend(AppColors.win, tr('G‘alaba')),
                      _legend(AppColors.loss, tr('Mag‘lubiyat')),
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
                  SectionHeader(tr('Mavsum muhim sanalari'), icon: Icons.event_note_outlined),
                  _dateRow(Icons.sports_soccer, tr('Mavsum boshlanishi'), cal.dateOfRound(1)),
                  _dateRow(Icons.lock_outline_rounded, 'Yozgi oyna yopiladi', cal.summerClose),
                  _dateRow(Icons.ac_unit_rounded, 'Qishki tanaffus', cal.dateOfRound(8).add(const Duration(days: 7))),
                  _dateRow(Icons.lock_open_rounded, 'Qishki oyna ochiladi', cal.winterOpen),
                  _dateRow(Icons.lock_outline_rounded, 'Qishki oyna yopiladi', cal.winterClose),
                  _dateRow(Icons.emoji_events_outlined, tr('So‘nggi tur'), cal.dateOfRound(game.totalRounds)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SectionHeader(tr('Barcha uchrashuvlarim'), icon: Icons.list_alt_rounded),
                  ),
                  for (final f in game.fixturesOf(userId))
                    FixtureTile(
                      fixture: f,
                      highlightClubId: userId,
                      onTap: f.isPlayed
                          ? () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(builder: (_) => MatchReportScreen(fixture: f)),
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _legend(Color c, String label, {bool outline = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: outline ? null : c,
          border: outline ? Border.all(color: c, width: 1.6) : null,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(tr(label), style: AppText.caption),
    ],
  );

  Widget _dateRow(IconData icon, String label, DateTime d) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(tr(label), style: AppText.small.copyWith(color: AppColors.ink))),
        Text(SeasonCalendar.format(d, year: true), style: AppText.number.copyWith(fontSize: 13)),
      ],
    ),
  );
}

// =========================================================================
// News
// =========================================================================
class NewsView extends StatefulWidget {
  const NewsView({super.key});
  @override
  State<NewsView> createState() => _NewsViewState();
}

class _NewsViewState extends State<NewsView> {
  @override
  void dispose() {
    final game = GameState();
    if (game.isInitialized && game.unreadNews > 0) {
      for (final n in game.news) {
        n.read = true;
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = GameState();
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => game.news.isEmpty
          ? EmptyState(icon: Icons.inbox_outlined, text: tr('Yangiliklar yo‘q'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [for (final n in game.news) NewsTile(item: n)],
                  ),
                ),
              ],
            ),
    );
  }
}

class NewsTile extends StatelessWidget {
  final NewsItem item;
  final bool dense;
  const NewsTile({super.key, required this.item, this.dense = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 8 : 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: item.kind.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(item.kind.icon, size: 18, color: item.kind.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                    ),
                  ),
                  if (!item.read)
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(left: 6, top: 4),
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                item.body,
                maxLines: dense ? 2 : 6,
                overflow: TextOverflow.ellipsis,
                style: AppText.small.copyWith(height: 1.35),
              ),
              const SizedBox(height: 4),
              Text(SeasonCalendar.format(item.date, year: true), style: AppText.caption),
            ],
          ),
        ),
      ],
    ),
  );
}

class NewsPage extends StatelessWidget {
  const NewsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('Yangiliklar'))),
    body: PageWidth(
      maxWidth: 900,
      child: const NewsView(),
    ),
  );
}

// =========================================================================
// Club profile
// =========================================================================
class ClubProfileView extends StatelessWidget {
  const ClubProfileView({super.key});
  @override
  Widget build(BuildContext context) {
    final game = GameState();
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final c = game.userClub;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            AppCard(
              child: Column(
                children: [
                  ClubCrestWidget(config: c.crestConfig, size: 96),
                  const SizedBox(height: 10),
                  Text(c.name, style: AppText.h2),
                  Text('${c.nickname} · ${c.city} · ${c.founded}', style: AppText.caption),
                  const Divider(height: 26),
                  InfoRow(tr('Stadion'), c.stadiumName),
                  InfoRow(tr('Sig‘imi'), '${c.stadiumCapacity}'),
                  InfoRow(tr('Obro‘ (reputatsiya)'), '${c.reputation}/100'),
                  InfoRow(tr('Tarkib'), trf('{0} futbolchi · o‘rtacha {1} yosh', [c.squad.length, c.averageAge.toStringAsFixed(1)])),
                  InfoRow(tr('Jamoa OVR'), '${c.teamOVR}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SectionHeader(tr('Mavsumlar tarixi'), icon: Icons.history_rounded),
                  ),
                  if (game.seasonHistory.isEmpty)
                    EmptyState(icon: Icons.history_toggle_off_rounded, text: tr('Birinchi mavsum davom etmoqda')),
                  for (final s in game.seasonHistory.reversed)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: s.userPosition == 1 ? AppColors.gold : AppColors.surfaceAlt,
                        child: Text('${s.userPosition}', style: AppText.number),
                      ),
                      title: Text(s.season),
                      subtitle: Text(trf('Chempion: {0} · To‘purar: {1}', [s.championName, s.topScorer])),
                      trailing: Text(trf('{0} o‘', [s.userPoints]), style: AppText.number),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SectionHeader(tr('Liga transferlari'), icon: Icons.swap_horiz_rounded),
                  ),
                  if (game.transferHistory.isEmpty)
                    EmptyState(icon: Icons.swap_horiz_rounded, text: tr('Hali transferlar yo‘q')),
                  for (final t in game.transferHistory.take(30))
                    ListTile(
                      dense: true,
                      title: Text(t.playerName, style: AppText.bodyStrong.copyWith(fontSize: 13)),
                      subtitle: Text('${t.fromClub} → ${t.toClub}', style: AppText.caption),
                      trailing: Text(formatMoney(t.fee), style: AppText.number.copyWith(fontSize: 13)),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
