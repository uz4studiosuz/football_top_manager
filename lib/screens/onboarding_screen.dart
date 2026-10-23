import 'package:flutter/material.dart';
import '../models/manager_profile.dart';
import '../ui/face_avatar.dart';
import '../ui/widgets.dart';
import 'club_selection_screen.dart';
import 'custom_club_creator_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController(text: 'Azizbek Rahimov');
  final _form = GlobalKey<FormState>();
  int step = 0, age = 35;
  String nationality = 'O‘zbekiston';
  FaceConfig face = FaceConfig.forPlayer('new_manager', 'O‘zbekiston', 35);
  ManagerPhilosophy philosophy = ManagerPhilosophy.possession;
  static const countries = {
    'O‘zbekiston': '🇺🇿',
    'Qozog‘iston': '🇰🇿',
    'Angliya': '🏴',
    'Ispaniya': '🇪🇸',
    'Italiya': '🇮🇹',
    'Germaniya': '🇩🇪',
    'Fransiya': '🇫🇷',
    'Portugaliya': '🇵🇹',
    'Niderlandiya': '🇳🇱',
    'Braziliya': '🇧🇷',
    'Argentina': '🇦🇷',
    'Turkiya': '🇹🇷',
  };
  static const titles = [
    'Menejer Karyerasi',
    'O‘z portretingiz',
    'O‘yin falsafasi',
    'Klubingizni tanlang',
  ];
  static const subtitles = [
    'Ism, millat va yosh – karyerangiz shu yerdan boshlanadi.',
    'Yuz shakli, soch, soqol va detallarni sozlang.',
    'Har bir uslub 70 dan boshlanadi va o‘yinlar bilan o‘sadi.',
    'Mavjud klubni boshqaring yoki o‘zingiznikini yarating.',
  ];
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  ManagerProfile profile() => ManagerProfile(
    name: _name.text.trim(),
    nationality: nationality,
    countryFlag: countries[nationality]!,
    age: age,
    face: face,
    philosophy: philosophy,
  );

  void next() {
    if (step == 0 && !_form.currentState!.validate()) return;
    setState(() => step++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(
        children: [
          Icon(Icons.sports_soccer, color: AppColors.primary),
          SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'FOOTBALL TOP MANAGER 2027',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6),
              ),
            ),
          ),
        ],
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('KARYERA YARATISH  ·  ${step + 1} / 4', style: AppText.overline),
                    const SizedBox(height: 8),
                    Text(titles[step], style: AppText.h1.copyWith(fontSize: 26)),
                    const SizedBox(height: 4),
                    Text(subtitles[step], style: AppText.small),
                    const SizedBox(height: 14),
                    Row(
                      children: List.generate(
                        4,
                        (i) => Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            height: 4,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              color: i <= step ? AppColors.primary : AppColors.line,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: switch (step) {
                  0 => Form(
                    key: _form,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _name,
                                decoration: const InputDecoration(
                                  labelText: 'Ism va familiya',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (v) => v == null || v.trim().length < 2 ? 'Kamida ikki belgi kiriting' : null,
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                initialValue: nationality,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Millatingiz',
                                  prefixIcon: Icon(Icons.flag_outlined),
                                ),
                                items: [
                                  for (final country in countries.keys)
                                    DropdownMenuItem(value: country, child: Text('${countries[country]}  $country')),
                                ],
                                onChanged: (v) => setState(() => nationality = v!),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  const Text('Yosh', style: AppText.bodyStrong),
                                  const Spacer(),
                                  Text('$age', style: AppText.number.copyWith(fontSize: 18, color: AppColors.primary)),
                                ],
                              ),
                              Slider(
                                value: age.toDouble(),
                                min: 18,
                                max: 80,
                                divisions: 62,
                                label: '$age',
                                onChanged: (v) => setState(() => age = v.round()),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  1 => FaceStudio(value: face, onChanged: (v) => setState(() => face = v)),
                  2 => ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final p in ManagerPhilosophy.values)
                        AppCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          color: philosophy == p ? AppColors.primarySoft : AppColors.surface,
                          onTap: () => setState(() => philosophy = p),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: philosophy == p ? AppColors.primary : AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(p.icon, color: philosophy == p ? Colors.white : AppColors.primary),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.title, style: AppText.bodyStrong),
                                    const SizedBox(height: 3),
                                    Text(p.description, style: AppText.small),
                                  ],
                                ),
                              ),
                              const ValueBadge(70, size: 34, filled: false),
                            ],
                          ),
                        ),
                    ],
                  ),
                  _ => ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      AppCard(
                        child: Row(
                          children: [
                            FaceAvatar(config: face, size: 72, shirt: const Color(0xFF2B3A55)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_name.text, style: AppText.h2),
                                  const SizedBox(height: 4),
                                  Text('${countries[nationality]} $nationality · $age yosh', style: AppText.small),
                                  const SizedBox(height: 4),
                                  Text('${philosophy.title} · 70', style: AppText.small.copyWith(color: AppColors.primary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _clubChoice(
                        'MAVJUD TOP KLUBNI TANLASH',
                        'Sakkiz yevropa giganti: 23 kishilik tarkib, haqiqiy taqvim va kengash maqsadlari.',
                        Icons.shield_outlined,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(builder: (_) => ClubSelectionScreen(managerProfile: profile())),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _clubChoice(
                        'YANGI KLUB YARATISH',
                        'Nom, stadion va emblema. Tarkib yangi ismlar bilan yaratiladi.',
                        Icons.add_moderator_outlined,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(builder: (_) => CustomClubCreatorScreen(managerProfile: profile())),
                        ),
                      ),
                    ],
                  ),
                },
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: step > 0 ? () => setState(() => step--) : null,
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Orqaga')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (step < 3)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: next,
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Davom etish')),
                        ),
                      )
                    else
                      const Spacer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _clubChoice(String title, String text, IconData icon, VoidCallback action) => AppCard(
    onTap: action,
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: AppColors.primary, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.h3),
              const SizedBox(height: 4),
              Text(text, style: AppText.small.copyWith(height: 1.4)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.ink3),
      ],
    ),
  );
}
