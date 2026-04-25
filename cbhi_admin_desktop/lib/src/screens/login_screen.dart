import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../i18n/app_localizations.dart';
import '../theme/admin_theme.dart';
import '../shared/fcm_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.repository,
    required this.onLogin,
    required this.locale,
    required this.onLocaleChanged,
  });

  final AdminRepository repository;
  final VoidCallback onLogin;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  String? _error;

  // TOTP second-factor state
  bool _requiresTotp = false;
  final _totpController = TextEditingController();
  bool _totpLoading = false;
  String? _totpError;

  Future<void> _login() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;
    final strings = AppLocalizations.of(context);
    if (identifier.isEmpty || password.isEmpty) {
      setState(() => _error = strings.t('identifierRequired'));
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await widget.repository.login(
        identifier: identifier,
        password: password,
      );

      // Check if backend requires TOTP second factor
      final requiresTotp = response['requiresTotp'] == true ||
          response['requiresTotpVerification'] == true;

      if (requiresTotp) {
        // Show TOTP step — do NOT call onLogin yet
        setState(() {
          _requiresTotp = true;
          _isLoading = false;
        });
        return;
      }

      // Register FCM Token
      try {
        final token = await FcmService.instance.init();
        if (token != null) {
          await widget.repository.registerFcmToken(token);
        }
      } catch (e) {
        debugPrint('[FCM] Token registration failed: $e');
      }

      widget.onLogin();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyTotp() async {
    final strings = AppLocalizations.of(context);
    final code = _totpController.text.trim();

    if (code.length != 6) {
      setState(() => _totpError = strings.t('pleaseEnterAll6Digits'));
      return;
    }

    setState(() {
      _totpLoading = true;
      _totpError = null;
    });

    try {
      await widget.repository.verifyTotp(code);

      // Register FCM Token after successful TOTP
      try {
        final token = await FcmService.instance.init();
        if (token != null) {
          await widget.repository.registerFcmToken(token);
        }
      } catch (e) {
        debugPrint('[FCM] Token registration failed: $e');
      }

      widget.onLogin();
    } catch (e) {
      setState(() {
        _totpError = e.toString().replaceFirst('Exception: ', '');
        _totpLoading = false;
      });
    }
  }

  void _backToPassword() {
    setState(() {
      _requiresTotp = false;
      _totpController.clear();
      _totpError = null;
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _totpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      body: Row(
        children: [
          // Left panel — branding
          Expanded(
            flex: 2,
            child: Container(
              decoration: const BoxDecoration(
                gradient: AdminTheme.headerGradient,
              ),
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 56,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      strings.t('portalTitle'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      strings.t('portalSubtitle'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _FeatureRow(
                      icon: Icons.rule_folder_outlined,
                      label: strings.t('claimsReviewApproval'),
                    ),
                    const SizedBox(height: 12),
                    _FeatureRow(
                      icon: Icons.people_outlined,
                      label: strings.t('householdEnrollmentManagement'),
                    ),
                    const SizedBox(height: 12),
                    _FeatureRow(
                      icon: Icons.bar_chart_outlined,
                      label: strings.t('reportsAnalytics'),
                    ),
                    const SizedBox(height: 12),
                    _FeatureRow(
                      icon: Icons.settings_outlined,
                      label: strings.t('systemConfiguration'),
                    ),
                    const SizedBox(height: 12),
                    _FeatureRow(
                      icon: Icons.download_outlined,
                      label: strings.t('csvDataExport'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right panel — login form or TOTP step
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.white,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          )),
                          child: child,
                        ),
                      ),
                      child: _requiresTotp
                          ? _TotpStep(
                              key: const ValueKey('totp'),
                              strings: strings,
                              controller: _totpController,
                              error: _totpError,
                              isLoading: _totpLoading,
                              onVerify: _verifyTotp,
                              onBack: _backToPassword,
                            )
                          : _PasswordStep(
                              key: const ValueKey('password'),
                              strings: strings,
                              identifierController: _identifierController,
                              passwordController: _passwordController,
                              obscure: _obscure,
                              isLoading: _isLoading,
                              error: _error,
                              locale: widget.locale,
                              onLocaleChanged: widget.onLocaleChanged,
                              onToggleObscure: () =>
                                  setState(() => _obscure = !_obscure),
                              onLogin: _login,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Password Step (extracted from inline build)
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordStep extends StatelessWidget {
  const _PasswordStep({
    super.key,
    required this.strings,
    required this.identifierController,
    required this.passwordController,
    required this.obscure,
    required this.isLoading,
    required this.error,
    required this.locale,
    required this.onLocaleChanged,
    required this.onToggleObscure,
    required this.onLogin,
  });

  final AppLocalizations strings;
  final TextEditingController identifierController;
  final TextEditingController passwordController;
  final bool obscure;
  final bool isLoading;
  final String? error;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final VoidCallback onToggleObscure;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: PopupMenuButton<Locale>(
            tooltip: strings.t('language'),
            onSelected: onLocaleChanged,
            itemBuilder: (_) => AppLocalizations.supportedLocales
                .map(
                  (l) => PopupMenuItem<Locale>(
                    value: l,
                    child: Text(strings.languageLabel(l.languageCode)),
                  ),
                )
                .toList(growable: false),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.translate, size: 16, color: AdminTheme.primary),
                const SizedBox(width: 6),
                Text(
                  strings.languageLabel(locale.languageCode),
                  style: const TextStyle(
                    color: AdminTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          strings.t('signIn'),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AdminTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          strings.t('adminAccessOnly'),
          style: const TextStyle(color: AdminTheme.textSecondary),
        ),
        const SizedBox(height: 32),

        if (error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminTheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AdminTheme.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: const TextStyle(color: AdminTheme.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        TextField(
          controller: identifierController,
          decoration: InputDecoration(
            labelText: strings.t('emailOrPhone'),
            prefixIcon: const Icon(Icons.person_outline),
          ),
          onSubmitted: (_) => onLogin(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: passwordController,
          obscureText: obscure,
          decoration: InputDecoration(
            labelText: strings.t('password'),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: onToggleObscure,
            ),
          ),
          onSubmitted: (_) => onLogin(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isLoading ? null : onLogin,
            style: FilledButton.styleFrom(
              backgroundColor: AdminTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    strings.t('signIn'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AdminTheme.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AdminTheme.gold.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.science_outlined, size: 16, color: Color(0xFF856404)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.t('demoMode'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF856404)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOTP Second-Factor Step
// ─────────────────────────────────────────────────────────────────────────────

class _TotpStep extends StatelessWidget {
  const _TotpStep({
    super.key,
    required this.strings,
    required this.controller,
    required this.error,
    required this.isLoading,
    required this.onVerify,
    required this.onBack,
  });

  final AppLocalizations strings;
  final TextEditingController controller;
  final String? error;
  final bool isLoading;
  final VoidCallback onVerify;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back button
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new, size: 14),
          label: Text(strings.t('totpBackToPassword')),
          style: TextButton.styleFrom(
            foregroundColor: AdminTheme.textSecondary,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 16),

        // Icon
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AdminTheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.security_outlined,
            size: 32,
            color: AdminTheme.primary,
          ),
        ),
        const SizedBox(height: 20),

        Text(
          strings.t('totpVerificationTitle'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AdminTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          strings.t('totpVerificationSubtitle'),
          style: const TextStyle(color: AdminTheme.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 32),

        if (error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminTheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AdminTheme.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: const TextStyle(color: AdminTheme.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          decoration: InputDecoration(
            labelText: strings.t('totpCodeLabel'),
            prefixIcon: const Icon(Icons.pin_outlined),
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AdminTheme.primary, width: 2),
            ),
          ),
          onSubmitted: (_) => onVerify(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isLoading ? null : onVerify,
            style: FilledButton.styleFrom(
              backgroundColor: AdminTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    strings.t('totpVerify'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
