import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart'
    if (dart.library.html) '../../shared/permission_handler_stub.dart';

import '../../cbhi_localizations.dart';
import '../../theme/app_theme.dart';
import '../../shared/language_selector.dart';
import '../../shared/file_image_widget.dart';
import '../../shared/local_attachment_store.dart';
import '../registration_cubit.dart';
import 'identity_cubit.dart';
import '../models/identity_model.dart';

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  State<IdentityVerificationScreen> createState() => _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends State<IdentityVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _idNumberController = TextEditingController();

  String? selectedIdentityType;
  String? selectedEmploymentStatus;

  // ID card uploads
  String? _idFrontPath;
  String? _idBackPath;

  // Verification state
  bool _verifying = false;
  Map<String, dynamic>? _verificationResult;
  String? _verificationError;

  // Real-time ID duplicate detection
  String? _idError;
  bool _checkingId = false;
  DateTime? _lastIdCheck;

  Future<void> _checkId(String value) async {
    final id = value.trim();
    if (id.length < 4) {
      if (_idError != null) setState(() => _idError = null);
      return;
    }
    final now = DateTime.now();
    _lastIdCheck = now;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (_lastIdCheck != now || !mounted) return;

    setState(() => _checkingId = true);
    final regCubit = context.read<RegistrationCubit>();
    final error = await regCubit.repository.checkIdAvailability(id);
    if (!mounted) return;
    setState(() {
      _idError = error;
      _checkingId = false;
    });
  }

  Future<void> _pickIdImage(String side) async {
    if (!kIsWeb) {
      await Permission.camera.request();
      await Permission.photos.request();
    }
    if (!mounted) return;
    final strings = CbhiLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (!kIsWeb) ...[
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(strings.t('takePhoto')),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(strings.t('chooseFromGallery')),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
            ],
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(strings.t('choosePdfOrImage')),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    String? pickedPath;

    if (choice == 'file') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
        withData: kIsWeb,
      );
      if (result == null) return;
      final file = result.files.single;
      if (kIsWeb) {
        if (file.bytes != null) {
          final key = LocalAttachmentStore.putWebBytes('web:${file.name}', file.bytes!);
          pickedPath = key;
        }
      } else if (file.path != null) {
        pickedPath = await LocalAttachmentStore.persist(
          file.path!,
          category: 'registration_id_$side',
        );
      }
    } else {
      final picked = choice == 'camera'
          ? await _picker.pickImage(source: ImageSource.camera, imageQuality: 85)
          : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked != null) {
        pickedPath = await LocalAttachmentStore.persist(
          picked.path,
          category: 'registration_id_$side',
        );
      }
    }

    if (pickedPath != null && mounted) {
      setState(() {
        if (side == 'front') {
          _idFrontPath = pickedPath;
        } else {
          _idBackPath = pickedPath;
        }
        // Reset verification when images change
        _verificationResult = null;
        _verificationError = null;
      });
    }
  }

  Future<void> _verifyIdDocument() async {
    if (_idFrontPath == null) return;
    final regCubit = context.read<RegistrationCubit>();
    final personalInfo = regCubit.state.personalInfo;
    if (personalInfo == null) return;

    debugPrint('[VerifyID] Starting verification — path: $_idFrontPath, name: ${personalInfo.fullName}, id: ${_idNumberController.text.trim()}');

    setState(() {
      _verifying = true;
      _verificationError = null;
    });

    try {
      final result = await regCubit.repository.verifyIdDocument(
        idFrontPath: _idFrontPath!,
        fullName: personalInfo.fullName,
        idNumber: _idNumberController.text.trim(),
      );
      debugPrint('[VerifyID] Result: $result');
      if (!mounted) return;
      setState(() {
        _verificationResult = result;
        _verifying = false;
      });
    } catch (e) {
      debugPrint('[VerifyID] Error: $e');
      if (!mounted) return;
      setState(() {
        _verificationError = e.toString();
        _verifying = false;
      });
    }
  }

  bool _isImage(String path) {
    final n = path.toLowerCase();
    return n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg');
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    final List<Map<String, String>> employmentOptions = [
      {'value': 'farmer', 'label': strings.t('farmer')},
      {'value': 'merchant', 'label': strings.t('merchant')},
      {'value': 'daily_laborer', 'label': strings.t('dailyLaborer')},
      {'value': 'employed', 'label': strings.t('employed')},
      {'value': 'homemaker', 'label': strings.t('homemaker')},
      {'value': 'student', 'label': strings.t('student')},
      {'value': 'unemployed', 'label': strings.t('unemployed')},
      {'value': 'pensioner', 'label': strings.t('pensioner')},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('identityAndEmployment')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.read<RegistrationCubit>().goBackToConfirmation(),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: LanguageSelector(isLight: true),
          ),
        ],
      ),
      body: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => IdentityCubit()),
        ],
        child: BlocBuilder<IdentityCubit, IdentityState>(
          builder: (context, identityState) {
            final identityCubit = context.read<IdentityCubit>();
            final regCubit = context.read<RegistrationCubit>();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppTheme.spacingM),
                        // Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: AppTheme.cardGradient,
                            borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.t('identityVerification'),
                                style: textTheme.headlineSmall?.copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                strings.t('collectIdForScreening'),
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Identity Section
                                Row(
                                  children: [
                                    const Icon(Icons.badge_outlined, color: AppTheme.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      strings.t('identityDetails'),
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 32),

                                // Identity Type Picker
                                DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: strings.t('identityType'),
                                    prefixIcon: const Icon(Icons.category_outlined),
                                  ),
                                  value: selectedIdentityType,
                                  items: [
                                    DropdownMenuItem(value: 'NATIONAL_ID', child: Text(strings.t('nationalId'))),
                                    DropdownMenuItem(value: 'PASSPORT', child: Text(strings.t('passport'))),
                                    DropdownMenuItem(value: 'LOCAL_ID', child: Text(strings.t('localId'))),
                                  ],
                                  onChanged: (value) {
                                    setState(() => selectedIdentityType = value);
                                  },
                                  validator: (v) => v == null ? strings.t('required') : null,
                                ),

                                const SizedBox(height: 20),

                                // Identity Number
                                TextFormField(
                                  controller: _idNumberController,
                                  decoration: InputDecoration(
                                    labelText: strings.t('identityNumber'),
                                    prefixIcon: const Icon(Icons.numbers_outlined),
                                    errorText: _idError,
                                    suffixIcon: _checkingId
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: Padding(
                                              padding: EdgeInsets.all(12),
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          )
                                        : _idError != null
                                            ? const Icon(Icons.error_outline, color: Colors.red)
                                            : null,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return strings.t('required');
                                    if (_idError != null) return _idError;
                                    return null;
                                  },
                                  onChanged: (v) {
                                    identityCubit.updateIdentityNumber(v);
                                    _checkId(v);
                                  },
                                ),

                                const SizedBox(height: 28),

                                // ── ID Card Upload Section ──
                                Row(
                                  children: [
                                    const Icon(Icons.credit_card, color: AppTheme.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      strings.t('uploadIdCard'),
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 32),

                                // Front & Back side by side
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Front
                                    Expanded(
                                      child: _IdCardPicker(
                                        label: strings.t('idCardFront'),
                                        subtitle: strings.t('requiredImageOrPdf'),
                                        path: _idFrontPath,
                                        isImage: _idFrontPath != null && _isImage(_idFrontPath!),
                                        onPick: () => _pickIdImage('front'),
                                        isRequired: true,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Back
                                    Expanded(
                                      child: _IdCardPicker(
                                        label: strings.t('idCardBack'),
                                        subtitle: strings.t('optionalImageOrPdf'),
                                        path: _idBackPath,
                                        isImage: _idBackPath != null && _isImage(_idBackPath!),
                                        onPick: () => _pickIdImage('back'),
                                        isRequired: false,
                                      ),
                                    ),
                                  ],
                                ),

                                // Verify button
                                if (_idFrontPath != null && _verificationResult == null && !_verifying) ...[
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _verifyIdDocument,
                                      icon: const Icon(Icons.verified_user_outlined),
                                      label: Text(strings.t('verifyIdCard')),
                                    ),
                                  ),
                                ],

                                // Verifying indicator
                                if (_verifying) ...[
                                  const SizedBox(height: 16),
                                  Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(strings.t('verifyingIdCard')),
                                      ],
                                    ),
                                  ),
                                ],

                                // Verification error
                                if (_verificationError != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            strings.t('verificationUnavailable'),
                                            style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Verification result
                                if (_verificationResult != null) ...[
                                  const SizedBox(height: 16),
                                  _VerificationResultCard(
                                    result: _verificationResult!,
                                    strings: strings,
                                  ),
                                ],

                                const SizedBox(height: 40),

                                // Employment Section
                                Row(
                                  children: [
                                    const Icon(Icons.work_outline, color: AppTheme.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      strings.t('employmentOccupationStatus'),
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 32),

                                DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: strings.t('mainOccupation'),
                                    prefixIcon: const Icon(Icons.work_history_outlined),
                                  ),
                                  value: selectedEmploymentStatus,
                                  items: employmentOptions
                                      .map((option) => DropdownMenuItem(
                                            value: option['value'],
                                            child: Text(option['label']!),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() => selectedEmploymentStatus = value);
                                    identityCubit.updateEmploymentStatus(value ?? '');
                                  },
                                  validator: (v) => v == null ? strings.t('required') : null,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              if (!_formKey.currentState!.validate()) return;
                              if (selectedIdentityType == null || selectedEmploymentStatus == null) return;
                              if (_idError != null || _checkingId) return;
                              if (_idFrontPath == null || _idFrontPath!.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(strings.t('idCardFrontRequired'))),
                                );
                                return;
                              }
                              if (_verifying) return;

                              final identityModel = IdentityModel(
                                identityType: selectedIdentityType!,
                                identityNumber: _idNumberController.text.trim(),
                                idFrontPath: _idFrontPath,
                                idBackPath: _idBackPath,
                                verificationId: _verificationResult?['verificationId']?.toString(),
                                verificationStatus: _verificationResult?['status']?.toString(),
                                employmentStatus: selectedEmploymentStatus!,
                              );

                              regCubit.submitIdentity(identityModel);
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(strings.t('continueToMembership')),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── ID Card Picker Widget ────────────────────────────────────────────────────

class _IdCardPicker extends StatelessWidget {
  const _IdCardPicker({
    required this.label,
    required this.subtitle,
    required this.path,
    required this.isImage,
    required this.onPick,
    required this.isRequired,
  });

  final String label;
  final String subtitle;
  final String? path;
  final bool isImage;
  final VoidCallback onPick;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label, style: theme.textTheme.titleSmall),
                if (isRequired)
                  Text(' *', style: TextStyle(color: theme.colorScheme.error, fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (isRequired && path == null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  CbhiLocalizations.of(context).t('idCardFrontRequired'),
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 11),
                ),
              ),
            const SizedBox(height: 8),
            if (path != null)
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: kIsWeb
                    ? const Center(child: Icon(Icons.description_outlined, size: 40))
                    : isImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: NativeFileImage(path: path!, height: 120, fit: BoxFit.cover),
                          )
                        : Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.description_outlined),
                                const SizedBox(width: 8),
                                Flexible(child: Text(path!.split('/').last, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
              )
            else
              Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: InkWell(
                  onTap: onPick,
                  borderRadius: BorderRadius.circular(8),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: theme.colorScheme.primary),
                        const SizedBox(height: 4),
                        Text(
                          CbhiLocalizations.of(context).t('uploadDocument'),
                          style: TextStyle(color: theme.colorScheme.primary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (path != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onPick,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(CbhiLocalizations.of(context).t('replaceDocument'), style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Verification Result Card ─────────────────────────────────────────────────

class _VerificationResultCard extends StatelessWidget {
  const _VerificationResultCard({required this.result, required this.strings});

  final Map<String, dynamic> result;
  final dynamic strings;

  @override
  Widget build(BuildContext context) {
    final status = result['status'] as String? ?? 'manual_review';
    final confidence = double.tryParse(result['confidence']?.toString() ?? '0') ?? 0;
    final reasons = (result['reasons'] as List?)?.cast<String>() ?? [];
    final extracted = result['extracted'] as Map<String, dynamic>?;

    final isApproved = status == 'approved';
    final isRejected = status == 'rejected';

    final Color bgColor;
    final Color fgColor;
    final IconData icon;

    if (isApproved) {
      bgColor = Colors.green.shade50;
      fgColor = Colors.green.shade800;
      icon = Icons.check_circle_outline;
    } else if (isRejected) {
      bgColor = Colors.red.shade50;
      fgColor = Colors.red.shade800;
      icon = Icons.cancel_outlined;
    } else {
      bgColor = Colors.orange.shade50;
      fgColor = Colors.orange.shade800;
      icon = Icons.pending_outlined;
    }

    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fgColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fgColor, size: 22),
              const SizedBox(width: 8),
              Text(
                isApproved
                    ? strings.t('verificationApproved')
                    : isRejected
                        ? strings.t('verificationRejected')
                        : strings.t('verificationManualReview'),
                style: theme.textTheme.titleSmall?.copyWith(color: fgColor, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${(confidence * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.labelLarge?.copyWith(color: fgColor),
              ),
            ],
          ),
          if (extracted != null) ...[
            const SizedBox(height: 10),
            Text(strings.t('extractedData'), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (extracted['name'] != null)
              Text('${strings.t('name')}: ${extracted['name']}', style: theme.textTheme.bodySmall),
            if (extracted['idNumber'] != null)
              Text('${strings.t('identityNumber')}: ${extracted['idNumber']}', style: theme.textTheme.bodySmall),
            if (extracted['expiryDate'] != null)
              Text('${strings.t('expiryDate')}: ${extracted['expiryDate']}', style: theme.textTheme.bodySmall),
          ],
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...reasons.map((r) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 14, color: fgColor),
                  const SizedBox(width: 4),
                  Expanded(child: Text(r, style: theme.textTheme.bodySmall?.copyWith(color: fgColor))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}
