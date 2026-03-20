// lib/features/settings/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sub_tracker/core/database/app_database.dart';
import 'package:sub_tracker/core/database/database_provider.dart';
import 'package:sub_tracker/features/categories/providers/categories_provider.dart';
import 'package:sub_tracker/features/categories/widgets/category_list_tile.dart';
import 'package:sub_tracker/features/settings/providers/settings_provider.dart';
import 'package:sub_tracker/features/settings/widgets/export_import_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeNotifierProvider);
    final remindersEnabled = ref.watch(remindersEnabledNotifierProvider);
    final reminderTime = ref.watch(reminderTimeNotifierProvider);
    final categoriesAsync = ref.watch(watchCategoriesProvider);
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ----------------------------------------------------------------
          // Theme
          // ----------------------------------------------------------------
          _SectionHeader(label: 'Внешний вид'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('Авто'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Светлая'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Тёмная'),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (modes) {
                if (modes.isNotEmpty) {
                  ref.read(themeModeNotifierProvider.notifier).setThemeMode(modes.first);
                }
              },
            ),
          ),

          const Divider(height: 24),

          // ----------------------------------------------------------------
          // Reminders
          // ----------------------------------------------------------------
          _SectionHeader(label: 'Напоминания'),
          SwitchListTile(
            title: const Text('Включить напоминания'),
            subtitle: const Text('Уведомления о предстоящих списаниях'),
            value: remindersEnabled,
            onChanged: (value) {
              ref.read(remindersEnabledNotifierProvider.notifier).setEnabled(value);
            },
          ),
          if (remindersEnabled)
            ListTile(
              leading: const Icon(Icons.access_time_outlined),
              title: const Text('Время напоминания'),
              subtitle: Text(reminderTime.toString()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickReminderTime(context, ref, reminderTime),
            ),

          const Divider(height: 24),

          // ----------------------------------------------------------------
          // Categories
          // ----------------------------------------------------------------
          _SectionHeader(label: 'Категории'),
          categoriesAsync.when(
            data: (categories) => Column(
              children: [
                ...categories.map(
                  (cat) => CategoryListTile(
                    category: cat,
                    onEdit: () => _showEditCategoryDialog(context, ref, cat),
                    onDelete: () => _confirmDeleteCategory(context, ref, cat),
                  ),
                ),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.add)),
                  title: const Text('Добавить категорию'),
                  onTap: () => _showAddCategoryDialog(context, ref),
                ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Ошибка: $e'),
            ),
          ),

          const Divider(height: 24),

          // ----------------------------------------------------------------
          // Export / Import
          // ----------------------------------------------------------------
          _SectionHeader(label: 'Данные'),
          ExportImportSection(db: db),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _pickReminderTime(
    BuildContext context,
    WidgetRef ref,
    ReminderTime current,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked != null) {
      await ref
          .read(reminderTimeNotifierProvider.notifier)
          .setTime(picked.hour, picked.minute);
    }
  }

  Future<void> _showAddCategoryDialog(BuildContext context, WidgetRef ref) async {
    await _showCategoryDialog(context, ref, null);
  }

  Future<void> _showEditCategoryDialog(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    await _showCategoryDialog(context, ref, category);
  }

  Future<void> _showCategoryDialog(
    BuildContext context,
    WidgetRef ref,
    Category? existing,
  ) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    var selectedColor = existing != null ? Color(existing.color) : Colors.blue;
    var selectedIcon = existing?.icon ?? 'category';

    final colorOptions = [
      Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
      Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
      Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
      Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
      Colors.brown, Colors.grey, Colors.blueGrey,
    ];

    final iconOptions = [
      ('movie', Icons.movie_outlined, 'Кино'),
      ('smart_toy', Icons.smart_toy_outlined, 'AI'),
      ('phone_android', Icons.phone_android_outlined, 'Связь'),
      ('sports_esports', Icons.sports_esports_outlined, 'Игры'),
      ('music_note', Icons.music_note_outlined, 'Музыка'),
      ('book', Icons.book_outlined, 'Книги'),
      ('cloud', Icons.cloud_outlined, 'Облако'),
      ('security', Icons.security_outlined, 'Безопасность'),
      ('shopping_bag', Icons.shopping_bag_outlined, 'Покупки'),
      ('category', Icons.category_outlined, 'Другое'),
    ];

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'Новая категория' : 'Редактировать категорию'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 16),
                const Text('Цвет'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colorOptions.map((color) {
                    final isSelected = selectedColor.toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTap: () => setState(() => selectedColor = color),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.black, width: 3)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Иконка'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: iconOptions.map((opt) {
                    final (iconKey, icon, label) = opt;
                    final isSelected = selectedIcon == iconKey;
                    return GestureDetector(
                      onTap: () => setState(() => selectedIcon = iconKey),
                      child: Tooltip(
                        message: label,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? selectedColor.withAlpha(50)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(color: selectedColor)
                                : Border.all(color: Colors.transparent),
                          ),
                          child: Icon(icon, color: isSelected ? selectedColor : null),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final notifier = ref.read(categoriesNotifierProvider.notifier);
                if (existing == null) {
                  await notifier.add(
                    name: name,
                    color: selectedColor.toARGB32(),
                    icon: selectedIcon,
                  );
                } else {
                  await notifier.updateCategory(
                    id: existing.id,
                    name: name,
                    color: selectedColor.toARGB32(),
                    icon: selectedIcon,
                  );
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text(existing == null ? 'Добавить' : 'Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCategory(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить категорию?'),
        content: Text('Категория «${category.name}» будет удалена. Подписки в этой категории останутся без категории.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(categoriesNotifierProvider.notifier).remove(category.id);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
