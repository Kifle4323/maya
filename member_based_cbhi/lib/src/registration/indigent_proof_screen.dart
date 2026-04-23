import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart'
    if (dart.library.html) '../shared/permission_handler_stub.dart';

import '../cbhi_localizations.dart';
import '../theme/app_theme.dart';
import '../shared/language_selector.dart';
import '../shared/local_attachment_store.dart';
import 'registration_cubit.dart';

/// Indigent pathway: same personal + identity data as paying members; only
/// extra step is supporting documents (kebele letter, income proof, etc.).
class IndigentProofScreen extends StatefulWidget {
  const IndigentProofScreen({super.key});

  @override
  State<IndigentProofScreen> createState() => _IndigentProofScreenState();
}

class _IndigentProofScreenState extends State<IndigentProofScreen> {
  final List<String> _paths = [];
  final _picker = ImagePicker();

  Future<void> _addDocument() async {
    final strings = CbhiLocalizations.of(context);
    if (_paths.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.t('uploadLimitReached'))),
      );
      return;
    }

    if (!kIsWeb) {
      await Permission.camera.request();
      await Permission.photos.request();
    }
    if (!mounted) return;

    final choice = await showModalBottomSheet<String>(
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
    if (choice == null || !mounted) return;

    if (choice == 'file') {
      final file = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
      );
      final path = file?.files.single.path;
      if (path != null) {
        final persisted = await LocalAttachmentStore.persist(
          path,
          category: 'indigent_proof',
        );
        setState(() => _paths.add(persisted));
      }
      return;
    }

    final picked = choice == 'camera'
        ? await _picker.pickImage(source: ImageSource.camera, imageQuality: 85)
        : await _picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 85,
          );
    if (picked != null) {
      final persisted = await LocalAttachmentStore.persist(
        picked.path,
        category: 'indigent_proof',
      );
      setState(() => _paths.add(persisted));
    }
  }

  void _removeAt(int index) {
    setState(() => _paths.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final strings = CbhiLocalizations.of(context);
    final regCubit = context.watch<RegistrationCubit>();
    final state = regCubit.state;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('indigentProofDocuments')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => regCubit.cancelIndigentProof(),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: LanguageSelector(isLight: true),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        strings.t('supportingDocuments'),
                        style: textTheme.headlineSmall?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.t('indigentProofDescription'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.attach_file, color: AppTheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              strings.t('indigentProofDocuments'),
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_paths.length} / 3',
                              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(height: 32),

                        if (_paths.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.cloud_upload_outlined, 
                                      size: 48, color: AppTheme.textSecondary.withOpacity(0.4)),
                                  const SizedBox(height: 12),
                                  Text(
                                    strings.t('noDocumentsYet'),
                                    style: textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    strings.t('tapAddToUpload'),
                                    style: textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ..._paths.asMap().entries.map((e) {
                            final path = e.value;
                            final name = p.basename(path);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                                  border: Border.all(color: Theme.of(context).dividerColor),
                                ),
                                child: ListTile(
                                  leading: const Icon(Icons.description_outlined, color: AppTheme.primary),
                                  title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                                    onPressed: () => _removeAt(e.key),
                                  ),
                                ),
                              ),
                            );
                          }),

                        const SizedBox(height: 16),
                        
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: state.isLoading ? null : _addDocument,
                            icon: const Icon(Icons.add_photo_alternate_outlined),
                            label: Text(strings.t('addDocument')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              state.errorMessage!,
                              style: const TextStyle(color: AppTheme.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (state.isLoading || _paths.isEmpty)
                        ? null
                        : () => regCubit.submitIndigentProofs(List.from(_paths)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: state.isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(strings.t('submitRegistration')),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
