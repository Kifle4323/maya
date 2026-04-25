import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../cbhi_data.dart';
import '../cbhi_localizations.dart';
import '../shared/animated_widgets.dart';
import '../shared/premium_widgets.dart';
import '../theme/app_theme.dart';

/// Full claims screen — shows claim history and allows viewing claim details.
/// Members cannot submit claims directly (only facility staff can).
/// This screen shows all claims for the household with status tracking.
/// Members can submit an appeal for REJECTED claims.
class MemberClaimsScreen extends StatefulWidget {
  const MemberClaimsScreen({super.key, required this.snapshot, this.repository});

  final CbhiSnapshot snapshot;
  final CbhiRepository? repository;

  @override
  State<MemberClaimsScreen> createState() => _MemberClaimsScreenState();
}

class _MemberClaimsScreenState extends State<MemberClaimsScreen> {
  List<Map<String, dynamic>> _appeals = [];
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadAppeals();
  }

  Future<void> _loadAppeals() async {
    final repo = widget.repository;
    if (repo == null) return;
    try {
      final appeals = await repo.getMyAppeals();
      if (mounted) setState(() => _appeals = appeals);
    } catch (_) {}
  }

  bool _hasAppeal(String claimId) =>
      _appeals.any((a) => a['claimId']?.toString() == claimId);

  List<Map<String, dynamic>> get _filteredClaims {
    final claims = widget.snapshot.claims;
    if (_statusFilter == 'ALL') return claims;
    return claims
        .where((c) =>
            c['status']?.toString().toUpperCase() == _statusFilter)
        .toList();
  }

  Future<void> _submitAppeal(BuildContext context, Map<String, dynamic> claim) async {
    final repo = widget.repository;
    if (repo == null) return;
    final strings = CbhiLocalizations.of(context);
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.gavel_outlined, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(strings.t('submitAppeal')),
        ]),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.f('appealForClaim', {'claimNumber': claim['claimNumber']?.toString() ?? ''}),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: strings.t('appealReason'),
                  hintText: strings.t('appealReasonHint'),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: Text(strings.t('submitAppeal')),
          ),
        ],
      ),
    );

    if (confirmed != true || reasonCtrl.text.trim().isEmpty) return;
    try {
      await repo.submitClaimAppeal(
        claimId: claim['id'].toString(),
        reason: reasonCtrl.text.trim(),
      );
      await _loadAppeals();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.t('appealSubmitted')),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final claims = widget.snapshot.claims;
    final filtered = _filteredClaims;

    // Build filter counts
    int countFor(String status) => status == 'ALL'
        ? claims.length
        : claims.where((c) => c['status']?.toString().toUpperCase() == status).length;

    final filters = [
      FilterOption(value: 'ALL', label: strings.t('all'), count: countFor('ALL')),
      FilterOption(value: 'SUBMITTED', label: strings.t('submitted'), count: countFor('SUBMITTED')),
      FilterOption(value: 'UNDER_REVIEW', label: strings.t('underReview'), count: countFor('UNDER_REVIEW')),
      FilterOption(value: 'APPROVED', label: strings.t('approved'), count: countFor('APPROVED')),
      FilterOption(value: 'REJECTED', label: strings.t('rejected'), count: countFor('REJECTED')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero header
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingM, AppTheme.spacingM, AppTheme.spacingM, 0),
          child: AnimatedHeroCard(
            icon: Icons.receipt_long_outlined,
            title: strings.t('myClaims'),
            subtitle: strings.t('trackClaimsSubtitle'),
            value: '${claims.length} ${strings.t('claims')}',
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
        ),

        const SizedBox(height: AppTheme.spacingM),

        // Info banner
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
          child: InfoBanner(
            message: strings.t('claimsSubmittedByFacility'),
            variant: BannerVariant.info,
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
        ),

        const SizedBox(height: AppTheme.spacingM),

        // Filter bar
        if (claims.isNotEmpty)
          FilterBar(
            filters: filters,
            selected: _statusFilter,
            onSelected: (v) => setState(() => _statusFilter = v),
          ).animate().fadeIn(duration: 300.ms, delay: 150.ms),

        const SizedBox(height: AppTheme.spacingS),

        // Claims list
        Expanded(
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: EmptyView(
                    icon: Icons.receipt_long_outlined,
                    title: _statusFilter == 'ALL'
                        ? strings.t('noClaimsYet')
                        : strings.t('noClaimsForFilter'),
                    subtitle: _statusFilter == 'ALL'
                        ? strings.t('claimsWillAppearHere')
                        : strings.t('tryDifferentFilter'),
                  ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacingM, 0, AppTheme.spacingM, AppTheme.spacingM),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final claim = filtered[index];
                    final claimId = claim['id']?.toString() ?? '';
                    final alreadyAppealed = _hasAppeal(claimId);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ClaimCard(
                        claim: claim,
                        index: index,
                        canAppeal:
                            claim['status']?.toString().toUpperCase() == 'REJECTED' &&
                                !alreadyAppealed &&
                                widget.repository != null,
                        alreadyAppealed: alreadyAppealed,
                        onAppeal: () => _submitAppeal(context, claim),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({
    required this.claim,
    required this.index,
    this.canAppeal = false,
    this.alreadyAppealed = false,
    this.onAppeal,
  });

  final Map<String, dynamic> claim;
  final int index;
  final bool canAppeal;
  final bool alreadyAppealed;
  final VoidCallback? onAppeal;

  Color _statusColor(String status) {
    return switch (status.toUpperCase()) {
      'APPROVED' || 'PAID' => AppTheme.success,
      'REJECTED' => AppTheme.error,
      'UNDER_REVIEW' => AppTheme.warning,
      'SUBMITTED' => AppTheme.primary,
      _ => AppTheme.textSecondary,
    };
  }

  IconData _statusIcon(String status) {
    return switch (status.toUpperCase()) {
      'APPROVED' || 'PAID' => Icons.check_circle_outline,
      'REJECTED' => Icons.cancel_outlined,
      'UNDER_REVIEW' => Icons.hourglass_empty,
      'SUBMITTED' => Icons.send_outlined,
      _ => Icons.help_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final status = claim['status']?.toString() ?? 'UNKNOWN';
    final claimNumber = claim['claimNumber']?.toString() ?? 'N/A';
    // Facility name is now the primary title (Oscar Health pattern)
    final facilityName = claim['facilityName']?.toString() ?? strings.t('healthFacility');
    final serviceDate = claim['serviceDate']?.toString();
    final claimedAmount = claim['claimedAmount'];
    final approvedAmount = claim['approvedAmount'];
    final decisionNote = claim['decisionNote']?.toString();
    final color = _statusColor(status);

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_statusIcon(status), color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Facility name is primary — more meaningful than claim number
                    Text(
                      facilityName,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      claimNumber,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              StatusPill(label: status, color: color),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DetailItem(
                  label: strings.t('serviceDate'),
                  value: serviceDate?.split('T').first ?? 'N/A',
                ),
              ),
              Expanded(
                child: _DetailItem(
                  label: strings.t('claimed'),
                  value: claimedAmount != null
                      ? '$claimedAmount ETB'
                      : 'N/A',
                ),
              ),
              if (approvedAmount != null &&
                  double.tryParse(approvedAmount.toString()) != null &&
                  double.parse(approvedAmount.toString()) > 0)
                Expanded(
                  child: _DetailItem(
                    label: strings.t('approved'),
                    value: '$approvedAmount ETB',
                    valueColor: AppTheme.success,
                  ),
                ),
            ],
          ),
          if (decisionNote != null && decisionNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_outlined,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      decisionNote,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Appeal button for rejected claims
          if (alreadyAppealed) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hourglass_empty, size: 14, color: AppTheme.warning),
                  const SizedBox(width: 6),
                  Text(
                    CbhiLocalizations.of(context).t('appealPending'),
                    style: const TextStyle(
                        color: AppTheme.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ] else if (canAppeal) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onAppeal,
              icon: const Icon(Icons.gavel_outlined, size: 16),
              label: Text(CbhiLocalizations.of(context).t('submitAppeal')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: const Size(0, 40),
              ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms, delay: (index * 60).ms)
        .slideY(begin: 0.05, end: 0, duration: 350.ms, delay: (index * 60).ms);
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
        ),
      ],
    );
  }
}
