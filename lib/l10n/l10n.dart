import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Interface languages. Uzbek is the source language: every UI string is
/// written in Uzbek and looked up in the English/Russian catalogs
/// (`assets/l10n/en.json`, `ru.json`, keyed by the Uzbek text).
enum AppLang {
  uz('O‘zbekcha', '🇺🇿'),
  en('English', '🇬🇧'),
  ru('Русский', '🇷🇺');

  const AppLang(this.nativeName, this.flag);
  final String nativeName, flag;
}

class L10n {
  static const _prefKey = 'ftm27_lang';
  static final ValueNotifier<AppLang> current = ValueNotifier(AppLang.uz);
  static final Map<AppLang, Map<String, String>> _catalogs = {};

  /// False until the player has picked a language once.
  static bool chosen = false;

  static AppLang get lang => current.value;

  static Future<void> load() async {
    for (final l in [AppLang.en, AppLang.ru]) {
      if (_catalogs.containsKey(l)) continue;
      try {
        // Decoded here rather than with loadString, which hands large files
        // to a background isolate.
        final bytes = await rootBundle.load('assets/l10n/${l.name}.json');
        final raw = jsonDecode(utf8.decode(bytes.buffer.asUint8List())) as Map;
        _catalogs[l] = raw.map((k, v) => MapEntry(k as String, v as String));
      } catch (_) {
        _catalogs[l] = {};
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = AppLang.values.asNameMap()[prefs.getString(_prefKey)];
      chosen = saved != null;
      current.value = saved ?? AppLang.uz;
    } catch (_) {}
  }

  static Future<void> set(AppLang lang) async {
    chosen = true;
    current.value = lang;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, lang.name);
    } catch (_) {}
  }

  /// Test hook: install catalogs without assets.
  @visibleForTesting
  static void install(AppLang lang, Map<String, String> catalog) => _catalogs[lang] = catalog;

  static String tr(String uz) {
    final l = current.value;
    if (l == AppLang.uz) return uz;
    return _catalogs[l]?[uz] ?? uz;
  }

  /// [template] uses {0}, {1}... for values that are not translated.
  static String trf(String template, List<Object?> args) {
    var s = tr(template);
    for (var i = 0; i < args.length; i++) {
      s = s.replaceAll('{$i}', '${args[i]}');
    }
    return s;
  }
}

/// Translates a UI string written in Uzbek into the current language.
String tr(String uz) => L10n.tr(uz);

/// Like [tr] for strings with values: `trf('{0}-tur', [round])`.
String trf(String template, List<Object?> args) => L10n.trf(template, args);
