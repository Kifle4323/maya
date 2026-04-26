import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../cbhi_localizations.dart';
import '../shared/language_selector.dart';
import '../theme/app_theme.dart';
import 'auth_cubit.dart';
import 'unified_login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.authCubit});

  final AuthCubit authCubit;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.welcomeGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Language selector
                Align(
                  alignment: Alignment.topRight,
                  child: const LanguageSelector(),
                ).animate().fadeIn(duration: 400.ms),

                const Spacer(flex: 2),

                // Logo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1, 1),
                      duration: 600.ms,
                      curve: Curves.easeOutBack,
                    ),

                const SizedBox(height: 28),

                // Title
                Text(
                  strings.t('appTitle'),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                )
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 200.ms)
                    .slideX(begin: -0.1, end: 0, duration: 600.ms, delay: 200.ms),

                const SizedBox(height: 16),

                // Subtitle
                Text(
                  strings.t('welcomeSubtitle'),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.5,
                      ),
                ).animate().fadeIn(duration: 500.ms, delay: 400.ms),

                const SizedBox(height: 12),

                // Feature chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FeatureChip(label: strings.t('multilingual'), icon: Icons.translate),
                    _FeatureChip(label: strings.t('digitalCard'), icon: Icons.qr_code_2),
                    _FeatureChip(label: strings.t('claimsTracking'), icon: Icons.receipt_long),
                    _FeatureChip(label: strings.t('offlineReady'), icon: Icons.cloud_off_outlined),
                  ],
                ).animate().fadeIn(duration: 500.ms, delay: 550.ms),

                const Spacer(flex: 3),

                // ── Sign In button ──────────────────────────────────────────
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    _slideRoute(const UnifiedLoginScreen()),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryDark,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.login),
                      const SizedBox(width: 10),
                      Text(
                        strings.t('signIn'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 650.ms)
                    .slideY(begin: 0.2, end: 0, duration: 500.ms, delay: 650.ms, curve: Curves.easeOutCubic),

                // Sign In hint
                if (screenWidth > 360)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 4),
                    child: Center(
                      child: Text(
                        strings.t('signInHint'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 700.ms),

                const SizedBox(height: 12),

                // ── Register button ─────────────────────────────────────────
                OutlinedButton(
                  onPressed: authCubit.continueAsGuest,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_add_alt_1),
                      const SizedBox(width: 10),
                      Text(strings.t('register_action')),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 750.ms)
                    .slideY(begin: 0.2, end: 0, duration: 500.ms, delay: 750.ms, curve: Curves.easeOutCubic),

                // Register hint
                if (screenWidth > 360)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Center(
                      child: Text(
                        strings.t('registerHint'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 800.ms),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Right-to-left slide transition (300 ms).
  static PageRoute<T> _slideRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
