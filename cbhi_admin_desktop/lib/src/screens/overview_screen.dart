import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../i18n/app_localizations.dart';
import '../theme/admin_theme.dart';
import '../widgets/stat_card.dart';
import '../widgets/section_card.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key, required this.repository});
  final AdminRepository repository;

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _report = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await widget.repository.getSummaryReport();
      setState(() {
        _report = report;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AdminTheme.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: AdminTheme.error)),
      );
    }

    final claims = (_report['claims'] as Map?)?.cast<String, dynamic>() ?? {};
    final payments =
        (_report['payments'] as Map?)?.cast<String, dynamic>() ?? {};

    return RefreshIndicator(
      onRefresh: _load,
      color: AdminTheme.primary,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI row
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: strings.t('totalHouseholds'),
                    value: '${_report['households'] ?? 0}',
                    icon: Icons.home_outlined,
                    color: AdminTheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    label: strings.t('accreditedFacilities'),
                    value: '${_report['accreditedFacilities'] ?? 0}',
                    icon: Icons.local_hospital_outlined,
                    color: AdminTheme.accent,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    label: strings.t('claimsSubmitted'),
                    value: '${claims['submitted'] ?? 0}',
                    icon: Icons.receipt_long_outlined,
                    color: AdminTheme.warning,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    label: strings.t('pendingIndigent'),
                    value: '${_report['pendingIndigentApplications'] ?? 0}',
                    icon: Icons.volunteer_activism_outlined,
                    color: AdminTheme.gold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Claims breakdown
                Expanded(
                  child: SectionCard(
                    title: strings.t('claimsBreakdown'),
                    icon: Icons.pie_chart_outline,
                    child: Column(
                      children: [
                        _ClaimsRow(
                          label: strings.t('submitted'),
                          value: '${claims['submitted'] ?? 0}',
                          color: AdminTheme.primary,
                        ),
                        _ClaimsRow(
                          label: strings.t('approved'),
                          value: '${claims['approved'] ?? 0}',
                          color: AdminTheme.success,
                        ),
                        _ClaimsRow(
                          label: strings.t('rejected'),
                          value: '${claims['rejected'] ?? 0}',
                          color: AdminTheme.error,
                        ),
                        _ClaimsRow(
                          label: strings.t('paid'),
                          value: '${claims['paid'] ?? 0}',
                          color: AdminTheme.accent,
                        ),
                        const Divider(),
                        _ClaimsRow(
                          label: strings.t('totalClaimed'),
                          value: '${claims['totalClaimedAmount'] ?? 0} ETB',
                          color: AdminTheme.textPrimaryFor(Theme.of(context).brightness),
                          bold: true,
                        ),
                        _ClaimsRow(
                          label: strings.t('totalApproved'),
                          value: '${claims['totalApprovedAmount'] ?? 0} ETB',
                          color: AdminTheme.success,
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Financial summary
                Expanded(
                  child: SectionCard(
                    title: strings.t('financialSummary'),
                    icon: Icons.account_balance_outlined,
                    child: Column(
                      children: [
                        _ClaimsRow(
                          label: strings.t('totalTransactions'),
                          value: '${payments['totalTransactions'] ?? 0}',
                          color: AdminTheme.primary,
                        ),
                        _ClaimsRow(
                          label: strings.t('totalCollected'),
                          value: '${payments['totalCollectedAmount'] ?? 0} ETB',
                          color: AdminTheme.success,
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClaimsRow extends StatelessWidget {
  const _ClaimsRow({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });
  final String label;
  final String value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AdminTheme.textSecondaryFor(Theme.of(context).brightness),
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
