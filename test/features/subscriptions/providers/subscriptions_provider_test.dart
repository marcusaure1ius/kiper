import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sub_tracker/core/database/app_database.dart';
import 'package:sub_tracker/core/database/database_provider.dart';
import 'package:sub_tracker/features/subscriptions/providers/subscriptions_provider.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Reads active subscriptions directly from the database (bypasses provider caching).
  Future<List<Subscription>> readActiveSubs() =>
      (db.select(db.subscriptions)..where((t) => t.status.equals('active'))).get();

  test('add and watch subscription', () async {
    await container.read(subscriptionsNotifierProvider.notifier).add(
      name: 'Netflix', amount: 22.99, currency: 'USD', billingPeriod: 'monthly',
      nextBillingDate: DateTime(2026, 4, 1), startDate: DateTime(2026, 1, 1),
    );
    final subs = await readActiveSubs();
    expect(subs.length, 1);
    expect(subs.first.name, 'Netflix');
  });

  test('pause subscription excludes from active list', () async {
    await container.read(subscriptionsNotifierProvider.notifier).add(
      name: 'Spotify', amount: 10.99, currency: 'USD', billingPeriod: 'monthly',
      nextBillingDate: DateTime(2026, 4, 1), startDate: DateTime(2026, 1, 1),
    );
    var subs = await readActiveSubs();
    final id = subs.first.id;
    await container.read(subscriptionsNotifierProvider.notifier).updateStatus(id, 'paused');
    subs = await readActiveSubs();
    expect(subs.isEmpty, isTrue);
  });

  test('advanceBillingDates moves past dates forward', () async {
    await container.read(subscriptionsNotifierProvider.notifier).add(
      name: 'Test', amount: 100, currency: 'RUB', billingPeriod: 'monthly',
      nextBillingDate: DateTime(2026, 1, 1), startDate: DateTime(2025, 6, 1),
    );
    await container.read(subscriptionsNotifierProvider.notifier).advanceBillingDates();
    final subs = await readActiveSubs();
    expect(subs.first.nextBillingDate.isAfter(DateTime.now()), isTrue);
  });

  test('cancel subscription soft-deletes it', () async {
    await container.read(subscriptionsNotifierProvider.notifier).add(
      name: 'ToCancel', amount: 50, currency: 'RUB', billingPeriod: 'monthly',
      nextBillingDate: DateTime(2026, 4, 1), startDate: DateTime(2026, 1, 1),
    );
    var subs = await readActiveSubs();
    final id = subs.first.id;
    await container.read(subscriptionsNotifierProvider.notifier).updateStatus(id, 'cancelled');
    subs = await readActiveSubs();
    expect(subs.isEmpty, isTrue);
    final all = await db.select(db.subscriptions).get();
    expect(all.any((s) => s.id == id), isTrue);
  });
}
