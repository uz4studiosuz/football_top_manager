import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../models/player.dart';
import '../../services/game_state.dart';
import '../../ui/face_avatar.dart';
import '../../ui/widgets.dart';
import '../../l10n/l10n.dart';

/// Team tactics in eFootball terms: playstyle, attack, defence and extras.
class TeamTacticsView extends StatelessWidget {
  const TeamTacticsView({super.key});

  @override
  Widget build(BuildContext context) {
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
                          tr('Menejer reytingi shu uslubdagi pas aniqligi va qarorlarga bevosita ta’sir qiladi.'),
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
                            trailing: ValueBadge(
                              game.managerProfile.ratingFor(style),
                              size: 32,
                              filled: t.playstyle == style,
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
            Text(tr(label), style: AppText.bodyStrong),
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
            Expanded(child: Text(low, style: AppText.caption)),
            Text(high, style: AppText.caption),
          ],
        ),
      ],
    ),
  );

  Widget _switch(String title, String subtitle, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(tr(title), style: AppText.bodyStrong),
    subtitle: Text(subtitle, style: AppText.caption),
    value: value,
    onChanged: onChanged,
  );
}

/// Captain, set-piece takers and per-player instructions for the XI.
class IndividualInstructionsView extends StatelessWidget {
  const IndividualInstructionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameState();
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        if (!game.isInitialized) return const SizedBox();
        final c = game.userClub;
        final xi = c.startingXI;
        Widget picker(String label, IconData icon, String? value, ValueChanged<String?> onChanged) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: DropdownButtonFormField<String?>(
            initialValue: xi.any((p) => p.id == value) ? value : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(tr('Avtomatik (eng yaxshisi)'))),
              for (final p in xi)
                DropdownMenuItem<String?>(value: p.id, child: Text('${p.shortName} · ${p.mainPosition.code}')),
            ],
            onChanged: (v) {
              onChanged(v);
              game.touch();
            },
          ),
        );
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
                      picker(tr('Kapitan'), Icons.copyright_rounded, c.captainId, (v) => c.captainId = v),
                      picker(tr('Burchak ijrochisi'), Icons.flag_circle_outlined, c.cornerTakerId, (v) => c.cornerTakerId = v),
                      picker(tr('Jarima zarbasi ijrochisi'), Icons.adjust_rounded, c.freeKickTakerId, (v) => c.freeKickTakerId = v),
                      picker(tr('Penalti ijrochisi'), Icons.radio_button_checked, c.penaltyTakerId, (v) => c.penaltyTakerId = v),
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
                for (final i in PlayerInstruction.values)
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
