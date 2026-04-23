---
inclusion: always
---

# Flutter Web / Vercel Deployment Rules

## Critical: dart2js compiles ALL imports
`kIsWeb` only guards runtime. For native-only plugins, use conditional imports.

## Native-only plugins — ALWAYS use conditional imports
- `flutter_image_compress` → use `image_compress_stub.dart` / `image_compress_native.dart`
- `local_auth` → use `biometric_stub.dart` / `biometric_native.dart`
- `sqflite_common_ffi` → use `db_stubs.dart` conditional import
- `dart:io` → always add `if (dart.library.html) 'shared/web_stubs.dart'`
- `Platform.isX` → always wrap in `if (!kIsWeb)` or use web_stubs.dart Platform stub
- `permission_handler` → use `if (dart.library.html) 'shared/permission_handler_stub.dart'`

## Web-safe plugins (no stubs needed)
- `flutter_secure_storage` — has web support
- `image_picker` — has web support
- `file_picker` — has web support
- `shared_preferences` — has web support
- `http` — has web support
- `connectivity_plus` — has web support

## pubspec.yaml rules
- `generate: false` must be explicit
- SDK: `'>=3.5.0 <4.0.0'`
- `sqflite_common_ffi_web: ^1.0.1+2`
- NO `l10n.yaml` file in project root

## vercel-build.sh rules
- Flutter version: 3.41.7
- NO `flutter create .`
- NO `l10n.yaml`
- Always `flutter clean` THEN `flutter pub get` before build (clean first)
- Build flags: `--no-tree-shake-icons --no-source-maps --no-pub`

## When adding a new package
1. Check if it has web support on pub.dev
2. If native-only: create stub + native conditional import pair
3. Never import native-only packages at the top level of any file
