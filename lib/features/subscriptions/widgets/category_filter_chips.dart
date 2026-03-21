// lib/features/subscriptions/widgets/category_filter_chips.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiper/core/database/app_database.dart';
import 'package:kiper/features/categories/providers/categories_provider.dart';

class CategoryFilterChips extends ConsumerWidget {
  const CategoryFilterChips({
    super.key,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(watchCategoriesProvider);

    return categoriesAsync.when(
      data: (categories) => _buildChips(context, categories),
      loading: () => const SizedBox(height: 48),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildChips(BuildContext context, List<Category> categories) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Все'),
              selected: selectedCategoryId == null,
              onSelected: (_) => onCategorySelected(null),
            ),
          ),
          ...categories.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(cat.name),
                  selected: selectedCategoryId == cat.id,
                  onSelected: (_) => onCategorySelected(
                    selectedCategoryId == cat.id ? null : cat.id,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
