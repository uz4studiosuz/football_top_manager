import 'onboarding_screen.dart';
import 'package:flutter/material.dart';
import '../services/game_state.dart';
import '../models/club.dart';
import '../models/manager_profile.dart';
import '../ui/face_avatar.dart';
import '../ui/widgets.dart';
import '../services/save_service.dart';
import '../l10n/l10n.dart';
import '../ui/language_picker.dart';
import 'db_editor_screen.dart';
import 'save_slots_screen.dart';

class ManagerProfileScreen extends StatefulWidget {
  const ManagerProfileScreen({super.key});
  @override
  State<ManagerProfileScreen> createState() => _ManagerProfileScreenState();
}

class _ManagerProfileScreenState extends State<ManagerProfileScreen> {
  void _newCareer() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Yangi karyera boshlash')),
        content: Text(tr('Joriy karyera yakunlanadi. Yangi menejer va klub yaratasiz.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Bekor qilish'))),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => OnboardingScreen()),
                (route) => false,
              );
            },
            child: Text(tr('Yangi karyera')),
          ),
        ],
      ),
    );
  }

  void _logout() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Chiqish va tozalash')),
        content: Text(tr('Saqlangan karyera butunlay o‘chiriladi. Bu amalni qaytarib bo‘lmaydi.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Bekor qilish'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.live),
            onPressed: () async {
              Navigator.pop(ctx);
              SaveService.enabled = false;
              await SaveService.clear();
              GameState().resetCareer();
              SaveService.enabled = true;
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => OnboardingScreen()),
                (route) => false,
              );
            },
            child: Text(tr('O‘chirish')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = GameState(), m = game.managerProfile;
    final club = game.isInitialized ? game.userClub : null;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Menejer profili'))),
      body: PageWidth(
      maxWidth: 860,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          AppCard(
            child: Column(
              children: [
                FaceAvatar(config: m.face, size: 120, shirt: const Color(0xFF2B3A55)),
                const SizedBox(height: 12),
                Text(m.name, style: AppText.h1),
                const SizedBox(height: 4),
                Text(trf('{0} {1} · {2} yosh', [m.countryFlag, tr(m.nationality), m.age]), style: AppText.small),
                if (club != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClubCrestWidget(config: club.crestConfig, size: 20),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          trf('{0} bosh murabbiyi', [club.name]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.small,
                        ),
                      ),
                    ],
                  ),
                ],
                TextButton.icon(
                  onPressed: () async {
                    final v = await editFace(context, m.face, nationality: m.nationality, age: m.age);
                    if (v != null && mounted) {
                      game.updateManagerProfile(m.copyWith(face: v));
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.face_outlined),
                  label: Text(tr('Yuzni tahrirlash')),
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(child: StatTile('${m.matchesManaged}', tr('O‘yin'))),
                    Expanded(child: StatTile('${m.wins}', tr('G‘alaba'), color: AppColors.win)),
                    Expanded(child: StatTile('${m.draws}', 'Durang')),
                    Expanded(child: StatTile('${m.losses}', tr('Mag‘lubiyat'), color: AppColors.loss)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: StatTile('${m.winRate.toStringAsFixed(0)}%', tr('G‘alaba foizi'))),
                    Expanded(child: StatTile('${m.trophies}', 'Kubok', color: AppColors.gold)),
                    Expanded(child: StatTile(m.reputationRank, 'Maqom')),
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
                SectionHeader(tr('Menejer reytingi'), icon: Icons.trending_up_rounded),
                Row(
                  children: [
                    Text('${m.reputation.round()}', style: AppText.h2.copyWith(color: AppColors.primary)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(m.reputationLevel, style: AppText.bodyStrong)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: m.reputation / 100,
                    minHeight: 8,
                    backgroundColor: AppColors.line,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  trf('Kutilganidan yaxshi natijalar (kuchliroq raqiblarni yutish, jadvalda yuqoriroq o‘rin, kuboklar) reytingni oshiradi. Mavsum oxirida obro‘si taxminan {0} bo‘lgan klublar – dunyoning istalgan ligasidan – ish taklif qiladi.', [GameState.jobLevel(m.reputation).round()]),
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(tr('Falsafa reytinglari'), icon: Icons.psychology_outlined),
                Text(
                  tr('Har besh uchrashuvda amaldagi uslub +1 ga o‘sadi. Reyting pas aniqligi va jamoa qarorlariga ta’sir qiladi.'),
                  style: AppText.caption,
                ),
                const SizedBox(height: 8),
                for (final p in ManagerPhilosophy.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(p.icon, size: 20, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.title, style: AppText.bodyStrong.copyWith(fontSize: 13)),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: m.proficiency[p]! / 100,
                                  minHeight: 6,
                                  color: AppColors.attribute(m.proficiency[p]!),
                                  backgroundColor: AppColors.surfaceAlt,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ValueBadge(m.proficiency[p]!, size: 32),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(tr('Til'), icon: Icons.language_rounded),
                const SingleChildScrollView(scrollDirection: Axis.horizontal, child: LanguageSelector()),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(tr('Karyera'), icon: Icons.save_outlined),
                Text(
                  tr('Karyera har bir o‘zgarishdan keyin avtomatik saqlanadi (telefon va brauzerda).'),
                  style: AppText.caption,
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await SaveService.save();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('Karyera saqlandi'))),
                      );
                    }
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: Text(tr('Hozir saqlash')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _newCareer,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(tr('Yangi karyera')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const SaveSlotsScreen()),
                  ),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(tr('Saqlash slotlari')),
                ),
                const SizedBox(height: 8),
                // Creator tool (also at /editor in the browser).
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const DbEditorScreen()),
                  ),
                  icon: const Icon(Icons.storage_rounded),
                  label: Text(tr('Baza muharriri')),
                ),
                const SizedBox(height: 8),
                // Open-source licences of the packages and fonts the app uses.
                OutlinedButton.icon(
                  onPressed: () => showLicensePage(context: context, applicationName: 'Football Top Manager'),
                  icon: const Icon(Icons.description_outlined),
                  label: Text(tr('Litsenziyalar')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.live),
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(tr('Chiqish va saqlanganni tozalash')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
    );
  }
}
