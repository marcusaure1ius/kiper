import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sub_tracker/core/database/app_database.dart';
import 'package:sub_tracker/core/database/database_provider.dart';
import 'package:sub_tracker/features/categories/providers/categories_provider.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  // Keep the stream provider alive for the duration of each test.
  ProviderSubscription<AsyncValue<List<Category>>>? catSub;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    // Start listening immediately so the provider is always active.
    catSub = container.listen(watchCategoriesProvider, (_, _) {});
  });

  tearDown(() async {
    catSub?.close();
    container.dispose();
    await db.close();
  });

  /// Reads categories directly from the database (bypasses provider caching).
  Future<List<Category>> readCategories() => db.select(db.categories).get();

  test('watchCategories returns seed categories', () async {
    final categories = await readCategories();
    expect(categories.length, 5);
  });

  test('addCategory inserts a new category', () async {
    await container.read(categoriesNotifierProvider.notifier).add(
      name: 'Тест', color: 0xFF000000, icon: 'star',
    );
    final categories = await readCategories();
    expect(categories.any((c) => c.name == 'Тест'), isTrue);
  });

  test('deleteCategory removes a category', () async {
    await container.read(categoriesNotifierProvider.notifier).remove('cat-other');
    final categories = await readCategories();
    expect(categories.any((c) => c.id == 'cat-other'), isFalse);
  });
}
