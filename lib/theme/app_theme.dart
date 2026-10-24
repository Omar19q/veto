// Black/gold brand. Admin retains the established dark theme.
import 'package:flutter/material.dart';

class AppTheme {
  static String productFontFamily(BuildContext context) {
    final family = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return const ['Inter', 'IBMPlexSansArabic', 'Cairo'].contains(family)
        ? family!
        : 'Cairo';
  }

  /// Product typography is embedded; admin continues using the legacy theme.
  static ThemeData productTheme(Brightness brightness, String language) {
    final base = brightness == Brightness.dark ? darkTheme : lightTheme;
    final family = language == 'en' ? 'Inter' : 'IBMPlexSansArabic';
    TextTheme typography(TextTheme theme) => theme
        .apply(
          fontFamily: family,
          fontFamilyFallback: const ['Cairo', 'IBMPlexSansArabic', 'Inter'],
        )
        .copyWith(
          titleLarge: theme.titleLarge?.copyWith(
            fontFamily: family,
            fontSize: 20,
          ),
          titleMedium: theme.titleMedium?.copyWith(
            fontFamily: family,
            fontSize: 17,
          ),
          titleSmall: theme.titleSmall?.copyWith(
            fontFamily: family,
            fontSize: 16,
          ),
          bodyLarge: theme.bodyLarge?.copyWith(
            fontFamily: family,
            fontSize: 17,
          ),
          bodyMedium: theme.bodyMedium?.copyWith(
            fontFamily: family,
            fontSize: 16,
          ),
          bodySmall: theme.bodySmall?.copyWith(
            fontFamily: family,
            fontSize: 14,
          ),
          labelLarge: theme.labelLarge?.copyWith(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          labelMedium: theme.labelMedium?.copyWith(
            fontFamily: 'Inter',
            fontSize: 14,
          ),
          labelSmall: theme.labelSmall?.copyWith(
            fontFamily: 'Inter',
            fontSize: 12,
          ),
        );
    return base.copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          backgroundColor: brightness == Brightness.dark
              ? const Color(0xFFFFC107)
              : const Color(0xFF0B0F1A),
          foregroundColor: brightness == Brightness.dark
              ? primary
              : Colors.white,
          textStyle: TextStyle(
            fontFamily: family,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: base.colorScheme.surface,
        modalBackgroundColor: base.colorScheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      textTheme: typography(base.textTheme),
      primaryTextTheme: typography(base.primaryTextTheme),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: base.elevatedButtonTheme.style?.copyWith(
          minimumSize: const WidgetStatePropertyAll(Size(48, 52)),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: family,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        hintStyle: base.inputDecorationTheme.hintStyle?.copyWith(
          fontFamily: family,
        ),
      ),
    );
  }

  // Brand Colors
  static const Color primary = Color(0xFF0B0F1A);
  static const Color gold = Color(0xFFFFC107);
  static const Color goldDark = Color(0xFFE5A800);
  static const Color goldLight = Color(0xFFFFD54F);
  static const Color surface = Color(0xFF13182A);
  static const Color surfaceVariant = Color(0xFF1E2540);
  static const Color surfaceElevated = Color(0xFF252D45);
  static const Color backgroundDark = Color(0xFF0B0F1A);
  static const Color cardBorder = Color(0xFF2A3355);

  // Semantic Colors
  static const Color tertiary = Color(0xFF10B981);
  static const Color neutral = Color(0xFF94A3B8);
  static const Color routeIndigo = Color(0xFF0B0F1A);
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFB45309);
  static const Color error = Color(0xFFB91C1C);
  static const Color errorLight = Color(0xFFEF5350);
  static const Color whatsapp = Color(0xFF25D366);

  // Text Colors
  static const Color textPrimary = Color(0xFFF0F2F8);
  static const Color textSecondary = Color(0xFFBCC5DE);
  static const Color textMuted = Color(0xFFAAB5CF);

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF0B0F1A),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF1E2540),
      onPrimaryContainer: Colors.white,
      secondary: Color(0xFF10B981),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFD1FAE5),
      onSecondaryContainer: Color(0xFF065F46),
      tertiary: Color(0xFF10B981),
      onTertiary: Colors.white,
      surface: Colors.white,
      onSurface: Color(0xFF0F172A),
      surfaceContainerHighest: Color(0xFFF1F5F9),
      surfaceContainerLow: Color(0xFFF8FAFC),
      onSurfaceVariant: Color(0xFF64748B),
      outline: Color(0xFFCBD5E1),
      outlineVariant: Color(0xFFE2E8F0),
      error: Color(0xFFDC2626),
      onError: Colors.white,
    ),
    textTheme: _buildTextTheme(Brightness.light),
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    appBarTheme: const AppBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: Color(0xFF0F172A)),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFF0B0F1A), width: 2),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFFDC2626)),
      ),
      labelStyle: const TextStyle(color: Color(0xFF64748B)),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0B0F1A),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: gold,
      onPrimary: backgroundDark,
      primaryContainer: Color(0xFF2A1F00),
      onPrimaryContainer: goldLight,
      secondary: goldDark,
      onSecondary: backgroundDark,
      secondaryContainer: Color(0xFF1E2540),
      onSecondaryContainer: textPrimary,
      tertiary: Color(0xFF10B981),
      onTertiary: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: Color(0xFF1F293D),
      onSurfaceVariant: Color(0xFF94A3B8),
      error: errorLight,
      onError: Colors.white,
      outline: cardBorder,
      outlineVariant: Color(0xFF1E293B),
      inverseSurface: textPrimary,
      onInverseSurface: primary,
      shadow: Colors.black,
    ),
    textTheme: _buildTextTheme(Brightness.dark),
    scaffoldBackgroundColor: backgroundDark,
    appBarTheme: const AppBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: textPrimary),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: cardBorder, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: gold, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorLight),
      ),
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: const TextStyle(color: textMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: primary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );

  static TextTheme _buildTextTheme(Brightness brightness) {
    final Color onSurface = brightness == Brightness.dark
        ? textPrimary
        : primary;
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      headlineLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: brightness == Brightness.dark
            ? textSecondary
            : const Color(0xFF666666),
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: brightness == Brightness.dark
            ? textSecondary
            : const Color(0xFF888888),
      ),
    ).apply(fontFamily: 'Cairo');
  }
}
