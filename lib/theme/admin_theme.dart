import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Dedicated administration palette.
/// Keeps customer/captain apps on the original dark VETO brand theme while
/// the admin workspace uses a clean reporting-oriented white/yellow look.
class AdminTheme {
  static final dark = ValueNotifier<bool>(false);
  static Future<void> loadPreference() async {
    dark.value =
        (await SharedPreferences.getInstance()).getBool('admin_dark_v9') ??
        false;
  }

  static Future<void> toggle() async {
    dark.value = !dark.value;
    await (await SharedPreferences.getInstance()).setBool(
      'admin_dark_v9',
      dark.value,
    );
  }

  static Color get background =>
      dark.value ? Color(0xFF0C111C) : Color(0xFFFFFDF6);
  static Color get surface => dark.value ? Color(0xFF171F2D) : Colors.white;
  static Color get surfaceSoft =>
      dark.value ? Color(0xFF202B3E) : Color(0xFFFFF8D9);
  static Color get surfaceStrong =>
      dark.value ? Color(0xFF423921) : Color(0xFFFFF1A8);
  static Color gold = Color(0xFFFFC247);
  static Color goldDark = Color(0xFFB98C00);
  static Color goldLight = Color(0xFFFFD84D);
  static Color get border => dark.value ? Color(0xFF69542B) : Color(0xFFF0D56A);
  static Color get borderSoft =>
      dark.value ? Color(0xFF323E51) : Color(0xFFF6E7AA);
  static Color get ink => dark.value ? Color(0xFFF5F3E9) : Color(0xFF241D00);
  static Color get muted => dark.value ? Color(0xFFADB8CA) : Color(0xFF756A3B);
  static Color get mutedLight =>
      dark.value ? Color(0xFF8999AF) : Color(0xFFA19669);
  static Color get success =>
      dark.value ? Color(0xFF8BD5A0) : Color(0xFF6F8B21);
  static Color get error => dark.value ? Color(0xFFFF9B86) : Color(0xFFB24B28);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    brightness: dark.value ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: background,
    textTheme: ThemeData(
      brightness: dark.value ? Brightness.dark : Brightness.light,
    ).textTheme.apply(fontFamily: 'Cairo'),
    colorScheme: ColorScheme(
      brightness: dark.value ? Brightness.dark : Brightness.light,
      primary: gold,
      onPrimary: const Color(0xFF0B0F1A),
      secondary: goldDark,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: ink,
      surfaceContainerHighest: surfaceSoft,
      onSurfaceVariant: muted,
      outline: border,
      error: error,
      onError: Colors.white,
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: surface,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: goldDark),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderSoft),
      ),
    ),
    dividerColor: borderSoft,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      labelStyle: TextStyle(color: muted),
      hintStyle: TextStyle(color: mutedLight),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: gold, width: 1.7),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: const Color(0xFF0B0F1A),
        minimumSize: const Size(48, 52),
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: const Color(0xFF0B0F1A),
        minimumSize: const Size(48, 52),
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: goldDark,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceSoft,
      selectedColor: surfaceStrong,
      side: BorderSide(color: borderSoft),
      labelStyle: TextStyle(color: ink, fontFamily: 'Cairo'),
    ),
  );
}
