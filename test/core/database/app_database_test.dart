import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sub_tracker/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Categories', () {
    test('seed categories are inserted on creation', () async {
      final categories = await db.select(db.categories).get();
      expect(categories.length, 5);
      expect(categories.map((c) => c.name), containsAll(['Стриминг', 'AI-сервисы', 'Связь', 'Развлечения', 'Другое']));
    });

    test('can insert and retrieve a category', () async {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'test-id',
        name: 'Test',
        color: 0xFFFF0000,
        icon: 'star',
      ));
      final all = await db.select(db.categories).get();
      expect(all.any((c) => c.name == 'Test'), isTrue);
    });
  });

  group('Subscriptions', () {
    test('can insert and retrieve a subscription', () async {
      await db.into(db.subscriptions).insert(SubscriptionsCompanion.insert(
        id: 'sub-1',
        name: 'Netflix',
        amount: 22.99,
        currency: 'USD',
        billingPeriod: 'monthly',
        nextBillingDate: DateTime(2026, 4, 1),
        startDate: DateTime(2026, 1, 1),
        createdAt: DateTime.now(),
      ));
      final subs = await db.select(db.subscriptions).get();
      expect(subs.length, 1);
      expect(subs.first.name, 'Netflix');
    });
  });

  group('ExchangeRates', () {
    test('can upsert and retrieve exchange rate', () async {
      await db.into(db.exchangeRates).insertOnConflictUpdate(
        ExchangeRatesCompanion.insert(
          fromCurrency: 'USD',
          toCurrency: 'RUB',
          rate: 92.5,
          updatedAt: DateTime.now(),
        ),
      );
      final rates = await db.select(db.exchangeRates).get();
      expect(rates.length, 1);
      expect(rates.first.rate, 92.5);
    });
  });
}
