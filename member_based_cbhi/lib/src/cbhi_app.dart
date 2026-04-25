import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/onboarding_screen.dart';
import 'auth/privacy_consent_screen.dart';
import 'auth/auth_cubit.dart';
import 'auth/auth_state.dart';
import 'auth/welcome_screen.dart';
import 'card/digital_card_screen.dart';
import 'cbhi_data.dart';
import 'cbhi_localizations.dart';
import 'cbhi_state.dart';
import 'claims/member_claims_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'family/my_family_cubit.dart';
import 'family/my_family_screen.dart';
import 'notifications/notification_inbox_screen.dart';
import 'profile/profile_screen.dart';
import 'registration/registration_cubit.dart';
import 'registration/registration_flow.dart';
import 'shared/animated_widgets.dart';
import 'shared/connectivity_banner.dart';
import 'shared/connectivity_cubit.dart';
import 'shared/help_screen.dart';
import 'shared/premium_sidebar.dart';
import 'theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CbhiApp
// ═══════════════════════════════════════════════════════════════════════════

class CbhiApp extends StatelessWidget {
  const CbhiApp({super.key, required this.repository});

  final CbhiRepository repository;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ConnectivityCubit>(create: (_) => ConnectivityCubit()),
        BlocProvider<AppCubit>(create: (_) => AppCubit(repository)),
        BlocProvider<AuthCubit>(create: (_) => AuthCubit(repository)),
        BlocProvider<RegistrationCubit>(
          create: (_) => RegistrationCubit(repository),
        ),
        BlocProvider<MyFamilyCubit>(create: (_) => MyFamilyCubit(repository)),
      ],
      child: BlocBuilder<AppCubit, AppState>(
        builder: (context, state) {
          final appLocale = state.locale;
          // GlobalMaterialLocalizations doesn't support 'om'.
          // Pass 'en' as the framework locale for om users so TextField,
          // Dropdown, DatePicker etc. render correctly.
          // Our AppLocalizations delegate still loads om strings.
          final frameworkLocale = appLocale.languageCode == 'om'
              ? const Locale('en')
              : appLocale;

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: frameworkLocale,
            supportedLocales: CbhiLocalizations.supportedLocales,
            localeResolutionCallback: (locale, supportedLocales) {
              if (locale == null) return const Locale('en');
              for (final supported in supportedLocales) {
                if (supported.languageCode == locale.languageCode) {
                  return supported;
                }
              }
              return const Locale('en');
            },
            localizationsDelegates: CbhiLocalizations.delegatesFor(appLocale),
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: state.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const _BootstrapScreen(),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Bootstrap
// ═══════════════════════════════════════════════════════════════════════════

class _BootstrapScreen extends StatefulWidget {
  const _BootstrapScreen();

  @override
  State<_BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<_BootstrapScreen> {
  bool _showOnboarding = false;
  bool _showConsent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final appCubit = context.read<AppCubit>();
      final authCubit = context.read<AuthCubit>();
      final connectivityCubit = context.read<ConnectivityCubit>();
      await connectivityCubit.initialize();
      await appCubit.load();
      await authCubit.bootstrap();

      // Check consent first, then onboarding
      final consented = await hasGivenConsent();
      if (!consented && mounted) {
        setState(() => _showConsent = true);
        return;
      }

      final seen = await hasSeenOnboarding();
      if (!seen && mounted) {
        setState(() => _showOnboarding = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show privacy consent for first-time users
    if (_showConsent) {
      return PrivacyConsentScreen(
        onDone: () async {
          setState(() => _showConsent = false);
          final seen = await hasSeenOnboarding();
          if (!seen && mounted) {
            setState(() => _showOnboarding = true);
          }
        },
      );
    }

    // Show onboarding for first-time users before the auth flow
    if (_showOnboarding) {
      return OnboardingScreen(
        onDone: () => setState(() => _showOnboarding = false),
      );
    }

    return MultiBlocListener(
      listeners: [
        BlocListener<AuthCubit, AuthState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) async {
            final appCubit = context.read<AppCubit>();
            final familyCubit = context.read<MyFamilyCubit>();
            final registrationCubit = context.read<RegistrationCubit>();
            if (state.status == AuthStatus.authenticated) {
              await appCubit.sync();
              await familyCubit.load();
              return;
            }
            if (state.status == AuthStatus.guest) {
              registrationCubit.reset();
              return;
            }
            if (state.status == AuthStatus.unauthenticated) {
              familyCubit.clear();
            }
          },
        ),
      ],
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          final strings = CbhiLocalizations.of(context);
          if (authState.status == AuthStatus.checking) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.health_and_safety,
                        size: 48,
                        color: AppTheme.primary,
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .shimmer(
                          duration: 1500.ms,
                          color: AppTheme.accent.withValues(alpha: 0.3),
                        ),
                    const SizedBox(height: 24),
                    Text(
                      strings.t('appTitle'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.t('loading'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          if (authState.status == AuthStatus.guest) {
            return const RegistrationFlow();
          }

          if (authState.status == AuthStatus.authenticated) {
            return const _HomeShell();
          }

          return WelcomeScreen(authCubit: context.read<AuthCubit>());
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Home Shell
// ═══════════════════════════════════════════════════════════════════════════

class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _checkFirstLogin();
  }

  Future<void> _checkFirstLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLogin = prefs.getBool('cbhi_first_login_done') != true;
    if (isFirstLogin && mounted) {
      await prefs.setBool('cbhi_first_login_done', true);
      // Show a non-blocking SnackBar guiding to Family tab
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final strings = CbhiLocalizations.of(context);
        // Check if family member — if so, no Family tab to navigate to
        final isFamilyMember =
            context.read<AuthCubit>().state.isFamilyMember;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.t('onboardingBody1')),
            duration: const Duration(seconds: 5),
            action: isFamilyMember
                ? null
                : SnackBarAction(
                    label: strings.t('goToFamily'),
                    onPressed: () {
                      // Family tab is index 1 for household heads
                      if (mounted) setState(() => _index = 1);
                    },
                  ),
          ),
        );
      });
    }
  }

  /// Build the ordered page list based on role.
  /// Family members don't see the Family tab — indices shift accordingly.
  List<Widget> _buildPages(bool isFamilyMember, AppCubit appCubit) {
    final pages = <Widget>[const DashboardScreen()];
    if (!isFamilyMember) pages.add(const MyFamilyScreen());
    pages.add(const DigitalCardScreen());
    pages.add(
      BlocBuilder<AppCubit, AppState>(
        builder: (context, state) {
          final snapshot = state.snapshot ?? CbhiSnapshot.empty();
          return MemberClaimsScreen(
            snapshot: snapshot,
            repository: appCubit.repository,
          );
        },
      ),
    );
    pages.add(const ProfileScreen());
    return pages;
  }

  List<NavigationDestination> _buildDestinations(
    bool isFamilyMember,
    dynamic strings,
  ) {
    return [
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home_rounded),
        label: strings.t('home'),
      ),
      if (!isFamilyMember)
        NavigationDestination(
          icon: const Icon(Icons.family_restroom_outlined),
          selectedIcon: const Icon(Icons.family_restroom),
          label: strings.t('family'),
        ),
      NavigationDestination(
        icon: const Icon(Icons.badge_outlined),
        selectedIcon: const Icon(Icons.badge),
        label: strings.t('card'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.receipt_long_outlined),
        selectedIcon: const Icon(Icons.receipt_long),
        label: strings.t('claims'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: strings.t('profile'),
      ),
    ];
  }

  Future<void> _handlePop(BuildContext context) async {
    if (  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final authState = context.watch<AuthCubit>().state;
    final isFamilyMember = authState.isFamilyMember;
    final appCubit = context.read<AppCubit>();
    final snapshot = context.watch<AppCubit>().state.snapshot;

    final pages = _buildPages(isFamilyMember, appCubit);
    final destinations = _buildDestinations(isFamilyMember, strings);

    // Guard: clamp index to valid range when role changes
    final safeIndex = _index.clamp(0, pages.length - 1);

    // Responsive Logic
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 800;
    final isMediumScreen = screenWidth > 600 && screenWidth <= 800;
    final useSidebar = isLargeScreen || isMediumScreen;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handlePop(context);
      },
      child: NotificationListener<ProfileTabNotification>(
        onNotification: (_) {
          // Profile tab is always the last tab
          setState(() => _index = pages.length - 1);
          return true;
        },
        child: NotificationListener<FamilyTabNotification>(
          onNotification: (_) {
            // Family tab is index 1 for household heads (not shown for family members)
            if (!isFamilyMember) setState(() => _index = 1);
            return true;
          },
          child: MultiBlocListener(
        listeners: [
          BlocListener<ConnectivityCubit, ConnectivityState>(
            listenWhen: (prev, curr) => !prev.isOnline && curr.isOnline,
            listener: (context, _) => context.read<AppCubit>().sync(),
          ),
        ],
        child: Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.health_and_safety,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(strings.t('appTitle')),
                if (isFamilyMember) ...[
                  const SizedBox(width: 8),
                  StatusBadge(
                    label: strings.t('familyMemberSession'),
                    color: AppTheme.accent,
                  ),
                ],
              ],
            ),
            actions: [
              BlocBuilder<AppCubit, AppState>(
                builder: (context, state) {
                  final snap = state.snapshot;
                  final isPendingSync = snap?.isPendingSync ?? false;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPendingSync)
                        Semantics(
                          label: 'Offline — changes pending sync',
                          child: Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color:
                                      AppTheme.warning.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cloud_off_outlined,
                                    color: AppTheme.warning, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  strings.t('offlineBadge'),
                                  style: const TextStyle(
                                    color: AppTheme.warning,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Notification bell with unread badge
                      _NotificationBell(snapshot: snap),
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          tooltip: strings.t('syncNow'),
                          onPressed: state.isSyncing
                              ? null
                              : () async {
                                  final authCubit =
                                      context.read<AuthCubit>();
                                  final familyCubit =
                                      context.read<MyFamilyCubit>();
                                  await appCubit.sync();
                                  await authCubit.refreshSession();
                                  await familyCubit.load();
                                },
                          icon: state.isSyncing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.sync),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          body: Row(
            children: [
              if (useSidebar)
                PremiumSidebar(
                  selectedIndex: safeIndex,
                  onDestinationSelected: (idx) => setState(() => _index = idx),
                  isFamilyMember: isFamilyMember,
                  userName: authState.session?.user.displayName ?? 'Member',
                  householdCode: snapshot?.householdCode ?? 'Pending',
                  isCollapsed: isMediumScreen,
                ),
              Expanded(
                child: Column(
                  children: [
                    const ConnectivityBanner(),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.03, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey(safeIndex),
                          child: pages[safeIndex],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: safeIndex != 0
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HelpScreen()),
                  ),
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Help & FAQ'),
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ).animate().scale(curve: Curves.easeOutBack, duration: 400.ms)
              : null,
          bottomNavigationBar: useSidebar
              ? null
              : Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: NavigationBar(
                    selectedIndex: safeIndex,
                    onDestinationSelected: (value) =>
                        setState(() => _index = value),
                    destinations: destinations,
                  ),
                ),
        ),
      ),
    ),
    ),
    );
  }

// ═══════════════════════════════════════════════════════════════════════════
// Notification Bell — AppBar action with unread badge
// ═══════════════════════════════════════════════════════════════════════════

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.snapshot});
  final CbhiSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final unreadCount = (snapshot?.notifications ?? [])
        .where((n) => n['isRead'] != true)
        .length;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationInboxScreen(),
              ),
            ),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}


