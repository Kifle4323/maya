import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminTheme {
  AdminTheme._();

  // ── Shared palette ──────────────────────────────────────────────────────
  static const Color primary = Color(0xFF1565C0);
  static const Color accent = Color(0xFF00B0FF);
  static const Color gold = Color(0xFFFFA000);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);

  // ── Light palette ──────────────────────────────────────────────────────
  static const Color surface = Color(0xFFF5F7FA);
  static const Color sidebarBg = Color(0xFF0D1B2A);
  static const Color sidebarText = Color(0xFFB0C4DE);
  static const Color sidebarSelected = Color(0xFF00B0FF);
  static const Color textDark = Color(0xFF0D1B2A);
  static const Color textSecondary = Color(0xFF4A6572);

  // ── Dark palette ───────────────────────────────────────────────────────
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkCard = Color(0xFF1E1E2E);
  static const Color darkSidebarBg = Color(0xFF0A0E1A);
  static const Color darkSidebarText = Color(0xFF8EACC8);
  static const Color darkTextPrimary = Color(0xFFE0E6ED);
  static const Color darkTextSecondary = Color(0xFF8EACC8);
  static const Color darkInputBg = Color(0xFF252535);
  static const Color darkBorder = Color(0xFF3A3A4A);
  static const Color darkTopBar = Color(0xFF1A1A2E);

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF1565C0), Color(0xFF00B0FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Light theme ────────────────────────────────────────────────────────
  static ThemeData? _cachedTheme;
  static ThemeData get theme => _cachedTheme ??= _buildLightTheme();

  static ThemeData _buildLightTheme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
      ),
      scaffoldBackgroundColor: surface,
    );

    final textTheme = GoogleFonts.outfitTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        titleTextStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w700,
          color: textDark,
          fontSize: 20,
        ),
        shadowColor: Colors.black.withValues(alpha: 0.05),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(surface),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return primary.withValues(alpha: 0.04);
          }
          return Colors.white;
        }),
        headingTextStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w700,
          color: textSecondary,
          fontSize: 13,
        ),
        dataTextStyle: GoogleFonts.outfit(color: textDark, fontSize: 13),
        dividerThickness: 1,
        columnSpacing: 24,
      ),
    );
  }

  // ── Dark theme ─────────────────────────────────────────────────────────
  static ThemeData? _cachedDarkTheme;
  static ThemeData get darkTheme => _cachedDarkTheme ??= _buildDarkTheme();

  static ThemeData _buildDarkTheme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        primary: accent,
        secondary: primary,
        surface: darkSurface,
        error: error,
        onSurface: darkTextPrimary,
      ),
      scaffoldBackgroundColor: darkSurface,
    );

    final textTheme = GoogleFonts.outfitTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: darkTopBar,
        foregroundColor: darkTextPrimary,
        titleTextStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
          fontSize: 20,
        ),
        shadowColor: Colors.black.withValues(alpha: 0.3),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInputBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(darkCard),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return accent.withValues(alpha: 0.08);
          }
          return darkSurface;
        }),
        headingTextStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w700,
          color: darkTextSecondary,
          fontSize: 13,
        ),
        dataTextStyle: GoogleFonts.outfit(color: darkTextPrimary, fontSize: 13),
        dividerThickness: 1,
        columnSpacing: 24,
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
      ),
    );
  }

  // ── Sidebar helpers that adapt to brightness ───────────────────────────
  static Color sidebarBgFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSidebarBg : sidebarBg;

  static Color sidebarTextFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSidebarText : sidebarText;

  static Color topBarBgFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkTopBar : Colors.white;

  static Color topBarTextFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkTextPrimary : textDark;

  static Color dividerFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkBorder : const Color(0xFF1E3530);

  static Color textPrimaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkTextPrimary : textDark;

  static Color textSecondaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkTextSecondary : textSecondary;

  static Color cardBgFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkCard : Colors.white;
}
