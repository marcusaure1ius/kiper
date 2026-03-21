import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sub_tracker/app.dart';
import 'package:sub_tracker/core/database/database_provider.dart';
import 'package:sub_tracker/core/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  await NotificationService.init();
  final db = await createDatabase();

  // Seed test data if DB is empty (debug only — remove for production)
  final subCount = await db.select(db.subscriptions).get();
  if (subCount.isEmpty) {
    await db.seedTestSubscriptions();
  }

  runApp(ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: const SubTrackerApp(),
  ));
}
