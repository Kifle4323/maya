import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart'
    if (dart.library.html) '../shared/permission_handler_stub.dart';

import '../cbhi_localizations.dart';
import '../theme/app_theme.dart';
import '../shared/language_selector.dart';
import '../shared/local_attachment_store.dart';
import '../shared/premium_widgets.dart';
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
      body: Stack(
        children: [
          Center(
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
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Mesh Effect
                      Positioned(
                        top: -50,
                        right: -50,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppTheme.accent.withValues(alpha: 0.3),
                                AppTheme.accent.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).move(begin: const Offset(-10, -10), end: const Offset(10, 10), duration: 5.seconds),

                      Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingL),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.t('supportingDocuments'),
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              strings.t('indigentProofDescription'),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.attach_file, color: AppTheme.primary, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            strings.t('indigentProofDocuments'),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          StatusPill(
                            label: '${_paths.length} / 3',
                            color: _paths.isNotEmpty ? AppTheme.primary : AppTheme.textSecondaryFor(Theme.of(context).brightness),
                            compact: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      if (_paths.isEmpty)
                        SpringTap(
                          onTap: state.isLoading ? null : _addDocument,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(AppTheme.radiusM),
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.15),
                                style: BorderStyle.solid,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.cloud_upload_outlined, 
                                      size: 32, color: AppTheme.primary),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  strings.t('noDocumentsYet'),
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  strings.t('tapAddToUpload'),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondaryFor(Theme.of(context).brightness),
                                  ),
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
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(AppTheme.radiusS),
                                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.description_outlined, color: AppTheme.primary),
                                title: Text(name, 
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  maxLines: 1, 
                                  overflow: TextOverflow.ellipsis
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                                  onPressed: () => _removeAt(e.key),
                                ),
                              ),
                            ).animate().fadeIn().slideX(begin: 0.1, end: 0),
                          );
                        }),

                      if (_paths.isNotEmpty && _paths.length < 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextButton.icon(
                            onPressed: state.isLoading ? null : _addDocument,
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            label: Text(strings.t('addAnotherDocument')),
                          ),
                        ),
                    ],
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

                LoadingButton(
                  isLoading: state.isLoading,
                  onPressed: _paths.isEmpty
                      ? null
                      : () => regCubit.submitIndigentProofs(List.from(_paths)),
                  label: strings.t('submitRegistration'),
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          ),
          ),
          
          // Scanning Overlay (Google Vision API visualization)
          if (state.isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.75),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 240,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.accent, width: 2),
                        ),
                        child: Stack(
                          children: [
                            // Scanning line
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  color: AppTheme.accent,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accent.withValues(alpha: 0.8),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ).animate(onPlay: (c) => c.repeat()).moveY(begin: 0, end: 158, duration: 2.seconds, curve: Curves.easeInOut),
                            ),
                            // Face/Document icon hint
                            Center(
                              child: Icon(Icons.document_scanner_outlined, color: Colors.white.withValues(alpha: 0.5), size: 64),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        strings.t('scanningIndigentProofs'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.t('googleVisionAiProcessing'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(),
            ),
        ],
      ),
    );
  }
}
