"""Wraps Uzbek UI string literals in tr()/trf() for translation.

    python -I tool/i18n_wrap.py lib/screens lib/ui ...   # rewrite files
    python -I tool/i18n_wrap.py --fix-const               # drop rejected `const`s (uses flutter analyze)
    python -I tool/i18n_wrap.py --keys                    # print every tr/trf key as JSON

Interpolated literals become templates: 'Hozir: $zone zonasida' →
trf('Hozir: {0} zonasida', [zone]).
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UZ_MARK = re.compile(r"[‘’ʻʼ]|o‘|g‘")
NAMED = ('label', 'labelText', 'hintText', 'tooltip', 'title', 'subtitle', 'message', 'text', 'caption',
         'action', 'helperText', 'semanticLabel', 'description', 'confirm', 'cancel', 'hint', 'empty',
         'emptyText', 'question', 'body', 'heading', 'subtitleText', 'trailingText', 'note')
CALLS = ('Text', 'SectionHeader', 'InfoRow', 'StatLine', 'StatTile', 'EmptyState', 'LoadingView',
         'SelectableText', 'ConfirmDialog', 'Tab', '_legend', '_metric', '_row', '_stat', '_section',
         'MeterRow', '_header', '_info', '_pill', '_chip', 'AttributeBar', '_tile', '_line', '_fact', 'fact', 'stat',
         'row', 'cell', 'chip', '_card', '_kv', 'kv', '_label', '_title', 'pill', 'metric', 'header', 'StatPair',
         '_inboxTile', '_choices', '_swatches', '_toggle', 'divider', 'quiet', '_BigNumber', 'SnackBar', 'showSnack',
         '_snack', 'snack', 'section', '_group', 'group', 'title', 'labelled', '_detailRow', '_kpi', 'kpi', '_stepTitle')


def literals(src):
    """Yields (start, end, body) of single-quoted, non-raw string literals."""
    i, n = 0, len(src)
    while i < n:
        ch = src[i]
        if src.startswith('//', i):
            i = src.find('\n', i)
            i = n if i < 0 else i
            continue
        if src.startswith('/*', i):
            j = src.find('*/', i + 2)
            i = n if j < 0 else j + 2
            continue
        if ch == '"':
            i = skip_string(src, i, '"')
            continue
        if ch == "'":
            if src.startswith("'''", i):
                j = src.find("'''", i + 3)
                i = n if j < 0 else j + 3
                continue
            raw = i > 0 and src[i - 1] == 'r' and (i < 2 or not (src[i - 2].isalnum() or src[i - 2] == '_'))
            end = skip_string(src, i, "'")
            if not raw:
                yield i, end, src[i + 1:end - 1]
            i = end
            continue
        i += 1


def skip_string(src, i, q):
    j = i + 1
    while j < len(src):
        c = src[j]
        if c == '\\':
            j += 2
            continue
        if c == q:
            return j + 1
        if c == '$' and j + 1 < len(src) and src[j + 1] == '{':
            depth, j = 1, j + 2
            while j < len(src) and depth:
                if src[j] in '\'"':
                    j = skip_string(src, j, src[j])
                    continue
                if src[j] == '{':
                    depth += 1
                elif src[j] == '}':
                    depth -= 1
                j += 1
            continue
        if c == '\n':
            return j
        j += 1
    return j


def template(body):
    """'a $x b ${f(y)}' → ('a {0} b {1}', ['x', 'f(y)'])."""
    out, args, i = [], [], 0
    while i < len(body):
        c = body[i]
        if c == '\\':
            out.append(body[i:i + 2])
            i += 2
            continue
        if c == '$' and i + 1 < len(body):
            if body[i + 1] == '{':
                depth, j = 1, i + 2
                while j < len(body) and depth:
                    if body[j] in '\'"':
                        j = skip_string(body, j, body[j])
                        continue
                    depth += {'{': 1, '}': -1}.get(body[j], 0)
                    j += 1
                args.append(body[i + 2:j - 1])
                out.append('{%d}' % (len(args) - 1))
                i = j
                continue
            m = re.match(r'[A-Za-z_][A-Za-z0-9_]*', body[i + 1:])
            if m:
                args.append(m.group(0))
                out.append('{%d}' % (len(args) - 1))
                i += 1 + len(m.group(0))
                continue
        out.append(c)
        i += 1
    return ''.join(out), args


def is_ui_text(body):
    text = re.sub(r'\{\d+\}', '', template(body)[0])
    letters = re.findall(r'[A-Za-zА-Яа-я‘’ʻʼ]', text)
    if len(letters) < 2:
        return False
    if body.startswith(('package:', 'dart:', 'assets/', 'http', '../')) or body.endswith(('.dart', '.json', '.png')):
        return False
    if re.fullmatch(r'[a-z][A-Za-z0-9_]*', text):
        return False  # identifiers, map keys
    if re.fullmatch(r'[A-Z0-9_]{1,4}', text):
        return False  # position codes like CF, GK
    return True


ARG_CALLS = ('_news', '_post', 'BoardObjective', 'TransferRecord', 'SeasonSummary')


def inside_call(src, start):
    """True when the literal is a direct argument of one of ARG_CALLS."""
    before = src[max(0, start - 1500):start]
    calls = list(re.finditer(r'\b(?:%s)\(' % '|'.join(ARG_CALLS), before))
    if not calls:
        return False
    depth = 0
    for ch in before[calls[-1].end():]:
        depth += {'(': 1, ')': -1, '[': 1, ']': -1, '{': 1, '}': -1}.get(ch, 0)
        if depth < 0:
            return False
    return depth == 0


def in_const_region(src, start):
    """Inside `static const x = ...;` / `const [...]` collections: tr() is not allowed there."""
    before = src[max(0, start - 3000):start]
    decl = list(re.finditer(r'\bconst\s+(?:[A-Za-z_<>, ]+\s+)?[A-Za-z_]+\s*=|\bconst\s*[\[{(]|\bconst\s+[A-Z]\w*\(', before))
    if not decl:
        return False
    depth = 0
    for ch in before[decl[-1].end():]:
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        elif ch == ';' and depth <= 0:
            return False
        if depth < 0:
            return False
    return True


def context_ok(src, start):
    before = src[max(0, start - 300):start]
    stripped = before.rstrip()
    if re.search(r'\btrf?\($', stripped):
        return False
    if in_const_region(src, start) and '/screens/' not in CURRENT and '/ui/' not in CURRENT:
        return False
    if inside_call(src, start) and re.search(r'[(,]$', stripped):
        return True
    if re.search(r'\blastTransferError\s*=$', stripped):
        return True
    if re.search(r'(?:\b(?:const\s+)?(?:%s))\($' % '|'.join(map(re.escape, CALLS)), stripped):
        return True
    if re.search(r'\b(?:%s):$' % '|'.join(NAMED), stripped):
        return True
    line = before[before.rfind('\n') + 1:]
    if '==' in line or 'case ' in line or 'byName' in line or "['" in line:
        return False
    # list of labels: labels: [ 'a', 'b' ]
    m = list(re.finditer(r'\blabels?\s*:\s*(?:const\s*)?(?:<String>)?\[', before))
    if m and before[m[-1].end():].count(']') == 0 and re.search(r'[\[,]$', stripped):
        return True
    if re.search(r'(=>|\?|:)$', stripped) and not re.search(r'\b(?:%s):$' % '|'.join(NAMED), stripped):
        return True
    return False


def import_line(path):
    rel = os.path.relpath(ROOT / 'lib' / 'l10n' / 'l10n.dart', path.parent).replace('\\', '/')
    return f"import '{rel}';\n"


CURRENT = ''


def wrap_file(path):
    global CURRENT
    CURRENT = path.as_posix()
    src = path.read_text(encoding='utf8')
    edits = []
    # Adjacent literals ('a' 'b') form one string: merge them first.
    groups = []
    for start, end, body in literals(src):
        if groups and src[groups[-1][1]:start].strip() == '':
            s0, _, b0 = groups[-1]
            groups[-1] = (s0, end, b0 + body)
        else:
            groups.append((start, end, body))
    for start, end, body in groups:
        if not is_ui_text(body) or not context_ok(src, start):
            continue
        tpl, args = template(body)
        if args:
            new = "trf('%s', [%s])" % (tpl, ', '.join(args))
        else:
            new = "tr('%s')" % body
        edits.append((start, end, new))
    if not edits:
        return 0
    for start, end, new in reversed(edits):
        src = src[:start] + new + src[end:]
    if 'l10n/l10n.dart' not in src:
        imports = list(re.finditer(r"^import [^\n]+\n", src, re.M))
        pos = imports[-1].end() if imports else 0
        src = src[:pos] + import_line(path) + src[pos:]
    path.write_text(src, encoding='utf8')
    return len(edits)


CONST_ERRORS = ('invalid_constant', 'const_with_non_constant_argument', 'non_constant_list_element',
                'const_initialized_with_non_constant_value', 'non_constant_map_value', 'non_constant_default_value',
                'const_constructor_param_type_mismatch', 'non_constant_map_element', 'const_eval_method_invocation',
                'non_constant_case_expression', 'const_with_non_const')


def fix_const():
    for round_ in range(30):
        out = subprocess.run('flutter analyze --no-pub', shell=True, capture_output=True, text=True,
                             cwd=ROOT, encoding='utf8', errors='replace').stdout
        hits = []
        for line in out.splitlines():
            m = re.match(r'\s*error - .* - (.+?):(\d+):(\d+) - (\w+)', line)
            if m and m.group(4) in CONST_ERRORS:
                hits.append((m.group(1), int(m.group(2)), int(m.group(3))))
        if not hits:
            print('const fixes done after', round_, 'rounds')
            return
        by_file = {}
        for f, l, c in hits:
            by_file.setdefault(f, []).append((l, c))
        for f, locs in by_file.items():
            p = ROOT / f
            src = p.read_text(encoding='utf8')
            lines = src.split('\n')
            offsets = []
            for l, c in locs:
                offsets.append(sum(len(x) + 1 for x in lines[:l - 1]) + c - 1)
            removed = set()
            for off in sorted(offsets, reverse=True):
                k = off
                while k >= 0:
                    m = re.match(r'const\b', src[k:k + 6])
                    if m and (k == 0 or not (src[k - 1].isalnum() or src[k - 1] == '_')):
                        break
                    k -= 1
                if k >= 0 and k not in removed:
                    removed.add(k)
                    src = src[:k] + src[k + 6:].lstrip(' ') if src[k + 5:k + 6] in (' ', '\n') else src[:k] + src[k + 5:]
            p.write_text(src, encoding='utf8')
        print('round', round_, 'fixed', len(hits))
    print('gave up; check analyzer output')


def keys():
    found = set()
    pat = re.compile(r"\btrf?\(\s*'((?:[^'\\\n]|\\.)*)'")
    for f in (ROOT / 'lib').rglob('*.dart'):
        for m in pat.finditer(f.read_text(encoding='utf8')):
            found.add(m.group(1).encode().decode('unicode_escape').encode('latin1').decode('utf8')
                      if '\\' in m.group(1) else m.group(1))
    return sorted(found)


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['--fix-const']:
        fix_const()
    elif args == ['--keys']:
        sys.stdout.reconfigure(encoding='utf-8')
        print(json.dumps(keys(), ensure_ascii=False, indent=1))
    else:
        total = 0
        for a in args:
            p = ROOT / a
            files = [p] if p.is_file() else sorted(p.rglob('*.dart'))
            for f in files:
                n = wrap_file(f)
                if n:
                    print(f'{n:4d}  {f.relative_to(ROOT)}')
                total += n
        print('wrapped', total)
