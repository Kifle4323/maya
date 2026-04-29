import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
            themeMode: state.themeMode,
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
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      strings.t('appTitle'),
                      style: Theme.of(context).textTheme.headlineSmall,
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
          icon: const Icon(Icons.group_outlined),
          selectedIcon: const Icon(Icons.group),
          label: strings.t('family'),
        ),
      NavigationDestination(
        icon: const Icon(Icons.contact_page_outlined),
        selectedIcon: const Icon(Icons.contact_page),
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
        label: strings.t('account'),
      ),
    ];
  }

  Future<void> _handlePop(BuildContext context) async {
    if (_index != 0) {
      setState(() => _index = 0);
    } else {
      SystemNavigator.pop();
    }
  }
      @override
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
    final useSidebar = kIsWeb && (isLargeScreen || isMediumScreen);

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
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: _M3TopAppBar(
              isFamilyMember: isFamilyMember,
              snapshot: snapshot,
              isSyncing: context.watch<AppCubit>().state.isSyncing,
              appCubit: appCubit,
            ),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
              : _M3BottomNavBar(
                  selectedIndex: safeIndex,
                  onDestinationSelected: (value) => setState(() => _index = value),
                  destinations: destinations,
                ),
        ),
      ),
    ),
    ),
    );
  }
    }

// ═══════════════════════════════════════════════════════════════════════════
// M3 Top App Bar — frosted glass, avatar + "Maya CBHI" blue, notification bell
// ═══════════════════════════════════════════════════════════════════════════

class _M3TopAppBar extends StatelessWidget {
  const _M3TopAppBar({
    required this.isFamilyMember,
    required this.snapshot,
    required this.isSyncing,
    required this.appCubit,
  });

  final bool isFamilyMember;
  final CbhiSnapshot? snapshot;
  final bool isSyncing;
  final AppCubit appCubit;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final isPendingSync = snapshot?.isPendingSync ?? false;
    final displayName = context.watch<AuthCubit>().state.session?.user.displayName ?? '';
    final initials = _initials(displayName);

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppTheme.cardBgFor(Theme.of(context).brightness).withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.m3OutlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Avatar with initials
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.m3PrimaryContainer,
                border: Border.all(
                  color: AppTheme.m3OutlineVariant,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppTheme.m3OnPrimaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // App title
            Text(
              strings.t('appTitle'),
              style: const TextStyle(
                color: AppTheme.m3Primary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            if (isFamilyMember) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.m3TertiaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppTheme.m3TertiaryContainer.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  strings.t('familyMemberSession'),
                  style: const TextStyle(
                    color: AppTheme.m3Tertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const Spacer(),
            // Offline badge
            if (isPendingSync)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, color: AppTheme.warning, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      strings.t('offlineBadge'),
                      style: const TextStyle(
                        color: AppTheme.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            // Notification bell
            _NotificationBell(snapshot: snapshot),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'M';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// M3 Bottom Nav Bar — white bg, top border, active pill state
// ═══════════════════════════════════════════════════════════════════════════

class _M3BottomNavBar extends StatelessWidget {
  const _M3BottomNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBgFor(Theme.of(context).brightness),
        border: Border(
          top: BorderSide(
            color: AppTheme.m3OutlineVariant.withValues(alpha: 0.4),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: destinations.asMap().entries.map((entry) {
              final idx = entry.key;
              final dest = entry.value;
              final isSelected = idx == selectedIndex;
              return _NavBarItem(
                destination: dest,
                isSelected: isSelected,
                onTap: () => onDestinationSelected(idx),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final NavigationDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: destination.label,
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.m3Primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme(
                data: IconThemeData(
                  color: isSelected ? AppTheme.m3Primary : AppTheme.textSecondaryFor(Theme.of(context).brightness),
                  size: 24,
                ),
                child: isSelected ? destination.selectedIcon! : destination.icon,
              ),
              const SizedBox(height: 2),
              Text(
                destination.label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.m3Primary : AppTheme.textSecondaryFor(Theme.of(context).brightness),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_outlined),
          color: AppTheme.m3Primary,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const NotificationInboxScreen(),
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
                color: AppTheme.error,
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


