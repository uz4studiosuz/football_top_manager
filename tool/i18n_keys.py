"""Translation catalog helper.

    python -I tool/i18n_keys.py keys        # every key the app can look up (JSON list)
    python -I tool/i18n_keys.py missing en  # keys without an English translation
    python -I tool/i18n_keys.py leftovers   # Uzbek-looking literals not routed through tr()

Keys are the Uzbek source strings: arguments of tr()/trf(), plus constant
labels that are translated where they are displayed (enum values, label
lists such as FaceConfig.cutLabels).
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import i18n_wrap as W  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / 'lib'
SKIP = {'commentary.dart', 'commentary_i18n.dart', 'l10n.dart', 'language_picker.dart', 'save_service.dart'}
NATIONS = re.compile(r"^(O‘zbekiston|Qozog‘iston|Qirg‘iziston|Tojikiston|Turkmaniston|Ozarbayjon)$")
UZ = re.compile(r"[‘’ʻ]|\b(va|bilan|uchun|yo‘q|tur|o‘yin|klub|jamoa|futbolchi|gol|daqiqa|mavsum|hafta|kun)\b"
                r"|lar\b|ni\b|da\b|ga\b|dan\b|ish\b", re.I)
TR_CALL = re.compile(r"\btrf?\(\s*$")


def unescape(s):
    return s.replace("\\'", "'").replace('\\$', '$').replace('\\\\', '\\')


def scan():
    """Returns (keys, leftovers)."""
    keys, leftovers = set(), []
    for f in sorted(LIB.rglob('*.dart')):
        if f.name in SKIP:
            continue
        src = f.read_text(encoding='utf8')
        groups = []
        for start, end, body in W.literals(src):
            if groups and src[groups[-1][1]:start].strip() == '':
                s0, _, b0 = groups[-1]
                groups[-1] = (s0, end, b0 + body)
            else:
                groups.append((start, end, body))
        for start, end, body in groups:
            if TR_CALL.search(src[max(0, start - 8):start]):
                keys.add(unescape(body))
                continue
            if not W.is_ui_text(body) or NATIONS.match(body):
                continue
            tpl = W.template(body)[0]
            text = re.sub(r'\{\d+\}', '', tpl)
            in_enum_or_labels = f.parent.name == 'models'
            if '$' not in body and (in_enum_or_labels or UZ.search(text)):
                # constant labels translated at display time
                keys.add(unescape(body))
            elif UZ.search(text):
                line = src.count('\n', 0, start) + 1
                leftovers.append(f'{f.relative_to(ROOT)}:{line}: {body[:100]}')
    return sorted(keys), leftovers


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'keys'
    keys, leftovers = scan()
    if cmd == 'keys':
        print(json.dumps(keys, ensure_ascii=False, indent=1))
    elif cmd == 'missing':
        lang = sys.argv[2]
        cat = json.loads((ROOT / 'assets' / 'l10n' / f'{lang}.json').read_text(encoding='utf8'))
        missing = [k for k in keys if k not in cat]
        print(json.dumps(missing, ensure_ascii=False, indent=1))
        print(len(missing), 'missing of', len(keys), file=sys.stderr)
    elif cmd == 'uimissing':
        # Any UI-looking literal in screens/ui (shown through variables, e.g. tab
        # label lists) that the English catalog does not cover yet.
        cat = json.loads((ROOT / 'assets' / 'l10n' / 'en.json').read_text(encoding='utf8'))
        found = set()
        files = list((LIB / 'screens').rglob('*.dart')) + list((LIB / 'ui').rglob('*.dart'))
        files.append(LIB / 'models' / 'face.dart')
        for f in files:
            if f.name in SKIP:
                continue
            src = f.read_text(encoding='utf8')
            for start, end, body in W.literals(src):
                if '$' in body or '\\' in body or body in cat or not W.is_ui_text(body):
                    continue
                if re.fullmatch(r'[A-Za-z0-9_./:-]+', body) and not body[:1].isupper():
                    continue
                found.add(body)
        print(json.dumps(sorted(found), ensure_ascii=False, indent=1))
        print(len(found), 'ui literals without translation', file=sys.stderr)
    elif cmd == 'leftovers':
        print('\n'.join(leftovers))
        print(len(leftovers), 'leftovers', file=sys.stderr)
