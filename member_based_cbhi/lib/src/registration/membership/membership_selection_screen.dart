import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cbhi_localizations.dart';
import '../../theme/app_theme.dart';
import '../../shared/language_selector.dart';
import '../registration_cubit.dart';
import '../models/membership_type.dart';

class MembershipSelectionScreen extends StatelessWidget {
  const MembershipSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final regCubit = context.read<RegistrationCubit>();
    final state = regCubit.state;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('membershipSelection')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => regCubit.goBackToIdentity(),
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
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppTheme.heroGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.health_and_safety, color: Colors.white, size: 36),
                      const SizedBox(height: 16),
                      Text(
                        strings.t('membershipSelection'),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.t('chooseMembershipPathway'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9)),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

                const SizedBox(height: 32),

                // Selection options row/column based on screen width
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useRow = constraints.maxWidth > 600;
                    if (useRow) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildIndigentCard(context, regCubit, strings)),
                          const SizedBox(width: 24),
                          Expanded(child: _buildPayingCard(context, regCubit, strings)),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildIndigentCard(context, regCubit, strings),
                          const SizedBox(height: 20),
                          _buildPayingCard(context, regCubit, strings),
                        ],
                      );
                    }
                  }
                ),

                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              state.errorMessage!,
                              style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndigentCard(BuildContext context, RegistrationCubit cubit, dynamic strings) {
    return _MembershipCard(
      icon: Icons.volunteer_activism_outlined,
      title: strings.t('indigentMembership'),
      subtitle: strings.t('indigentMembershipSubtitle'),
      features: [
        strings.t('indigentFeature1'),
        strings.t('indigentFeature2'),
        strings.t('indigentFeature3'),
      ],
      color: AppTheme.success,
      isRecommended: true,
      onSelect: (BuildContext ctx) => _showIndigentDialog(ctx, cubit, strings),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideX(begin: -0.05, end: 0);
  }

  Widget _buildPayingCard(BuildContext context, RegistrationCubit cubit, dynamic strings) {
    return _MembershipCard(
      icon: Icons.payments_outlined,
      title: strings.t('payingMembership'),
      subtitle: strings.t('payingMembershipSubtitle'),
      features: [
        strings.t('payingFeature1'),
        strings.t('payingFeature2'),
        strings.t('payingFeature3'),
      ],
      color: AppTheme.primary,
      isRecommended: false,
      onSelect: (BuildContext ctx) => _showPayingDialog(ctx, cubit, strings),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideX(begin: 0.05, end: 0);
  }

  void _showIndigentDialog(
      BuildContext context, RegistrationCubit cubit, dynamic strings) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.t('indigentMembership')),
        content: Text(strings.t('indigentUploadNowOrLater')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Submit now without docs — can upload later from dashboard
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
            child: Text(strings.t('uploadNow')),
          ),
        ],
      ),
    );
  }

  void _showPayingDialog(
      BuildContext context, RegistrationCubit cubit, dynamic strings) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.t('payingMembership')),
        content: Text(strings.t('payingPayNowOrLater')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Skip payment — can pay later from dashboard
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
              // Navigate to payment step
              cubit.beginPayment(
                const MembershipSelection(
                  type: MembershipType.paying,
                  premiumAmount: 500,
                ),
              );
            },
            child: Text(strings.t('payNow')),
          ),
        ],
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.features,
    required this.color,
    required this.isRecommended,
    required this.onSelect,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> features;
  final Color color;
  final bool isRecommended;
  final void Function(BuildContext context) onSelect;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: InkWell(
        onTap: () => onSelect(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700)),
                        Text(subtitle,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: color)),
                      ],
                    ),
                  ),
                  if (isRecommended)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        strings.t('recommended'),
                        style: TextStyle(
                            color: color, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ...features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: color, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(f,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => onSelect(context),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(strings.t('selectThisOption')),
                style: FilledButton.styleFrom(backgroundColor: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
