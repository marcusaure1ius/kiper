import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'dart:io';
import 'package:sub_tracker/core/database/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Override in main.dart');
});

Future<AppDatabase> createDatabase() async {
  // Ensure sqlite3 native library is loaded on Android
  await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();

  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'subtracker.db'));
  return AppDatabase(NativeDatabase.createInBackground(file));
}
