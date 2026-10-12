// test/features/settings/import_status_test.dart
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiper/core/database/app_database.dart';
import 'package:kiper/features/settings/widgets/export_import_section.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Map<String, dynamic> sub(String id, String? status) => {
        'id': id,
        'name': 'Sub $id',
        'amount': 100.0,
        'currency': 'RUB',
        'billingPeriod': 'monthly',
        'nextBillingDate': '2026-11-01T00:00:00.000',
        'startDate': '2026-01-01T00:00:00.000',
        'status': status,
      };

  Future<Map<String, String>> statuses() async {
    final rows = await db.select(db.subscriptions).get();
    return {for (final r in rows) r.id: r.status};
  }

  test('JSON import keeps paused and cancelled statuses (e.g. from the iOS app)', () async {
    final json = jsonEncode({
      'version': 1,
      'exportedAt': '2026-10-13T00:00:00.000',
      'subscriptions': [sub('a', 'active'), sub('p', 'paused'), sub('c', 'cancelled'), sub('x', 'weird'), sub('n', null)],
      'categories': [],
      'settings': {},
    });

    await ExportImportHelper.importJsonReplace(db, json);

    expect(await statuses(), {'a': 'active', 'p': 'paused', 'c': 'cancelled', 'x': 'active', 'n': 'active'});
  });

  test('CSV import keeps status column', () async {
    const csv = 'id,name,amount,currency,billingPeriod,customPeriodDays,categoryId,nextBillingDate,startDate,status,reminderDaysBefore,note\n'
        'p,Paused,10.0,USD,monthly,,,2026-11-01T00:00:00.000,2026-01-01T00:00:00.000,paused,1,\n'
        'a,Active,10.0,USD,monthly,,,2026-11-01T00:00:00.000,2026-01-01T00:00:00.000,,1,\n';

    await ExportImportHelper.importCsv(db, csv);

    expect(await statuses(), {'p': 'paused', 'a': 'active'});
  });
}
