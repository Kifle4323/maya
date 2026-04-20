import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../cbhi_data.dart';
import '../cbhi_localizations.dart';
import '../shared/file_image_widget.dart';
import '../shared/image_utils.dart';
import '../shared/local_attachment_store.dart';
import '../theme/app_theme.dart';
import 'indigent_models.dart';

/// Complete indigent application screen with:
/// - Income, property, disability data entry
/// - Document upload (1-3 documents)
/// - Real-time Vision API validation per document:
///     * Type detection (Income/Disability/Kebele/Poverty/Agricultural)
///     * Date extraction (Gregorian + Ethiopic calendar)
///     * Expiry check (each type has a validity period)
///     * Expired documents block submission
/// - Auto-scoring on backend (0-100)
/// - Clear feedback in English + Amharic
class IndigentApplicationScreen extends StatefulWidget {
  const IndigentApplicationScreen({
    super.key,
    required this.repository,
    required this.userId,
    required this.familySize,
    required this.employmentStatus,
    required this.onSubmitted,
  });

  final CbhiRepository repository;
  final String userId;
  final int familySize;
  final String employmentStatus;
  final void Function(Map<String, dynamic> result) onSubmitted;

  @override
  State<IndigentApplicationScreen> createState() =>
      _IndigentApplicationScreenState();
}

class _IndigentApplicationScreenState
    extends State<IndigentApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _incomeController = TextEditingController();
  bool _hasProperty = false;
  bool _hasDisability = false;
  final List<IndigentDocumentMeta> _documents = [];
  bool _isSubmitting = false;
  String? _submitError;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _incomeController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    if (_documents.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CbhiLocalizations.of(context).t('maxDocumentsReached'))),
      );
      return;
    }

    await Permission.camera.request();
    await Permission.photos.request();
    if (!mounted) return;

    final strings = CbhiLocalizations.of(context);
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
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
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(strings.t('choosePdfOrImage')),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    String? filePath;
    if (source == 'file') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
      );
      filePath = result?.files.single.path;
    } else {
      final image = await _picker.pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        filePath = await compressImageForUpload(image.path);
      }
    }

    if (filePath == null || !mounted) return;

    final persistedPath = await LocalAttachmentStore.persist(
      filePath,
      category: 'indigent_doc',
    );

    final meta = IndigentDocumentMeta(
      localPath: persistedPath,
      isValidating: true,
    );
    setState(() => _documents.add(meta));

    await _validateDocument(_documents.length - 1);
  }

  Future<void> _validateDocument(int index) async {
    final doc = _documents[index];
    setState(() {
      _documents[index] = doc.copyWith(isValidating: true);
    });

    try {
      final base64 = await fileToBase64(doc.localPath);
      if (base64 == null) {
        setState(() {
          _documents[index] = doc.copyWith(
            isValidating: false,
            isValidated: true,
            validationError: 'Could not read file. Please try again.',
          );
        });
        return;
      }

      final result = await widget.repository.validateIndigentDocument(
        imageBase64: base64,
      );

      final issues = (result['issues'] as List?)?.cast<String>() ?? [];

      setState(() {
        _documents[index] = doc.copyWith(
          isValidating: false,
          isValidated: true,
          documentType: result['documentType']?.toString(),
          detectedDate: result['detectedDate']?.toString(),
          isExpired: result['isExpired'] == true,
          expiryWarning: result['expiryWarning']?.toString(),
          validationSummary: issues.join('; '),
          confidence: (result['confidence'] as num?)?.toDouble() ?? 0,
          detectedKeywords:
              (result['detectedKeywords'] as List?)?.cast<String>() ?? [],
          validationError: issues.isNotEmpty ? issues.first : null,
        );
      });
    } catch (e) {
      setState(() {
        _documents[index] = doc.copyWith(
          isValidating: false,
          isValidated: true,
          validationError: 'Validation failed: ${e.toString()}',
        );
      });
    }
  }

  Future<void> _submit() async {
    final strings = CbhiLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    if (_documents.isEmpty) {
      setState(() =>
          _submitError = strings.t('pleaseUploadAtLeastOneDocument'));
      return;
    }

    final expiredDocs = _documents.where((d) => d.isExpired).toList();
    if (expiredDocs.isNotEmpty) {
      setState(() {
        _submitError = strings.f('expiredDocumentError', {
          'docs': expiredDocs.map((d) => d.documentType ?? 'document').join(', '),
        });
      });
      return;
    }

    final stillValidating = _documents.any((d) => d.isValidating);
    if (stillValidating) {
      setState(() =>
          _submitError = strings.t('waitForValidation'));
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final result = await widget.repository.submitIndigentApplication(
        userId: widget.userId,
        income: int.tryParse(_incomeController.text.trim()) ?? 0,
        employmentStatus: widget.employmentStatus,
        familySize: widget.familySize,
        hasProperty: _hasProperty,
        disabilityStatus: _hasDisability,
        documents: _documents.map((d) => d.localPath).toList(),
        documentMeta: _documents.map((d) => d.toJson()).toList(),
      );
      widget.onSubmitted(result);
    } catch (e) {
      setState(() =>
          _submitError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.t('indigentApplication'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          children: [
            _InfoBanner().animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 20),
            _buildIncomeCard(),
            const SizedBox(height: 16),
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildDocumentsCard(),
            const SizedBox(height: 16),
            if (_submitError != null) _ErrorCard(message: _submitError!),
            const SizedBox(height: 16),
            _buildSubmitButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeCard() {
    final strings = CbhiLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.t('monthlyIncome'),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              strings.t('monthlyIncomeSubtitle'),
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _incomeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: strings.t('monthlyIncomeEtb'),
                prefixIcon: const Icon(Icons.payments_outlined),
                hintText: 'e.g. 500',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return strings.t('required');
                if (int.tryParse(v.trim()) == null) {
                  return strings.t('invalidNumber');
                }
                return null;
              },
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildStatusCard() {
    final strings = CbhiLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.t('householdStatus'),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(strings.t('ownsProperty')),
              subtitle: Text(strings.t('ownsPropertySubtitle')),
              value: _hasProperty,
              onChanged: (v) => setState(() => _hasProperty = v),
              activeThumbColor: AppTheme.primary,
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(strings.t('hasMemberWithDisability')),
              subtitle: Text(strings.t('hasMemberWithDisabilitySubtitle')),
              value: _hasDisability,
              onChanged: (v) => setState(() => _hasDisability = v),
              activeThumbColor: AppTheme.primary,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 150.ms);
  }

  Widget _buildDocumentsCard() {
    final strings = CbhiLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.t('supportingDocuments'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(
                        strings.t('upload1To3Documents'),
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (_documents.length < 3)
                  FilledButton.tonalIcon(
                    onPressed: _pickDocument,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: Text(strings.t('addDocument')),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _AcceptedTypesExpansion(),
            const SizedBox(height: 12),
            if (_documents.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.upload_file_outlined,
                          size: 40, color: AppTheme.textSecondary),
                      const SizedBox(height: 8),
                      Text(strings.t('noDocumentsYet'),
                          style: const TextStyle(color: AppTheme.textSecondary)),
                      Text(strings.t('tapAddToUpload'),
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              )
            else
              ..._documents.asMap().entries.map(
                (entry) => _DocumentCard(
                  doc: entry.value,
                  index: entry.key,
                  onRemove: () =>
                      setState(() => _documents.removeAt(entry.key)),
                  onRetry: () => _validateDocument(entry.key),
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildSubmitButton() {
    final strings = CbhiLocalizations.of(context);
    final hasExpired = _documents.any((d) => d.isExpired);
    final isValidating = _documents.any((d) => d.isValidating);

    return FilledButton.icon(
      onPressed: (_isSubmitting || hasExpired || isValidating) ? null : _submit,
      icon: _isSubmitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.send_outlined),
      label: Text(
        isValidating
            ? strings.t('validatingDocuments')
            : hasExpired
                ? strings.t('expiredDocumentsCannotSubmit')
                : strings.t('submitApplication'),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.volunteer_activism, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  strings.t('indigentApplicationTitle'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            strings.t('indigentApplicationBannerBody'),
            style: const TextStyle(
                color: Colors.white70, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _AcceptedTypesExpansion extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        strings.t('acceptedDocumentTypesTitle'),
        style: const TextStyle(
            fontSize: 13,
            color: AppTheme.primary,
            fontWeight: FontWeight.w600),
      ),
      leading: const Icon(Icons.info_outline,
          color: AppTheme.primary, size: 18),
      children: IndigentDocumentType.values
          .map(
            (type) => ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8),
              leading: const Icon(Icons.check_circle_outline,
                  color: AppTheme.success, size: 18),
              title: Text(type.label,
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                '${type.amharic} • ${strings.f('validForMonths', {'months': type.validityMonths})}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(
            color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline,
              color: AppTheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: AppTheme.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.doc,
    required this.index,
    required this.onRemove,
    required this.onRetry,
  });

  final IndigentDocumentMeta doc;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  Color get _statusColor {
    if (doc.isValidating) return AppTheme.primary;
    if (doc.isExpired) return AppTheme.error;
    if (doc.isAccepted) return AppTheme.success;
    if (doc.validationError != null) return AppTheme.warning;
    return AppTheme.textSecondary;
  }

  IconData get _statusIcon {
    if (doc.isValidating) return Icons.hourglass_empty;
    if (doc.isExpired) return Icons.cancel_outlined;
    if (doc.isAccepted) return Icons.check_circle_outline;
    if (doc.validationError != null) return Icons.warning_amber_outlined;
    return Icons.description_outlined;
  }

  String _statusLabel(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    if (doc.isValidating) return strings.t('statusValidating');
    if (doc.isExpired) return strings.t('statusExpired');
    if (doc.isAccepted) return strings.t('statusAccepted');
    if (doc.validationError != null) return strings.t('statusIssueDetected');
    return strings.t('statusPending');
  }

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
            color: _statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: doc.localPath.toLowerCase().endsWith('.pdf')
                      ? Container(
                          color: AppTheme.primary
                              .withValues(alpha: 0.1),
                          child: const Icon(Icons.picture_as_pdf,
                              color: AppTheme.primary, size: 28),
                        )
                      : NativeFileImage(
                          path: doc.localPath,
                          fit: BoxFit.cover,
                          width: 52,
                          height: 52,
                          errorWidget: Container(
                            color: AppTheme.surfaceLight,
                            child: const Icon(Icons.description_outlined,
                                color: AppTheme.textSecondary, size: 28),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.documentType ?? 'Document ${index + 1}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _statusColor,
                          fontSize: 14),
                    ),
                    if (doc.detectedDate != null)
                      Text(
                        strings.f('issued', {'date': doc.detectedDate!}),
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary),
                      ),
                    Row(
                      children: [
                        Icon(_statusIcon,
                            color: _statusColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _statusLabel(context),
                          style: TextStyle(
                              color: _statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        if (doc.confidence > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            strings.f('confidence', {'percent': (doc.confidence * 100).toStringAsFixed(0)}),
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (doc.isValidating)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onRemove,
                  color: AppTheme.textSecondary,
                ),
            ],
          ),

          // Expiry warning (not yet expired)
          if (doc.expiryWarning != null && !doc.isExpired) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_outlined,
                      color: AppTheme.warning, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      doc.expiryWarning!,
                      style: const TextStyle(
                          color: AppTheme.warning, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Error / expired message
          if (doc.validationError != null || doc.isExpired) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.error, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          doc.isExpired
                              ? strings.t('documentExpiredBilingual')
                              : doc.validationError ?? '',
                          style: const TextStyle(
                              color: AppTheme.error, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  if (!doc.isExpired) ...[
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, size: 14),
                      label: Text(strings.t('retryValidation'),
                          style: const TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Detected keywords (accepted docs only)
          if (doc.detectedKeywords.isNotEmpty && doc.isAccepted) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: doc.detectedKeywords
                  .take(5)
                  .map(
                    (kw) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        kw,
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.success,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
