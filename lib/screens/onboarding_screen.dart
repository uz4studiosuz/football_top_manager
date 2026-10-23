import 'package:flutter/material.dart';
import '../models/manager_profile.dart';
import '../ui/face_avatar.dart';
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
  FaceConfig face = FaceConfig.seed('new_manager');
  ManagerPhilosophy philosophy = ManagerPhilosophy.possession;
  static const countries = {
    'O‘zbekiston': '🇺🇿',
    'Angliya': '🏴',
    'Ispaniya': '🇪🇸',
    'Italiya': '🇮🇹',
    'Germaniya': '🇩🇪',
    'Fransiya': '🇫🇷',
    'Braziliya': '🇧🇷',
    'Argentina': '🇦🇷',
  };
  static const titles = [
    'Menejer Karyerasi',
    'O‘z portretingiz',
    'O‘yin falsafasi',
    'Klubingizni tanlang',
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
      title: const Text(
        'FOOTBALL TOP MANAGER 2027',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
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
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KARYERA YARATISH  ·  ${step + 1} / 4',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF637184),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      titles[step],
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: List.generate(
                        4,
                        (i) => Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.only(right: 5),
                            color: i <= step
                                ? const Color(0xFF1769E0)
                                : const Color(0xFFDAE1EB),
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
                      padding: const EdgeInsets.all(24),
                      children: [
                        const Text(
                          'Avval menejer haqidagi ma’lumotlar. Keyingi bosqichda yuzingizni yaratasiz.',
                          style: TextStyle(
                            color: Color(0xFF637184),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Ism va familiya',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().length < 2
                              ? 'Kamida ikki belgi kiriting'
                              : null,
                        ),
                        const SizedBox(height: 24),
                        DropdownButtonFormField<String>(
                          initialValue: nationality,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Millatingiz',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final country in countries.keys)
                              DropdownMenuItem(
                                value: country,
                                child: Text(country),
                              ),
                          ],
                          onChanged: (v) => setState(() => nationality = v!),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Yosh: $age',
                          style: const TextStyle(fontWeight: FontWeight.w600),
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
                  1 => FaceStudio(
                    value: face,
                    onChanged: (v) => setState(() => face = v),
                  ),
                  2 => ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Text(
                        'Har bir yangi menejer barcha uslublarda 70 reytingdan boshlaydi. Tanlov afzal falsafangizni belgilaydi; har besh uchrashuv amaldagi uslubni rivojlantiradi.',
                        style: TextStyle(color: Color(0xFF637184), height: 1.6),
                      ),
                      const SizedBox(height: 20),
                      for (final p in ManagerPhilosophy.values)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: philosophy == p
                                ? const Color(0xFFE7F0FF)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Icon(
                                p.icon,
                                color: const Color(0xFF1769E0),
                              ),
                              title: Text(
                                p.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                p.description,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                              trailing: const Text(
                                '70',
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1769E0),
                                ),
                              ),
                              onTap: () => setState(() => philosophy = p),
                            ),
                          ),
                        ),
                    ],
                  ),
                  _ => ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Row(
                        children: [
                          FaceAvatar(
                            config: face,
                            size: 68,
                            shirt: const Color(0xFF34475E),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _name.text,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text('$nationality · $age yosh'),
                                const SizedBox(height: 6),
                                Text(
                                  '${philosophy.title} · 70',
                                  style: const TextStyle(
                                    color: Color(0xFF1769E0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _clubChoice(
                        'YANGI KLUB YARATISH',
                        'Nom, stadion va emblema. Tarkib yangi ismlar bilan yaratiladi.',
                        Icons.add_moderator_outlined,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => CustomClubCreatorScreen(
                              managerProfile: profile(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _clubChoice(
                        'MAVJUD TOP KLUBNI TANLASH',
                        'Sakkiz klubdan birini tanlang va mavsumni boshlang.',
                        Icons.shield_outlined,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ClubSelectionScreen(managerProfile: profile()),
                          ),
                        ),
                      ),
                    ],
                  ),
                },
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: step > 0
                            ? () => setState(() => step--)
                            : null,
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Orqaga'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (step < 3)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: next,
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Davom etish'),
                          ),
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
  Widget _clubChoice(
    String title,
    String text,
    IconData icon,
    VoidCallback action,
  ) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: action,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF1769E0), size: 28),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(color: Color(0xFF637184), height: 1.5),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerRight,
              child: Icon(Icons.arrow_forward, color: Color(0xFF1769E0)),
            ),
          ],
        ),
      ),
    ),
  );
}
