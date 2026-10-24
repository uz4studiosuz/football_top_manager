import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'data/initial_database.dart';
import 'services/save_service.dart';
import 'services/coin_wallet.dart';
import 'ui/widgets.dart';
import 'ui/language_picker.dart';
import 'services/game_state.dart';
import 'l10n/l10n.dart';

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
  // Changing the language rebuilds the whole app (the career stays loaded).
  Widget build(BuildContext context) => ValueListenableBuilder<AppLang>(
    valueListenable: L10n.current,
    builder: (context, lang, _) {
      if (_shown != null && _shown != lang) StartupScreen.keepCareer = true;
      _shown = lang;
      return MaterialApp(
        key: ValueKey(lang),
        title: 'Football Top Manager 2027',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const StartupScreen(),
      );
    },
  );
  static AppLang? _shown;
}

/// Loads the league data and any saved career, then opens the right screen.
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  /// Set when the app restarts for a language switch: keep the open career.
  static bool keepCareer = false;
  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  late final Future<bool> _boot = _load();

  bool _askLanguage = false;

  Future<bool> _load() async {
    await L10n.load();
    await InitialDatabase.load();
    await CoinWallet().load();
    _askLanguage = !L10n.chosen;
    if (StartupScreen.keepCareer && GameState().isInitialized) return true;
    return SaveService.load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _boot,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return LoadingView(message: tr('Liga va karyera yuklanmoqda…'));
      }
      if (_askLanguage) {
        return LanguageScreen(
          onDone: () => setState(() => _askLanguage = false),
        );
      }
      return snap.data == true
          ? const MainNavigationScreen()
          : OnboardingScreen();
    },
  );
}
