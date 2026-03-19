import 'package:drift/drift.dart';

part 'app_database.g.dart';

class Subscriptions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text().nullable()();
  RealColumn get amount => real()();
  TextColumn get currency => text()();
  TextColumn get billingPeriod => text()();
  IntColumn get customPeriodDays => integer().nullable()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  DateTimeColumn get nextBillingDate => dateTime()();
  IntColumn get reminderDaysBefore => integer().withDefault(const Constant(1))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get startDate => dateTime()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get color => integer()();
  TextColumn get icon => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class ExchangeRates extends Table {
  TextColumn get fromCurrency => text()();
  TextColumn get toCurrency => text()();
  RealColumn get rate => real()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {fromCurrency, toCurrency};
}

@DriftDatabase(tables: [Subscriptions, Categories, ExchangeRates])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedCategories();
    },
  );

  Future<void> _seedCategories() async {
    final seeds = [
      CategoriesCompanion.insert(id: 'cat-streaming', name: 'Стриминг', color: 0xFF7C4DFF, icon: 'movie'),
      CategoriesCompanion.insert(id: 'cat-ai', name: 'AI-сервисы', color: 0xFF2196F3, icon: 'smart_toy'),
      CategoriesCompanion.insert(id: 'cat-telecom', name: 'Связь', color: 0xFFFF6B35, icon: 'phone_android'),
      CategoriesCompanion.insert(id: 'cat-entertainment', name: 'Развлечения', color: 0xFFE50914, icon: 'sports_esports'),
      CategoriesCompanion.insert(id: 'cat-other', name: 'Другое', color: 0xFF9E9E9E, icon: 'category'),
    ];
    for (final seed in seeds) {
      await into(categories).insert(seed);
    }
  }
}
