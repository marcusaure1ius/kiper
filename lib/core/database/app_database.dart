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
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedCategories();
    },
  );

  /// Call after database creation to populate test data (debug only).
  Future<void> seedTestSubscriptions() => _seedTestSubscriptions();

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

  Future<void> _seedTestSubscriptions() async {
    final now = DateTime.now();
    final testSubs = [
      // Стриминг (USD)
      SubscriptionsCompanion.insert(id: 'test-1', name: 'Netflix', amount: 22.99, currency: 'USD', billingPeriod: 'monthly', categoryId: const Value('cat-streaming'), nextBillingDate: now.add(const Duration(days: 5)), startDate: DateTime(2024, 3, 1), createdAt: now),
      SubscriptionsCompanion.insert(id: 'test-2', name: 'YouTube Premium', amount: 13.99, currency: 'USD', billingPeriod: 'monthly', categoryId: const Value('cat-streaming'), nextBillingDate: now.add(const Duration(days: 12)), startDate: DateTime(2023, 8, 15), createdAt: now),
      SubscriptionsCompanion.insert(id: 'test-3', name: 'Spotify', amount: 10.99, currency: 'USD', billingPeriod: 'monthly', categoryId: const Value('cat-streaming'), nextBillingDate: now.add(const Duration(days: 8)), startDate: DateTime(2022, 1, 10), createdAt: now),
      SubscriptionsCompanion.insert(id: 'test-4', name: 'Apple Music', amount: 10.99, currency: 'USD', billingPeriod: 'monthly', categoryId: const Value('cat-streaming'), nextBillingDate: now.add(const Duration(days: 20)), startDate: DateTime(2024, 6, 1), createdAt: now),
      SubscriptionsCompanion.insert(id: 'test-5', name: 'Яндекс Музыка', amount: 299, currency: 'RUB', billingPeriod: 'monthly', categoryId: const Value('cat-streaming'), nextBillingDate: now.add(const Duration(days: 3)), startDate: DateTime(2023, 11, 1), createdAt: now),
      SubscriptionsCompanion.insert(id: 'test-6', name: 'Кинопоиск', amount: 269, currency: 'RUB', billingPeriod: 'monthly', categoryId: const Value('cat-streaming'), nextBillingDate: now.add(const Duration(days: 15)), startDate: DateTime(2024, 1, 20), createdAt: now),

      // AI-сервисы (USD)
      SubscriptionsCompanion.insert(id: 'test-7', name: 'Claude Pro', amount: 20, currency: 'USD', billingPeriod: 'monthly', categoryId: const Value('cat-ai'), nextBillingDate: now.add(const Duration(days: 2)), startDate: DateTime(2024, 5, 1), createdAt: now),
      SubscriptionsCompanion.insert(id: 'test-8', name: 'ChatGPT Plus', amount: 20, currency: 'USD', billingPeriod: 'monthly', categoryId: const Value('cat-ai'), nextBillingDate: now.add(const Duration(days: 7)), startDate: DateTime(2023, 3, 15), createdAt: now),
      SubscriptionsCompanion.insert(id: 'test-9', name: 'Perplexity Pro', amount: 20, currency: 'USD', billingPeriod: 'monthly', categoryId: const Value('cat-ai'), nextBillingDate: now.add(const Duration(days: 18)), startDate: DateTime(2024, 9, 1), createdAt: now),
      SubscriptionsCompanion.insert(id: 'test-10', name: 'Google AI Premium', amount: 19.99, currency: 'USD', billingPeriod: 'monthly', categoryId: const Value('cat-ai'), nextBillingDate: now.add(const Duration(days: 25)), startDate: DateTime(2025, 1, 10), createdAt: now),
      SubscriptionsCompanion.insert(id: 'test-11', name: 'Midjourney', amount: 10, currency: 'USD', billingPeriod: 'monthly', categoryId: const Value('cat-ai'), nextBillingDate: now.add(const Duration(days: 11)), startDate: DateTime(2024, 7, 1), createdAt: now),

      // Связь (RUB)
      SubscriptionsCompanion.insert(id: 'test-12', name: 'МТС', amount: 890, currency: 'RUB', billingPeriod: 'monthly', categoryId: const Value('cat-telecom'), nextBillingDate: now.add(const Duration(days: 1)), startDate: DateTime(2020, 6, 1), createdAt: now),
      SubscriptionsCompanion.insert(id: 'test-13', name: 'Домашний интернет', amount: 750, currency: 'RUB', billingPeriod: 'monthly', categoryId: const Value('cat-telecom'), nextBillingDate: now.add(const Duration(days: 10)), startDate: DateTime(2021, 3, 1), createdAt: now),
      SubscriptionsCompanion.insert(id: 'test-14', name: 'Мегафон (жена)', amount: 650, currency: 'RUB', billingPeriod: 'monthly', categoryId: const Value('cat-telecom'), nextBillingDate: now.add(const Duration(days: 14)), startDate: DateTime(2022, 9, 1), createdAt: now),
      SubscriptionsCompanion.insert(id: 'test-15', name: 'Ростелеком ТВ', amount: 450, currency: 'RUB', billingPeriod: 'monthly', categoryId: const Value('cat-telecom'), nextBillingDate: now.add(const Duration(days: 22)), startDate: DateTime(2023, 1, 15), createdAt: now),

      // Развлечения
      SubscriptionsCompanion.insert(id: 'test-16', name: 'PlayStation Plus', amount: 59.99, currency: 'USD', billingPeriod: 'annual', categoryId: const Value('cat-entertainment'), nextBillingDate: now.add(const Duration(days: 90)), startDate: DateTime(2023, 6, 1), createdAt: now),
      SubscriptionsCompanion.insert(id: 'test-17', name: 'Xbox Game Pass', amount: 14.99, currency: 'USD', billingPeriod: 'monthly', categoryId: const Value('cat-entertainment'), nextBillingDate: now.add(const Duration(days: 6)), startDate: DateTime(2024, 2, 1), createdAt: now),
      SubscriptionsCompanion.insert(id: 'test-18', name: 'Nintendo Online', amount: 3.99, currency: 'USD', billingPeriod: 'monthly', categoryId: const Value('cat-entertainment'), nextBillingDate: now.add(const Duration(days: 16)), startDate: DateTime(2024, 11, 1), createdAt: now),

      // Другое
      SubscriptionsCompanion.insert(id: 'test-19', name: 'Notion Plus', amount: 10, currency: 'USD', billingPeriod: 'monthly', categoryId: const Value('cat-other'), nextBillingDate: now.add(const Duration(days: 4)), startDate: DateTime(2024, 4, 1), createdAt: now),
      SubscriptionsCompanion.insert(id: 'test-20', name: 'iCloud 200GB', amount: 2.99, currency: 'USD', billingPeriod: 'monthly', categoryId: const Value('cat-other'), nextBillingDate: now.add(const Duration(days: 9)), startDate: DateTime(2022, 5, 1), createdAt: now),
      SubscriptionsCompanion.insert(id: 'test-21', name: 'Фитнес клуб', amount: 3500, currency: 'RUB', billingPeriod: 'monthly', categoryId: const Value('cat-other'), nextBillingDate: now.add(const Duration(days: 13)), startDate: DateTime(2025, 1, 1), createdAt: now),
      SubscriptionsCompanion.insert(id: 'test-22', name: 'Яндекс Плюс', amount: 399, currency: 'RUB', billingPeriod: 'monthly', categoryId: const Value('cat-other'), nextBillingDate: now.add(const Duration(days: 17)), startDate: DateTime(2023, 5, 1), createdAt: now),
      SubscriptionsCompanion.insert(id: 'test-23', name: 'NordVPN', amount: 99.99, currency: 'USD', billingPeriod: 'annual', categoryId: const Value('cat-other'), nextBillingDate: now.add(const Duration(days: 120)), startDate: DateTime(2024, 8, 1), createdAt: now),
      SubscriptionsCompanion.insert(id: 'test-24', name: 'Dropbox Plus', amount: 11.99, currency: 'USD', billingPeriod: 'monthly', categoryId: const Value('cat-other'), nextBillingDate: now.add(const Duration(days: 21)), startDate: DateTime(2023, 10, 1), createdAt: now),
      SubscriptionsCompanion.insert(id: 'test-25', name: '1Password', amount: 2.99, currency: 'USD', billingPeriod: 'monthly', categoryId: const Value('cat-other'), nextBillingDate: now.add(const Duration(days: 27)), startDate: DateTime(2022, 12, 1), createdAt: now),
    ];

    // Одна приостановленная
    final pausedSub = SubscriptionsCompanion.insert(id: 'test-paused', name: 'Hulu', amount: 17.99, currency: 'USD', billingPeriod: 'monthly', categoryId: const Value('cat-streaming'), nextBillingDate: now.add(const Duration(days: 30)), startDate: DateTime(2024, 2, 1), createdAt: now, status: const Value('paused'));

    for (final sub in testSubs) {
      await into(subscriptions).insert(sub);
    }
    await into(subscriptions).insert(pausedSub);
  }
}
