import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/club.dart';

/// FTM Coins: the account currency. It lives outside the career save, so it
/// carries over from one career to the next.
///
/// Economy:
/// * every new player gets [welcomeBonus] once;
/// * taking over an existing club costs by squad strength ([clubCost]);
/// * founding a custom club (name, kits, crest, stadium) costs [customClubCost];
/// * coins are earned back through results ([reward]).
class CoinWallet {
  static final CoinWallet _instance = CoinWallet._();
  factory CoinWallet() => _instance;
  CoinWallet._();

  static const _key = 'ftm27_coins_v1';
  static const welcomeBonus = 1000;
  static const customClubCost = 500;

  // Rewards.
  static const winReward = 10, drawReward = 3;
  static const titleReward = 500, promotionReward = 300, objectiveReward = 150;

  final ValueNotifier<int> balance = ValueNotifier(0);

  /// True right after the welcome bonus was granted, until it is shown.
  bool welcomePending = false;
  bool _loaded = false;

  /// Price of managing [club]: stronger squads cost more.
  static int clubCost(Club club) => switch (club.teamOVR) {
    >= 85 => 900,
    >= 80 => 600,
    >= 75 => 350,
    >= 70 => 200,
    _ => 100,
  };

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_key);
      if (saved == null) {
        balance.value = welcomeBonus;
        welcomePending = true;
        await prefs.setInt(_key, welcomeBonus);
      } else {
        balance.value = saved;
      }
    } catch (e) {
      // No storage (tests, private mode): play with the welcome bonus.
      balance.value = welcomeBonus;
    }
  }

  bool canAfford(int amount) => balance.value >= amount;

  /// Takes [amount] coins; false (and nothing taken) when short.
  bool spend(int amount) {
    if (!canAfford(amount)) return false;
    _set(balance.value - amount);
    return true;
  }

  void reward(int amount) {
    if (amount > 0) _set(balance.value + amount);
  }

  void _set(int value) {
    balance.value = value;
    SharedPreferences.getInstance().then((p) => p.setInt(_key, value)).ignore();
  }
}
