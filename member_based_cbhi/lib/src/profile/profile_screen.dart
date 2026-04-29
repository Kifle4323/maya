import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_cubit.dart';
import '../cbhi_data.dart';
import '../cbhi_localizations.dart';
import '../cbhi_state.dart';
import '../shared/premium_widgets.dart';
import '../benefits/benefit_package_screen.dart';
import '../coverage/coverage_history_screen.dart';
import '../grievances/grievance_screen.dart';
import '../indigent/indigent_application_screen.dart';
import '../shared/biometric_service.dart';
import '../shared/help_screen.dart';
import '../shared/passkey_service.dart';
import '../theme/app_theme.dart';

/// Profile screen — M3 HealthShield account settings redesign.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final session = authState.session;
    final snapshot =
        context.watch<AppCubit>().state.snapshot ?? CbhiSnapshot.empty();
    final strings = CbhiLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Page title
        Text(
          strings.t('accountSettings'),
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 20),

        // Profile header card
        _M3ProfileHeaderCard(
          session: session,
          snapshot: snapshot,
          strings: strings,
        ),

        const SizedBox(height: 16),

        // Plan & Coverage
        _M3SettingsSection(
          icon: Icons.health_and_safety_outlined,
          title: strings.t('planAndCoverage'),
          children: [
            _M3SettingsTile(
              icon: Icons.history_outlined,
              label: strings.t('coverageHistory'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CoverageHistoryScreen(repository: context.read<AppCubit>().repository),
              )),
            ),
            if (!authState.isFamilyMember && session != null) ...[
              _M3SettingsTile(
                icon: Icons.health_and_safety_outlined,
                label: strings.t('benefitPackageTitle'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BenefitPackageScreen(repository: context.read<AppCubit>().repository),
                )),
              ),
              _M3SettingsTile(
                icon: Icons.volunteer_activism_outlined,
                label: strings.t('indigentApplicationMenuTitle'),
                onTap: () async {
                  final appCubit = context.read<AppCubit>();
                  final repo = appCubit.repository;
                  final uid = session.user.id;
                  final memberCount = snapshot.familyMembers.isNotEmpty
                      ? snapshot.familyMembers.length
                      : (double.tryParse(snapshot.household['memberCount']?.toString() ?? '1')?.toInt() ?? 1);
                  final employment =
                      snapshot.household['headEmploymentStatus']?.toString() ??
                          snapshot.household['employmentStatus']?.toString() ??
                          'unemployed';
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (ctx) => IndigentApplicationScreen(
                        repository: repo,
                        userId: uid,
                        familySize: memberCount,
                        employmentStatus: employment,
                        onSubmitted: (result) {
                          Navigator.of(ctx).pop();
                          context.read<AppCubit>().sync();
                        },
                      ),
                    ),
                  );
                },
              ),
              _M3SettingsTile(
                icon: Icons.gavel_outlined,
                label: strings.t('grievancesTitle'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => GrievanceScreen(repository: context.read<AppCubit>().repository),
                )),
              ),
            ],
          ],
        ),

        const SizedBox(height: 16),

        // Preferences
        _M3SettingsSection(
          icon: Icons.tune_outlined,
          title: strings.t('preferences'),
          children: [
            // Language
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.language_outlined, size: 20, color: AppTheme.textSecondaryFor(Theme.of(context).brightness)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.t('language'),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15),
                        ),
                        Text(
                          _currentLanguageLabel(context),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showLanguageSheet(context, strings),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.m3Primary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.m3Primary,
                      ),
                    ),
                    child: Text(strings.t('change')),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppTheme.m3OutlineVariant.withValues(alpha: 0.3), indent: 16),
            // Appearance
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette_outlined, size: 20, color: AppTheme.textSecondaryFor(Theme.of(context).brightness)),
                      const SizedBox(width: 12),
                      Text(strings.t('appearance'), style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceHighestFor(Theme.of(context).brightness),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _AppearanceBtn(
                          label: strings.t('system'),
                          selected: context.watch<AppCubit>().state.themeMode == ThemeMode.system,
                          onTap: () => context.read<AppCubit>().setThemeMode(ThemeMode.system),
                        ),
                        _AppearanceBtn(
                          label: strings.t('light'),
                          selected: context.watch<AppCubit>().state.themeMode == ThemeMode.light,
                          onTap: () => context.read<AppCubit>().setThemeMode(ThemeMode.light),
                        ),
                        _AppearanceBtn(
                          label: strings.t('dark'),
                          selected: context.watch<AppCubit>().state.themeMode == ThemeMode.dark,
                          onTap: () => context.read<AppCubit>().setThemeMode(ThemeMode.dark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Security
        _M3SettingsSection(
          icon: Icons.security_outlined,
          title: strings.t('security'),
          children: [
            // Passkeys (web only)
            if (kIsWeb) ...[
              _PasskeysSection(repository: context.read<AppCubit>().repository),
              Divider(height: 1, color: AppTheme.m3OutlineVariant.withValues(alpha: 0.3), indent: 16),
            ],
            // Biometric
            const _BiometricToggle(),
            Divider(height: 1, color: AppTheme.m3OutlineVariant.withValues(alpha: 0.3), indent: 16),
            // Change password
            _M3SettingsTile(
              icon: Icons.lock_reset_outlined,
              label: strings.t('changePassword'),
              onTap: () => _showChangePasswordDialog(context),
            ),
            _M3SettingsTile(
              icon: Icons.help_outline,
              label: strings.t('helpAndFaq'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HelpScreen()),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Sign out
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async => context.read<AuthCubit>().logout(),
            icon: Icon(Icons.logout),
            label: Text(strings.t('signOut')),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimaryFor(Theme.of(context).brightness),
              side: BorderSide(color: AppTheme.m3OutlineVariant),
              shape: const StadiumBorder(),
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: AppTheme.surfaceBgFor(Theme.of(context).brightness),
            ),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  String _currentLanguageLabel(BuildContext context) {
    final code = context.watch<AppCubit>().state.locale.languageCode;
    return switch (code) {
      'en' => 'English (US)',
      'am' => 'አማርኛ',
      'om' => 'Afaan Oromoo',
      _ => code.toUpperCase(),
    };
  }

  void _showLanguageSheet(BuildContext context, dynamic strings) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.t('language'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ...CbhiLocalizations.supportedLocales.map((locale) {
              final isSelected = context.read<AppCubit>().state.locale.languageCode == locale.languageCode;
              final label = switch (locale.languageCode) {
                'en' => 'English',
                'am' => 'አማርኛ',
                'om' => 'Afaan Oromoo',
                _ => locale.languageCode.toUpperCase(),
              };
              return ListTile(
                title: Text(label),
                trailing: isSelected ? Icon(Icons.check, color: AppTheme.m3Primary) : null,
                onTap: () {
                  context.read<AppCubit>().setLocale(locale);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _formatDateLabel(dynamic value) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty) return 'Not available';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final month = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ][parsed.month - 1];
  return '${parsed.day.toString().padLeft(2, '0')} $month ${parsed.year}';
}

Future<void> _showChangePasswordDialog(BuildContext context) async {
  final strings = CbhiLocalizations.of(context);
  final currentCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  String? error;
  bool usingTempCode = false;
  String? tempCode;

  // Check if user has a temp password stored
  final prefs = await SharedPreferences.getInstance();
  final hasTempPassword = prefs.getBool('cbhi_has_temp_password') ?? false;
  if (hasTempPassword) {
    tempCode = prefs.getString('cbhi_setup_code') ??
        prefs.getString('cbhi_temp_password');
  }

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(strings.t('changePassword')),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(error!,
                      style: TextStyle(color: AppTheme.error, fontSize: 13)),
                ),
              // Toggle for temp code users
              if (hasTempPassword && tempCode != null) ...[
                Row(
                  children: [
                    Checkbox(
                      value: usingTempCode,
                      onChanged: (v) {
                        setDialogState(() {
                          usingTempCode = v ?? false;
                          if (usingTempCode) {
                            currentCtrl.text = tempCode!;
                          } else {
                            currentCtrl.clear();
                          }
                        });
                      },
                    ),
                    Expanded(
                      child: Text(
                        strings.t('usingTempCode'),
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              // Current password field
              TextField(
                controller: currentCtrl,
                obscureText: !usingTempCode,
                readOnly: usingTempCode,
                decoration: InputDecoration(
                  labelText: usingTempCode
                      ? strings.t('tempCodePreFilled')
                      : strings.t('currentPassword'),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: strings.t('newPassword'),
                    prefixIcon: Icon(Icons.lock_reset_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: strings.t('confirmPassword'),
                    prefixIcon: Icon(Icons.lock_outline)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.t('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              if (newCtrl.text.length < 6) {
                setDialogState(() => error = strings.t('passwordTooShort'));
                return;
              }
              if (newCtrl.text != confirmCtrl.text) {
                setDialogState(() => error = strings.t('passwordsDoNotMatch'));
                return;
              }
              try {
                await ctx.read<AppCubit>().repository.setInitialPasswordDirect(
                      password: newCtrl.text,
                    );
                // Clear all setup code flags — session stays active (no tokenVersion bump)
                final p = await SharedPreferences.getInstance();
                await p.remove('cbhi_setup_code');
                await p.remove('cbhi_temp_password');
                await p.remove('cbhi_has_temp_password');

                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(strings.t('passwordChanged')),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              } catch (e) {
                setDialogState(
                    () => error = e.toString().replaceFirst('Exception: ', ''));
              }
            },
            child: Text(strings.t('save')),
          ),
        ],
      ),
    ),
  );
}

// ── Private widgets ───────────────────────────────────────────────────────────

class _BiometricToggle extends StatefulWidget {
  const _BiometricToggle();

  @override
  State<_BiometricToggle> createState() => _BiometricToggleState();
}

class _BiometricToggleState extends State<_BiometricToggle> {
  bool _available = false;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isBiometricEnabled();
    if (mounted) setState(() { _available = available; _enabled = enabled; });
  }

  Future<void> _toggle(bool value, BuildContext ctx) async {
    if (value) {
      final session = ctx.read<AuthCubit>().state.session;
      if (session == null) return;
      // Parse token expiry from session so BiometricService can validate it
      final tokenExpiry = DateTime.tryParse(session.expiresAt);
      final ok = await BiometricService.enableBiometric(
        session.accessToken,
        tokenExpiry: tokenExpiry,
      );
      if (mounted) setState(() => _enabled = ok);
    } else {
      await BiometricService.disableBiometric();
      if (mounted) setState(() => _enabled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    return GlassCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.fingerprint, color: AppTheme.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Builder(builder: (ctx) {
              final strings = CbhiLocalizations.of(ctx);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.t('biometricLogin'), style: Theme.of(ctx).textTheme.titleMedium),
                  Text(strings.t('useFingerprintOrFace'),
                      style: Theme.of(ctx).textTheme.bodySmall),
                ],
              );
            }),
          ),
          Switch(
            value: _enabled,
            onChanged: (v) => _toggle(v, context),
            activeThumbColor: AppTheme.accent,
          ),
        ],
      ),
    );
  }
}

// ── Passkeys section (web only) ───────────────────────────────────────────────

class _PasskeysSection extends StatefulWidget {
  const _PasskeysSection({required this.repository});

  final CbhiRepository repository;

  @override
  State<_PasskeysSection> createState() => _PasskeysSectionState();
}

class _PasskeysSectionState extends State<_PasskeysSection> {
  List<Map<String, dynamic>> _credentials = [];
  bool _loading = true;
  bool _adding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final creds = await widget.repository.getPasskeyCredentials();
      if (mounted) setState(() { _credentials = creds; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _addPasskey(BuildContext ctx) async {
    final strings = CbhiLocalizations.of(ctx);
    final session = ctx.read<AuthCubit>().state.session;
    if (session == null) return;

    setState(() { _adding = true; _error = null; });
    try {
      // 1. Get registration options from backend
      final options = await widget.repository.getPasskeyRegisterOptions();

      final challenge = options['challenge']?.toString() ?? '';
      final rpId = options['rp']?['id']?.toString() ??
          options['rpId']?.toString() ?? '';
      final userId = session.user.id;
      final userName = session.user.displayName;

      // 2. Call PasskeyService.register() to invoke navigator.credentials.create()
      final attestation = await PasskeyService.register(
        userId: userId,
        userName: userName,
        challenge: challenge,
        rpId: rpId,
      );

      if (attestation == null) {
        // User cancelled or passkey not supported
        if (mounted && ctx.mounted) {
          setState(() { _adding = false; });
          ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
            SnackBar(content: Text(strings.t('passkeyNotSupported'))),
          );
        }
        return;
      }

      // 3. Send attestation to backend
      await widget.repository.registerPasskey({
        'credentialId': attestation.credentialId,
        'clientDataJSON': attestation.clientDataJSON,
        'attestationObject': attestation.attestationObject,
      });

      if (mounted && ctx.mounted) {
        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
          SnackBar(
            content: Text(strings.t('passkeyRegistered')),
            backgroundColor: AppTheme.success,
          ),
        );
        await _loadCredentials();
      }
    } catch (e) {
      if (mounted && ctx.mounted) {
        setState(() {
          _adding = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
          SnackBar(
            content: Text(strings.t('passkeyAddFailed')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _deletePasskey(BuildContext ctx, String credentialId) async {
    final strings = CbhiLocalizations.of(ctx);

    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text(strings.t('passkeyDeleteConfirmTitle')),
        content: Text(strings.t('passkeyDeleteConfirmMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(strings.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text(strings.t('deletePasskey')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.repository.removePasskey(credentialId);
      if (mounted && ctx.mounted) {
        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
          SnackBar(content: Text(strings.t('passkeyDeleted'))),
        );
        await _loadCredentials();
      }
    } catch (e) {
      if (mounted && ctx.mounted) {
        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.key_outlined, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.t('passkeysSection'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      strings.t('passkeysSubtitle'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryFor(Theme.of(context).brightness),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Error message
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: AppTheme.error, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Credentials list
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              ),
            )
          else if (_credentials.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppTheme.textSecondaryFor(Theme.of(context).brightness)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.t('noPasskeysRegistered'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryFor(Theme.of(context).brightness),
                          ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...(_credentials.map((cred) {
              final credentialId = cred['credentialId']?.toString() ?? '';
              final deviceName = cred['deviceName']?.toString();
              final lastUsedAt = cred['lastUsedAt']?.toString();
              final displayName = (deviceName != null && deviceName.isNotEmpty)
                  ? deviceName
                  : strings.t('passkeyDevice');
              final lastUsed = lastUsedAt != null && lastUsedAt.isNotEmpty
                  ? _formatDateLabel(lastUsedAt)
                  : null;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.security_outlined,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            if (lastUsed != null)
                              Text(
                                lastUsed,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textSecondaryFor(Theme.of(context).brightness),
                                    ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: AppTheme.error,
                          size: 20,
                        ),
                        tooltip: strings.t('deletePasskey'),
                        onPressed: credentialId.isEmpty
                            ? null
                            : () => _deletePasskey(context, credentialId),
                      ),
                    ],
                  ),
                ),
              );
            })),

          const SizedBox(height: 8),

          // Add passkey button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _adding ? null : () => _addPasskey(context),
              icon: _adding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    )
                  : Icon(Icons.add, size: 18),
              label: Text(strings.t('addPasskey')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── M3 Profile Header Card ────────────────────────────────────────────────────

class _M3ProfileHeaderCard extends StatelessWidget {
  const _M3ProfileHeaderCard({
    required this.session,
    required this.snapshot,
    required this.strings,
  });

  final dynamic session;
  final CbhiSnapshot snapshot;
  final dynamic strings;

  @override
  Widget build(BuildContext context) {
    final displayName = session?.user?.displayName?.toString() ?? strings.t('member');
    final memberId = snapshot.viewerMembershipId;
    final coverageStatus = snapshot.coverageStatus;
    final isHead = !(context.read<AuthCubit>().state.isFamilyMember);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceBgFor(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.m3OutlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          ProfileAvatar(
            name: displayName,
            photoPath: snapshot.viewerPhotoPath,
            repository: context.read<AppCubit>().repository,
            radius: 40,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (memberId.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${strings.t('memberIdLabel')}: $memberId',
                    style: TextStyle(
                      color: AppTheme.textSecondaryFor(Theme.of(context).brightness),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (isHead)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.m3TertiaryContainer.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppTheme.m3TertiaryContainer.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          strings.t('headOfHousehold'),
                          style: TextStyle(
                            color: AppTheme.m3TertiaryContainer,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.m3Primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppTheme.m3Primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        strings.enumValue(coverageStatus),
                        style: TextStyle(
                          color: AppTheme.m3Primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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

// ── M3 Settings Section ───────────────────────────────────────────────────────

class _M3SettingsSection extends StatelessWidget {
  const _M3SettingsSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceBgFor(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.m3OutlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: AppTheme.cardBgFor(Theme.of(context).brightness).withValues(alpha: 0.5),
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.m3OutlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.m3Primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.15,
                  ),
                ),
              ],
            ),
          ),
          // Children
          ...children,
        ],
      ),
    );
  }
}

// ── M3 Settings Tile ──────────────────────────────────────────────────────────

class _M3SettingsTile extends StatelessWidget {
  const _M3SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.textSecondaryFor(Theme.of(context).brightness)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppTheme.textSecondaryFor(Theme.of(context).brightness),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Appearance Button ─────────────────────────────────────────────────────────

class _AppearanceBtn extends StatelessWidget {
  const _AppearanceBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.cardBgFor(Theme.of(context).brightness) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ── GlassCard (legacy compat) ─────────────────────────────────────────────────

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceBgFor(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.m3OutlineVariant.withValues(alpha: 0.3),
        ),
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }
}
