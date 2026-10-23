import 'package:flutter/material.dart';
import 'club_screen.dart';

/// "Moliya" tab: finances first, with the calendar, inbox and club profile
/// one swipe away.
class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Klub moliyasi'),
        bottom: const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Moliya'),
            Tab(text: 'Kalendar'),
            Tab(text: 'Yangiliklar'),
            Tab(text: 'Klub profili'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [FinanceView(), CalendarView(), NewsView(), ClubProfileView()],
      ),
    ),
  );
}
