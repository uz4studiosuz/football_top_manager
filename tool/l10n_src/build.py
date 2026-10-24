"""Builds assets/l10n/en.json and ru.json from the translation chunks.

Each chunkNN.json is a list of [english, russian] pairs aligned with the
Uzbek keys in keys_v1.json (same order). Extra files `extra_*.json` map
{uzbek: [english, russian]} for keys added later.

    python -I tool/l10n_src/build.py
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE.parent.parent / 'assets' / 'l10n'


def main():
    keys = json.loads((HERE / 'keys_v1.json').read_text(encoding='utf8'))
    pairs = []
    for f in sorted(HERE.glob('chunk*.json')):
        pairs += json.loads(f.read_text(encoding='utf8'))
    if len(pairs) != len(keys):
        sys.exit(f'{len(pairs)} translations for {len(keys)} keys')
    en, ru = {}, {}
    for k, (e, r) in zip(keys, pairs):
        en[k], ru[k] = e, r
    for f in sorted(HERE.glob('extra_*.json')):
        for k, (e, r) in json.loads(f.read_text(encoding='utf8')).items():
            en[k], ru[k] = e, r
    for k in en:
        for lang, cat in (('en', en), ('ru', ru)):
            # placeholders must survive translation
            for i in range(10):
                if ('{%d}' % i in k) != ('{%d}' % i in cat[k]):
                    print(f'placeholder mismatch [{lang}] {k!r} -> {cat[k]!r}')
    OUT.mkdir(parents=True, exist_ok=True)
    for name, cat in (('en', en), ('ru', ru)):
        (OUT / f'{name}.json').write_text(json.dumps(cat, ensure_ascii=False, indent=1, sort_keys=True) + '\n',
                                          encoding='utf8')
    print('keys', len(en))


if __name__ == '__main__':
    main()
