/// Platform-aware widget that renders a local file path as an image.
/// On web (dart:io unavailable) it shows a placeholder icon instead.
///
/// Usage:
///   NativeFileImage(path: '/path/to/file.jpg', fit: BoxFit.cover)
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

// On web this resolves to the stub; on native to dart:io.
import 'native_file_image_impl.dart'
    if (dart.library.html) 'native_file_image_web.dart' as impl;

class NativeFileImage extends StatelessWidget {
  const NativeFileImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorWidget,
  });

  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return errorWidget ??
          const Icon(Icons.description_outlined, color: Colors.grey);
    }
    return impl.buildFileImage(
      path: path,
      fit: fit,
      width: width,
      height: height,
      errorWidget: errorWidget,
    );
  }
}
