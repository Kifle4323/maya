import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cbhi_localizations.dart';
import '../shared/animated_widgets.dart';
import '../shared/biometric_service.dart';
import '../shared/pin_service.dart';
import '../theme/app_theme.dart';
import 'auth_cubit.dart';
import 'auth_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdaptiveAuthMethod
// ─────────────────────────────────────────────────────────────────────────────

enum AdaptiveAuthMethod { biometric, passkey, pin }

// ─────────────────────────────────────────────────────────────────────────────
// UnifiedLoginScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Single login screen for ALL users (household heads and beneficiaries).
/// Primary methods: biometric (mobile), passkey (web), PIN (all platforms).
/// OTP recovery accessible via "Forgot PIN / Can't sign in?" link.
class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key});

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  AdaptiveAuthMethod _activeMethod = AdaptiveAuthMethod.pin;
  bool _methodPickerOpen = false;
  bool _biometricAvailable = false;
  bool _biometricEnrolled = false;
  bool _pinSet = false; // used to show "Set up PIN" vs PIN entry
  bool _pinLocked = false;
  int _biometricAttempts = 0;
  int _pinRemainingAttempts = PinService.maxFailAttempts; // shown below PIN dots
  String _pinInput = '';
  String? _error;
  bool _showEnrollBiometricBanner = false;
  bool _enrollBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final biometricAvailable = await BiometricService.isAvailable();
    final biometricEnrolled = biometricAvailable
        ? await BiometricService.isBiometricEnabled()
        : false;
    final pinSet = await PinService.hasPin();
    final pinLocked = pinSet ? await PinService.isLocked() : false;
    final remaining = pinSet ? await PinService.remainingAttempts() : PinService.maxFailAttempts;

    if (!mounted) return;
    setState(() {
      _biometricAvailable = biometricAvailable;
      _biometricEnrolled = biometricEnrolled;
      _pinSet = pinSet;
      _pinLocked = pinLocked;
      _pinRemainingAttempts = remaining;

      // Determine initial method
      if (!kIsWeb && biometricEnrolled) {
        _activeMethod = AdaptiveAuthMethod.biometric;
      } else if (kIsWeb) {
        // Passkey check happens async — default to PIN, update if passkey available
        _activeMethod = AdaptiveAuthMethod.pin;
      } else {
        _activeMethod = AdaptiveAuthMethod.pin;
      }

      // Show enrollment banner if biometric available but not enrolled
      if (!kIsWeb && biometricAvailable && !biometricEnrolled && pinSet) {
        _showEnrollBiometricBanner = true;
      }
    });

    // Auto-trigger biometric after 500ms if enrolled
    if (!kIsWeb && biometricEnrolled) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _biometricAttempts == 0) {
          _triggerBiometric();
        }
      });
    }
  }

  // ── Biometric ──────────────────────────────────────────────────────────────

  Future<void> _triggerBiometric() async {
    final token = await BiometricService.authenticateAndGetToken();
    if (!mounted) return;

    if (token != null) {
      // Success
      await context.read<AuthCubit>().loginWithStoredToken(token);
    } else {
      // Failure or cancel
      setState(() => _biometricAttempts++);
      if (_biometricAttempts >= 3) {
        setState(() {
          _activeMethod = AdaptiveAuthMethod.pin;
          _error = null;
        });
      }
      // If user cancelled (attempts == 1 and token null), switch to PIN silently
      if (_biometricAttempts == 1) {
        setState(() => _activeMethod = AdaptiveAuthMethod.pin);
      }
    }
  }

  // ── PIN ────────────────────────────────────────────────────────────────────

  void _onKeyTap(String digit) {
    if (_pinInput.length >= PinService.maxLength) return;
    setState(() {
      _pinInput += digit;
      _error = null;
    });
    if (_pinInput.length >= PinService.minLength) {
      // Auto-submit when max length reached
      if (_pinInput.length == PinService.maxLength) {
        _submitPin();
      }
    }
  }

  void _onBackspace() {
    if (_pinInput.isEmpty) return;
    setState(() => _pinInput = _pinInput.substring(0, _pinInput.length - 1));
  }

  Future<void> _submitPin() async {
    final strings = CbhiLocalizations.of(context);
    if (_pinInput.length < PinService.minLength) {
      setState(() => _error = strings.t('pinTooShort'));
      return;
    }

    if (_pinLocked) {
      setState(() => _error = strings.t('pinLocked'));
      return;
    }

    try {
      final ok = await PinService.verifyPin(_pinInput);
      if (!mounted) return;

      if (ok) {
        // PIN correct — retrieve stored token
        final token = await BiometricService.authenticateAndGetToken();
        if (!mounted) return;
        if (token != null) {
          await context.read<AuthCubit>().loginWithStoredToken(token);
        } else {
          // Token expired — need OTP recovery
          setState(() {
            _error = strings.t('sessionExpired');
            _pinInput = '';
          });
        }
      } else {
        final remaining = await PinService.remainingAttempts();
        final locked = await PinService.isLocked();
        setState(() {
          _pinInput = '';
          _pinRemainingAttempts = remaining;
          _pinLocked = locked;
          _error = locked
              ? strings.t('pinLocked')
              : strings.f('pinAttemptsRemaining', {'count': remaining});
        });
      }
    } on PinLockedException {
      setState(() {
        _pinInput = '';
        _pinLocked = true;
        _error = strings.t('pinLocked');
      });
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.t('authMethodTitle')),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: BlocListener<AuthCubit, AuthState>(
          listenWhen: (prev, curr) => prev.error != curr.error && curr.error != null,
          listener: (context, state) {
            if (state.error != null) {
              setState(() => _error = state.error);
            }
          },
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Biometric enrollment banner
                  if (_showEnrollBiometricBanner && !_enrollBannerDismissed)
                    _EnrollBiometricBanner(
                      onDismiss: () => setState(() => _enrollBannerDismissed = true),
                    ).animate().fadeIn(duration: 300.ms),

                  const SizedBox(height: 16),

                  // Auth method header
                  _AuthMethodHeader(method: _activeMethod),

                  const SizedBox(height: 24),

                  // Auth content area
                  GlassCard(
                    child: _buildAuthContent(strings),
                  ).animate().fadeIn(duration: 400.ms),

                  const SizedBox(height: 16),

                  // Error message
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.error, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: AppTheme.error, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 200.ms),

                  const SizedBox(height: 16),

                  // Primary action button
                  _buildPrimaryButton(strings),

                  const SizedBox(height: 12),

                  // Method switcher
                  TextButton(
                    onPressed: () => setState(() => _methodPickerOpen = !_methodPickerOpen),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(strings.t('switchAuthMethod')),
                        const SizedBox(width: 4),
                        Icon(
                          _methodPickerOpen ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                        ),
                      ],
                    ),
                  ),

                  // Inline method picker
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: _methodPickerOpen
                        ? _MethodPicker(
                            current: _activeMethod,
                            biometricAvailable: _biometricAvailable && _biometricEnrolled,
                            onSelect: (method) {
                              setState(() {
                                _activeMethod = method;
                                _methodPickerOpen = false;
                                _pinInput = '';
                                _error = null;
                                _biometricAttempts = 0;
                              });
                              if (method == AdaptiveAuthMethod.biometric) {
                                _triggerBiometric();
                              }
                            },
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 24),

                  // Forgot PIN link
                  TextButton.icon(
                    onPressed: () => _showForgotPinDialog(context, strings),
                    icon: const Icon(Icons.help_outline, size: 16),
                    label: Text(strings.t('forgotPin')),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Security note
                  Text(
                    strings.t('authSecurityNote'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthContent(dynamic strings) {
    switch (_activeMethod) {
      case AdaptiveAuthMethod.biometric:
        return _BiometricContent(
          onTap: _triggerBiometric,
          attempts: _biometricAttempts,
        );
      case AdaptiveAuthMethod.passkey:
        return _PasskeyContent(onTap: () {/* passkey flow — Task 12 */});
      case AdaptiveAuthMethod.pin:
        return _PinContent(
          pinInput: _pinInput,
          locked: _pinLocked,
          remainingAttempts: _pinRemainingAttempts,
          pinNotSet: !_pinSet,
          onKeyTap: _onKeyTap,
          onBackspace: _onBackspace,
          onSubmit: _submitPin,
        );
    }
  }

  Widget _buildPrimaryButton(dynamic strings) {
    final label = switch (_activeMethod) {
      AdaptiveAuthMethod.biometric => strings.t('signInWithBiometric'),
      AdaptiveAuthMethod.passkey => strings.t('signInWithPasskey'),
      AdaptiveAuthMethod.pin => strings.t('signInWithPin'),
    };

    final icon = switch (_activeMethod) {
      AdaptiveAuthMethod.biometric => Icons.fingerprint,
      AdaptiveAuthMethod.passkey => Icons.key_outlined,
      AdaptiveAuthMethod.pin => Icons.check_circle_outline,
    };

    return FilledButton.icon(
      onPressed: _activeMethod == AdaptiveAuthMethod.pin
          ? (_pinInput.length >= PinService.minLength ? _submitPin : null)
          : _activeMethod == AdaptiveAuthMethod.biometric
              ? _triggerBiometric
              : () {/* passkey — Task 12 */},
      icon: Icon(icon),
      label: Text(label),
    );
  }

  void _showForgotPinDialog(BuildContext context, dynamic strings) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.t('forgotPin')),
        content: Text(strings.t('forgotPinMessage') ?? 'We will send an OTP to your registered phone number to recover access.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.t('cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: trigger OTP recovery flow
            },
            child: Text(strings.t('sendOtp')),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AuthMethodHeader extends StatelessWidget {
  const _AuthMethodHeader({required this.method});
  final AdaptiveAuthMethod method;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final (icon, title, subtitle) = switch (method) {
      AdaptiveAuthMethod.biometric => (
          Icons.fingerprint,
          strings.t('signInWithBiometric'),
          strings.t('biometricPromptReason'),
        ),
      AdaptiveAuthMethod.passkey => (
          Icons.key_outlined,
          strings.t('signInWithPasskey'),
          strings.t('enrollPasskeyMessage'),
        ),
      AdaptiveAuthMethod.pin => (
          Icons.pin_outlined,
          strings.t('enterPin'),
          strings.t('authSecurityNote'),
        ),
    };

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 40, color: AppTheme.primary),
        ),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _BiometricContent extends StatelessWidget {
  const _BiometricContent({required this.onTap, required this.attempts});
  final VoidCallback onTap;
  final int attempts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 2),
            ),
            child: const Icon(Icons.fingerprint, size: 64, color: AppTheme.primary),
          ),
        ),
      ),
    );
  }
}

class _PasskeyContent extends StatelessWidget {
  const _PasskeyContent({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3), width: 2),
            ),
            child: const Icon(Icons.key_outlined, size: 64, color: AppTheme.accent),
          ),
        ),
      ),
    );
  }
}

class _PinContent extends StatelessWidget {
  const _PinContent({
    required this.pinInput,
    required this.locked,
    required this.remainingAttempts,
    required this.pinNotSet,
    required this.onKeyTap,
    required this.onBackspace,
    required this.onSubmit,
  });

  final String pinInput;
  final bool locked;
  final int remainingAttempts;
  final bool pinNotSet;
  final void Function(String) onKeyTap;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        children: [
          // PIN dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(PinService.maxLength, (i) {
              final filled = i < pinInput.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? AppTheme.primary : Colors.transparent,
                  border: Border.all(
                    color: locked ? AppTheme.error : AppTheme.primary,
                    width: 2,
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 8),

          // Remaining attempts indicator
          if (!locked && remainingAttempts < PinService.maxFailAttempts)
            Text(
              strings.f('pinAttemptsRemaining', {'count': remainingAttempts}),
              style: const TextStyle(
                color: AppTheme.warning,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),

          if (pinNotSet)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                strings.t('pinNotSetHint'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ),

          const SizedBox(height: 24),

          // Numeric keypad
          if (!locked) _NumericKeypad(onKeyTap: onKeyTap, onBackspace: onBackspace),

          if (locked)
            const Icon(Icons.lock_outline, size: 48, color: AppTheme.error),
        ],
      ),
    );
  }
}

class _NumericKeypad extends StatelessWidget {
  const _NumericKeypad({required this.onKeyTap, required this.onBackspace});
  final void Function(String) onKeyTap;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'DEL'],
    ];

    return Column(
      children: keys.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((key) {
            if (key.isEmpty) return const SizedBox(width: 80, height: 64);
            return _KeyButton(
              label: key,
              onTap: key == 'DEL' ? onBackspace : () => onKeyTap(key),
              isDelete: key == 'DEL',
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.label, required this.onTap, this.isDelete = false});
  final String label;
  final VoidCallback onTap;
  final bool isDelete;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isDelete ? 'Delete' : label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 80,
          height: 64,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Center(
            child: isDelete
                ? const Icon(Icons.backspace_outlined, color: AppTheme.primary, size: 22)
                : Text(
                    label,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MethodPicker extends StatelessWidget {
  const _MethodPicker({
    required this.current,
    required this.biometricAvailable,
    required this.onSelect,
  });

  final AdaptiveAuthMethod current;
  final bool biometricAvailable;
  final void Function(AdaptiveAuthMethod) onSelect;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final methods = [
      if (!kIsWeb && biometricAvailable)
        (AdaptiveAuthMethod.biometric, Icons.fingerprint, strings.t('signInWithBiometric')),
      if (kIsWeb)
        (AdaptiveAuthMethod.passkey, Icons.key_outlined, strings.t('signInWithPasskey')),
      (AdaptiveAuthMethod.pin, Icons.pin_outlined, strings.t('signInWithPin')),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: methods.map((m) {
          final isSelected = m.$1 == current;
          return ListTile(
            leading: Icon(m.$2, color: isSelected ? AppTheme.primary : AppTheme.textSecondary),
            title: Text(m.$3),
            trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primary) : null,
            onTap: () => onSelect(m.$1),
          );
        }).toList(),
      ),
    );
  }
}

class _EnrollBiometricBanner extends StatelessWidget {
  const _EnrollBiometricBanner({required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.fingerprint, color: AppTheme.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.t('enrollBiometricMessage'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: onDismiss,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}
