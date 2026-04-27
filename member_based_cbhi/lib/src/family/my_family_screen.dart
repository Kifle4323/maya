import 'dart:io' if (dart.library.html) '../shared/web_stubs.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../shared/native_file_image_impl.dart'
    if (dart.library.html) '../shared/native_file_image_web.dart' as impl;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth/auth_cubit.dart';
import '../cbhi_data.dart';
import '../cbhi_localizations.dart';
import '../i18n/app_localizations.dart' as i18n;
import '../theme/app_theme.dart';
import 'add_beneficiary_screen.dart';
import 'my_family_cubit.dart';

class MyFamilyScreen extends StatelessWidget {
  const MyFamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final familyCubit = context.read<MyFamilyCubit>();
    final repository = familyCubit.repository;
    final isFamilyMember = context.watch<AuthCubit>().state.isFamilyMember;

    return BlocConsumer<MyFamilyCubit, FamilyState>(
      listenWhen: (previous, current) => previous.error != current.error,
      listener: (context, state) {
        if (state.error != null && state.error!.isNotEmpty) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.error!)));
        }
      },
      builder: (context, state) {
        final strings = CbhiLocalizations.of(context);
        return _MyFamilyBody(
          state: state,
          repository: repository,
          isFamilyMember: isFamilyMember,
          strings: strings,
          familyCubit: familyCubit,
        );
      },
    );
  }
}

class _MyFamilyBody extends StatefulWidget {
  const _MyFamilyBody({
    required this.state,
    required this.repository,
    required this.isFamilyMember,
    required this.strings,
    required this.familyCubit,
  });
  final FamilyState state;
  final CbhiRepository repository;
  final bool isFamilyMember;
  final i18n.AppLocalizations strings;
  final MyFamilyCubit familyCubit;

  @override
  State<_MyFamilyBody> createState() => _MyFamilyBodyState();
}

class _MyFamilyBodyState extends State<_MyFamilyBody> {
  String _searchQuery = '';

  List<FamilyMember> get _filteredMembers {
    if (_searchQuery.isEmpty) return widget.state.members;
    final q = _searchQuery.toLowerCase();
    return widget.state.members
        .where((m) =>
            m.fullName.toLowerCase().contains(q) ||
            m.membershipId.toLowerCase().contains(q))
        .toList();
  }

  // Head of household is the primary holder
  FamilyMember? get _headMember {
    try {
      return widget.state.members.firstWhere((m) => m.isPrimaryHolder);
    } catch (_) {
      return widget.state.members.isNotEmpty ? widget.state.members.first : null;
    }
  }

  List<FamilyMember> get _dependents {
    return widget.state.members.where((m) => !m.isPrimaryHolder).toList();
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final state = widget.state;
    final repository = widget.repository;
    final isFamilyMember = widget.isFamilyMember;
    final familyCubit = widget.familyCubit;
    final filtered = _filteredMembers;
    final head = _headMember;
    final dependents = _dependents;

    return RefreshIndicator(
      onRefresh: familyCubit.load,
      color: AppTheme.m3Primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Page header + search
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFamilyMember
                          ? strings.t('householdMembers')
                          : strings.t('familyManagement'),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isFamilyMember
                          ? strings.t('viewHouseholdMembers')
                          : strings.t('manageHouseholdBeneficiaries'),
                      style: const TextStyle(
                        color: AppTheme.m3OnSurfaceVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Search bar
          if (state.members.isNotEmpty) ...[
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.m3SurfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: strings.t('searchByNameOrId'),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.m3OnSurfaceVariant, size: 20),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  hintStyle: const TextStyle(
                    color: AppTheme.m3OnSurfaceVariant,
                    fontSize: 14,
                  ),
                  fillColor: Colors.transparent,
                  filled: true,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (state.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(color: AppTheme.m3Primary),
              ),
            )
          else if (state.members.isEmpty)
            _EmptyFamilyState(
              isFamilyMember: isFamilyMember,
              repository: repository,
              familyCubit: familyCubit,
              strings: strings,
            )
          else ...[
            // Head of household bento card
            if (head != null && _searchQuery.isEmpty) ...[
              _HeadOfHouseholdCard(
                member: head,
                dependentCount: dependents.length,
                repository: repository,
                strings: strings,
              ),
              const SizedBox(height: 20),
            ],

            // Household members section
            Row(
              children: [
                Text(
                  strings.t('householdMembers'),
                  style: const TextStyle(
                    color: AppTheme.m3OnSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.15,
                  ),
                ),
                const Spacer(),
                if (!isFamilyMember)
                  FilledButton.icon(
                    onPressed: state.isSaving
                        ? null
                        : () async {
                            final changed = await Navigator.of(context)
                                .push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => AddBeneficiaryScreen(
                                      repository: repository,
                                    ),
                                  ),
                                );
                            if (changed == true && context.mounted) {
                              await familyCubit.load();
                            }
                          },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(strings.t('addMember')),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.m3Primary,
                      foregroundColor: AppTheme.m3OnPrimary,
                      shape: const StadiumBorder(),
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Member grid
            ...filtered.map(
              (member) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _M3MemberCard(
                  member: member,
                  repository: repository,
                  isFamilyMember: isFamilyMember,
                  strings: strings,
                  familyCubit: familyCubit,
                ),
              ),
            ),

            if (filtered.isEmpty && _searchQuery.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    strings.f('showingXofY', {
                      'x': '0',
                      'y': state.members.length.toString(),
                    }),
                    style: const TextStyle(color: AppTheme.m3OnSurfaceVariant),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Head of Household bento card ──────────────────────────────────────────────

class _HeadOfHouseholdCard extends StatelessWidget {
  const _HeadOfHouseholdCard({
    required this.member,
    required this.dependentCount,
    required this.repository,
    required this.strings,
  });

  final FamilyMember member;
  final int dependentCount;
  final CbhiRepository repository;
  final i18n.AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.m3SurfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.m3OutlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Decorative bg
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: AppTheme.m3Primary.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(999),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                _MemberAvatar(repository: repository, member: member, radius: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.m3TertiaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              strings.t('headOfHousehold'),
                              style: const TextStyle(
                                color: AppTheme.m3OnTertiaryContainer,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, size: 14, color: AppTheme.m3Primary),
                              const SizedBox(width: 4),
                              Text(
                                member.coverageStatus,
                                style: const TextStyle(
                                  color: AppTheme.m3Primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        member.fullName,
                        style: const TextStyle(
                          color: AppTheme.m3OnSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (member.membershipId.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${member.membershipId}',
                          style: const TextStyle(
                            color: AppTheme.m3OnSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Stats
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.m3SurfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.m3OutlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        children: [
                          Text(
                            '$dependentCount',
                            style: const TextStyle(
                              color: AppTheme.m3OnSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            strings.t('dependents'),
                            style: const TextStyle(
                              color: AppTheme.m3OnSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: AppTheme.m3OutlineVariant.withValues(alpha: 0.5),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      Column(
                        children: [
                          Text(
                            strings.t('valid'),
                            style: const TextStyle(
                              color: AppTheme.m3OnSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            strings.t('coverage'),
                            style: const TextStyle(
                              color: AppTheme.m3OnSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
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

// ── M3 Member Card ────────────────────────────────────────────────────────────

class _M3MemberCard extends StatelessWidget {
  const _M3MemberCard({
    required this.member,
    required this.repository,
    required this.isFamilyMember,
    required this.strings,
    required this.familyCubit,
  });
  final FamilyMember member;
  final CbhiRepository repository;
  final bool isFamilyMember;
  final i18n.AppLocalizations strings;
  final MyFamilyCubit familyCubit;

  Color _statusBg(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return AppTheme.m3TertiaryContainer.withValues(alpha: 0.15);
      case 'EXPIRED':
        return AppTheme.m3ErrorContainer;
      case 'PENDING_RENEWAL':
      case 'PENDING':
        return AppTheme.m3SurfaceVariant;
      default:
        return AppTheme.m3SurfaceVariant;
    }
  }

  Color _statusFg(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return AppTheme.m3Tertiary;
      case 'EXPIRED':
        return AppTheme.m3OnErrorContainer;
      case 'PENDING_RENEWAL':
      case 'PENDING':
        return AppTheme.m3OnSurfaceVariant;
      default:
        return AppTheme.m3OnSurfaceVariant;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return Icons.verified_outlined;
      case 'EXPIRED':
        return Icons.cancel_outlined;
      default:
        return Icons.pending_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = member.coverageStatus;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.m3SurfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.m3OutlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Stack(
                children: [
                  _MemberAvatar(repository: repository, member: member, radius: 24),
                  if (member.isPrimaryHolder)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.star, color: Colors.amber, size: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.fullName,
                      style: const TextStyle(
                        color: AppTheme.m3OnSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${member.relationshipToHouseholdHead ?? strings.t('member')} • ${member.membershipId.isEmpty ? '—' : member.membershipId}',
                      style: const TextStyle(
                        color: AppTheme.m3OnSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // More options
              if (!isFamilyMember)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppTheme.m3OnSurfaceVariant, size: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      final changed = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => AddBeneficiaryScreen(
                            repository: repository,
                            member: member,
                          ),
                        ),
                      );
                      if (changed == true && context.mounted) {
                        await familyCubit.load();
                      }
                    } else if (value == 'remove' && !member.isPrimaryHolder) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(strings.t('removeBeneficiary')),
                          content: Text(strings.f('removeConfirmMessage', {'name': member.fullName})),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(strings.t('cancel')),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                              child: Text(strings.t('remove')),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        await familyCubit.removeMember(member.id);
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(strings.t('edit')),
                        ],
                      ),
                    ),
                    if (!member.isPrimaryHolder)
                      PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                            const SizedBox(width: 8),
                            Text(strings.t('remove'), style: const TextStyle(color: AppTheme.error)),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Status + View Details row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusBg(status),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon(status), size: 13, color: _statusFg(status)),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(
                        color: _statusFg(status),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (!isFamilyMember)
                GestureDetector(
                  onTap: () async {
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => AddBeneficiaryScreen(
                          repository: repository,
                          member: member,
                        ),
                      ),
                    );
                    if (changed == true && context.mounted) {
                      await familyCubit.load();
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        strings.t('viewDetails'),
                        style: const TextStyle(
                          color: AppTheme.m3Primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, size: 14, color: AppTheme.m3Primary),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyFamilyState extends StatelessWidget {
  const _EmptyFamilyState({
    required this.isFamilyMember,
    required this.repository,
    required this.familyCubit,
    required this.strings,
  });

  final bool isFamilyMember;
  final CbhiRepository repository;
  final MyFamilyCubit familyCubit;
  final i18n.AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.m3SurfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group_outlined,
                size: 40,
                color: AppTheme.m3OnSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              strings.t('noBeneficiariesAvailable'),
              style: const TextStyle(
                color: AppTheme.m3OnSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              strings.t('addFamilyMembersOnceActive'),
              style: const TextStyle(
                color: AppTheme.m3OnSurfaceVariant,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isFamilyMember) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => AddBeneficiaryScreen(repository: repository),
                    ),
                  );
                  if (changed == true && context.mounted) {
                    await familyCubit.load();
                  }
                },
                icon: const Icon(Icons.add),
                label: Text(strings.t('addBeneficiary')),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.m3Primary,
                  foregroundColor: AppTheme.m3OnPrimary,
                  shape: const StadiumBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Member Avatar ─────────────────────────────────────────────────────────────

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({
    required this.repository,
    required this.member,
    this.radius = 28,
  });

  final CbhiRepository repository;
  final FamilyMember member;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final resolved = repository.resolveMediaUrl(member.photoPath);
    final hasLocalFile =
        !kIsWeb &&
        member.photoPath != null &&
        member.photoPath!.isNotEmpty &&
        File(member.photoPath!).existsSync();

    if (hasLocalFile) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: impl.getFileImageProvider(member.photoPath!),
      );
    }

    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return CircleAvatar(
        radius: radius,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: resolved,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                const CircularProgressIndicator(strokeWidth: 2),
            errorWidget: (context, url, error) => Text(_initials(member.fullName)),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.m3SecondaryContainer,
      child: Text(
        _initials(member.fullName),
        style: TextStyle(
          color: AppTheme.m3OnSecondaryContainer,
          fontSize: radius * 0.6,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'B';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}
