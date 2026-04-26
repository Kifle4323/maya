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
  });

  final AdminRepository repository;
  final VoidCallback onLogout;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _isOnline = true;
  bool _sidebarExpanded = true;
  Timer? _pingTimer;

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
    final strings = AppLocalizations.of(context);
    final navItems = _buildNavItems(strings);
    final pages = _buildPages();

    return Scaffold(
      body: Row(
        children: [
          // ── Collapsible Sidebar ───────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: _sidebarExpanded
                ? _kSidebarExpandedWidth
                : _kSidebarCollapsedWidth,
            color: AdminTheme.sidebarBg,
            child: Column(
              children: [
                // Toggle button row at top of sidebar
                _SidebarHeader(
                  expanded: _sidebarExpanded,
                  onToggle: _toggleSidebar,
                  strings: strings,
                ),

                const Divider(color: Color(0xFF1E3530), height: 1),
                const SizedBox(height: 8),

                // Nav items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    itemCount: navItems.length,
                    itemBuilder: (context, index) {
                      final item = navItems[index];
                      final isSelected = _selectedIndex == index;
                      return _SidebarNavItem(
                        item: item,
                        isSelected: isSelected,
                        expanded: _sidebarExpanded,
                        onTap: () => setState(() => _selectedIndex = index),
                      );
                    },
                  ),
                ),

                // Bottom — user info + logout
                const Divider(color: Color(0xFF1E3530), height: 1),
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

          // ── Main content ─────────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  height: 64,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        navItems[_selectedIndex].label,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AdminTheme.textDark,
                        ),
                      ),
                      const Spacer(),
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
                const Divider(height: 1),

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
                      color: AdminTheme.sidebarText,
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
                  color: AdminTheme.sidebarText,
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

/// A single nav item in the sidebar.
class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.item,
    required this.isSelected,
    required this.expanded,
    required this.onTap,
  });

  final _NavItem item;
  final bool isSelected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 12 : 0,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF2D3748)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? const Border(
                      left: BorderSide(
                        color: Color(0xFF1A73E8),
                        width: 3,
                      ),
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                if (isSelected && expanded) const SizedBox(width: 1),
                Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  color: isSelected
                      ? Colors.white
                      : AdminTheme.sidebarText,
                  size: 20,
                ),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AdminTheme.sidebarText,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (!expanded) {
      return Tooltip(
        message: item.label,
        preferBelow: false,
        child: tile,
      );
    }
    return tile;
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
                  const Icon(
                    Icons.logout,
                    color: AdminTheme.sidebarText,
                    size: 20,
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 12),
                    Text(
                      strings.t('signOut'),
                      style: const TextStyle(
                        color: AdminTheme.sidebarText,
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
                        color: AdminTheme.sidebarText,
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
                color: Colors.white,
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
                  const Divider(height: 1),
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
