// lib/shared/widgets/currency_text.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sub_tracker/core/currency/currency.dart';
import 'package:sub_tracker/core/currency/exchange_rate_provider.dart';
import 'package:sub_tracker/core/currency/exchange_rate_service.dart';

class CurrencyText extends ConsumerWidget {
  const CurrencyText({
    super.key,
    required this.amount,
    required this.currency,
    this.style,
    this.rubStyle,
    this.showRubEquivalent = true,
  });

  final double amount;
  final Currency currency;
  final TextStyle? style;
  final TextStyle? rubStyle;
  final bool showRubEquivalent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mainText = '${currency.symbol}${amount.toStringAsFixed(2)}';

    if (currency == Currency.rub || !showRubEquivalent) {
      return Text(mainText, style: style);
    }

    final ratesAsync = ref.watch(exchangeRatesProvider);

    return ratesAsync.when(
      data: (rates) {
        final rubAmount = ExchangeRateService.convertToRub(amount, currency, rates);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mainText, style: style),
            Text(
              '≈ ₽${rubAmount.toStringAsFixed(0)}',
              style: rubStyle ??
                  theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        );
      },
      loading: () => Text(mainText, style: style),
      error: (_, _) => Text(mainText, style: style),
    );
  }
}
