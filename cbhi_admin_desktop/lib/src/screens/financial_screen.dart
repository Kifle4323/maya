import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../i18n/app_localizations.dart';
import '../theme/admin_theme.dart';
import '../widgets/stat_card.dart';
import '../widgets/section_card.dart';

/// Financial Dashboard — revenue, claims paid, net position, sustainability metrics.
class FinancialScreen extends StatefulWidget {
  const FinancialScreen({super.key, required this.repository});
  final AdminRepository repository;

  @override
  State<FinancialScreen> createState() => _FinancialScreenState();
}

class _FinancialScreenState extends State<FinancialScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.repository.getFinancialDashboard(
        from: _from?.toIso8601String().split('T').first,
        to: _to?.toIso8601String().split('T').first,
      );
      setState(() => _data = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AdminTheme.primary)),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() { _from = range.start; _to = range.end; });
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator(color: AdminTheme.primary));
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: AdminTheme.error)));

    final revenue = (_data['totalRevenue'] as num? ?? 0).toDouble();
    final claimed = (_data['totalClaimsPaid'] as num? ?? 0).toDouble();
    final net = (_data['netPosition'] as num? ?? 0).toDouble();
    final approvalRate = (_data['claimApprovalRate'] as num? ?? 0).toInt();
    final avgClaim = (_data['averageClaimAmount'] as num? ?? 0).toDouble();
    final households = (_data['totalHouseholds'] as num? ?? 0).toInt();

    final isHealthy = net >= 0;

    return RefreshIndicator(
      onRefresh: _load,
      color: AdminTheme.primary,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date range
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(strings.t('financialDashboard'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Theme.of(context).brightness == Brightness.dark ? AdminTheme.darkTextPrimary : AdminTheme.textDark)),
                    Text(strings.t('financialDashboardSubtitle'), style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AdminTheme.darkTextSecondary : AdminTheme.textSecondary, fontSize: 13)),
                  ],
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range_outlined, size: 16, color: AdminTheme.primary),
                  label: Text(
                    _from != null && _to != null
                        ? '${_from!.day}/${_from!.month} — ${_to!.day}/${_to!.month}'
                        : strings.t('allTime'),
                    style: const TextStyle(color: AdminTheme.primary),
                  ),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AdminTheme.primary)),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: strings.t('refresh')),
              ],
            ),

            const SizedBox(height: 24),

            // Net position banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isHealthy
                      ? [const Color(0xFF2E7D52), const Color(0xFF43A047)]
                      : [const Color(0xFFE53935), const Color(0xFFEF5350)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                    child: Icon(isHealthy ? Icons.trending_up : Icons.trending_down, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(strings.t('netPosition'), style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                        Text(
                          '${net >= 0 ? '+' : ''}${net.toStringAsFixed(0)} ETB',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28),
                        ),
                        Text(
                          isHealthy ? strings.t('schemeFinanciallyHealthy') : strings.t('schemeDeficit'),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(strings.t('claimRatio'), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                      Text(
                        revenue > 0 ? '${(claimed / revenue * 100).toStringAsFixed(1)}%' : '—',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // KPI row
            Row(
              children: [
                Expanded(child: StatCard(label: strings.t('totalRevenue'), value: '${revenue.toStringAsFixed(0)} ETB', icon: Icons.account_balance_outlined, color: AdminTheme.success)),
                const SizedBox(width: 16),
                Expanded(child: StatCard(label: strings.t('totalClaimsPaid'), value: '${claimed.toStringAsFixed(0)} ETB', icon: Icons.payments_outlined, color: AdminTheme.warning)),
                const SizedBox(width: 16),
                Expanded(child: StatCard(label: strings.t('claimApprovalRate'), value: '$approvalRate%', icon: Icons.check_circle_outline, color: AdminTheme.primary)),
                const SizedBox(width: 16),
                Expanded(child: StatCard(label: strings.t('avgClaimAmount'), value: '${avgClaim.toStringAsFixed(0)} ETB', icon: Icons.receipt_long_outlined, color: AdminTheme.accent)),
              ],
            ),

            const SizedBox(height: 20),

            // Sustainability metrics
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SectionCard(
                    title: strings.t('sustainabilityMetrics'),
                    icon: Icons.eco_outlined,
                    child: Column(
                      children: [
                        _MetricRow(label: strings.t('enrolledHouseholds'), value: '$households', icon: Icons.home_outlined, color: AdminTheme.primary),
                        _MetricRow(label: strings.t('revenuePerHousehold'), value: households > 0 ? '${(revenue / households).toStringAsFixed(0)} ETB' : '—', icon: Icons.person_outlined, color: AdminTheme.accent),
                        _MetricRow(label: strings.t('claimsPerHousehold'), value: households > 0 ? '${(claimed / households).toStringAsFixed(0)} ETB' : '—', icon: Icons.receipt_outlined, color: AdminTheme.warning),
                        _MetricRow(label: strings.t('fundingRatio'), value: claimed > 0 ? '${(revenue / claimed * 100).toStringAsFixed(0)}%' : '—', icon: Icons.pie_chart_outline, color: isHealthy ? AdminTheme.success : AdminTheme.error),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SectionCard(
                    title: strings.t('quickActions'),
                    icon: Icons.bolt_outlined,
                    child: Column(
                      children: [
                        _ActionButton(
                          icon: Icons.download_outlined,
                          label: strings.t('exportFinancialReport'),
                          onTap: () {},
                        ),
                        const SizedBox(height: 8),
                        _ActionButton(
                          icon: Icons.send_outlined,
                          label: strings.t('sendToFMOH'),
                          onTap: () {},
                          color: AdminTheme.accent,
                        ),
                        const SizedBox(height: 8),
                        _ActionButton(
                          icon: Icons.schedule_outlined,
                          label: strings.t('scheduleReimbursement'),
                          onTap: () {},
                          color: AdminTheme.warning,
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

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AdminTheme.darkTextSecondary : AdminTheme.textSecondary, fontSize: 13))),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.color = AdminTheme.primary});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 12, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
