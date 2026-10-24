"""One-off: wrap label literals passed to small UI helpers in tr()."""
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent.parent / 'lib'
pattern = re.compile(r"\b(_colorRow|_slider|_rating|_switch|picker|_metric)\(\s*'([^'$\\]+)'")
n = 0
for f in list((root / 'screens').rglob('*.dart')) + list((root / 'ui').rglob('*.dart')):
    s = f.read_text(encoding='utf8')
    s2, k = pattern.subn(lambda m: f"{m.group(1)}(tr('{m.group(2)}')", s)
    if k:
        f.write_text(s2, encoding='utf8')
        n += k
print('wrapped', n)
