import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../cbhi_data.dart';
import '../cbhi_localizations.dart';
import '../shared/premium_widgets.dart';
import '../theme/app_theme.dart';

/// Full claims screen — M3 HealthShield redesign.
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
          const Icon(Icons.gavel_outlined, color: AppTheme.m3Primary),
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
            style: FilledButton.styleFrom(backgroundColor: AppTheme.m3Primary),
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
            backgroundColor: AppTheme.m3Tertiary,
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
        // Page header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.t('claimsHistory'),
                style: const TextStyle(
                  color: AppTheme.m3OnSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                strings.t('trackClaimsSubtitle'),
                style: const TextStyle(
                  color: AppTheme.m3OnSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Automated billing info banner
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.m3TertiaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome_outlined, color: AppTheme.m3OnTertiaryContainer, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.t('automatedBillingActive'),
                        style: const TextStyle(
                          color: AppTheme.m3OnTertiaryContainer,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.t('claimsSubmittedByFacility'),
                        style: TextStyle(
                          color: AppTheme.m3OnTertiaryContainer.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
        ),

        const SizedBox(height: 16),

        // Filter bar
        if (claims.isNotEmpty)
          FilterBar(
            filters: filters,
            selected: _statusFilter,
            onSelected: (v) => setState(() => _statusFilter = v),
          ).animate().fadeIn(duration: 300.ms, delay: 150.ms),

        const SizedBox(height: 8),

        // Claims list
        Expanded(
          child: filtered.isEmpty
              ? _EmptyClaimsState(
                  statusFilter: _statusFilter,
                  strings: strings,
                ).animate().fadeIn(duration: 400.ms, delay: 150.ms)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final claim = filtered[index];
                    final claimId = claim['id']?.toString() ?? '';
                    final alreadyAppealed = _hasAppeal(claimId);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _M3ClaimCard(
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

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyClaimsState extends StatelessWidget {
  const _EmptyClaimsState({
    required this.statusFilter,
    required this.strings,
  });

  final String statusFilter;
  final dynamic strings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Main empty area
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.m3SurfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.m3OutlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.m3SurfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      size: 40,
                      color: AppTheme.m3OnSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    statusFilter == 'ALL'
                        ? strings.t('noClaimsYet')
                        : strings.t('noClaimsForFilter'),
                    style: const TextStyle(
                      color: AppTheme.m3OnSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      statusFilter == 'ALL'
                          ? strings.t('claimsWillAppearHere')
                          : strings.t('tryDifferentFilter'),
                      style: const TextStyle(
                        color: AppTheme.m3OnSurfaceVariant,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Info cards
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _InfoCard(
                    icon: Icons.schedule_outlined,
                    title: strings.t('processingTime'),
                    items: [
                      _InfoRow(label: strings.t('automatedBilling'), value: '1-3 ${strings.t('days')}'),
                      _InfoRow(label: strings.t('manualClaims'), value: '7-14 ${strings.t('days')}'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoCard(
                    icon: Icons.verified_user_outlined,
                    title: strings.t('claimVerification'),
                    description: strings.t('claimVerificationHint'),
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    this.items,
    this.description,
  });

  final IconData icon;
  final String title;
  final List<_InfoRow>? items;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.m3SurfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.m3OutlineVariant.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.m3Primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.m3OnSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items != null)
            ...items!.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item.label, style: const TextStyle(color: AppTheme.m3OnSurfaceVariant, fontSize: 12)),
                  Text(item.value, style: const TextStyle(color: AppTheme.m3OnSurface, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            )),
          if (description != null)
            Text(
              description!,
              style: const TextStyle(color: AppTheme.m3OnSurfaceVariant, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
}

// ── M3 Claim Card ─────────────────────────────────────────────────────────────

class _M3ClaimCard extends StatelessWidget {
  const _M3ClaimCard({
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

  Color _statusBg(String status) {
    return switch (status.toUpperCase()) {
      'APPROVED' || 'PAID' => AppTheme.m3TertiaryContainer.withValues(alpha: 0.2),
      'REJECTED' => AppTheme.m3ErrorContainer,
      'UNDER_REVIEW' => AppTheme.m3SurfaceVariant,
      'SUBMITTED' => AppTheme.m3PrimaryContainer.withValues(alpha: 0.2),
      _ => AppTheme.m3SurfaceVariant,
    };
  }

  Color _statusFg(String status) {
    return switch (status.toUpperCase()) {
      'APPROVED' || 'PAID' => AppTheme.m3Tertiary,
      'REJECTED' => AppTheme.m3OnErrorContainer,
      'UNDER_REVIEW' => AppTheme.m3OnSurfaceVariant,
      'SUBMITTED' => AppTheme.m3Primary,
      _ => AppTheme.m3OnSurfaceVariant,
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
    final facilityName = claim['facilityName']?.toString() ?? strings.t('healthFacility');
    final serviceDate = claim['serviceDate']?.toString();
    final claimedAmount = claim['claimedAmount'];
    final approvedAmount = claim['approvedAmount'];
    final decisionNote = claim['decisionNote']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.m3SurfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.m3OutlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.m3SurfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_outlined, color: AppTheme.m3OnSurfaceVariant, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facilityName,
                      style: const TextStyle(
                        color: AppTheme.m3OnSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      claimNumber,
                      style: const TextStyle(
                        color: AppTheme.m3OnSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Status chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusBg(status),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon(status), size: 12, color: _statusFg(status)),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(
                        color: _statusFg(status),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.m3OutlineVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
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
                  value: claimedAmount != null ? '$claimedAmount ETB' : 'N/A',
                ),
              ),
              if (approvedAmount != null &&
                  double.tryParse(approvedAmount.toString()) != null &&
                  double.parse(approvedAmount.toString()) > 0)
                Expanded(
                  child: _DetailItem(
                    label: strings.t('approved'),
                    value: '$approvedAmount ETB',
                    valueColor: AppTheme.m3Tertiary,
                  ),
                ),
            ],
          ),
          if (decisionNote != null && decisionNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.m3SurfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_outlined, size: 14, color: AppTheme.m3OnSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      decisionNote,
                      style: const TextStyle(
                        color: AppTheme.m3OnSurfaceVariant,
                        fontSize: 12,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Appeal states
          if (alreadyAppealed) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hourglass_empty, size: 14, color: AppTheme.warning),
                  const SizedBox(width: 6),
                  Text(
                    strings.t('appealPending'),
                    style: const TextStyle(
                      color: AppTheme.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (canAppeal) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onAppeal,
              icon: const Icon(Icons.gavel_outlined, size: 16),
              label: Text(strings.t('submitAppeal')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.m3Primary,
                side: const BorderSide(color: AppTheme.m3Primary),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: const Size(0, 40),
              ),
            ),
          ],
        ],
      ),
    );
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
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.m3OnSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppTheme.m3OnSurface,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
