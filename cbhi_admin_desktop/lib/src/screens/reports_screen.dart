// ignore_for_file: use_build_context_synchronously
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/admin_repository.dart';
import '../i18n/app_localizations.dart';
import '../theme/admin_theme.dart';
import '../widgets/error_state_widget.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.repository});
  final AdminRepository repository;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  DateTime? _from;
  DateTime? _to;

  // Summary tab data
  bool _summaryLoading = true;
  String? _summaryError;
  Map<String, dynamic> _summary = {};

  // Claims tab data
  bool _claimsLoading = true;
  String? _claimsError;
  List<Map<String, dynamic>> _claims = [];
  String _claimsSearch = '';

  // Financial tab data
  bool _financialLoading = true;
  String? _financialError;
  Map<String, dynamic> _financial = {};

  // Facility performance tab data
  bool _facilityLoading = true;
  String? _facilityError;
  List<Map<String, dynamic>> _facilities = [];

  // Indigent/member trends tab data
  bool _indigentLoading = true;
  String? _indigentError;
  List<Map<String, dynamic>> _indigent = [];

  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _loadCurrentTab();
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? get _fromStr => _from?.toIso8601String().split('T').first;
  String? get _toStr => _to?.toIso8601String().split('T').first;

  Future<void> _loadAll() async {
    _loadSummary();
    _loadClaims();
    _loadFinancial();
    _loadFacilities();
    _loadIndigent();
  }

  Future<void> _loadCurrentTab() async {
    switch (_tabController.index) {
      case 0: _loadSummary();
      case 1: _loadClaims();
      case 2: _loadFinancial();
      case 3: _loadFacilities();
      case 4: _loadIndigent();
    }
  }

  Future<void> _loadSummary() async {
    setState(() { _summaryLoading = true; _summaryError = null; });
    try {
      final data = await widget.repository.getSummaryReport(
        from: _fromStr, to: _toStr,
      );
      if (mounted) setState(() => _summary = data);
    } catch (e) {
      if (mounted) setState(() => _summaryError = e.toString());
    } finally {
      if (mounted) setState(() => _summaryLoading = false);
    }
  }

  Future<void> _loadClaims() async {
    setState(() { _claimsLoading = true; _claimsError = null; });
    try {
      final data = await widget.repository.getClaims();
      if (mounted) setState(() => _claims = data);
    } catch (e) {
      if (mounted) setState(() => _claimsError = e.toString());
    } finally {
      if (mounted) setState(() => _claimsLoading = false);
    }
  }

  Future<void> _loadFinancial() async {
    setState(() { _financialLoading = true; _financialError = null; });
    try {
      final data = await widget.repository.getFinancialDashboard(
        from: _fromStr, to: _toStr,
      );
      if (mounted) setState(() => _financial = data);
    } catch (e) {
      if (mounted) setState(() => _financialError = e.toString());
    } finally {
      if (mounted) setState(() => _financialLoading = false);
    }
  }

  Future<void> _loadFacilities() async {
    setState(() { _facilityLoading = true; _facilityError = null; });
    try {
      final data = await widget.repository.getFacilityPerformance(
        from: _fromStr, to: _toStr,
      );
      if (mounted) setState(() => _facilities = data);
    } catch (e) {
      if (mounted) setState(() => _facilityError = e.toString());
    } finally {
      if (mounted) setState(() => _facilityLoading = false);
    }
  }

  Future<void> _loadIndigent() async {
    setState(() { _indigentLoading = true; _indigentError = null; });
    try {
      final data = await widget.repository.getPendingIndigent();
      if (mounted) setState(() => _indigent = data);
    } catch (e) {
      if (mounted) setState(() => _indigentError = e.toString());
    } finally {
      if (mounted) setState(() => _indigentLoading = false);
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
          : DateTimeRange(
              start: now.subtract(const Duration(days: 30)),
              end: now,
            ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AdminTheme.primary),
        ),
        child: child!,
      ),
    );
    if (range != null && mounted) {
      setState(() { _from = range.start; _to = range.end; });
      _loadAll();
    }
  }

  void _clearDateRange() {
    setState(() { _from = null; _to = null; });
    _loadAll();
  }

  Future<void> _export(String type) async {
    setState(() => _exporting = true);
    try {
      final csv = await widget.repository.exportCsv(
        type: type,
        from: _fromStr,
        to: _toStr,
      );
      if (!mounted) return;
      if (kIsWeb) {
        _showCsvDialog(context, csv,
            'cbhi_${type}_${DateTime.now().toIso8601String().split('T').first}.csv');
      } else {
        final strings = AppLocalizations.of(context);
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Save $type export',
          fileName: 'cbhi_${type}_${DateTime.now().toIso8601String().split('T').first}.csv',
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );
        if (path != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(strings.t('exportedTo', {'path': path})),
            backgroundColor: AdminTheme.success,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AdminTheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final fmt = DateFormat('dd MMM yyyy');
    final hasRange = _from != null && _to != null;

    return Column(
      children: [
        // ── Date range filter bar ─────────────────────────────────────────
        Container(
          color: AdminTheme.cardBgFor(Theme.of(context).brightness),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickDateRange,
                icon: const Icon(Icons.date_range_outlined,
                    size: 16, color: AdminTheme.primary),
                label: Text(
                  hasRange
                      ? '${fmt.format(_from!)} — ${fmt.format(_to!)}'
                      : strings.t('selectDateRange'),
                  style: TextStyle(color: AdminTheme.primary, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AdminTheme.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              if (hasRange) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _clearDateRange,
                  icon: Icon(Icons.close, size: 16,
                      color: AdminTheme.textSecondaryFor(Theme.of(context).brightness)),
                  tooltip: strings.t('clearDateRange'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AdminTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    strings.t('dateRangeActive'),
                    style: TextStyle(
                        color: AdminTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                onPressed: _loadCurrentTab,
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: strings.t('refresh'),
              ),
            ],
          ),
        ),

        // ── Tab bar ───────────────────────────────────────────────────────
        Container(
          color: AdminTheme.cardBgFor(Theme.of(context).brightness),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AdminTheme.primary,
            unselectedLabelColor: AdminTheme.textSecondaryFor(Theme.of(context).brightness),
            indicatorColor: AdminTheme.primary,
            indicatorWeight: 2,
            labelStyle: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: TextStyle(fontSize: 13),
            tabs: const [
              Tab(text: 'Summary'),
              Tab(text: 'Claims Analysis'),
              Tab(text: 'Financial'),
              Tab(text: 'Facility Performance'),
              Tab(text: 'Member Trends'),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Tab views ─────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _SummaryTab(
                loading: _summaryLoading,
                error: _summaryError,
                summary: _summary,
                onRetry: _loadSummary,
                onExport: _exporting ? null : () => _export('households'),
              ),
              _ClaimsTab(
                loading: _claimsLoading,
                error: _claimsError,
                claims: _claims,
                search: _claimsSearch,
                onSearchChanged: (v) => setState(() => _claimsSearch = v),
                onRetry: _loadClaims,
                onExport: _exporting ? null : () => _export('claims'),
              ),
              _FinancialTab(
                loading: _financialLoading,
                error: _financialError,
                financial: _financial,
                onRetry: _loadFinancial,
                onExport: _exporting ? null : () => _export('payments'),
              ),
              _FacilityTab(
                loading: _facilityLoading,
                error: _facilityError,
                facilities: _facilities,
                onRetry: _loadFacilities,
              ),
              _MemberTrendsTab(
                loading: _indigentLoading,
                error: _indigentError,
                indigent: _indigent,
                summary: _summary,
                onRetry: _loadIndigent,
                onExport: _exporting ? null : () => _export('indigent'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Tab: Summary ──────────────────────────────────────────────────────────

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({
    required this.loading,
    required this.error,
    required this.summary,
    required this.onRetry,
    required this.onExport,
  });

  final bool loading;
  final String? error;
  final Map<String, dynamic> summary;
  final VoidCallback onRetry;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: AdminTheme.primary));
    }
    if (error != null) {
      return ErrorStateWidget(message: error!, onRetry: onRetry);
    }

    final households = summary['households'] as int? ?? 0;
    final claims = summary['claims'] as Map? ?? {};
    final payments = summary['payments'] as Map? ?? {};
    final submitted = claims['submitted'] as int? ?? 0;
    final approved = claims['approved'] as int? ?? 0;
    final approvalRate = submitted > 0
        ? ((approved / submitted) * 100).toStringAsFixed(1)
        : '0.0';
    final totalCollected = (payments['totalCollected'] as num? ?? 0).toStringAsFixed(0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI cards row
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _KpiCard(
                label: 'Total Households',
                value: '$households',
                icon: Icons.home_outlined,
                color: AdminTheme.primary,
                trend: null,
              ),
              _KpiCard(
                label: 'Claims Submitted',
                value: '$submitted',
                icon: Icons.receipt_long_outlined,
                color: AdminTheme.accent,
                trend: null,
              ),
              _KpiCard(
                label: 'Claim Approval Rate',
                value: '$approvalRate%',
                icon: Icons.check_circle_outline,
                color: AdminTheme.success,
                trend: null,
              ),
              _KpiCard(
                label: 'Revenue Collected',
                value: '$totalCollected ETB',
                icon: Icons.payments_outlined,
                color: AdminTheme.gold,
                trend: null,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Claims breakdown
          _SectionHeader(title: 'Claims Breakdown'),
          const SizedBox(height: 12),
          _ClaimsBreakdownTable(claims: claims),

          const SizedBox(height: 32),

          // Financial summary
          _SectionHeader(title: 'Financial Summary'),
          const SizedBox(height: 12),
          _FinancialSummaryTable(payments: payments),

          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.download_outlined, size: 16),
            label: const Text('Export Full Report (CSV)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminTheme.primary,
              side: const BorderSide(color: AdminTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.trend,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double? trend; // positive = up, negative = down, null = no trend

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminTheme.cardBgFor(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: (trend! >= 0 ? AdminTheme.success : AdminTheme.error)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trend! >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        size: 12,
                        color: trend! >= 0 ? AdminTheme.success : AdminTheme.error,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${trend!.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: trend! >= 0 ? AdminTheme.success : AdminTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AdminTheme.textSecondaryFor(Theme.of(context).brightness),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AdminTheme.textPrimaryFor(Theme.of(context).brightness),
      ),
    );
  }
}

class _ClaimsBreakdownTable extends StatelessWidget {
  const _ClaimsBreakdownTable({required this.claims});
  final Map claims;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Submitted', claims['submitted'] ?? 0, AdminTheme.textSecondary),
      ('Approved', claims['approved'] ?? 0, AdminTheme.success),
      ('Rejected', claims['rejected'] ?? 0, AdminTheme.error),
      ('Paid', claims['paid'] ?? 0, AdminTheme.primary),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AdminTheme.cardBgFor(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final i = entry.key;
          final (label, value, color) = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: i < rows.length - 1
                  ? Border(bottom: BorderSide(color: Colors.grey.shade100))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Text(label,
                    style: TextStyle(
                        color: AdminTheme.textPrimaryFor(Theme.of(context).brightness), fontSize: 13)),
                const Spacer(),
                Text(
                  '$value',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FinancialSummaryTable extends StatelessWidget {
  const _FinancialSummaryTable({required this.payments});
  final Map payments;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Total Transactions', '${payments['totalTransactions'] ?? 0}'),
      ('Total Collected', '${payments['totalCollected'] ?? 0} ETB'),
      ('Total Approved', '${payments['totalApproved'] ?? 0} ETB'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AdminTheme.cardBgFor(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final i = entry.key;
          final (label, value) = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: i < rows.length - 1
                  ? Border(bottom: BorderSide(color: Colors.grey.shade100))
                  : null,
            ),
            child: Row(
              children: [
                Text(label,
                    style: TextStyle(
                        color: AdminTheme.textSecondaryFor(Theme.of(context).brightness), fontSize: 13)),
                const Spacer(),
                Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AdminTheme.textPrimaryFor(Theme.of(context).brightness))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Tab: Claims Analysis ──────────────────────────────────────────────────

class _ClaimsTab extends StatelessWidget {
  const _ClaimsTab({
    required this.loading,
    required this.error,
    required this.claims,
    required this.search,
    required this.onSearchChanged,
    required this.onRetry,
    required this.onExport,
  });

  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> claims;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRetry;
  final VoidCallback? onExport;

  List<Map<String, dynamic>> get _filtered {
    if (search.isEmpty) return claims;
    final q = search.toLowerCase();
    return claims.where((c) {
      final num = c['claimNumber']?.toString().toLowerCase() ?? '';
      final ben = (c['beneficiary'] as Map?)?['name']?.toString().toLowerCase() ?? '';
      return num.contains(q) || ben.contains(q);
    }).toList();
  }

  Color _statusColor(String status) => switch (status.toUpperCase()) {
        'APPROVED' => AdminTheme.success,
        'REJECTED' => AdminTheme.error,
        'PAID' => AdminTheme.primary,
        'UNDER_REVIEW' => AdminTheme.warning,
        _ => AdminTheme.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: AdminTheme.primary));
    }
    if (error != null) {
      return ErrorStateWidget(message: error!, onRetry: onRetry);
    }

    final filtered = _filtered;
    final statusCounts = <String, int>{};
    for (final c in claims) {
      final s = c['status']?.toString() ?? 'UNKNOWN';
      statusCounts[s] = (statusCounts[s] ?? 0) + 1;
    }

    return Column(
      children: [
        // Search + export bar
        Container(
          color: AdminTheme.cardBgFor(Theme.of(context).brightness),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by claim # or beneficiary...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Status breakdown chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: statusCounts.entries.map((e) {
                      final color = _statusColor(e.key);
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${e.key.replaceAll('_', ' ')}: ${e.value}',
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Export CSV'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminTheme.primary,
                  side: const BorderSide(color: AdminTheme.primary),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Table
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No claims found',
                    style: TextStyle(color: AdminTheme.textSecondaryFor(Theme.of(context).brightness)),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Claim #')),
                          DataColumn(label: Text('Beneficiary')),
                          DataColumn(label: Text('Facility')),
                          DataColumn(label: Text('Claimed (ETB)')),
                          DataColumn(label: Text('Approved (ETB)')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Service Date')),
                        ],
                        rows: filtered.map((c) {
                          final status = c['status']?.toString() ?? '';
                          final color = _statusColor(status);
                          return DataRow(cells: [
                            DataCell(Text(
                              c['claimNumber']?.toString() ?? '—',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 12),
                            )),
                            DataCell(Text(
                              (c['beneficiary'] as Map?)?['name']
                                      ?.toString() ??
                                  '—',
                              style: TextStyle(fontSize: 13),
                            )),
                            DataCell(Text(
                              (c['facility'] as Map?)?['name']?.toString() ??
                                  '—',
                              style: TextStyle(fontSize: 13),
                            )),
                            DataCell(Text(
                              '${c['claimedAmount'] ?? 0}',
                              style: TextStyle(fontSize: 13),
                            )),
                            DataCell(Text(
                              '${c['approvedAmount'] ?? '—'}',
                              style: TextStyle(fontSize: 13),
                            )),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status.replaceAll('_', ' '),
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            )),
                            DataCell(Text(
                              c['serviceDate']?.toString().split('T').first ??
                                  '—',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AdminTheme.textSecondaryFor(Theme.of(context).brightness)),
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Tab: Financial ────────────────────────────────────────────────────────

class _FinancialTab extends StatelessWidget {
  const _FinancialTab({
    required this.loading,
    required this.error,
    required this.financial,
    required this.onRetry,
    required this.onExport,
  });

  final bool loading;
  final String? error;
  final Map<String, dynamic> financial;
  final VoidCallback onRetry;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: AdminTheme.primary));
    }
    if (error != null) {
      return ErrorStateWidget(message: error!, onRetry: onRetry);
    }

    final revenue = (financial['totalRevenue'] as num? ?? 0).toDouble();
    final claimsPaid = (financial['totalClaimsPaid'] as num? ?? 0).toDouble();
    final netPosition = revenue - claimsPaid;
    final isHealthy = netPosition >= 0;
    final approvalRate = financial['claimApprovalRate'];
    final avgClaim = financial['avgClaimAmount'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Net position card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isHealthy
                    ? [const Color(0xFF1B5E20), const Color(0xFF2E7D52)]
                    : [const Color(0xFFB71C1C), const Color(0xFFE53935)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  isHealthy
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Net Position',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        '${netPosition.toStringAsFixed(0)} ETB',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        isHealthy
                            ? 'Scheme is financially healthy'
                            : 'Scheme is in deficit — action required',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // KPI row
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _KpiCard(
                label: 'Total Revenue',
                value: '${revenue.toStringAsFixed(0)} ETB',
                icon: Icons.payments_outlined,
                color: AdminTheme.success,
                trend: null,
              ),
              _KpiCard(
                label: 'Total Claims Paid',
                value: '${claimsPaid.toStringAsFixed(0)} ETB',
                icon: Icons.receipt_long_outlined,
                color: AdminTheme.error,
                trend: null,
              ),
              _KpiCard(
                label: 'Claim Approval Rate',
                value: approvalRate != null
                    ? '${(approvalRate as num).toStringAsFixed(1)}%'
                    : '—',
                icon: Icons.check_circle_outline,
                color: AdminTheme.primary,
                trend: null,
              ),
              _KpiCard(
                label: 'Avg Claim Amount',
                value: avgClaim != null
                    ? '${(avgClaim as num).toStringAsFixed(0)} ETB'
                    : '—',
                icon: Icons.bar_chart_outlined,
                color: AdminTheme.gold,
                trend: null,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Revenue vs Claims bar chart (custom painter)
          _SectionHeader(title: 'Revenue vs Claims Paid'),
          const SizedBox(height: 12),
          Container(
            height: 200,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AdminTheme.cardBgFor(Theme.of(context).brightness),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _RevenueClaimsBar(
              revenue: revenue,
              claimsPaid: claimsPaid,
            ),
          ),

          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.download_outlined, size: 16),
            label: const Text('Export Financial Report (CSV)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminTheme.primary,
              side: const BorderSide(color: AdminTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple horizontal bar chart comparing revenue vs claims paid.
class _RevenueClaimsBar extends StatelessWidget {
  const _RevenueClaimsBar({
    required this.revenue,
    required this.claimsPaid,
  });

  final double revenue;
  final double claimsPaid;

  @override
  Widget build(BuildContext context) {
    final max = [revenue, claimsPaid, 1.0].reduce((a, b) => a > b ? a : b);

    Widget bar(String label, double value, Color color) {
      final fraction = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12, color: AdminTheme.textSecondaryFor(Theme.of(context).brightness))),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (_, constraints) => Stack(
                    children: [
                      Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        height: 28,
                        width: constraints.maxWidth * fraction,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: Text(
                  '${value.toStringAsFixed(0)} ETB',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        bar('Revenue', revenue, AdminTheme.success),
        const SizedBox(height: 20),
        bar('Claims Paid', claimsPaid, AdminTheme.error),
      ],
    );
  }
}

// ── Tab: Facility Performance ─────────────────────────────────────────────

class _FacilityTab extends StatelessWidget {
  const _FacilityTab({
    required this.loading,
    required this.error,
    required this.facilities,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> facilities;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: AdminTheme.primary));
    }
    if (error != null) {
      return ErrorStateWidget(message: error!, onRetry: onRetry);
    }
    if (facilities.isEmpty) {
      return Center(
        child: Text('No facility data available.',
            style: TextStyle(color: AdminTheme.textSecondaryFor(Theme.of(context).brightness))),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Facility')),
              DataColumn(label: Text('Total Claims')),
              DataColumn(label: Text('Approved')),
              DataColumn(label: Text('Approval Rate')),
              DataColumn(label: Text('Avg Claim (ETB)')),
            ],
            rows: facilities.map((f) {
              final total = (f['totalClaims'] as num? ?? 0).toInt();
              final approved = (f['approvedClaims'] as num? ?? 0).toInt();
              final rate = total > 0
                  ? ((approved / total) * 100).toStringAsFixed(1)
                  : '0.0';
              final rateVal = double.tryParse(rate) ?? 0;
              final rateColor = rateVal >= 70
                  ? AdminTheme.success
                  : rateVal >= 40
                      ? AdminTheme.warning
                      : AdminTheme.error;

              return DataRow(cells: [
                DataCell(Text(
                  f['facilityName']?.toString() ??
                      f['name']?.toString() ??
                      '—',
                  style: TextStyle(fontWeight: FontWeight.w600),
                )),
                DataCell(Text('$total')),
                DataCell(Text('$approved')),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: rateColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$rate%',
                    style: TextStyle(
                      color: rateColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                )),
                DataCell(Text(
                  (f['avgClaimAmount'] as num? ?? 0).toStringAsFixed(0),
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Tab: Member Trends ────────────────────────────────────────────────────

class _MemberTrendsTab extends StatelessWidget {
  const _MemberTrendsTab({
    required this.loading,
    required this.error,
    required this.indigent,
    required this.summary,
    required this.onRetry,
    required this.onExport,
  });

  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> indigent;
  final Map<String, dynamic> summary;
  final VoidCallback onRetry;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: AdminTheme.primary));
    }
    if (error != null) {
      return ErrorStateWidget(message: error!, onRetry: onRetry);
    }

    final totalHouseholds = summary['households'] as int? ?? 0;
    final pendingIndigent = indigent.length;
    final approvedIndigent = indigent
        .where((a) => a['status']?.toString() == 'APPROVED')
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _KpiCard(
                label: 'Total Enrolled Households',
                value: '$totalHouseholds',
                icon: Icons.home_outlined,
                color: AdminTheme.primary,
                trend: null,
              ),
              _KpiCard(
                label: 'Indigent Applications',
                value: '$pendingIndigent',
                icon: Icons.volunteer_activism_outlined,
                color: AdminTheme.warning,
                trend: null,
              ),
              _KpiCard(
                label: 'Indigent Approved',
                value: '$approvedIndigent',
                icon: Icons.check_circle_outline,
                color: AdminTheme.success,
                trend: null,
              ),
            ],
          ),

          const SizedBox(height: 32),

          _SectionHeader(title: 'Indigent vs Paying Breakdown'),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AdminTheme.cardBgFor(Theme.of(context).brightness),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _BreakdownRow(
                  label: 'Paying Members',
                  count: totalHouseholds - approvedIndigent,
                  total: totalHouseholds,
                  color: AdminTheme.primary,
                ),
                const SizedBox(height: 16),
                _BreakdownRow(
                  label: 'Indigent (Subsidized)',
                  count: approvedIndigent,
                  total: totalHouseholds,
                  color: AdminTheme.warning,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          if (indigent.isNotEmpty) ...[
            _SectionHeader(title: 'Recent Indigent Applications'),
            const SizedBox(height: 12),
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('User ID')),
                    DataColumn(label: Text('Score')),
                    DataColumn(label: Text('Employment')),
                    DataColumn(label: Text('Family Size')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: indigent.take(10).map((a) {
                    final status = a['status']?.toString() ?? 'PENDING';
                    final statusColor = switch (status) {
                      'APPROVED' => AdminTheme.success,
                      'REJECTED' => AdminTheme.error,
                      _ => AdminTheme.warning,
                    };
                    return DataRow(cells: [
                      DataCell(Text(
                        (a['userId']?.toString() ?? '—').length > 12
                            ? '${a['userId'].toString().substring(0, 12)}…'
                            : a['userId']?.toString() ?? '—',
                        style: TextStyle(
                            fontFamily: 'monospace', fontSize: 11),
                      )),
                      DataCell(Text('${a['score'] ?? 0}')),
                      DataCell(Text(a['employmentStatus']?.toString() ?? '—')),
                      DataCell(Text('${a['familySize'] ?? 0}')),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.download_outlined, size: 16),
            label: const Text('Export Indigent Data (CSV)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminTheme.primary,
              side: const BorderSide(color: AdminTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    final pct = (fraction * 100).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13, color: AdminTheme.textPrimaryFor(Theme.of(context).brightness))),
            const Spacer(),
            Text(
              '$count ($pct%)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (_, constraints) => Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                height: 8,
                width: constraints.maxWidth * fraction,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

void _showCsvDialog(BuildContext context, String csv, String filename) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(filename),
      content: SizedBox(
        width: 600,
        height: 400,
        child: SingleChildScrollView(
          child: SelectableText(
            csv,
            style: TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
