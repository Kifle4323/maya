import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' if (dart.library.html) 'db_stubs.dart';

// Import dart:io only for non-web platforms.
import 'dart:io' if (dart.library.html) 'web_stubs.dart'; 

class LocalAttachmentStore {
  LocalAttachmentStore._();

  /// In-memory byte cache for web — file_picker provides bytes on web
  /// but no filesystem path, so we store them here keyed by a synthetic path.
  static final _webBytesCache = <String, Uint8List>{};

  /// Store bytes on web and return a synthetic path key.
  /// On native, this is a no-op (returns [path] unchanged).
  static String putWebBytes(String key, Uint8List bytes) {
    if (kIsWeb) {
      _webBytesCache[key] = bytes;
    }
    return key;
  }

  /// Retrieve cached bytes for a web path key.
  /// Returns null if not found or not on web.
  static Uint8List? getWebBytes(String path) {
    if (!kIsWeb) return null;
    return _webBytesCache[path];
  }

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

