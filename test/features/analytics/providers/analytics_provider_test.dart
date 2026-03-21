// test/features/analytics/providers/analytics_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kiper/core/currency/currency.dart';
import 'package:kiper/core/currency/exchange_rate_service.dart';
import 'package:kiper/features/analytics/providers/analytics_provider.dart';
import 'package:kiper/features/subscriptions/models/billing_period.dart';

void main() {
  final fallbackRates = ExchangeRateService.fallbackRates;

  AnalyticsSubscription makeSub({
    String id = 'sub-1',
    String name = 'Test',
    double amount = 100,
    Currency currency = Currency.rub,
    BillingPeriod billingPeriod = BillingPeriod.monthly,
    int? customPeriodDays,
    DateTime? startDate,
    DateTime? nextBillingDate,
    String status = 'active',
    String? categoryId,
  }) {
    return AnalyticsSubscription(
      id: id,
      name: name,
      amount: amount,
      currency: currency,
      billingPeriod: billingPeriod,
      customPeriodDays: customPeriodDays,
      startDate: startDate ?? DateTime(2026, 1, 1),
      nextBillingDate: nextBillingDate ?? DateTime(2026, 4, 1),
      status: status,
      categoryId: categoryId,
    );
  }

  group('AnalyticsCalculator.monthlyTotals', () {
    test('returns correct count of months (past + present + future)', () {
      final now = DateTime(2026, 3, 15);
      final subs = <AnalyticsSubscription>[];

      final totals = AnalyticsCalculator.monthlyTotals(
        subscriptions: subs,
        rates: fallbackRates,
        pastMonths: 3,
        futureMonths: 2,
        now: now,
      );

      // 3 past months (Dec, Jan, Feb) + current month (Mar) + 2 future months (Apr, May) = 6
      expect(totals.length, 6);
    });

    test('sums monthly subscription amounts for past months in RUB', () {
      final now = DateTime(2026, 3, 15);
      final sub = makeSub(
        amount: 500,
        currency: Currency.rub,
        billingPeriod: BillingPeriod.monthly,
        startDate: DateTime(2025, 10, 1),
      );

      final totals = AnalyticsCalculator.monthlyTotals(
        subscriptions: [sub],
        rates: fallbackRates,
        pastMonths: 3,
        futureMonths: 0,
        now: now,
      );

      // Months: Dec 2025, Jan 2026, Feb 2026, Mar 2026
      for (final t in totals) {
        expect(t.amount, closeTo(500, 0.001));
      }
    });

    test('past months have isForecast=false, future months isForecast=true', () {
      final now = DateTime(2026, 3, 15);
      final sub = makeSub(
        amount: 200,
        currency: Currency.rub,
        billingPeriod: BillingPeriod.monthly,
        startDate: DateTime(2025, 1, 1),
      );

      final totals = AnalyticsCalculator.monthlyTotals(
        subscriptions: [sub],
        rates: fallbackRates,
        pastMonths: 2,
        futureMonths: 2,
        now: now,
      );

      final currentMonth = DateTime(now.year, now.month, 1);
      for (final t in totals) {
        if (t.month.isBefore(currentMonth)) {
          expect(t.isForecast, isFalse, reason: '${t.month} should not be forecast');
        } else {
          expect(t.isForecast, isTrue, reason: '${t.month} should be forecast');
        }
      }
    });

    test('converts USD amounts to RUB using exchange rates', () {
      final now = DateTime(2026, 3, 15);
      const usdAmount = 10.0;
      final rates = {Currency.usd: 90.0, Currency.eur: 98.0};
      final sub = makeSub(
        amount: usdAmount,
        currency: Currency.usd,
        billingPeriod: BillingPeriod.monthly,
        startDate: DateTime(2026, 3, 1),
      );

      final totals = AnalyticsCalculator.monthlyTotals(
        subscriptions: [sub],
        rates: rates,
        pastMonths: 0,
        futureMonths: 0,
        now: now,
      );

      final march = totals.firstWhere((t) => t.month == DateTime(2026, 3, 1));
      expect(march.amount, closeTo(usdAmount * 90.0, 0.001));
    });

    test('quarterly subscription appears every 3 months', () {
      final now = DateTime(2026, 6, 15);
      final sub = makeSub(
        amount: 300,
        currency: Currency.rub,
        billingPeriod: BillingPeriod.quarterly,
        startDate: DateTime(2026, 1, 1),
      );

      final totals = AnalyticsCalculator.monthlyTotals(
        subscriptions: [sub],
        rates: fallbackRates,
        pastMonths: 5,
        futureMonths: 2,
        now: now,
      );

      // Start is Jan 2026, so charges at Jan, Apr, Jul
      // Range: Jan 2026 to Aug 2026
      final nonZero = totals.where((t) => t.amount > 0).toList();
      expect(nonZero.length, greaterThanOrEqualTo(2));
      for (final t in nonZero) {
        expect(t.amount, closeTo(300, 0.001));
      }
    });

    test('cancelled subscription is excluded', () {
      final now = DateTime(2026, 3, 15);
      final sub = makeSub(
        amount: 500,
        currency: Currency.rub,
        status: 'cancelled',
      );

      final totals = AnalyticsCalculator.monthlyTotals(
        subscriptions: [sub],
        rates: fallbackRates,
        pastMonths: 2,
        futureMonths: 2,
        now: now,
      );

      for (final t in totals) {
        expect(t.amount, 0.0);
      }
    });

    test('forecast months contain future charges', () {
      final now = DateTime(2026, 3, 15);
      final sub = makeSub(
        amount: 1000,
        currency: Currency.rub,
        billingPeriod: BillingPeriod.monthly,
        startDate: DateTime(2026, 1, 1),
      );

      final totals = AnalyticsCalculator.monthlyTotals(
        subscriptions: [sub],
        rates: fallbackRates,
        pastMonths: 0,
        futureMonths: 3,
        now: now,
      );

      final forecasts = totals.where((t) => t.isForecast).toList();
      expect(forecasts.length, greaterThan(0));
      for (final f in forecasts) {
        expect(f.amount, closeTo(1000, 0.001));
      }
    });
  });

  group('AnalyticsCalculator.categoryBreakdown', () {
    test('groups subscriptions by categoryId', () {
      final subs = [
        makeSub(id: '1', amount: 500, categoryId: 'cat-streaming', billingPeriod: BillingPeriod.monthly),
        makeSub(id: '2', amount: 300, categoryId: 'cat-streaming', billingPeriod: BillingPeriod.monthly),
        makeSub(id: '3', amount: 200, categoryId: 'cat-ai', billingPeriod: BillingPeriod.monthly),
      ];

      final breakdown = AnalyticsCalculator.categoryBreakdown(subs, fallbackRates);

      expect(breakdown['cat-streaming'], closeTo(800, 0.001));
      expect(breakdown['cat-ai'], closeTo(200, 0.001));
    });

    test('null categoryId is a separate group', () {
      final subs = [
        makeSub(id: '1', amount: 100, categoryId: null, billingPeriod: BillingPeriod.monthly),
        makeSub(id: '2', amount: 200, categoryId: 'cat-ai', billingPeriod: BillingPeriod.monthly),
      ];

      final breakdown = AnalyticsCalculator.categoryBreakdown(subs, fallbackRates);

      expect(breakdown.containsKey(null), isTrue);
      expect(breakdown[null], closeTo(100, 0.001));
    });

    test('applies monthlyEquivalent for non-monthly periods', () {
      final subs = [
        makeSub(id: '1', amount: 1200, categoryId: 'cat-a', billingPeriod: BillingPeriod.annual),
      ];

      final breakdown = AnalyticsCalculator.categoryBreakdown(subs, fallbackRates);

      // annual monthlyEquivalent = 1/12
      expect(breakdown['cat-a'], closeTo(1200 * (1 / 12), 0.001));
    });

    test('converts non-RUB currencies', () {
      final rates = {Currency.usd: 90.0, Currency.eur: 98.0};
      final subs = [
        makeSub(id: '1', amount: 10, currency: Currency.usd, categoryId: 'cat-a', billingPeriod: BillingPeriod.monthly),
      ];

      final breakdown = AnalyticsCalculator.categoryBreakdown(subs, rates);

      expect(breakdown['cat-a'], closeTo(10 * 90.0, 0.001));
    });

    test('paused subscriptions are excluded', () {
      final subs = [
        makeSub(id: '1', amount: 500, categoryId: 'cat-a', status: 'paused'),
      ];

      final breakdown = AnalyticsCalculator.categoryBreakdown(subs, fallbackRates);

      expect(breakdown.isEmpty, isTrue);
    });

    test('empty subscription list returns empty breakdown', () {
      final breakdown = AnalyticsCalculator.categoryBreakdown([], fallbackRates);
      expect(breakdown.isEmpty, isTrue);
    });
  });
}
