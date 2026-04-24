import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cbhi_localizations.dart';
import '../theme/app_theme.dart';
import 'connectivity_cubit.dart';

/// Full-width banner that slides in when the device goes offline and slides
/// out when connectivity is restored.
///
/// Placement: insert as the first child of a [Column] in [_HomeShell.body],
/// with the page content wrapped in [Expanded].
///
/// Accessibility: wrapped in [Semantics] with [liveRegion: true] so screen
/// readers announce connectivity changes automatically.
class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  // Tracks whether we were previously offline so we can show the "back online"
  // success state before hiding the banner.
  bool _wasOffline = false;
  bool _showBackOnline = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onStateChange(ConnectivityState previous, ConnectivityState current) {
    if (!previous.isOnline && current.isOnline) {
      // Just came back online — show success banner for 2 seconds then hide.
      setState(() {
        _wasOffline = true;
        _showBackOnline = true;
      });
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _wasOffline = false;
            _showBackOnline = false;
          });
        }
      });
    } else if (!current.isOnline) {
      _hideTimer?.cancel();
      setState(() {
        _wasOffline = true;
        _showBackOnline = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectivityCubit, ConnectivityState>(
      listenWhen: (prev, curr) => prev.isOnline != curr.isOnline,
      listener: (context, current) {
        final previous = context.read<ConnectivityCubit>().state;
        _onStateChange(previous, current);
      },
      buildWhen: (prev, curr) =>
          prev.isOnline != curr.isOnline ||
          _showBackOnline != (_showBackOnline),
      builder: (context, state) {
        final strings = CbhiLocalizations.of(context);

        // Online and no pending "back online" message — render nothing.
        if (state.isOnline && !_showBackOnline && !_wasOffline) {
          return const SizedBox.shrink();
        }

        final isBackOnline = _showBackOnline;
        final bgColor =
            isBackOnline ? AppTheme.success : AppTheme.warning;
        final icon = isBackOnline
            ? Icons.cloud_done_outlined
            : Icons.cloud_off_outlined;
        final message = isBackOnline
            ? strings.t('backOnline')
            : strings.t('youAreOffline');

        if (!state.isOnline || isBackOnline) {
          return Semantics(
            liveRegion: true,
            child: _BannerBar(
              bgColor: bgColor,
              icon: icon,
              message: message,
              visible: !state.isOnline || isBackOnline,
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _BannerBar extends StatelessWidget {
  const _BannerBar({
    required this.bgColor,
    required this.icon,
    required this.message,
    required this.visible,
  });

  final Color bgColor;
  final IconData icon;
  final String message;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: bgColor,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .slideY(
          begin: -1,
          end: 0,
          duration: 300.ms,
          curve: Curves.easeOutCubic,
        )
        .fadeIn(duration: 300.ms);
  }
}
