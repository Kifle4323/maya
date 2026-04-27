import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/account_setup_screen.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';
import '../cbhi_localizations.dart';
import '../theme/app_theme.dart';
import 'registration_cubit.dart';
import 'registration_step_indicator.dart';
import 'personal_info/personal_info_form.dart';
import 'confirmation/personal_info_confirmation.dart';
import 'identity/identity_verification_screen.dart';
import 'membership/membership_selection_screen.dart';
import 'indigent_proof_screen.dart';
import '../payment/payment_screen.dart';

class RegistrationFlow extends StatefulWidget {
  const RegistrationFlow({super.key});

  @override
  State<RegistrationFlow> createState() => _RegistrationFlowState();
}

class _RegistrationFlowState extends State<RegistrationFlow> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<RegistrationCubit>().startRegistration();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthCubit, AuthState>(
          listenWhen: (prev, curr) =>
              prev.status != AuthStatus.authenticated &&
              curr.status == AuthStatus.authenticated,
          listener: (context, _) {
            context.read<RegistrationCubit>().reset();
          },
        ),
      ],
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final strings = CbhiLocalizations.of(context);
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(strings.t('abandonRegistrationTitle')),
              content: Text(strings.t('abandonRegistrationMessage')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(strings.t('cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.error,
                  ),
                  child: Text(strings.t('yes')),
                ),
              ],
            ),
          );
          if (confirmed == true && context.mounted) {
            context.read<RegistrationCubit>().reset();
            context.read<AuthCubit>().leaveGuest();
          }
        },
        child: BlocBuilder<RegistrationCubit, RegistrationState>(
          builder: (context, state) {
            final regCubit = context.read<RegistrationCubit>();
            final authCubit = context.read<AuthCubit>();
            final repo = authCubit.repository;

          switch (state.currentStep) {
            case RegistrationStep.personalInfo:
              return _StepWrapper(
                step: RegistrationStep.personalInfo,
                child: PersonalInfoForm(
                  repository: repo,
                  onNext: regCubit.submitPersonalInfo,
                ),
              );
            case RegistrationStep.confirmation:
              return _StepWrapper(
                step: RegistrationStep.confirmation,
                child: const PersonalInfoConfirmation(),
              );
            case RegistrationStep.identity:
              return _StepWrapper(
                step: RegistrationStep.identity,
                child: const IdentityVerificationScreen(),
              );
            case RegistrationStep.membership:
              return _StepWrapper(
                step: RegistrationStep.membership,
                child: const MembershipSelectionScreen(),
              );
            case RegistrationStep.indigentProof:
              return _StepWrapper(
                step: RegistrationStep.indigentProof,
                child: const IndigentProofScreen(),
              );
            case RegistrationStep.payment:
              final snapshot = state.registrationSnapshot;
              if (snapshot == null) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return _StepWrapper(
                step: RegistrationStep.payment,
                child: PaymentScreen(
                  repository: repo,
                  snapshot: snapshot,
                  onPaymentComplete: regCubit.submitPaymentSuccess,
                ),
              );

            case RegistrationStep.setupAccount:
              final phone = state.registeredPhone ?? '';
              if (phone.isEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  regCubit.reset();
                  authCubit.adoptRegisteredSession();
                });
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return _StepWrapper(
                step: RegistrationStep.setupAccount,
                child: AccountSetupScreen(
                  authCubit: authCubit,
                  repository: repo,
                  phoneNumber: phone,
                ),
              );

            case RegistrationStep.completed:
              return _RegistrationCompletedView(
                personalInfo: state.personalInfo,
                snapshot: state.registrationSnapshot,
                isOffline: state.isOffline,
              );
            case RegistrationStep.start:
            case RegistrationStep.error:
              // Restart from personalInfo on unexpected states
              WidgetsBinding.instance.addPostFrameCallback((_) {
                regCubit.startRegistration();
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
          }
        },
      ),
    ),
    );
  }
}

// ── Step Wrapper — adds progress indicator above each step screen ─────────────

/// Overlays a [RegistrationStepIndicator] at the very top of the step screen
/// without modifying the individual step widgets.
class _StepWrapper extends StatelessWidget {
  const _StepWrapper({required this.step, required this.child});

  final RegistrationStep step;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RegistrationStepIndicator(step: step),
        Expanded(child: child),
      ],
    );
  }
}

// ── Registration Completed ────────────────────────────────────────────────────

class _RegistrationCompletedView extends StatefulWidget {
  const _RegistrationCompletedView({
    required this.personalInfo,
    required this.snapshot,
    required this.isOffline,
  });

  final dynamic personalInfo;
  final dynamic snapshot;
  final bool isOffline;

  @override
  State<_RegistrationCompletedView> createState() =>
      _RegistrationCompletedViewState();
}

class _RegistrationCompletedViewState
    extends State<_RegistrationCompletedView> {
  String? _tempPassword;

  @override
  void initState() {
    super.initState();
    _loadTempPassword();
    // Open dashboard immediately — pass personalInfo so offline fallback works
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthCubit>().adoptRegisteredSession(
        personalInfo: widget.personalInfo,
        offlineSnapshot: widget.snapshot,
      );
    });
  }

  Future<void> _loadTempPassword() async {
    final prefs = await SharedPreferences.getInstance();
    final pw = prefs.getString('cbhi_temp_password');
    if (pw != null && mounted) {
      setState(() => _tempPassword = pw);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.m3SurfaceContainerLow,
      body: SafeArea(
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, auth) {
            final strings = CbhiLocalizations.of(context);

            if (auth.isBusy) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.m3Primary));
            }

            final authenticated = auth.status == AuthStatus.authenticated;

            if (authenticated) {
              // M3 Registration Complete screen
              return _M3RegistrationCompleteScreen(
                strings: strings,
                tempPassword: _tempPassword,
                snapshot: widget.snapshot,
                isOffline: false,
              );
            }

            // Offline / pending — Registration Received screen
            return _M3RegistrationReceivedScreen(
              strings: strings,
              tempPassword: _tempPassword,
              onGoToDashboard: () =>
                  context.read<AuthCubit>().adoptRegisteredSession(
                    personalInfo: widget.personalInfo,
                    offlineSnapshot: widget.snapshot,
                  ),
              onBackToSignIn: () {
                context.read<RegistrationCubit>().reset();
                context.read<AuthCubit>().leaveGuest();
              },
            );
          },
        ),
      ),
    );
  }
}

// ── M3 Registration Complete Screen ──────────────────────────────────────────

class _M3RegistrationCompleteScreen extends StatelessWidget {
  const _M3RegistrationCompleteScreen({
    required this.strings,
    required this.tempPassword,
    required this.snapshot,
    required this.isOffline,
  });

  final dynamic strings;
  final String? tempPassword;
  final dynamic snapshot;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final memberId = snapshot?.viewerMembershipId?.toString() ?? '—';
    final planTier = snapshot?.household?['membershipType']?.toString() ??
        strings.t('payingMembership');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success icon with glow
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.m3TertiaryContainer
                          .withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppTheme.m3Tertiary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Text(
                strings.t('registrationCompleteTitle'),
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.m3OnSurface,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                strings.t('welcomeToMayaCbhi'),
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.m3Primary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                strings.t('registrationCompleteBody'),
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.m3OnSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Summary card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.m3SurfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppTheme.m3OutlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Member ID row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          strings.t('memberIdLabel'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.m3OnSurfaceVariant,
                          ),
                        ),
                        Text(
                          memberId,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.m3OnSurface,
                          ),
                        ),
                      ],
                    ),
                    Divider(
                      height: 24,
                      color: AppTheme.m3OutlineVariant.withValues(alpha: 0.5),
                    ),
                    // Plan tier row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          strings.t('planTierLabel'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.m3OnSurfaceVariant,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified,
                                size: 18, color: AppTheme.m3Tertiary),
                            const SizedBox(width: 6),
                            Text(
                              planTier,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.m3OnSurface,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (tempPassword != null) ...[
                const SizedBox(height: 16),
                _TempPasswordCard(tempPassword: tempPassword!),
              ],

              const SizedBox(height: 32),

              // Start Using App button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.m3Primary,
                    foregroundColor: AppTheme.m3OnPrimary,
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        strings.t('startUsingApp'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                        constraints: BoxConstraints(
                            maxWidth: 16, maxHeight: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── M3 Registration Received Screen ──────────────────────────────────────────

class _M3RegistrationReceivedScreen extends StatelessWidget {
  const _M3RegistrationReceivedScreen({
    required this.strings,
    required this.tempPassword,
    required this.onGoToDashboard,
    required this.onBackToSignIn,
  });

  final dynamic strings;
  final String? tempPassword;
  final VoidCallback onGoToDashboard;
  final VoidCallback onBackToSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.m3SurfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.m3SurfaceContainer,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFA0F2E1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: AppTheme.m3Tertiary,
                    size: 40,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  strings.t('registrationReceivedTitle'),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.m3OnSurface,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  strings.t('registrationReceivedSubtitle'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.m3OnSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.m3SurfaceVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule,
                          size: 16,
                          color: AppTheme.m3OnSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        strings.t('statusPendingChip').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.m3OnSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  strings.t('registrationReceivedBody'),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.m3OnSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                if (tempPassword != null) ...[
                  const SizedBox(height: 16),
                  _TempPasswordCard(tempPassword: tempPassword!),
                ],

                const SizedBox(height: 24),

                // Go to Dashboard button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: onGoToDashboard,
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: Text(strings.t('goToDashboard')),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.m3Primary,
                      foregroundColor: AppTheme.m3OnPrimary,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: onBackToSignIn,
                  child: Text(
                    strings.t('backToSignIn'),
                    style: const TextStyle(color: AppTheme.m3OnSurfaceVariant),
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

// ── Temp Password Warning Card ────────────────────────────────────────────────

class _TempPasswordCard extends StatelessWidget {
  const _TempPasswordCard({required this.tempPassword});
  final String tempPassword;

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: tempPassword));
    if (!context.mounted) return;
    final strings = CbhiLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.t('tempPasswordCopied')),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, color: AppTheme.warning, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.t('tempPasswordCardTitle'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            strings.t('tempPasswordCardBody'),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.warning),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tempPassword,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    color: AppTheme.warning,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: AppTheme.warning),
                  onPressed: () => _copyCode(context),
                  tooltip: strings.t('tempPasswordCopyCode'),
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _copyCode(context),
              icon: const Icon(Icons.copy, size: 16),
              label: Text(strings.t('tempPasswordCopyCode')),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.warning,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.t('tempPasswordWarning'),
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
