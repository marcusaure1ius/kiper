import 'package:flutter/material.dart';
import 'package:kiper/shared/utils/format_utils.dart';

class MonthSummaryHeader extends StatelessWidget {
  final double totalMonthly;
  final double paid;
  final double remaining;

  const MonthSummaryHeader({
    super.key,
    required this.totalMonthly,
    required this.paid,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = paid + remaining;
    final fraction = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Сумма подписок',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatAmount(totalMonthly, decimals: 0)} ₽',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              width: double.infinity,
              color: theme.colorScheme.surfaceContainerHighest,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction,
                child: Container(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Оплачено ${formatAmount(paid, decimals: 0)} ₽',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                'Осталось ${formatAmount(remaining, decimals: 0)} ₽',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
    );
  }
}
