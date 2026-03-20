// test/features/settings/export_import_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sub_tracker/features/settings/widgets/export_import_section.dart';

void main() {
  group('BackupData', () {
    final sampleSubscriptions = [
      {
        'id': 'uuid-1',
        'name': 'Netflix',
        'icon': null,
        'amount': 22.99,
        'currency': 'USD',
        'billingPeriod': 'monthly',
        'customPeriodDays': null,
        'categoryId': 'cat-streaming',
        'nextBillingDate': '2026-04-01T00:00:00.000',
        'startDate': '2026-01-01T00:00:00.000',
        'status': 'active',
        'reminderDaysBefore': 1,
        'note': null,
        'createdAt': '2026-01-01T00:00:00.000',
      }
    ];

    final sampleCategories = [
      {'id': 'cat-streaming', 'name': 'Стриминг', 'color': 0xFF7C4DFF, 'icon': 'movie'},
    ];

    test('round-trip serialization preserves all fields', () {
      final original = BackupData(
        version: 1,
        exportedAt: DateTime(2026, 3, 20, 12, 0),
        subscriptions: sampleSubscriptions,
        categories: sampleCategories,
        settings: {'theme': 'dark'},
      );

      final json = original.toJson();
      final jsonStr = jsonEncode(json);
      final decoded = BackupData.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

      expect(decoded.version, original.version);
      expect(decoded.exportedAt, original.exportedAt);
      expect(decoded.subscriptions.length, 1);
      expect(decoded.subscriptions.first['name'], 'Netflix');
      expect(decoded.categories.length, 1);
      expect(decoded.categories.first['id'], 'cat-streaming');
      expect(decoded.settings['theme'], 'dark');
    });

    test('fromJson throws FormatException for version > 1', () {
      final json = {
        'version': 99,
        'exportedAt': '2026-03-20T12:00:00.000',
        'subscriptions': [],
        'categories': [],
        'settings': {},
      };

      expect(
        () => BackupData.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson accepts version 1', () {
      final json = {
        'version': 1,
        'exportedAt': '2026-03-20T12:00:00.000',
        'subscriptions': [],
        'categories': [],
        'settings': {},
      };

      final backup = BackupData.fromJson(json);
      expect(backup.version, 1);
    });

    test('fromJson handles missing optional fields gracefully', () {
      final json = {
        'version': 1,
        'exportedAt': '2026-03-20T12:00:00.000',
        // subscriptions, categories, settings missing
      };

      final backup = BackupData.fromJson(json);
      expect(backup.subscriptions, isEmpty);
      expect(backup.categories, isEmpty);
      expect(backup.settings, isEmpty);
    });

    test('toJson includes version field', () {
      final backup = BackupData(
        version: 1,
        exportedAt: DateTime(2026, 1, 1),
        subscriptions: [],
        categories: [],
        settings: {},
      );
      final json = backup.toJson();
      expect(json['version'], 1);
      expect(json.containsKey('exportedAt'), isTrue);
    });
  });

  group('CsvExporter', () {
    test('generates header row', () {
      final csv = CsvExporter.generate([]);
      final lines = csv.trim().split('\n');
      expect(lines.first, contains('id'));
      expect(lines.first, contains('name'));
      expect(lines.first, contains('amount'));
      expect(lines.first, contains('currency'));
    });

    test('generates data rows for subscriptions', () {
      final subs = [
        {
          'id': 'sub-1',
          'name': 'Netflix',
          'amount': 22.99,
          'currency': 'USD',
          'billingPeriod': 'monthly',
          'customPeriodDays': null,
          'categoryId': 'cat-1',
          'nextBillingDate': '2026-04-01T00:00:00.000',
          'startDate': '2026-01-01T00:00:00.000',
          'status': 'active',
          'reminderDaysBefore': 1,
          'note': null,
        }
      ];

      final csv = CsvExporter.generate(subs);
      final lines = csv.trim().split('\n');
      expect(lines.length, 2); // header + 1 row
      expect(lines[1], contains('Netflix'));
      expect(lines[1], contains('22.99'));
      expect(lines[1], contains('USD'));
    });

    test('escapes commas and quotes in values', () {
      final subs = [
        {
          'id': 'sub-1',
          'name': 'Service, Inc.',
          'amount': 10.0,
          'currency': 'RUB',
          'billingPeriod': 'monthly',
          'customPeriodDays': null,
          'categoryId': null,
          'nextBillingDate': '2026-04-01T00:00:00.000',
          'startDate': '2026-01-01T00:00:00.000',
          'status': 'active',
          'reminderDaysBefore': 1,
          'note': 'Has "quotes"',
        }
      ];

      final csv = CsvExporter.generate(subs);
      // Name contains comma → should be quoted
      expect(csv, contains('"Service, Inc."'));
      // Note contains quotes → should be double-quoted
      expect(csv, contains('"Has ""quotes"""'));
    });

    test('generates empty CSV for empty subscription list', () {
      final csv = CsvExporter.generate([]);
      final lines = csv.trim().split('\n');
      // Only header line
      expect(lines.length, 1);
    });

    test('generates multiple rows', () {
      final subs = List.generate(
        5,
        (i) => {
          'id': 'sub-$i',
          'name': 'Service $i',
          'amount': (i + 1) * 10.0,
          'currency': 'RUB',
          'billingPeriod': 'monthly',
          'customPeriodDays': null,
          'categoryId': null,
          'nextBillingDate': '2026-04-01T00:00:00.000',
          'startDate': '2026-01-01T00:00:00.000',
          'status': 'active',
          'reminderDaysBefore': 1,
          'note': null,
        },
      );

      final csv = CsvExporter.generate(subs);
      final lines = csv.trim().split('\n');
      expect(lines.length, 6); // header + 5 rows
    });
  });
}
