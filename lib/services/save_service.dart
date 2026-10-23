import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_state.dart';

/// Persists the career in shared_preferences (localStorage on the web) and
/// auto-saves shortly after every change to the game state.
class SaveService {
  static const _key = 'ftm27_career_v1';
  static Timer? _debounce;
  static bool _listening = false;
  static bool enabled = true;

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('Saqlash mavjud emas: $e');
      return null;
    }
  }

  static Future<bool> hasSave() async => (await _prefs())?.containsKey(_key) ?? false;

  static Future<void> save() async {
    final game = GameState();
    if (!enabled || !game.isInitialized) return;
    final prefs = await _prefs();
    await prefs?.setString(_key, jsonEncode(game.toSave()));
  }

  /// Loads the saved career into [GameState]; false when nothing usable.
  static Future<bool> load() async {
    final prefs = await _prefs();
    final raw = prefs?.getString(_key);
    if (raw == null) return false;
    try {
      return GameState().restore(Map<String, dynamic>.from(jsonDecode(raw)));
    } catch (e) {
      debugPrint('Saqlangan karyerani o‘qib bo‘lmadi: $e');
      return false;
    }
  }

  static Future<void> clear() async {
    _debounce?.cancel();
    await (await _prefs())?.remove(_key);
  }

  static void startAutoSave() {
    if (_listening) return;
    _listening = true;
    GameState().addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 700), save);
    });
  }
}
