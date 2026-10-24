import 'package:flutter/material.dart';
import '../l10n/l10n.dart';

enum FinanceCategory {
  tickets('Chipta tushumi', Icons.confirmation_number_outlined, true),
  commercial('Homiylik va reklama', Icons.handshake_outlined, true),
  broadcast('Teletranslyatsiya', Icons.live_tv_outlined, true),
  prize('Mukofot puli', Icons.emoji_events_outlined, true),
  transferIn('Transfer tushumi', Icons.call_received_rounded, true),
  wages('Futbolchi maoshlari', Icons.payments_outlined, false),
  stadium('Stadion xarajatlari', Icons.stadium_outlined, false),
  operations('Klub va akademiya', Icons.apartment_outlined, false),
  transferOut('Transfer xarajati', Icons.call_made_rounded, false),
  agent('Agent va imzo', Icons.badge_outlined, false);

  const FinanceCategory(this._label, this.icon, this.income);
  final String _label;
  String get label => tr(_label);
  final IconData icon;
  final bool income;
}

class FinanceEntry {
  final int round;
  final String clubId;
  final String label;
  final int amount;
  final FinanceCategory category;
  final DateTime? date;
  const FinanceEntry(
    this.round,
    this.clubId,
    this.label,
    this.amount, {
    this.category = FinanceCategory.operations,
    this.date,
  });
}

class TransferRecord {
  final int round;
  final String playerName;
  final String fromClub;
  final String toClub;
  final int fee;
  final DateTime? date;
  const TransferRecord(
    this.round,
    this.playerName,
    this.fromClub,
    this.toClub,
    this.fee, {
    this.date,
  });
}

enum NewsKind {
  board(Icons.account_balance_outlined, Color(0xFF374DF5)),
  match(Icons.sports_soccer, Color(0xFF12A150)),
  transfer(Icons.swap_horiz_rounded, Color(0xFF7C3AED)),
  injury(Icons.healing_outlined, Color(0xFFE5352B)),
  contract(Icons.description_outlined, Color(0xFFF5A524)),
  window(Icons.event_available_outlined, Color(0xFF0EA5E9)),
  award(Icons.emoji_events_outlined, Color(0xFFE2A900)),
  finance(Icons.account_balance_wallet_outlined, Color(0xFF0F766E));

  const NewsKind(this.icon, this.color);
  final IconData icon;
  final Color color;
}

class NewsItem {
  final DateTime date;
  final String title;
  final String body;
  final NewsKind kind;
  bool read;
  NewsItem({
    required this.date,
    required this.title,
    required this.body,
    required this.kind,
    this.read = false,
  });
}
