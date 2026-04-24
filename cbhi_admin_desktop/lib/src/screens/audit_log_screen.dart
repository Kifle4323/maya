import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../i18n/app_localizations.dart';
import '../theme/admin_theme.dart';
import '../widgets/error_state_widget.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key, required this.repository});
  final AdminRepository repository;

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _logs = [];
  final _entityTypeCtrl = TextEditingController();
  final _entityIdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _entityTypeCtrl.dispose();
    _entityIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final logs = await widget.repository.getAuditLogs(
        entityType: _entityTypeCtrl.text.trim().isEmpty ? null : _entityTypeCtrl.text.trim(),
        entityId: _entityIdCtrl.text.trim().isEmpty ? null : _entityIdCtrl.text.trim(),
      );
      setState(() => _logs = logs);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _actionColor(String action) => switch (action.toUpperCase()) {
    'CREATE' || 'MEMBER_ADD' => AdminTheme.success,
    'DELETE' || 'MEMBER_REMOVE' => AdminTheme.error,
    'UPDATE' || 'SETTINGS_UPDATE' => AdminTheme.warning,
    'CLAIM_REVIEW' || 'INDIGENT_REVIEW' => AdminTheme.accent,
    'LOGIN' => AdminTheme.primary,
    _ => AdminTheme.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Column(
      children: [
        // Filter bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _entityTypeCtrl,
                  decoration: InputDecoration(
                    labelText: strings.t('entityType'),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _entityIdCtrl,
                  decoration: InputDecoration(
                    labelText: strings.t('entityId'),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.search, size: 16),
                label: Text(strings.t('search')),
                style: FilledButton.styleFrom(backgroundColor: AdminTheme.primary),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  _entityTypeCtrl.clear();
                  _entityIdCtrl.clear();
                  _load();
                },
                child: Text(strings.t('clear')),
              ),
              const Spacer(),
              if (!_loading)
                Text('${_logs.length} ${strings.t('records')}',
                    style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13)),
              const SizedBox(width: 8),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh),
                  tooltip: strings.t('refresh')),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AdminTheme.primary))
              : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : _logs.isEmpty
              ? Center(child: Text(strings.t('noAuditLogsFound')))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text(strings.t('timestamp'))),
                          DataColumn(label: Text(strings.t('action'))),
                          DataColumn(label: Text(strings.t('entityType'))),
                          DataColumn(label: Text(strings.t('entityId'))),
                          DataColumn(label: Text(strings.t('userId'))),
                          DataColumn(label: Text(strings.t('userRole'))),
                          DataColumn(label: Text(strings.t('ipAddress'))),
                        ],
                        rows: _logs.map((log) {
                          final action = log['action']?.toString() ?? '';
                          final color = _actionColor(action);
                          return DataRow(cells: [
                            DataCell(Text(
                              log['createdAt']?.toString().replaceFirst('T', ' ').substring(0, 19) ?? '—',
                              style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                            )),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(action,
                                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
                            )),
                            DataCell(Text(log['entityType']?.toString() ?? '—',
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(
                              (log['entityId']?.toString() ?? '—').length > 12
                                  ? '${(log['entityId']?.toString() ?? '').substring(0, 12)}…'
                                  : log['entityId']?.toString() ?? '—',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                            )),
                            DataCell(Text(
                              (log['userId']?.toString() ?? '—').length > 12
                                  ? '${(log['userId']?.toString() ?? '').substring(0, 12)}…'
                                  : log['userId']?.toString() ?? '—',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                            )),
                            DataCell(Text(log['userRole']?.toString() ?? '—',
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(log['ipAddress']?.toString() ?? '—',
                                style: const TextStyle(fontSize: 12))),
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
