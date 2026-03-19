// lib/features/subscriptions/widgets/subscription_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sub_tracker/core/currency/currency.dart';
import 'package:sub_tracker/core/database/app_database.dart';
import 'package:sub_tracker/shared/widgets/currency_text.dart';

class SubscriptionCard extends StatelessWidget {
  const SubscriptionCard({
    super.key,
    required this.subscription,
    required this.onTap,
  });

  final Subscription subscription;
  final VoidCallback onTap;

  IconData _iconFromName(String? name) {
    if (name == null) return Icons.subscriptions_outlined;
    switch (name) {
      case 'movie':
        return Icons.movie;
      case 'smart_display':
        return Icons.smart_display;
      case 'music_note':
        return Icons.music_note;
      case 'smart_toy':
        return Icons.smart_toy;
      case 'search':
        return Icons.search;
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'phone_android':
        return Icons.phone_android;
      case 'wifi':
        return Icons.wifi;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'category':
        return Icons.category;
      default:
        return Icons.subscriptions_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPaused = subscription.status == 'paused';
    final currency = Currency.values.firstWhere(
      (c) => c.code == subscription.currency,
      orElse: () => Currency.rub,
    );
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Opacity(
      opacity: isPaused ? 0.5 : 1.0,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _iconFromName(subscription.icon),
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subscription.name,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Следующее: ${dateFormat.format(subscription.nextBillingDate)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (isPaused)
                        Text(
                          'Приостановлено',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                CurrencyText(
                  amount: subscription.amount,
                  currency: currency,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  showRubEquivalent: currency != Currency.rub,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
