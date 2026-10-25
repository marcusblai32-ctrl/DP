import 'package:flutter/material.dart';

/// Palette de DP (identité noir / rouge conservée).
class AppColors {
  const AppColors._();

  static const Color ink = Color(0xFF090A0D);
  static const Color panel = Color(0xFF15171D);
  static const Color panelHigh = Color(0xFF1E2128);
  static const Color border = Color(0xFF30333D);
  static const Color red = Color(0xFFE51C35);
  static const Color redSoft = Color(0xFFFF6575);
  static const Color redTint = Color(0x29E51C35);
  static const Color redBorder = Color(0x73E51C35);
  static const Color muted = Color(0xFFB4BAC8);
  static const Color success = Color(0xFF4CD995);
  static const Color warning = Color(0xFFFFBE55);
  static const Color info = Color(0xFF6CB6FF);
  static const Color danger = Color(0xFFFF6B6B);
}

/// Thème global de l'application. Appliqué au niveau de MaterialApp afin que
/// les dialogues, feuilles et menus héritent aussi du thème sombre.
ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.red,
    onPrimary: Colors.white,
    secondary: AppColors.redSoft,
    onSecondary: Colors.black,
    surface: AppColors.panel,
    onSurface: Colors.white,
    error: AppColors.danger,
    onError: Colors.black,
    outline: AppColors.border,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
  );

  final shape12 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.ink,
    visualDensity: VisualDensity.standard,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ink,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppColors.panel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.panel,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.redTint,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? AppColors.redSoft : AppColors.muted,
          )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? AppColors.redSoft : AppColors.muted,
          )),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.red,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.panelHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.redSoft, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.muted),
      floatingLabelStyle: const TextStyle(color: AppColors.redSoft),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.red,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: shape12,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        side: const BorderSide(color: AppColors.border),
        shape: shape12,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.redSoft,
        minimumSize: const Size(48, 48),
        shape: shape12,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.panelHigh,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: shape12,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.panelHigh,
      surfaceTintColor: Colors.transparent,
      shape: shape12,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
    listTileTheme: ListTileThemeData(shape: shape12),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.red,
      linearTrackColor: Color(0xFF333640),
    ),
  );
}
