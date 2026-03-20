// lib/features/analytics/widgets/monthly_bar_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sub_tracker/features/analytics/providers/analytics_provider.dart';

class MonthlyBarChart extends StatelessWidget {
  final List<MonthlyTotal> data;

  const MonthlyBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('Нет данных'));
    }

    final colorScheme = Theme.of(context).colorScheme;
    final maxY = data.map((e) => e.amount).fold(0.0, (a, b) => a > b ? a : b);
    final effectiveMaxY = maxY == 0 ? 100.0 : maxY * 1.2;

    final barGroups = data.asMap().entries.map((entry) {
      final index = entry.key;
      final total = entry.value;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: total.amount,
            color: total.isForecast
                ? colorScheme.primary.withAlpha(100)
                : colorScheme.primary,
            width: 18,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    final monthFormat = DateFormat('MMM', 'ru');

    return BarChart(
      BarChartData(
        maxY: effectiveMaxY,
        barGroups: barGroups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withAlpha(80),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                final formatted = _formatAmount(value);
                return Text(
                  formatted,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                final month = data[idx].month;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    monthFormat.format(month),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final total = data[group.x];
              final label = total.isForecast ? ' (прогноз)' : '';
              return BarTooltipItem(
                '${_formatAmount(rod.toY)} ₽$label',
                Theme.of(context).textTheme.labelSmall!.copyWith(
                  color: colorScheme.onSurface,
                ),
              );
            },
            getTooltipColor: (group) => colorScheme.surface,
          ),
        ),
      ),
    );
  }

  String _formatAmount(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }
}
