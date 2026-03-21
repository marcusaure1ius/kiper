// lib/features/analytics/screens/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiper/features/analytics/providers/analytics_provider.dart';
import 'package:kiper/features/analytics/widgets/category_pie_chart.dart';
import 'package:kiper/features/analytics/widgets/monthly_bar_chart.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Аналитика'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(monthlyTotalsProvider);
          ref.invalidate(weeklyTotalsProvider);
          ref.invalidate(categoryBreakdownProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _ChartCard(),
            const SizedBox(height: 24),
            const CategoryBreakdownCard(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends ConsumerStatefulWidget {
  const _ChartCard();

  @override
  ConsumerState<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends ConsumerState<_ChartCard> {
  ChartPeriod _period = ChartPeriod.monthly;

  @override
  Widget build(BuildContext context) {
    final dataAsync = _period == ChartPeriod.monthly
        ? ref.watch(monthlyTotalsProvider)
        : ref.watch(weeklyTotalsProvider);

    final hsl = HSLColor.fromColor(Theme.of(context).colorScheme.primary);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgDark = hsl
        .withLightness(isDark ? 0.15 : 0.22)
        .withSaturation(isDark ? 0.25 : 0.28)
        .toColor();
    final bgLight = hsl
        .withLightness(isDark ? 0.20 : 0.28)
        .withSaturation(isDark ? 0.20 : 0.22)
        .toColor();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bgDark, bgLight],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              _period == ChartPeriod.monthly
                  ? 'Расходы по месяцам'
                  : 'Расходы по неделям',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 220,
            child: dataAsync.when(
              data: (data) => MonthlyExpenseChart(
                data: data,
                period: _period,
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white54),
              ),
              error: (e, _) => Center(
                child: Text('Ошибка: $e',
                    style: const TextStyle(color: Colors.white70)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Period toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _PeriodChip(
                  label: 'Месяц',
                  isActive: _period == ChartPeriod.monthly,
                  onTap: () => setState(() => _period = ChartPeriod.monthly),
                ),
                const SizedBox(width: 8),
                _PeriodChip(
                  label: 'Неделя',
                  isActive: _period == ChartPeriod.weekly,
                  onTap: () => setState(() => _period = ChartPeriod.weekly),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withValues(alpha: 0.15) : null,
          border: Border.all(
            color: isActive ? Colors.white38 : Colors.white12,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white38,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

