// lib/features/subscriptions/catalog/catalog_picker.dart
import 'package:flutter/material.dart';
import 'package:kiper/features/subscriptions/catalog/catalog_data.dart';

class CatalogPicker extends StatelessWidget {
  const CatalogPicker({super.key, required this.onSelect});

  final ValueChanged<CatalogEntry> onSelect;

  static const _categoryIcons = <String, IconData>{
    'cat-streaming': Icons.movie_outlined,
    'cat-ai': Icons.smart_toy_outlined,
    'cat-telecom': Icons.phone_android_outlined,
    'cat-entertainment': Icons.sports_esports_outlined,
  };

  static const _categoryColors = <String, Color>{
    'cat-streaming': Color(0xFF7C4DFF),
    'cat-ai': Color(0xFF2196F3),
    'cat-telecom': Color(0xFFFF6B35),
    'cat-entertainment': Color(0xFFE50914),
  };

  IconData _iconFromName(String name) {
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
      default:
        return Icons.subscriptions_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group entries by categoryId, preserving order.
    final groupOrder = <String>[];
    final groups = <String, List<CatalogEntry>>{};
    for (final entry in catalogData) {
      if (!groups.containsKey(entry.categoryId)) {
        groupOrder.add(entry.categoryId);
      }
      groups.putIfAbsent(entry.categoryId, () => []).add(entry);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        // Build widget list: headers + entry tiles.
        final items = <Widget>[];
        for (final categoryId in groupOrder) {
          items.add(_buildCategoryHeader(context, categoryId));
          for (final entry in groups[categoryId]!) {
            items.add(_buildEntryTile(context, entry));
          }
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Выбрать из каталога',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: items,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryHeader(BuildContext context, String categoryId) {
    final name = catalogCategoryNames[categoryId] ?? categoryId;
    final icon = _categoryIcons[categoryId] ?? Icons.category_outlined;
    final color = _categoryColors[categoryId] ?? Colors.grey;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryTile(BuildContext context, CatalogEntry entry) {
    return ListTile(
      leading: SizedBox(
        width: 40,
        height: 40,
        child: entry.logoUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  entry.logoUrl!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => CircleAvatar(
                    child: Icon(_iconFromName(entry.icon)),
                  ),
                ),
              )
            : CircleAvatar(
                child: Icon(_iconFromName(entry.icon)),
              ),
      ),
      title: Text(entry.name),
      subtitle: Text(
        '${entry.defaultCurrency.code} · ${_periodLabel(entry.defaultPeriod.name)}',
      ),
      onTap: () {
        Navigator.of(context).pop();
        onSelect(entry);
      },
    );
  }

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
}
