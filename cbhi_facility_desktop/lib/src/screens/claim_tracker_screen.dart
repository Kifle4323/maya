import '../app.dart';
import '../data/facility_repository.dart';
import '../i18n/app_localizations.dart';
import '../shared/widgets.dart';

class ClaimTrackerScreen extends StatefulWidget {
  const ClaimTrackerScreen({super.key, required this.repository});
  final FacilityRepository repository;

  @override
  State<ClaimTrackerScreen> createState() => _ClaimTrackerScreenState();
}

class _ClaimTrackerScreenState extends State<ClaimTrackerScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _claims = [];

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
      final claims = await widget.repository.getClaims();
      setState(() => _claims = claims);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) => switch (status.toUpperCase()) {
    'APPROVED' || 'PAID' => kSuccess,
    'REJECTED' => kError,
    'UNDER_REVIEW' => kWarning,
    _ => kPrimary,
  };

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final approved = _claims.where((c) => c['status'] == 'APPROVED' || c['status'] == 'PAID').length;
    final pending = _claims.where((c) => c['status'] == 'UNDER_REVIEW' || c['status'] == 'PENDING').length;
    final totalAmount = _claims.fold<double>(0, (sum, c) => sum + (double.tryParse(c['claimedAmount']?.toString() ?? '0') ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.t('claimOverview'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: kTextDark,
                    ),
                  ),
                  Text(
                    '${_claims.length} ${strings.t('totalClaimsSubmitted')}',
                    style: const TextStyle(color: kTextSecondary),
                  ),
                ],
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(strings.t('refreshData')),
              ),
            ],
          ),
        ),
        
        if (!_loading && _error == null && _claims.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: BentoGrid(
              children: [
                MetricCard(
                  title: strings.t('totalClaimedAmount'),
                  value: '${totalAmount.toStringAsFixed(0)} ETB',
                  icon: Icons.payments_outlined,
                  color: kPrimary,
                ),
                MetricCard(
                  title: strings.t('approvedClaims'),
                  value: approved.toString(),
                  icon: Icons.check_circle_outline,
                  color: kSuccess,
                  trend: '+12%',
                ),
                MetricCard(
                  title: strings.t('pendingReview'),
                  value: pending.toString(),
                  icon: Icons.hourglass_empty_outlined,
                  color: kWarning,
                ),
              ],
            ),
          ),

        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kPrimary))
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: kError, size: 48),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: kError)),
                    ],
                  ),
                )
              : _claims.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: kTextSecondary.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text(
                        strings.t('noClaimsSubmittedYet'),
                        style: const TextStyle(color: kTextSecondary, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            strings.t('recentClaimActivity'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: kTextDark,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        SizedBox(
                          width: double.infinity,
                          child: DataTable(
                            horizontalMargin: 20,
                            columns: [
                              DataColumn(label: Text(strings.t('claimNumber'))),
                              DataColumn(label: Text(strings.t('beneficiary'))),
                              DataColumn(label: Text(strings.t('serviceDate'))),
                              DataColumn(label: Text(strings.t('claimed'))),
                              DataColumn(label: Text(strings.t('approved'))),
                              DataColumn(label: Text(strings.t('status'))),
                              const DataColumn(label: Text('')),
                            ],
                            rows: _claims.map((claim) {
                              final status = claim['status']?.toString() ?? '';
                              final color = _statusColor(status);
                              return DataRow(
                                cells: [
                                  DataCell(Text(claim['claimNumber']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text(claim['beneficiaryName']?.toString() ?? '—')),
                                  DataCell(Text(claim['serviceDate']?.toString().split('T').first ?? '—')),
                                  DataCell(Text('${claim['claimedAmount'] ?? 0} ETB')),
                                  DataCell(Text('${claim['approvedAmount'] ?? 0} ETB', style: TextStyle(color: color, fontWeight: FontWeight.bold))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        strings.statusLabel(status),
                                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                  ),
                                  DataCell(IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_right, size: 20))),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
