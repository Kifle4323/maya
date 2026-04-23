// Web stub — flutter_image_compress is not available on web.
// compressImageForUpload is never called on web (kIsWeb guard in image_utils.dart),
// but dart2js still needs this symbol to compile.
Future<String> compressImageForUpload(
  String sourcePath, {
  int maxSizeKb = 500,
}) async =>
    sourcePath;
