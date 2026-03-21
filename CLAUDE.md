# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Кипер (Kiper) — Flutter Android app for tracking recurring subscriptions with multi-currency support, analytics, and notifications.

## Build & Run

```bash
flutter pub get                                                   # install dependencies
dart run build_runner build --delete-conflicting-outputs           # code generation (Drift, freezed, Riverpod)
flutter build apk --debug                                         # build debug APK
flutter install --debug                                           # install on connected device
flutter run                                                       # run on connected device/emulator
flutter test                                                      # run all tests
flutter test test/path/to_test.dart                                # run single test file
dart analyze                                                      # static analysis (must show "No issues found!")
```

Always run `build_runner` after modifying files with `part` directives (models, database, providers).

## Architecture

Feature-first + Riverpod. Code in `lib/features/{feature}/` with models/providers/screens/widgets. Core services in `lib/core/`.

- **State management**: Riverpod v4 (`flutter_riverpod ^3.1.0`) with code generation (`@riverpod` annotation). Use `Ref` (not feature-specific Ref types) in provider functions.
- **Database**: Drift (SQLite) — schema in `lib/core/database/app_database.dart`, provider in `lib/core/database/database_provider.dart`
- **Models**: freezed v3 + json_serializable — use `abstract class` with `_$` mixin pattern. Generated `.freezed.dart` and `.g.dart` files.
- **Navigation**: go_router with StatefulShellRoute for bottom nav (3 tabs: Подписки, Аналитика, Настройки)
- **Theme**: Material 3 with dynamic_color, persisted via SharedPreferences
- **Notifications**: flutter_local_notifications with timezone, scheduled reminders

## Key Conventions

- Enums for Currency, BillingPeriod, SubscriptionStatus — not strings in app logic (strings only in DB layer)
- Exchange rates fetched from CBR XML API (`https://www.cbr.ru/scripts/XML_daily.asp`), fallback hardcoded rates
- Subscription soft-delete: status changes to `cancelled`, row stays in DB for analytics
- When deleting a category, null out `categoryId` on related subscriptions first
- Russian-only UI, no l10n
- All amounts displayed in original currency + RUB equivalent
- Test data seeded in `main.dart` when DB is empty (debug only — remove for production)

## Android Build Notes

- Requires Java 17 (set in `android/gradle.properties` via `org.gradle.java.home`)
- Core library desugaring enabled in `android/app/build.gradle.kts`
- `sqlite3_flutter_libs` required for SQLite native library on Android
