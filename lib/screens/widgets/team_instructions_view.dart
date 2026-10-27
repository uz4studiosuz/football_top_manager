import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../models/manager_profile.dart';
import '../../models/player.dart';
import '../../services/game_state.dart';
import '../../ui/face_avatar.dart';
import '../../ui/widgets.dart';
import '../../l10n/l10n.dart';
import 'strategy_planner.dart';

/// Team tactics in eFootball terms: playstyle, attack, defence and extras.
class TeamTacticsView extends StatelessWidget {
  const TeamTacticsView({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette tokens when appearance changes.
    final game = GameState();
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        if (!game.isInitialized) return const SizedBox();
        final t = game.userClub.tactics;
        void set(TeamTactics v) => game.updateTactics(v);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const StrategyPlanner(),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SectionHeader(tr('Jamoa o‘yin uslubi'), icon: Icons.psychology_outlined),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Text(
                          tr('Menejerning shu uslubdagi tajribasi pas aniqligi va qarorlarga ta’sir qiladi.'),
                          style: AppText.caption,
                        ),
                      ),
                      for (final style in TeamPlaystyle.values)
                        Material(
                          color: t.playstyle == style ? AppColors.primarySoft : Colors.transparent,
                          child: ListTile(
                            leading: Icon(style.icon, color: AppColors.primary),
                            title: Text(style.displayName),
                            subtitle: Text(style.description),
                            trailing: Text(
                              game.managerProfile.mastery(ManagerPhilosophy.forStyle(style)),
                              style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                            onTap: () => set(t.copyWith(playstyle: style)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(tr('Hujum'), icon: Icons.north_east_rounded),
                      _segment<BuildUpStyle>(
                        'Hujum qurilishi',
                        BuildUpStyle.values,
                        t.buildUp,
                        (v) => v.label,
                        (v) => set(t.copyWith(buildUp: v, playOutFromBack: v != BuildUpStyle.long)),
                      ),
                      _segment<AttackingArea>(
                        'Hujum hududi',
                        AttackingArea.values,
                        t.attackingArea,
                        (v) => v.label,
                        (v) => set(t.copyWith(attackingArea: v)),
                      ),
                      _slider(tr('Hujum intensivligi'), 'Ehtiyotkor', tr('Ko‘p yugurish'), t.attackingIntensity,
                          (v) => set(t.copyWith(attackingIntensity: v))),
                      _slider(tr('Temp'), 'Sekin', 'Tezkor', t.tempo, (v) => set(t.copyWith(tempo: v))),
                      _slider(tr('Qanot kengligi'), 'Tor', 'Keng', t.width, (v) => set(t.copyWith(width: v))),
                      _switch(tr('Erkin pozitsiyalash'), tr('O‘yinchilar sxemadan chiqib bo‘shliq qidiradi'),
                          t.flexiblePositioning, (v) => set(t.copyWith(flexiblePositioning: v))),
                      _switch(tr('Himoyadan qisqa pas'), tr('Darvozabon uzun to‘p o‘rniga himoyachiga beradi'),
                          t.playOutFromBack, (v) => set(t.copyWith(playOutFromBack: v))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(tr('Himoya'), icon: Icons.shield_outlined),
                      _segment<DefensiveApproach>(
                        'Himoya yondashuvi',
                        DefensiveApproach.values,
                        t.defensiveApproach,
                        (v) => v.label,
                        (v) => set(t.copyWith(defensiveApproach: v)),
                      ),
                      _segment<ContainmentArea>(
                        'Qamal hududi',
                        ContainmentArea.values,
                        t.containment,
                        (v) => v.label,
                        (v) => set(t.copyWith(containment: v)),
                      ),
                      _slider(tr('Himoya chizig‘i'), 'Past blok', 'Baland chiziq', t.defensiveLine,
                          (v) => set(t.copyWith(defensiveLine: v))),
                      _slider(tr('Ixchamlik'), 'Keng', 'Zich', t.compactness, (v) => set(t.copyWith(compactness: v))),
                      _slider(tr('Pressing'), tr('Kutish'), 'Agressiv', t.pressing, (v) => set(t.copyWith(pressing: v))),
                      _switch(tr('Yo‘qotishdan keyin pressing'), tr('Ko‘proq bosim, ko‘proq charchoq'), t.counterPress,
                          (v) => set(t.copyWith(counterPress: v))),
                      _switch(tr('Ofsayd tuzog‘i'), tr('Ko‘proq ofsayd, lekin orqaga uzatmaga zaif'), t.offsideTrap,
                          (v) => set(t.copyWith(offsideTrap: v))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(tr('O‘yin boshqaruvi'), icon: Icons.timer_outlined),
                      _switch(tr('Vaqtni cho‘zish'), tr('Oldinda bo‘lsa 75-daqiqadan keyin o‘yinni sekinlashtiradi'),
                          t.timeWasting, (v) => set(t.copyWith(timeWasting: v))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _segment<T>(String label, List<T> values, T selected, String Function(T) text, ValueChanged<T> onTap) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(tr(label), style: AppText.bodyStrong)),
                _Info(label),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<T>(
                showSelectedIcon: false,
                segments: [
                  for (final v in values)
                    ButtonSegment(
                      value: v,
                      label: FittedBox(fit: BoxFit.scaleDown, child: Text(text(v))),
                    ),
                ],
                selected: {selected},
                onSelectionChanged: (s) => onTap(s.first),
              ),
            ),
          ],
        ),
      );

  Widget _slider(String label, String low, String high, int value, ValueChanged<int> onChanged) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(tr(label), style: AppText.bodyStrong)),
            _Info(label),
            Text('$value / 5', style: AppText.number.copyWith(fontSize: 13, color: AppColors.primary)),
          ],
        ),
        Slider(
          min: 1,
          max: 5,
          divisions: 4,
          value: value.toDouble(),
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
        Row(
          children: [
            Expanded(child: Text(tr(low), style: AppText.caption)),
            Text(tr(high), style: AppText.caption),
          ],
        ),
      ],
    ),
  );

  Widget _switch(String title, String subtitle, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Row(
      children: [
        Flexible(child: Text(tr(title), style: AppText.bodyStrong)),
        _Info(title),
      ],
    ),
    subtitle: Text(subtitle, style: AppText.caption),
    value: value,
    onChanged: onChanged,
  );
}

/// What each team setting does, for players new to tactics. Keys are the
/// Uzbek setting names (translated labels are looked up the same way).
const _help = <String, String>{
  'Hujum qurilishi': 'Qisqa – himoyadan pas bilan chiqish: to‘p nazorati yuqori, lekin o‘z yarmingizda to‘p yo‘qotish xavfi bor. Uzun – to‘p tezda oldinga uzatiladi: xavf kam, lekin to‘p tez-tez yo‘qotiladi. Aralash – vaziyatga qarab.',
  'Hujum hududi': 'Qanotlar – hujum qanotdan, krosslar ko‘payadi. Markaz – qisqa paslar va markazdan yorib kirish. Muvozanatli – ikkalasi aralash.',
  'Hujum intensivligi': 'Hujumga nechta futbolchi qo‘shilishi. Yuqori qiymat – ko‘proq zarba va imkoniyat, lekin orqada bo‘shliq qoladi va raqib qarshi hujumiga zaif bo‘lasiz.',
  'Temp': 'Jamoa qanchalik tez qaror qabul qiladi. Tez – ko‘proq hujum, lekin paslar aniqligi pasayadi va futbolchilar tezroq charchaydi. Sekin – to‘p nazorati va aniq paslar.',
  'Qanot kengligi': 'Hujumda futbolchilar qanchalik keng joylashadi. Keng – raqib himoyasi cho‘ziladi, qanotdan kross ko‘p. Tor – markazda ko‘proq odam, qisqa paslar.',
  'Erkin pozitsiyalash': 'Yoqilsa futbolchilar o‘z joyidan chiqib bo‘sh joy qidiradi: raqib uchun kutilmagan, lekin himoyaga qaytish sekinlashadi.',
  'Himoyadan qisqa pas': 'Darvozabon to‘pni himoyachiga beradi va hujum orqadan quriladi. O‘chirilsa darvozabon uzun uradi – xavfsizroq, lekin to‘p ko‘pincha yo‘qotiladi.',
  'Himoya yondashuvi': 'Frontline Pressure – raqibni yuqorida siqish. Muvozanat – o‘rtacha. All-out Defence – hamma orqada, gol o‘tkazish qiyin, lekin hujum sust.',
  'Qamal hududi': 'Raqibni qayerga yo‘naltirish. Markazni yopish – raqib qanotga chiqishga majbur. Qanotlarni yopish – raqib markazdan o‘ynaydi.',
  'Himoya chizig‘i': 'Himoyachilar qanchalik yuqorida turadi. Baland chiziq – jamoa ixcham, raqib ofsaydga ko‘p tushadi, lekin himoya ortiga uzun pasga zaif. Past blok – orqada xavfsiz, lekin raqib ko‘proq to‘p nazorat qiladi.',
  'Ixchamlik': 'Futbolchilar orasidagi masofa. Zich – markazda bo‘shliq kam, lekin qanotlar ochiladi. Keng – maydonni ko‘proq yopadi, lekin chiziqlar orasida bo‘shliq qoladi.',
  'Pressing': 'To‘p egasiga qanchalik tez va ko‘p bosim qilinadi. Agressiv – to‘pni yuqorida qaytarib olish ko‘payadi, lekin charchoq va qoidabuzarlik ham ko‘payadi.',
  'Yo‘qotishdan keyin pressing': 'To‘p yo‘qotilgan zahoti uni qaytarib olishga urinish (gegenpress). Raqib qarshi hujumi qiyinlashadi, lekin futbolchilar tez charchaydi.',
  'Ofsayd tuzog‘i': 'Himoyachilar bir chiziqda oldinga chiqib hujumchini ofsaydda qoldiradi. Ko‘p ofsayd beradi, lekin xato bo‘lsa raqib darvozabon bilan yakkama-yakka qoladi.',
  'Vaqtni cho‘zish': 'Hisobda oldinda bo‘lsangiz 75-daqiqadan keyin jamoa o‘yinni sekinlashtiradi: kamroq xavf, lekin sariq kartochka ehtimoli oshadi.',
};

class _Info extends StatelessWidget {
  final String label;
  const _Info(this.label);
  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette tokens when appearance changes.
    // Callers pass either the Uzbek key or an already translated label.
    final key = _help.keys.where((k) => k == label || tr(k) == label).firstOrNull;
    if (key == null) return const SizedBox.shrink();
    final text = _help[key]!;
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: tr('Bu nima?'),
      icon: Icon(Icons.info_outline_rounded, size: 18, color: AppColors.ink3),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tr(key), style: AppText.h3)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(tr(text), style: AppText.body.copyWith(height: 1.45)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Captain, set-piece takers and per-player instructions for the XI.
class IndividualInstructionsView extends StatelessWidget {
  const IndividualInstructionsView({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette tokens when appearance changes.
    final game = GameState();
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        if (!game.isInitialized) return const SizedBox();
        final c = game.userClub;
        final xi = c.startingXI;
        // Each role lists the XI by the attribute that matters for it; the
        // two best candidates carry a star.
        Widget picker(String label, IconData icon, String? value, ValueChanged<String?> onChanged, int Function(Player) score) {
          final ranked = List<Player>.of(xi)..sort((a, b) => score(b).compareTo(score(a)));
          return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: DropdownButtonFormField<String?>(
            initialValue: xi.any((p) => p.id == value) ? value : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(tr('Avtomatik (eng yaxshisi)'))),
              for (var i = 0; i < ranked.length; i++)
                DropdownMenuItem<String?>(
                  value: ranked[i].id,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        child: i < 2 ? const Icon(Icons.star_rounded, size: 16, color: AppColors.gold) : null,
                      ),
                      Expanded(
                        child: Text('${ranked[i].shortName} · ${ranked[i].mainPosition.code}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      ValueBadge(score(ranked[i]), size: 24),
                    ],
                  ),
                ),
            ],
            onChanged: (v) {
              onChanged(v);
              game.touch();
            },
          ),
        );
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(tr('Kapitan va standart vaziyatlar'), icon: Icons.flag_outlined),
                      picker(tr('Kapitan'), Icons.copyright_rounded, c.captainId, (v) => c.captainId = v, (p) {
                        // Leadership: character, experience and standing in the team.
                        final leader = p.personality == Personality.leader ? 12 : p.personality == Personality.professional ? 5 : 0;
                        return (p.ovr * 0.6 + min(p.age, 33) + leader).round().clamp(40, 99);
                      }),
                      picker(tr('Burchak ijrochisi'), Icons.flag_circle_outlined, c.cornerTakerId, (v) => c.cornerTakerId = v,
                          (p) => ((p.stats.curl + p.stats.loftedPass + p.stats.setPieceTaking) / 3).round()),
                      picker(tr('Jarima zarbasi ijrochisi'), Icons.adjust_rounded, c.freeKickTakerId, (v) => c.freeKickTakerId = v,
                          (p) => ((p.stats.setPieceTaking * 2 + p.stats.curl + p.stats.kickingPower) / 4).round()),
                      picker(tr('Penalti ijrochisi'), Icons.radio_button_checked, c.penaltyTakerId, (v) => c.penaltyTakerId = v,
                          (p) => ((p.stats.setPieceTaking + p.stats.finishing * 2 + p.stats.kickingPower) / 4).round()),
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
                        child: SectionHeader(tr('Individual ko‘rsatmalar'), icon: Icons.person_pin_circle_outlined),
                      ),
                      for (final p in xi) _InstructionRow(player: p, club: c),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(tr('Ko‘rsatmalar lug‘ati'), icon: Icons.menu_book_outlined),
                      for (final i in PlayerInstruction.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                i.offence ? Icons.north_east_rounded : Icons.shield_outlined,
                                size: 16,
                                color: i.offence ? AppColors.win : AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: '${i.label}: ', style: AppText.bodyStrong.copyWith(fontSize: 13)),
                                      TextSpan(text: i.description, style: AppText.small),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InstructionRow extends StatelessWidget {
  final Player player;
  final Club club;
  const _InstructionRow({required this.player, required this.club});
  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette tokens when appearance changes.
    final game = GameState();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          FaceAvatar(config: player.face, size: 34, shirt: club.primaryColor, circle: true),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.shortName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong.copyWith(fontSize: 13)),
                Text(player.playingStyle.title, style: AppText.caption),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: DropdownButton<PlayerInstruction>(
              value: player.instruction,
              isExpanded: true,
              underline: const SizedBox(),
              items: [
                for (final i in PlayerInstruction.forPosition(
                  club.startingLineupIds.contains(player.id) ? club.slotPosition(club.startingLineupIds.indexOf(player.id)) : player.mainPosition,
                  keep: player.instruction,
                ))
                  DropdownMenuItem(
                    value: i,
                    child: Text(i.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                  ),
              ],
              onChanged: (v) {
                if (v != null) game.setPlayerInstruction(player, v);
              },
            ),
          ),
        ],
      ),
    );
  }
}
