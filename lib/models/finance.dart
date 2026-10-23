class FinanceEntry {
  final int round;
  final String clubId;
  final String label;
  final int amount;
  const FinanceEntry(this.round, this.clubId, this.label, this.amount);
}

class TransferRecord {
  final int round;
  final String playerName;
  final String fromClub;
  final String toClub;
  final int fee;
  const TransferRecord(
    this.round,
    this.playerName,
    this.fromClub,
    this.toClub,
    this.fee,
  );
}
