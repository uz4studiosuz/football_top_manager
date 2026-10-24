import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_state.dart';

/// Persists careers in shared_preferences (localStorage on the web), one per
/// save slot, and auto-saves shortly after every change to the game state.
class SaveService {
  static const _base = 'ftm27_career_v1';
  static const _slotKey = 'ftm27_active_slot';
  static const slotCount = 3;
  static Timer? _debounce;
  static bool _listening = false;
  static bool enabled = true;

  /// The slot the current career is saved in (0 = the original save).
  static int activeSlot = 0;

  static String _key(int slot) => slot == 0 ? _base : '${_base}_s$slot';
  static String _metaKey(int slot) => '${_key(slot)}_meta';

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('Saqlash mavjud emas: $e');
      return null;
    }
  }

  static Future<void> _loadActiveSlot() async {
    activeSlot = ((await _prefs())?.getInt(_slotKey) ?? 0).clamp(0, slotCount - 1);
  }

  static Future<bool> hasSave() async {
    await _loadActiveSlot();
    return (await _prefs())?.containsKey(_key(activeSlot)) ?? false;
  }

  static Future<void> save() async {
    final game = GameState();
    if (!enabled || !game.isInitialized) return;
    final prefs = await _prefs();
    await prefs?.setString(_key(activeSlot), jsonEncode(game.toSave()));
    await prefs?.setString(
      _metaKey(activeSlot),
      jsonEncode({
        'club': game.userClub.name,
        'league': game.leagueName,
        'season': game.seasonLabel,
        'round': game.currentRound,
        'manager': game.managerProfile.name,
        'at': DateTime.now().toIso8601String(),
      }),
    );
  }

  /// Loads the active slot's career into [GameState]; false when nothing usable.
  static Future<bool> load() async {
    await _loadActiveSlot();
    final raw = (await _prefs())?.getString(_key(activeSlot));
    if (raw == null) return false;
    return _restore(raw);
  }

  static bool _restore(String raw) {
    try {
      return GameState().restore(Map<String, dynamic>.from(jsonDecode(raw)));
    } catch (e) {
      debugPrint('Saqlangan karyerani o‘qib bo‘lmadi: $e');
      return false;
    }
  }

  /// Summary of a slot (club, league, season…) or null when empty.
  static Future<Map<String, dynamic>?> meta(int slot) async {
    final prefs = await _prefs();
    if (prefs == null || !prefs.containsKey(_key(slot))) return null;
    final raw = prefs.getString(_metaKey(slot));
    return raw == null ? {'club': '?'} : Map<String, dynamic>.from(jsonDecode(raw));
  }

  /// Saves the current career, then makes [slot] the active one.
  static Future<void> setActiveSlot(int slot) async {
    await save();
    activeSlot = slot;
    await (await _prefs())?.setInt(_slotKey, slot);
  }

  static Future<void> clearSlot(int slot) async {
    if (slot == activeSlot) _debounce?.cancel();
    final prefs = await _prefs();
    await prefs?.remove(_key(slot));
    await prefs?.remove(_metaKey(slot));
  }

  static Future<void> clear() => clearSlot(activeSlot);

  /// The current career as a file (to move it to another device).
  static String exportCareer() => const JsonEncoder.withIndent(' ').convert(GameState().toSave());

  /// Loads a career file into the active slot.
  static Future<bool> importCareer(String raw) async {
    if (!_restore(raw)) return false;
    await save();
    return true;
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
