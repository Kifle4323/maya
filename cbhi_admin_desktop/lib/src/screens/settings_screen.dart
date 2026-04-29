import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../i18n/app_localizations.dart';
import '../theme/admin_theme.dart';
import '../widgets/error_state_widget.dart';
import 'totp_setup_screen.dart';

/// Redesigned Settings Screen — sectioned cards for General, Notifications,
/// Premium Configuration, Claim Rules, and Security.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.repository});
  final AdminRepository repository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  String? _error;

  // Raw settings map keyed by setting key
  Map<String, Map<String, dynamic>> _settingsMap = {};

  // ── General ──────────────────────────────────────────────────────────────
  String _language = 'en';
  bool _darkMode = false; // placeholder

  // ── Notifications ─────────────────────────────────────────────────────────
  bool _smsEnabled = true;
  bool _pushEnabled = true;

  // ── Premium Configuration ─────────────────────────────────────────────────
  final _lowIncomeCtrl = TextEditingController();
  final _middleIncomeCtrl = TextEditingController();
  final _highIncomeCtrl = TextEditingController();
  final _additionalAdultCtrl = TextEditingController();

  // ── Claim Rules ───────────────────────────────────────────────────────────
  final _annualCeilingCtrl = TextEditingController();
  final _waitingPeriodCtrl = TextEditingController();

  // Per-section save state
  final Map<String, bool> _saving = {};
  final Map<String, String?> _saveMessages = {};
  final Map<String, bool> _saveSuccess = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _lowIncomeCtrl.dispose();
    _middleIncomeCtrl.dispose();
    _highIncomeCtrl.dispose();
    _additionalAdultCtrl.dispose();
    _annualCeilingCtrl.dispose();
    _waitingPeriodCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final settings = await widget.repository.getConfiguration();
      final map = <String, Map<String, dynamic>>{};
      for (final s in settings) {
        final key = s['key']?.toString() ?? '';
        if (key.isNotEmpty) map[key] = s;
      }
      _settingsMap = map;
      _populateFields();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _populateFields() {
    // General
    final langSetting = _settingsMap['app_language']?['value'];
    if (langSetting is Map) {
      _language = langSetting['code']?.toString() ?? 'en';
    }

    // Notifications
    final notifSetting = _settingsMap['notifications']?['value'];
    if (notifSetting is Map) {
      _smsEnabled = notifSetting['smsEnabled'] as bool? ?? true;
      _pushEnabled = notifSetting['pushEnabled'] as bool? ?? true;
    }

    // Premium
    final premiumSetting = _settingsMap['premium_rates']?['value'];
    if (premiumSetting is Map) {
      _lowIncomeCtrl.text = '${premiumSetting['lowIncome'] ?? 120}';
      _middleIncomeCtrl.text = '${premiumSetting['middleIncome'] ?? 240}';
      _highIncomeCtrl.text = '${premiumSetting['highIncome'] ?? 480}';
      _additionalAdultCtrl.text = '${premiumSetting['additionalAdult'] ?? 60}';
    } else {
      _lowIncomeCtrl.text = '120';
      _middleIncomeCtrl.text = '240';
      _highIncomeCtrl.text = '480';
      _additionalAdultCtrl.text = '60';
    }

    // Claim rules
    final claimSetting = _settingsMap['claim_rules']?['value'];
    if (claimSetting is Map) {
      _annualCeilingCtrl.text = '${claimSetting['annualCeiling'] ?? 5000}';
      _waitingPeriodCtrl.text = '${claimSetting['waitingPeriodDays'] ?? 30}';
    } else {
      _annualCeilingCtrl.text = '5000';
      _waitingPeriodCtrl.text = '30';
    }
  }

  Future<void> _saveSection(
    String sectionKey,
    String settingKey,
    Map<String, dynamic> value,
  ) async {
    setState(() {
      _saving[sectionKey] = true;
      _saveMessages[sectionKey] = null;
    });
    try {
      await widget.repository.updateConfiguration(
        key: settingKey,
        value: value,
      );
      if (mounted) {
        setState(() {
          _saveSuccess[sectionKey] = true;
          _saveMessages[sectionKey] = 'Saved successfully';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saveSuccess[sectionKey] = false;
          _saveMessages[sectionKey] =
              e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _saving[sectionKey] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AdminTheme.primary));
    }
    if (_error != null) {
      return ErrorStateWidget(message: _error!, onRetry: _load);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.t('systemConfiguration'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AdminTheme.textPrimaryFor(Theme.of(context).brightness),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                strings.t('manageSystemSettings'),
                style: TextStyle(
                    color: AdminTheme.textSecondaryFor(Theme.of(context).brightness), fontSize: 13),
              ),
              const SizedBox(height: 28),

              // ── General ─────────────────────────────────────────────────
              _SettingsCard(
                icon: Icons.tune_outlined,
                title: 'General',
                sectionKey: 'general',
                saving: _saving['general'] == true,
                message: _saveMessages['general'],
                isSuccess: _saveSuccess['general'] ?? false,
                onSave: () => _saveSection('general', 'app_language', {
                  'code': _language,
                }),
                child: Column(
                  children: [
                    _SettingsRow(
                      label: strings.t('language'),
                      child: DropdownButtonFormField<String>(
                        initialValue: _language,
                        decoration: const InputDecoration(isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(
                              value: 'am', child: Text('አማርኛ (Amharic)')),
                          DropdownMenuItem(
                              value: 'om',
                              child: Text('Afaan Oromoo')),
                        ],
                        onChanged: (v) =>
                            setState(() => _language = v ?? _language),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SettingsRow(
                      label: 'Theme',
                      child: Row(
                        children: [
                          Switch(
                            value: _darkMode,
                            onChanged: (v) => setState(() => _darkMode = v),
                            activeTrackColor: AdminTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _darkMode ? 'Dark mode' : 'Light mode',
                            style: TextStyle(
                                color: AdminTheme.textSecondaryFor(Theme.of(context).brightness), fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AdminTheme.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Coming soon',
                              style: TextStyle(
                                  color: AdminTheme.warning,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Notifications ────────────────────────────────────────────
              _SettingsCard(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                sectionKey: 'notifications',
                saving: _saving['notifications'] == true,
                message: _saveMessages['notifications'],
                isSuccess: _saveSuccess['notifications'] ?? false,
                onSave: () => _saveSection(
                  'notifications',
                  'notifications',
                  {
                    'smsEnabled': _smsEnabled,
                    'pushEnabled': _pushEnabled,
                  },
                ),
                child: Column(
                  children: [
                    _SettingsRow(
                      label: 'SMS Notifications',
                      child: Row(
                        children: [
                          Switch(
                            value: _smsEnabled,
                            onChanged: (v) =>
                                setState(() => _smsEnabled = v),
                            activeTrackColor: AdminTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _smsEnabled ? 'Enabled' : 'Disabled',
                            style: TextStyle(
                              color: _smsEnabled
                                  ? AdminTheme.success
                                  : AdminTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SettingsRow(
                      label: 'Push Notifications',
                      child: Row(
                        children: [
                          Switch(
                            value: _pushEnabled,
                            onChanged: (v) =>
                                setState(() => _pushEnabled = v),
                            activeTrackColor: AdminTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _pushEnabled ? 'Enabled' : 'Disabled',
                            style: TextStyle(
                              color: _pushEnabled
                                  ? AdminTheme.success
                                  : AdminTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Premium Configuration ─────────────────────────────────────
              _SettingsCard(
                icon: Icons.payments_outlined,
                title: 'Premium Configuration',
                sectionKey: 'premium',
                saving: _saving['premium'] == true,
                message: _saveMessages['premium'],
                isSuccess: _saveSuccess['premium'] ?? false,
                onSave: () => _saveSection(
                  'premium',
                  'premium_rates',
                  {
                    'lowIncome':
                        double.tryParse(_lowIncomeCtrl.text) ?? 120,
                    'middleIncome':
                        double.tryParse(_middleIncomeCtrl.text) ?? 240,
                    'highIncome':
                        double.tryParse(_highIncomeCtrl.text) ?? 480,
                    'additionalAdult':
                        double.tryParse(_additionalAdultCtrl.text) ?? 60,
                  },
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _LabeledField(
                            label: 'Low Income Tier (ETB/yr)',
                            controller: _lowIncomeCtrl,
                            suffix: 'ETB',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _LabeledField(
                            label: 'Middle Income Tier (ETB/yr)',
                            controller: _middleIncomeCtrl,
                            suffix: 'ETB',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _LabeledField(
                            label: 'High Income Tier (ETB/yr)',
                            controller: _highIncomeCtrl,
                            suffix: 'ETB',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _LabeledField(
                            label: 'Additional Adult Rate (ETB/yr)',
                            controller: _additionalAdultCtrl,
                            suffix: 'ETB',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Claim Rules ───────────────────────────────────────────────
              _SettingsCard(
                icon: Icons.rule_outlined,
                title: 'Claim Rules',
                sectionKey: 'claimRules',
                saving: _saving['claimRules'] == true,
                message: _saveMessages['claimRules'],
                isSuccess: _saveSuccess['claimRules'] ?? false,
                onSave: () => _saveSection(
                  'claimRules',
                  'claim_rules',
                  {
                    'annualCeiling':
                        double.tryParse(_annualCeilingCtrl.text) ?? 5000,
                    'waitingPeriodDays':
                        int.tryParse(_waitingPeriodCtrl.text) ?? 30,
                  },
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _LabeledField(
                        label: 'Annual Ceiling (ETB)',
                        controller: _annualCeilingCtrl,
                        suffix: 'ETB',
                        hint: '0 = unlimited',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _LabeledField(
                        label: 'Waiting Period (days)',
                        controller: _waitingPeriodCtrl,
                        suffix: 'days',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Security ──────────────────────────────────────────────────
              _SecurityCard(repository: widget.repository),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Settings Card ─────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.sectionKey,
    required this.saving,
    required this.message,
    required this.isSuccess,
    required this.onSave,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String sectionKey;
  final bool saving;
  final String? message;
  final bool isSuccess;
  final VoidCallback onSave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminTheme.cardBgFor(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AdminTheme.primary.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade100),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AdminTheme.primary, size: 18),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AdminTheme.textPrimaryFor(Theme.of(context).brightness),
                  ),
                ),
              ],
            ),
          ),

          // Card body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                child,
                const SizedBox(height: 20),

                // Save feedback
                if (message != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: (isSuccess ? AdminTheme.success : AdminTheme.error)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSuccess
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          size: 14,
                          color: isSuccess
                              ? AdminTheme.success
                              : AdminTheme.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          message!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSuccess
                                ? AdminTheme.success
                                : AdminTheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Save button
                FilledButton.icon(
                  onPressed: saving ? null : onSave,
                  icon: saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 16),
                  label: Text(saving ? 'Saving…' : 'Save'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AdminTheme.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
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

// ── Security Card ─────────────────────────────────────────────────────────

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.repository});
  final AdminRepository repository;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminTheme.cardBgFor(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AdminTheme.primary.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade100),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.security_outlined,
                    color: AdminTheme.primary, size: 18),
                SizedBox(width: 10),
                Text(
                  'Security',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AdminTheme.textPrimaryFor(Theme.of(context).brightness),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _SecurityAction(
                  icon: Icons.lock_reset_outlined,
                  title: 'Change Password',
                  subtitle: 'Update your admin account password',
                  buttonLabel: 'Change Password',
                  onTap: () => _showChangePasswordDialog(context),
                ),
                const Divider(height: 24),
                _SecurityAction(
                  icon: Icons.verified_user_outlined,
                  title: 'Two-Factor Authentication (TOTP)',
                  subtitle:
                      'Set up or reconfigure your authenticator app for 2FA',
                  buttonLabel: 'Setup 2FA',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => TotpSetupScreen(
                        repository: repository,
                        onComplete: () => Navigator.pop(context),
                      ),
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

  void _showChangePasswordDialog(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_reset_outlined, color: AdminTheme.primary),
            SizedBox(width: 8),
            Text('Change Password'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
                backgroundColor: AdminTheme.primary),
            child: const Text('Update Password'),
          ),
        ],
      ),
    );
  }
}

class _SecurityAction extends StatelessWidget {
  const _SecurityAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AdminTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AdminTheme.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AdminTheme.textPrimaryFor(Theme.of(context).brightness),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: AdminTheme.textSecondaryFor(Theme.of(context).brightness),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: AdminTheme.primary,
            side: const BorderSide(color: AdminTheme.primary),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: Text(buttonLabel, style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 200,
          child: Text(
            label,
            style: TextStyle(
              color: AdminTheme.textSecondaryFor(Theme.of(context).brightness),
              fontSize: 13,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.suffix,
    this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String? suffix;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AdminTheme.textSecondaryFor(Theme.of(context).brightness),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixText: suffix,
            hintText: hint,
            isDense: true,
          ),
        ),
      ],
    );
  }
}
