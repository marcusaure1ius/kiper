// lib/features/subscriptions/catalog/catalog_picker.dart
import 'package:flutter/material.dart';
import 'package:sub_tracker/features/subscriptions/catalog/catalog_data.dart';

class CatalogPicker extends StatelessWidget {
  const CatalogPicker({super.key, required this.onSelect});

  final ValueChanged<CatalogEntry> onSelect;

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
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
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
              child: ListView.builder(
                controller: scrollController,
                itemCount: catalogData.length,
                itemBuilder: (context, index) {
                  final entry = catalogData[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Icon(_iconFromName(entry.icon)),
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
                },
              ),
            ),
          ],
        );
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
