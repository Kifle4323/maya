import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../cbhi_data.dart';
import '../cbhi_localizations.dart';
import '../shared/animated_widgets.dart';
import '../theme/app_theme.dart';

/// Grievance submission and tracking screen for members.
/// Members can report issues (facility denial, claim rejection, etc.)
/// and track the resolution status.
class GrievanceScreen extends StatefulWidget {
  const GrievanceScreen({super.key, required this.repository});
  final CbhiRepository repository;

  @override
  State<GrievanceScreen> createState() => _GrievanceScreenState();
}

class _GrievanceScreenState extends State<GrievanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = true;
  List<Map<String, dynamic>> _grievances = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.repository.getMyGrievances();
      setState(() => _grievances = data);
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
      appBar: AppBar(
        title: Text(strings.t('grievancesTitle')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: strings.t('myGrievances')),
            Tab(text: strings.t('submitNew')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: My grievances
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error)))
              : _grievances.isEmpty
              ? _EmptyGrievances(onSubmit: () => _tabController.animateTo(1))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    itemCount: _grievances.length,
                    itemBuilder: (_, i) => _GrievanceCard(
                      grievance: _grievances[i],
                    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),
                  ),
                ),

          // Tab 2: Submit new
          _SubmitGrievanceForm(
            repository: widget.repository,
            onSubmitted: () {
              _tabController.animateTo(0);
              _load();
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyGrievances extends StatelessWidget {
  const _EmptyGrievances({required this.onSubmit});
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inbox_outlined, size: 56, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            Text(strings.t('noGrievancesTitle'), style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(strings.t('noGrievancesSubtitle'), style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.add_comment_outlined),
              label: Text(strings.t('submitGrievance')),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrievanceCard extends StatelessWidget {
  const _GrievanceCard({required this.grievance});
  final Map<String, dynamic> grievance;

  Color _statusColor(String status) => switch (status.toUpperCase()) {
    'RESOLVED' => AppTheme.success,
    'UNDER_REVIEW' => AppTheme.warning,
    'CLOSED' => AppTheme.m3OnSurfaceVariant,
    _ => AppTheme.primary,
  };

  IconData _typeIcon(String type) => switch (type.toUpperCase()) {
    'CLAIM_REJECTION' => Icons.receipt_long_outlined,
    'FACILITY_DENIAL' => Icons.local_hospital_outlined,
    'PAYMENT_ISSUE' => Icons.payments_outlined,
    'INDIGENT_REJECTION' => Icons.volunteer_activism_outlined,
    _ => Icons.help_outline,
  };

  @override
  Widget build(BuildContext context) {
    final status = grievance['status']?.toString() ?? 'OPEN';
    final type = grievance['type']?.toString() ?? 'OTHER';
    final color = _statusColor(status);
    final strings = CbhiLocalizations.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(_typeIcon(type), color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(grievance['subject']?.toString() ?? '', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    Text(strings.enumValue(type), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              StatusBadge(label: strings.enumValue(status), color: color),
            ],
          ),
          const SizedBox(height: 12),
          Text(grievance['description']?.toString() ?? '', style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          if ((grievance['resolution']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 14),
                  const SizedBox(width: 6),
                  Expanded(child: Text(grievance['resolution'].toString(), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.success))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _formatDate(grievance['createdAt']?.toString()),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null) return '';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _SubmitGrievanceForm extends StatefulWidget {
  const _SubmitGrievanceForm({required this.repository, required this.onSubmitted});
  final CbhiRepository repository;
  final VoidCallback onSubmitted;

  @override
  State<_SubmitGrievanceForm> createState() => _SubmitGrievanceFormState();
}

class _SubmitGrievanceFormState extends State<_SubmitGrievanceForm> {
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  String _type = 'OTHER';
  bool _submitting = false;
  String? _error;

  final _typeIcons = [
    ('CLAIM_REJECTION', Icons.receipt_long_outlined),
    ('FACILITY_DENIAL', Icons.local_hospital_outlined),
    ('PAYMENT_ISSUE', Icons.payments_outlined),
    ('INDIGENT_REJECTION', Icons.volunteer_activism_outlined),
    ('ENROLLMENT_ISSUE', Icons.person_add_outlined),
    ('OTHER', Icons.help_outline),
  ];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final strings = CbhiLocalizations.of(context);
    if (_subjectCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      setState(() => _error = strings.t('fillRequiredFields'));
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      await widget.repository.submitGrievance(
        type: _type,
        subject: _subjectCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        referenceId: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      );
      widget.onSubmitted();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(strings.t('grievanceInfoBanner'), style: Theme.of(context).textTheme.bodySmall)),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

          // Type selection
          Text(strings.t('grievanceType'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _typeIcons.map((t) {
              final isSelected = _type == t.$1;
              final label = switch (t.$1) {
                'CLAIM_REJECTION' => strings.t('grievanceTypeClaimRejection'),
                'FACILITY_DENIAL' => strings.t('grievanceTypeFacilityDenial'),
                'PAYMENT_ISSUE' => strings.t('grievanceTypePaymentIssue'),
                'INDIGENT_REJECTION' => strings.t('grievanceTypeIndigentRejection'),
                'ENROLLMENT_ISSUE' => strings.t('grievanceTypeEnrollmentIssue'),
                _ => strings.t('grievanceTypeOther'),
              };
              return GestureDetector(
                onTap: () => setState(() => _type = t.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    border: Border.all(color: isSelected ? AppTheme.primary : Colors.grey.shade200),
                    boxShadow: isSelected ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))] : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.$2, size: 16, color: isSelected ? Colors.white : AppTheme.textSecondaryFor(Theme.of(context).brightness)),
                      const SizedBox(width: 6),
                      Text(label, style: TextStyle(color: isSelected ? Colors.white : AppTheme.textPrimaryFor(Theme.of(context).brightness), fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, fontSize: 13)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

          const SizedBox(height: 20),

          // Subject
          TextField(
            controller: _subjectCtrl,
            decoration: InputDecoration(
              labelText: strings.t('grievanceSubject'),
              hintText: strings.t('grievanceSubjectHint'),
              prefixIcon: const Icon(Icons.title_outlined),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 150.ms),

          const SizedBox(height: 14),

          // Description
          TextField(
            controller: _descCtrl,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: strings.t('grievanceDescription'),
              hintText: strings.t('grievanceDescriptionHint'),
              alignLabelWithHint: true,
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

          const SizedBox(height: 14),

          // Reference ID (optional)
          TextField(
            controller: _refCtrl,
            decoration: InputDecoration(
              labelText: strings.t('referenceId'),
              hintText: strings.t('referenceIdHint'),
              prefixIcon: const Icon(Icons.tag_outlined),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 250.ms),

          const SizedBox(height: 20),

          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppTheme.radiusS)),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13))),
                ],
              ),
            ),

          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_outlined),
            label: Text(strings.t('submitGrievance')),
          ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
