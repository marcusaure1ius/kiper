// lib/features/settings/providers/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiper/core/notifications/notification_service.dart';

// ---------------------------------------------------------------------------
// Theme Mode
// ---------------------------------------------------------------------------

const _kThemeModeKey = 'theme_mode';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Load synchronously; async init is done via _loadInitial called by provider
    _loadInitial();
    return ThemeMode.system;
  }

  Future<void> _loadInitial() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_kThemeModeKey);
    if (value != null) {
      state = _fromString(value);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, _toString(mode));
  }

  static ThemeMode _fromString(String value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String _toString(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}

final themeModeNotifierProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

// ---------------------------------------------------------------------------
// Reminders Enabled
// ---------------------------------------------------------------------------

const _kRemindersEnabledKey = 'reminders_enabled';

class RemindersEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadInitial();
    return true;
  }

  Future<void> _loadInitial() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kRemindersEnabledKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRemindersEnabledKey, enabled);
    if (!enabled) {
      await NotificationService.cancelAll();
    }
  }
}

final remindersEnabledNotifierProvider = NotifierProvider<RemindersEnabledNotifier, bool>(
  RemindersEnabledNotifier.new,
);

// ---------------------------------------------------------------------------
// Reminder Time (hour + minute)
// ---------------------------------------------------------------------------

const _kReminderHourKey = 'reminder_hour';
const _kReminderMinuteKey = 'reminder_minute';

class ReminderTime {
  final int hour;
  final int minute;
  const ReminderTime({required this.hour, required this.minute});

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class ReminderTimeNotifier extends Notifier<ReminderTime> {
  @override
  ReminderTime build() {
    _loadInitial();
    return const ReminderTime(hour: 9, minute: 0); // default 09:00
  }

  Future<void> _loadInitial() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_kReminderHourKey) ?? 9;
    final minute = prefs.getInt(_kReminderMinuteKey) ?? 0;
    state = ReminderTime(hour: hour, minute: minute);
  }

  Future<void> setTime(int hour, int minute) async {
    state = ReminderTime(hour: hour, minute: minute);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kReminderHourKey, hour);
    await prefs.setInt(_kReminderMinuteKey, minute);
  }
}

final reminderTimeNotifierProvider = NotifierProvider<ReminderTimeNotifier, ReminderTime>(
  ReminderTimeNotifier.new,
);
