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

  Color _statusBorderColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return Colors.green;
      case 'EXPIRED':
        return Colors.red;
      case 'PENDING_RENEWAL':
      case 'PENDING':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  Color _statusChipColor(String status) => _statusBorderColor(status);

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final state = widget.state;
    final repository = widget.repository;
    final isFamilyMember = widget.isFamilyMember;
    final familyCubit = widget.familyCubit;
    final filtered = _filteredMembers;

    return RefreshIndicator(
        onRefresh: familyCubit.load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isFamilyMember
                        ? strings.t('householdMembers')
                        : strings.t('myFamily'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
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
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: Text(strings.t('addBeneficiary')),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isFamilyMember
                  ? strings.t('viewHouseholdMembers')
                  : strings.t('manageHouseholdBeneficiaries'),
            ),
            const SizedBox(height: 12),
            // F9: Search bar
            if (state.members.isNotEmpty) ...[
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search by name or membership ID...',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 8),
              Text(
                'Showing ${filtered.length} of ${state.members.length} members',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],
            if (state.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (state.members.isEmpty)
              Card(
                child: ListTile(
                  title: Text(strings.t('noBeneficiariesAvailable')),
                  subtitle: Text(strings.t('addFamilyMembersOnceActive')),
                ),
              )
            else
              ...filtered.map(
                (member) => _MemberCard(
                  member: member,
                  repository: repository,
                  isFamilyMember: isFamilyMember,
                  strings: strings,
                  familyCubit: familyCubit,
                  statusBorderColor: _statusBorderColor(member.coverageStatus),
                  statusChipColor: _statusChipColor(member.coverageStatus),
                ),
              ),
          ],
        ),
      );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.repository,
    required this.isFamilyMember,
    required this.strings,
    required this.familyCubit,
    required this.statusBorderColor,
    required this.statusChipColor,
  });
  final FamilyMember member;
  final CbhiRepository repository;
  final bool isFamilyMember;
  final i18n.AppLocalizations strings;
  final MyFamilyCubit familyCubit;
  final Color statusBorderColor;
  final Color statusChipColor;

  String _detailLine(BuildContext context) {
    final details = <String>[
      if (member.dateOfBirth != null && member.dateOfBirth!.isNotEmpty)
        '${strings.t('dobLabel')}: ${member.dateOfBirth!.split('T').first}',
      if (member.gender != null && member.gender!.isNotEmpty)
        '${strings.t('genderLabel')}: ${member.gender}',
      if (member.identityType != null && member.identityType!.isNotEmpty)
        '${strings.t('idLabel')}: ${member.identityType} ${member.identityNumber ?? ''}'.trim(),
      if (!member.canLoginIndependently && member.relationshipToHouseholdHead == 'CHILD')
        strings.t('accessThroughHouseholdHead'),
      if (!member.canLoginIndependently && member.relationshipToHouseholdHead != 'CHILD')
        strings.t('independentLoginNotEnabled'),
    ];
    return details.join('  •  ');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      // F10: Left border colored by coverage status
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusBorderColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: statusBorderColor, width: 4),
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // F10: Gold star overlay for primary holder
                  Stack(
                    children: [
                      _MemberAvatar(repository: repository, member: member),
                      if (member.isPrimaryHolder)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.star, color: Colors.amber, size: 14),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                member.fullName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            // F10: Colored status chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusChipColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusChipColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                member.coverageStatus,
                                style: TextStyle(
                                  color: statusChipColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InlineBadge(label: member.relationshipToHouseholdHead ?? 'Member'),
                            if (member.membershipId.isNotEmpty)
                              _InlineBadge(label: member.membershipId),
                            if (member.phoneNumber != null && member.phoneNumber!.isNotEmpty)
                              _InlineBadge(label: member.phoneNumber!),
                            if (member.canLoginIndependently)
                              _InlineBadge(label: strings.t('otpEnabled')),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(_detailLine(context), style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (!isFamilyMember)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
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
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(strings.t('edit')),
                      ),
                    ),
                    if (!member.isPrimaryHolder) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () async {
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
                                    child: Text(strings.t('remove')),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true && context.mounted) {
                              await familyCubit.removeMember(member.id);
                            }
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: Text(strings.t('remove')),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.repository, required this.member});

  final CbhiRepository repository;
  final FamilyMember member;

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
        radius: 28,
        backgroundImage: impl.getFileImageProvider(member.photoPath!),
      );
    }

    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return CircleAvatar(
        radius: 28,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: resolved,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                const CircularProgressIndicator(strokeWidth: 2),
            errorWidget: (context, url, error) => Text(_initials(member.fullName)),
          ),
        ),
      );
    }

    return CircleAvatar(radius: 28, child: Text(_initials(member.fullName)));
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

class _InlineBadge extends StatelessWidget {
  const _InlineBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
