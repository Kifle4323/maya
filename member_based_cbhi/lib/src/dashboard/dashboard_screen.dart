import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_cubit.dart';
import '../benefits/benefit_utilization_widget.dart';
import '../cbhi_data.dart';
import '../cbhi_localizations.dart';
import '../cbhi_state.dart';
import '../coverage/renewal_reminder_widget.dart';
import '../family/my_family_cubit.dart';
import '../indigent/indigent_application_screen.dart';
import '../payment/payment_screen.dart';
import '../shared/animated_widgets.dart';
import '../shared/premium_widgets.dart';
import '../shared/skeleton_widgets.dart';
import '../theme/app_theme.dart';

const _kTempPasswordKey = 'cbhi_has_temp_password';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    return BlocBuilder<AppCubit, AppState>(
      builder: (context, state) {
        if (state.isLoading) return const DashboardSkeleton();

        final snapshot = state.snapshot ?? CbhiSnapshot.empty();
        final isFamilyMember = authState.isFamilyMember;
        final canRenew = !isFamilyMember;

        final membershipType =
            snapshot.coverage?['membershipType']?.toString() ??
                snapshot.household['membershipType']?.toString() ??
                'paying';
        final isIndigent = membershipType.toLowerCase() == 'indigent';

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
              _SetupBanner(),
              // Bento Top Section
              BentoGrid(
                crossAxisCount: 2,
                children: [
                  // Full width hero
                  SizedBox(
                    width: double.infinity,
                    child: _CoverageHeroCard(
                      snapshot: snapshot,
                      isFamilyMember: isFamilyMember,
                      isIndigent: isIndigent,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), curve: Curves.easeOutBack),
                  
                  // Grid items
                  _QuickStatTile(
                    label: strings.t('coverage'),
                    value: snapshot.coverageStatus,
                    icon: Icons.verified_outlined,
                    color: _coverageColor(snapshot.coverageStatus),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                  
                  if (isFamilyMember)
                    _QuickStatTile(
                      label: strings.t('eligibility'),
                      value: snapshot.eligibility?['approved'] == true ? strings.t('eligible') : strings.t('pending'),
                      icon: Icons.verified_user_outlined,
                      color: snapshot.eligibility?['approved'] == true ? AppTheme.success : AppTheme.warning,
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0)
                  else if (isIndigent)
                    _QuickStatTile(
                      label: strings.t('indigentApplication'),
                      value: snapshot.household['indigentStatus']?.toString() ?? strings.t('pending'),
                      icon: Icons.volunteer_activism_outlined,
                      color: AppTheme.accent,
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0)
                  else
                    _QuickStatTile(
                      label: strings.t('members'),
                      value: snapshot.familyMembers.length.toString(),
                      icon: Icons.family_restroom_outlined,
                      color: AppTheme.primary,
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                ],
              ),
              
              const SizedBox(height: AppTheme.spacingL),
              
              if (canRenew && !isIndigent) ...[
                _RenewalSection(
                  snapshot: snapshot,
                  isSyncing: state.isSyncing,
                  onRenew: () => _showRenewCoverageSheet(
                    context, snapshot, context.read<AppCubit>().repository),
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: AppTheme.spacingM),
              ],
              
              _SyncStatusCard(
                snapshot: snapshot,
                isFamilyMember: isFamilyMember,
                canRenew: canRenew && !isIndigent,
                isSyncing: state.isSyncing,
                onRenew: () => _showRenewCoverageSheet(
                  context, snapshot, context.read<AppCubit>().repository),
              ).animate().fadeIn(delay: 450.ms),
              
              const SizedBox(height: AppTheme.spacingL),
              
              if (!isIndigent) ...[
                _PaymentHistorySection(snapshot: snapshot).animate().fadeIn(delay: 500.ms),
                const SizedBox(height: AppTheme.spacingL),
              ],
              
              _BenefitUtilizationSection(snapshot: snapshot).animate().fadeIn(delay: 550.ms),
              
              const SizedBox(height: AppTheme.spacingL),
              
              if (snapshot.referrals.isNotEmpty) ...[
                _ReferralsSection(snapshot: snapshot).animate().fadeIn(delay: 600.ms),
                const SizedBox(height: AppTheme.spacingL),
              ],
              
              _RecentNotificationsSection(snapshot: snapshot).animate().fadeIn(delay: 650.ms),
              const SizedBox(height: AppTheme.spacingL),
            ],
          ),
        );
      },
    );
  }
}

// ─── _CoverageHeroCard ───────────────────────────────────────────────────────

class _CoverageHeroCard extends StatelessWidget {
  const _CoverageHeroCard({
    required this.snapshot,
    required this.isFamilyMember,
    required this.isIndigent,
  });

  final CbhiSnapshot snapshot;
  final bool isFamilyMember;
  final bool isIndigent;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final status = snapshot.coverageStatus;

    // Expiry date label
    final endDateStr = snapshot.coverage?['endDate']?.toString();
    final endDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;
    final expiryLabel = endDate != null
        ? '${_formatDateLabel(endDate.toIso8601String())}'
        : '';

    // Subtitle line
    String subtitle;
    if (snapshot.householdCode.isEmpty) {
      subtitle = strings.t('noHouseholdSynced');
    } else if (isFamilyMember) {
      subtitle = snapshot.    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Aurora Mesh Effect (Layered gradients)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.4),
                    AppTheme.accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).move(begin: const Offset(-20, -20), end: const Offset(20, 20), duration: 8.s, curve: Curves.easeInOut),
          
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.15),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).move(begin: const Offset(10, 10), end: const Offset(-10, -10), duration: 6.s, curve: Curves.easeInOut),

          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Icon(
                        isFamilyMember
                            ? Icons.person
                            : (isIndigent
                                ? Icons.volunteer_activism_outlined
                                : Icons.home_work_outlined),
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isFamilyMember
                            ? strings.t('beneficiaryProfile')
                            : strings.t('household'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                      ),
                    ),
                    // Status pill (Glass style)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: status.toUpperCase() == 'ACTIVE' ? Colors.white : AppTheme.gold,
                            ),
                          ).animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(1, 1), end: const Offset(1.5, 1.5), duration: 1.s, curve: Curves.easeInOut),
                          const SizedBox(width: 6),
                          Text(
                            status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  snapshot.householdCode.isEmpty
                      ? strings.t('guestSession')
                      : snapshot.viewerName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                ),
                if (isFamilyMember || isIndigent || expiryLabel.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFamilyMember 
                            ? Icons.badge_outlined 
                            : (isIndigent ? Icons.handshake_outlined : Icons.calendar_today_outlined),
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isFamilyMember 
                            ? strings.t('familyMemberSession')
                            : (isIndigent ? strings.t('indigentMembership') : expiryLabel),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
              ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── _QuickStatTile ──────────────────────────────────────────────────────────

class _QuickStatTile extends StatelessWidget {
  const _QuickStatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return MetricTile(
      label: label,
      value: value,
      icon: icon,
      color: color,
    );
  }
}

Color _coverageColor(String status) => switch (status.toUpperCase()) {
      'ACTIVE' => AppTheme.success,
      'EXPIRED' => AppTheme.error,
      'PENDING_RENEWAL' || 'WAITING_PERIOD' => AppTheme.warning,
      _ => AppTheme.textSecondary,
    };

// ─── _RenewalSection ─────────────────────────────────────────────────────────

class _RenewalSection extends StatelessWidget {
  const _RenewalSection({
    required this.snapshot,
    required this.isSyncing,
    required this.onRenew,
  });

  final CbhiSnapshot snapshot;
  final bool isSyncing;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final status = snapshot.coverageStatus;
    final isActive = status == 'ACTIVE';

    // Check if expiring within 30 days
    final endDateStr = snapshot.coverage?['endDate']?.toString();
    final endDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;
    final daysLeft = endDate?.difference(DateTime.now()).inDays;
    final isExpiringSoon = daysLeft != null && daysLeft <= 30 && daysLeft >= 0;
    final isExpired = status == 'EXPIRED' || (daysLeft != null && daysLeft < 0);

    // Show renew button when not active, expired, or expiring soon
    final showRenewButton = !isActive || isExpiringSoon || isExpired;

    return PremiumCard(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.payments_outlined,
                    color: AppTheme.gold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  strings.t('renewalStatus'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isActive && !isExpiringSoon)
                StatusPill(
                  label: strings.t('active'),
                  color: AppTheme.success,
                  compact: true,
                ),
            ],
          ),
          const SizedBox(height: 16),
                        strings.t('eligible'),
                        style: const TextStyle(
                          color: AppTheme.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Renewal reminder widget handles expiry messaging
          RenewalReminderWidget(snapshot: snapshot, onRenew: onRenew),
          if (showRenewButton) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoChip(
                    label: strings.t('premium'),
                    value: snapshot.premiumAmount > 0
                        ? '${snapshot.premiumAmount.toStringAsFixed(0)} ETB'
                        : _calcDisplayPremium(snapshot),
                    icon: Icons.payments_outlined,
                    color: AppTheme.gold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoChip(
                    label: strings.t('paid'),
                    value:
                        '${snapshot.paidAmount.toStringAsFixed(0)} ETB',
                    icon: Icons.account_balance_wallet_outlined,
                    color: AppTheme.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isSyncing ? null : onRenew,
              icon: const Icon(Icons.autorenew, size: 18),
              label: Text(
                snapshot.premiumAmount > 0
                    ? strings.t('renewCoverage')
                    : strings.t('payPremiumNow'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// When premiumAmount is 0 (pay-later case), calculate from member count.
String _calcDisplayPremium(CbhiSnapshot snapshot) {
  final memberCount =
      (snapshot.household['memberCount'] as num?)?.toInt() ?? 1;
  final calculated = memberCount * 120;
  return '$calculated ETB';
}

// ─── _IndigentStatusSection ──────────────────────────────────────────────────
class _IndigentStatusSection extends StatelessWidget {
  const _IndigentStatusSection({required this.snapshot});

  final CbhiSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);

    final rawStatus =
        snapshot.household['indigentStatus']?.toString() ??
            snapshot.household['indigentApplicationStatus']?.toString() ??
            'PENDING';
    final upperStatus = rawStatus.toUpperCase();

    final isApproved = upperStatus == 'APPROVED';
    final isRejected = upperStatus == 'REJECTED' || upperStatus == 'DENIED';

    final Color statusColor = isApproved
        ? AppTheme.success
        : (isRejected ? AppTheme.error : AppTheme.warning);
    final IconData statusIcon = isApproved
        ? Icons.verified_outlined
        : (isRejected ? Icons.cancel_outlined : Icons.hourglass_top_outlined);

    String statusTitle;
    String statusBody;
    if (isApproved) {
      statusTitle = strings.t('indigentMembership');
      final endDateStr = snapshot.coverage?['endDate']?.toString();
      final endDate =
          endDateStr != null ? DateTime.tryParse(endDateStr) : null;
      statusBody = endDate != null
          ? '${strings.t('coverage')}: ${_formatDateLabel(endDate.toIso8601String())}'
          : strings.t('coverageEligibilityDetails');
    } else if (isRejected) {
      statusTitle = strings.t('indigentApplicationTitle');
      statusBody = strings.t('indigentApplicationSubtitle');
    } else {
      statusTitle = strings.t('indigentApplicationTitle');
      statusBody = strings.t('indigentApplicationSubtitle');
    }

    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  statusTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  upperStatus,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            statusBody,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (isApproved) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: Row(
                children: [
                  const Icon(Icons.volunteer_activism_outlined,
                      color: AppTheme.success, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.t('freeRenewalMessage'),
                      style: const TextStyle(
                          color: AppTheme.success, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Pending or Rejected — show upload proof button
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _navigateToIndigentApplication(context, snapshot),
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: Text(strings.t('uploadProofDocuments')),
                style: FilledButton.styleFrom(
                  backgroundColor: statusColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void _navigateToIndigentApplication(
    BuildContext context, CbhiSnapshot snapshot) {
  final appCubit = context.read<AppCubit>();
  final authCubit = context.read<AuthCubit>();
  final session = authCubit.state.session;
  if (session == null) return;
  final memberCount = snapshot.familyMembers.isNotEmpty
      ? snapshot.familyMembers.length
      : ((snapshot.household['memberCount'] as num?)?.toInt() ?? 1);
  final employment =
      snapshot.household['headEmploymentStatus']?.toString() ??
          snapshot.household['employmentStatus']?.toString() ??
          'unemployed';
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => IndigentApplicationScreen(
        repository: appCubit.repository,
        userId: session.user.id,
        familySize: memberCount,
        employmentStatus: employment,
        onSubmitted: (_) {
          Navigator.of(context).pop();
          appCubit.sync();
        },
      ),
    ),
  );
}

// ─── _SyncStatusCard ─────────────────────────────────────────────────────────
// Shows sync status only — renewal button removed (lives in _RenewalSection).

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({
    required this.snapshot,
    required this.isFamilyMember,
    required this.canRenew,
    required this.isSyncing,
    required this.onRenew,
  });

  final CbhiSnapshot snapshot;
  final bool isFamilyMember;
  final bool canRenew;
  final bool isSyncing;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final isPending = snapshot.isPendingSync;
    final syncColor = isPending ? AppTheme.warning : AppTheme.success;
    final syncIcon = isPending
        ? Icons.cloud_upload_outlined
        : Icons.cloud_done_outlined;

    // Last synced time
    final syncedAt = snapshot.syncedAt;
    final syncedDate = syncedAt.isNotEmpty ? DateTime.tryParse(syncedAt) : null;
    final syncLabel = syncedDate != null
        ? _formatDateLabel(syncedDate.toIso8601String())
        : '';

    return PremiumCard(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: syncColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(syncIcon, color: syncColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPending
                      ? strings.t('offlineQueueActive')
                      : strings.t('householdSynced'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (syncLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    syncLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          // Sync spinner when actively syncing
          if (isSyncing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── _PaymentHistorySection ──────────────────────────────────────────────────

class _PaymentHistorySection extends StatelessWidget {
  const _PaymentHistorySection({required this.snapshot});

  final CbhiSnapshot snapshot;

  String _formatPaymentMethodLabel(String? method) {
    if (method == null || method.isEmpty) return 'Payment';
    return switch (method.toLowerCase()) {
      'telebirr' => 'Telebirr',
      'cbe_birr' || 'cbebirr' => 'CBE Birr',
      'amole' => 'Amole',
      'mpesa' || 'm_pesa' => 'M-Pesa',
      'bank_transfer' || 'bank' => 'Bank Transfer',
      'chapa' => 'Chapa',
      'cash' => 'Cash',
      _ => method,
    };
  }

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: strings.t('paymentHistory'),
          icon: Icons.payments_outlined,
        ),
        const SizedBox(height: 4),
        if (snapshot.payments.isEmpty)
          EmptyView(
            icon: Icons.payments_outlined,
            title: strings.t('noPaymentsRecorded'),
            subtitle: strings.t('renewalTransactionsHere'),
          )
        else
          ...snapshot.payments.take(3).toList().asMap().entries.map((entry) {
            final payment = entry.value;
            final method = _formatPaymentMethodLabel(payment['method']?.toString());
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PremiumCard(
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
                            '$method \u2022 ${_formatDateLabel(payment['paidAt'] ?? payment['createdAt'])}',
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    StatusPill(
                        label: payment['status']?.toString() ?? 'UNKNOWN'),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 350.ms, delay: (50 * entry.key).ms)
                  .slideX(
                      begin: 0.05,
                      end: 0,
                      duration: 350.ms,
                      delay: (50 * entry.key).ms),
            );
          }),
      ],
    );
  }
}

// ─── _BenefitUtilizationSection ──────────────────────────────────────────────

class _BenefitUtilizationSection extends StatelessWidget {
  const _BenefitUtilizationSection({required this.snapshot});

  final CbhiSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return BenefitUtilizationWidget(
      totalClaimed: snapshot.claims.fold(
          0.0,
          (sum, c) =>
              sum + ((c['claimedAmount'] as num?)?.toDouble() ?? 0)),
      annualCeiling:
          (snapshot.coverage?['annualCeiling'] as num?)?.toDouble() ?? 0,
      claimsCount: snapshot.claims.length,
    );
  }
}

// ─── _RecentNotificationsSection ─────────────────────────────────────────────

class _RecentNotificationsSection extends StatelessWidget {
  const _RecentNotificationsSection({required this.snapshot});

  final CbhiSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final unreadCount = snapshot.notifications.where((n) => n['isRead'] != true).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: strings.t('recentNotifications'),
          icon: unreadCount > 0 ? Icons.notifications_active_outlined : Icons.notifications_outlined,
          action: snapshot.notifications.length >= 3
              ? () => _showAllNotificationsSheet(context, snapshot, strings)
              : null,
          actionLabel: snapshot.notifications.length >= 3
              ? strings.t('viewAllNotifications')
              : null,
        ),
        const SizedBox(height: 4),
        if (snapshot.notifications.isEmpty)
          EmptyView(
            icon: Icons.notifications_outlined,
            title: strings.t('noNotificationsYet'),
            subtitle: strings.t('coverageAlertsHere'),
          )
        else ...[
          ...snapshot.notifications
              .take(3)
              .toList()
              .asMap()
              .entries
              .map((entry) {
            final notification = entry.value;
            final isRead = notification['isRead'] == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PremiumCard(
                onTap: notification['id'] == null
                    ? null
                    : () => context
                        .read<AppCubit>()
                        .markNotificationRead(
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
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            notification['message']?.toString() ?? '',
                            style:
                                Theme.of(context).textTheme.bodySmall,
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
                  .fadeIn(
                      duration: 350.ms, delay: (50 * entry.key).ms)
                  .slideX(
                      begin: 0.05,
                      end: 0,
                      duration: 350.ms,
                      delay: (50 * entry.key).ms),
            );
          }),
        ],
      ],
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
                    title: Text(
                      n['title']?.toString() ?? '',
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      n['message']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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

// ─── _InfoChip ───────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 13,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _formatDateLabel(dynamic value) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty) return '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
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
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.success),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

// ─── Setup Banner ─────────────────────────────────────────────────────────────

/// Shown after registration until the user sets their password.
/// Displays the 6-digit setup code prominently so the user can copy it
/// and use it in the Change Password dialog without being signed out.
class _SetupBanner extends StatefulWidget {
  @override
  State<_SetupBanner> createState() => _SetupBannerState();
}

class _SetupBannerState extends State<_SetupBanner> {
  bool _visible = false;
  String? _setupCode;
  bool _codeCopied = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final hasTempPassword = prefs.getBool(_kTempPasswordKey) ?? false;
    if (hasTempPassword && mounted) {
      final code = prefs.getString('cbhi_setup_code') ??
          prefs.getString('cbhi_temp_password');
      setState(() {
        _visible = true;
        _setupCode = code;
      });
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTempPasswordKey);
    await prefs.remove('cbhi_setup_code');
    await prefs.remove('cbhi_temp_password');
    if (mounted) setState(() => _visible = false);
  }

  Future<void> _copyCode() async {
    if (_setupCode == null) return;
    await Clipboard.setData(ClipboardData(text: _setupCode!));
    if (!mounted) return;
    setState(() => _codeCopied = true);
    final strings = CbhiLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.t('setupCodeCopied')),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.success,
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _codeCopied = false);
  }

  Future<void> _showSetPasswordDialog(BuildContext context) async {
    final strings = CbhiLocalizations.of(context);
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;
    bool loading = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(strings.t('changePassword')),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show setup code for reference
                if (_setupCode != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppTheme.primary, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            strings.t('setupCodeReference'),
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.primary),
                          ),
                        ),
                        GestureDetector(
                          onTap: _copyCode,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusS),
                            ),
                            child: Text(
                              _setupCode!,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 4,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(error!,
                        style: const TextStyle(
                            color: AppTheme.error, fontSize: 13)),
                  ),
                ],
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: strings.t('newPassword'),
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: strings.t('confirmPassword'),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(strings.t('cancel')),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (newCtrl.text.length < 6) {
                        setDialogState(
                            () => error = strings.t('passwordTooShort'));
                        return;
                      }
                      if (newCtrl.text != confirmCtrl.text) {
                        setDialogState(
                            () => error = strings.t('passwordsDoNotMatch'));
                        return;
                      }
                      setDialogState(() => loading = true);
                      try {
                        // Use set-initial-password — does NOT invalidate session
                        await ctx
                            .read<AppCubit>()
                            .repository
                            .setInitialPasswordDirect(
                                password: newCtrl.text);
                        // Clear all setup code flags
                        final p = await SharedPreferences.getInstance();
                        await p.remove('cbhi_setup_code');
                        await p.remove('cbhi_temp_password');
                        await p.remove(_kTempPasswordKey);

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          setState(() => _visible = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(strings.t('passwordChanged')),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          error = e
                              .toString()
                              .replaceFirst('Exception: ', '');
                          loading = false;
                        });
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(strings.t('save')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final strings = CbhiLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_open_outlined,
                  color: AppTheme.warning, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.t('setupAccountTitle'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.warning,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: _dismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                color: AppTheme.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            strings.t('setupCodeBannerBody'),
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
          // Setup code display — tap to copy
          if (_setupCode != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _copyCode,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  border: Border.all(
                      color: AppTheme.warning.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _setupCode!,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                        color: AppTheme.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      _codeCopied
                          ? Icons.check_circle_outline
                          : Icons.copy_outlined,
                      color: _codeCopied
                          ? AppTheme.success
                          : AppTheme.warning,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                strings.t('tapToCopyCode'),
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.warning,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _showSetPasswordDialog(context),
                  icon: const Icon(Icons.lock_reset_outlined, size: 16),
                  label: Text(
                    strings.t('setPasswordNow'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                onPressed: _dismiss,
                child: Text(
                  strings.t('remindMeLater'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
  }
}

class ProfileTabNotification extends Notification {}

class FamilyTabNotification extends Notification {}

class _ReferralsSection extends StatelessWidget {
  const _ReferralsSection({required this.snapshot});

  final CbhiSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final activeReferrals =
        snapshot.referrals.where((r) => r['isUsed'] == false).toList();

    if (activeReferrals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: strings.t('activeReferrals'),
          icon: Icons.medical_services_outlined,
        ),
        const SizedBox(height: 12),
        ...activeReferrals.map((ref) => _ReferralCard(ref: ref)),
      ],
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.ref});

  final Map<String, dynamic> ref;

  @override
  Widget build(BuildContext context) {
    final code = ref['code']?.toString() ?? 'REF-XXXX';
    final facility =
        ref['issuedByFacility']?['name']?.toString() ?? 'Health Center';
    final expiresAtStr = ref['expiresAt']?.toString();
    final expiresAt =
        expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.assignment_outlined, color: AppTheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Issued by: $facility',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
                if (expiresAt != null)
                  Text(
                    'Expires: ${DateFormat.yMMMd().format(expiresAt)}',
                    style: TextStyle(
                      color: expiresAt.isBefore(DateTime.now())
                          ? AppTheme.error
                          : AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.qr_code, color: AppTheme.primary, size: 32),
        ],
      ),
    );
  }
}


