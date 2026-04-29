import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../cbhi_localizations.dart';
import '../theme/app_theme.dart';
import 'registration_cubit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Step metadata
// ─────────────────────────────────────────────────────────────────────────────

/// Maps each RegistrationStep to a 1-based display index within the 5 visible
/// user-facing steps. Returns null for non-displayable steps (start, error,
/// completed, setupAccount).
extension RegistrationStepX on RegistrationStep {
  /// 1-based index among the 5 visible steps. Null = not shown.
  int? get stepNumber => switch (this) {
        RegistrationStep.personalInfo => 1,
        RegistrationStep.confirmation => 2,
        RegistrationStep.identity => 3,
        RegistrationStep.membership => 4,
        RegistrationStep.indigentProof => 4, // sub-step of membership
        RegistrationStep.payment => 5,
        _ => null,
      };

  static const int totalSteps = 5;
}

// ─────────────────────────────────────────────────────────────────────────────
// RegistrationStepIndicator
// ─────────────────────────────────────────────────────────────────────────────

/// A compact named-step progress bar shown above each registration screen.
///
/// Shows 5 labelled steps. The active step is highlighted in primary colour;
/// completed steps show a filled check circle; upcoming steps are muted.
///
/// Placed by [_StepWrapper] in registration_flow.dart — no AppBar involvement.
class RegistrationStepIndicator extends StatelessWidget {
  const RegistrationStepIndicator({super.key, required this.step});

  final RegistrationStep step;

  @override
  Widget build(BuildContext context) {
    final current = step.stepNumber;
    if (current == null) return const SizedBox.shrink();

    final strings = CbhiLocalizations.of(context);

    // Step labels — short enough to fit on one line
    final labels = [
      strings.t('regStepPersonal'),
      strings.t('regStepConfirm'),
      strings.t('regStepIdentity'),
      strings.t('regStepMembership'),
      strings.t('regStepPayment'),
    ];

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Dot + connector row ──────────────────────────────────────────
          Row(
            children: List.generate(RegistrationStepX.totalSteps * 2 - 1, (i) {
              if (i.isOdd) {
                // Connector line
                final leftStep = i ~/ 2 + 1;
                final filled = leftStep < current;
                return Expanded(
                  child: AnimatedContainer(
                    duration: 300.ms,
                    height: 2,
                    color: filled
                        ? AppTheme.primary
                        : AppTheme.primary.withValues(alpha: 0.15),
                  ),
                );
              }

              // Step dot
              final stepIdx = i ~/ 2 + 1;
              final isDone = stepIdx < current;
              final isActive = stepIdx == current;

              return AnimatedContainer(
                duration: 300.ms,
                width: isActive ? 28 : 22,
                height: isActive ? 28 : 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? AppTheme.primary
                      : isActive
                          ? AppTheme.primary
                          : AppTheme.primary.withValues(alpha: 0.12),
                  border: isActive
                      ? Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          width: 3,
                        )
                      : null,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: isDone
                      ? Icon(Icons.check, size: 12, color: AppTheme.cardBgFor(Theme.of(context).brightness))
                      : Text(
                          '$stepIdx',
                          style: TextStyle(
                            fontSize: isActive ? 12 : 10,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? Colors.white
                                : AppTheme.primary.withValues(alpha: 0.5),
                          ),
                        ),
                ),
              ).animate(key: ValueKey('dot_$stepIdx')).scale(
                    begin: const Offset(0.85, 0.85),
                    end: const Offset(1, 1),
                    duration: 250.ms,
                    curve: Curves.easeOutBack,
                  );
            }),
          ),

          const SizedBox(height: 6),

          // ── Step labels row ──────────────────────────────────────────────
          Row(
            children: List.generate(RegistrationStepX.totalSteps * 2 - 1, (i) {
              if (i.isOdd) return const Expanded(child: SizedBox.shrink());

              final stepIdx = i ~/ 2 + 1;
              final isDone = stepIdx < current;
              final isActive = stepIdx == current;

              return SizedBox(
                width: 52,
                child: Text(
                  labels[stepIdx - 1],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    color: isDone
                        ? AppTheme.primary
                        : isActive
                            ? AppTheme.primary
                            : AppTheme.textSecondaryFor(Theme.of(context).brightness).withValues(alpha: 0.6),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
