# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

SubTracker — Flutter Android app for tracking recurring subscriptions with multi-currency support, analytics, and notifications.

## Build & Run

```bash
flutter pub get                    # install dependencies
dart run build_runner build --delete-conflicting-outputs  # code generation (Drift, freezed, Riverpod)
flutter run                       # run on connected device/emulator
flutter test                      # run all tests
flutter test test/path/to_test.dart  # run single test file
```

Always run `build_runner` after modifying files with `part` directives (models, database, providers).

## Architecture

Feature-first + Riverpod. Code in `lib/features/{feature}/` with models/providers/screens/widgets. Core services in `lib/core/`.

- **State management**: Riverpod v4 with code generation (`@riverpod` annotation). Use `Ref` (not feature-specific Ref types) in provider functions.
- **Database**: Drift (SQLite) — schema in `lib/core/database/app_database.dart`
- **Models**: freezed v3 + json_serializable — immutable, with `.freezed.dart` and `.g.dart` generated files
- **Navigation**: go_router with StatefulShellRoute for bottom nav
- **Theme**: Material 3 with dynamic_color

## Key Conventions

- Enums for Currency, BillingPeriod, SubscriptionStatus — not strings in app logic (strings only in DB layer)
- Exchange rates fetched from CBR XML API, cached locally, fallback hardcoded rates
- Subscription soft-delete: status changes to `cancelled`, row stays in DB for analytics
- Russian-only UI, no l10n
- All amounts displayed in original currency + RUB equivalent
