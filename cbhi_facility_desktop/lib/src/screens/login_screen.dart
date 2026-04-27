import 'package:flutter/material.dart';
import '../app.dart';
import '../data/facility_repository.dart';
import '../i18n/app_localizations.dart';
import '../shared/fcm_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.repository,
    required this.onLogin,
    required this.locale,
    required this.onLocaleChanged,
  });
  final FacilityRepository repository;
  final VoidCallback onLogin;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _login() async {
    final strings = AppLocalizations.of(context);
    if (_idCtrl.text.trim().isEmpty || _pwCtrl.text.isEmpty) {
      setState(() => _error = strings.t('identifierRequired'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.login(
        identifier: _idCtrl.text.trim(),
        password: _pwCtrl.text,
      );

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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      body: Row(
        children: [
          // Left branding panel
          Expanded(
            flex: 2,
            child: Container(
              decoration: const BoxDecoration(
                gradient: FacilityTheme.headerGradient,
              ),
              padding: const EdgeInsets.all(48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 56,
                      height: 56,
                      fit: BoxFit.contain,
                    ),
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
                  _Row(
                    icon: Icons.verified_user_outlined,
                    label: strings.t('realtimeEligibility'),
                  ),
                  const SizedBox(height: 12),
                  _Row(
                    icon: Icons.note_add_outlined,
                    label: strings.t('multiItemClaimSubmission'),
                  ),
                  const SizedBox(height: 12),
                  _Row(
                    icon: Icons.fact_check_outlined,
                    label: strings.t('claimStatusTracking'),
                  ),
                  const SizedBox(height: 12),
                  _Row(
                    icon: Icons.qr_code_scanner_outlined,
                    label: strings.t('qrLookup'),
                  ),
                ],
              ),
            ),
          ),

          // Right login form
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
                                  color: kPrimary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  strings.languageLabel(
                                    widget.locale.languageCode,
                                  ),
                                  style: const TextStyle(
                                    color: kPrimary,
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
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: kTextDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.t('staffAccessOnly'),
                          style: const TextStyle(color: kTextSecondary),
                        ),
                        const SizedBox(height: 32),
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: kError.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: kError,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: kError,
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
                          controller: _idCtrl,
                          decoration: InputDecoration(
                            labelText: strings.t('emailOrPhone'),
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          onSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _pwCtrl,
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
                            onPressed: _loading ? null : _login,
                            style: FilledButton.styleFrom(
                              backgroundColor: kPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _loading
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

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label});
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
