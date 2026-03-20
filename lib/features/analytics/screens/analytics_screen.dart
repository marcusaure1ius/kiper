// lib/features/analytics/screens/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sub_tracker/features/analytics/providers/analytics_provider.dart';
import 'package:sub_tracker/features/analytics/widgets/category_pie_chart.dart';
import 'package:sub_tracker/features/analytics/widgets/monthly_bar_chart.dart';
import 'package:sub_tracker/features/categories/providers/categories_provider.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthlyAsync = ref.watch(monthlyTotalsProvider);
    final categoryAsync = ref.watch(categoryBreakdownProvider);
    final categoriesAsync = ref.watch(watchCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Аналитика'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(monthlyTotalsProvider);
          ref.invalidate(categoryBreakdownProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Monthly bar chart section
            Text(
              'Расходы по месяцам',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Прозрачные столбцы — прогноз',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 220,
                  child: monthlyAsync.when(
                    data: (data) => data.isEmpty
                        ? const Center(child: Text('Нет данных'))
                        : MonthlyBarChart(data: data),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Ошибка: $e')),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Category pie chart section
            Text(
              'Расходы по категориям',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ежемесячные расходы в рублях',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: categoryAsync.when(
                  data: (breakdown) => categoriesAsync.when(
                    data: (categories) => CategoryPieChart(
                      breakdown: breakdown,
                      categories: categories,
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Ошибка категорий: $e')),
                  ),
                  loading: () => const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Center(child: Text('Ошибка: $e')),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Summary card
            monthlyAsync.when(
              data: (data) {
                final pastData = data.where((t) => !t.isForecast).toList();
                final forecastData = data.where((t) => t.isForecast).toList();
                final pastAvg = pastData.isEmpty
                    ? 0.0
                    : pastData.fold(0.0, (s, t) => s + t.amount) / pastData.length;
                final forecastTotal = forecastData.isEmpty
                    ? 0.0
                    : forecastData.first.amount;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Сводка',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SummaryRow(
                          label: 'Средний расход/мес',
                          value: '${pastAvg.toStringAsFixed(0)} ₽',
                        ),
                        const SizedBox(height: 8),
                        _SummaryRow(
                          label: 'Прогноз на следующий месяц',
                          value: '${forecastTotal.toStringAsFixed(0)} ₽',
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _e) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
