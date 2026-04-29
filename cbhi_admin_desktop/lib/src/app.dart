import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/admin_repository.dart';
import 'i18n/app_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'theme/admin_theme.dart';

class CbhiAdminApp extends StatefulWidget {
  const CbhiAdminApp({super.key, required this.repository});

  final AdminRepository repository;

  @override
  State<CbhiAdminApp> createState() => _CbhiAdminAppState();
}

class _CbhiAdminAppState extends State<CbhiAdminApp> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = AppLocalizations.resolveAppLocale(
    WidgetsBinding.instance.platformDispatcher.locale,
  );

  @override
  void initState() {
    super.initState();
    // If no stored token, skip network calls and show login immediately
    if (!widget.repository.isAuthenticated) {
      _isLoading = false;
      _isAuthenticated = false;
    } else {
      // Has a token — validate it in the background while showing splash
      _validateToken();
    }
  }

  Future<void> _validateToken() async {
    try {
      final valid = await widget.repository.ping().timeout(const Duration(seconds: 5));
      debugPrint('[AdminApp] Ping result: $valid');
      if (!valid) {
        // Backend unreachable — still show main shell (offline mode)
        if (mounted) setState(() { _isAuthenticated = true; _isLoading = false; });
        return;
      }
      // Try a lightweight auth check
      try {
        await widget.repository.getSummaryReport().timeout(const Duration(seconds: 8));
        debugPrint('[AdminApp] Auth check passed');
        if (mounted) setState(() { _isAuthenticated = true; _isLoading = false; });
      } catch (e) {
        debugPrint('[AdminApp] Auth check failed: $e');
        // Token invalid/expired — force re-login
        await widget.repository.logout();
        if (mounted) setState(() { _isAuthenticated = false; _isLoading = false; });
      }
    } catch (e) {
      debugPrint('[AdminApp] Token validation error: $e');
      if (mounted) setState(() { _isAuthenticated = true; _isLoading = false; });
    }
  }

  void _onLogin() {
    setState(() => _isAuthenticated = true);
  }

  @override
  Widget build(BuildContext context) {
    final frameworkLocale = AppLocalizations.resolveFrameworkLocale(_locale);
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
      theme: AdminTheme.theme,
      darkTheme: AdminTheme.darkTheme,
      themeMode: _themeMode,
      home: _isLoading
          ? const _SplashScreen()
          : !_isAuthenticated
          ? LoginScreen(
              repository: widget.repository,
              onLogin: _onLogin,
              locale: _locale,
              onLocaleChanged: (locale) => setState(() => _locale = locale),
            )
          : MainShell(
              repository: widget.repository,
              onLogout: () => setState(() => _isAuthenticated = false),
              locale: _locale,
              onLocaleChanged: (locale) => setState(() => _locale = locale),
              themeMode: _themeMode,
              onThemeChanged: (mode) => setState(() => _themeMode = mode),
            ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.admin_panel_settings,
              size: 64,
              color: AdminTheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              strings.t('appTitle'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const CircularProgressIndicator(color: AdminTheme.primary),
          ],
        ),
      ),
    );
  }
}
