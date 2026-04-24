import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../i18n/app_localizations.dart';
import '../theme/admin_theme.dart';
import '../widgets/error_state_widget.dart';

class FacilitiesScreen extends StatefulWidget {
  const FacilitiesScreen({super.key, required this.repository});
  final AdminRepository repository;

  @override
  State<FacilitiesScreen> createState() => _FacilitiesScreenState();
}

class _FacilitiesScreenState extends State<FacilitiesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _facilities = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.repository.listFacilities();
      setState(() => _facilities = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCreateDialog() async {
    final strings = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final levelCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.t('addFacility')),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl,
                    decoration: InputDecoration(labelText: strings.t('facilityName'))),
                const SizedBox(height: 10),
                TextField(controller: codeCtrl,
                    decoration: InputDecoration(labelText: strings.t('facilityCode'))),
                const SizedBox(height: 10),
                TextField(controller: levelCtrl,
                    decoration: InputDecoration(labelText: strings.t('serviceLevel'))),
                const SizedBox(height: 10),
                TextField(controller: phoneCtrl,
                    decoration: InputDecoration(labelText: strings.t('phoneNumber'))),
                const SizedBox(height: 10),
                TextField(controller: addressCtrl,
                    decoration: InputDecoration(labelText: strings.t('address'))),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(strings.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(strings.t('create'))),
        ],
      ),
    );

    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;
    try {
      await widget.repository.createFacility(
        name: nameCtrl.text.trim(),
        facilityCode: codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
        serviceLevel: levelCtrl.text.trim().isEmpty ? null : levelCtrl.text.trim(),
        phoneNumber: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
        addressLine: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AdminTheme.error),
        );
      }
    }
  }

  Future<void> _showAddStaffDialog(String facilityId) async {
    final strings = AppLocalizations.of(context);
    final identifierCtrl = TextEditingController();
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.t('addStaff')),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: identifierCtrl,
                  decoration: InputDecoration(labelText: strings.t('emailOrPhone'))),
              const SizedBox(height: 10),
              TextField(controller: firstNameCtrl,
                  decoration: InputDecoration(labelText: strings.t('firstName'))),
              const SizedBox(height: 10),
              TextField(controller: lastNameCtrl,
                  decoration: InputDecoration(labelText: strings.t('lastName'))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(strings.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(strings.t('addStaff'))),
        ],
      ),
    );

    if (confirmed != true || identifierCtrl.text.trim().isEmpty) return;
    try {
      await widget.repository.addFacilityStaff(
        facilityId: facilityId,
        identifier: identifierCtrl.text.trim(),
        firstName: firstNameCtrl.text.trim().isEmpty ? null : firstNameCtrl.text.trim(),
        lastName: lastNameCtrl.text.trim().isEmpty ? null : lastNameCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.t('staffAdded')),
              backgroundColor: AdminTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AdminTheme.error),
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
              Text(strings.t('healthFacilities'),
                  style: const TextStyle(fontWeight: FontWeight.w600,
                      color: AdminTheme.textDark)),
              if (!_loading)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AdminTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${_facilities.length}',
                        style: const TextStyle(color: AdminTheme.primary,
                            fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                ),
              const Spacer(),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh),
                  tooltip: strings.t('refresh')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add, size: 18),
                label: Text(strings.t('addFacility')),
                style: FilledButton.styleFrom(backgroundColor: AdminTheme.primary),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AdminTheme.primary))
              : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : _facilities.isEmpty
              ? Center(child: Text(strings.t('noFacilitiesFound')))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 1100) {
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _facilities.length,
                        itemBuilder: (_, i) => _FacilityCard(
                          facility: _facilities[i],
                          strings: strings,
                          onAddStaff: () => _showAddStaffDialog(_facilities[i]['id'].toString()),
                        ),
                      );
                    }
                    return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text(strings.t('facilityName'))),
                          DataColumn(label: Text(strings.t('facilityCode'))),
                          DataColumn(label: Text(strings.t('serviceLevel'))),
                          DataColumn(label: Text(strings.t('phoneNumber'))),
                          DataColumn(label: Text(strings.t('staffCount'))),
                          DataColumn(label: Text(strings.t('accredited'))),
                          DataColumn(label: Text(strings.t('actions'))),
                        ],
                        rows: _facilities.map((f) {
                          final isAccredited = f['isAccredited'] == true;
                          return DataRow(cells: [
                            DataCell(Text(f['name']?.toString() ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(Text(f['facilityCode']?.toString() ?? '—')),
                            DataCell(Text(f['serviceLevel']?.toString() ?? '—')),
                            DataCell(Text(f['phoneNumber']?.toString() ?? '—')),
                            DataCell(Text('${f['staffCount'] ?? 0}')),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isAccredited ? AdminTheme.success : AdminTheme.error)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isAccredited ? strings.t('yes') : strings.t('no'),
                                style: TextStyle(
                                  color: isAccredited ? AdminTheme.success : AdminTheme.error,
                                  fontWeight: FontWeight.w700, fontSize: 11,
                                ),
                              ),
                            )),
                            DataCell(TextButton.icon(
                              onPressed: () => _showAddStaffDialog(f['id'].toString()),
                              icon: const Icon(Icons.person_add_outlined, size: 16),
                              label: Text(strings.t('addStaff')),
                              style: TextButton.styleFrom(foregroundColor: AdminTheme.primary),
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                  );
                  },
                ),
        ),
      ],
    );
  }
}

class _FacilityCard extends StatelessWidget {
  const _FacilityCard({
    required this.facility,
    required this.strings,
    required this.onAddStaff,
  });
  final Map<String, dynamic> facility;
  final AppLocalizations strings;
  final VoidCallback onAddStaff;

  @override
  Widget build(BuildContext context) {
    final isAccredited = facility['isAccredited'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    facility['name']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isAccredited ? AdminTheme.success : AdminTheme.error)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isAccredited ? strings.t('accredited') : strings.t('no'),
                    style: TextStyle(
                      color: isAccredited ? AdminTheme.success : AdminTheme.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${strings.t('facilityCode')}: ${facility['facilityCode'] ?? '—'}',
                style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13)),
            Text('${strings.t('serviceLevel')}: ${facility['serviceLevel'] ?? '—'}',
                style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13)),
            Text('${strings.t('staffCount')}: ${facility['staffCount'] ?? 0}',
                style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onAddStaff,
              icon: const Icon(Icons.person_add_outlined, size: 16),
              label: Text(strings.t('addStaff')),
              style: TextButton.styleFrom(foregroundColor: AdminTheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
