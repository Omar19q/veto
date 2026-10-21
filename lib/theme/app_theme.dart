// Black/gold brand. Admin retains the established dark theme.
import 'package:flutter/material.dart';

class AppTheme {
  static String productFontFamily(BuildContext context) {
    final family = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return const ['Inter', 'IBMPlexSansArabic'].contains(family)
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
          fontFamilyFallback: const ['IBMPlexSansArabic', 'Inter'],
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
          labelMedium: theme.labelMedium?.copyWith(
            fontFamily: family,
            fontSize: 14,
          ),
          labelSmall: theme.labelSmall?.copyWith(
            fontFamily: family,
            fontSize: 12,
          ),
        );
    return base.copyWith(
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          backgroundColor: const Color(0xFFFFC247),
          foregroundColor: primary,
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
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: TextStyle(
            fontFamily: family,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
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
  static const Color success = Color(0xFF2D7A4F);
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
    colorScheme: ColorScheme.light(
      primary: const Color(0xFF8A6500),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFFFE69A),
      onPrimaryContainer: const Color(0xFF2A1F00),
      secondary: const Color(0xFF715A1B),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFF7E8BC),
      onSecondaryContainer: primary,
      surface: Colors.white,
      onSurface: primary,
      surfaceContainerHighest: const Color(0xFFEAECEF),
      onSurfaceVariant: const Color(0xFF454A56),
      outline: const Color(0xFF767B87),
      outlineVariant: const Color(0xFFD5D8DF),
      error: error,
      onError: Colors.white,
    ),
    textTheme: _buildTextTheme(Brightness.light),
    scaffoldBackgroundColor: const Color(0xFFF5F6FA),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: gold,
      onPrimary: primary,
      primaryContainer: const Color(0xFF2A1F00),
      onPrimaryContainer: goldLight,
      secondary: goldDark,
      onSecondary: primary,
      secondaryContainer: const Color(0xFF1E2540),
      onSecondaryContainer: textPrimary,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceVariant,
      onSurfaceVariant: textSecondary,
      error: errorLight,
      onError: Colors.white,
      outline: cardBorder,
      outlineVariant: const Color(0xFF1A2035),
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
