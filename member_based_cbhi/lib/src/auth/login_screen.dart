import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cbhi_localizations.dart';
import '../shared/animated_widgets.dart';
import '../shared/biometric_service.dart';
import '../theme/app_theme.dart';
import 'auth_cubit.dart';
import 'auth_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LoginScreen — phone/email + password, with optional fingerprint sign-in
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  String? _error;

  // Biometric availability
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    }
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Password login ────────────────────────────────────────────────────────

  Future<void> _loginWithPassword() async {
    final strings = CbhiLocalizations.of(context);
    final identifier = _identifierCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (identifier.isEmpty) {
      setState(() => _error = strings.t('invalidPhone'));
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = strings.t('passwordRequired'));
      return;
    }

    setState(() => _error = null);

    final cubit = context.read<AuthCubit>();
    final ok = await cubit.loginWithPassword(
      identifier: identifier,
      password: password,
    );

    if (!mounted) return;

    if (!ok) {
      setState(() => _error = cubit.state.error ?? strings.t('unknownError'));
    } else {
      Navigator.of(context).pop();
    }
  }

  // ── Biometric login ───────────────────────────────────────────────────────

  Future<void> _loginWithBiometric() async {
    final strings = CbhiLocalizations.of(context);
    setState(() => _error = null);

    // authenticateAndGetToken handles the biometric prompt + expiry check
    // in one call — no need to call authenticate() separately.
    final token = await BiometricService.authenticateAndGetToken();
    if (!mounted) return;

    if (token == null) {
      setState(() => _error = strings.t('biometricAuthenticationFailed'));
      return;
    }

    final cubit = context.read<AuthCubit>();
    final ok = await cubit.loginWithStoredToken(token);
    if (!mounted) return;

    if (!ok) {
      setState(() => _error = cubit.state.error ?? strings.t('unknownError'));
    } else {
      Navigator.of(context).pop();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('signIn')),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocListener<AuthCubit, AuthState>(
        listenWhen: (prev, curr) =>
            prev.error != curr.error && curr.error != null,
        listener: (context, state) {
          // Errors handled inline
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 40,
                    color: AppTheme.primary,
                  ),
                ).animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 24),

                Text(
                  strings.t('signIn'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.t('credentialLoginSubtitle'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryFor(Theme.of(context).brightness),
                      ),
                ),

                const SizedBox(height: 32),

                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Error banner
                      if (_error != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusS),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: AppTheme.error, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                      color: AppTheme.error, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Identifier field
                      TextField(
                        controller: _identifierCtrl,
                        keyboardType: TextInputType.emailAddress,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[+\d@.\w]')),
                        ],
                        decoration: InputDecoration(
                          labelText: strings.t('emailOrPhone'),
                          hintText: '+251 9XX XXX XXX',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        onSubmitted: (_) => _loginWithPassword(),
                      ),

                      const SizedBox(height: 16),

                      // Password field
                      TextField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: strings.t('password'),
                          prefixIcon: Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        onSubmitted: (_) => _loginWithPassword(),
                      ),

                      const SizedBox(height: 20),

                      // Sign In button
                      BlocBuilder<AuthCubit, AuthState>(
                        builder: (context, authState) {
                          final isBusy = authState.isBusy;
                          return SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: isBusy ? null : _loginWithPassword,
                              icon: isBusy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(Icons.login),
                              label: Text(strings.t('signIn')),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

                // Biometric button — shown only when available and enabled
                if (_biometricAvailable && _biometricEnabled) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: BlocBuilder<AuthCubit, AuthState>(
                      builder: (context, authState) {
                        return OutlinedButton.icon(
                          onPressed:
                              authState.isBusy ? null : _loginWithBiometric,
                          icon: Icon(Icons.fingerprint),
                          label: Text(strings.t('signInWithBiometrics')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: BorderSide(
                                color: AppTheme.primary.withValues(alpha: 0.5)),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        );
                      },
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                ],

                const SizedBox(height: 24),

                // Security note
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 14, color: AppTheme.textSecondaryFor(Theme.of(context).brightness)),
                      const SizedBox(width: 6),
                      Text(
                        strings.t('authSecurityNote'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondaryFor(Theme.of(context).brightness),
                            ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
