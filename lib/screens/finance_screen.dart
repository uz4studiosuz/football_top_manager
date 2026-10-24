import 'package:flutter/material.dart';
import 'club_screen.dart';
import '../l10n/l10n.dart';

/// "Moliya" tab: finances first, with the calendar, inbox and club profile
/// one swipe away.
class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: Text(tr('Klub moliyasi')),
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: tr('Moliya')),
            Tab(text: tr('Kalendar')),
            Tab(text: tr('Yangiliklar')),
            Tab(text: tr('Klub profili')),
          ],
        ),
      ),
      body: const TabBarView(
        children: [FinanceView(), CalendarView(), NewsView(), ClubProfileView()],
      ),
    ),
  );
}
