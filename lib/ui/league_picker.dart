import 'package:flutter/material.dart';
import '../data/initial_database.dart';
import '../l10n/l10n.dart';
import '../models/crest.dart';
import 'widgets.dart';

/// Horizontal league cards: name, country, size, level and strength.
class LeaguePicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const LeaguePicker({super.key, required this.selected, required this.onChanged});

  // Copying a league's data is costly: summaries are computed once.
  static final Map<String, ({int count, int strength, List<ClubCrestConfig> crests})> _summary = {};

  static ({int count, int strength, List<ClubCrestConfig> crests}) _of(String id) =>
      _summary[id] ??= () {
        final clubs = InitialDatabase.getClubs(id);
        final top = (List.of(clubs)..sort((a, b) => b.reputation.compareTo(a.reputation))).take(3);
        return (
          count: clubs.length,
          strength: clubs.isEmpty
              ? 0
              : (clubs.map((c) => c.squadDepthRating).reduce((a, b) => a + b) / clubs.length).round(),
          crests: [for (final c in top) c.crestConfig],
        );
      }();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 150,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: InitialDatabase.leagues.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, i) {
        final l = InitialDatabase.leagues[i];
        final info = _of(l.id);
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
              onTap: () => onChanged(l.id),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
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
