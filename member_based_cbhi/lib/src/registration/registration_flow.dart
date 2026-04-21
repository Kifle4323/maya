import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth/account_setup_screen.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';
import 'registration_cubit.dart';
import 'personal_info/personal_info_form.dart';
import 'confirmation/personal_info_confirmation.dart';
import 'identity/identity_verification_screen.dart';
import 'membership/membership_selection_screen.dart';
import 'indigent_proof_screen.dart';

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
      // Restores any in-progress draft from SharedPreferences so the user
      // doesn't lose their registration progress after the app is killed.
      await context.read<RegistrationCubit>().startRegistration();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<RegistrationCubit, RegistrationState>(
          listenWhen: (prev, curr) =>
              curr.currentStep == RegistrationStep.completed &&
              prev.currentStep != RegistrationStep.completed,
          listener: (context, _) {
            context.read<AuthCubit>().adoptRegisteredSession();
          },
        ),
        // When auth becomes authenticated (e.g. after account setup),
        // reset the registration cubit so the flow is fully cleared.
        BlocListener<AuthCubit, AuthState>(
          listenWhen: (prev, curr) =>
              prev.status != AuthStatus.authenticated &&
              curr.status == AuthStatus.authenticated,
          listener: (context, _) {
            context.read<RegistrationCubit>().reset();
          },
        ),
      ],
      child: BlocBuilder<RegistrationCubit, RegistrationState>(
        builder: (context, state) {
          final regCubit = context.read<RegistrationCubit>();
          final authCubit = context.read<AuthCubit>();
          final repo = authCubit.repository;

          switch (state.currentStep) {
            case RegistrationStep.personalInfo:
              return PersonalInfoForm(
                repository: repo,
                onNext: regCubit.submitPersonalInfo,
              );
            case RegistrationStep.confirmation:
              return const PersonalInfoConfirmation();
            case RegistrationStep.identity:
              return const IdentityVerificationScreen();
            case RegistrationStep.membership:
              return const MembershipSelectionScreen();
            case RegistrationStep.indigentProof:
              return const IndigentProofScreen();

            // ── NEW: account setup after registration ──────────────────────
            case RegistrationStep.setupAccount:
              final phone = state.registeredPhone ?? '';
              if (phone.isEmpty) {
                // No phone — skip straight to completed
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  regCubit.reset();
                  authCubit.adoptRegisteredSession();
                });
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return AccountSetupScreen(
                authCubit: authCubit,
                repository: repo,
                phoneNumber: phone,
              );

            case RegistrationStep.completed:
              return const _RegistrationCompletedView();
            default:
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
          }
        },
      ),
    );
  }
}

class _RegistrationCompletedView extends StatelessWidget {
  const _RegistrationCompletedView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, auth) {
              final authenticated = auth.status == AuthStatus.authenticated;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    authenticated ? 'Registration complete' : 'Registration saved',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    authenticated
                        ? 'You are signed in. Continue to your dashboard below.'
                        : 'When you are online, open the app again and sign in with your phone number to finish syncing your account.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  if (!authenticated)
                    FilledButton(
                      onPressed: () {
                        context.read<RegistrationCubit>().reset();
                        context.read<AuthCubit>().leaveGuest();
                      },
                      child: const Text('Back to sign in'),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
