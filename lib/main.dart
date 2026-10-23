import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'data/initial_database.dart';
import 'services/save_service.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFFFFFFF),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  SaveService.startAutoSave();
  runApp(const FootballTopManagerApp());
}

class FootballTopManagerApp extends StatelessWidget {
  const FootballTopManagerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Football Top Manager 2027',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: const StartupScreen(),
  );
}

/// Loads the league data and any saved career, then opens the right screen.
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});
  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  late final Future<bool> _boot = _load();

  Future<bool> _load() async {
    await InitialDatabase.load();
    return SaveService.load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _boot,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const LoadingView(message: 'Liga va karyera yuklanmoqda…');
      }
      return snap.data == true ? const MainNavigationScreen() : const OnboardingScreen();
    },
  );
}
