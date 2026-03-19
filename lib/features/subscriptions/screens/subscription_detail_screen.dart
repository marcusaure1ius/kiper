// lib/features/subscriptions/screens/subscription_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sub_tracker/core/currency/currency.dart';
import 'package:sub_tracker/core/database/app_database.dart';
import 'package:sub_tracker/core/database/database_provider.dart';
import 'package:sub_tracker/features/subscriptions/providers/subscriptions_provider.dart';
import 'package:sub_tracker/shared/widgets/currency_text.dart';

final _subscriptionByIdProvider = StreamProvider.family<Subscription?, String>((ref, id) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.subscriptions)..where((t) => t.id.equals(id))).watchSingleOrNull();
});

class SubscriptionDetailScreen extends ConsumerWidget {
  const SubscriptionDetailScreen({super.key, required this.subscriptionId});

  final String subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(_subscriptionByIdProvider(subscriptionId));

    return subAsync.when(
      data: (sub) {
        if (sub == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Подписка')),
            body: const Center(child: Text('Подписка не найдена')),
          );
        }
        return _SubscriptionDetailView(subscription: sub);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Подписка')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Подписка')),
        body: Center(child: Text('Ошибка: $error')),
      ),
    );
  }
}

class _SubscriptionDetailView extends ConsumerWidget {
  const _SubscriptionDetailView({required this.subscription});

  final Subscription subscription;

  static final _dateFormat = DateFormat('dd.MM.yyyy');

  String _periodLabel(String period) {
    switch (period) {
      case 'weekly':
        return 'Еженедельно';
      case 'monthly':
        return 'Ежемесячно';
      case 'quarterly':
        return 'Ежеквартально';
      case 'semiannual':
        return 'Раз в полгода';
      case 'annual':
        return 'Ежегодно';
      case 'custom':
        return 'Другой период';
      default:
        return period;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Активна';
      case 'paused':
        return 'Приостановлена';
      case 'cancelled':
        return 'Отменена';
      default:
        return status;
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить подписку?'),
        content: Text('Подписка "${subscription.name}" будет удалена. Это действие необратимо.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(subscriptionsNotifierProvider.notifier)
          .updateStatus(subscription.id, 'cancelled');
      if (context.mounted) context.pop();
    }
  }

  Future<void> _togglePause(BuildContext context, WidgetRef ref) async {
    final newStatus = subscription.status == 'paused' ? 'active' : 'paused';
    await ref
        .read(subscriptionsNotifierProvider.notifier)
        .updateStatus(subscription.id, newStatus);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currency = Currency.values.firstWhere(
      (c) => c.code == subscription.currency,
      orElse: () => Currency.rub,
    );
    final isPaused = subscription.status == 'paused';

    return Scaffold(
      appBar: AppBar(
        title: Text(subscription.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'toggle_pause') {
                await _togglePause(context, ref);
              } else if (value == 'delete') {
                await _confirmDelete(context, ref);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle_pause',
                child: Row(
                  children: [
                    Icon(isPaused ? Icons.play_arrow : Icons.pause),
                    const SizedBox(width: 8),
                    Text(isPaused ? 'Возобновить' : 'Приостановить'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Text('Удалить', style: TextStyle(color: theme.colorScheme.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Amount card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Сумма',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CurrencyText(
                    amount: subscription.amount,
                    currency: currency,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Details card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _DetailRow(
                    label: 'Период',
                    value: _periodLabel(subscription.billingPeriod),
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    label: 'Следующее списание',
                    value: _dateFormat.format(subscription.nextBillingDate),
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    label: 'Дата начала',
                    value: _dateFormat.format(subscription.startDate),
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    label: 'Статус',
                    value: _statusLabel(subscription.status),
                    valueColor: subscription.status == 'active'
                        ? Colors.green
                        : subscription.status == 'paused'
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.error,
                  ),
                  if (subscription.note != null && subscription.note!.isNotEmpty) ...[
                    const Divider(height: 24),
                    _DetailRow(label: 'Заметка', value: subscription.note!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
