import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'data/facility_repository.dart';
import 'i18n/app_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';

const Color kPrimary = Color(0xFF0D7A5F);
const Color kAccent = Color(0xFF00BFA5);
const Color kSurface = Color(0xFFF0F4F3);
const Color kSidebarBg = Color(0xFF0D1F1A);
const Color kTextDark = Color(0xFF1A2E35);
const Color kTextSecondary = Color(0xFF5A7A84);
const Color kSuccess = Color(0xFF2E7D52);
const Color kError = Color(0xFFE53935);
const Color kWarning = Color(0xFFFF8F00);

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
        setState(() { _authenticated = true; _loading = false; });
        return;
      }
      try {
        await widget.repository.getClaims();
        setState(() { _authenticated = true; _loading = false; });
      } catch (e) {
        await widget.repository.logout();
        setState(() { _authenticated = false; _loading = false; });
      }
    } else {
      setState(() { _authenticated = false; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final frameworkLocale = AppLocalizations.resolveFrameworkLocale(_locale);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kPrimary,
        primary: kPrimary,
        secondary: kAccent,
        surface: kSurface,
      ),
      scaffoldBackgroundColor: kSurface,
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
            borderSide: const BorderSide(color: kPrimary, width: 2),
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
          headingRowColor: WidgetStateProperty.all(kSurface),
          dataRowColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return kPrimary.withValues(alpha: 0.04);
            }
            return Colors.white;
          }),
          dividerThickness: 1,
          columnSpacing: 24,
        ),
      ),
      home: _loading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator(color: kPrimary)),
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
