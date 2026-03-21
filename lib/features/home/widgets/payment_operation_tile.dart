import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiper/core/currency/currency.dart';
import 'package:kiper/core/database/app_database.dart';
import 'package:kiper/features/categories/providers/categories_provider.dart';
import 'package:kiper/features/home/models/payment_event.dart';
import 'package:kiper/shared/utils/format_utils.dart';

IconData _iconFromName(String? name) {
  const map = {
    'movie': Icons.movie,
    'smart_display': Icons.smart_display,
    'music_note': Icons.music_note,
    'smart_toy': Icons.smart_toy,
    'search': Icons.search,
    'auto_awesome': Icons.auto_awesome,
    'phone_android': Icons.phone_android,
    'wifi': Icons.wifi,
    'sports_esports': Icons.sports_esports,
    'category': Icons.category,
  };
  return map[name] ?? Icons.subscriptions_outlined;
}

class PaymentOperationTile extends ConsumerWidget {
  final PaymentEvent event;
  const PaymentOperationTile({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(watchCategoriesProvider);

    final categories = switch (categoriesAsync) {
      AsyncData(:final value) => value,
      _ => const <Category>[],
    };
    final category = categories.where((c) => c.id == event.categoryId).firstOrNull;

    final categoryColor = category != null ? Color(category.color) : Colors.grey;
    final categoryName = category?.name ?? 'Без категории';

    final currency = Currency.values.firstWhere(
      (c) => c.code == event.currency,
      orElse: () => Currency.rub,
    );

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: categoryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconFromName(event.icon),
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    categoryName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '- ${formatAmount(event.amount, decimals: 0)} ${currency.symbol}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
