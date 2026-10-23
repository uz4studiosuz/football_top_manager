import 'package:flutter/material.dart';
import '../services/game_state.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});
  static String money(int n) =>
      '${n < 0 ? '-' : ''}€${(n.abs() / 1000000).toStringAsFixed(2)}M';
  @override
  Widget build(BuildContext context) {
    final game = GameState();
    return Scaffold(
      appBar: AppBar(title: const Text('Klub moliyasi')),
      body: ListenableBuilder(
        listenable: game,
        builder: (context, _) {
          final c = game.userClub;
          final entries = game.ledger
              .where((e) => e.clubId == c.id)
              .toList()
              .reversed
              .toList();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mavjud mablag‘',
                      style: TextStyle(color: Color(0xFF637184)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      money(c.transferBudget),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                    const Divider(height: 32),
                    _row(
                      'Haftalik futbolchi maoshlari',
                      money(c.totalWeeklyWages),
                    ),
                    _row('Haftalik maosh limiti', money(c.wageBudget)),
                    _row(
                      'Qolgan maosh imkoniyati',
                      money(c.remainingWageBudget),
                    ),
                    _row(
                      'Mavsumiy sof pul oqimi',
                      money(entries.fold<int>(0, (sum, e) => sum + e.amount)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Daromad va xarajatlar',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Har tur bir moliyaviy hafta. Uy o‘yinida chipta tushumi va stadion xarajati, har haftada homiylik, maosh va klub xarajatlari hisoblanadi.',
                style: TextStyle(height: 1.5, color: Color(0xFF637184)),
              ),
              const SizedBox(height: 16),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Birinchi uchrashuv yoki transferdan keyin operatsiyalar shu yerda ko‘rinadi.',
                  ),
                ),
              for (final e in entries)
                Container(
                  color: Colors.white,
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: Icon(
                        e.amount >= 0 ? Icons.south_west : Icons.north_east,
                        color: e.amount >= 0
                            ? const Color(0xFF1769E0)
                            : const Color(0xFF637184),
                      ),
                      title: Text(e.label),
                      subtitle: Text('${e.round}-tur'),
                      trailing: Text(
                        money(e.amount),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'Liga transferlari',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (game.transferHistory.isEmpty)
                const Text('Hali yakunlangan transfer yo‘q.'),
              for (final t in game.transferHistory)
                Container(
                  color: Colors.white,
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      title: Text(t.playerName),
                      subtitle: Text(
                        '${t.fromClub} > ${t.toClub} · ${t.round}-tur',
                      ),
                      trailing: Text(money(t.fee)),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(l, style: const TextStyle(color: Color(0xFF637184))),
        ),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
