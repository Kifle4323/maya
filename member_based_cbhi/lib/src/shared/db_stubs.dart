// Minimal stubs for sqflite_common_ffi types when on Web
// These satisfy the compiler for types used in cbhi_data.dart.

typedef Database = dynamic;

class ConflictAlgorithm {
  static const dynamic replace = null;
}

dynamic get databaseFactoryFfi => null;
dynamic databaseFactory;

void sqfliteFfiInit() {}

Future<String> getDatabasesPath() async => '';

Future<dynamic> openDatabase(
  String path, {
  int? version,
  Future<void> Function(dynamic db, int version)? onCreate,
}) async => null;
