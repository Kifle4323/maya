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
      await widget.repository.login(identifier: identifier, password: password);
      
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

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
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

          // Right panel — login form
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.white,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: PopupMenuButton<Locale>(
                            tooltip: strings.t('language'),
                            onSelected: widget.onLocaleChanged,
                            itemBuilder: (_) => AppLocalizations
                                .supportedLocales
                                .map(
                                  (locale) => PopupMenuItem<Locale>(
                                    value: locale,
                                    child: Text(
                                      strings.languageLabel(
                                        locale.languageCode,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.translate,
                                  size: 16,
                                  color: AdminTheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  strings.languageLabel(
                                    widget.locale.languageCode,
                                  ),
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
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AdminTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.t('adminAccessOnly'),
                          style: const TextStyle(
                            color: AdminTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),

                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AdminTheme.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AdminTheme.error,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: AdminTheme.error,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        TextField(
                          controller: _identifierController,
                          decoration: InputDecoration(
                            labelText: strings.t('emailOrPhone'),
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          onSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: strings.t('password'),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          onSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _login,
                            style: FilledButton.styleFrom(
                              backgroundColor: AdminTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isLoading
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
                            border: Border.all(
                              color: AdminTheme.gold.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.science_outlined,
                                size: 16,
                                color: Color(0xFF856404),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  strings.t('demoMode'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF856404),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
