// lib/features/settings/widgets/export_import_section.dart
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kiper/core/database/app_database.dart';

// ---------------------------------------------------------------------------
// BackupData
// ---------------------------------------------------------------------------

class BackupData {
  static const int currentVersion = 1;

  final int version;
  final DateTime exportedAt;
  final List<Map<String, dynamic>> subscriptions;
  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic> settings;

  const BackupData({
    required this.version,
    required this.exportedAt,
    required this.subscriptions,
    required this.categories,
    required this.settings,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'exportedAt': exportedAt.toIso8601String(),
    'subscriptions': subscriptions,
    'categories': categories,
    'settings': settings,
  };

  factory BackupData.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 0;
    if (version > currentVersion) {
      throw FormatException(
        'Unsupported backup version: $version. Maximum supported: $currentVersion',
      );
    }
    return BackupData(
      version: version,
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      subscriptions: List<Map<String, dynamic>>.from(
        (json['subscriptions'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
      ),
      categories: List<Map<String, dynamic>>.from(
        (json['categories'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
      ),
      settings: Map<String, dynamic>.from(json['settings'] as Map? ?? {}),
    );
  }
}

// ---------------------------------------------------------------------------
// CsvExporter
// ---------------------------------------------------------------------------

class CsvExporter {
  static const _separator = ',';
  static const _headers = [
    'id', 'name', 'amount', 'currency', 'billingPeriod',
    'customPeriodDays', 'categoryId', 'nextBillingDate',
    'startDate', 'status', 'reminderDaysBefore', 'note',
  ];

  static String generate(List<Map<String, dynamic>> subscriptions) {
    final buffer = StringBuffer();
    buffer.writeln(_headers.join(_separator));
    for (final sub in subscriptions) {
      final row = _headers.map((key) {
        final value = sub[key];
        if (value == null) return '';
        final str = value.toString();
        // Escape commas and quotes
        if (str.contains(_separator) || str.contains('"') || str.contains('\n')) {
          return '"${str.replaceAll('"', '""')}"';
        }
        return str;
      }).join(_separator);
      buffer.writeln(row);
    }
    return buffer.toString();
  }
}

// ---------------------------------------------------------------------------
// ExportImportHelper
// ---------------------------------------------------------------------------

class ExportImportHelper {
  /// Reads all subscriptions and categories from [db] as list of maps.
  static Future<BackupData> _buildBackupData(AppDatabase db) async {
    final subs = await db.select(db.subscriptions).get();
    final cats = await db.select(db.categories).get();

    final subsJson = subs.map((s) => {
      'id': s.id,
      'name': s.name,
      'icon': s.icon,
      'amount': s.amount,
      'currency': s.currency,
      'billingPeriod': s.billingPeriod,
      'customPeriodDays': s.customPeriodDays,
      'categoryId': s.categoryId,
      'nextBillingDate': s.nextBillingDate.toIso8601String(),
      'startDate': s.startDate.toIso8601String(),
      'status': s.status,
      'reminderDaysBefore': s.reminderDaysBefore,
      'note': s.note,
      'createdAt': s.createdAt.toIso8601String(),
    }).toList();

    final catsJson = cats.map((c) => {
      'id': c.id,
      'name': c.name,
      'color': c.color,
      'icon': c.icon,
    }).toList();

    return BackupData(
      version: BackupData.currentVersion,
      exportedAt: DateTime.now(),
      subscriptions: subsJson,
      categories: catsJson,
      settings: {},
    );
  }

  /// Export all data as JSON and share via system share sheet.
  static Future<void> exportJson(AppDatabase db) async {
    final backup = await _buildBackupData(db);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(backup.toJson());

    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/kiper_backup.json');
    await file.writeAsString(jsonStr);

    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      subject: 'Кипер — Резервная копия',
    ));
  }

  /// Export subscriptions as CSV and share via system share sheet.
  static Future<void> exportCsv(AppDatabase db) async {
    final backup = await _buildBackupData(db);
    final csv = CsvExporter.generate(backup.subscriptions);

    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/kiper_subscriptions.csv');
    await file.writeAsString(csv);

    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Кипер — Подписки',
    ));
  }

  /// Import JSON, replacing ALL existing data.
  static Future<void> importJsonReplace(AppDatabase db, String json) async {
    final backup = BackupData.fromJson(jsonDecode(json) as Map<String, dynamic>);

    await db.transaction(() async {
      // Delete existing data (order matters due to FK constraints)
      await db.delete(db.subscriptions).go();
      await db.delete(db.categories).go();

      // Insert categories first
      for (final cat in backup.categories) {
        await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            id: cat['id'] as String,
            name: cat['name'] as String,
            color: cat['color'] as int,
            icon: cat['icon'] as String,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }

      // Insert subscriptions
      for (final sub in backup.subscriptions) {
        await _insertSubFromMap(db, sub);
      }
    });
  }

  /// Import JSON, merging with existing data (upsert by UUID).
  static Future<void> importJsonMerge(AppDatabase db, String json) async {
    final backup = BackupData.fromJson(jsonDecode(json) as Map<String, dynamic>);

    await db.transaction(() async {
      // Upsert categories
      for (final cat in backup.categories) {
        await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            id: cat['id'] as String,
            name: cat['name'] as String,
            color: cat['color'] as int,
            icon: cat['icon'] as String,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }

      // Upsert subscriptions
      for (final sub in backup.subscriptions) {
        await _insertSubFromMap(db, sub, mode: InsertMode.insertOrReplace);
      }
    });
  }

  static Future<void> _insertSubFromMap(
    AppDatabase db,
    Map<String, dynamic> sub, {
    InsertMode mode = InsertMode.insertOrIgnore,
  }) async {
    await db.into(db.subscriptions).insert(
      SubscriptionsCompanion.insert(
        id: sub['id'] as String,
        name: sub['name'] as String,
        amount: (sub['amount'] as num).toDouble(),
        currency: sub['currency'] as String,
        billingPeriod: sub['billingPeriod'] as String,
        nextBillingDate: DateTime.parse(sub['nextBillingDate'] as String),
        startDate: DateTime.parse(sub['startDate'] as String),
        createdAt: DateTime.parse(
          sub['createdAt'] as String? ?? DateTime.now().toIso8601String(),
        ),
        icon: Value(sub['icon'] as String?),
        customPeriodDays: Value(sub['customPeriodDays'] as int?),
        categoryId: Value(sub['categoryId'] as String?),
        reminderDaysBefore: Value(sub['reminderDaysBefore'] as int? ?? 1),
        note: Value(sub['note'] as String?),
      ),
      mode: mode,
    );
  }

  /// Import subscriptions from CSV (basic, no category import).
  static Future<void> importCsv(AppDatabase db, String csv) async {
    final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return;

    // Parse header row
    final headers = _parseCsvRow(lines.first);
    final subsData = lines.skip(1).map((line) {
      final values = _parseCsvRow(line);
      final map = <String, dynamic>{};
      for (var i = 0; i < headers.length && i < values.length; i++) {
        final val = values[i];
        map[headers[i]] = val.isEmpty ? null : val;
      }
      return map;
    }).toList();

    await db.transaction(() async {
      for (final sub in subsData) {
        if (sub['id'] == null || sub['name'] == null) continue;
        try {
          await db.into(db.subscriptions).insert(
            SubscriptionsCompanion.insert(
              id: sub['id'] as String,
              name: sub['name'] as String,
              amount: double.tryParse(sub['amount']?.toString() ?? '0') ?? 0,
              currency: sub['currency'] as String? ?? 'RUB',
              billingPeriod: sub['billingPeriod'] as String? ?? 'monthly',
              nextBillingDate: sub['nextBillingDate'] != null
                  ? DateTime.parse(sub['nextBillingDate'] as String)
                  : DateTime.now().add(const Duration(days: 30)),
              startDate: sub['startDate'] != null
                  ? DateTime.parse(sub['startDate'] as String)
                  : DateTime.now(),
              createdAt: DateTime.now(),
              icon: const Value(null),
              customPeriodDays: Value(
                sub['customPeriodDays'] != null
                    ? int.tryParse(sub['customPeriodDays'].toString())
                    : null,
              ),
              categoryId: Value(sub['categoryId'] as String?),
              reminderDaysBefore: Value(
                int.tryParse(sub['reminderDaysBefore']?.toString() ?? '1') ?? 1,
              ),
              note: Value(sub['note'] as String?),
            ),
            mode: InsertMode.insertOrReplace,
          );
        } catch (_) {
          // Skip rows with invalid data
        }
      }
    });
  }

  static List<String> _parseCsvRow(String row) {
    final fields = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < row.length; i++) {
      final char = row[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < row.length && row[i + 1] == '"') {
            current.write('"');
            i++; // skip escaped quote
          } else {
            inQuotes = false;
          }
        } else {
          current.write(char);
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == ',') {
          fields.add(current.toString());
          current.clear();
        } else {
          current.write(char);
        }
      }
    }
    fields.add(current.toString());
    return fields;
  }

  /// Show file picker, detect file type, and import accordingly.
  static Future<void> importFile(BuildContext context, AppDatabase db) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'csv'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final path = file.path;
    if (path == null) return;

    final content = await File(path).readAsString();
    final isJson = path.toLowerCase().endsWith('.json');

    if (!context.mounted) return;

    if (isJson) {
      // Ask user: replace or merge?
      final choice = await showDialog<_ImportChoice>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Импорт данных'),
          content: const Text(
            'Как импортировать данные?\n\n'
            '• Заменить — удалит все текущие данные\n'
            '• Объединить — добавит и обновит записи по ID',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(_ImportChoice.merge),
              child: const Text('Объединить'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(_ImportChoice.replace),
              child: const Text('Заменить'),
            ),
          ],
        ),
      );

      if (choice == null) return;

      try {
        if (choice == _ImportChoice.replace) {
          await importJsonReplace(db, content);
        } else {
          await importJsonMerge(db, content);
        }
        if (context.mounted) {
          _showSuccess(context, 'Данные успешно импортированы');
        }
      } on FormatException catch (e) {
        if (context.mounted) {
          _showError(context, 'Ошибка формата: ${e.message}');
        }
      } catch (e) {
        if (context.mounted) {
          _showError(context, 'Ошибка импорта: $e');
        }
      }
    } else {
      // CSV
      try {
        await importCsv(db, content);
        if (context.mounted) {
          _showSuccess(context, 'CSV импортирован');
        }
      } catch (e) {
        if (context.mounted) {
          _showError(context, 'Ошибка импорта CSV: $e');
        }
      }
    }
  }

  static void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

enum _ImportChoice { replace, merge }

// ---------------------------------------------------------------------------
// ExportImportSection widget
// ---------------------------------------------------------------------------

class ExportImportSection extends StatelessWidget {
  final AppDatabase db;

  const ExportImportSection({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.upload_outlined),
          title: const Text('Экспорт JSON'),
          subtitle: const Text('Полная резервная копия'),
          onTap: () async {
            try {
              await ExportImportHelper.exportJson(db);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка экспорта: $e')),
                );
              }
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.table_chart_outlined),
          title: const Text('Экспорт CSV'),
          subtitle: const Text('Только подписки'),
          onTap: () async {
            try {
              await ExportImportHelper.exportCsv(db);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка экспорта: $e')),
                );
              }
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('Импорт'),
          subtitle: const Text('JSON или CSV файл'),
          onTap: () => ExportImportHelper.importFile(context, db),
        ),
      ],
    );
  }
}
