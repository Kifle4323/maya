import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../theme/app_theme.dart';

/// Wraps the app and shows an in-app banner when an FCM message arrives
/// while the app is in the foreground.
///
/// Usage: wrap your top-level widget with this:
///   FcmNotificationOverlay(child: MyApp())
class FcmNotificationOverlay extends StatefulWidget {
  const FcmNotificationOverlay({super.key, required this.child});
  final Widget child;

  @override
  State<FcmNotificationOverlay> createState() => _FcmNotificationOverlayState();
}

class _FcmNotificationOverlayState extends State<FcmNotificationOverlay>
    with SingleTickerProviderStateMixin {
  StreamSubscription<RemoteMessage>? _sub;
  _NotificationBannerData? _current;
  Timer? _dismissTimer;
  late final AnimationController _animCtrl;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _sub = FirebaseMessaging.onMessage.listen(_onMessage);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _dismissTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  void _onMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    setState(() {
      _current = _NotificationBannerData(
        title: notification.title ?? '',
        body: notification.body ?? '',
        type: message.data['type']?.toString() ?? '',
      );
    });

    _animCtrl.forward(from: 0);
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    _animCtrl.reverse().then((_) {
      if (mounted) setState(() => _current = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (_current != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: SlideTransition(
              position: _slideAnim,
              child: _NotificationBanner(
                data: _current!,
                onDismiss: _dismiss,
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationBannerData {
  const _NotificationBannerData({
    required this.title,
    required this.body,
    required this.type,
  });
  final String title;
  final String body;
  final String type;
}

class _NotificationBanner extends StatelessWidget {
  const _NotificationBanner({required this.data, required this.onDismiss});
  final _NotificationBannerData data;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconData, color: _iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (data.title.isNotEmpty)
                    Text(
                      data.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (data.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      data.body,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _iconData {
    switch (data.type) {
      case 'CLAIM_UPDATE':
        return Icons.receipt_long_outlined;
      case 'PAYMENT_CONFIRMATION':
        return Icons.payments_outlined;
      case 'RENEWAL_REMINDER':
        return Icons.autorenew_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get _iconColor {
    switch (data.type) {
      case 'CLAIM_UPDATE':
        return AppTheme.primary;
      case 'PAYMENT_CONFIRMATION':
        return AppTheme.gold;
      case 'RENEWAL_REMINDER':
        return AppTheme.warning;
      default:
        return AppTheme.accent;
    }
  }
}
