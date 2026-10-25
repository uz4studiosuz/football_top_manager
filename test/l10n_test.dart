import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/l10n/l10n.dart';
import 'package:football_top_manager/main.dart';
import 'package:football_top_manager/services/season_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, String> _catalog(String lang) =>
    (jsonDecode(File('assets/l10n/$lang.json').readAsStringSync()) as Map).cast<String, String>();

String _unescape(String s) => s.replaceAll(r"\'", "'").replaceAll(r'\$', r'$');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(InitialDatabase.load);

  test('every tr()/trf() key has an English and a Russian translation', () {
    final en = _catalog('en'), ru = _catalog('ru');
    final call = RegExp(r"\btrf?\(\s*'((?:[^'\\\n]|\\.)*)'");
    final missing = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      for (final m in call.allMatches(f.readAsStringSync())) {
        final key = _unescape(m.group(1)!);
        if (!en.containsKey(key) || !ru.containsKey(key)) missing.add('${f.path}: $key');
      }
    }
    expect(missing, isEmpty, reason: 'run: python -I tool/i18n_keys.py missing en');
  });

  test('templates keep their placeholders in every language', () {
    for (final lang in ['en', 'ru']) {
      _catalog(lang).forEach((k, v) {
        for (var i = 0; i < 10; i++) {
          expect(k.contains('{$i}'), v.contains('{$i}'), reason: '[$lang] $k -> $v');
        }
      });
    }
  });

  test('tr, trf and calendar follow the selected language', () async {
    L10n.install(AppLang.en, _catalog('en'));
    L10n.install(AppLang.ru, _catalog('ru'));
    L10n.current.value = AppLang.en;
    expect(tr('Davom etish'), 'Continue');
    expect(trf('{0}-tur', [5]), 'Round 5');
    expect(SeasonCalendar.format(DateTime(2026, 8, 15)), '15 August');
    L10n.current.value = AppLang.ru;
    expect(tr('Davom etish'), 'Продолжить');
    expect(SeasonCalendar.format(DateTime(2026, 8, 15)), '15 августа');
    L10n.current.value = AppLang.uz;
    expect(tr('Davom etish'), 'Davom etish');
  });

  testWidgets('first launch asks for a language and the app switches to it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    L10n.install(AppLang.en, _catalog('en'));
    L10n.install(AppLang.ru, _catalog('ru'));
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const FootballTopManagerApp());
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Manager Career'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    L10n.current.value = AppLang.uz;
    await tester.pumpAndSettle();
  });
}
