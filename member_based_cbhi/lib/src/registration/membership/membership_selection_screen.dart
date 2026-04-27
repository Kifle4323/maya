import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cbhi_localizations.dart';
import '../../theme/app_theme.dart';
import '../../shared/language_selector.dart';
import '../registration_cubit.dart';
import '../models/membership_type.dart';

/// Step 3 of 4 — Membership Selection
/// M3 HealthShield redesign: two plan cards (Subsidized outlined, Standard filled primary)
/// with "Most Popular" badge, feature lists, and pill action buttons.
class MembershipSelectionScreen extends StatefulWidget {
  const MembershipSelectionScreen({super.key});

  @override
  State<MembershipSelectionScreen> createState() =>
      _MembershipSelectionScreenState();
}

class _MembershipSelectionScreenState
    extends State<MembershipSelectionScreen> {
  // Track which plan is selected for visual feedback
  String _selectedPlan = 'paying'; // 'indigent' | 'paying'

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final regCubit = context.read<RegistrationCubit>();
    final state = regCubit.state;

    return Scaffold(
      backgroundColor: AppTheme.m3SurfaceContainerLow,
      appBar: AppBar(
        backgroundColor: AppTheme.m3SurfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: AppTheme.m3Primary,
          onPressed: () => regCubit.goBackToIdentity(),
        ),
        title: Row(
          children: [
            const Icon(Icons.health_and_safety,
                color: AppTheme.m3Primary, size: 20),
            const SizedBox(width: 8),
            Text(
              strings.t('appTitle'),
              style: const TextStyle(
                color: AppTheme.m3Primary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: LanguageSelector(isLight: true),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Progress section ──────────────────────────────────────
                _ProgressHeader(
                  stepLabel: strings.t('step3of4'),
                  title: strings.t('membershipSelection'),
                  subtitle: strings.t('chooseMembershipPathway'),
                  progress: 3 / 4,
                ).animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 32),

                // ── Plan cards ────────────────────────────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useRow = constraints.maxWidth > 600;
                    if (useRow) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _SubsidizedPlanCard(
                              isSelected: _selectedPlan == 'indigent',
                              onSelect: () =>
                                  setState(() => _selectedPlan = 'indigent'),
                              strings: strings,
                            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _StandardPlanCard(
                              isSelected: _selectedPlan == 'paying',
                              onSelect: () =>
                                  setState(() => _selectedPlan = 'paying'),
                              strings: strings,
                            ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _SubsidizedPlanCard(
                          isSelected: _selectedPlan == 'indigent',
                          onSelect: () =>
                              setState(() => _selectedPlan = 'indigent'),
                          strings: strings,
                        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                        const SizedBox(height: 20),
                        _StandardPlanCard(
                          isSelected: _selectedPlan == 'paying',
                          onSelect: () =>
                              setState(() => _selectedPlan = 'paying'),
                          strings: strings,
                        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                      ],
                    );
                  },
                ),

                // Error
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.m3ErrorContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppTheme.m3OnErrorContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(
                                color: AppTheme.m3OnErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (state.isLoading) ...[
                  const SizedBox(height: 24),
                  const Center(child: CircularProgressIndicator()),
                ],

                const SizedBox(height: 40),

                // ── Action buttons ────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Save & Exit
                    OutlinedButton(
                      onPressed: state.isLoading
                          ? null
                          : () => regCubit.reset(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.m3OnSurface,
                        side: const BorderSide(color: AppTheme.m3Outline),
                        shape: const StadiumBorder(),
                        minimumSize: const Size(0, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      child: Text(strings.t('saveAndExit')),
                    ),
                    const SizedBox(width: 12),
                    // Complete Registration
                    FilledButton(
                      onPressed: state.isLoading
                          ? null
                          : () => _onConfirm(context, regCubit, strings),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.m3Primary,
                        foregroundColor: AppTheme.m3OnPrimary,
                        shape: const StadiumBorder(),
                        minimumSize: const Size(0, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      child: Text(strings.t('completeRegistration')),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onConfirm(
      BuildContext context, RegistrationCubit cubit, dynamic strings) {
    if (_selectedPlan == 'indigent') {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(strings.t('indigentMembership')),
          content: Text(strings.t('indigentUploadNowOrLater')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                cubit.submitPayingMembership(
                  const MembershipSelection(type: MembershipType.indigent),
                );
              },
              child: Text(strings.t('uploadLater')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                cubit.beginIndigentProof(
                  const MembershipSelection(type: MembershipType.indigent),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.m3Primary,
                shape: const StadiumBorder(),
              ),
              child: Text(strings.t('uploadNow')),
            ),
          ],
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(strings.t('payingMembership')),
          content: Text(strings.t('payingPayNowOrLater')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                cubit.submitPayingMembership(
                  const MembershipSelection(
                    type: MembershipType.paying,
                    premiumAmount: 0,
                  ),
                );
              },
              child: Text(strings.t('payLater')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                cubit.beginPayment(
                  const MembershipSelection(
                    type: MembershipType.paying,
                    premiumAmount: 500,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.m3Primary,
                shape: const StadiumBorder(),
              ),
              child: Text(strings.t('payNow')),
            ),
          ],
        ),
      );
    }
  }
}

// ── Progress Header ───────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.stepLabel,
    required this.title,
    required this.subtitle,
    required this.progress,
  });

  final String stepLabel;
  final String title;
  final String subtitle;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stepLabel,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.m3Primary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: AppTheme.m3OnSurface,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppTheme.m3OnSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        // Progress bar — 4 segments
        Row(
          children: List.generate(4, (i) {
            final filled = i < (progress * 4).round();
            return Expanded(
              child: Container(
                height: 8,
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                decoration: BoxDecoration(
                  color: filled
                      ? AppTheme.m3Primary
                      : AppTheme.m3SurfaceVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Subsidized Plan Card ──────────────────────────────────────────────────────

class _SubsidizedPlanCard extends StatelessWidget {
  const _SubsidizedPlanCard({
    required this.isSelected,
    required this.onSelect,
    required this.strings,
  });

  final bool isSelected;
  final VoidCallback onSelect;
  final dynamic strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.m3SurfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppTheme.m3Primary
              : AppTheme.m3SurfaceVariant,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.t('indigentMembership'),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: AppTheme.m3OnSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.t('indigentMembershipSubtitle'),
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.m3OnSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '0',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.m3OnSurface,
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'ETB',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.m3OnSurfaceVariant,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 4, left: 4),
                child: Text(
                  '/ year',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.m3OnSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Features
          _FeatureRow(
              icon: Icons.check_circle_outline,
              color: AppTheme.m3Primary,
              text: strings.t('indigentFeature1')),
          const SizedBox(height: 12),
          _FeatureRow(
              icon: Icons.check_circle_outline,
              color: AppTheme.m3Primary,
              text: strings.t('indigentFeature2')),
          const SizedBox(height: 12),
          _FeatureRow(
              icon: Icons.check_circle_outline,
              color: AppTheme.m3Primary,
              text: strings.t('indigentFeature3')),
          const SizedBox(height: 12),
          _FeatureRow(
              icon: Icons.cancel_outlined,
              color: AppTheme.m3Outline,
              text: strings.t('noSpecialistConsultations'),
              muted: true),
          const SizedBox(height: 24),
          // Select button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: onSelect,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.m3Primary,
                side: const BorderSide(
                    color: AppTheme.m3Primary, width: 2),
                shape: const StadiumBorder(),
                backgroundColor: isSelected
                    ? AppTheme.m3PrimaryFixed.withValues(alpha: 0.3)
                    : null,
              ),
              child: Text(
                strings.t('selectSubsidized'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Standard Plan Card ────────────────────────────────────────────────────────

class _StandardPlanCard extends StatelessWidget {
  const _StandardPlanCard({
    required this.isSelected,
    required this.onSelect,
    required this.strings,
  });

  final bool isSelected;
  final VoidCallback onSelect;
  final dynamic strings;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.m3SurfaceContainerHigh
                : AppTheme.m3SurfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.m3Primary,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.m3Primary.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.t('payingMembership'),
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.m3OnSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                strings.t('payingMembershipSubtitle'),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.m3OnSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              // Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '500',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.m3Primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      'ETB',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.m3OnSurfaceVariant,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(
                      '/ year',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.m3OnSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Features
              _FeatureRow(
                  icon: Icons.check_circle_outline,
                  color: AppTheme.m3Primary,
                  text: strings.t('payingFeature1')),
              const SizedBox(height: 12),
              _FeatureRow(
                  icon: Icons.check_circle_outline,
                  color: AppTheme.m3Primary,
                  text: strings.t('payingFeature2')),
              const SizedBox(height: 12),
              _FeatureRow(
                  icon: Icons.check_circle_outline,
                  color: AppTheme.m3Primary,
                  text: strings.t('payingFeature3')),
              const SizedBox(height: 12),
              _FeatureRow(
                  icon: Icons.check_circle_outline,
                  color: AppTheme.m3Primary,
                  text: strings.t('specialistReferralsIncluded')),
              const SizedBox(height: 16),
              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.m3PrimaryFixed.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppTheme.m3Primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strings.t('currentSelectionBasedOnAssessment'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.m3OnSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Select button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: onSelect,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(
                    isSelected
                        ? strings.t('selected')
                        : strings.t('selectThisOption'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.m3Primary,
                    foregroundColor: AppTheme.m3OnPrimary,
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
        // "Most Popular" badge
        Positioned(
          top: -12,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.m3Primary,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.m3Primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                strings.t('mostPopular'),
                style: const TextStyle(
                  color: AppTheme.m3OnPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Feature Row ───────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.text,
    this.muted = false,
  });

  final IconData icon;
  final Color color;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: muted
                  ? AppTheme.m3Outline
                  : AppTheme.m3OnSurface,
            ),
          ),
        ),
      ],
    );
  }
}
