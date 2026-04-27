import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'data/facility_repository.dart';
import 'i18n/app_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';

/// CBHI standard palette — matches AdminTheme and AppTheme exactly.
class FacilityTheme {
  FacilityTheme._();

  static const Color primary = Color(0xFF1565C0);
  static const Color accent = Color(0xFF00B0FF);
  static const Color gold = Color(0xFFFFA000);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);
  static const Color surface = Color(0xFFF5F7FA);
  static const Color sidebarBg = Color(0xFF0D1B2A);
  static const Color textDark = Color(0xFF0D1B2A);
  static const Color textSecondary = Color(0xFF4A6572);

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF1565C0), Color(0xFF00B0FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// Legacy top-level constants kept for backward compatibility with existing screens.
const Color kPrimary = FacilityTheme.primary;
const Color kAccent = FacilityTheme.accent;
const Color kSurface = FacilityTheme.surface;
const Color kSidebarBg = FacilityTheme.sidebarBg;
const Color kTextDark = FacilityTheme.textDark;
const Color kTextSecondary = FacilityTheme.textSecondary;
const Color kSuccess = FacilityTheme.success;
const Color kError = FacilityTheme.error;
const Color kWarning = FacilityTheme.warning;

class CbhiFacilityApp extends StatefulWidget {
  const CbhiFacilityApp({super.key, required this.repository});
  final FacilityRepository repository;

  @override
  State<CbhiFacilityApp> createState() => _CbhiFacilityAppState();
}

class _CbhiFacilityAppState extends State<CbhiFacilityApp> {
  bool _loading = true;
  bool _authenticated = false;
  Locale _locale = AppLocalizations.resolveAppLocale(
    WidgetsBinding.instance.platformDispatcher.locale,
  );

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await widget.repository.init();
    if (widget.repository.isAuthenticated) {
      final valid = await widget.repository.ping();
      if (!valid) {
        setState(() {
          _authenticated = true;
          _loading = false;
        });
        return;
      }
      try {
        await widget.repository.getClaims();
        setState(() {
          _authenticated = true;
          _loading = false;
        });
      } catch (e) {
        await widget.repository.logout();
        setState(() {
          _authenticated = false;
          _loading = false;
        });
      }
    } else {
      setState(() {
        _authenticated = false;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final frameworkLocale = AppLocalizations.resolveFrameworkLocale(_locale);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: FacilityTheme.primary,
        primary: FacilityTheme.primary,
        secondary: FacilityTheme.accent,
        surface: FacilityTheme.surface,
        error: FacilityTheme.error,
      ),
      scaffoldBackgroundColor: FacilityTheme.surface,
    );

    return MaterialApp(
      title: AppLocalizations(_locale).t('appWindowTitle'),
      debugShowCheckedModeBanner: false,
      locale: frameworkLocale,
      supportedLocales: AppLocalizations.frameworkSupportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegateFor(_locale),
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: base.copyWith(
        textTheme: GoogleFonts.outfitTextTheme(base.textTheme),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: EdgeInsets.zero,
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
            borderSide: const BorderSide(color: FacilityTheme.primary, width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        dataTableTheme: DataTableThemeData(
          headingRowColor: WidgetStateProperty.all(FacilityTheme.surface),
          dataRowColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return FacilityTheme.primary.withValues(alpha: 0.04);
            }
            return Colors.white;
          }),
          dividerThickness: 1,
          columnSpacing: 24,
        ),
      ),
      home: _loading
          ? Scaffold(
              body: Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.contain,
                ),
              ),
            )
          : _authenticated
          ? MainShell(
              repository: widget.repository,
              onLogout: () => setState(() => _authenticated = false),
              locale: _locale,
              onLocaleChanged: (locale) => setState(() => _locale = locale),
            )
          : LoginScreen(
              repository: widget.repository,
              onLogin: () => setState(() => _authenticated = true),
              locale: _locale,
              onLocaleChanged: (locale) => setState(() => _locale = locale),
            ),
    );
  }
}
