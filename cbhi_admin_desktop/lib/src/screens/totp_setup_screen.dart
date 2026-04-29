import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/admin_repository.dart';
import '../i18n/app_localizations.dart';
import '../theme/admin_theme.dart';

/// TOTP 2FA setup screen for admin accounts.
/// Shown after first login if 2FA is not yet enabled.
/// Guides the admin through scanning the QR code and verifying a token.
class TotpSetupScreen extends StatefulWidget {
  const TotpSetupScreen({
    super.key,
    required this.repository,
    required this.onComplete,
  });

  final AdminRepository repository;
  final VoidCallback onComplete;

  @override
  State<TotpSetupScreen> createState() => _TotpSetupScreenState();
}

class _TotpSetupScreenState extends State<TotpSetupScreen> {
  bool _loading = true;
  String? _error;
  String? _secret;
  final _tokenCtrl = TextEditingController();
  bool _verifying = false;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.repository.setupTotp();
      setState(() {
        _secret = result['secret']?.toString();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _activate() async {
    final strings = AppLocalizations.of(context);
    final token = _tokenCtrl.text.trim();
    if (token.length != 6) {
      setState(() => _error = strings.t('pleaseEnterAll6Digits'));
      return;
    }
    setState(() { _verifying = true; _error = null; });
    try {
      await widget.repository.activateTotp(token);
      setState(() { _verified = true; _verifying = false; });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _verifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AdminTheme.primary)),
      );
    }

    if (_verified) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user, size: 72, color: AdminTheme.success),
              const SizedBox(height: 20),
              Text(
                strings.t('totpActivated'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AdminTheme.textPrimaryFor(Theme.of(context).brightness),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                strings.t('totpActivatedSubtitle'),
                style: TextStyle(color: AdminTheme.textSecondaryFor(Theme.of(context).brightness)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: widget.onComplete,
                style: FilledButton.styleFrom(backgroundColor: AdminTheme.primary),
                child: Text(strings.t('continueToAdmin')),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('setupTwoFactor')),
        backgroundColor: AdminTheme.sidebarBg,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AdminTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AdminTheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.security, color: AdminTheme.primary, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.t('twoFactorRequired'),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AdminTheme.textPrimaryFor(Theme.of(context).brightness),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              strings.t('twoFactorRequiredSubtitle'),
                              style: TextStyle(
                                color: AdminTheme.textSecondaryFor(Theme.of(context).brightness),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Step 1: Install authenticator
                _StepCard(
                  step: '1',
                  title: strings.t('totpStep1Title'),
                  body: strings.t('totpStep1Body'),
                ),

                const SizedBox(height: 16),

                // Step 2: Scan QR code
                _StepCard(
                  step: '2',
                  title: strings.t('totpStep2Title'),
                  body: strings.t('totpStep2Body'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      // QR code placeholder — in production render _qrUri as QR image
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AdminTheme.cardBgFor(Theme.of(context).brightness),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.qr_code_2,
                              size: 80,
                              color: AdminTheme.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              strings.t('totpQrHint'),
                              style: TextStyle(
                                color: AdminTheme.textSecondaryFor(Theme.of(context).brightness),
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Manual entry secret
                      Text(
                        strings.t('totpManualEntry'),
                        style: TextStyle(
                          color: AdminTheme.textSecondaryFor(Theme.of(context).brightness),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6F9F8),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                _secret ?? '',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.copy_outlined,
                                color: AdminTheme.primary),
                            tooltip: strings.t('copySecret'),
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await Clipboard.setData(
                                ClipboardData(text: _secret ?? ''),
                              );
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(strings.t('secretCopied')),
                                    backgroundColor: AdminTheme.success,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Step 3: Verify token
                _StepCard(
                  step: '3',
                  title: strings.t('totpStep3Title'),
                  body: strings.t('totpStep3Body'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      if (_error != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AdminTheme.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AdminTheme.error, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: AdminTheme.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      TextField(
                        controller: _tokenCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: strings.t('totpTokenLabel'),
                          hintText: '000000',
                          prefixIcon: const Icon(Icons.pin_outlined),
                          counterText: '',
                        ),
                        onSubmitted: (_) => _activate(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _verifying ? null : _activate,
                          icon: _verifying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.verified_user_outlined),
                          label: Text(strings.t('activateTwoFactor')),
                          style: FilledButton.styleFrom(
                            backgroundColor: AdminTheme.primary,
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
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.title,
    required this.body,
    this.child,
  });

  final String step;
  final String title;
  final String body;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AdminTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      step,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AdminTheme.textPrimaryFor(Theme.of(context).brightness),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                color: AdminTheme.textSecondaryFor(Theme.of(context).brightness),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}
