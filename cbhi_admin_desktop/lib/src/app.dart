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
    setState(() {
      _isAuthenticated = widget.repository.isAuthenticated;
      _isLoading = false;
    });
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
