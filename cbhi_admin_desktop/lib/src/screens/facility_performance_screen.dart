import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../i18n/app_localizations.dart';
import '../theme/admin_theme.dart';

/// Facility Performance Dashboard — claims submitted, approval rate, average claim amount per facility.
class FacilityPerformanceScreen extends StatefulWidget {
  const FacilityPerformanceScreen({super.key, required this.repository});
  final AdminRepository repository;

  @override
  State<FacilityPerformanceScreen> createState() => _FacilityPerformanceScreenState();
}

class _FacilityPerformanceScreenState extends State<FacilityPerformanceScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _facilities = [];
  String _sortBy = 'totalClaims';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.repository.getFacilityPerformance();
      setState(() => _facilities = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _sorted {
    final list = List<Map<String, dynamic>>.from(_facilities);
    list.sort((a, b) {
      final av = (a[_sortBy] as num? ?? 0);
      final bv = (b[_sortBy] as num? ?? 0);
      return bv.compareTo(av);
    });
    return list;
  }

  Color _performanceColor(double approvalRate) {
    if (approvalRate >= 80) return AdminTheme.success;
    if (approvalRate >= 60) return AdminTheme.warning;
    return AdminTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator(color: AdminTheme.primary));
    if (_error != null) return Center(child: Text(_error!, style: TextStyle(color: AdminTheme.error)));

    final sorted = _sorted;

    return Column(
      children: [
        // Header
        Container(
          color: AdminTheme.cardBgFor(Theme.of(context).brightness),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Text(strings.t('facilityPerformance'), style: TextStyle(fontWeight: FontWeight.w600, color: AdminTheme.textPrimaryFor(Theme.of(context).brightness))),
              const SizedBox(width: 16),
              Text(strings.t('sortBy'), style: TextStyle(color: AdminTheme.textSecondaryFor(Theme.of(context).brightness), fontSize: 13)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _sortBy,
                underline: const SizedBox(),
                style: TextStyle(color: AdminTheme.primary, fontWeight: FontWeight.w600, fontSize: 13),
                items: [
                  DropdownMenuItem(value: 'totalClaims', child: Text(strings.t('totalClaims'))),
                  DropdownMenuItem(value: 'approvalRate', child: Text(strings.t('approvalRate'))),
                  DropdownMenuItem(value: 'totalApprovedAmount', child: Text(strings.t('totalApproved'))),
                ],
                onChanged: (v) => setState(() => _sortBy = v ?? _sortBy),
              ),
              const Spacer(),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: strings.t('refresh')),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: sorted.isEmpty
              ? Center(child: Text(strings.t('noFacilitiesFound')))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: sorted.asMap().entries.map((entry) {
                      final i = entry.key;
                      final f = entry.value;
                      final totalClaims = (f['totalClaims'] as num? ?? 0).toInt();
                      final approvalRate = (f['approvalRate'] as num? ?? 0).toDouble();
                      final totalApproved = (f['totalApprovedAmount'] as num? ?? 0).toDouble();
                      final avgClaim = (f['averageClaimAmount'] as num? ?? 0).toDouble();
                      final color = _performanceColor(approvalRate);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AdminTheme.cardBgFor(Theme.of(context).brightness),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade100),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            // Rank badge
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: i < 3 ? AdminTheme.gold.withValues(alpha: 0.15) : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '#${i + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: i < 3 ? AdminTheme.gold : AdminTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Facility info
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f['facilityName']?.toString() ?? '—', style: TextStyle(fontWeight: FontWeight.w700, color: AdminTheme.textPrimaryFor(Theme.of(context).brightness), fontSize: 14)),
                                  Text(f['serviceLevel']?.toString() ?? '', style: TextStyle(color: AdminTheme.textSecondaryFor(Theme.of(context).brightness), fontSize: 12)),
                                ],
                              ),
                            ),

                            // Metrics
                            Expanded(
                              flex: 4,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _PerfMetric(label: strings.t('totalClaims'), value: '$totalClaims', color: AdminTheme.primary),
                                  if ((f['referralsIssued'] as num? ?? 0) > 0)
                                    _PerfMetric(label: strings.t('referralsIssued'), value: '${f['referralsIssued']}', color: AdminTheme.accent),
                                  if ((f['referralsUsed'] as num? ?? 0) > 0)
                                    _PerfMetric(label: strings.t('referralsUsed'), value: '${f['referralsUsed']}', color: AdminTheme.gold),
                                  _PerfMetric(label: strings.t('approvalRate'), value: '${approvalRate.toStringAsFixed(0)}%', color: color),
                                  _PerfMetric(label: strings.t('totalApproved'), value: '${totalApproved.toStringAsFixed(0)} ETB', color: AdminTheme.success),
                                  _PerfMetric(label: strings.t('avgClaim'), value: '${avgClaim.toStringAsFixed(0)} ETB', color: AdminTheme.warning),
                                ],
                              ),
                            ),

                            // Performance bar
                            SizedBox(
                              width: 80,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${approvalRate.toStringAsFixed(0)}%', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: approvalRate / 100,
                                      backgroundColor: color.withValues(alpha: 0.1),
                                      valueColor: AlwaysStoppedAnimation<Color>(color),
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }
}

class _PerfMetric extends StatelessWidget {
  const _PerfMetric({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: AdminTheme.textSecondaryFor(Theme.of(context).brightness))),
      ],
    );
  }
}
