// Native (dart:io) implementation.
import 'dart:io';
import 'package:flutter/material.dart';

Widget buildFileImage({
  required String path,
  required BoxFit fit,
  double? width,
  double? height,
  Widget? errorWidget,
}) {
  return Image.file(
    File(path),
    fit: fit,
    width: width,
    height: height,
    errorBuilder: (_, __, ___) =>
        errorWidget ?? const Icon(Icons.broken_image_outlined, color: Colors.grey),
  );
}
