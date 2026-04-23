// Native implementation — dart:io is available here.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> compressImageForUpload(
  String sourcePath, {
  int maxSizeKb = 500,
}) async {
  try {
    final file = File(sourcePath);
    if (!file.existsSync()) return sourcePath;

    final originalSize = await file.length();
    final maxBytes = maxSizeKb * 1024;

    if (originalSize <= maxBytes) return sourcePath;

    final ext = p.extension(sourcePath).toLowerCase();
    final isJpeg = ext == '.jpg' || ext == '.jpeg';
    final isPng = ext == '.png';
    if (!isJpeg && !isPng) return sourcePath;

    final tempDir = await getTemporaryDirectory();
    final targetPath = p.join(
      tempDir.path,
      'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    int quality = 85;
    Uint8List? compressed;

    while (quality >= 40) {
      compressed = await FlutterImageCompress.compressWithFile(
        sourcePath,
        minWidth: 1024,
        minHeight: 1024,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (compressed == null) break;
      if (compressed.length <= maxBytes) break;
      quality -= 15;
    }

    if (compressed == null || compressed.isEmpty) return sourcePath;

    await File(targetPath).writeAsBytes(compressed);

    debugPrint(
      '[ImageUtils] Compressed ${(originalSize / 1024).toStringAsFixed(0)}KB → '
      '${(compressed.length / 1024).toStringAsFixed(0)}KB (quality: $quality)',
    );

    return targetPath;
  } catch (e) {
    debugPrint('[ImageUtils] Compression failed: $e — using original');
    return sourcePath;
  }
}
