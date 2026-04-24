import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';

/// Reusable soft error widget — replaces raw exception text across all screens.
///
/// Usage:
/// ```dart
/// if (_error != null)
///   ErrorStateWidget(
///     message: _error!,
///     onRetry: _load,
///   )
/// ```
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.compact = false,
  });

  /// The raw error string — will be mapped to a human-readable message.
  final String message;

  /// Optional retry callback. If null, no "Try again" button is shown.
  final VoidCallback? onRetry;

  /// When true, renders a smaller inline version (for use inside cards).
  final bool compact;

  String get _friendlyMessage {
    final lower = message.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('network') ||
        lower.contains('unreachable') ||
        lower.contains('timeout') ||
        lower.contains('check that the api')) {
      return "Couldn't load data. Check your connection.";
    }
    if (lower.contains('401') ||
        lower.contains('unauthorized') ||
        lower.contains('forbidden') ||
        lower.contains('403')) {
      return 'Session expired. Please sign in again.';
    }
    if (lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('unexpected response')) {
      return 'Something went wrong on our end. Try again in a moment.';
    }
    if (lower.contains('404') || lower.contains('not found')) {
      return 'The requested data could not be found.';
    }
    // Strip "Exception: " prefix for cleaner display
    return message.replaceFirst('Exception: ', '');
  }

  IconData get _icon {
    final lower = message.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('network') ||
        lower.contains('timeout') ||
        lower.contains('unreachable') ||
        lower.contains('check that the api')) {
      return Icons.cloud_off_outlined;
    }
    if (lower.contains('401') || lower.contains('unauthorized')) {
      return Icons.lock_outline;
    }
    return Icons.error_outline;
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFDDD6)),
        ),
        child: Row(
          children: [
            Icon(_icon, color: const Color(0xFFBF4040), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _friendlyMessage,
                style: const TextStyle(
                  color: Color(0xFF7A3030),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 12),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFBF4040),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Try again', style: TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3F0),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _icon,
                size: 40,
                color: const Color(0xFFBF4040),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _friendlyMessage,
              style: const TextStyle(
                fontSize: 15,
                color: AdminTheme.textDark,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminTheme.primary,
                  side: const BorderSide(color: AdminTheme.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
