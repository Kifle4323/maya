// Web stub — dart:io is unavailable.
import 'package:flutter/material.dart';

Widget buildFileImage({
  required String path,
  required BoxFit fit,
  double? width,
  double? height,
  Widget? errorWidget,
}) {
  return errorWidget ?? const Icon(Icons.description_outlined, color: Colors.grey);
}
ImageProvider getFileImageProvider(String path) {
  // On web, we return a blank placeholder to satisfy the type system.
  // The UI should use kIsWeb to avoid showing this.
  return const AssetImage('assets/placeholder.png');
}
