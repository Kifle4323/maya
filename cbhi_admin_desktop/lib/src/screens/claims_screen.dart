import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../i18n/app_localizations.dart';
import '../theme/admin_theme.dart';
import '../widgets/status_chip.dart';

class ClaimsScreen extends StatefulWidget {
  const ClaimsScreen({super.key, required this.repository});
  final AdminRepository repository;

  @override
  State<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends State<ClaimsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _claims = [];
  String _filter = 'ALL';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

  List<Map<String, dynamic>> get _filtered {
    var list = _filter == 'ALL'
        ? _claims
        : _claims.where((c) => c['status'] == _filter).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((c) {
        final claimNum = c['claimNumber']?.toString().toLowerCase() ?? '';
        final beneficiary = c['beneficiaryName']?.toString().toLowerCase() ?? '';
        final household = c['householdCode']?.toString().toLowerCase() ?? '';
        return claimNum.contains(q) || beneficiary.contains(q) || household.contains(q);
      }).toList();
    }
    return list;
  }

  Future<void> _review(Map<String, dynamic> claim, String status) async {
    final strings = AppLocalizations.of(context);
    final amountCtrl = TextEditingController(
      text: claim['claimedAmount']?.toString() ?? '',
    );
    final noteCtrl = TextEditingController(
      text: claim['decisionNote']?.toString() ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          strings.t('setClaimTo', {'status': strings.statusLabel(status)}),
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                decoration: InputDecoration(
                  labelText: strings.t('approvedAmount'),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: strings.t('decisionNote'),
                ),
                maxLines: 3,
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
            style: FilledButton.styleFrom(
              backgroundColor: status == 'APPROVED'
                  ? AdminTheme.success
                  : AdminTheme.error,
            ),
            child: Text(strings.statusLabel(status)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.repository.reviewClaim(
        claimId: claim['id'].toString(),
        status: status,
        approvedAmount: double.tryParse(amountCtrl.text.trim()),
        decisionNote: noteCtrl.text.trim().isEmpty
            ? null
            : noteCtrl.text.trim(),
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.t('claimUpdatedTo', {
                'status': strings.statusLabel(status),
              }),
            ),
            backgroundColor: AdminTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AdminTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Column(
      children: [
        // Filter bar
        Container(
          color: AdminTheme.cardBgFor(Theme.of(context).brightness),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              for (final status in [
                'ALL',
                'SUBMITTED',
                'UNDER_REVIEW',
                'APPROVED',
                'REJECTED',
                'PAID',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(strings.statusLabel(status)),
                    selected: _filter == status,
                    onSelected: (_) => setState(() => _filter = status),
                    selectedColor: AdminTheme.primary.withValues(alpha: 0.15),
                    checkmarkColor: AdminTheme.primary,
                    labelStyle: TextStyle(
                      color: _filter == status
                          ? AdminTheme.primary
                          : AdminTheme.textSecondary,
                      fontWeight: _filter == status
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              // Search field
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: strings.t('searchClaimsHint'),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: strings.t('refresh'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Table
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AdminTheme.primary),
                )
              : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AdminTheme.error),
                  ),
                )
              : _filtered.isEmpty
              ? Center(child: Text(strings.t('noClaimsFound')))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text(strings.t('claimNumber'))),
                          DataColumn(label: Text(strings.t('beneficiary'))),
                          DataColumn(label: Text(strings.t('facility'))),
                          DataColumn(label: Text(strings.t('claimedAmount'))),
                          DataColumn(label: Text(strings.t('approvedAmount'))),
                          DataColumn(label: Text(strings.t('status'))),
                          DataColumn(label: Text(strings.t('serviceDate'))),
                          DataColumn(label: Text(strings.t('actions'))),
                        ],
                        rows: _filtered.map((claim) {
                          final status = claim['status']?.toString() ?? '';
                          final isPending =
                              status == 'SUBMITTED' || status == 'UNDER_REVIEW';
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  claim['claimNumber']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  claim['beneficiaryName']?.toString() ??
                                      strings.t('notAvailable'),
                                ),
                              ),
                              DataCell(
                                Text(
                                  claim['facilityName']?.toString() ??
                                      strings.t('notAvailable'),
                                ),
                              ),
                              DataCell(Text('${claim['claimedAmount'] ?? 0}')),
                              DataCell(Text('${claim['approvedAmount'] ?? 0}')),
                              DataCell(StatusChip(status: status)),
                              DataCell(
                                Text(
                                  claim['serviceDate']
                                          ?.toString()
                                          .split('T')
                                          .first ??
                                      strings.t('notAvailable'),
                                ),
                              ),
                              DataCell(
                                isPending
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                _review(claim, 'APPROVED'),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  AdminTheme.success,
                                            ),
                                            child: Text(strings.t('approve')),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                _review(claim, 'REJECTED'),
                                            style: TextButton.styleFrom(
                                              foregroundColor: AdminTheme.error,
                                            ),
                                            child: Text(strings.t('reject')),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        '—',
                                        style: TextStyle(
                                          color: AdminTheme.textSecondaryFor(Theme.of(context).brightness),
                                        ),
                                      ),
                              ),
                            ],
                          );
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
