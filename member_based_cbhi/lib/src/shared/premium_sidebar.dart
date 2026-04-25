import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../cbhi_localizations.dart';
import '../theme/app_theme.dart';
import 'help_screen.dart';

class PremiumSidebar extends StatelessWidget {
  const PremiumSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.isFamilyMember,
    required this.userName,
    required this.householdCode,
    this.isCollapsed = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isFamilyMember;
  final String userName;
  final String householdCode;
  final bool isCollapsed;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      width: isCollapsed ? 88 : 280,
      height: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Mesh Header
            _SidebarHeader(
              userName: userName,
              householdCode: householdCode,
              isCollapsed: isCollapsed,
            ),
            
            const SizedBox(height: 24),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 16),
                children: [
                  _SidebarItem(
                    icon: Icons.dashboard_outlined,
                    selectedIcon: Icons.dashboard,
                    label: strings.t('home'),
                    selected: selectedIndex == 0,
                    isCollapsed: isCollapsed,
                    onTap: () => onDestinationSelected(0),
                  ),
                  if (!isFamilyMember)
                    _SidebarItem(
                      icon: Icons.family_restroom_outlined,
                      selectedIcon: Icons.family_restroom,
                      label: strings.t('family'),
                      selected: selectedIndex == 1,
                      isCollapsed: isCollapsed,
                      onTap: () => onDestinationSelected(1),
                    ),
                  _SidebarItem(
                    icon: Icons.badge_outlined,
                    selectedIcon: Icons.badge,
                    label: strings.t('card'),
                    selected: selectedIndex == (isFamilyMember ? 1 : 2),
                    isCollapsed: isCollapsed,
                    onTap: () => onDestinationSelected(isFamilyMember ? 1 : 2),
                  ),
                  _SidebarItem(
                    icon: Icons.receipt_long_outlined,
                    selectedIcon: Icons.receipt_long,
                    label: strings.t('claims'),
                    selected: selectedIndex == (isFamilyMember ? 2 : 3),
                    isCollapsed: isCollapsed,
                    onTap: () => onDestinationSelected(isFamilyMember ? 2 : 3),
                  ),
                  _SidebarItem(
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    label: strings.t('profile'),
                    selected: selectedIndex == (isFamilyMember ? 3 : 4),
                    isCollapsed: isCollapsed,
                    onTap: () => onDestinationSelected(isFamilyMember ? 3 : 4),
                  ),
                  
                  const Divider(height: 40),
                  
                  // Global FAQ (Only visible if NOT on dashboard)
                  if (selectedIndex != 0)
                    _SidebarItem(
                      icon: Icons.help_outline,
                      label: strings.t('helpAndFaq'),
                      isCollapsed: isCollapsed,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      ),
                    ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
                ],
              ),
            ),
            
            // Footer
            if (!isCollapsed)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      strings.t('ehia'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'v2.4.0-Premium',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.userName,
    required this.householdCode,
    required this.isCollapsed,
  });

  final String userName;
  final String householdCode;
  final bool isCollapsed;

  @override
  Widget build(BuildContext context) {
    if (isCollapsed) {
      return Container(
        margin: const EdgeInsets.only(top: 20),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: AppTheme.heroGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.health_and_safety, color: Colors.white, size: 28),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.health_and_safety, color: Colors.white, size: 32),
          const SizedBox(height: 16),
          Text(
            userName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'HH: $householdCode',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
    this.selected = false,
    required this.isCollapsed,
    required this.onTap,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final bool selected;
  final bool isCollapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = AppTheme.primary;
    final inactiveColor = AppTheme.textSecondary;

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: selected ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                selected ? (selectedIcon ?? icon) : icon,
                color: selected ? activeColor : inactiveColor,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                selected ? (selectedIcon ?? icon) : icon,
                color: selected ? activeColor : inactiveColor,
                size: 22,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: selected ? activeColor : inactiveColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
