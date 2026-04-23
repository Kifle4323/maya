import 'dart:io' if (dart.library.html) '../shared/web_stubs.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../shared/native_file_image_impl.dart'
    if (dart.library.html) '../shared/native_file_image_web.dart' as impl;


import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart'
    if (dart.library.html) '../shared/permission_handler_stub.dart';

import '../cbhi_data.dart';
import '../cbhi_localizations.dart';
import '../shared/ethiopic_date_picker.dart';
import '../shared/local_attachment_store.dart';
import 'add_beneficiary_cubit.dart';

class AddBeneficiaryScreen extends StatefulWidget {
  const AddBeneficiaryScreen({
    super.key,
    required this.repository,
    this.member,
  });

  final CbhiRepository repository;
  final FamilyMember? member;

  @override
  State<AddBeneficiaryScreen> createState() => _AddBeneficiaryScreenState();
}

class _AddBeneficiaryScreenState extends State<AddBeneficiaryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final AddBeneficiaryCubit _cubit;
  late final TextEditingController _fullNameController;
  late final TextEditingController _dobController;
  late final TextEditingController _phoneController;
  late final TextEditingController _idNumberController;

  String _gender = 'FEMALE';
  String _relationship = 'CHILD';
  String? _identityType;

  @override
  void initState() {
    super.initState();
    _cubit = AddBeneficiaryCubit(
      widget.repository,
      initialPhotoPath: widget.member?.photoPath,
    );
    _fullNameController = TextEditingController(
      text: widget.member?.fullName ?? '',
    );
    _dobController = TextEditingController(
      text: widget.member?.dateOfBirth?.split('T').first ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.member?.phoneNumber ?? '+2519',
    );
    _idNumberController = TextEditingController(
      text: widget.member?.identityNumber ?? '',
    );
    _gender = widget.member?.gender ?? 'FEMALE';
    _relationship = widget.member?.relationshipToHouseholdHead ?? 'CHILD';
    _identityType = widget.member?.identityType;
  }

  @override
  void dispose() {
    _cubit.close();
    _fullNameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final strings = CbhiLocalizations.of(context);
    final now = DateTime.now();
    final initialDate =
        DateTime.tryParse(_dobController.text) ?? DateTime(now.year - 12);
    final picked = await showEthiopicDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: strings.t('selectDateOfBirth'),
    );
    if (picked != null) {
      _dobController.text =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _selectPhoto() async {
    final strings = CbhiLocalizations.of(context);
    final cameraStatus = await Permission.camera.request();
    final photoStatus = await Permission.photos.request();
    if (!mounted) {
      return;
    }
    if (!cameraStatus.isGranted && !photoStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.t('cameraOrGalleryPermissionRequired'))),
      );
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(strings.t('takePhoto')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(strings.t('chooseFromGallery')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) {
      return;
    }

    final image = await _picker.pickImage(source: source, imageQuality: 85);
    if (image != null && mounted) {
      final persistedPath = await LocalAttachmentStore.persist(
        image.path,
        category: 'beneficiary_photo',
      );
      _cubit.setPhotoPath(persistedPath);
    }
  }

  Future<void> _save() async {
    final strings = CbhiLocalizations.of(context);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if ((_cubit.state.photoPath ?? '').isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.t('photoRequired'))));
      return;
    }

    final nameParts = _splitName(_fullNameController.text.trim());
    final dateOfBirth =
        DateTime.tryParse(_dobController.text.trim()) ?? DateTime.now();
    final draft = FamilyMemberDraft(
      firstName: nameParts.$1,
      middleName: nameParts.$2,
      lastName: nameParts.$3,
      gender: _gender,
      dateOfBirth: dateOfBirth,
      relationshipToHouseholdHead: _relationship,
      identityType: _idNumberController.text.trim().isEmpty
          ? null
          : _identityType,
      identityNumber: _idNumberController.text.trim().isEmpty
          ? null
          : _idNumberController.text.trim(),
      phoneNumber:
          (_phoneController.text.trim().isEmpty ||
              _phoneController.text.trim() == '+2519')
          ? null
          : _phoneController.text.trim(),
      photoPath: _cubit.state.photoPath,
    );

    final success = await _cubit.submit(
      memberId: widget.member?.id,
      draft: draft,
    );
    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Builder(
        builder: (context) {
          return BlocListener<AddBeneficiaryCubit, AddBeneficiaryState>(
            listenWhen: (previous, current) => previous.error != current.error,
            listener: (context, state) {
              if (state.error != null && state.error!.isNotEmpty) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(state.error!)));
              }
            },
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  widget.member == null
                      ? CbhiLocalizations.of(context).t('addBeneficiary')
                      : CbhiLocalizations.of(context).t('editBeneficiary'),
                ),
              ),
              body: BlocBuilder<AddBeneficiaryCubit, AddBeneficiaryState>(
                builder: (context, state) {
                  final strings = CbhiLocalizations.of(context);
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.t('beneficiaryDetails'),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(strings.t('captureBeneficiaryProfile')),
                          const SizedBox(height: 24),
                          _PhotoPreview(
                            repository: widget.repository,
                            photoPath: state.photoPath,
                            fallbackLabel: _initials(_fullNameController.text),
                            onPick: _selectPhoto,
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _fullNameController,
                            decoration: InputDecoration(
                              labelText: strings.t('fullName'),
                            ),
                            validator: (value) {
                              final parts =
                                  value
                                      ?.trim()
                                      .split(RegExp(r'\s+'))
                                      .where((part) => part.isNotEmpty)
                                      .toList() ??
                                  const <String>[];
                              if (parts.length < 2) {
                                return strings.t('fullNamePartsRequired');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _dobController,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: strings.t('dateOfBirth'),
                              suffixIcon: const Icon(
                                Icons.calendar_today_outlined,
                              ),
                            ),
                            onTap: _pickDate,
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? strings.t('dateOfBirthRequired')
                                : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _gender,
                            decoration: InputDecoration(
                              labelText: strings.t('gender'),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'FEMALE',
                                child: Text(strings.t('female')),
                              ),
                              DropdownMenuItem(
                                value: 'MALE',
                                child: Text(strings.t('male')),
                              ),
                              DropdownMenuItem(
                                value: 'OTHER',
                                child: Text(strings.t('other')),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _gender = value ?? 'FEMALE'),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _relationship,
                            decoration: InputDecoration(
                              labelText: strings.t(
                                'relationshipToHouseholdHead',
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'SPOUSE',
                                child: Text(strings.t('spouse')),
                              ),
                              DropdownMenuItem(
                                value: 'CHILD',
                                child: Text(strings.t('child')),
                              ),
                              DropdownMenuItem(
                                value: 'PARENT',
                                child: Text(strings.t('parent')),
                              ),
                              DropdownMenuItem(
                                value: 'SIBLING',
                                child: Text(strings.t('sibling')),
                              ),
                              DropdownMenuItem(
                                value: 'OTHER',
                                child: Text(strings.t('other')),
                              ),
                            ],
                            onChanged: (value) => setState(
                              () => _relationship = value ?? 'CHILD',
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            strings.t('independentAccessSection'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(strings.t('independentAccessDescription')),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: strings.t('phoneNumber'),
                            ),
                            validator: (value) {
                              final trimmed = value?.trim() ?? '';
                              if (_relationship == 'CHILD' &&
                                  (trimmed.isEmpty || trimmed == '+2519')) {
                                return null;
                              }
                              if (trimmed.isEmpty || trimmed == '+2519') {
                                return strings.t('phoneRequiredForNonChild');
                              }
                              if (trimmed.length < 10) {
                                return strings.t(
                                  'enterValidEthiopianMobileNumber',
                                );
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            strings.t('identityDetails'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(strings.t('nationalIdOrLocalIdOptional')),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            initialValue: _identityType,
                            decoration: InputDecoration(
                              labelText: strings.t('idTypeOptional'),
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(strings.t('none')),
                              ),
                              DropdownMenuItem<String?>(
                                value: 'NATIONAL_ID',
                                child: Text(strings.t('nationalId')),
                              ),
                              DropdownMenuItem<String?>(
                                value: 'LOCAL_ID',
                                child: Text(strings.t('localId')),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _identityType = value),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _idNumberController,
                            decoration: InputDecoration(
                              labelText: strings.t('idNumberOptional'),
                            ),
                            validator: (value) {
                              final trimmed = value?.trim() ?? '';
                              if (trimmed.isNotEmpty && _identityType == null) {
                                return strings.t('selectIdTypeForNumber');
                              }
                              if (trimmed.isEmpty && _identityType != null) {
                                return strings.t('enterIdNumberForType');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: state.isSubmitting ? null : _save,
                              icon: state.isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(
                                widget.member == null
                                    ? strings.t('saveBeneficiary')
                                    : strings.t('updateBeneficiary'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  (String, String?, String) _splitName(String fullName) {
    final parts = fullName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length < 2) {
      return (fullName.trim(), null, 'Member');
    }
    if (parts.length == 2) {
      return (parts.first, null, parts.last);
    }
    return (
      parts.first,
      parts.sublist(1, parts.length - 1).join(' '),
      parts.last,
    );
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'B';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    required this.repository,
    required this.photoPath,
    required this.fallbackLabel,
    required this.onPick,
  });

  final CbhiRepository repository;
  final String? photoPath;
  final String fallbackLabel;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final resolvedUrl = repository.resolveMediaUrl(photoPath);
    final hasLocalFile =
        !kIsWeb &&
        photoPath != null &&
        photoPath!.isNotEmpty &&
        File(photoPath!).existsSync();


    Widget avatar;
    if (hasLocalFile) {
      avatar = CircleAvatar(
        radius: 42,
        backgroundImage: impl.getFileImageProvider(photoPath!),
      );
    } else if (resolvedUrl.startsWith('http://') ||
        resolvedUrl.startsWith('https://')) {
      avatar = CircleAvatar(
        radius: 42,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: resolvedUrl,
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                const CircularProgressIndicator(strokeWidth: 2),
            errorWidget: (context, url, error) => Text(
              fallbackLabel,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
      );
    } else {
      avatar = CircleAvatar(
        radius: 42,
        child: Text(
          fallbackLabel,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            avatar,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.t('beneficiaryPhoto'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(strings.t('useCameraOrGalleryConfirmPreview')),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: onPick,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(strings.t('addOrChangePhoto')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
