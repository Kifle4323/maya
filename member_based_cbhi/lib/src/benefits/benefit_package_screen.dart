import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../cbhi_data.dart';
import '../cbhi_localizations.dart';
import '../shared/animated_widgets.dart';
import '../theme/app_theme.dart';

/// Benefit Package Screen — shows members what services are covered,
/// co-payment rules, and annual limits.
class BenefitPackageScreen extends StatefulWidget {
  const BenefitPackageScreen({super.key, required this.repository});
  final CbhiRepository repository;

  @override
  State<BenefitPackageScreen> createState() => _BenefitPackageScreenState();
}

class _BenefitPackageScreenState extends State<BenefitPackageScreen> {
  bool _loading = true;
  Map<String, dynamic>? _package;
  String? _error;
  String _selectedCategory = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.repository.getActiveBenefitPackage();
      setState(() => _package = data);
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
      appBar: AppBar(title: Text(strings.t('benefitPackageTitle'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error)))
          : _package == null
          ? Center(child: Text(strings.t('noPackageConfigured')))
          : _BenefitPackageBody(package: _package!, selectedCategory: _selectedCategory, onCategoryChanged: (c) => setState(() => _selectedCategory = c)),
    );
  }
}

class _BenefitPackageBody extends StatelessWidget {
  const _BenefitPackageBody({required this.package, required this.selectedCategory, required this.onCategoryChanged});
  final Map<String, dynamic> package;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final items = (package['items'] as List? ?? []).cast<Map<String, dynamic>>();
    final categories = ['ALL', ...{...items.map((i) => i['category']?.toString() ?? 'other')}];

    final filtered = selectedCategory == 'ALL'
        ? items
        : items.where((i) => i['category']?.toString() == selectedCategory).toList();

    final categoryColors = <String, Color>{
      'outpatient': AppTheme.primary,
      'inpatient': const Color(0xFF7B1FA2),
      'pharmacy': AppTheme.accent,
      'lab': AppTheme.warning,
      'surgery': AppTheme.error,
      'maternal': const Color(0xFFE91E63),
      'emergency': const Color(0xFFFF5722),
      'other': AppTheme.textSecondaryFor(Theme.of(context).brightness),
    };

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      children: [
        // Package header card
        Container(
          decoration: BoxDecoration(
            gradient: AppTheme.heroGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.health_and_safety_outlined, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(package['name']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                        if ((package['description']?.toString() ?? '').isNotEmpty)
                          Text(package['description'].toString(), style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _PackageStat(label: strings.t('coveredServices'), value: '${items.where((i) => i['isCovered'] == true).length}', icon: Icons.check_circle_outline),
                  const SizedBox(width: 20),
                  _PackageStat(
                    label: strings.t('annualCeiling'),
                    value: double.tryParse(package['annualCeiling']?.toString() ?? '0') == 0 ? strings.t('unlimited') : '${package['annualCeiling']} ETB',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  const SizedBox(width: 20),
                  _PackageStat(label: strings.t('premiumPerMember'), value: '${package['premiumPerMember'] ?? 0} ETB', icon: Icons.payments_outlined),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),

        const SizedBox(height: 20),

        // Category filter
        Text(strings.t('filterByCategory'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final isSelected = selectedCategory == cat;
              final color = cat == 'ALL' ? AppTheme.primary : (categoryColors[cat] ?? AppTheme.textSecondaryFor(Theme.of(context).brightness));
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onCategoryChanged(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? color : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? color : Colors.grey.shade200),
                      boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))] : null,
                    ),
                    child: Text(
                      cat == 'ALL' ? strings.t('allCategories') : cat.toUpperCase(),
                      style: TextStyle(color: isSelected ? Colors.white : AppTheme.textSecondaryFor(Theme.of(context).brightness), fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, fontSize: 12),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 150.ms),

        const SizedBox(height: 16),

        // Service items
        if (items.isEmpty)
          EmptyState(
            icon: Icons.medical_services_outlined,
            title: strings.t('noServicesConfigured'),
            subtitle: strings.t('noServicesConfiguredSubtitle'),
          )
        else if (filtered.isEmpty)
          EmptyState(
            icon: Icons.medical_services_outlined,
            title: strings.t('noServicesInCategory'),
            subtitle: strings.t('tryDifferentCategory'),
          )
        else
          ...filtered.asMap().entries.map((entry) {
            final item = entry.value;
            final category = item['category']?.toString() ?? 'other';
            final color = categoryColors[category] ?? AppTheme.textSecondaryFor(Theme.of(context).brightness);
            final maxAmount = double.tryParse(item['maxClaimAmount']?.toString() ?? '0') ?? 0;
            final coPay = double.tryParse(item['coPaymentPercent']?.toString() ?? '0') ?? 0;
            final maxPerYear = double.tryParse(item['maxClaimsPerYear']?.toString() ?? '0') ?? 0;
            final isCovered = item['isCovered'] == true;

            return GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isCovered ? color : AppTheme.textSecondaryFor(Theme.of(context).brightness)).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isCovered ? Icons.check_circle_outline : Icons.cancel_outlined,
                      color: isCovered ? color : AppTheme.textSecondaryFor(Theme.of(context).brightness),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(item['serviceName']?.toString() ?? '', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
                            if (!isCovered)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                child: Text(strings.t('notCovered'), style: const TextStyle(color: AppTheme.error, fontSize: 10, fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _ServiceTag(label: category.toUpperCase(), color: color),
                            if (maxAmount > 0) _ServiceTag(label: '${strings.t('maxClaim')}: $maxAmount ETB', color: AppTheme.warning),
                            if (coPay > 0) _ServiceTag(label: '${strings.t('coPay')}: $coPay%', color: AppTheme.primary),
                            if (maxPerYear > 0) _ServiceTag(label: '${strings.t('maxPerYear')}: $maxPerYear', color: AppTheme.textSecondaryFor(Theme.of(context).brightness)),
                            if (maxAmount == 0 && coPay == 0 && isCovered) _ServiceTag(label: strings.t('fullyCovered'), color: AppTheme.success),
                          ],
                        ),
                        if ((item['notes']?.toString() ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(item['notes'].toString(), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0);
          }),

        const SizedBox(height: 24),
      ],
    );
  }
}

class _PackageStat extends StatelessWidget {
  const _PackageStat({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
      ],
    );
  }
}

class _ServiceTag extends StatelessWidget {
  const _ServiceTag({required this.label, required this.color});
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
