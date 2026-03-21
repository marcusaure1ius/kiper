// lib/features/subscriptions/widgets/total_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiper/core/currency/currency.dart';
import 'package:kiper/core/currency/exchange_rate_provider.dart';
import 'package:kiper/core/currency/exchange_rate_service.dart';
import 'package:kiper/core/database/app_database.dart';
import 'package:kiper/features/subscriptions/models/billing_period.dart';

class TotalHeader extends ConsumerWidget {
  const TotalHeader({super.key, required this.subscriptions});

  final List<Subscription> subscriptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ratesAsync = ref.watch(exchangeRatesProvider);

    return ratesAsync.when(
      data: (rates) {
        double totalMonthlyRub = 0;
        for (final sub in subscriptions) {
          if (sub.status != 'active') continue;
          final currency = Currency.values.firstWhere(
            (c) => c.code == sub.currency,
            orElse: () => Currency.rub,
          );
          final period = BillingPeriod.values.firstWhere(
            (p) => p.name == sub.billingPeriod,
            orElse: () => BillingPeriod.monthly,
          );
          final amountInRub = ExchangeRateService.convertToRub(sub.amount, currency, rates);
          totalMonthlyRub += amountInRub * period.monthlyEquivalent;
        }

        return Card(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Итого в месяц',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₽${totalMonthlyRub.toStringAsFixed(0)}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        margin: EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
