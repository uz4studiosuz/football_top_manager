import 'onboarding_screen.dart';
import 'package:flutter/material.dart';
import '../services/game_state.dart';
import '../models/club.dart';
import '../models/manager_profile.dart';
import '../ui/face_avatar.dart';
import '../ui/widgets.dart';
import '../services/save_service.dart';

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
        title: const Text('Yangi karyera boshlash'),
        content: const Text('Joriy karyera yakunlanadi. Yangi menejer va klub yaratasiz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => const OnboardingScreen()),
                (route) => false,
              );
            },
            child: const Text('Yangi karyera'),
          ),
        ],
      ),
    );
  }

  void _logout() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chiqish va tozalash'),
        content: const Text('Saqlangan karyera butunlay o‘chiriladi. Bu amalni qaytarib bo‘lmaydi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish')),
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
                MaterialPageRoute<void>(builder: (_) => const OnboardingScreen()),
                (route) => false,
              );
            },
            child: const Text('O‘chirish'),
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
      appBar: AppBar(title: const Text('Menejer profili')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          AppCard(
            child: Column(
              children: [
                FaceAvatar(config: m.face, size: 120, shirt: const Color(0xFF2B3A55)),
                const SizedBox(height: 12),
                Text(m.name, style: AppText.h1),
                const SizedBox(height: 4),
                Text('${m.countryFlag} ${m.nationality} · ${m.age} yosh', style: AppText.small),
                if (club != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClubCrestWidget(config: club.crestConfig, size: 20),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${club.name} bosh murabbiyi',
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
                    final v = await editFace(context, m.face);
                    if (v != null && mounted) {
                      game.updateManagerProfile(m.copyWith(face: v));
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.face_outlined),
                  label: const Text('Yuzni tahrirlash'),
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(child: StatTile('${m.matchesManaged}', 'O‘yin')),
                    Expanded(child: StatTile('${m.wins}', 'G‘alaba', color: AppColors.win)),
                    Expanded(child: StatTile('${m.draws}', 'Durang')),
                    Expanded(child: StatTile('${m.losses}', 'Mag‘lubiyat', color: AppColors.loss)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: StatTile('${m.winRate.toStringAsFixed(0)}%', 'G‘alaba foizi')),
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
                const SectionHeader('Falsafa reytinglari', icon: Icons.psychology_outlined),
                const Text(
                  'Har besh uchrashuvda amaldagi uslub +1 ga o‘sadi. Reyting pas aniqligi va jamoa qarorlariga ta’sir qiladi.',
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
                const SectionHeader('Karyera', icon: Icons.save_outlined),
                const Text(
                  'Karyera har bir o‘zgarishdan keyin avtomatik saqlanadi (telefon va brauzerda).',
                  style: AppText.caption,
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await SaveService.save();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Karyera saqlandi')),
                      );
                    }
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Hozir saqlash'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _newCareer,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Yangi karyera'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.live),
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Chiqish va saqlanganni tozalash'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
