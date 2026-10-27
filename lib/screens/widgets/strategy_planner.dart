import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../services/game_state.dart';
import '../../ui/widgets.dart';
import '../../l10n/l10n.dart';

/// Individual corner assignments and one optional automatic match instruction.
class StrategyPlanner extends StatelessWidget {
  const StrategyPlanner({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameState(), club = game.userClub;
    final rule = game.life.autoRule;
    final enabled = rule['enabled'] == true;
    void change(String key, Object value) => game.setAutomaticRule({...rule, key: value});
    Widget selector(String label, String value, Map<String, String> options, ValueChanged<String> onChange) =>
      DropdownButtonFormField<String>(
        initialValue: options.containsKey(value) ? value : options.keys.first,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))],
        onChanged: (v) { if (v != null) onChange(v); },
      );
    return Column(children: [
      AppCard(child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: const Icon(Icons.flag_outlined),
        title: Text(tr('Burchak rejasi'), style: AppText.bodyStrong),
        subtitle: Text(tr('Har futbolchi uchun joylashuv va yugurish yo‘nalishini tanlang'), style: AppText.caption),
        children: [
        for (final player in club.startingXI.where((p) => !p.mainPosition.isGoalkeeper))
          ExpansionTile(
            title: Text(player.shortName, style: AppText.bodyStrong),
            subtitle: Text(club.slotPosition(club.startingLineupIds.indexOf(player.id)).code, style: AppText.caption),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              selector(tr('Joylashuv'), club.cornerPlans[player.id]?.first ?? 'auto', {
                'auto': tr('Avtomatik'), 'near': tr('Yaqin ustun'), 'far': tr('Uzoq ustun'), 'edge': tr('Jarima maydoni cheti'),
              }, (v) => game.setCornerPlan(player, v, club.cornerPlans[player.id]?.last ?? 'hold')),
              const SizedBox(height: 8),
              selector(tr('Yugurish'), club.cornerPlans[player.id]?.last ?? 'hold', {
                'hold': tr('Joyida'), 'forward': tr('Oldinga'), 'back': tr('Orqaga'),
              }, (v) => game.setCornerPlan(player, club.cornerPlans[player.id]?.first ?? 'near', v)),
            ],
          ),
      ])),
      const SizedBox(height: 12),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile(contentPadding: EdgeInsets.zero, value: enabled,
          title: Text(tr('Avtomatik match ko‘rsatmasi'), style: AppText.bodyStrong),
          subtitle: Text(tr('Shartlar bajarilganda bir marta qo‘llanadi'), style: AppText.caption),
          onChanged: (v) => change('enabled', v)),
        if (enabled) ...[
          selector(tr('Daqiqadan boshlab'), '${rule['minute'] ?? 60}', {
            '30': "30'", '45': "45'", '60': "60'", '75': "75'", '85': "85'",
          }, (v) => change('minute', int.parse(v))),
          const SizedBox(height: 8),
          selector(tr('Hisob holati'), '${rule['score'] ?? 'any'}', {
            'any': tr('Har qanday hisob'), 'losing': tr('Yutqazayotganda'),
            'drawing': tr('Durangda'), 'winning': tr('Yutayotganda'),
          }, (v) => change('score', v)),
          const SizedBox(height: 8),
          selector(tr('Raqib uslubi'), '${rule['opponent'] ?? 'any'}', {
            'any': tr('Har qanday uslub'), for (final s in TeamPlaystyle.values) s.name: s.displayName,
          }, (v) => change('opponent', v)),
          const SizedBox(height: 8),
          selector(tr('Qo‘llanadigan taktika'), '${rule['action'] ?? 'press'}', {
            'press': tr('Yuqori pressing'), 'attack': tr('Hujumni kuchaytirish'),
            'defend': tr('Himoyani mustahkamlash'), 'wide': tr('Qanotdan hujum'),
          }, (v) => change('action', v)),
        ],
      ])),
    ]);
  }
}
