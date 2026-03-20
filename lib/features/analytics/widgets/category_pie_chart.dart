// lib/features/analytics/widgets/category_pie_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:sub_tracker/core/database/app_database.dart';

class CategoryPieChart extends StatefulWidget {
  final Map<String?, double> breakdown;
  final List<Category> categories;

  const CategoryPieChart({
    super.key,
    required this.breakdown,
    required this.categories,
  });

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.breakdown.isEmpty) {
      return const Center(child: Text('Нет активных подписок'));
    }

    final colorScheme = Theme.of(context).colorScheme;
    final entries = widget.breakdown.entries.toList();
    final total = entries.fold<double>(0, (sum, e) => sum + e.value);

    final sections = entries.asMap().entries.map((mapEntry) {
      final index = mapEntry.key;
      final entry = mapEntry.value;
      final category = widget.categories.where((c) => c.id == entry.key).firstOrNull;
      final isTouched = index == _touchedIndex;
      final color = _colorForCategory(entry.key, category, index, colorScheme);
      final percentage = total > 0 ? (entry.value / total * 100) : 0.0;

      return PieChartSectionData(
        value: entry.value,
        color: color,
        radius: isTouched ? 72 : 60,
        title: isTouched ? '${percentage.toStringAsFixed(1)}%' : '',
        titleStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        badgeWidget: null,
      );
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response == null ||
                        response.touchedSection == null) {
                      _touchedIndex = null;
                      return;
                    }
                    _touchedIndex = response.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: entries.asMap().entries.map((mapEntry) {
            final index = mapEntry.key;
            final entry = mapEntry.value;
            final category = widget.categories.where((c) => c.id == entry.key).firstOrNull;
            final color = _colorForCategory(entry.key, category, index, colorScheme);
            final label = category?.name ?? 'Без категории';
            final amount = entry.value;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '$label: ${_formatAmount(amount)} ₽/мес',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _colorForCategory(
    String? categoryId,
    Category? category,
    int index,
    ColorScheme colorScheme,
  ) {
    if (category != null) {
      return Color(category.color);
    }
    // fallback colors for uncategorized or missing categories
    final fallbacks = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    return fallbacks[index % fallbacks.length];
  }

  String _formatAmount(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}
