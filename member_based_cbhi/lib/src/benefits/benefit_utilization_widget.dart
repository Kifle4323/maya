import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';
import '../cbhi_localizations.dart';

/// Benefit Utilization Widget — shows annual benefit limit and used amount.
/// Displayed on the dashboard and profile screens.
class BenefitUtilizationWidget extends StatelessWidget {
  const BenefitUtilizationWidget({
    super.key,
    required this.totalClaimed,
    required this.annualCeiling,
    required this.claimsCount,
  });

  final double totalClaimed;
  final double annualCeiling;
  final int claimsCount;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final hasLimit = annualCeiling > 0;
    final utilizationRate = hasLimit ? (totalClaimed / annualCeiling).clamp(0.0, 1.0) : 0.0;
    final remaining = hasLimit ? (annualCeiling - totalClaimed).clamp(0.0, annualCeiling) : 0.0;

    Color barColor;
    if (!hasLimit) {
      barColor = AppTheme.primary;
    } else if (utilizationRate >= 0.9) {
      barColor = AppTheme.error;
    } else if (utilizationRate >= 0.7) {
      barColor = AppTheme.warning;
    } else {
      barColor = AppTheme.success;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: barColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.bar_chart_outlined, color: barColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(strings.t('benefitUtilization'), style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text('$claimsCount ${strings.t('claims')}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 14),

          // Progress bar
          if (hasLimit) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${totalClaimed.toStringAsFixed(0)} ETB ${strings.t('used')}', style: TextStyle(fontWeight: FontWeight.w700, color: barColor, fontSize: 13)),
                Text('${annualCeiling.toStringAsFixed(0)} ETB ${strings.t('limit')}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: utilizationRate,
                backgroundColor: barColor.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 10,
              ),
            ).animate().scaleX(begin: 0, end: 1, duration: 800.ms, curve: Curves.easeOutCubic),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        Text('${remaining.toStringAsFixed(0)} ETB', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.success, fontSize: 14)),
                        Text(strings.t('remaining'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: barColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        Text('${(utilizationRate * 100).toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.w700, color: barColor, fontSize: 14)),
                        Text(strings.t('utilized'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (utilizationRate >= 0.9)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_outlined, color: AppTheme.warning, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(strings.t('nearingBenefitLimit'), style: const TextStyle(color: AppTheme.warning, fontSize: 12))),
                  ],
                ),
              ),
          ] else ...[
            Row(
              children: [
                Text('${totalClaimed.toStringAsFixed(0)} ETB ${strings.t('totalClaimed')}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary, fontSize: 13)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(strings.t('unlimited'), style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w700, fontSize: 11)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
