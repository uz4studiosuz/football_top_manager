import '../l10n/l10n.dart';
import 'club.dart';
import 'player.dart';

/// Where a transfer negotiation stands. Every step that waits for the other
/// side is answered when the next round is played, so deals take time.
enum DealStage {
  /// User's bid is with the selling club.
  clubReview('Klub javobini kutmoqda'),

  /// Selling club answered with a higher price.
  clubCountered('Klub qarshi taklif qildi'),

  /// Fee agreed: the user must offer the player a contract.
  contractTalks('Shartnoma muzokarasi'),

  /// Contract offer is with the player.
  playerReview('Futbolchi javobini kutmoqda'),

  /// An AI club bid for the user's player.
  offerReceived('Yangi taklif'),

  /// User countered an AI bid; the buyer is thinking.
  buyerReview('Xaridor javobini kutmoqda'),

  /// Fee accepted; the player is agreeing terms with the buyer.
  medical('Tibbiy ko‘rik va shartlar'),

  done('Yakunlandi'),
  collapsed('Bekor bo‘ldi');

  const DealStage(this._label);
  final String _label;
  String get label => tr(_label);

  bool get finished => this == done || this == collapsed;
  bool get waitsForUser => this == clubCountered || this == contractTalks || this == offerReceived;
}

class TransferDeal {
  final Player player;
  final Club seller, buyer;
  int fee;
  int wage, years;
  DealStage stage;

  /// Round in which the other side answers (or the deal expires).
  int dueRound;
  int? counterFee;

  /// Last message from the other side, already in the interface language.
  String note;

  TransferDeal({
    required this.player,
    required this.seller,
    required this.buyer,
    required this.fee,
    required this.stage,
    required this.dueRound,
    this.wage = 0,
    this.years = 3,
    this.counterFee,
    this.note = '',
  });
}
