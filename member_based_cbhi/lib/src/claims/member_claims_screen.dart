import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../cbhi_data.dart';
import '../cbhi_localizations.dart';
import '../shared/animated_widgets.dart';
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

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      children: [
        AnimatedHeroCard(
          icon: Icons.receipt_long_outlined,
          title: strings.t('myClaims'),
          subtitle: strings.t('trackClaimsSubtitle'),
          value: strings.t('claims'),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

        const SizedBox(height: 16),

        // Info banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: AppTheme.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.t('claimsSubmittedByFacility'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

        const SizedBox(height: 20),

        if (claims.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: strings.t('noClaimsYet'),
            subtitle: strings.t('claimsWillAppearHere'),
          ).animate().fadeIn(duration: 400.ms, delay: 150.ms)
        else
          ...claims.asMap().entries.map((entry) {
            final claim = entry.value;
            final alreadyAppealed = _hasAppeal(claim['id']?.toString() ?? '');
            return _ClaimCard(
              claim: claim,
              index: entry.key,
              canAppeal: claim['status']?.toString().toUpperCase() == 'REJECTED' &&
                  !alreadyAppealed &&
                  widget.repository != null,
              alreadyAppealed: alreadyAppealed,
              onAppeal: () => _submitAppeal(context, claim),
            );
          }),
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
    final facilityName = claim['facilityName']?.toString();
    final serviceDate = claim['serviceDate']?.toString();
    final claimedAmount = claim['claimedAmount'];
    final approvedAmount = claim['approvedAmount'];
    final decisionNote = claim['decisionNote']?.toString();
    final color = _statusColor(status);

    return GlassCard(
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
                    Text(
                      claimNumber,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (facilityName != null)
                      Text(facilityName,
                          style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              StatusBadge(label: status, color: color),
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
                    style: const TextStyle(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.w600),
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
