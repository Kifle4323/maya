import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cbhi_localizations.dart';
import '../shared/animated_widgets.dart';
import '../shared/pin_service.dart';
import '../theme/app_theme.dart';
import 'auth_cubit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OTP Recovery Screen
// Implements: phone → send OTP → verify OTP → set new PIN
// ─────────────────────────────────────────────────────────────────────────────

enum _RecoveryStep { phone, verify, setPin }

class OtpRecoveryScreen extends StatefulWidget {
  const OtpRecoveryScreen({super.key});

  @override
  State<OtpRecoveryScreen> createState() => _OtpRecoveryScreenState();
}

class _OtpRecoveryScreenState extends State<OtpRecoveryScreen> {
  _RecoveryStep _step = _RecoveryStep.phone;

  // Step 1 — phone
  final _phoneCtrl = TextEditingController(text: '+251');
  String? _phoneError;
  bool _sendingOtp = false;
  int _otpSendCount = 0; // rate-limit guard (max 3 per session)

  // Step 2 — OTP verify
  final _otpCtrl = TextEditingController();
  String? _otpError;
  bool _verifyingOtp = false;
  String? _challengePhone; // phone used for the challenge

  // Step 3 — new PIN
  String _newPin = '';
  String _confirmPin = '';
  bool _settingPin = false;
  String? _pinError;
  bool _pinSuccess = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  // ── Step 1: Send OTP ───────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    final strings = CbhiLocalizations.of(context);
    final phone = _phoneCtrl.text.trim();

    if (phone.isEmpty || phone == '+251') {
      setState(() => _phoneError = strings.t('invalidPhone'));
      return;
    }

    // Client-side rate limit: max 3 sends per session
    if (_otpSendCount >= 3) {
      setState(() => _phoneError = strings.t('otpRecoveryRateLimit'));
      return;
    }

    setState(() {
      _sendingOtp = true;
      _phoneError = null;
    });

    try {
      final challenge = await context.read<AuthCubit>().sendOtp(
            phoneNumber: phone,
          );

      if (!mounted) return;

      if (challenge != null) {
        setState(() {
          _step = _RecoveryStep.verify;
          _challengePhone = phone;
          _otpSendCount++;
          _sendingOtp = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.f('otpRecoveryCodeSent', {'phone': phone}),
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        // AuthCubit sets error on state
        final error = context.read<AuthCubit>().state.error;
        setState(() {
          _phoneError = error ?? strings.t('unknownError');
          _sendingOtp = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phoneError = e.toString().replaceFirst('Exception: ', '');
        _sendingOtp = false;
      });
    }
  }

  // ── Step 2: Verify OTP ────────────────────────────────────────────────────

  Future<void> _verifyOtp() async {
    final strings = CbhiLocalizations.of(context);
    final code = _otpCtrl.text.trim();

    if (code.length != 6) {
      setState(() => _otpError = strings.t('pleaseEnterAll6Digits'));
      return;
    }

    setState(() {
      _verifyingOtp = true;
      _otpError = null;
    });

    try {
      final ok = await context.read<AuthCubit>().verifyOtp(
            phoneNumber: _challengePhone,
            code: code,
          );

      if (!mounted) return;

      if (ok) {
        // OTP verified — move to PIN setup step
        // Sign out immediately so the user must set a new PIN before accessing
        await context.read<AuthCubit>().logout();
        if (!mounted) return;
        setState(() {
          _step = _RecoveryStep.setPin;
          _verifyingOtp = false;
        });
      } else {
        final error = context.read<AuthCubit>().state.error;
        setState(() {
          _otpError = error ?? strings.t('unknownError');
          _verifyingOtp = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _otpError = e.toString().replaceFirst('Exception: ', '');
        _verifyingOtp = false;
      });
    }
  }

  // ── Step 3: Set new PIN ───────────────────────────────────────────────────

  void _onNewPinKey(String digit) {
    if (_newPin.length < PinService.maxLength) {
      setState(() {
        _newPin += digit;
        _pinError = null;
      });
    }
  }

  void _onNewPinBackspace() {
    if (_newPin.isNotEmpty) {
      setState(() => _newPin = _newPin.substring(0, _newPin.length - 1));
    }
  }

  void _onConfirmPinKey(String digit) {
    if (_confirmPin.length < PinService.maxLength) {
      setState(() {
        _confirmPin += digit;
        _pinError = null;
      });
    }
  }

  void _onConfirmPinBackspace() {
    if (_confirmPin.isNotEmpty) {
      setState(() =>
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1));
    }
  }

  Future<void> _saveNewPin() async {
    final strings = CbhiLocalizations.of(context);

    if (_newPin.length < PinService.minLength) {
      setState(() => _pinError = strings.t('pinTooShort'));
      return;
    }
    if (_newPin != _confirmPin) {
      setState(() => _pinError = strings.t('pinMismatch'));
      return;
    }

    setState(() {
      _settingPin = true;
      _pinError = null;
    });

    try {
      await PinService.setPin(_newPin);
      if (!mounted) return;
      setState(() {
        _settingPin = false;
        _pinSuccess = true;
      });
      // Brief success display then pop back to login
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pinError = e.toString().replaceFirst('Exception: ', '');
        _settingPin = false;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('otpRecoveryTitle')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            if (_step == _RecoveryStep.verify) {
              setState(() {
                _step = _RecoveryStep.phone;
                _otpCtrl.clear();
                _otpError = null;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: child,
              ),
            ),
            child: switch (_step) {
              _RecoveryStep.phone => _PhoneStep(
                  key: const ValueKey('phone'),
                  controller: _phoneCtrl,
                  error: _phoneError,
                  isLoading: _sendingOtp,
                  onSend: _sendOtp,
                ),
              _RecoveryStep.verify => _VerifyStep(
                  key: const ValueKey('verify'),
                  controller: _otpCtrl,
                  phone: _challengePhone ?? '',
                  error: _otpError,
                  isLoading: _verifyingOtp,
                  onVerify: _verifyOtp,
                  onResend: _otpSendCount < 3 ? _sendOtp : null,
                ),
              _RecoveryStep.setPin => _SetPinStep(
                  key: const ValueKey('setPin'),
                  newPin: _newPin,
                  confirmPin: _confirmPin,
                  error: _pinError,
                  isLoading: _settingPin,
                  isSuccess: _pinSuccess,
                  onNewPinKey: _onNewPinKey,
                  onNewPinBackspace: _onNewPinBackspace,
                  onConfirmPinKey: _onConfirmPinKey,
                  onConfirmPinBackspace: _onConfirmPinBackspace,
                  onSave: _saveNewPin,
                ),
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Phone Entry
// ─────────────────────────────────────────────────────────────────────────────

class _PhoneStep extends StatelessWidget {
  const _PhoneStep({
    super.key,
    required this.controller,
    required this.error,
    required this.isLoading,
    required this.onSend,
  });

  final TextEditingController controller;
  final String? error;
  final bool isLoading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_reset_outlined,
            size: 40,
            color: AppTheme.primary,
          ),
        ).animate().fadeIn(duration: 400.ms),

        const SizedBox(height: 24),

        Text(
          strings.t('otpRecoveryTitle'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          strings.t('otpRecoverySubtitle'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),

        const SizedBox(height: 32),

        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[+\d]'))],
                decoration: InputDecoration(
                  labelText: strings.t('otpRecoveryPhoneLabel'),
                  prefixIcon: const Icon(Icons.phone_outlined),
                  errorText: error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    borderSide:
                        const BorderSide(color: AppTheme.primary, width: 2),
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isLoading ? null : onSend,
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(strings.t('otpRecoverySendCode')),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — OTP Verification
// ─────────────────────────────────────────────────────────────────────────────

class _VerifyStep extends StatelessWidget {
  const _VerifyStep({
    super.key,
    required this.controller,
    required this.phone,
    required this.error,
    required this.isLoading,
    required this.onVerify,
    required this.onResend,
  });

  final TextEditingController controller;
  final String phone;
  final String? error;
  final bool isLoading;
  final VoidCallback onVerify;
  final VoidCallback? onResend;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.sms_outlined,
            size: 40,
            color: AppTheme.accent,
          ),
        ).animate().fadeIn(duration: 400.ms),

        const SizedBox(height: 24),

        Text(
          strings.t('otpRecoveryTitle'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          strings.f('enterCodeSentTo', {'target': phone}),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),

        const SizedBox(height: 32),

        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: strings.t('otpRecoveryCodeLabel'),
                  hintText: strings.t('otpRecoveryCodeHint'),
                  prefixIcon: const Icon(Icons.pin_outlined),
                  errorText: error,
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    borderSide:
                        const BorderSide(color: AppTheme.primary, width: 2),
                  ),
                ),
                onSubmitted: (_) => onVerify(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isLoading ? null : onVerify,
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(strings.t('otpRecoveryVerify')),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                  ),
                ),
              ),
              if (onResend != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: onResend,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(strings.t('resendCode')),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 — Set New PIN
// ─────────────────────────────────────────────────────────────────────────────

class _SetPinStep extends StatelessWidget {
  const _SetPinStep({
    super.key,
    required this.newPin,
    required this.confirmPin,
    required this.error,
    required this.isLoading,
    required this.isSuccess,
    required this.onNewPinKey,
    required this.onNewPinBackspace,
    required this.onConfirmPinKey,
    required this.onConfirmPinBackspace,
    required this.onSave,
  });

  final String newPin;
  final String confirmPin;
  final String? error;
  final bool isLoading;
  final bool isSuccess;
  final void Function(String) onNewPinKey;
  final VoidCallback onNewPinBackspace;
  final void Function(String) onConfirmPinKey;
  final VoidCallback onConfirmPinBackspace;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final isEnteringNew = newPin.length < PinService.maxLength;

    if (isSuccess) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          const Icon(
            Icons.check_circle_outline,
            size: 80,
            color: AppTheme.success,
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text(
            strings.t('otpRecoverySuccess'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.success,
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_outline,
            size: 40,
            color: AppTheme.success,
          ),
        ).animate().fadeIn(duration: 400.ms),

        const SizedBox(height: 24),

        Text(
          strings.t('otpRecoveryNewPin'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          isEnteringNew
              ? strings.f('otpRecoveryNewPinHint',
                  {'length': PinService.maxLength.toString()})
              : strings.t('otpRecoveryConfirmPin'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 32),

        GlassCard(
          child: Column(
            children: [
              // PIN dots — new PIN
              _PinDots(
                label: strings.t('otpRecoveryNewPin'),
                pin: newPin,
                isActive: isEnteringNew,
                isComplete: newPin.length == PinService.maxLength,
              ),

              const SizedBox(height: 16),

              // PIN dots — confirm PIN (shown once new PIN is complete)
              if (newPin.length == PinService.maxLength)
                _PinDots(
                  label: strings.t('otpRecoveryConfirmPin'),
                  pin: confirmPin,
                  isActive: !isEnteringNew,
                  isComplete: confirmPin.length == PinService.maxLength,
                ).animate().fadeIn(duration: 300.ms),

              if (error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error!,
                          style: const TextStyle(
                              color: AppTheme.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Keypad
              _RecoveryKeypad(
                onKeyTap: isEnteringNew ? onNewPinKey : onConfirmPinKey,
                onBackspace:
                    isEnteringNew ? onNewPinBackspace : onConfirmPinBackspace,
              ),

              const SizedBox(height: 20),

              // Save button — only shown when both PINs are complete
              if (newPin.length == PinService.maxLength &&
                  confirmPin.length == PinService.maxLength)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isLoading ? null : onSave,
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(strings.t('setNewPin')),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PIN Dots indicator
// ─────────────────────────────────────────────────────────────────────────────

class _PinDots extends StatelessWidget {
  const _PinDots({
    required this.label,
    required this.pin,
    required this.isActive,
    required this.isComplete,
  });

  final String label;
  final String pin;
  final bool isActive;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isActive ? AppTheme.primary : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(PinService.maxLength, (i) {
            final filled = i < pin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled
                    ? (isComplete ? AppTheme.success : AppTheme.primary)
                    : Colors.transparent,
                border: Border.all(
                  color: isActive
                      ? AppTheme.primary
                      : AppTheme.textSecondary.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Numeric Keypad (reused from PIN content)
// ─────────────────────────────────────────────────────────────────────────────

class _RecoveryKeypad extends StatelessWidget {
  const _RecoveryKeypad({
    required this.onKeyTap,
    required this.onBackspace,
  });

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
            return _RecoveryKeyButton(
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

class _RecoveryKeyButton extends StatelessWidget {
  const _RecoveryKeyButton({
    required this.label,
    required this.onTap,
    this.isDelete = false,
  });

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
                ? const Icon(Icons.backspace_outlined,
                    color: AppTheme.primary, size: 22)
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
