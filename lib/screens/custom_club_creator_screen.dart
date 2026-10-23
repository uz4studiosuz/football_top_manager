import 'dart:math';
import 'package:flutter/material.dart';
import '../models/club.dart';
import '../services/game_state.dart';
import 'main_navigation_screen.dart';
import '../models/manager_profile.dart';

/// Foydalanuvchi o'z jamoasini noldan yaratish ekrani
class CustomClubCreatorScreen extends StatefulWidget {
  final ManagerProfile? managerProfile;
  const CustomClubCreatorScreen({super.key, this.managerProfile});
  @override
  State<CustomClubCreatorScreen> createState() =>
      _CustomClubCreatorScreenState();
}

class _CustomClubCreatorScreenState extends State<CustomClubCreatorScreen> {
  final _nameController = TextEditingController(text: 'Toshkent Stars');
  final _shortNameController = TextEditingController(text: 'TKS');
  final _stadiumController = TextEditingController(text: 'Milliy Arena');
  int _stadiumCapacity = 45000;
  // Logo sozlamalari
  CrestShape _selectedShape = CrestShape.modernShield;
  CrestPattern _selectedPattern = CrestPattern.verticalStripes;
  Color _primaryColor = const Color(0xFF1769E0); // Emerald
  Color _secondaryColor = const Color(0xFF0F172A); // Dark Slate
  Color _trimColor = const Color(0xFFF59E0B); // Gold
  String _monogram = 'TS';
  final List<Color> _availableColors = const [
    Color(0xFF1769E0), // Emerald
    Color(0xFF3B82F6), // Electric Blue
    Color(0xFFEF4444), // Crimson Red
    Color(0xFFF59E0B), // Amber Gold
    Color(0xFF8B5CF6), // Purple
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEC4899), // Pink
    Color(0xFF1E293B), // Navy/Slate
    Color(0xFFFFFFFF), // White
    Color(0xFF000000), // Black
  ];
  @override
  void dispose() {
    _nameController.dispose();
    _shortNameController.dispose();
    _stadiumController.dispose();
    super.dispose();
  }

  ClubCrestConfig get _currentCrestConfig => ClubCrestConfig(
    shape: _selectedShape,
    pattern: _selectedPattern,
    primaryColor: _primaryColor,
    secondaryColor: _secondaryColor,
    trimColor: _trimColor,
    monogram: _monogram.isNotEmpty ? _monogram : 'FC',
    stars: 1,
  );
  void _createAndStart() {
    final name = _nameController.text.trim();
    final shortName = _shortNameController.text.trim();
    final stadium = _stadiumController.text.trim();
    if (name.isEmpty || shortName.isEmpty || stadium.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Iltimos, barcha maydonlarni to\'ldiring!'),
        ),
      );
      return;
    }
    GameState().startCareerWithCustomClub(
      name: name,
      shortName: shortName,
      stadiumName: stadium,
      stadiumCapacity: _stadiumCapacity,
      crestConfig: _currentCrestConfig,
      managerProfile: widget.managerProfile,
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  void _randomLogo() {
    final r = Random();
    setState(() {
      _selectedShape = CrestShape.values[r.nextInt(CrestShape.values.length)];
      _selectedPattern =
          CrestPattern.values[r.nextInt(CrestPattern.values.length)];
      final colors = List<Color>.of(_availableColors)..shuffle(r);
      _primaryColor = colors[0];
      _secondaryColor = colors[1];
      _trimColor = _primaryColor.computeLuminance() > 0.45
          ? const Color(0xFF192B42)
          : Colors.white;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8), // 60% Canvas
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF), // 30% Surface
        elevation: 0,
        title: const Text(
          'Yangi Jamoa Yaratish',
          style: TextStyle(
            color: Color(0xFF192B42),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Jonli Vektor Logo Preview Kartasi
            _buildLiveLogoPreview(),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                onPressed: _randomLogo,
                icon: const Icon(Icons.casino_outlined),
                label: const Text('Tasodifiy logo yaratish'),
              ),
            ),
            const SizedBox(height: 24),
            // 2. Klub nomi va qisqartmasi
            _buildSectionHeader('1. Jamoa Ma\'lumotlari'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _nameController,
              label: 'Klub Nomi',
              hint: 'Masalan: Toshkent Lions',
              icon: Icons.shield_rounded,
              onChanged: (val) {
                if (val.length >= 2 && _monogram.length <= 2) {
                  setState(() {
                    _monogram = val.substring(0, 2).toUpperCase();
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _shortNameController,
                    label: 'Qisqartma (3 harf)',
                    hint: 'TKS',
                    icon: Icons.tag_rounded,
                    maxLength: 3,
                    onChanged: (val) {
                      setState(() {
                        _monogram = val.toUpperCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _stadiumController,
                    label: 'Stadion Nomi',
                    hint: 'Bunyodkor Arena',
                    icon: Icons.stadium_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Stadion sig\'imi: ${(_stadiumCapacity / 1000).toStringAsFixed(0)} 000 muxlis',
              style: const TextStyle(color: Color(0xFF526174), fontSize: 13),
            ),
            Slider(
              value: _stadiumCapacity.toDouble(),
              min: 25000,
              max: 90000,
              divisions: 13,
              activeColor: const Color(0xFF1769E0),
              inactiveColor: const Color(0xFFE8EDF3),
              onChanged: (val) {
                setState(() {
                  _stadiumCapacity = val.round();
                });
              },
            ),
            const SizedBox(height: 24),
            // 3. Logo Geometriyasi va Shakli
            _buildSectionHeader('2. Emblem Shakli'),
            const SizedBox(height: 12),
            _buildShapeSelector(),
            const SizedBox(height: 20),
            // 4. Logo Naqshi (Pattern)
            _buildSectionHeader('3. Emblema Naqshi'),
            const SizedBox(height: 12),
            _buildPatternSelector(),
            const SizedBox(height: 20),
            // 5. Ranglar Palitrasi
            _buildSectionHeader('4. Klub Ranglari'),
            const SizedBox(height: 12),
            _buildColorSection('Asosiy Rang (Primary)', _primaryColor, (c) {
              setState(() => _primaryColor = c);
            }),
            const SizedBox(height: 10),
            _buildColorSection('Ikkilamchi Rang (Secondary)', _secondaryColor, (
              c,
            ) {
              setState(() => _secondaryColor = c);
            }),
            const SizedBox(height: 10),
            _buildColorSection('Hoshiya Rangi (Trim/Gold)', _trimColor, (c) {
              setState(() => _trimColor = c);
            }),
            const SizedBox(height: 32),
            // Boshlang'ich bonus ma'lumoti
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF1769E0).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.stars_rounded, color: Color(0xFF1769E0), size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Klub yaratilgach, sizga avtomatik 16 ta o\'yinchidan iborat muvozanatli tarkib va €80.0M byudjet ajratiladi!',
                      style: TextStyle(color: Color(0xFF526174), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Yaratish tugmasi
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _createAndStart,
                icon: const Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.white,
                ),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'KLUBNI YARATISH VA BOSHLASH',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1769E0),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF192B42),
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildLiveLogoPreview() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Color(0xFF192B42).withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            ClubCrestWidget(config: _currentCrestConfig, size: 110),
            const SizedBox(height: 14),
            Text(
              _nameController.text.isNotEmpty
                  ? _nameController.text
                  : 'Klub Nomi',
              style: const TextStyle(
                color: Color(0xFF192B42),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_shortNameController.text.toUpperCase()} • ${_stadiumController.text}',
              style: const TextStyle(color: Color(0xFF637184), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int? maxLength,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      onChanged: onChanged,
      style: const TextStyle(color: Color(0xFF192B42), fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF637184), fontSize: 13),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFD7DEE7), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF1769E0), size: 18),
        counterText: '',
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Color(0xFF192B42).withValues(alpha: 0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Color(0xFF192B42).withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1769E0)),
        ),
      ),
    );
  }

  Widget _buildShapeSelector() {
    final shapes = [
      {'shape': CrestShape.modernShield, 'label': 'Modern'},
      {'shape': CrestShape.shield, 'label': 'Klassik'},
      {'shape': CrestShape.circle, 'label': 'Doira'},
      {'shape': CrestShape.oval, 'label': 'Oval'},
    ];
    return Row(
      children: shapes.map((item) {
        final shape = item['shape'] as CrestShape;
        final label = item['label'] as String;
        final isSelected = _selectedShape == shape;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedShape = shape),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1769E0).withValues(alpha: 0.18)
                    : const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1769E0)
                      : Color(0xFFE4E9F0),
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF1769E0)
                        : Color(0xFF526174),
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPatternSelector() {
    final patterns = [
      {'pat': CrestPattern.verticalStripes, 'label': 'Chiziqli'},
      {'pat': CrestPattern.diagonalSash, 'label': 'Diagonal'},
      {'pat': CrestPattern.halves, 'label': 'Ikkiga'},
      {'pat': CrestPattern.quarters, 'label': 'To\'rtga'},
      {'pat': CrestPattern.solid, 'label': 'Silliq'},
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: patterns.map((item) {
        final pat = item['pat'] as CrestPattern;
        final label = item['label'] as String;
        final isSelected = _selectedPattern == pat;
        return GestureDetector(
          onTap: () => setState(() => _selectedPattern = pat),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF1769E0).withValues(alpha: 0.18)
                  : const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? const Color(0xFF1769E0) : Color(0xFFE4E9F0),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF1769E0) : Color(0xFF526174),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorSection(
    String title,
    Color selectedColor,
    ValueChanged<Color> onSelect,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: selectedColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Color(0xFF526174), fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _availableColors.length,
            itemBuilder: (context, i) {
              final c = _availableColors[i];
              final isChosen = c.toARGB32() == selectedColor.toARGB32();
              return GestureDetector(
                onTap: () => onSelect(c),
                child: Container(
                  width: 34,
                  height: 34,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isChosen ? Color(0xFF192B42) : Color(0xFFD7DEE7),
                      width: isChosen ? 2.5 : 1.0,
                    ),
                  ),
                  child: isChosen
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: Color(0xFF192B42),
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
