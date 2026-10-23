import 'onboarding_screen.dart';
import 'package:flutter/material.dart';
import '../services/game_state.dart';
import '../models/manager_profile.dart';
import '../ui/face_avatar.dart';

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
        content: const Text(
          'Joriy karyera yakunlanadi. Yangi menejer va klub yaratasiz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(
                  builder: (_) => const OnboardingScreen(),
                ),
                (route) => false,
              );
            },
            child: const Text('Yangi karyera'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = GameState(), m = GameState().managerProfile;
    return Scaffold(
      appBar: AppBar(title: const Text('Menejer profili')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: FaceAvatar(
              config: m.face,
              size: 130,
              shirt: const Color(0xFF34475E),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            m.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${m.nationality} · ${m.age} yosh',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF637184)),
          ),
          Center(
            child: TextButton.icon(
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
          ),
          const SizedBox(height: 24),
          const Text(
            'Falsafa reytinglari',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Yangi menejer: barcha uslublar 70. Har besh uchrashuvda amaldagi uslub +1.',
            style: TextStyle(color: Color(0xFF637184), height: 1.5),
          ),
          const SizedBox(height: 20),
          for (final p in ManagerPhilosophy.values)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(p.icon, size: 20, color: const Color(0xFF1769E0)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          p.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${m.proficiency[p]}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1769E0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: m.proficiency[p]! / 100,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFE9EEF5),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Text(
            '${m.matchesManaged} uchrashuv · ${m.wins} g‘alaba · ${m.draws} durang · ${m.losses} mag‘lubiyat',
            style: const TextStyle(color: Color(0xFF637184)),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _newCareer,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Yangi karyera'),
          ),
        ],
      ),
    );
  }
}
