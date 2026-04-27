import 'package:flutter/material.dart';

/// Premium CBHI design system — HealthShield M3 palette.
class AppTheme {
  AppTheme._();

  // ───── M3 HealthShield Palette ─────
  static const Color m3Primary = Color(0xFF005DAC);
  static const Color m3PrimaryContainer = Color(0xFF1976D2);
  static const Color m3OnPrimary = Color(0xFFFFFFFF);
  static const Color m3OnPrimaryContainer = Color(0xFFFFFDFF);
  static const Color m3Secondary = Color(0xFF5D5F5F);
  static const Color m3SecondaryContainer = Color(0xFFDCDDDD);
  static const Color m3OnSecondaryContainer = Color(0xFF5F6161);
  static const Color m3Tertiary = Color(0xFF00695C);
  static const Color m3TertiaryContainer = Color(0xFF2D8274);
  static const Color m3OnTertiaryContainer = Color(0xFFF8FFFC);
  static const Color m3Surface = Color(0xFFFBF8FE);
  static const Color m3SurfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color m3SurfaceContainerLow = Color(0xFFF6F2F8);
  static const Color m3SurfaceContainer = Color(0xFFF0EDF2);
  static const Color m3SurfaceContainerHigh = Color(0xFFEAE7ED);
  static const Color m3SurfaceContainerHighest = Color(0xFFE4E1E7);
  static const Color m3OnSurface = Color(0xFF1B1B1F);
  static const Color m3OnSurfaceVariant = Color(0xFF414752);
  static const Color m3Outline = Color(0xFF717783);
  static const Color m3OutlineVariant = Color(0xFFC1C6D4);
  static const Color m3ErrorContainer = Color(0xFFFFDAD6);
  static const Color m3OnErrorContainer = Color(0xFF93000A);
  static const Color m3SurfaceVariant = Color(0xFFE4E1E7);
  static const Color m3PrimaryFixed = Color(0xFFD4E3FF);
  static const Color m3OnPrimaryFixed = Color(0xFF001C3A);
  static const Color m3OnPrimaryFixedVariant = Color(0xFF004786);

  // ───── Legacy Brand Palette (kept for backward compat) ─────
  static const Color primary = m3Primary;
  static const Color primaryDark = Color(0xFF004786);
  static const Color accent = m3PrimaryContainer;
  static const Color gold = Color(0xFFFFA000);
  static const Color surfaceLight = m3SurfaceContainerLow;
  static const Color surfaceCard = m3SurfaceContainerLowest;
  static const Color textDark = m3OnSurface;
  static const Color textSecondary = m3OnSurfaceVariant;
  static const Color error = Color(0xFFBA1A1A);
  static const Color success = m3Tertiary;
  static const Color warning = Color(0xFFF57C00);
  static const Color info = m3PrimaryContainer;

  // Surface hierarchy (elevation system)
  static const Color surface0 = m3SurfaceContainerLow;  // page background
  static const Color surface1 = m3SurfaceContainerLowest; // card background
  static const Color surface2 = m3SurfaceContainer;     // subtle section bg
  static const Color surface3 = m3SurfaceContainerHigh; // pressed/hover state

  // ───── Dark mode surfaces
  static const Color darkSurface0 = Color(0xFF0F1A17);
  static const Color darkSurface1 = Color(0xFF1A2E28);
  static const Color darkSurface2 = Color(0xFF243D35);

  // ───── Context-aware color helpers ─────
  // Use these instead of hardcoded m3OnSurface/m3OnSurfaceVariant in widgets
  // so text is visible in both light and dark mode.
  static Color onSurface(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color onSurfaceVariant(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color surfaceContainerLowAdaptive(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerLow;

  static Color surfaceContainerAdaptive(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainer;

  static Color outlineVariantAdaptive(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  // Gradient presets — M3 blue family
  static const LinearGradient heroGradient = LinearGradient(
    colors: [m3Primary, m3PrimaryContainer],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient welcomeGradient = LinearGradient(
    colors: [m3OnPrimaryFixedVariant, m3Primary, m3PrimaryContainer],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [m3Primary, m3PrimaryContainer],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ───── Shape ─────
  static const double radiusXS = 6;
  static const double radiusS = 12;
  static const double radiusM = 16;
  static const double radiusL = 24;
  static const double radiusXL = 32;

  // ───── Spacing ─────
  static const double spacingXS = 4;
  static const double spacingS = 8;
  static const double spacingM = 16;
  static const double spacingL = 24;
  static const double spacingXL = 32;
  static const double spacingXXL = 48;

  // ───── Motion ─────
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);

  // ───── Elevation & Shadows ─────
  // Modern Material 3 relies on tonal elevation and surface colors,
  // but if explicit shadows are needed, keep them extremely subtle.
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get subtleShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.02),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  // ───── ThemeData ─────
  static ThemeData get lightTheme {
    final textTheme = Typography.material2021().black.apply(
      fontFamily: 'Outfit',
    );

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: m3Primary,
      onPrimary: m3OnPrimary,
      primaryContainer: m3PrimaryContainer,
      onPrimaryContainer: m3OnPrimaryContainer,
      secondary: m3Secondary,
      onSecondary: m3OnPrimary,
      secondaryContainer: m3SecondaryContainer,
      onSecondaryContainer: m3OnSecondaryContainer,
      tertiary: m3Tertiary,
      onTertiary: m3OnPrimary,
      tertiaryContainer: m3TertiaryContainer,
      onTertiaryContainer: m3OnTertiaryContainer,
      error: error,
      onError: m3OnPrimary,
      errorContainer: m3ErrorContainer,
      onErrorContainer: m3OnErrorContainer,
      surface: m3Surface,
      onSurface: m3OnSurface,
      onSurfaceVariant: m3OnSurfaceVariant,
      outline: m3Outline,
      outlineVariant: m3OutlineVariant,
      surfaceContainerLowest: m3SurfaceContainerLowest,
      surfaceContainerLow: m3SurfaceContainerLow,
      surfaceContainer: m3SurfaceContainer,
      surfaceContainerHigh: m3SurfaceContainerHigh,
      surfaceContainerHighest: m3SurfaceContainerHighest,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: m3SurfaceContainerLow,
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: m3OnSurface,
        ),
        displayMedium: textTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: m3OnSurface,
        ),
        displaySmall: textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: m3OnSurface,
        ),
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: m3OnSurface,
          fontSize: 32,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: m3OnSurface,
          fontSize: 28,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: m3OnSurface,
          fontSize: 22,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: m3OnSurface,
          fontSize: 22,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: m3OnSurface,
          fontSize: 16,
          letterSpacing: 0.15,
        ),
        titleSmall: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: m3OnSurface,
          fontSize: 14,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: m3OnSurface,
          fontSize: 16,
          letterSpacing: 0.5,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: m3OnSurfaceVariant,
          fontSize: 14,
          letterSpacing: 0.25,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: m3OnSurfaceVariant,
          fontSize: 12,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: m3OnSurface,
          fontSize: 14,
          letterSpacing: 0.1,
        ),
        labelMedium: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: m3OnSurfaceVariant,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
        labelSmall: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: m3OnSurfaceVariant,
          fontSize: 11,
        ),
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: m3SurfaceContainerLowest.withValues(alpha: 0.8),
        foregroundColor: m3OnSurface,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: m3Primary,
          fontSize: 18,
          letterSpacing: -0.5,
        ),
        surfaceTintColor: Colors.transparent,
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        color: m3SurfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
          side: BorderSide(color: m3OutlineVariant.withValues(alpha: 0.3)),
        ),
        margin: EdgeInsets.zero,
        shadowColor: Colors.black.withValues(alpha: 0.02),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: m3SecondaryContainer,
        selectedColor: m3PrimaryContainer.withValues(alpha: 0.2),
        labelStyle: textTheme.labelMedium?.copyWith(color: m3Primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        side: BorderSide(color: m3OutlineVariant.withValues(alpha: 0.3)),
      ),

      // Buttons — pill-shaped per M3 HealthShield spec
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: const StadiumBorder(),
          backgroundColor: m3Primary,
          foregroundColor: m3OnPrimary,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: const StadiumBorder(),
          side: BorderSide(color: m3Outline),
          foregroundColor: m3OnSurface,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: m3Primary,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: m3SurfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: const BorderSide(color: m3Primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: const BorderSide(color: error),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: m3OnSurfaceVariant),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: m3OnSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),

      // NavigationBar — M3 HealthShield bottom nav
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: m3SurfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: m3Primary.withValues(alpha: 0.1),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              color: m3Primary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            );
          }
          return textTheme.labelSmall?.copyWith(
            color: m3OnSurfaceVariant,
            fontSize: 11,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: m3Primary, size: 24);
          }
          return IconThemeData(color: m3OnSurfaceVariant, size: 24);
        }),
      ),

      // TabBar
      tabBarTheme: TabBarThemeData(
        indicatorColor: m3Primary,
        labelColor: m3Primary,
        unselectedLabelColor: m3OnSurfaceVariant,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: m3OutlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),

      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusL)),
        ),
        backgroundColor: m3SurfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
        backgroundColor: m3SurfaceContainerLowest,
      ),

      // Dropdown
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: m3SurfaceContainerHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusS),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ───── Dark Theme ─────
  static ThemeData get darkTheme {
    const darkSurface = Color(0xFF111318);
    const darkCard = Color(0xFF1C1F26);
    const darkText = Color(0xFFE3E2E6);
    const darkTextSecondary = Color(0xFF8D9199);

    final textTheme = Typography.material2021().white.apply(
      fontFamily: 'Outfit',
    );

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: const Color(0xFFA5C8FF),
      onPrimary: const Color(0xFF003063),
      primaryContainer: const Color(0xFF004786),
      onPrimaryContainer: const Color(0xFFD4E3FF),
      secondary: const Color(0xFFC6C6C7),
      onSecondary: const Color(0xFF303131),
      secondaryContainer: const Color(0xFF454747),
      onSecondaryContainer: const Color(0xFFE2E2E2),
      tertiary: const Color(0xFF84D5C5),
      onTertiary: const Color(0xFF003731),
      tertiaryContainer: const Color(0xFF005046),
      onTertiaryContainer: const Color(0xFFA0F2E1),
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      errorContainer: const Color(0xFF93000A),
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: darkSurface,
      onSurface: darkText,
      onSurfaceVariant: darkTextSecondary,
      outline: const Color(0xFF8D9199),
      outlineVariant: const Color(0xFF414752),
      surfaceContainerLowest: const Color(0xFF0C0F14),
      surfaceContainerLow: darkSurface,
      surfaceContainer: darkCard,
      surfaceContainerHigh: const Color(0xFF262930),
      surfaceContainerHighest: const Color(0xFF31343B),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkSurface,
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w700, color: darkText),
        displayMedium: textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700, color: darkText),
        displaySmall: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, color: darkText),
        headlineLarge: textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w600, color: darkText),
        headlineMedium: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600, color: darkText),
        headlineSmall: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: darkText),
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: darkText),
        titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500, color: darkText),
        bodyLarge: textTheme.bodyLarge?.copyWith(color: darkText),
        bodyMedium: textTheme.bodyMedium?.copyWith(color: darkTextSecondary),
        bodySmall: textTheme.bodySmall?.copyWith(color: darkTextSecondary),
        labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: darkText),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: darkCard.withValues(alpha: 0.9),
        foregroundColor: darkText,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFFA5C8FF),
          fontSize: 18,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
          side: const BorderSide(color: Color(0xFF414752), width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: const BorderSide(color: Color(0xFFA5C8FF), width: 2),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: darkTextSecondary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: darkTextSecondary.withValues(alpha: 0.5)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFA5C8FF).withValues(alpha: 0.15),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              color: const Color(0xFFA5C8FF),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            );
          }
          return textTheme.labelSmall?.copyWith(color: darkTextSecondary, fontSize: 11);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFFA5C8FF), size: 24);
          }
          return IconThemeData(color: darkTextSecondary, size: 24);
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusL)),
        ),
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: const StadiumBorder(),
          backgroundColor: const Color(0xFFA5C8FF),
          foregroundColor: const Color(0xFF003063),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: const StadiumBorder(),
          side: const BorderSide(color: Color(0xFF8D9199)),
          foregroundColor: darkText,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF414752),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
