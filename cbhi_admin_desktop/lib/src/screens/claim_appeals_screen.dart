import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../i18n/app_localizations.dart';
import '../theme/admin_theme.dart';
import '../widgets/error_state_widget.dart';
import '../widgets/status_chip.dart';

/// Admin Claim Appeals Screen — review and resolve member claim appeals.
class ClaimAppealsScreen extends StatefulWidget {
  const ClaimAppealsScreen({super.key, required this.repository});
  final AdminRepository repository;

  @override
  State<ClaimAppealsScreen> createState() => _ClaimAppealsScreenState();
}

class _ClaimAppealsScreenState extends State<ClaimAppealsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _appeals = [];

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
      final data = await widget.repository.getAllAppeals();
      setState(() => _appeals = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(Map<String, dynamic> appeal) async {
    final strings = AppLocalizations.of(context);
    final noteCtrl = TextEditingController();
    String newStatus = 'APPROVED';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.gavel_outlined, color: AdminTheme.primary),
            const SizedBox(width: 8),
            Text(strings.t('reviewAppeal')),
          ]),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${strings.t('claimNumber')}: ${appeal['claimNumber']?.toString() ?? '—'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appeal['reason']?.toString() ?? '',
                        style: const TextStyle(
                          color: AdminTheme.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: newStatus,
                  decoration: InputDecoration(labelText: strings.t('decision')),
                  items: ['APPROVED', 'REJECTED']
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(strings.statusLabel(s)),
                          ))
                      .toList(),
                  onChanged: (v) => setS(() => newStatus = v ?? newStatus),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: strings.t('reviewNote'),
                    hintText: strings.t('reviewNoteHint'),
                    alignLabelWithHint: true,
                  ),
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
                backgroundColor: newStatus == 'APPROVED'
                    ? AdminTheme.success
                    : AdminTheme.error,
              ),
              child: Text(strings.statusLabel(newStatus)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    try {
      await widget.repository.reviewAppeal(
        appealId: appeal['id'].toString(),
        status: newStatus,
        reviewNote: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.t('appealReviewed')),
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
    final pendingCount =
        _appeals.where((a) => a['status']?.toString() == 'PENDING').length;

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Text(
                strings.t('claimAppeals'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AdminTheme.textDark,
                ),
              ),
              if (pendingCount > 0) ...[
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AdminTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$pendingCount pending',
                    style: const TextStyle(
                      color: AdminTheme.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
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
                  child: CircularProgressIndicator(color: AdminTheme.primary))
              : _error != null
                  ? ErrorStateWidget(message: _error!, onRetry: _load)
                  : _appeals.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  size: 64, color: AdminTheme.success),
                              const SizedBox(height: 16),
                              Text(
                                strings.t('noAppeals'),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                strings.t('noAppealsSubtitle'),
                                style: const TextStyle(
                                    color: AdminTheme.textSecondary),
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
                                  DataColumn(
                                      label: Text(strings.t('claimNumber'))),
                                  DataColumn(
                                      label: Text(strings.t('submittedBy'))),
                                  DataColumn(
                                      label: Text(strings.t('reason'))),
                                  DataColumn(
                                      label: Text(strings.t('status'))),
                                  DataColumn(
                                      label: Text(strings.t('submittedAt'))),
                                  DataColumn(
                                      label: Text(strings.t('actions'))),
                                ],
                                rows: _appeals.map((appeal) {
                                  final status =
                                      appeal['status']?.toString() ?? 'PENDING';
                                  final isPending = status == 'PENDING';
                                  return DataRow(cells: [
                                    DataCell(Text(
                                      appeal['claimNumber']?.toString() ?? '—',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    )),
                                    DataCell(Text(
                                      appeal['submittedBy']?.toString() ?? '—',
                                    )),
                                    DataCell(SizedBox(
                                      width: 240,
                                      child: Text(
                                        appeal['reason']?.toString() ?? '—',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    )),
                                    DataCell(StatusChip(status: status)),
                                    DataCell(Text(
                                      appeal['createdAt']
                                              ?.toString()
                                              .split('T')
                                              .first ??
                                          '—',
                                      style: const TextStyle(fontSize: 12),
                                    )),
                                    DataCell(
                                      isPending
                                          ? FilledButton.icon(
                                              onPressed: () =>
                                                  _review(appeal),
                                              icon: const Icon(
                                                  Icons.gavel_outlined,
                                                  size: 14),
                                              label:
                                                  Text(strings.t('review')),
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    AdminTheme.primary,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8),
                                              ),
                                            )
                                          : Text(
                                              appeal['reviewNote']
                                                      ?.toString() ??
                                                  '—',
                                              style: const TextStyle(
                                                  color:
                                                      AdminTheme.textSecondary,
                                                  fontSize: 12),
                                            ),
                                    ),
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
