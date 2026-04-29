import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../cbhi_data.dart';
import '../cbhi_localizations.dart';
import '../shared/animated_widgets.dart';
import '../theme/app_theme.dart';

/// Coverage History Screen — shows past and current coverage periods,
/// renewal history, and benefit utilization.
class CoverageHistoryScreen extends StatefulWidget {
  const CoverageHistoryScreen({super.key, required this.repository});
  final CbhiRepository repository;

  @override
  State<CoverageHistoryScreen> createState() => _CoverageHistoryScreenState();
}

class _CoverageHistoryScreenState extends State<CoverageHistoryScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _history = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.repository.getCoverageHistory();
      setState(() => _history = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.t('coverageHistory'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error)))
          : _history.isEmpty
          ? EmptyState(icon: Icons.history_outlined, title: strings.t('noCoverageHistory'), subtitle: strings.t('noCoverageHistorySubtitle'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                itemCount: _history.length,
                itemBuilder: (_, i) {
                  final coverage = _history[i];
                  final status = coverage['status']?.toString() ?? '';
                  final isActive = status == 'ACTIVE';
                  final startDate = coverage['startDate']?.toString().split('T').first ?? '—';
                  final endDate = coverage['endDate']?.toString().split('T').first ?? '—';
                  final premium = double.tryParse(coverage['premiumAmount']?.toString() ?? '0') ?? 0;
                  final paid = double.tryParse(coverage['paidAmount']?.toString() ?? '0') ?? 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (isActive ? AppTheme.success : AppTheme.textSecondaryFor(Theme.of(context).brightness)).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isActive ? Icons.verified_outlined : Icons.history_outlined,
                                  color: isActive ? AppTheme.success : AppTheme.textSecondaryFor(Theme.of(context).brightness),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      coverage['coverageNumber']?.toString() ?? '—',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                                    ),
                                    Text('$startDate → $endDate', style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              StatusBadge(label: status),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _CoverageMetric(label: strings.t('premium'), value: '${premium.toStringAsFixed(0)} ETB', color: AppTheme.gold)),
                              Expanded(child: _CoverageMetric(label: strings.t('paid'), value: '${paid.toStringAsFixed(0)} ETB', color: AppTheme.success)),
                              Expanded(child: _CoverageMetric(
                                label: strings.t('membershipType'),
                                value: coverage['membershipType']?.toString() ?? '—',
                                color: AppTheme.primary,
                              )),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0);
                },
              ),
            ),
    );
  }
}

class _CoverageMetric extends StatelessWidget {
  const _CoverageMetric({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 14)),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
      ],
    );
  }
}
