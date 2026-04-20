import 'dart:io' if (dart.library.html) '../shared/web_stubs.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;


import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../cbhi_localizations.dart';
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

    await Permission.camera.request();
    await Permission.photos.request();
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
              title: Text(strings.t('chooseImage')),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.t('supportingDocuments'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              strings.t('indigentProofDescription'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            ..._paths.asMap().entries.map((e) {
              final path = e.value;
              final name = p.basename(path);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeAt(e.key),
                  ),
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: state.isLoading ? null : _addDocument,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(strings.t('addDocument')),
            ),
            const SizedBox(height: 28),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  state.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (state.isLoading || _paths.isEmpty)
                    ? null
                    : () => regCubit.submitIndigentProofs(List.from(_paths)),
                child: state.isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(strings.t('submitRegistration')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
