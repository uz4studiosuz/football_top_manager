import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manager workspace tokens: blue navigation, violet actions, teal feedback
/// and dense neutral panels shared by mobile and desktop layouts.
/// One application palette, rebuilt atomically when the user changes mode.
class AppAppearance extends ValueNotifier<bool> {
  AppAppearance._() : super(true);
  static final instance = AppAppearance._();
  Future<void> load() async {
    value = (await SharedPreferences.getInstance()).getBool('darkMode') ?? true;
    _systemBars();
  }

  Future<void> toggle() async {
    value = !value;
    _systemBars();
    await (await SharedPreferences.getInstance()).setBool('darkMode', value);
  }

  void _systemBars() => SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: value ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: value ? Brightness.light : Brightness.dark,
    ),
  );
}

abstract final class AppColors {
  static Color get bg =>
      AppAppearance.instance.value ? const Color(0xFF10131C) : const Color(0xFFF0F2F7);
  static Color get surface =>
      AppAppearance.instance.value ? const Color(0xFF1B1F2B) : const Color(0xFFFFFFFF);
  static Color get surfaceAlt =>
      AppAppearance.instance.value ? const Color(0xFF232836) : const Color(0xFFF5F6FA);
  static Color get ink =>
      AppAppearance.instance.value ? const Color(0xFFECEEF1) : const Color(0xFF222226);
  static Color get ink2 =>
      AppAppearance.instance.value ? const Color(0xFFB5BCC7) : const Color(0xFF5B6270);
  static Color get ink3 =>
      AppAppearance.instance.value ? const Color(0xFF929CAA) : const Color(0xFF9AA1AD);
  static Color get line =>
      AppAppearance.instance.value ? const Color(0xFF323848) : const Color(0xFFE0E4ED);
  static Color get primary =>
      AppAppearance.instance.value ? const Color(0xFFBE9AFF) : const Color(0xFF763ADC);
  static Color get primarySoft =>
      AppAppearance.instance.value ? const Color(0xFF37284F) : const Color(0xFFF0E8FC);
  static Color get action => const Color(0xFF8247E5);
  static const header = Color(0xFF294B91);
  static const teal = Color(0xFF36CDB8);
  static const live = Color(0xFFE5352B);
  static const win = Color(0xFF12A150);
  static const draw = Color(0xFFA1A7B3);
  static const loss = Color(0xFFE5352B);
  static const warning = Color(0xFFF5A524);
  static const gold = Color(0xFFE2A900);
  static const pitch = Color(0xFF438343);
  static const pitchDark = Color(0xFF39763A);

  // Tinted surfaces must retain readable text in either appearance.
  static Color get dangerSurface => AppAppearance.instance.value ? const Color(0xFF342326) : const Color(0xFFFFF4F2);
  static Color get successSurface => AppAppearance.instance.value ? const Color(0xFF20342B) : const Color(0xFFEFFAF3);
  static Color get warningSurface => AppAppearance.instance.value ? const Color(0xFF393023) : const Color(0xFFFFF6EC);
  static Color get cupSurface => AppAppearance.instance.value ? const Color(0xFF393122) : const Color(0xFFFFF8E6);
  static Color get infoSurface => AppAppearance.instance.value ? const Color(0xFF253442) : const Color(0xFFEFF8FF);

  static Color condition(int index) => [win, const Color(0xFF00ADC4), ink2, warning, loss][index];

  /// SofaScore style player-rating scale (3.0 – 10.0).
  static Color rating(double? r) {
    if (r == null) return ink3;
    if (r >= 9.0) return const Color(0xFF374DF5);
    if (r >= 8.0) return const Color(0xFF00ADC4);
    if (r >= 7.0) return const Color(0xFF00C424);
    if (r >= 6.5) return const Color(0xFFD9AF00);
    if (r >= 6.0) return const Color(0xFFED7E07);
    return const Color(0xFFDC0C00);
  }

  /// Attribute / OVR scale: 90+ sky blue, 80–89 green, 70–79 amber,
  /// 69 and below red.
  static Color attribute(int v) {
    if (v >= 90) return const Color(0xFF00ADC4);
    if (v >= 80) return const Color(0xFF12A150);
    if (v >= 70) return const Color(0xFFE08A00);
    return const Color(0xFFDC0C00);
  }

  static Color result(String r) => switch (r) {
    'W' => win,
    'L' => loss,
    _ => draw,
  };

  static Color position(String code) => switch (code) {
    'GK' => const Color(0xFFE39A00),
    'CB' || 'LB' || 'RB' => const Color(0xFF2F7BEA),
    'DMF' || 'CMF' || 'AMF' || 'LMF' || 'RMF' => const Color(0xFF12A150),
    _ => const Color(0xFFE5352B),
  };
}

abstract final class AppText {
  static const tabular = [FontFeature.tabularFigures()];
  static TextStyle get h1 => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    letterSpacing: -0.4,
  );
  static TextStyle get h2 => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    letterSpacing: -0.2,
  );
  static TextStyle get h3 =>
      TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink);
  static TextStyle get body => TextStyle(fontSize: 14, color: AppColors.ink);
  static TextStyle get bodyStrong =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink);
  static TextStyle get small => TextStyle(fontSize: 12, color: AppColors.ink2);
  static TextStyle get caption => TextStyle(fontSize: 11, color: AppColors.ink3);
  static TextStyle get overline => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.ink3,
    letterSpacing: 0.6,
  );
  static TextStyle get number => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    fontFeatures: tabular,
  );
}

ThemeData buildAppTheme() {
  const radius = BorderRadius.all(Radius.circular(8));
  return ThemeData(
    useMaterial3: true,
    brightness: AppAppearance.instance.value ? Brightness.dark : Brightness.light,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme(
      brightness: AppAppearance.instance.value ? Brightness.dark : Brightness.light,
      onError: Colors.white,
      primary: AppColors.primary,
      onPrimary: AppAppearance.instance.value ? const Color(0xFF24123B) : Colors.white,
      secondary: AppColors.primary,
      onSecondary: Colors.white,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.primary,
      secondaryContainer: AppColors.primarySoft,
      onSecondaryContainer: AppColors.primary,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.ink2,
      outline: AppColors.line,
      outlineVariant: AppColors.line,
      error: AppColors.live,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppAppearance.instance.value ? AppColors.header : AppColors.surface,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      dividerColor: AppColors.line,
      indicatorColor: AppColors.teal,
      labelColor: AppColors.ink,
      unselectedLabelColor: AppColors.ink2,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: TextStyle(fontFamily: 'Roboto', fontSize: 13, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      tabAlignment: TabAlignment.fill,
    ),
    dividerTheme: DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10)), side: BorderSide(color: AppColors.line)),
    ),
    dialogTheme: DialogThemeData(
      elevation: 0,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      elevation: 0,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.action,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 46),
        textStyle: TextStyle(fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w700),
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.action,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 46),
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(44, 46),
        side: BorderSide(color: AppColors.line),
        textStyle: TextStyle(fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w600),
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: TextStyle(fontFamily: 'Roboto', fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      labelStyle: TextStyle(
        color: AppColors.ink,
        fontFamily: 'Roboto',
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      showCheckmark: false,
      selectedColor: AppColors.primarySoft,
      backgroundColor: AppColors.surface,
      side: WidgetStateBorderSide.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.line,
          width: states.contains(WidgetState.selected) ? 1.4 : 1,
        ),
      ),
      shape: StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      labelStyle: TextStyle(color: AppColors.ink2),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.line,
      thumbColor: AppColors.primary,
      trackHeight: 4,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.primary : null,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.ink2,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      subtitleTextStyle: TextStyle(fontFamily: 'Roboto', fontSize: 12, color: AppColors.ink2),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.line,
    ),
  );
}
