import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kiper/features/home/providers/home_providers.dart';
import 'package:kiper/features/home/widgets/month_summary_header.dart';
import 'package:kiper/features/home/widgets/payments_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthlyTotalAsync = ref.watch(monthlyTotalRubProvider);
    final monthProgressAsync = ref.watch(monthProgressProvider);
    final pastPaymentsAsync = ref.watch(pastPaymentsProvider);
    final futurePaymentsAsync = ref.watch(futurePaymentsProvider);

    final totalMonthly = monthlyTotalAsync.value ?? 0.0;
    final progress = monthProgressAsync.value ?? (paid: 0.0, remaining: 0.0);
    final pastPayments = pastPaymentsAsync.value ?? [];
    final futurePayments = futurePaymentsAsync.value ?? [];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 36, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MonthSummaryHeader(
                    totalMonthly: totalMonthly,
                    paid: progress.paid,
                    remaining: progress.remaining,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => context.push('/subscriptions/list'),
                          icon: const Icon(Icons.list_rounded, size: 18),
                          label: const Text('Все подписки'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1C1C1E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => context.push('/subscriptions/add'),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Добавить'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1C1C1E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          PaymentsSheet(
            pastPayments: pastPayments,
            futurePayments: futurePayments,
          ),
        ],
      ),
    );
  }
}
