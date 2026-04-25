import 'package:flutter/material.dart';

import '../cbhi_localizations.dart';
import '../theme/app_theme.dart';
import 'registration_cubit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Step number extension on RegistrationStep
// ─────────────────────────────────────────────────────────────────────────────

extension RegistrationStepX on RegistrationStep {
  /// 1-based step number for display. Returns null for non-displayable steps.
  int? get stepNumber => switch (this) {
        RegistrationStep.personalInfo => 1,
        RegistrationStep.confirmation => 2,
        RegistrationStep.identity => 3,
        RegistrationStep.membership => 4,
        RegistrationStep.indigentProof => 5,
        RegistrationStep.payment => 6,
        RegistrationStep.setupAccount => 7,
        _ => null,
      };

  static const int totalSteps = 7;
}

// ─────────────────────────────────────────────────────────────────────────────
// RegistrationStepIndicator widget
// ─────────────────────────────────────────────────────────────────────────────

/// Displays a linear progress bar + "Step N of 7" label at the top of each
/// registration step screen.
///
/// Usage: place at the top of the step screen's Scaffold body, before the
/// main content.
class RegistrationStepIndicator extends StatelessWidget {
  const RegistrationStepIndicator({
    super.key,
    required this.step,
  });

  final RegistrationStep step;

  @override
  Widget build(BuildContext context) {
    final stepNumber = step.stepNumber;
    if (stepNumber == null) return const SizedBox.shrink();

    final progress = stepNumber / RegistrationStepX.totalSteps;
    final strings = CbhiLocalizations.of(context);

    // Use localized label if key exists, otherwise fall back to English
    String stepLabel;
    try {
      stepLabel = strings.f('stepNofM', {
        'n': stepNumber.toString(),
        'm': RegistrationStepX.totalSteps.toString(),
      });
    } catch (_) {
      stepLabel = 'Step $stepNumber of ${RegistrationStepX.totalSteps}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                stepLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(progress * 100).round()}%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TimelineStep(
            steps: List.generate(RegistrationStepX.totalSteps, (i) => ''),
            currentStep: stepNumber - 1,
            compact: true,
          ),
        ],
      ),
    );
  }
}
