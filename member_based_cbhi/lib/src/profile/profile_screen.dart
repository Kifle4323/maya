import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth/auth_cubit.dart';
import '../cbhi_data.dart';
import '../cbhi_localizations.dart';
import '../cbhi_state.dart';
import '../benefits/benefit_package_screen.dart';
import '../coverage/coverage_history_screen.dart';
import '../grievances/grievance_screen.dart';
import '../indigent/indigent_application_screen.dart';
import '../shared/animated_widgets.dart';
import '../shared/biometric_service.dart';
import '../shared/help_screen.dart';
import '../shared/passkey_service.dart';
import '../shared/premium_widgets.dart';
import '../theme/app_theme.dart';

/// Profile screen — settings, language, dark mode, biometric, account actions.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final session = authState.session;
    final snapshot =
        context.watch<AppCubit>().state.snapshot ?? CbhiSnapshot.empty();
    final member = snapshot.currentMember;
    final eligibility = snapshot.eligibility ?? const <String, dynamic>{};
    final strings = CbhiLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      children: [
        // Profile header
        Container(
          decoration: BoxDecoration(
            gradient: AppTheme.heroGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
          ),
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              // ProfileAvatar with initials fallback — no hardcoded Icons.person
              ProfileAvatar(
                name: session?.user.displayName ?? 'Member',
                radius: 30,
                backgroundColor: Colors.white.withValues(alpha: 0.20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session?.user.displayName ?? 'Member',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((session?.user.phoneNumber ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        session!.user.phoneNumber!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                      ),
                    ],
                    if ((session?.user.membershipId ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${session!.user.membershipId}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 500.ms)
            .slideY(begin: 0.08, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),

        const SizedBox(height: 20),

        // Profile details card
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.t('profileDetails'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              _ProfileRow(
                icon: Icons.home_work_outlined,
                label: strings.t('household'),
                value: snapshot.householdCode.isEmpty ? strings.t('notSynced') : snapshot.householdCode,
              ),
              _ProfileRow(
                icon: Icons.verified_outlined,
                label: strings.t('coverage'),
                value: snapshot.coverageStatus,
              ),
              if (member?.dateOfBirth != null)
                _ProfileRow(
                  icon: Icons.cake_outlined,
                  label: strings.t('dobLabel'),
                  value: _formatDateLabel(member?.dateOfBirth),
                ),
              if ((member?.relationshipToHouseholdHead ?? '').isNotEmpty)
                _ProfileRow(
                  icon: Icons.people_outline,
                  label: strings.t('relationshipToHouseholdHead'),
                  value: member!.relationshipToHouseholdHead!,
                ),
              _ProfileRow(
                icon: Icons.verified_user_outlined,
                label: strings.t('eligibility'),
                value: eligibility['approved'] == true ? strings.t('eligible') : strings.t('pending'),
              ),
              if ((eligibility['reason']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Text(eligibility['reason'].toString(),
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
              const SizedBox(height: 8),
              StatusBadge(
                label: eligibility['canLoginIndependently'] == true
                    ? strings.t('independentAccessLabel')
                    : strings.t('householdManagedLabel'),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: 150.ms)
            .slideY(begin: 0.06, end: 0, duration: 400.ms, delay: 150.ms),

        const SizedBox(height: 20),

        if (!authState.isFamilyMember && session != null) ...[
          GlassCard(
            child: ListTile(
              leading: Icon(Icons.volunteer_activism_outlined,
                  color: Theme.of(context).colorScheme.primary),
              title: Text(strings.t('indigentApplicationMenuTitle')),
              subtitle: Text(strings.t('indigentApplicationMenuSubtitle')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final appCubit = context.read<AppCubit>();
                final repo = appCubit.repository;
                final uid = session.user.id;
                final memberCount = snapshot.familyMembers.isNotEmpty
                    ? snapshot.familyMembers.length
                    : ((snapshot.household['memberCount'] as num?)?.toInt() ?? 1);
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
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          SnackBar(content: Text(strings.t('indigentApplicationSubmitted'))),
                        );
                        context.read<AppCubit>().sync();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Benefit Package — what's covered
          GlassCard(
            child: ListTile(
              leading: const Icon(Icons.health_and_safety_outlined, color: AppTheme.primary),
              title: Text(strings.t('benefitPackageTitle')),
              subtitle: Text(strings.t('benefitPackageInfo')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BenefitPackageScreen(repository: context.read<AppCubit>().repository),
              )),
            ),
          ),
          const SizedBox(height: 12),

          // Coverage History
          GlassCard(
            child: ListTile(
              leading: const Icon(Icons.history_outlined, color: AppTheme.accent),
              title: Text(strings.t('coverageHistory')),
              subtitle: Text(strings.t('noCoverageHistorySubtitle')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CoverageHistoryScreen(repository: context.read<AppCubit>().repository),
              )),
            ),
          ),
          const SizedBox(height: 12),

          // Grievances
          GlassCard(
            child: ListTile(
              leading: const Icon(Icons.gavel_outlined, color: AppTheme.warning),
              title: Text(strings.t('grievancesTitle')),
              subtitle: Text(strings.t('noGrievancesSubtitle')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => GrievanceScreen(repository: context.read<AppCubit>().repository),
              )),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Language selection
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.translate, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(strings.t('language'), style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: CbhiLocalizations.supportedLocales.map((locale) {
                  final isSelected =
                      context.watch<AppCubit>().state.locale.languageCode ==
                          locale.languageCode;
                  final label = switch (locale.languageCode) {
                    'en' => 'English',
                    'am' => 'አማርኛ',
                    'om' => 'Afaan Oromoo',
                    _ => locale.languageCode.toUpperCase(),
                  };
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) => context.read<AppCubit>().setLocale(locale),
                  );
                }).toList(growable: false),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: 250.ms)
            .slideY(begin: 0.06, end: 0, duration: 400.ms, delay: 250.ms),

        const SizedBox(height: 16),

        // Dark mode toggle
        GlassCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.dark_mode_outlined, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(strings.t('darkMode'), style: Theme.of(context).textTheme.titleMedium),
                    Text(strings.t('easierOnEyes'),
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Switch(
                value: context.watch<AppCubit>().state.isDarkMode,
                onChanged: (_) => context.read<AppCubit>().toggleDarkMode(),
                activeThumbColor: AppTheme.primary,
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: 300.ms)
            .slideY(begin: 0.06, end: 0, duration: 400.ms, delay: 300.ms),

        const SizedBox(height: 16),

        // Biometric login toggle
        const _BiometricToggle()
            .animate()
            .fadeIn(duration: 400.ms, delay: 320.ms)
            .slideY(begin: 0.06, end: 0, duration: 400.ms, delay: 320.ms),

        const SizedBox(height: 16),

        // Passkeys section (web only)
        if (kIsWeb) ...[
          _PasskeysSection(repository: context.read<AppCubit>().repository)
              .animate()
              .fadeIn(duration: 400.ms, delay: 335.ms)
              .slideY(begin: 0.06, end: 0, duration: 400.ms, delay: 335.ms),
          const SizedBox(height: 16),
        ],

        // App info card
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.info_outline, color: AppTheme.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(strings.t('about'), style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              _ProfileRow(
                icon: Icons.verified_outlined,
                label: strings.t('platform'),
                value: strings.t('platformVersion'),
              ),
              _ProfileRow(
                icon: Icons.account_balance_outlined,
                label: strings.t('authority'),
                value: strings.t('ehia'),
              ),
              _ProfileRow(
                icon: Icons.local_hospital_outlined,
                label: strings.t('ministry'),
                value: strings.t('fmoh'),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: 350.ms)
            .slideY(begin: 0.06, end: 0, duration: 400.ms, delay: 350.ms),

        const SizedBox(height: 24),

        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HelpScreen()),
          ),
          icon: const Icon(Icons.help_outline),
          label: Text(strings.t('helpAndFaq')),
        ).animate().fadeIn(duration: 400.ms, delay: 420.ms),

        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: () => _showChangePasswordDialog(context),
          icon: const Icon(Icons.lock_reset_outlined),
          label: Text(strings.t('changePassword')),
        ).animate().fadeIn(duration: 400.ms, delay: 430.ms),

        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: () async => context.read<AuthCubit>().logout(),
          icon: const Icon(Icons.logout),
          label: Text(strings.t('signOut')),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.error,
            side: BorderSide(color: AppTheme.error.withValues(alpha: 0.5)),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 400.ms),

        const SizedBox(height: 12),

        TextButton.icon(
          onPressed: () => _showDeleteAccountDialog(context),
          icon: const Icon(Icons.delete_forever_outlined, color: AppTheme.error),
          label: Text(strings.t('deleteAccount'),
              style: const TextStyle(color: AppTheme.error)),
        ).animate().fadeIn(duration: 400.ms, delay: 460.ms),

        const SizedBox(height: 24),
      ],
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
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  String? error;

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
                      style: const TextStyle(color: AppTheme.error, fontSize: 13)),
                ),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: strings.t('newPassword')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: strings.t('confirmPassword')),
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
                await ctx.read<AppCubit>().repository.setInitialPassword(
                      password: newCtrl.text,
                    );
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

Future<void> _showDeleteAccountDialog(BuildContext context) async {
  final strings = CbhiLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(strings.t('deleteAccountTitle')),
      content: Text(strings.t('deleteAccountMessage')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(strings.t('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
          child: Text(strings.t('deleteAccount')),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await context.read<AppCubit>().repository.deleteAccount();
    if (context.mounted) await context.read<AuthCubit>().logout();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
      );
    }
  }
}

// ── Private widgets ───────────────────────────────────────────────────────────

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
          ),
        ],
      ),
    );
  }
}

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
            child: const Icon(Icons.fingerprint, color: AppTheme.accent, size: 20),
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
        if (mounted) {
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

      if (mounted) {
        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
          SnackBar(
            content: Text(strings.t('passkeyRegistered')),
            backgroundColor: AppTheme.success,
          ),
        );
        await _loadCredentials();
      }
    } catch (e) {
      if (mounted) {
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
      if (mounted) {
        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
          SnackBar(content: Text(strings.t('passkeyDeleted'))),
        );
        await _loadCredentials();
      }
    } catch (e) {
      if (mounted) {
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
                child: const Icon(Icons.key_outlined, color: AppTheme.primary, size: 20),
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
                            color: AppTheme.textSecondary,
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
                style: const TextStyle(color: AppTheme.error, fontSize: 13),
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
                  const Icon(Icons.info_outline, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.t('noPasskeysRegistered'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
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
                      const Icon(
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
                                      color: AppTheme.textSecondary,
                                    ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
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
                  : const Icon(Icons.add, size: 18),
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
