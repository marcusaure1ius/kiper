// lib/features/analytics/providers/analytics_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:kiper/core/currency/currency.dart';
import 'package:kiper/core/currency/exchange_rate_provider.dart';
import 'package:kiper/core/currency/exchange_rate_service.dart';
import 'package:kiper/features/subscriptions/models/billing_period.dart';
import 'package:kiper/features/subscriptions/providers/subscriptions_provider.dart';

part 'analytics_provider.g.dart';

class AnalyticsSubscription {
  final String id;
  final String name;
  final double amount;
  final Currency currency;
  final BillingPeriod billingPeriod;
  final int? customPeriodDays;
  final DateTime startDate;
  final DateTime nextBillingDate;
  final String status;
  final String? categoryId;

  const AnalyticsSubscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.currency,
    required this.billingPeriod,
    this.customPeriodDays,
    required this.startDate,
    required this.nextBillingDate,
    required this.status,
    this.categoryId,
  });
}

class MonthlyTotal {
  final DateTime month; // first day of month
  final double amount; // in RUB
  final bool isForecast;

  const MonthlyTotal({
    required this.month,
    required this.amount,
    required this.isForecast,
  });
}

class AnalyticsCalculator {
  /// Returns monthly totals for past [pastMonths] and future [futureMonths] months.
  /// Iterates from each subscription's startDate forward, summing charges per month.
  static List<MonthlyTotal> monthlyTotals({
    required List<AnalyticsSubscription> subscriptions,
    required Map<Currency, double> rates,
    required int pastMonths,
    required int futureMonths,
    required DateTime now,
  }) {
    final startOfNow = DateTime(now.year, now.month, 1);
    final rangeStart = DateTime(startOfNow.year, startOfNow.month - pastMonths, 1);
    final rangeEnd = DateTime(startOfNow.year, startOfNow.month + futureMonths + 1, 1);

    // Build a map of month -> amount
    final totals = <DateTime, double>{};

    // Initialize all months in range with 0
    var cursor = rangeStart;
    while (cursor.isBefore(rangeEnd)) {
      totals[cursor] = 0.0;
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    for (final sub in subscriptions) {
      // Only include active (and potentially paused) subscriptions that have started
      if (sub.status == 'cancelled') continue;

      // Start iterating from the subscription startDate
      var billingDate = sub.startDate;

      // Advance to the range start if needed
      while (billingDate.isBefore(rangeStart)) {
        billingDate = _nextBillingDate(billingDate, sub.billingPeriod, sub.customPeriodDays);
      }

      // Accumulate charges within the range
      while (billingDate.isBefore(rangeEnd)) {
        final monthKey = DateTime(billingDate.year, billingDate.month, 1);
        if (totals.containsKey(monthKey)) {
          final amountInRub = ExchangeRateService.convertToRub(sub.amount, sub.currency, rates);
          totals[monthKey] = (totals[monthKey] ?? 0) + amountInRub;
        }
        billingDate = _nextBillingDate(billingDate, sub.billingPeriod, sub.customPeriodDays);
      }
    }

    final currentMonth = DateTime(now.year, now.month, 1);

    return totals.entries.map((e) => MonthlyTotal(
      month: e.key,
      amount: e.value,
      isForecast: !e.key.isBefore(currentMonth),
    )).toList()
      ..sort((a, b) => a.month.compareTo(b.month));
  }

  static DateTime _nextBillingDate(DateTime current, BillingPeriod period, int? customPeriodDays) {
    if (period == BillingPeriod.custom && customPeriodDays != null) {
      return period.nextDateCustom(current, customPeriodDays);
    }
    return period.nextDate(current);
  }

  /// Returns weekly totals for past [pastWeeks] and future [futureWeeks] weeks.
  static List<MonthlyTotal> weeklyTotals({
    required List<AnalyticsSubscription> subscriptions,
    required Map<Currency, double> rates,
    required int pastWeeks,
    required int futureWeeks,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    // Monday of current week
    final currentWeekStart = today.subtract(Duration(days: today.weekday - 1));
    final rangeStart = currentWeekStart.subtract(Duration(days: pastWeeks * 7));
    final rangeEnd = currentWeekStart.add(Duration(days: (futureWeeks + 1) * 7));

    final totals = <DateTime, double>{};
    var cursor = rangeStart;
    while (cursor.isBefore(rangeEnd)) {
      totals[cursor] = 0.0;
      cursor = cursor.add(const Duration(days: 7));
    }

    for (final sub in subscriptions) {
      if (sub.status == 'cancelled') continue;

      var billingDate = sub.startDate;
      while (billingDate.isBefore(rangeStart)) {
        billingDate = _nextBillingDate(billingDate, sub.billingPeriod, sub.customPeriodDays);
      }

      while (billingDate.isBefore(rangeEnd)) {
        final bd = DateTime(billingDate.year, billingDate.month, billingDate.day);
        final weekStart = bd.subtract(Duration(days: bd.weekday - 1));

        if (totals.containsKey(weekStart)) {
          final amountInRub = ExchangeRateService.convertToRub(sub.amount, sub.currency, rates);
          totals[weekStart] = (totals[weekStart] ?? 0) + amountInRub;
        }
        billingDate = _nextBillingDate(billingDate, sub.billingPeriod, sub.customPeriodDays);
      }
    }

    return totals.entries.map((e) => MonthlyTotal(
      month: e.key,
      amount: e.value,
      isForecast: !e.key.isBefore(currentWeekStart),
    )).toList()
      ..sort((a, b) => a.month.compareTo(b.month));
  }

  /// Returns total spend per category (in RUB) for the past [pastMonths] months.
  static Map<String?, double> categoryTotalsForPeriod({
    required List<AnalyticsSubscription> subscriptions,
    required Map<Currency, double> rates,
    required int pastMonths,
    required DateTime now,
  }) {
    final rangeStart = DateTime(now.year, now.month - pastMonths + 1, 1);
    final rangeEnd = DateTime(now.year, now.month + 1, 1);

    final totals = <String?, double>{};

    for (final sub in subscriptions) {
      if (sub.status == 'cancelled') continue;

      var billingDate = sub.startDate;
      while (billingDate.isBefore(rangeStart)) {
        billingDate = _nextBillingDate(billingDate, sub.billingPeriod, sub.customPeriodDays);
      }

      while (billingDate.isBefore(rangeEnd)) {
        final amountInRub = ExchangeRateService.convertToRub(sub.amount, sub.currency, rates);
        totals[sub.categoryId] = (totals[sub.categoryId] ?? 0) + amountInRub;
        billingDate = _nextBillingDate(billingDate, sub.billingPeriod, sub.customPeriodDays);
      }
    }

    return totals;
  }

  /// Returns monthly spend per category (in RUB), using monthlyEquivalent.
  static Map<String?, double> categoryBreakdown(
    List<AnalyticsSubscription> subscriptions,
    Map<Currency, double> rates,
  ) {
    final breakdown = <String?, double>{};
    for (final sub in subscriptions) {
      if (sub.status != 'active') continue;
      final monthlyAmountInRub = ExchangeRateService.convertToRub(
        sub.amount * sub.billingPeriod.monthlyEquivalent,
        sub.currency,
        rates,
      );
      breakdown[sub.categoryId] = (breakdown[sub.categoryId] ?? 0) + monthlyAmountInRub;
    }
    return breakdown;
  }
}

// Provider that converts subscriptions from DB format to AnalyticsSubscription list
@riverpod
Future<List<AnalyticsSubscription>> analyticsSubscriptions(Ref ref) async {
  final subsAsync = ref.watch(watchAllSubscriptionsProvider);
  final subs = subsAsync.value ?? [];
  return subs.map((sub) {
    final currency = Currency.values.firstWhere(
      (c) => c.name == sub.currency.toLowerCase(),
      orElse: () => Currency.rub,
    );
    final billingPeriod = BillingPeriod.values.firstWhere(
      (p) => p.name == sub.billingPeriod,
      orElse: () => BillingPeriod.monthly,
    );
    return AnalyticsSubscription(
      id: sub.id,
      name: sub.name,
      amount: sub.amount,
      currency: currency,
      billingPeriod: billingPeriod,
      customPeriodDays: sub.customPeriodDays,
      startDate: sub.startDate,
      nextBillingDate: sub.nextBillingDate,
      status: sub.status,
      categoryId: sub.categoryId,
    );
  }).toList();
}

@riverpod
Future<List<MonthlyTotal>> monthlyTotals(Ref ref) async {
  final subs = await ref.watch(analyticsSubscriptionsProvider.future);
  final rates = await ref.watch(exchangeRatesProvider.future);
  return AnalyticsCalculator.monthlyTotals(
    subscriptions: subs,
    rates: rates,
    pastMonths: 6,
    futureMonths: 3,
    now: DateTime.now(),
  );
}

@riverpod
Future<List<MonthlyTotal>> weeklyTotals(Ref ref) async {
  final subs = await ref.watch(analyticsSubscriptionsProvider.future);
  final rates = await ref.watch(exchangeRatesProvider.future);
  return AnalyticsCalculator.weeklyTotals(
    subscriptions: subs,
    rates: rates,
    pastWeeks: 6,
    futureWeeks: 4,
    now: DateTime.now(),
  );
}

@riverpod
Future<Map<String?, double>> categoryTotals6m(Ref ref) async {
  final subs = await ref.watch(analyticsSubscriptionsProvider.future);
  final rates = await ref.watch(exchangeRatesProvider.future);
  return AnalyticsCalculator.categoryTotalsForPeriod(
    subscriptions: subs,
    rates: rates,
    pastMonths: 6,
    now: DateTime.now(),
  );
}

@riverpod
Future<Map<String?, double>> categoryBreakdown(Ref ref) async {
  final subs = await ref.watch(analyticsSubscriptionsProvider.future);
  final rates = await ref.watch(exchangeRatesProvider.future);
  return AnalyticsCalculator.categoryBreakdown(subs, rates);
}
