import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth/auth_cubit.dart';
import '../benefits/benefit_utilization_widget.dart';
import '../cbhi_data.dart';
import '../cbhi_localizations.dart';
import '../cbhi_state.dart';
import '../coverage/renewal_reminder_widget.dart';
import '../family/my_family_cubit.dart';
import '../payment/payment_screen.dart';
import '../shared/animated_widgets.dart';
import '../shared/skeleton_widgets.dart';
import '../theme/app_theme.dart';

/// Home / Dashboard screen — shows househol   d coverage status, metrics,
/// payment history, and recent notifications.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final authState = context.watch<AuthCubit>().state;
    return BlocBuilder<AppCubit, AppState>(
      builder: (context, state) {
        if (state.isLoading) return const DashboardSkeleton();

        final snapshot = state.snapshot ?? CbhiSnapshot.empty();
        final currentMember = snapshot.currentMember;
        final eligibility = snapshot.eligibility ?? const <String, dynamic>{};
        final canRenew = !authState.isFamilyMember;

        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async {
            final appCubit = context.read<AppCubit>();
            final authCubit = context.read<AuthCubit>();
            final familyCubit = context.read<MyFamilyCubit>();
            await appCubit.sync();
            await authCubit.refreshSession();
            await familyCubit.load();
          },
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            children: [
              // Hero card
              AnimatedHeroCard(
                icon: authState.isFamilyMember
                    ? Icons.person
                    : Icons.home_work_outlined,
                title: authState.isFamilyMember
                    ? strings.t('beneficiaryProfile')
                    : strings.t('household'),
                subtitle: snapshot.householdCode.isEmpty
                    ? strings.t('noHouseholdSynced')
                    : '${snapshot.viewerName} • ${snapshot.householdCode}',
                value: snapshot.householdCode.isEmpty
                    ? strings.t('guestSession')
                    : snapshot.coverageStatus,
              )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),

              const SizedBox(height: 16),

              // Metrics row 1
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      label: strings.t('coverage'),
                      value: snapshot.coverageStatus,
                      icon: Icons.verified_outlined,
                      color: AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      label: authState.isFamilyMember
                          ? strings.t('eligibility')
                          : strings.t('members'),
                      value: authState.isFamilyMember
                          ? (eligibility['approved'] == true
                              ? strings.t('eligible')
                              : strings.t('pending'))
                          : snapshot.familyMembers.length.toString(),
                      icon: authState.isFamilyMember
                          ? Icons.verified_user_outlined
                          : Icons.family_restroom_outlined,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 150.ms)
                  .slideY(begin: 0.08, end: 0, duration: 400.ms, delay: 150.ms),

              const SizedBox(height: 12),

              // Metrics row 2
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      label: strings.t('premium'),
                      value: '${snapshot.premiumAmount.toStringAsFixed(0)} ETB',
                      icon: Icons.payments_outlined,
                      color: AppTheme.gold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      label: strings.t('paid'),
                      value: '${snapshot.paidAmount.toStringAsFixed(0)} ETB',
                      icon: Icons.account_balance_wallet_outlined,
                      color: AppTheme.accent,
                    ),
                  ),
                ],
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 250.ms)
                  .slideY(begin: 0.08, end: 0, duration: 400.ms, delay: 250.ms),

              const SizedBox(height: 20),

              // Renewal reminder — shown when coverage is expiring or expired
              if (canRenew) ...[
                RenewalReminderWidget(
                  snapshot: snapshot,
                  onRenew: () => _showRenewCoverageSheet(
                    context,
                    snapshot,
                    context.read<AppCubit>().repository,
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                const SizedBox(height: 12),
              ],

              // Sync / eligibility card
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (snapshot.isPendingSync
                                    ? AppTheme.warning
                                    : AppTheme.success)
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            snapshot.isPendingSync
                                ? Icons.cloud_upload_outlined
                                : Icons.cloud_done_outlined,
                            color: snapshot.isPendingSync
                                ? AppTheme.warning
                                : AppTheme.success,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                snapshot.isPendingSync
                                    ? strings.t('offlineQueueActive')
                                    : strings.t('householdSynced'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                snapshot.isPendingSync
                                    ? strings.t('changesWaitingToSync')
                                    : strings.t('dataAndCardUpToDate'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      authState.isFamilyMember
                          ? strings.t('personalEligibility')
                          : strings.t('renewalStatus'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      eligibility['reason']?.toString() ??
                          strings.t('coverageEligibilityDetails'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (currentMember != null) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusBadge(
                            label: currentMember.relationshipToHouseholdHead ??
                                'MEMBER',
                          ),
                          StatusBadge(
                            label: eligibility['canLoginIndependently'] == true
                                ? strings.t('independentAccess')
                                : strings.t('householdManaged'),
                            color: AppTheme.primary,
                          ),
                        ],
                      ),
                    ],
                    if (canRenew) ...[
                      const SizedBox(height: 16),
                      // FIX: Only show renew button when coverage needs renewal
                      if (snapshot.coverageStatus != 'ACTIVE' ||
                          snapshot.premiumAmount == 0)
                        FilledButton.icon(
                          onPressed: state.isSyncing
                              ? null
                              : () => _showRenewCoverageSheet(
                                  context,
                                  snapshot,
                                  context.read<AppCubit>().repository,
                                ),
                          icon: const Icon(Icons.autorenew),
                          label: Text(
                            snapshot.premiumAmount > 0
                                ? strings.t('renewCoverage')
                                : strings.t('confirmRenewal'),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.10),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusS),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  color: AppTheme.success, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                strings.t('eligible'),
                                style: const TextStyle(
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 350.ms)
                  .slideY(begin: 0.06, end: 0, duration: 400.ms, delay: 350.ms),

              const SizedBox(height: 24),

              // Payment History
              SectionHeader(title: strings.t('paymentHistory')),
              const SizedBox(height: 4),
              ...snapshot.payments.take(3).toList().asMap().entries.map(
                (entry) {
                  final payment = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.gold.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.payments_outlined,
                                color: AppTheme.gold, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${payment['amount']?.toString() ?? '0'} ETB',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  // FIX: Properly title-case the payment method
                                  '${_formatPaymentMethod(payment['method']?.toString())} • ${_formatDateLabel(payment['paidAt'] ?? payment['createdAt'])}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(
                              label: payment['status']?.toString() ?? 'UNKNOWN'),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 350.ms, delay: 450.ms)
                        .slideX(begin: 0.05, end: 0, duration: 350.ms, delay: 450.ms),
                  );
                },
              ),
              if (snapshot.payments.isEmpty)
                EmptyState(
                  icon: Icons.payments_outlined,
                  title: strings.t('noPaymentsRecorded'),
                  subtitle: strings.t('renewalTransactionsHere'),
                ).animate().fadeIn(duration: 400.ms, delay: 450.ms),

              const SizedBox(height: 24),

              // Benefit Utilization — shows annual benefit usage
              BenefitUtilizationWidget(
                totalClaimed: snapshot.claims
                    .fold(0.0, (sum, c) => sum + ((c['claimedAmount'] as num?)?.toDouble() ?? 0)),
                annualCeiling: 0, // Will be populated from benefit package API
                claimsCount: snapshot.claims.length,
              ).animate().fadeIn(duration: 400.ms, delay: 480.ms),

              const SizedBox(height: 24),

              // Notifications
              SectionHeader(title: strings.t('recentNotifications')),
              const SizedBox(height: 4),
              ...snapshot.notifications.take(3).toList().asMap().entries.map(
                (entry) {
                  final notification = entry.value;
                  final isRead = notification['isRead'] == true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      onTap: notification['id'] == null
                          ? null
                          : () => context.read<AppCubit>().markNotificationRead(
                              notification['id'].toString()),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (isRead
                                      ? AppTheme.textSecondary
                                      : AppTheme.accent)
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isRead
                                  ? Icons.mark_email_read_outlined
                                  : Icons.notifications_active_outlined,
                              color: isRead
                                  ? AppTheme.textSecondary
                                  : AppTheme.accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notification['title']?.toString() ??
                                      strings.t('notifications'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  notification['message']?.toString() ?? '',
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 350.ms, delay: 550.ms)
                        .slideX(begin: 0.05, end: 0, duration: 350.ms, delay: 550.ms),
                  );
                },
              ),
              if (snapshot.notifications.isEmpty)
                EmptyState(
                  icon: Icons.notifications_outlined,
                  title: strings.t('noNotificationsYet'),
                  subtitle: strings.t('coverageAlertsHere'),
                ).animate().fadeIn(duration: 400.ms, delay: 550.ms),

              if (snapshot.notifications.length >= 3)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextButton.icon(
                    onPressed: () =>
                        _showAllNotificationsSheet(context, snapshot, strings),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(strings.t('viewAllNotifications')),
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showAllNotificationsSheet(
    BuildContext context,
    CbhiSnapshot snapshot,
    dynamic strings,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                strings.t('allNotifications'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: snapshot.notifications.length,
                itemBuilder: (_, index) {
                  final n = snapshot.notifications[index];
                  return ListTile(
                    leading: Icon(
                      n['isRead'] == true
                          ? Icons.mark_email_read_outlined
                          : Icons.notifications_active_outlined,
                      color: n['isRead'] == true
                          ? AppTheme.textSecondary
                          : AppTheme.accent,
                    ),
                    title: Text(n['title']?.toString() ?? ''),
                    subtitle: Text(n['message']?.toString() ?? ''),
                    onTap: n['id'] == null
                        ? null
                        : () => context
                            .read<AppCubit>()
                            .markNotificationRead(n['id'].toString()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _formatDateLabel(dynamic value) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty) return 'Not available';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
}

// FIX: Properly format payment method enum values for display
String _formatPaymentMethod(String? raw) {
  if (raw == null || raw.isEmpty) return 'Payment';
  return raw
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

Future<void> _showRenewCoverageSheet(
  BuildContext context,
  CbhiSnapshot snapshot,
  CbhiRepository repository,
) async {
  if (snapshot.premiumAmount > 0) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          repository: repository,
          snapshot: snapshot,
          onPaymentComplete: () async {
            Navigator.of(context).pop();
            await context.read<AppCubit>().sync();
          },
        ),
      ),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final strings = CbhiLocalizations.of(context);
      return Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.autorenew, color: AppTheme.success),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    strings.t('confirmFreeRenewal'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(strings.t('freeRenewalMessage')),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                await context.read<AppCubit>().renewCoverage();
                if (context.mounted) Navigator.of(sheetContext).pop();
              },
              icon: const Icon(Icons.check_circle_outline),
              label: Text(strings.t('confirmFreeRenewalButton')),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.success),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
