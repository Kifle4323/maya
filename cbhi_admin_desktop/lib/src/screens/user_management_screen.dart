import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../i18n/app_localizations.dart';
import '../theme/admin_theme.dart';

/// User Management Screen — view all users, activate/deactivate, reset passwords.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key, required this.repository});
  final AdminRepository repository;

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  String _roleFilter = 'ALL';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  final _roles = ['ALL', 'HOUSEHOLD_HEAD', 'BENEFICIARY', 'HEALTH_FACILITY_STAFF', 'CBHI_OFFICER', 'SYSTEM_ADMIN'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.repository.listUsers(role: _roleFilter == 'ALL' ? null : _roleFilter);
      setState(() => _users = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return _users;
    final q = _searchQuery.toLowerCase();
    return _users.where((u) {
      final name = u['displayName']?.toString().toLowerCase() ?? '';
      final phone = u['phoneNumber']?.toString().toLowerCase() ?? '';
      final email = u['email']?.toString().toLowerCase() ?? '';
      return name.contains(q) || phone.contains(q) || email.contains(q);
    }).toList();
  }

  Future<void> _toggleActive(Map<String, dynamic> user) async {
    final strings = AppLocalizations.of(context);
    final isActive = user['isActive'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isActive ? strings.t('deactivateUser') : strings.t('activateUser')),
        content: Text(isActive ? strings.t('deactivateUserConfirm') : strings.t('activateUserConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(strings.t('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: isActive ? AdminTheme.error : AdminTheme.success),
            child: Text(isActive ? strings.t('deactivate') : strings.t('activate')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (isActive) {
        await widget.repository.deactivateUser(user['id'].toString());
      } else {
        await widget.repository.activateUser(user['id'].toString());
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AdminTheme.error));
    }
  }

  Future<void> _resetPassword(Map<String, dynamic> user) async {
    final strings = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.t('resetPassword')),
        content: Text(strings.t('resetPasswordConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(strings.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(strings.t('resetPassword'))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.resetUserPassword(user['id'].toString());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.t('passwordResetSuccess')), backgroundColor: AdminTheme.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AdminTheme.error));
    }
  }

  Color _roleColor(String role) => switch (role.toUpperCase()) {
    'SYSTEM_ADMIN' => AdminTheme.error,
    'CBHI_OFFICER' => AdminTheme.primary,
    'HEALTH_FACILITY_STAFF' => AdminTheme.accent,
    'HOUSEHOLD_HEAD' => AdminTheme.success,
    _ => AdminTheme.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Column(
      children: [
        // Filter bar
        Container(
          color: AdminTheme.cardBgFor(Theme.of(context).brightness),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              // Role filter chips
              Wrap(
                spacing: 6,
                children: _roles.map((role) => FilterChip(
                  label: Text(role == 'ALL' ? strings.t('statusAll') : role.replaceAll('_', ' '), style: TextStyle(fontSize: 11)),
                  selected: _roleFilter == role,
                  onSelected: (_) { setState(() => _roleFilter = role); _load(); },
                  selectedColor: AdminTheme.primary.withValues(alpha: 0.15),
                  checkmarkColor: AdminTheme.primary,
                  labelStyle: TextStyle(color: _roleFilter == role ? AdminTheme.primary : AdminTheme.textSecondary, fontWeight: _roleFilter == role ? FontWeight.w700 : FontWeight.normal),
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: strings.t('searchUsers'),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); }) : null,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
              ),
              const Spacer(),
              if (!_loading) Text('${_filtered.length} ${strings.t('records')}', style: TextStyle(color: AdminTheme.textSecondaryFor(Theme.of(context).brightness), fontSize: 13)),
              const SizedBox(width: 8),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: strings.t('refresh')),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AdminTheme.primary))
              : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: AdminTheme.error)))
              : _filtered.isEmpty
              ? Center(child: Text(strings.t('noUsersFound')))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text(strings.t('name'))),
                          DataColumn(label: Text(strings.t('phoneNumber'))),
                          DataColumn(label: Text(strings.t('role'))),
                          DataColumn(label: Text(strings.t('status'))),
                          DataColumn(label: Text(strings.t('lastLogin'))),
                          DataColumn(label: Text(strings.t('actions'))),
                        ],
                        rows: _filtered.map((user) {
                          final isActive = user['isActive'] == true;
                          final role = user['role']?.toString() ?? '';
                          final roleColor = _roleColor(role);

                          return DataRow(cells: [
                            DataCell(Row(children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: roleColor.withValues(alpha: 0.15),
                                child: Text(
                                  (user['displayName']?.toString() ?? 'U').substring(0, 1).toUpperCase(),
                                  style: TextStyle(color: roleColor, fontWeight: FontWeight.w700, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(user['displayName']?.toString() ?? '—', style: TextStyle(fontWeight: FontWeight.w600)),
                            ])),
                            DataCell(Text(user['phoneNumber']?.toString() ?? user['email']?.toString() ?? '—')),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                              child: Text(role.replaceAll('_', ' '), style: TextStyle(color: roleColor, fontWeight: FontWeight.w700, fontSize: 11)),
                            )),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isActive ? AdminTheme.success : AdminTheme.error).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(isActive ? strings.t('active') : strings.t('inactive'), style: TextStyle(color: isActive ? AdminTheme.success : AdminTheme.error, fontWeight: FontWeight.w700, fontSize: 11)),
                            )),
                            DataCell(Text(
                              user['lastLoginAt'] != null
                                  ? user['lastLoginAt'].toString().split('T').first
                                  : strings.t('never'),
                              style: TextStyle(fontSize: 12, color: AdminTheme.textSecondaryFor(Theme.of(context).brightness)),
                            )),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(isActive ? Icons.person_off_outlined : Icons.person_outlined, size: 18, color: isActive ? AdminTheme.error : AdminTheme.success),
                                  tooltip: isActive ? strings.t('deactivate') : strings.t('activate'),
                                  onPressed: () => _toggleActive(user),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.lock_reset_outlined, size: 18, color: AdminTheme.warning),
                                  tooltip: strings.t('resetPassword'),
                                  onPressed: () => _resetPassword(user),
                                ),
                              ],
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
