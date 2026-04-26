import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../app.dart';
import '../blocs/claim_tracker_cubit.dart';
import '../blocs/submit_claim_cubit.dart';
import '../blocs/verify_cubit.dart';
import '../data/facility_repository.dart';
import '../i18n/app_localizations.dart';
import 'verify_screen.dart';
import 'submit_claim_screen.dart';
import 'claim_tracker_screen.dart';

// FIX: Removed duplicate MainShell class definition.
// FIX ME-4: All three screens are now wrapped in BLoC providers.

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.repository,
    required this.onLogout,
    required this.locale,
    required this.onLocaleChanged,
  });
  final FacilityRepository repository;
  final VoidCallback onLogout;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _isOnline = true;
  Timer? _pingTimer;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _pingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkConnectivity(),
    );
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final online = await widget.repository.ping();
    if (mounted && online != _isOnline) {
      setState(() => _isOnline = online);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final items = [
      (
        icon: Icons.verified_user_outlined,
        selected: Icons.verified_user,
        label: strings.t('navVerify'),
      ),
      (
        icon: Icons.note_add_outlined,
        selected: Icons.note_add,
        label: strings.t('navSubmitClaim'),
      ),
      (
        icon: Icons.fact_check_outlined,
        selected: Icons.fact_check,
        label: strings.t('navClaimDecisions'),
      ),
    ];

    // FIX ME-4: Wrap each page in its own BLoC provider for consistent state management
    final pages = [
      BlocProvider(
        create: (_) => VerifyCubit(widget.repository),
        child: VerifyScreen(repository: widget.repository),
      ),
      BlocProvider(
        create: (_) => SubmitClaimCubit(widget.repository),
        child: SubmitClaimScreen(repository: widget.repository),
      ),
      BlocProvider(
        create: (_) => ClaimTrackerCubit(widget.repository)..load(),
        child: ClaimTrackerScreen(repository: widget.repository),
      ),
    ];

    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────────────────────
          Container(
            width: 220,
            color: kSidebarBg,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.t('facilityBrand'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              strings.t('staffPortal'),
                              style: const TextStyle(
                                color: Color(0xFF8AADA4),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF1E3530), height: 1),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final selected = _index == i;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _index = i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? kAccent.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: selected
                                    ? Border.all(
                                        color: kAccent.withValues(alpha: 0.3),
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected ? item.selected : item.icon,
                                    color: selected
                                        ? kAccent
                                        : const Color(0xFF8AADA4),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      color: selected
                                          ? kAccent
                                          : const Color(0xFF8AADA4),
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(color: Color(0xFF1E3530), height: 1),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        await widget.repository.logout();
                        widget.onLogout();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.logout,
                              color: Color(0xFF8AADA4),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              strings.t('signOut'),
                              style: const TextStyle(
                                color: Color(0xFF8AADA4),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Main content ─────────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  height: 60,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        items[_index].label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: kTextDark,
                        ),
                      ),
                      const Spacer(),
                      // Language selector
                      PopupMenuButton<Locale>(
                        tooltip: strings.t('language'),
                        onSelected: widget.onLocaleChanged,
                        itemBuilder: (_) => AppLocalizations.supportedLocales
                            .map(
                              (locale) => PopupMenuItem<Locale>(
                                value: locale,
                                child: Text(
                                  strings.languageLabel(locale.languageCode),
                                ),
                              ),
                            )
                            .toList(growable: false),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.translate,
                              size: 16,
                              color: kPrimary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              strings.languageLabel(widget.locale.languageCode),
                              style: const TextStyle(
                                color: kPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Connectivity indicator with semantic label
                      Semantics(
                        label: _isOnline
                            ? 'Connected to server'
                            : 'Offline — no server connection',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: (_isOnline ? kSuccess : kError)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                color: _isOnline ? kSuccess : kError,
                                size: 8,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isOnline
                                    ? strings.t('online')
                                    : strings.t('offline'),
                                style: TextStyle(
                                  color: _isOnline ? kSuccess : kError,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Page content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: KeyedSubtree(
                      key: ValueKey(_index),
                      child: pages[_index],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
