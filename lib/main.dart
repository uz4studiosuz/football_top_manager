import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/onboarding_screen.dart';
import 'data/initial_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await InitialDatabase.load();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFFFFFFF),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const FootballTopManagerApp());
}

class FootballTopManagerApp extends StatelessWidget {
  const FootballTopManagerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Football Top Manager 2027',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF3F5F8),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1769E0),
          secondary: Color(0xFF1769E0),
          onSecondary: Colors.white,
          primaryContainer: Color(0xFFE7F0FF),
          onPrimaryContainer: Color(0xFF1769E0),
          secondaryContainer: Color(0xFFE7F0FF),
          onSecondaryContainer: Color(0xFF1769E0),
          onSurfaceVariant: Color(0xFF637184),
          outline: Color(0xFFD7DEE7),
          surface: Colors.white,
          onSurface: Color(0xFF192B42),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF192B42),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        dialogTheme: const DialogThemeData(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        dividerColor: const Color(0xFFE4E9F0),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE4E9F0),
          thickness: 1,
        ),
        tabBarTheme: const TabBarThemeData(dividerColor: Color(0xFFE4E9F0)),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFD7DEE7)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        chipTheme: const ChipThemeData(
          labelStyle: TextStyle(
            color: Color(0xFF192B42),
            fontFamily: 'Roboto',
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          checkmarkColor: Color(0xFF1769E0),
          selectedColor: Color(0xFFE7F0FF),
          backgroundColor: Colors.white,
          side: BorderSide(color: Color(0xFFD7DEE7)),
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: const Color(0xFF1769E0),
            foregroundColor: Colors.white,
            minimumSize: const Size(44, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        fontFamily: 'Roboto',
      ),
      home: const OnboardingScreen(),
    );
  }
}
