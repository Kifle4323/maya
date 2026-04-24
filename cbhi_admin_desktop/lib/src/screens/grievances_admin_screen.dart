import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../i18n/app_localizations.dart';
import '../theme/admin_theme.dart';
import '../widgets/error_state_widget.dart';
import '../widgets/status_chip.dart';

/// Admin Grievance Management Screen — view, assign, and resolve member grievances.
class GrievancesAdminScreen extends StatefulWidget {
  const GrievancesAdminScreen({super.key, required this.repository});
  final AdminRepository repository;

  @override
  State<GrievancesAdminScreen> createState() => _GrievancesAdminScreenState();
}

class _GrievancesAdminScreenState extends State<GrievancesAdminScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _grievances = [];
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.repository.getAllGrievances(
        status: _statusFilter == 'ALL' ? null : _statusFilter,
      );
      setState(() => _grievances = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolve(Map<String, dynamic> grievance) async {
    final strings = AppLocalizations.of(context);
    final resolutionCtrl = TextEditingController();
    String newStatus = 'RESOLVED';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.gavel_outlined, color: AdminTheme.primary),
            const SizedBox(width: 8),
            Text(strings.t('resolveGrievance')),
          ]),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AdminTheme.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(grievance['subject']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(grievance['description']?.toString() ?? '', style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 12), maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: newStatus,
                  decoration: InputDecoration(labelText: strings.t('newStatus')),
                  items: ['UNDER_REVIEW', 'RESOLVED', 'CLOSED'].map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ')))).toList(),
                  onChanged: (v) => setS(() => newStatus = v ?? newStatus),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: resolutionCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: strings.t('resolutionNote'),
                    hintText: strings.t('resolutionNoteHint'),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(strings.t('cancel'))),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AdminTheme.primary),
              child: Text(strings.t('save')),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    try {
      await widget.repository.updateGrievance(
        grievanceId: grievance['id'].toString(),
        status: newStatus,
        resolution: resolutionCtrl.text.trim().isEmpty ? null : resolutionCtrl.text.trim(),
      );
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.t('grievanceUpdated')), backgroundColor: AdminTheme.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AdminTheme.error));
    }
  }

  Color _typeColor(String type) => switch (type.toUpperCase()) {
    'CLAIM_REJECTION' => AdminTheme.error,
    'FACILITY_DENIAL' => AdminTheme.warning,
    'PAYMENT_ISSUE' => AdminTheme.gold,
    'INDIGENT_REJECTION' => AdminTheme.accent,
    _ => AdminTheme.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final statuses = ['ALL', 'OPEN', 'UNDER_REVIEW', 'RESOLVED', 'CLOSED'];
    final openCount = _grievances.where((g) => g['status'] == 'OPEN').length;

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Text(strings.t('memberGrievances'), style: const TextStyle(fontWeight: FontWeight.w600, color: AdminTheme.textDark)),
              if (openCount > 0) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AdminTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text('$openCount open', style: const TextStyle(color: AdminTheme.error, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
              const SizedBox(width: 16),
              Wrap(
                spacing: 6,
                children: statuses.map((s) => FilterChip(
                  label: Text(s == 'ALL' ? strings.t('statusAll') : s.replaceAll('_', ' '), style: const TextStyle(fontSize: 11)),
                  selected: _statusFilter == s,
                  onSelected: (_) { setState(() => _statusFilter = s); _load(); },
                  selectedColor: AdminTheme.primary.withValues(alpha: 0.15),
                  checkmarkColor: AdminTheme.primary,
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
              const Spacer(),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: strings.t('refresh')),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AdminTheme.primary))
              : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : _grievances.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sentiment_satisfied_outlined, size: 64, color: AdminTheme.success),
                      const SizedBox(height: 16),
                      Text(strings.t('noGrievancesAdmin'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      Text(strings.t('noGrievancesAdminSubtitle'), style: const TextStyle(color: AdminTheme.textSecondary)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: _grievances.map((g) {
                      final status = g['status']?.toString() ?? 'OPEN';
                      final type = g['type']?.toString() ?? 'OTHER';
                      final typeColor = _typeColor(type);
                      final isOpen = status == 'OPEN' || status == 'UNDER_REVIEW';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isOpen ? AdminTheme.warning.withValues(alpha: 0.3) : Colors.grey.shade100),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                                  child: Text(type.replaceAll('_', ' '), style: TextStyle(color: typeColor, fontWeight: FontWeight.w700, fontSize: 11)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(g['subject']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, color: AdminTheme.textDark))),
                                StatusChip(status: status),
                                if (isOpen) ...[
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    onPressed: () => _resolve(g),
                                    icon: const Icon(Icons.gavel_outlined, size: 14),
                                    label: Text(strings.t('resolve')),
                                    style: FilledButton.styleFrom(backgroundColor: AdminTheme.primary, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(g['description']?.toString() ?? '', style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 14, color: AdminTheme.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  (g['submittedBy'] as Map?)?['name']?.toString() ?? '—',
                                  style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 12),
                                ),
                                const SizedBox(width: 16),
                                const Icon(Icons.schedule_outlined, size: 14, color: AdminTheme.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  g['createdAt']?.toString().split('T').first ?? '—',
                                  style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 12),
                                ),
                                if ((g['referenceId']?.toString() ?? '').isNotEmpty) ...[
                                  const SizedBox(width: 16),
                                  const Icon(Icons.tag_outlined, size: 14, color: AdminTheme.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(g['referenceId'].toString(), style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 12, fontFamily: 'monospace')),
                                ],
                              ],
                            ),
                            if ((g['resolution']?.toString() ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: AdminTheme.success.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, color: AdminTheme.success, size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(g['resolution'].toString(), style: const TextStyle(color: AdminTheme.success, fontSize: 12))),
                                  ],
                                ),
                              ),
                            ],
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
