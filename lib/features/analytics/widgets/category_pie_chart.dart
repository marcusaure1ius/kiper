// lib/features/analytics/widgets/category_pie_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiper/core/database/app_database.dart';
import 'package:kiper/features/analytics/providers/analytics_provider.dart';
import 'package:kiper/features/categories/providers/categories_provider.dart';
import 'package:kiper/shared/utils/format_utils.dart';

class CategoryBreakdownCard extends ConsumerStatefulWidget {
  const CategoryBreakdownCard({super.key});

  @override
  ConsumerState<CategoryBreakdownCard> createState() =>
      _CategoryBreakdownCardState();
}

class _CategoryBreakdownCardState extends ConsumerState<CategoryBreakdownCard> {
  bool _showList = false;
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final breakdownAsync = ref.watch(categoryBreakdownProvider);
    final categoriesAsync = ref.watch(watchCategoriesProvider);

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: breakdownAsync.when(
          data: (breakdown) => categoriesAsync.when(
            data: (categories) =>
                _buildContent(context, breakdown, categories),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Ошибка: $e')),
          ),
          loading: () => const SizedBox(
            height: 280,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Center(child: Text('Ошибка: $e')),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Map<String?, double> breakdown,
    List<Category> categories,
  ) {
    if (breakdown.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: Text('Нет активных подписок')),
      );
    }

    final entries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    final colorScheme = Theme.of(context).colorScheme;

    final items = entries.asMap().entries.map((e) {
      final cat =
          categories.where((c) => c.id == e.value.key).firstOrNull;
      return _CatItem(
        name: cat?.name ?? 'Без категории',
        amount: e.value.value,
        pct: total > 0 ? e.value.value / total * 100 : 0,
        color: _color(e.value.key, cat, e.key, colorScheme),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Расходы по категориям',
                    style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${items.length} ${_plural(items.length)}',
                    style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.pie_chart_rounded, size: 18),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.format_list_bulleted_rounded, size: 18),
                ),
              ],
              selected: {_showList},
              onSelectionChanged: (v) => setState(() {
                _showList = v.first;
                _touchedIndex = null;
              }),
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Body
        if (_showList)
          _ListBody(items: items)
        else
          _ChartBody(
            items: items,
            total: total,
            touchedIndex: _touchedIndex,
            onTouch: (i) => setState(() => _touchedIndex = i),
          ),
      ],
    );
  }

  String _plural(int n) {
    final m = n % 100;
    if (m >= 11 && m <= 19) return 'категорий';
    switch (n % 10) {
      case 1:
        return 'категория';
      case 2:
      case 3:
      case 4:
        return 'категории';
      default:
        return 'категорий';
    }
  }

  Color _color(
      String? id, Category? cat, int idx, ColorScheme cs) {
    if (cat != null) return Color(cat.color);
    const fallbacks = [
      Color(0xFF5B93C7),
      Color(0xFFC7B55B),
      Color(0xFFC78B5B),
      Color(0xFF5BC777),
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    return fallbacks[idx % fallbacks.length];
  }
}

// --- Donut chart view ---

class _ChartBody extends StatelessWidget {
  final List<_CatItem> items;
  final double total;
  final int? touchedIndex;
  final ValueChanged<int?> onTouch;

  const _ChartBody({
    required this.items,
    required this.total,
    required this.touchedIndex,
    required this.onTouch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 210,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: items.asMap().entries.map((e) {
                    final i = e.key;
                    final item = e.value;
                    final touched = i == touchedIndex;
                    final show = item.pct >= 8;
                    return PieChartSectionData(
                      value: item.amount,
                      color: item.color,
                      radius: touched ? 65 : 55,
                      title: show ? '${item.pct.round()}%' : '',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      titlePositionPercentageOffset: 0.55,
                    );
                  }).toList(),
                  centerSpaceRadius: 50,
                  sectionsSpace: 2,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, resp) {
                      if (!event.isInterestedForInteractions ||
                          resp == null ||
                          resp.touchedSection == null) {
                        onTouch(null);
                        return;
                      }
                      onTouch(
                          resp.touchedSection!.touchedSectionIndex);
                    },
                  ),
                ),
              ),
              // Center label
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${items.length}',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Расходы',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 8),
        // Legend
        ...items.asMap().entries.map((e) => _LegendRow(
              item: e.value,
              highlighted: e.key == touchedIndex,
            )),
      ],
    );
  }
}

// --- List view ---

class _ListBody extends StatelessWidget {
  final List<_CatItem> items;

  const _ListBody({required this.items});

  @override
  Widget build(BuildContext context) {
    final maxAmt = items.isEmpty ? 1.0 : items.first.amount;
    return Column(
      children: items
          .map((item) => _ListRow(item: item, fraction: item.amount / maxAmt))
          .toList(),
    );
  }
}

// --- Sub-widgets ---

class _CatItem {
  final String name;
  final double amount;
  final double pct;
  final Color color;
  const _CatItem({
    required this.name,
    required this.amount,
    required this.pct,
    required this.color,
  });
}

class _LegendRow extends StatelessWidget {
  final _CatItem item;
  final bool highlighted;

  const _LegendRow({
    required this.item,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: highlighted
            ? item.color.withValues(alpha: 0.10)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.name,
              style: ts.bodyMedium?.copyWith(
                fontWeight:
                    highlighted ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            '${formatAmount(item.amount, decimals: 0)} ₽',
            style: ts.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Text(
            '— ${item.pct.round()}%',
            style: ts.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  final _CatItem item;
  final double fraction;

  const _ListRow({required this.item, required this.fraction});

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item.name, style: ts.bodyMedium),
              ),
              Text(
                '${item.pct.round()}%',
                style: ts.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(item.color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatAmount(item.amount, decimals: 0)} ₽',
            style: ts.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
