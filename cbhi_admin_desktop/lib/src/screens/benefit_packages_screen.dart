import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../i18n/app_localizations.dart';
import '../theme/admin_theme.dart';
import '../widgets/error_state_widget.dart';

/// Benefit Package Management Screen
/// Allows CBHI officers to define covered services, max claim amounts,
/// co-payment rules, and annual ceilings.
class BenefitPackagesScreen extends StatefulWidget {
  const BenefitPackagesScreen({super.key, required this.repository});
  final AdminRepository repository;

  @override
  State<BenefitPackagesScreen> createState() => _BenefitPackagesScreenState();
}

class _BenefitPackagesScreenState extends State<BenefitPackagesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _packages = [];
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.repository.getBenefitPackages();
      setState(() { _packages = data; _selected = data.isNotEmpty ? data.first : null; });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCreatePackageDialog() async {
    final strings = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final premiumCtrl = TextEditingController(text: '120');
    final ceilingCtrl = TextEditingController(text: '0');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.add_circle_outline, color: AdminTheme.primary),
          const SizedBox(width: 8),
          Text(strings.t('createBenefitPackage')),
        ]),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: strings.t('packageName'), prefixIcon: Icon(Icons.inventory_2_outlined))),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: InputDecoration(labelText: strings.t('description')), maxLines: 2),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: premiumCtrl, decoration: InputDecoration(labelText: strings.t('premiumPerMember'), suffixText: 'ETB'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: ceilingCtrl, decoration: InputDecoration(labelText: strings.t('annualCeiling'), suffixText: 'ETB', hintText: '0 = unlimited'), keyboardType: TextInputType.number)),
              ]),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(strings.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(strings.t('create'))),
        ],
      ),
    );

    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;
    try {
      await widget.repository.createBenefitPackage(
        name: nameCtrl.text.trim(),
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        premiumPerMember: double.tryParse(premiumCtrl.text) ?? 120,
        annualCeiling: double.tryParse(ceilingCtrl.text) ?? 0,
      );
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AdminTheme.error));
    }
  }

  Future<void> _showAddItemDialog(String packageId) async {
    final strings = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final maxCtrl = TextEditingController(text: '0');
    final coPayCtrl = TextEditingController(text: '0');
    final maxPerYearCtrl = TextEditingController(text: '0');
    String category = 'outpatient';

    final categories = ['outpatient', 'inpatient', 'pharmacy', 'lab', 'surgery', 'maternal', 'emergency', 'other'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(children: [
            Icon(Icons.medical_services_outlined, color: AdminTheme.primary),
            const SizedBox(width: 8),
            Text(strings.t('addServiceItem')),
          ]),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: nameCtrl, decoration: InputDecoration(labelText: strings.t('serviceName'), prefixIcon: Icon(Icons.local_hospital_outlined))),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: codeCtrl, decoration: InputDecoration(labelText: strings.t('serviceCode'), hintText: 'e.g. OPD-001'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: InputDecoration(labelText: strings.t('category')),
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase()))).toList(),
                      onChanged: (v) => setS(() => category = v ?? category),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: maxCtrl, decoration: InputDecoration(labelText: strings.t('maxClaimAmount'), suffixText: 'ETB', hintText: '0 = no limit'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: coPayCtrl, decoration: InputDecoration(labelText: strings.t('coPaymentPercent'), suffixText: '%'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: maxPerYearCtrl, decoration: InputDecoration(labelText: strings.t('maxPerYear'), hintText: '0 = unlimited'), keyboardType: TextInputType.number)),
                ]),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(strings.t('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(strings.t('addItem'))),
          ],
        ),
      ),
    );

    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;
    try {
      await widget.repository.addBenefitItem(
        packageId: packageId,
        serviceName: nameCtrl.text.trim(),
        serviceCode: codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
        category: category,
        maxClaimAmount: double.tryParse(maxCtrl.text) ?? 0,
        coPaymentPercent: int.tryParse(coPayCtrl.text) ?? 0,
        maxClaimsPerYear: int.tryParse(maxPerYearCtrl.text) ?? 0,
      );
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AdminTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator(color: AdminTheme.primary));
    if (_error != null) return ErrorStateWidget(message: _error!, onRetry: _load);

    return Row(
      children: [
        // Package list sidebar
        SizedBox(
          width: 280,
          child: Container(
            color: AdminTheme.cardBgFor(Theme.of(context).brightness),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AdminTheme.primary.withValues(alpha: 0.04),
                  child: Row(
                    children: [
                      Text(strings.t('benefitPackages'), style: TextStyle(fontWeight: FontWeight.w700, color: AdminTheme.textPrimaryFor(Theme.of(context).brightness))),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.add, color: AdminTheme.primary),
                        tooltip: strings.t('createBenefitPackage'),
                        onPressed: _showCreatePackageDialog,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _packages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 48, color: AdminTheme.textSecondaryFor(Theme.of(context).brightness)),
                              const SizedBox(height: 12),
                              Text(strings.t('noPackagesYet'), style: TextStyle(color: AdminTheme.textSecondaryFor(Theme.of(context).brightness))),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _showCreatePackageDialog,
                                icon: Icon(Icons.add, size: 16),
                                label: Text(strings.t('createFirst')),
                                style: FilledButton.styleFrom(backgroundColor: AdminTheme.primary),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _packages.length,
                          itemBuilder: (_, i) {
                            final pkg = _packages[i];
                            final isSelected = _selected?['id'] == pkg['id'];
                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: AdminTheme.primary.withValues(alpha: 0.08),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (isSelected ? AdminTheme.primary : AdminTheme.textSecondary).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.inventory_2_outlined, size: 18, color: isSelected ? AdminTheme.primary : AdminTheme.textSecondary),
                              ),
                              title: Text(pkg['name']?.toString() ?? '', style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? AdminTheme.primary : AdminTheme.textDark, fontSize: 13)),
                              subtitle: Text('${pkg['premiumPerMember'] ?? 0} ETB/member', style: TextStyle(fontSize: 11, color: AdminTheme.textSecondaryFor(Theme.of(context).brightness))),
                              trailing: pkg['isActive'] == true
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: AdminTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                      child: const Text('ACTIVE', style: TextStyle(color: AdminTheme.success, fontSize: 10, fontWeight: FontWeight.w700)),
                                    )
                                  : null,
                              onTap: () => setState(() => _selected = pkg),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),

        const VerticalDivider(width: 1),

        // Package detail
        Expanded(
          child: _selected == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Color(0xFFCCDDD9)),
                      const SizedBox(height: 16),
                      Text(strings.t('selectPackagePrompt'), style: TextStyle(color: AdminTheme.textSecondaryFor(Theme.of(context).brightness), fontSize: 16)),
                    ],
                  ),
                )
              : _PackageDetail(
                  package: _selected!,
                  onAddItem: () => _showAddItemDialog(_selected!['id'].toString()),
                  onRefresh: _load,
                  repository: widget.repository,
                ),
        ),
      ],
    );
  }
}

class _PackageDetail extends StatelessWidget {
  const _PackageDetail({
    required this.package,
    required this.onAddItem,
    required this.onRefresh,
    required this.repository,
  });

  final Map<String, dynamic> package;
  final VoidCallback onAddItem;
  final VoidCallback onRefresh;
  final AdminRepository repository;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final items = (package['items'] as List? ?? []).cast<Map<String, dynamic>>();

    final categoryColors = <String, Color>{
      'outpatient': AdminTheme.primary,
      'inpatient': const Color(0xFF7B1FA2),
      'pharmacy': AdminTheme.accent,
      'lab': AdminTheme.warning,
      'surgery': AdminTheme.error,
      'maternal': const Color(0xFFE91E63),
      'emergency': const Color(0xFFFF5722),
      'other': AdminTheme.textSecondary,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Package header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0D7A5F), Color(0xFF00BFA5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.inventory_2_outlined, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(package['name']?.toString() ?? '', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                      if ((package['description']?.toString() ?? '').isNotEmpty)
                        Text(package['description'].toString(), style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${package['premiumPerMember'] ?? 0} ETB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                    Text(strings.t('perMemberPerYear'), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Stats row
          Row(
            children: [
              _StatChip(label: strings.t('coveredServices'), value: '${items.where((i) => i['isCovered'] == true).length}', color: AdminTheme.success),
              const SizedBox(width: 12),
              _StatChip(label: strings.t('annualCeiling'), value: (package['annualCeiling'] as num? ?? 0) == 0 ? strings.t('unlimited') : '${package['annualCeiling']} ETB', color: AdminTheme.primary),
              const SizedBox(width: 12),
              _StatChip(label: strings.t('totalItems'), value: '${items.length}', color: AdminTheme.warning),
            ],
          ),

          const SizedBox(height: 24),

          // Items header
          Row(
            children: [
              Text(strings.t('coveredServices'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AdminTheme.textPrimaryFor(Theme.of(context).brightness))),
              const Spacer(),
              FilledButton.icon(
                onPressed: onAddItem,
                icon: Icon(Icons.add, size: 16),
                label: Text(strings.t('addService')),
                style: FilledButton.styleFrom(backgroundColor: AdminTheme.primary, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: AdminTheme.cardBgFor(Theme.of(context).brightness), borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? AdminTheme.darkBorder : Colors.grey.shade200)),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.medical_services_outlined, size: 48, color: AdminTheme.textSecondaryFor(Theme.of(context).brightness)),
                    const SizedBox(height: 12),
                    Text(strings.t('noServicesYet'), style: TextStyle(color: AdminTheme.textSecondaryFor(Theme.of(context).brightness))),
                    const SizedBox(height: 8),
                    Text(strings.t('addServicesHint'), style: TextStyle(color: AdminTheme.textSecondaryFor(Theme.of(context).brightness), fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            ...items.map((item) {
              final category = item['category']?.toString() ?? 'other';
              final color = categoryColors[category] ?? AdminTheme.textSecondary;
              final maxAmount = (item['maxClaimAmount'] as num? ?? 0);
              final coPay = (item['coPaymentPercent'] as num? ?? 0);
              final maxPerYear = (item['maxClaimsPerYear'] as num? ?? 0);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AdminTheme.cardBgFor(Theme.of(context).brightness),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.medical_services_outlined, color: color, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(item['serviceName']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: AdminTheme.textPrimaryFor(Theme.of(context).brightness), fontSize: 14)),
                              const SizedBox(width: 8),
                              if ((item['serviceCode']?.toString() ?? '').isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                                  child: Text(item['serviceCode'].toString(), style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: AdminTheme.textSecondaryFor(Theme.of(context).brightness))),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            children: [
                              _InfoTag(label: category.toUpperCase(), color: color),
                              if (maxAmount > 0) _InfoTag(label: 'Max: $maxAmount ETB', color: AdminTheme.warning),
                              if (coPay > 0) _InfoTag(label: 'Co-pay: $coPay%', color: AdminTheme.primary),
                              if (maxPerYear > 0) _InfoTag(label: 'Max $maxPerYear/yr', color: AdminTheme.textSecondaryFor(Theme.of(context).brightness)),
                              if (maxAmount == 0 && coPay == 0) _InfoTag(label: strings.t('fullyCovered'), color: AdminTheme.success),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: item['isCovered'] == true,
                      onChanged: (v) async {
                        try {
                          await repository.updateBenefitItem(item['id'].toString(), isCovered: v);
                          onRefresh();
                        } catch (_) {}
                      },
                      activeThumbColor: AdminTheme.success,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: AdminTheme.textSecondaryFor(Theme.of(context).brightness))),
        ],
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  const _InfoTag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
