import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cbhi_localizations.dart';
import '../cbhi_state.dart';
import '../theme/app_theme.dart';

/// Full-screen notification inbox — M3 HealthShield redesign.
/// Today/Yesterday category tags, colored icon circles, unread blue dot,
/// Featured Health Insight bento card at bottom.
class NotificationInboxScreen extends StatelessWidget {
  const NotificationInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.m3SurfaceContainerLow,
      appBar: AppBar(
        backgroundColor: AppTheme.m3SurfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          strings.t('allNotifications'),
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.m3OnSurface,
          ),
        ),
        actions: [
          BlocBuilder<AppCubit, AppState>(
            builder: (context, state) {
              final unread = (state.snapshot?.notifications ?? [])
                  .where((n) => n['isRead'] != true)
                  .length;
              if (unread == 0) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: () => _markAllRead(context, state),
                icon: const Icon(Icons.done_all, size: 18,
                    color: AppTheme.m3Primary),
                label: Text(
                  strings.t('markAllRead'),
                  style: const TextStyle(color: AppTheme.m3Primary),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<AppCubit, AppState>(
        builder: (context, state) {
          final notifications = state.snapshot?.notifications ?? [];
          if (state.isLoading) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.m3Primary));
          }
          if (notifications.isEmpty) {
            return _EmptyInbox(
              strings: strings,
              onRefresh: () => context.read<AppCubit>().sync(),
            );
          }

          // Group notifications by date
          final today = <Map<String, dynamic>>[];
          final yesterday = <Map<String, dynamic>>[];
          final older = <Map<String, dynamic>>[];

          final now = DateTime.now();
          for (final n in notifications) {
            final raw = n['createdAt']?.toString() ?? '';
            final dt = DateTime.tryParse(raw);
            if (dt == null) {
              older.add(n);
            } else {
              final diff = now.difference(dt).inDays;
              if (diff == 0) {
                today.add(n);
              } else if (diff == 1) {
                yesterday.add(n);
              } else {
                older.add(n);
              }
            }
          }

          return RefreshIndicator(
            color: AppTheme.m3Primary,
            onRefresh: () => context.read<AppCubit>().sync(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // Page header
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.t('allNotifications'),
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.m3OnSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.t('coverageAlertsHere'),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.m3OnSurfaceVariant,
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 300.ms),

                const SizedBox(height: 20),

                // Today group
                if (today.isNotEmpty) ...[
                  _CategoryTag(label: 'Today'),
                  const SizedBox(height: 8),
                  ...today.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _M3NotificationTile(
                          notification: e.value,
                          isUnread: e.value['isRead'] != true,
                          onTap: e.value['id'] == null
                              ? null
                              : () => context
                                  .read<AppCubit>()
                                  .markNotificationRead(
                                      e.value['id'].toString()),
                        ).animate().fadeIn(
                              duration: 300.ms,
                              delay: Duration(milliseconds: e.key * 50),
                            ),
                      )),
                  const SizedBox(height: 8),
                ],

                // Yesterday group
                if (yesterday.isNotEmpty) ...[
                  _CategoryTag(label: 'Yesterday'),
                  const SizedBox(height: 8),
                  ...yesterday.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _M3NotificationTile(
                          notification: e.value,
                          isUnread: false,
                          onTap: e.value['id'] == null
                              ? null
                              : () => context
                                  .read<AppCubit>()
                                  .markNotificationRead(
                                      e.value['id'].toString()),
                        ).animate().fadeIn(
                              duration: 300.ms,
                              delay: Duration(milliseconds: e.key * 50),
                            ),
                      )),
                  const SizedBox(height: 8),
                ],

                // Older group
                if (older.isNotEmpty) ...[
                  _CategoryTag(label: 'Earlier'),
                  const SizedBox(height: 8),
                  ...older.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _M3NotificationTile(
                          notification: e.value,
                          isUnread: false,
                          onTap: e.value['id'] == null
                              ? null
                              : () => context
                                  .read<AppCubit>()
                                  .markNotificationRead(
                                      e.value['id'].toString()),
                        ).animate().fadeIn(
                              duration: 300.ms,
                              delay: Duration(milliseconds: e.key * 50),
                            ),
                      )),
                  const SizedBox(height: 8),
                ],

                // Featured Health Insight bento card
                const SizedBox(height: 16),
                _HealthInsightCard()
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 200.ms),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _markAllRead(BuildContext context, AppState state) async {
    final cubit = context.read<AppCubit>();
    final unread = (state.snapshot?.notifications ?? [])
        .where((n) => n['isRead'] != true && n['id'] != null)
        .toList();
    for (final n in unread) {
      await cubit.markNotificationRead(n['id'].toString());
    }
  }
}

// ── Category Tag ──────────────────────────────────────────────────────────────

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.m3SecondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppTheme.m3OnSecondaryContainer,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

// ── M3 Notification Tile ──────────────────────────────────────────────────────

class _M3NotificationTile extends StatelessWidget {
  const _M3NotificationTile({
    required this.notification,
    required this.isUnread,
    this.onTap,
  });

  final Map<String, dynamic> notification;
  final bool isUnread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = notification['type']?.toString() ?? '';
    final title = notification['title']?.toString() ?? '';
    final message = notification['message']?.toString() ?? '';
    final createdAt = notification['createdAt']?.toString() ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isUnread
              ? AppTheme.m3SurfaceContainerLow
              : AppTheme.m3SurfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread
                ? AppTheme.m3OutlineVariant.withValues(alpha: 0.5)
                : AppTheme.m3OutlineVariant.withValues(alpha: 0.3),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon circle with optional unread dot
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _iconBg(type),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _iconData(type),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                if (isUnread)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.m3Primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.m3SurfaceContainerLow,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isUnread
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: AppTheme.m3OnSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.m3OnSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      color: isUnread
                          ? AppTheme.m3OnSurface
                          : AppTheme.m3OnSurfaceVariant,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _iconBg(String type) {
    switch (type) {
      case 'CLAIM_UPDATE':
        return AppTheme.m3TertiaryContainer;
      case 'PAYMENT_CONFIRMATION':
        return AppTheme.m3PrimaryContainer;
      case 'RENEWAL_REMINDER':
        return const Color(0xFFF57C00);
      case 'SYSTEM_ALERT':
        return AppTheme.m3Primary;
      default:
        return AppTheme.m3PrimaryContainer;
    }
  }

  IconData _iconData(String type) {
    switch (type) {
      case 'CLAIM_UPDATE':
        return Icons.receipt_long_outlined;
      case 'PAYMENT_CONFIRMATION':
        return Icons.payments_outlined;
      case 'RENEWAL_REMINDER':
        return Icons.autorenew_outlined;
      case 'SYSTEM_ALERT':
        return Icons.lock_reset_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ── Health Insight Bento Card ─────────────────────────────────────────────────

class _HealthInsightCard extends StatelessWidget {
  const _HealthInsightCard();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main insight card
        Expanded(
          flex: 2,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.m3PrimaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'HEALTH UPDATE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.m3PrimaryFixed,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your quarterly wellness checkup is due',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.m3OnPrimaryContainer,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Schedule Now',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.m3Primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Vitals card
        Expanded(
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.m3SurfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFA0F2E1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_outline,
                    color: AppTheme.m3Tertiary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Stable Vitals',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.m3OnSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sync your device to get real-time health alerts.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.m3OnSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Empty Inbox ───────────────────────────────────────────────────────────────

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox({required this.strings, this.onRefresh});
  final dynamic strings;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.m3Primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_outlined,
              size: 48,
              color: AppTheme.m3Primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            strings.t('noNotificationsYet'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.m3OnSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.t('coverageAlertsHere'),
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.m3OnSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRefresh != null) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.sync, size: 18),
              label: Text(strings.t('syncNow')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.m3Primary,
                side: const BorderSide(color: AppTheme.m3Primary),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}
