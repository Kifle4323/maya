import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cbhi_localizations.dart';
import '../shared/biometric_service.dart';
import '../theme/app_theme.dart';
import 'auth_cubit.dart';
import 'auth_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LoginScreen — M3 HealthShield card layout
// health_and_safety icon · email/phone + password · biometrics · create account
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
    }
  }

  Future<void> _loginWithBiometric() async {
    final strings = CbhiLocalizations.of(context);
    setState(() => _error = null);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.m3Surface,
      body: BlocListener<AuthCubit, AuthState>(
        listenWhen: (prev, curr) =>
            prev.error != curr.error && curr.error != null,
        listener: (context, state) {},
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── M3 Login Card ──────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.m3SurfaceContainerLowest,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.m3OutlineVariant.withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Header section
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                            child: Column(
                              children: [
                                // health_and_safety icon
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: AppTheme.m3PrimaryContainer
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.health_and_safety,
                                    size: 36,
                                    color: AppTheme.m3PrimaryContainer,
                                  ),
                                ).animate().fadeIn(duration: 400.ms).scale(
                                      begin: const Offset(0.8, 0.8),
                                      end: const Offset(1, 1),
                                      duration: 400.ms,
                                      curve: Curves.easeOutBack,
                                    ),
                                const SizedBox(height: 16),
                                Text(
                                  strings.t('appTitle'),
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.m3OnSurface,
                                    height: 1.2,
                                  ),
                                ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                                const SizedBox(height: 4),
                                Text(
                                  strings.t('securePortalSubtitle'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: AppTheme.m3OnSurfaceVariant,
                                  ),
                                ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
                              ],
                            ),
                          ),

                          // Form section
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Error banner
                                if (_error != null) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.m3ErrorContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline,
                                            color: AppTheme.m3OnErrorContainer,
                                            size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: const TextStyle(
                                              color: AppTheme.m3OnErrorContainer,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Email / Phone label
                                Text(
                                  strings.t('emailOrPhone'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.m3OnSurfaceVariant,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _identifierCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[+\d@.\w]')),
                                  ],
                                  decoration: InputDecoration(
                                    hintText: strings.t('enterYourCredentials'),
                                    prefixIcon: const Icon(Icons.person_outline,
                                        color: AppTheme.m3Outline),
                                    fillColor: AppTheme.m3SurfaceContainerLow,
                                    filled: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(4),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: AppTheme.m3OutlineVariant,
                                        width: 2,
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(4),
                                        topRight: Radius.circular(4),
                                      ),
                                    ),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: const BorderSide(
                                        color: AppTheme.m3Primary,
                                        width: 2,
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(4),
                                        topRight: Radius.circular(4),
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                  ),
                                  onSubmitted: (_) => _loginWithPassword(),
                                ),

                                const SizedBox(height: 16),

                                // Password label + forgot
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      strings.t('password'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.m3OnSurfaceVariant,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {},
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 24),
                                        foregroundColor: AppTheme.m3Primary,
                                      ),
                                      child: Text(
                                        strings.t('forgotPassword'),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _passwordCtrl,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    hintText: '••••••••',
                                    prefixIcon: const Icon(Icons.lock_outline,
                                        color: AppTheme.m3Outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: AppTheme.m3Outline,
                                      ),
                                      onPressed: () => setState(() =>
                                          _obscurePassword = !_obscurePassword),
                                    ),
                                    fillColor: AppTheme.m3SurfaceContainerLow,
                                    filled: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(4),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: AppTheme.m3OutlineVariant,
                                        width: 2,
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(4),
                                        topRight: Radius.circular(4),
                                      ),
                                    ),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: const BorderSide(
                                        color: AppTheme.m3Primary,
                                        width: 2,
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(4),
                                        topRight: Radius.circular(4),
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                  ),
                                  onSubmitted: (_) => _loginWithPassword(),
                                ),

                                const SizedBox(height: 24),

                                // Sign In pill button
                                BlocBuilder<AuthCubit, AuthState>(
                                  builder: (context, authState) {
                                    final isBusy = authState.isBusy;
                                    return SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: FilledButton(
                                        onPressed:
                                            isBusy ? null : _loginWithPassword,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppTheme.m3Primary,
                                          foregroundColor: AppTheme.m3OnPrimary,
                                          shape: const StadiumBorder(),
                                        ),
                                        child: isBusy
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Text(
                                                strings.t('signIn'),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  letterSpacing: 0.1,
                                                ),
                                              ),
                                      ),
                                    );
                                  },
                                ),

                                // OR divider
                                if (_biometricAvailable && _biometricEnabled) ...[
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: AppTheme.m3OutlineVariant
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Text(
                                          'OR',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.m3Outline,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: AppTheme.m3OutlineVariant
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Biometrics outlined pill button
                                  BlocBuilder<AuthCubit, AuthState>(
                                    builder: (context, authState) {
                                      return SizedBox(
                                        width: double.infinity,
                                        height: 52,
                                        child: OutlinedButton.icon(
                                          onPressed: authState.isBusy
                                              ? null
                                              : _loginWithBiometric,
                                          icon: const Icon(Icons.fingerprint,
                                              color: AppTheme.m3Primary),
                                          label: Text(
                                            strings.t('signInWithBiometrics'),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.m3OnSurface,
                                            side: BorderSide(
                                              color: AppTheme.m3OutlineVariant
                                                  .withValues(alpha: 0.5),
                                            ),
                                            backgroundColor:
                                                AppTheme.m3SurfaceContainer,
                                            shape: const StadiumBorder(),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],

                                const SizedBox(height: 24),

                                // Create account link
                                Center(
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.m3OnSurfaceVariant,
                                      ),
                                      children: [
                                        TextSpan(
                                            text: strings.t('newToMayaCbhi')),
                                        const WidgetSpan(
                                            child: SizedBox(width: 4)),
                                        WidgetSpan(
                                          child: GestureDetector(
                                            onTap: () =>
                                                Navigator.of(context).pop(),
                                            child: Text(
                                              strings.t('createAccount'),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: AppTheme.m3Primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: 50.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
