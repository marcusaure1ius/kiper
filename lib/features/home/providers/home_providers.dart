import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:kiper/core/currency/currency.dart';
import 'package:kiper/core/currency/exchange_rate_provider.dart';
import 'package:kiper/core/currency/exchange_rate_service.dart';
import 'package:kiper/features/subscriptions/models/billing_period.dart';
import 'package:kiper/features/subscriptions/providers/subscriptions_provider.dart';
import 'package:kiper/features/home/models/payment_event.dart';

part 'home_providers.g.dart';

/// Total monthly cost of all active subscriptions in RUB.
@riverpod
Future<double> monthlyTotalRub(Ref ref) async {
  final subsAsync = ref.watch(watchActiveSubscriptionsProvider);
  final subs = subsAsync.value ?? [];
  final rates = await ref.watch(exchangeRatesProvider.future);

  double total = 0.0;
  for (final sub in subs) {
    final currency = Currency.values.firstWhere(
      (c) => c.code == sub.currency,
      orElse: () => Currency.rub,
    );
    final billingPeriod = BillingPeriod.values.firstWhere(
      (p) => p.name == sub.billingPeriod,
      orElse: () => BillingPeriod.monthly,
    );
    final amountInRub = ExchangeRateService.convertToRub(sub.amount, currency, rates);
    total += amountInRub * billingPeriod.monthlyEquivalent;
  }
  return total;
}

/// Progress through the current month: paid vs remaining amounts in RUB.
@riverpod
Future<({double paid, double remaining})> monthProgress(Ref ref) async {
  final subsAsync = ref.watch(watchActiveSubscriptionsProvider);
  final subs = subsAsync.value ?? [];
  final rates = await ref.watch(exchangeRatesProvider.future);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 1);

  double paid = 0.0;
  double remaining = 0.0;

  for (final sub in subs) {
    final currency = Currency.values.firstWhere(
      (c) => c.code == sub.currency,
      orElse: () => Currency.rub,
    );
    final billingPeriod = BillingPeriod.values.firstWhere(
      (p) => p.name == sub.billingPeriod,
      orElse: () => BillingPeriod.monthly,
    );
    final amountInRub = ExchangeRateService.convertToRub(sub.amount, currency, rates);

    var billingDate = sub.startDate;

    // Advance to roughly the start of the current month
    while (billingDate.isBefore(monthStart)) {
      billingDate = _nextBillingDate(billingDate, billingPeriod, sub.customPeriodDays);
    }

    // Collect dates within the current month
    while (billingDate.isBefore(monthEnd)) {
      final billingDay = DateTime(billingDate.year, billingDate.month, billingDate.day);
      if (!billingDate.isBefore(monthStart)) {
        if (billingDay.isBefore(today)) {
          paid += amountInRub;
        } else {
          remaining += amountInRub;
        }
      }
      billingDate = _nextBillingDate(billingDate, billingPeriod, sub.customPeriodDays);
    }
  }

  return (paid: paid, remaining: remaining);
}

/// Payment events from the last 90 days, sorted newest-first.
@riverpod
Future<List<PaymentEvent>> pastPayments(Ref ref) async {
  final subsAsync = ref.watch(watchActiveSubscriptionsProvider);
  final subs = subsAsync.value ?? [];

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final rangeStart = today.subtract(const Duration(days: 90));

  final events = <PaymentEvent>[];

  for (final sub in subs) {
    final billingPeriod = BillingPeriod.values.firstWhere(
      (p) => p.name == sub.billingPeriod,
      orElse: () => BillingPeriod.monthly,
    );

    var billingDate = sub.startDate;

    // Advance to start of the range
    while (billingDate.isBefore(rangeStart)) {
      billingDate = _nextBillingDate(billingDate, billingPeriod, sub.customPeriodDays);
    }

    // Collect events in range [rangeStart, today)
    while (billingDate.isBefore(today)) {
      final billingDay = DateTime(billingDate.year, billingDate.month, billingDate.day);
      if (!billingDay.isBefore(rangeStart)) {
        events.add(PaymentEvent(
          subscriptionId: sub.id,
          name: sub.name,
          icon: sub.icon,
          amount: sub.amount,
          currency: sub.currency,
          date: billingDate,
          categoryId: sub.categoryId,
        ));
      }
      billingDate = _nextBillingDate(billingDate, billingPeriod, sub.customPeriodDays);
    }
  }

  events.sort((a, b) => b.date.compareTo(a.date));
  return events;
}

/// Payment events for the next 90 days, sorted soonest-first.
@riverpod
Future<List<PaymentEvent>> futurePayments(Ref ref) async {
  final subsAsync = ref.watch(watchActiveSubscriptionsProvider);
  final subs = subsAsync.value ?? [];

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final rangeEnd = today.add(const Duration(days: 90));

  final events = <PaymentEvent>[];

  for (final sub in subs) {
    final billingPeriod = BillingPeriod.values.firstWhere(
      (p) => p.name == sub.billingPeriod,
      orElse: () => BillingPeriod.monthly,
    );

    var billingDate = sub.startDate;

    // Advance to today
    while (billingDate.isBefore(today)) {
      billingDate = _nextBillingDate(billingDate, billingPeriod, sub.customPeriodDays);
    }

    // Collect events in range [today, rangeEnd)
    while (billingDate.isBefore(rangeEnd)) {
      events.add(PaymentEvent(
        subscriptionId: sub.id,
        name: sub.name,
        icon: sub.icon,
        amount: sub.amount,
        currency: sub.currency,
        date: billingDate,
        categoryId: sub.categoryId,
      ));
      billingDate = _nextBillingDate(billingDate, billingPeriod, sub.customPeriodDays);
    }
  }

  events.sort((a, b) => a.date.compareTo(b.date));
  return events;
}

DateTime _nextBillingDate(DateTime current, BillingPeriod period, int? customPeriodDays) {
  if (period == BillingPeriod.custom && customPeriodDays != null) {
    return period.nextDateCustom(current, customPeriodDays);
  }
  return period.nextDate(current);
}
