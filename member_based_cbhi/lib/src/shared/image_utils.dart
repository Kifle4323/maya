import 'dart:convert' show base64Encode;

import 'package:flutter/foundation.dart';

// dart:io + flutter_image_compress + path_provider are native-only.
// On web these imports resolve to stubs that return early.
import 'dart:io' if (dart.library.html) 'web_stubs.dart';
import 'image_compress_stub.dart'
    if (dart.library.io) 'image_compress_native.dart' as compress;

/// Compresses an image file to max 500KB before upload.
/// Returns the path to the compressed file.
/// Falls back to original path if compression fails or on web.
Future<String> compressImageForUpload(
  String sourcePath, {
  int maxSizeKb = 500,
}) async {
  if (kIsWeb) return sourcePath;
  return compress.compressImageForUpload(sourcePath, maxSizeKb: maxSizeKb);
}

/// Converts a local file to base64 string for API upload.
/// Returns null if file doesn't exist or on web.
Future<String?> fileToBase64(String filePath) async {
  if (kIsWeb) return null;
  try {
    final file = File(filePath);
    if (!file.existsSync()) return null;
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  } catch (_) {
    return null;
  }
}
