import 'package:flutter/material.dart';
import '../l10n/l10n.dart';

/// Clean, SofaScore-inspired design tokens. Every screen reads colours from
/// here so the whole game keeps one calm, data-first visual language.
abstract final class AppColors {
  static const bg = Color(0xFFEDF1F6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF5F7FA);
  static const ink = Color(0xFF222226);
  static const ink2 = Color(0xFF5B6270);
  static const ink3 = Color(0xFF9AA1AD);
  static const line = Color(0xFFE6E9EF);
  static const primary = Color(0xFF374DF5);
  static const primarySoft = Color(0xFFEBEEFE);
  static const live = Color(0xFFE5352B);
  static const win = Color(0xFF12A150);
  static const draw = Color(0xFFA1A7B3);
  static const loss = Color(0xFFE5352B);
  static const warning = Color(0xFFF5A524);
  static const gold = Color(0xFFE2A900);
  static const pitch = Color(0xFF2E8B57);
  static const pitchDark = Color(0xFF287A4C);

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
  static const h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    letterSpacing: -0.4,
  );
  static const h2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    letterSpacing: -0.2,
  );
  static const h3 = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static const body = TextStyle(fontSize: 14, color: AppColors.ink);
  static const bodyStrong = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );
  static const small = TextStyle(fontSize: 12, color: AppColors.ink2);
  static const caption = TextStyle(fontSize: 11, color: AppColors.ink3);
  static const overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.ink3,
    letterSpacing: 0.6,
  );
  static const number = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    fontFeatures: tabular,
  );
}

ThemeData buildAppTheme() {
  const radius = BorderRadius.all(Radius.circular(10));
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: tr('Roboto'),
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
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
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: tr('Roboto'),
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      dividerColor: AppColors.line,
      indicatorColor: AppColors.primary,
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.ink2,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: TextStyle(
        fontFamily: tr('Roboto'),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: tr('Roboto'),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      tabAlignment: TabAlignment.fill,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    dialogTheme: const DialogThemeData(
      elevation: 0,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      elevation: 0,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 46),
        textStyle: TextStyle(
          fontFamily: tr('Roboto'),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 46),
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(44, 46),
        side: const BorderSide(color: AppColors.line),
        textStyle: TextStyle(
          fontFamily: tr('Roboto'),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: TextStyle(
          fontFamily: tr('Roboto'),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      labelStyle: TextStyle(
        color: AppColors.ink,
        fontFamily: tr('Roboto'),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      checkmarkColor: AppColors.primary,
      selectedColor: AppColors.primarySoft,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: AppColors.line),
      shape: StadiumBorder(),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
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
    sliderTheme: const SliderThemeData(
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
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.ink2,
      titleTextStyle: TextStyle(
        fontFamily: tr('Roboto'),
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: tr('Roboto'),
        fontSize: 12,
        color: AppColors.ink2,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.line,
    ),
  );
}
