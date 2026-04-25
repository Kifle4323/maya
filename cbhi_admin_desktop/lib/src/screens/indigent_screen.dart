import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../i18n/app_localizations.dart';
import '../theme/admin_theme.dart';
import '../widgets/error_state_widget.dart';
import '../widgets/status_chip.dart';

class IndigentScreen extends StatefulWidget {
  const IndigentScreen({super.key, required this.repository});
  final AdminRepository repository;

  @override
  State<IndigentScreen> createState() => _IndigentScreenState();
}

class _IndigentScreenState extends State<IndigentScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _applications = [];

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
      final apps = await widget.repository.getPendingIndigent();
      setState(() => _applications = apps);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(Map<String, dynamic> app, String status) async {
    final strings = AppLocalizations.of(context);
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          strings.t('reviewIndigentTitle', {
            'action': strings.t(status == 'APPROVED' ? 'approve' : 'reject'),
          }),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.t('userIdValue', {
                  'userId':
                      app['userId']?.toString() ?? strings.t('notAvailable'),
                }),
              ),
              Text(
                strings.t('scoreValue', {
                  'score': app['score']?.toString() ?? '0',
                }),
              ),
              Text(
                strings.t('employmentValue', {
                  'employment':
                      app['employmentStatus']?.toString() ??
                      strings.t('notAvailable'),
                }),
              ),
              Text(
                strings.t('familySizeValue', {
                  'size': app['familySize']?.toString() ?? '0',
                }),
              ),
              const Divider(height: 24),
              Text(
                strings.t('visionValidationResults'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              if (app['documentMeta'] != null && (app['documentMeta'] as List).isNotEmpty)
                ...((app['documentMeta'] as List).map((meta) {
                  final isExp = meta['isExpired'] == true;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isExp ? AdminTheme.error.withValues(alpha: 0.05) : AdminTheme.success.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: isExp ? AdminTheme.error.withValues(alpha: 0.2) : AdminTheme.success.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(isExp ? Icons.error_outline : Icons.check_circle_outline, size: 14, color: isExp ? AdminTheme.error : AdminTheme.success),
                            const SizedBox(width: 4),
                            Text(
                              meta['documentType']?.toString() ?? 'Unknown Doc',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isExp ? AdminTheme.error : AdminTheme.success),
                            ),
                          ],
                        ),
                        if (meta['detectedDate'] != null)
                          Text('Issued: ${meta['detectedDate']}', style: const TextStyle(fontSize: 11)),
                        if (meta['validationSummary'] != null)
                          Text(meta['validationSummary']!, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  );
                }))
              else
                Text(strings.t('noVisionDataAvailable'), style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                decoration: InputDecoration(
                  labelText: strings.t('overrideReason'),
                  hintText: strings.t('explainWhyOverriding'),
                ),
                maxLines: 2,
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
            child: Text(strings.t(status == 'APPROVED' ? 'approve' : 'reject')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await widget.repository.reviewIndigent(
        applicationId: app['id'].toString(),
        status: status,
        reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
      );
      await _load();
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
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Text(
                strings.t('pendingIndigentApplications'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AdminTheme.textDark,
                ),
              ),
              const SizedBox(width: 12),
              if (!_loading)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AdminTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    strings.t('pendingCount', {
                      'count': _applications.length.toString(),
                    }),
                    style: const TextStyle(
                      color: AdminTheme.warning,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
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
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AdminTheme.primary),
                )
              : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : _applications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: AdminTheme.success,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        strings.t('noPendingApplications'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        strings.t('allIndigentProcessed'),
                        style: const TextStyle(color: AdminTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text(strings.t('userId'))),
                          DataColumn(label: Text(strings.t('income'))),
                          DataColumn(label: Text(strings.t('employment'))),
                          DataColumn(label: Text(strings.t('familySize'))),
                          DataColumn(label: Text(strings.t('score'))),
                          DataColumn(label: Text(strings.t('status'))),
                          DataColumn(label: Text(strings.t('actions'))),
                        ],
                        rows: _applications
                            .map(
                              (app) => DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      app['userId']?.toString() ??
                                          strings.t('notAvailable'),
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text('${app['income'] ?? 0}')),
                                  DataCell(
                                    Text(
                                      app['employmentStatus']?.toString() ??
                                          strings.t('notAvailable'),
                                    ),
                                  ),
                                  DataCell(Text('${app['familySize'] ?? 0}')),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (app['score'] as num? ?? 0) >= 70
                                            ? AdminTheme.success.withValues(
                                                alpha: 0.1,
                                              )
                                            : AdminTheme.warning.withValues(
                                                alpha: 0.1,
                                              ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${app['score'] ?? 0}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color:
                                              (app['score'] as num? ?? 0) >= 70
                                              ? AdminTheme.success
                                              : AdminTheme.warning,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    StatusChip(
                                      status:
                                          app['status']?.toString() ??
                                          'PENDING',
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton(
                                          onPressed: () =>
                                              _review(app, 'APPROVED'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: AdminTheme.success,
                                          ),
                                          child: Text(strings.t('approve')),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              _review(app, 'REJECTED'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: AdminTheme.error,
                                          ),
                                          child: Text(strings.t('reject')),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
