// lib/features/categories/widgets/category_list_tile.dart
import 'package:flutter/material.dart';
import 'package:sub_tracker/core/database/app_database.dart';

class CategoryListTile extends StatelessWidget {
  final Category category;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CategoryListTile({
    super.key,
    required this.category,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Color(category.color),
        child: Icon(
          _iconData(category.icon),
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(category.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Редактировать',
              onPressed: onEdit,
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Удалить',
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }

  IconData _iconData(String iconName) => switch (iconName) {
    'movie' => Icons.movie_outlined,
    'smart_toy' => Icons.smart_toy_outlined,
    'phone_android' => Icons.phone_android_outlined,
    'sports_esports' => Icons.sports_esports_outlined,
    'category' => Icons.category_outlined,
    'music_note' => Icons.music_note_outlined,
    'book' => Icons.book_outlined,
    'cloud' => Icons.cloud_outlined,
    'security' => Icons.security_outlined,
    'shopping_bag' => Icons.shopping_bag_outlined,
    _ => Icons.label_outlined,
  };
}
