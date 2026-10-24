"""One-off patch: shared country list and a plain default face."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
for rel, face_old in (
    ('lib/screens/onboarding_screen.dart', "FaceConfig face = FaceConfig.forPlayer('new_manager', 'O‘zbekiston', 35);"),
    ('lib/screens/player_creator_screen.dart', "late FaceConfig face = FaceConfig.forPlayer('creator', nationality, age);"),
):
    p = ROOT / rel
    s = p.read_text(encoding='utf8')
    s, n = re.subn(r"  static const countries = \{\n(?:    '[^\n]*\n)+  \};", '  static const countries = countryFlags;', s)
    assert n == 1, rel
    assert face_old in s, rel
    # A plain, neutral portrait to start from; "random" is one tap away.
    s = s.replace(face_old, face_old.split('=')[0].rstrip() + ' = const FaceConfig();', 1)
    imports = list(re.finditer(r"^import [^\n]+\n", s, re.M))
    s = s[:imports[-1].end()] + "import '../data/countries.dart';\n" + s[imports[-1].end():]
    p.write_text(s, encoding='utf8')

p = ROOT / 'lib/ui/face_avatar.dart'
s = p.read_text(encoding='utf8')
a = """            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: _random,"""
assert s.count(a) == 1
s = s.replace(a, """            TextButton.icon(
              onPressed: () => _set(const FaceConfig()),
              icon: const Icon(Icons.face_outlined, size: 18),
              label: Text(tr('Standart')),
            ),
            TextButton.icon(
              onPressed: _random,""", 1)
p.write_text(s, encoding='utf8')
print('ok')
