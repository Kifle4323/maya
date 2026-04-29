import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../cbhi_data.dart';
import '../cbhi_localizations.dart';
import '../theme/app_theme.dart';
import '../shared/language_selector.dart';
import 'auth_cubit.dart';

/// Shown immediately after successful registration.
/// The user sets a password — no OTP required.
class AccountSetupScreen extends StatefulWidget {
  const AccountSetupScreen({
    super.key,
    required this.authCubit,
    required this.repository,
    required this.phoneNumber,
  });

  final AuthCubit authCubit;
  final CbhiRepository repository;
  final String phoneNumber;

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isActivating = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final strings = CbhiLocalizations.of(context);
    setState(() => _error = null);

    if (_passwordController.text.length < 6) {
      setState(() => _error = strings.t('passwordTooShort'));
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = strings.t('passwordsDoNotMatch'));
      return;
    }

    setState(() => _isActivating = true);
    try {
      await widget.repository.setInitialPassword(
        password: _passwordController.text,
      );

      // Adopt the session that was stored during registration —
      // this emits AuthStatus.authenticated which the RegistrationFlow
      // listener picks up and calls regCubit.reset()
      await widget.authCubit.adoptRegisteredSession();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.t('accountActivated')),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      // If setInitialPassword fails (e.g. no session yet), try to
      // adopt the session anyway so the user can still log in
      if (e.toString().contains('401') || e.toString().contains('sign in')) {
        await widget.authCubit.adoptRegisteredSession();
      } else {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isActivating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('setupAccountTitle')),
        automaticallyImplyLeading: false,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: LanguageSelector(isLight: true),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppTheme.heroGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.verified_user_outlined,
                          color: Colors.white, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        strings.t('createPasswordSubtitle'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 32),

                // Phone display
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_outlined,
                          color: AppTheme.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        widget.phoneNumber,
                        style: textTheme.titleMedium?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

                const SizedBox(height: 32),

                // Password card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: strings.t('newPassword'),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _confirmController,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: strings.t('confirmPassword'),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

                const SizedBox(height: 24),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusS),
                        border: Border.all(
                            color: AppTheme.error.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.error, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: AppTheme.error,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().shake(),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isActivating ? null : _activate,
                    style: FilledButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 16)),
                    child: _isActivating
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(strings.t('activateAccount')),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
