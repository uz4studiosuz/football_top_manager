import 'package:flutter/material.dart';
import 'flag.dart';
import '../data/initial_database.dart';
import '../l10n/l10n.dart';
import '../models/crest.dart';
import 'widgets.dart';

/// Horizontal league cards (featured leagues plus the chosen one) and a
/// button that opens every league of the world, grouped by country.
class LeaguePicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const LeaguePicker({super.key, required this.selected, required this.onChanged});

  /// Premier League, LaLiga, Serie A, Ligue 1.
  static const featured = ['epl', 'es1', 'it1', 'fr1'];

  // Copying a league's data is costly: summaries are computed once.
  static final Map<String, ({int count, int strength, List<ClubCrestConfig> crests})> _summary = {};

  static ({int count, int strength, List<ClubCrestConfig> crests}) _of(LeagueInfo l) {
    if (!InitialDatabase.isLoaded(l.id)) return (count: l.clubCount, strength: _levelOvr(l.level), crests: const []);
    return _summary[l.id] ??= () {
      final clubs = InitialDatabase.getClubs(l.id);
      final top = (List.of(clubs)..sort((a, b) => b.reputation.compareTo(a.reputation))).take(3);
      return (
        count: clubs.length,
        strength: clubs.isEmpty
            ? 0
            : (clubs.map((c) => c.squadDepthRating).reduce((a, b) => a + b) / clubs.length).round(),
        crests: [for (final c in top) c.crestConfig],
      );
    }();
  }

  /// Database club power → our squad rating scale (as the data generator).
  static int _levelOvr(int level) => level >= 84 ? level : (42 + level * 0.5).round();

  Future<void> _choose(BuildContext context, String id) async {
    if (!InitialDatabase.isLoaded(id)) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        await InitialDatabase.ensurePyramid(id);
      } finally {
        if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      }
    }
    if (context.mounted) onChanged(id);
  }

  @override
  Widget build(BuildContext context) {
    // The big four up front; every other league sits in "All leagues".
    final shown = [
      for (final id in featured)
        if (InitialDatabase.leagues.any((l) => l.id == id)) InitialDatabase.info(id),
      if (!featured.contains(selected) && InitialDatabase.leagues.any((l) => l.id == selected)) InitialDatabase.info(selected),
    ];
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shown.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          if (i == shown.length) {
            return SizedBox(
              width: 150,
              child: Material(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.line),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    final id = await pickLeague(context, selected: selected);
                    if (id != null && context.mounted) await _choose(context, id);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.public_rounded, color: AppColors.primary, size: 30),
                        const SizedBox(height: 8),
                        Text(tr('Barcha ligalar'), style: AppText.bodyStrong, textAlign: TextAlign.center),
                        Text(trf('{0} ta liga', [InitialDatabase.leagues.length]), style: AppText.caption),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          final l = shown[i];
          final info = _of(l);
          final on = l.id == selected;
          return SizedBox(
            width: 190,
            child: Material(
              color: on ? AppColors.primarySoft : AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: on ? AppColors.primary : AppColors.line, width: on ? 2 : 1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _choose(context, l.id),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (info.crests.isEmpty && l.flag.isNotEmpty) FlagView(l.flag, nationality: l.country, height: 18),
                          for (final crest in info.crests)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: ClubCrestWidget(config: crest, size: 22),
                            ),
                          const Spacer(),
                          if (on) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                      Text(
                        [if (l.country.isNotEmpty) tr(l.country), if (l.pyramid != null) trf('{0}-daraja', [l.tier])].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              trf('{0} klub · {1} tur', [info.count, (info.count - 1) * 2]),
                              style: AppText.small,
                            ),
                          ),
                          ValueBadge(info.strength, size: 26),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Every league (or just [only]) in a searchable sheet, grouped by country.
Future<String?> pickLeague(BuildContext context, {String? selected, Iterable<LeagueInfo>? only}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        // The invented Super League is no longer offered for new careers.
        child: _LeagueBrowser(selected: selected, leagues: (only ?? InitialDatabase.leagues.where((l) => l.id != 'super')).toList()),
      ),
    );

class _LeagueBrowser extends StatefulWidget {
  final String? selected;
  final List<LeagueInfo> leagues;
  const _LeagueBrowser({required this.selected, required this.leagues});
  @override
  State<_LeagueBrowser> createState() => _LeagueBrowserState();
}

class _LeagueBrowserState extends State<_LeagueBrowser> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final byCountry = <String, List<LeagueInfo>>{};
    for (final l in widget.leagues) {
      final country = l.country.isEmpty ? '—' : tr(l.country);
      if (q.isNotEmpty && !l.name.toLowerCase().contains(q) && !country.toLowerCase().contains(q)) continue;
      byCountry.putIfAbsent(country, () => []).add(l);
    }
    final countries = byCountry.keys.toList()..sort();
    for (final list in byCountry.values) {
      list.sort((a, b) => a.tier != b.tier ? a.tier.compareTo(b.tier) : a.name.compareTo(b.name));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            autofocus: false,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: tr('Liga yoki davlat'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _q = v.trim()),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final c in countries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: FlagLabel(
                    byCountry[c]!.first.flag,
                    c,
                    nationality: byCountry[c]!.first.country,
                    style: AppText.caption.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                for (final l in byCountry[c]!)
                  ListTile(
                    dense: true,
                    selected: l.id == widget.selected,
                    title: Text(l.name),
                    subtitle: Text(
                      [
                        trf('{0}-daraja', [l.tier]),
                        if (l.clubCount > 0) trf('{0} klub', [l.clubCount]),
                      ].join(' · '),
                    ),
                    trailing: l.level > 0 ? ValueBadge(LeaguePicker._levelOvr(l.level), size: 26) : null,
                    onTap: () => Navigator.pop(context, l.id),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
