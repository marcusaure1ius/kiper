import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:sub_tracker/core/database/app_database.dart';
import 'package:sub_tracker/core/database/database_provider.dart';
import 'package:sub_tracker/features/subscriptions/models/billing_period.dart';

part 'subscriptions_provider.g.dart';

// Alias to match the expected provider name used across the app.
// Riverpod v4 generates `subscriptionsProvider` for SubscriptionsNotifier,
// but we expose it as `subscriptionsNotifierProvider` for clarity.
final subscriptionsNotifierProvider = subscriptionsProvider;

final watchActiveSubscriptionsProvider = StreamProvider<List<Subscription>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.subscriptions)
        ..where((t) => t.status.equals('active')))
      .watch();
});

final watchVisibleSubscriptionsProvider = StreamProvider<List<Subscription>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.subscriptions)
        ..where((t) => t.status.equals('active') | t.status.equals('paused')))
      .watch();
});

final watchAllSubscriptionsProvider = StreamProvider<List<Subscription>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.subscriptions).watch();
});

@riverpod
class SubscriptionsNotifier extends _$SubscriptionsNotifier {
  @override
  FutureOr<void> build() {}

  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> add({
    required String name,
    required double amount,
    required String currency,
    required String billingPeriod,
    required DateTime nextBillingDate,
    required DateTime startDate,
    String? icon,
    int? customPeriodDays,
    String? categoryId,
    int reminderDaysBefore = 1,
    String? note,
  }) async {
    await _db.into(_db.subscriptions).insert(SubscriptionsCompanion.insert(
      id: const Uuid().v4(),
      name: name,
      amount: amount,
      currency: currency,
      billingPeriod: billingPeriod,
      nextBillingDate: nextBillingDate,
      startDate: startDate,
      createdAt: DateTime.now(),
      icon: Value(icon),
      customPeriodDays: Value(customPeriodDays),
      categoryId: Value(categoryId),
      reminderDaysBefore: Value(reminderDaysBefore),
      note: Value(note),
    ));
    // TODO(Task 15+18): schedule notification after inserting
  }

  Future<void> updateSubscription({
    required String id,
    String? name,
    double? amount,
    String? currency,
    String? billingPeriod,
    DateTime? nextBillingDate,
    DateTime? startDate,
    Value<String?> icon = const Value.absent(),
    Value<int?> customPeriodDays = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    int? reminderDaysBefore,
    Value<String?> note = const Value.absent(),
  }) async {
    await (_db.update(_db.subscriptions)..where((t) => t.id.equals(id))).write(
      SubscriptionsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        amount: amount != null ? Value(amount) : const Value.absent(),
        currency: currency != null ? Value(currency) : const Value.absent(),
        billingPeriod: billingPeriod != null ? Value(billingPeriod) : const Value.absent(),
        nextBillingDate: nextBillingDate != null ? Value(nextBillingDate) : const Value.absent(),
        startDate: startDate != null ? Value(startDate) : const Value.absent(),
        icon: icon,
        customPeriodDays: customPeriodDays,
        categoryId: categoryId,
        reminderDaysBefore: reminderDaysBefore != null ? Value(reminderDaysBefore) : const Value.absent(),
        note: note,
      ),
    );
    // TODO(Task 15+18): reschedule notification after updating
  }

  Future<void> updateStatus(String id, String status) async {
    await (_db.update(_db.subscriptions)..where((t) => t.id.equals(id))).write(
      SubscriptionsCompanion(status: Value(status)),
    );
    // TODO(Task 15+18): cancel notification if paused/cancelled
  }

  Future<void> advanceBillingDates() async {
    final now = DateTime.now();
    final subs = await (_db.select(_db.subscriptions)
          ..where((t) => t.status.equals('active')))
        .get();

    for (final sub in subs) {
      if (sub.nextBillingDate.isBefore(now)) {
        final period = BillingPeriod.values.firstWhere(
          (p) => p.name == sub.billingPeriod,
          orElse: () => BillingPeriod.monthly,
        );

        var next = sub.nextBillingDate;
        while (next.isBefore(now)) {
          if (period == BillingPeriod.custom && sub.customPeriodDays != null) {
            next = period.nextDateCustom(next, sub.customPeriodDays!);
          } else {
            next = period.nextDate(next);
          }
        }

        await (_db.update(_db.subscriptions)..where((t) => t.id.equals(sub.id))).write(
          SubscriptionsCompanion(nextBillingDate: Value(next)),
        );
        // TODO(Task 15+18): reschedule notification after advancing date
      }
    }
  }
}
