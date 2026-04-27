import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';

/// A shimmer-effect skeleton placeholder for loading states.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppTheme.radiusS,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final shimmerBase = Theme.of(context).colorScheme.surfaceContainerHigh;
    final shimmerHighlight = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: shimmerBase,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1200.ms, color: shimmerHighlight);
  }
}

/// Skeleton for a metric card (2×2 grid on dashboard)
class SkeletonMetricCard extends StatelessWidget {
  const SkeletonMetricCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 80, height: 12),
          SizedBox(height: 10),
          SkeletonBox(width: 120, height: 24, borderRadius: 6),
          SizedBox(height: 8),
          SkeletonBox(width: 40, height: 12),
        ],
      ),
    );
  }
}

/// Skeleton for a list item card
class SkeletonListCard extends StatelessWidget {
  const SkeletonListCard({super.key});

  @override
  Widget build(BuildContext context) {
    final shimmerBase = Theme.of(context).colorScheme.surfaceContainerHigh;
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Row(
        children: [
          Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: shimmerBase,
                  shape: BoxShape.circle,
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .shimmer(duration: 1200.ms, color: Theme.of(context).colorScheme.surfaceContainerHighest),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 14),
                SizedBox(height: 8),
                SkeletonBox(width: 160, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full dashboard skeleton
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final shimmerBase = Theme.of(context).colorScheme.surfaceContainerHigh;
    final shimmerHighlight = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      children: [
        // Hero card skeleton
        Container(
              height: 100,
              decoration: BoxDecoration(
                color: shimmerBase,
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .shimmer(duration: 1200.ms, color: shimmerHighlight),

        const SizedBox(height: 16),

        // Metric cards
        const Row(
          children: [
            Expanded(child: SkeletonMetricCard()),
            SizedBox(width: 12),
            Expanded(child: SkeletonMetricCard()),
          ],
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(child: SkeletonMetricCard()),
            SizedBox(width: 12),
            Expanded(child: SkeletonMetricCard()),
          ],
        ),

        const SizedBox(height: 20),

        // List items
        const SkeletonListCard(),
        const SkeletonListCard(),
        const SkeletonListCard(),
      ],
    );
  }
}

/// Family list skeleton
class FamilyListSkeleton extends StatelessWidget {
  const FamilyListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final shimmerBase = Theme.of(context).colorScheme.surfaceContainerHigh;
    final shimmerHighlight = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      children: List.generate(
        4,
        (_) => Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            boxShadow: AppTheme.subtleShadow,
          ),
          child: Row(
            children: [
              Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: shimmerBase,
                      shape: BoxShape.circle,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .shimmer(duration: 1200.ms, color: shimmerHighlight),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 16),
                    SizedBox(height: 8),
                    SkeletonBox(width: 120, height: 12),
                    SizedBox(height: 6),
                    SkeletonBox(width: 80, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
