import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:kiper/core/database/app_database.dart';
import 'package:kiper/core/database/database_provider.dart';

part 'categories_provider.g.dart';

// Alias to match the expected provider name used across the app.
// Riverpod v4 generates `categoriesProvider` for CategoriesNotifier,
// but we expose it as `categoriesNotifierProvider` for clarity.
final categoriesNotifierProvider = categoriesProvider;

final watchCategoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.categories).watch();
});

@riverpod
class CategoriesNotifier extends _$CategoriesNotifier {
  @override
  FutureOr<void> build() {}

  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> add({required String name, required int color, required String icon}) async {
    await _db.into(_db.categories).insert(CategoriesCompanion.insert(
      id: const Uuid().v4(), name: name, color: color, icon: icon,
    ));
  }

  Future<void> updateCategory({required String id, required String name, required int color, required String icon}) async {
    await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(name: Value(name), color: Value(color), icon: Value(icon)),
    );
  }

  Future<void> remove(String id) async {
    // Null out categoryId for subscriptions in this category
    await (_db.update(_db.subscriptions)..where((t) => t.categoryId.equals(id))).write(
      const SubscriptionsCompanion(categoryId: Value(null)),
    );
    await (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
  }
}
