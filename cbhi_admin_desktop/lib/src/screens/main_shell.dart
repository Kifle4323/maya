import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../blocs/claims_cubit.dart';
import '../blocs/indigent_cubit.dart';
import '../blocs/overview_cubit.dart';
import '../data/admin_repository.dart';
import '../i18n/app_localizations.dart';
import '../theme/admin_theme.dart';
import 'audit_log_screen.dart';
import 'benefit_packages_screen.dart';
import 'claim_appeals_screen.dart';
import 'facility_performance_screen.dart';
import 'financial_screen.dart';
import 'grievances_admin_screen.dart';
import 'overview_screen.dart';
import 'claims_screen.dart';
import 'facilities_screen.dart';
import 'indigent_screen.dart';
import 'settings_screen.dart';
import 'reports_screen.dart';
import 'user_management_screen.dart';

const _kSidebarExpandedWidth = 240.0;
const _kSidebarCollapsedWidth = 64.0;
const _kSidebarPrefKey = 'cbhi_admin_sidebar_expanded';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.repository,
    required this.onLogout,
    required this.locale,
    required this.onLocaleChanged,
    required this.themeMode,
    required this.onThemeChanged,
  });

  final AdminRepository repository;
  final VoidCallback onLogout;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _isOnline = true;
  bool _sidebarExpanded = true;
  Timer? _pingTimer;
  String? _buildError;

  @override
  void initState() {
    super.initState();
    _loadSidebarState();
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

  Future<void> _loadSidebarState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _sidebarExpanded = prefs.getBool(_kSidebarPrefKey) ?? true;
      });
    }
  }

  Future<void> _toggleSidebar() async {
    final next = !_sidebarExpanded;
    setState(() => _sidebarExpanded = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSidebarPrefKey, next);
  }

  Future<void> _checkConnectivity() async {
    final online = await widget.repository.ping();
    if (mounted && online != _isOnline) {
      setState(() => _isOnline = online);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_buildError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Render Error', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SelectableText(_buildError!, style: const TextStyle(fontSize: 12, color: Colors.red)),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => setState(() => _buildError = null), child: Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    try {
      return _buildContent(context);
    } catch (e, st) {
      debugPrint('MainShell build error: $e\n$st');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _buildError = e.toString());
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
  }

  Widget _buildContent(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final navItems = _buildNavItems(strings);
    final pages = _buildPages();

    return Scaffold(
      body: Row(
        children: [
          // ── Custom Scrollable Sidebar ──────────────────────────────────────
          SizedBox(
            width: _sidebarExpanded ? _kSidebarExpandedWidth : _kSidebarCollapsedWidth,
            child: Material(
            color: AdminTheme.sidebarBgFor(Theme.of(context).brightness),
            child: Column(
              children: [
                _SidebarHeader(
                  expanded: _sidebarExpanded,
                  onToggle: _toggleSidebar,
                  strings: strings,
                ),
                Divider(color: AdminTheme.dividerFor(Theme.of(context).brightness), height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: navItems.length,
                    itemBuilder: (context, index) {
                      final item = navItems[index];
                      final isSelected = index == _selectedIndex;
                      return _SidebarItem(
                        icon: isSelected ? item.selectedIcon : item.icon,
                        label: item.label,
                        expanded: _sidebarExpanded,
                        isSelected: isSelected,
                        onTap: () => setState(() => _selectedIndex = index),
                      );
                    },
                  ),
                ),
                Divider(color: AdminTheme.dividerFor(Theme.of(context).brightness), height: 1),
                _SidebarFooter(
                  expanded: _sidebarExpanded,
                  strings: strings,
                  onLogout: () async {
                    await widget.repository.logout();
                    widget.onLogout();
                  },
                ),
              ],
            ),
          ),
          ),

          // ── Main content ─────────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  height: 64,
                  color: AdminTheme.topBarBgFor(Theme.of(context).brightness),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        navItems[_selectedIndex].label,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AdminTheme.topBarTextFor(Theme.of(context).brightness),
                        ),
                      ),
                      const Spacer(),
                      // Theme toggle
                      Tooltip(
                        message: Theme.of(context).brightness == Brightness.dark ? 'Switch to light mode' : 'Switch to dark mode',
                        child: IconButton(
                          icon: Icon(
                            Theme.of(context).brightness == Brightness.dark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                          ),
                          color: AdminTheme.topBarTextFor(Theme.of(context).brightness),
                          onPressed: () {
                            final isDark = widget.themeMode == ThemeMode.dark ||
                                (widget.themeMode == ThemeMode.system &&
                                    MediaQuery.of(context).platformBrightness == Brightness.dark);
                            widget.onThemeChanged(isDark ? ThemeMode.light : ThemeMode.dark);
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      _AdminNotificationBell(repository: widget.repository),
                      const SizedBox(width: 8),
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
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AdminTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.translate,
                                  size: 16, color: AdminTheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                strings.languageLabel(
                                    widget.locale.languageCode),
                                style: const TextStyle(
                                  color: AdminTheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Semantics(
                        label: _isOnline
                            ? 'Connected to server'
                            : 'Offline — no server connection',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: (_isOnline
                                    ? AdminTheme.success
                                    : AdminTheme.error)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                color: _isOnline
                                    ? AdminTheme.success
                                    : AdminTheme.error,
                                size: 8,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isOnline
                                    ? strings.t('connected')
                                    : strings.t('offline'),
                                style: TextStyle(
                                  color: _isOnline
                                      ? AdminTheme.success
                                      : AdminTheme.error,
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
                Divider(color: AdminTheme.dividerFor(Theme.of(context).brightness), height: 1),

                // Page content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                      key: ValueKey(_selectedIndex),
                      child: pages[_selectedIndex],
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

  List<_NavItem> _buildNavItems(AppLocalizations strings) => [
        _NavItem(
          icon: Icons.space_dashboard_outlined,
          selectedIcon: Icons.space_dashboard,
          label: strings.t('navOverview'),
        ),
        _NavItem(
          icon: Icons.rule_folder_outlined,
          selectedIcon: Icons.rule_folder,
          label: strings.t('navClaims'),
        ),
        _NavItem(
          icon: Icons.volunteer_activism_outlined,
          selectedIcon: Icons.volunteer_activism,
          label: strings.t('navIndigent'),
        ),
        _NavItem(
          icon: Icons.local_hospital_outlined,
          selectedIcon: Icons.local_hospital,
          label: strings.t('navFacilities'),
        ),
        _NavItem(
          icon: Icons.account_balance_outlined,
          selectedIcon: Icons.account_balance,
          label: strings.t('navFinancial'),
        ),
        _NavItem(
          icon: Icons.analytics_outlined,
          selectedIcon: Icons.analytics,
          label: strings.t('navFacilityPerformance'),
        ),
        _NavItem(
          icon: Icons.people_outlined,
          selectedIcon: Icons.people,
          label: strings.t('navUsers'),
        ),
        _NavItem(
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          label: strings.t('benefitPackages'),
        ),
        _NavItem(
          icon: Icons.gavel_outlined,
          selectedIcon: Icons.gavel,
          label: strings.t('memberGrievances'),
        ),
        _NavItem(
          icon: Icons.assignment_late_outlined,
          selectedIcon: Icons.assignment_late,
          label: strings.t('claimAppeals'),
        ),
        _NavItem(
          icon: Icons.bar_chart_outlined,
          selectedIcon: Icons.bar_chart,
          label: strings.t('navReports'),
        ),
        _NavItem(
          icon: Icons.history_outlined,
          selectedIcon: Icons.history,
          label: strings.t('navAuditLog'),
        ),
        _NavItem(
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          label: strings.t('navSettings'),
        ),
      ];

  List<Widget> _buildPages() => [
        BlocProvider(
          create: (_) => OverviewCubit(widget.repository)..load(),
          child: OverviewScreen(repository: widget.repository),
        ),
        BlocProvider(
          create: (_) => ClaimsCubit(widget.repository)..load(),
          child: ClaimsScreen(repository: widget.repository),
        ),
        BlocProvider(
          create: (_) => IndigentCubit(widget.repository)..load(),
          child: IndigentScreen(repository: widget.repository),
        ),
        FacilitiesScreen(repository: widget.repository),
        FinancialScreen(repository: widget.repository),
        FacilityPerformanceScreen(repository: widget.repository),
        UserManagementScreen(repository: widget.repository),
        BenefitPackagesScreen(repository: widget.repository),
        GrievancesAdminScreen(repository: widget.repository),
        ClaimAppealsScreen(repository: widget.repository),
        ReportsScreen(repository: widget.repository),
        AuditLogScreen(repository: widget.repository),
        SettingsScreen(repository: widget.repository),
      ];
}

// ── Sidebar sub-widgets ────────────────────────────────────────────────────

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Single sidebar item — icon + optional label, with hover/selected states.
class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final sidebarText = AdminTheme.sidebarTextFor(Theme.of(context).brightness);
    final bgColor = widget.isSelected
        ? AdminTheme.primary.withValues(alpha: 0.5)
        : _isHovered
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.transparent;
    final iconColor = widget.isSelected ? Colors.white : sidebarText;
    final labelColor = widget.isSelected ? Colors.white : sidebarText;

    return Tooltip(
      message: widget.expanded ? '' : widget.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: widget.expanded
                ? Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(widget.icon, size: 20, color: iconColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.label,
                          style: TextStyle(
                            color: labelColor,
                            fontSize: 13,
                            fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Icon(widget.icon, size: 22, color: iconColor),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Top section of the sidebar: logo + toggle button.
class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.expanded,
    required this.onToggle,
    required this.strings,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          // Logo icon — always visible
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AdminTheme.cardBgFor(Theme.of(context).brightness),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset(
                'assets/images/logo.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Title — only when expanded
          if (expanded) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Maya City',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'CBHI Admin',
                    style: TextStyle(
                      color: AdminTheme.sidebarTextFor(Theme.of(context).brightness),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            const Spacer(),

          // Toggle button — always visible
          Tooltip(
            message: expanded ? 'Collapse sidebar' : 'Expand sidebar',
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  // Split-panel / sidebar icon
                  expanded
                      ? Icons.view_sidebar
                      : Icons.view_sidebar_outlined,
                  color: AdminTheme.sidebarTextFor(Theme.of(context).brightness),
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Bottom section of the sidebar: user avatar + logout.
class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({
    required this.expanded,
    required this.strings,
    required this.onLogout,
  });

  final bool expanded;
  final AppLocalizations strings;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final logoutTile = Padding(
      padding: const EdgeInsets.all(8),
      child: Tooltip(
        message: expanded ? '' : strings.t('signOut'),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onLogout,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? 12 : 0,
                vertical: 11,
              ),
              child: Row(
                mainAxisAlignment: expanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout,
                    color: AdminTheme.sidebarTextFor(Theme.of(context).brightness),
                    size: 20,
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 12),
                    Text(
                      strings.t('signOut'),
                      style: TextStyle(
                        color: AdminTheme.sidebarTextFor(Theme.of(context).brightness),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!expanded) return logoutTile;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // User avatar row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AdminTheme.primary.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'CBHI Officer',
                      style: TextStyle(
                        color: AdminTheme.sidebarTextFor(Theme.of(context).brightness),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        logoutTile,
      ],
    );
  }
}

// ── Notification Bell ──────────────────────────────────────────────────────

class _AdminNotificationBell extends StatefulWidget {
  const _AdminNotificationBell({required this.repository});
  final AdminRepository repository;

  @override
  State<_AdminNotificationBell> createState() => _AdminNotificationBellState();
}

class _AdminNotificationBellState extends State<_AdminNotificationBell> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final list = await widget.repository.getNotifications();
      if (mounted) setState(() => _notifications = list);
    } catch (_) {
      // Non-fatal
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _unreadCount =>
      _notifications.where((n) => n['isRead'] != true).length;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => _showPanel(context),
        ),
        if (_unreadCount > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: AdminTheme.error,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _unreadCount > 9 ? '9+' : '$_unreadCount',
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

  void _showPanel(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 64, right: 16),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 360,
              constraints: const BoxConstraints(maxHeight: 480),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ?? (Theme.of(context).brightness == Brightness.dark ? AdminTheme.darkCard : Colors.white),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        const Text(
                          'Notifications',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 18),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _load();
                          },
                          tooltip: 'Refresh',
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: AdminTheme.dividerFor(Theme.of(context).brightness), height: 1),
                  if (_notifications.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.notifications_none_outlined,
                              size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('No notifications',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _notifications.length.clamp(0, 20),
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 56),
                        itemBuilder: (_, i) {
                          final n = _notifications[i];
                          final isRead = n['isRead'] == true;
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              _iconFor(n['type']?.toString() ?? ''),
                              color: isRead ? Colors.grey : AdminTheme.primary,
                              size: 20,
                            ),
                            title: Text(
                              n['title']?.toString() ?? '',
                              style: TextStyle(
                                fontWeight: isRead
                                    ? FontWeight.w400
                                    : FontWeight.w700,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              n['message']?.toString() ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: isRead
                                ? null
                                : Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AdminTheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                            onTap: n['id'] == null
                                ? null
                                : () async {
                                    final nav = Navigator.of(ctx);
                                    await widget.repository
                                        .markNotificationRead(
                                            n['id'].toString());
                                    if (!mounted) return;
                                    nav.pop();
                                    _load();
                                  },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
        'CLAIM_UPDATE' => Icons.receipt_long_outlined,
        'PAYMENT_CONFIRMATION' => Icons.payments_outlined,
        'SYSTEM_ALERT' => Icons.info_outline,
        _ => Icons.notifications_outlined,
      };
}
