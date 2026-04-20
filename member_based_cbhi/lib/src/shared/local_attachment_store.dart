import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' if (dart.library.html) 'db_stubs.dart';

// Import dart:io only for non-web platforms.
import 'dart:io' if (dart.library.html) 'web_stubs.dart'; 

class LocalAttachmentStore {
  LocalAttachmentStore._();

  /// Copies [sourcePath] to a persistent app-local folder and returns the new
  /// path. On web (where filesystem operations are not available) the
  /// original path is returned as-is.
  static Future<String> persist(
    String sourcePath, {
    required String category,
  }) async {
    // Web: no filesystem access – return the source path unchanged.
    if (kIsWeb) {
      return sourcePath;
    }

    try {
      // These classes will only be used on non-web platforms.
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return sourcePath;
      }

      final dbPath = await getDatabasesPath();
      final targetDirectory = Directory(
        p.join(dbPath, '..', 'attachments', category),
      );
      if (!await targetDirectory.exists()) {
        await targetDirectory.create(recursive: true);
      }

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}';
      final targetPath = p.join(targetDirectory.path, fileName);
      final copiedFile = await sourceFile.copy(targetPath);
      return copiedFile.path;
    } catch (_) {
      // Fallback: return original path if any I/O error occurs.
      return sourcePath;
    }
  }
}

// Minimal stubs for Web compilation if needed, though kIsWeb usually prunes it if handled correctly.
// But to be 100% safe from compiler errors, we define them or use 'dart:io' carefully.

