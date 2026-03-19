# SubTracker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter Android app for tracking recurring subscriptions with multi-currency support, analytics, and notifications.

**Architecture:** Feature-first + Riverpod. Code organized by features (subscriptions, analytics, settings), each with models/providers/screens/widgets. Drift for SQLite, fl_chart for graphs, go_router for navigation.

**Tech Stack:** Flutter 3.x, Riverpod (code gen), Drift, freezed, fl_chart, flutter_local_notifications, dynamic_color, go_router

**Spec:** `docs/superpowers/specs/2026-03-19-subtracker-design.md`

---

## File Map

```
lib/
├── main.dart                                          # Entry point, init notifications, run app
├── app.dart                                           # MaterialApp.router, theme, GoRouter config
├── core/
│   ├── database/
│   │   ├── app_database.dart                          # Drift database class, tables, DAOs
│   │   └── app_database.g.dart                        # Generated
│   ├── theme/
│   │   └── app_theme.dart                             # M3 light/dark ThemeData, dynamic_color
│   ├── currency/
│   │   ├── currency.dart                              # Currency enum (RUB, USD, EUR)
│   │   ├── exchange_rate_service.dart                 # Fetch CBR XML, parse, cache
│   │   └── exchange_rate_provider.dart                # Riverpod provider for rates
│   └── notifications/
│       └── notification_service.dart                  # Schedule/cancel local notifications
├── features/
│   ├── subscriptions/
│   │   ├── models/
│   │   │   ├── subscription.dart                      # Subscription freezed model
│   │   │   ├── subscription.freezed.dart              # Generated
│   │   │   ├── subscription.g.dart                    # Generated
│   │   │   ├── billing_period.dart                    # BillingPeriod enum + helpers
│   │   │   └── subscription_status.dart               # SubscriptionStatus enum
│   │   ├── providers/
│   │   │   └── subscriptions_provider.dart            # CRUD providers, filtered lists
│   │   ├── screens/
│   │   │   ├── subscriptions_list_screen.dart         # Main list with total
│   │   │   ├── subscription_detail_screen.dart        # View/edit/delete
│   │   │   └── subscription_form_screen.dart          # Add/edit form + catalog picker
│   │   ├── widgets/
│   │   │   ├── subscription_card.dart                 # M3 Card for list
│   │   │   ├── total_header.dart                      # Monthly total in RUB
│   │   │   └── category_filter_chips.dart             # Filter chips by category
│   │   └── catalog/
│   │       ├── catalog_data.dart                      # Predefined services list
│   │       └── catalog_picker.dart                    # Bottom sheet for picking from catalog
│   ├── categories/
│   │   ├── models/
│   │   │   ├── category.dart                          # Category freezed model
│   │   │   ├── category.freezed.dart                  # Generated
│   │   │   └── category.g.dart                        # Generated
│   │   ├── providers/
│   │   │   └── categories_provider.dart               # CRUD providers, seed defaults
│   │   └── widgets/
│   │       └── category_list_tile.dart                # Tile for settings screen
│   ├── analytics/
│   │   ├── providers/
│   │   │   └── analytics_provider.dart                # Monthly totals, forecast, category breakdown
│   │   ├── screens/
│   │   │   └── analytics_screen.dart                  # Charts screen
│   │   └── widgets/
│   │       ├── monthly_bar_chart.dart                 # Bar chart (past + forecast)
│   │       └── category_pie_chart.dart                # Pie chart by category
│   └── settings/
│       ├── providers/
│       │   └── settings_provider.dart                 # Theme mode, default currency, reminder time
│       ├── screens/
│       │   └── settings_screen.dart                   # Settings list
│       └── widgets/
│           └── export_import_section.dart             # Export/import logic + UI
└── shared/
    └── widgets/
        └── currency_text.dart                         # Format amount with currency symbol + RUB equivalent

test/
├── core/
│   ├── currency/
│   │   └── exchange_rate_service_test.dart
│   └── database/
│       └── app_database_test.dart
├── features/
│   ├── subscriptions/
│   │   ├── models/
│   │   │   └── billing_period_test.dart
│   │   └── providers/
│   │       └── subscriptions_provider_test.dart
│   ├── categories/
│   │   └── providers/
│   │       └── categories_provider_test.dart
│   ├── analytics/
│   │   └── providers/
│   │       └── analytics_provider_test.dart
│   └── settings/
│       └── export_import_test.dart
└── widget_test.dart                                   # Basic smoke test
```

---

### Task 1: Project scaffold and dependencies

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/main.dart`
- Create: `analysis_options.yaml`

- [ ] **Step 1: Create Flutter project**

```bash
flutter create --org com.subtracker --project-name sub_tracker --platforms android .
```

- [ ] **Step 2: Replace pubspec.yaml dependencies**

Replace the `dependencies` and `dev_dependencies` sections in `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1
  drift: ^2.22.1
  sqlite3_flutter_libs: ^0.5.28
  path_provider: ^2.1.5
  path: ^1.9.1
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  fl_chart: ^0.70.2
  flutter_local_notifications: ^18.0.1
  go_router: ^15.1.1
  dynamic_color: ^1.7.0
  http: ^1.3.0
  xml: ^6.5.0
  uuid: ^4.5.1
  intl: ^0.20.2
  share_plus: ^10.1.4
  file_picker: ^8.1.7
  google_fonts: ^6.2.1
  shared_preferences: ^2.3.4
  timezone: ^0.10.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.4.14
  drift_dev: ^2.22.1
  freezed: ^2.5.7
  json_serializable: ^6.9.4
  riverpod_generator: ^2.6.3
  riverpod_lint: ^2.6.3
  custom_lint: ^0.7.5
  mockito: ^5.4.5
  build_verify: ^3.1.0
```

- [ ] **Step 3: Run flutter pub get**

```bash
flutter pub get
```
Expected: resolves all dependencies without errors.

- [ ] **Step 4: Verify project builds**

```bash
flutter build apk --debug
```
Expected: BUILD SUCCESSFUL

- [ ] **Step 5: Commit**

```bash
git init && git add -A && git commit -m "chore: scaffold Flutter project with dependencies"
```

---

### Task 2: Enums and core models

**Files:**
- Create: `lib/core/currency/currency.dart`
- Create: `lib/features/subscriptions/models/billing_period.dart`
- Create: `lib/features/subscriptions/models/subscription_status.dart`
- Test: `test/features/subscriptions/models/billing_period_test.dart`

- [ ] **Step 1: Write billing period test**

```dart
// test/features/subscriptions/models/billing_period_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sub_tracker/features/subscriptions/models/billing_period.dart';

void main() {
  group('BillingPeriod', () {
    test('nextDate advances monthly correctly', () {
      final date = DateTime(2026, 1, 15);
      final next = BillingPeriod.monthly.nextDate(date);
      expect(next, DateTime(2026, 2, 15));
    });

    test('nextDate advances quarterly correctly', () {
      final date = DateTime(2026, 1, 15);
      final next = BillingPeriod.quarterly.nextDate(date);
      expect(next, DateTime(2026, 4, 15));
    });

    test('nextDate advances annually correctly', () {
      final date = DateTime(2026, 1, 15);
      final next = BillingPeriod.annual.nextDate(date);
      expect(next, DateTime(2027, 1, 15));
    });

    test('nextDate advances weekly correctly', () {
      final date = DateTime(2026, 1, 15);
      final next = BillingPeriod.weekly.nextDate(date);
      expect(next, DateTime(2026, 1, 22));
    });

    test('nextDate advances semiannually correctly', () {
      final date = DateTime(2026, 1, 15);
      final next = BillingPeriod.semiannual.nextDate(date);
      expect(next, DateTime(2026, 7, 15));
    });

    test('monthlyEquivalent returns correct multiplier', () {
      expect(BillingPeriod.monthly.monthlyEquivalent, 1.0);
      expect(BillingPeriod.quarterly.monthlyEquivalent, closeTo(0.3333, 0.001));
      expect(BillingPeriod.annual.monthlyEquivalent, closeTo(0.0833, 0.001));
      expect(BillingPeriod.weekly.monthlyEquivalent, closeTo(4.333, 0.01));
      expect(BillingPeriod.semiannual.monthlyEquivalent, closeTo(0.1667, 0.001));
    });

    test('customNextDate advances by N days', () {
      final date = DateTime(2026, 1, 15);
      final next = BillingPeriod.custom.nextDateCustom(date, 45);
      expect(next, DateTime(2026, 3, 1));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/subscriptions/models/billing_period_test.dart
```
Expected: FAIL — file not found.

- [ ] **Step 3: Create Currency enum**

```dart
// lib/core/currency/currency.dart
enum Currency {
  rub(symbol: '₽', code: 'RUB'),
  usd(symbol: '\$', code: 'USD'),
  eur(symbol: '€', code: 'EUR');

  const Currency({required this.symbol, required this.code});
  final String symbol;
  final String code;
}
```

- [ ] **Step 4: Create SubscriptionStatus enum**

```dart
// lib/features/subscriptions/models/subscription_status.dart
enum SubscriptionStatus {
  active,
  paused,
  cancelled;
}
```

- [ ] **Step 5: Create BillingPeriod enum with helpers**

```dart
// lib/features/subscriptions/models/billing_period.dart
enum BillingPeriod {
  weekly,
  monthly,
  quarterly,
  semiannual,
  annual,
  custom;

  /// How many times per month this period bills (for monthly cost calculation).
  double get monthlyEquivalent => switch (this) {
    weekly => 52 / 12,
    monthly => 1.0,
    quarterly => 1 / 3,
    semiannual => 1 / 6,
    annual => 1 / 12,
    custom => 1.0, // caller must compute manually
  };

  /// Returns the next billing date after [current] for this period.
  DateTime nextDate(DateTime current) => switch (this) {
    weekly => current.add(const Duration(days: 7)),
    monthly => DateTime(current.year, current.month + 1, current.day),
    quarterly => DateTime(current.year, current.month + 3, current.day),
    semiannual => DateTime(current.year, current.month + 6, current.day),
    annual => DateTime(current.year + 1, current.month, current.day),
    custom => current, // use nextDateCustom instead
  };

  /// For custom periods: advance by [days].
  DateTime nextDateCustom(DateTime current, int days) =>
      current.add(Duration(days: days));
}
```

- [ ] **Step 6: Run test to verify it passes**

```bash
flutter test test/features/subscriptions/models/billing_period_test.dart
```
Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/core/currency/currency.dart lib/features/subscriptions/models/ test/features/subscriptions/models/
git commit -m "feat: add Currency, BillingPeriod, SubscriptionStatus enums"
```

---

### Task 3: Freezed models (Subscription, Category)

**Files:**
- Create: `lib/features/subscriptions/models/subscription.dart`
- Create: `lib/features/categories/models/category.dart`

- [ ] **Step 1: Create Subscription freezed model**

```dart
// lib/features/subscriptions/models/subscription.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:sub_tracker/core/currency/currency.dart';
import 'package:sub_tracker/features/subscriptions/models/billing_period.dart';
import 'package:sub_tracker/features/subscriptions/models/subscription_status.dart';

part 'subscription.freezed.dart';
part 'subscription.g.dart';

@freezed
class Subscription with _$Subscription {
  const factory Subscription({
    required String id,
    required String name,
    String? icon,
    required double amount,
    required Currency currency,
    required BillingPeriod billingPeriod,
    int? customPeriodDays,
    String? categoryId,
    required DateTime nextBillingDate,
    @Default(1) int reminderDaysBefore,
    @Default(SubscriptionStatus.active) SubscriptionStatus status,
    required DateTime startDate,
    String? note,
    required DateTime createdAt,
  }) = _Subscription;

  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);
}
```

- [ ] **Step 2: Create Category freezed model**

```dart
// lib/features/categories/models/category.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'category.freezed.dart';
part 'category.g.dart';

@freezed
class Category with _$Category {
  const factory Category({
    required String id,
    required String name,
    required int color,
    required String icon,
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
}
```

- [ ] **Step 3: Run code generation**

```bash
dart run build_runner build --delete-conflicting-outputs
```
Expected: generates `.freezed.dart` and `.g.dart` files without errors.

- [ ] **Step 4: Verify build**

```bash
flutter build apk --debug
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 5: Commit**

```bash
git add lib/features/subscriptions/models/ lib/features/categories/models/
git commit -m "feat: add Subscription and Category freezed models"
```

---

### Task 4: Drift database with tables and DAOs

**Files:**
- Create: `lib/core/database/app_database.dart`
- Test: `test/core/database/app_database_test.dart`

- [ ] **Step 1: Write database test**

```dart
// test/core/database/app_database_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sub_tracker/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Categories', () {
    test('seed categories are inserted on creation', () async {
      final categories = await db.select(db.categories).get();
      expect(categories.length, 5);
      expect(categories.map((c) => c.name), containsAll(['Стриминг', 'AI-сервисы', 'Связь', 'Развлечения', 'Другое']));
    });

    test('can insert and retrieve a category', () async {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'test-id',
        name: 'Test',
        color: 0xFFFF0000,
        icon: 'star',
      ));
      final all = await db.select(db.categories).get();
      expect(all.any((c) => c.name == 'Test'), isTrue);
    });
  });

  group('Subscriptions', () {
    test('can insert and retrieve a subscription', () async {
      await db.into(db.subscriptions).insert(SubscriptionsCompanion.insert(
        id: 'sub-1',
        name: 'Netflix',
        amount: 22.99,
        currency: 'USD',
        billingPeriod: 'monthly',
        nextBillingDate: DateTime(2026, 4, 1),
        startDate: DateTime(2026, 1, 1),
        createdAt: DateTime.now(),
      ));
      final subs = await db.select(db.subscriptions).get();
      expect(subs.length, 1);
      expect(subs.first.name, 'Netflix');
    });
  });

  group('ExchangeRates', () {
    test('can upsert and retrieve exchange rate', () async {
      await db.into(db.exchangeRates).insertOnConflictUpdate(
        ExchangeRatesCompanion.insert(
          fromCurrency: 'USD',
          toCurrency: 'RUB',
          rate: 92.5,
          updatedAt: DateTime.now(),
        ),
      );
      final rates = await db.select(db.exchangeRates).get();
      expect(rates.length, 1);
      expect(rates.first.rate, 92.5);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/core/database/app_database_test.dart
```
Expected: FAIL — imports not found.

- [ ] **Step 3: Create Drift database**

```dart
// lib/core/database/app_database.dart
import 'package:drift/drift.dart';

part 'app_database.g.dart';

class Subscriptions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text().nullable()();
  RealColumn get amount => real()();
  TextColumn get currency => text()(); // RUB, USD, EUR
  TextColumn get billingPeriod => text()(); // weekly, monthly, etc.
  IntColumn get customPeriodDays => integer().nullable()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  DateTimeColumn get nextBillingDate => dateTime()();
  IntColumn get reminderDaysBefore => integer().withDefault(const Constant(1))();
  TextColumn get status => text().withDefault(const Constant('active'))(); // active, paused, cancelled
  DateTimeColumn get startDate => dateTime()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get color => integer()();
  TextColumn get icon => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class ExchangeRates extends Table {
  TextColumn get fromCurrency => text()();
  TextColumn get toCurrency => text()();
  RealColumn get rate => real()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {fromCurrency, toCurrency};
}

@DriftDatabase(tables: [Subscriptions, Categories, ExchangeRates])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedCategories();
    },
  );

  Future<void> _seedCategories() async {
    final seeds = [
      CategoriesCompanion.insert(id: 'cat-streaming', name: 'Стриминг', color: 0xFF7C4DFF, icon: 'movie'),
      CategoriesCompanion.insert(id: 'cat-ai', name: 'AI-сервисы', color: 0xFF2196F3, icon: 'smart_toy'),
      CategoriesCompanion.insert(id: 'cat-telecom', name: 'Связь', color: 0xFFFF6B35, icon: 'phone_android'),
      CategoriesCompanion.insert(id: 'cat-entertainment', name: 'Развлечения', color: 0xFFE50914, icon: 'sports_esports'),
      CategoriesCompanion.insert(id: 'cat-other', name: 'Другое', color: 0xFF9E9E9E, icon: 'category'),
    ];
    for (final seed in seeds) {
      await into(categories).insert(seed);
    }
  }
}
```

- [ ] **Step 4: Run code generation**

```bash
dart run build_runner build --delete-conflicting-outputs
```
Expected: generates `app_database.g.dart`.

- [ ] **Step 5: Run test to verify it passes**

```bash
flutter test test/core/database/app_database_test.dart
```
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/database/ test/core/database/
git commit -m "feat: add Drift database with Subscriptions, Categories, ExchangeRates tables"
```

---

### Task 5: Exchange rate service

**Files:**
- Create: `lib/core/currency/exchange_rate_service.dart`
- Create: `lib/core/currency/exchange_rate_provider.dart`
- Test: `test/core/currency/exchange_rate_service_test.dart`

- [ ] **Step 1: Write exchange rate service test**

```dart
// test/core/currency/exchange_rate_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sub_tracker/core/currency/currency.dart';
import 'package:sub_tracker/core/currency/exchange_rate_service.dart';

void main() {
  group('ExchangeRateService', () {
    test('parseCbrXml extracts USD and EUR rates', () {
      const xml = '''<?xml version="1.0" encoding="windows-1251"?>
<ValCurs Date="19.03.2026" name="Foreign Currency Market">
  <Valute ID="R01235">
    <NumCode>840</NumCode>
    <CharCode>USD</CharCode>
    <Nominal>1</Nominal>
    <Name>Доллар США</Name>
    <Value>92,5000</Value>
    <VunitRate>92,5000</VunitRate>
  </Valute>
  <Valute ID="R01239">
    <NumCode>978</NumCode>
    <CharCode>EUR</CharCode>
    <Nominal>1</Nominal>
    <Name>Евро</Name>
    <Value>100,5000</Value>
    <VunitRate>100,5000</VunitRate>
  </Valute>
</ValCurs>''';

      final rates = ExchangeRateService.parseCbrXml(xml);
      expect(rates[Currency.usd], 92.5);
      expect(rates[Currency.eur], 100.5);
    });

    test('fallback rates are provided', () {
      final rates = ExchangeRateService.fallbackRates;
      expect(rates.containsKey(Currency.usd), isTrue);
      expect(rates.containsKey(Currency.eur), isTrue);
      expect(rates[Currency.usd]!, greaterThan(0));
    });

    test('convertToRub returns same value for RUB', () {
      final rates = {Currency.usd: 92.5, Currency.eur: 100.5};
      expect(ExchangeRateService.convertToRub(1000, Currency.rub, rates), 1000.0);
    });

    test('convertToRub converts USD correctly', () {
      final rates = {Currency.usd: 92.5, Currency.eur: 100.5};
      expect(ExchangeRateService.convertToRub(10, Currency.usd, rates), 925.0);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/core/currency/exchange_rate_service_test.dart
```
Expected: FAIL.

- [ ] **Step 3: Create ExchangeRateService**

```dart
// lib/core/currency/exchange_rate_service.dart
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:sub_tracker/core/currency/currency.dart';

class ExchangeRateService {
  static const _cbrUrl = 'https://www.cbr.ru/scripts/XML_daily.asp';

  static final Map<Currency, double> fallbackRates = {
    Currency.usd: 90.0,
    Currency.eur: 98.0,
  };

  /// Fetches current rates from CBR. Returns {Currency: rateInRub}.
  static Future<Map<Currency, double>> fetchRates() async {
    try {
      final response = await http.get(Uri.parse(_cbrUrl));
      if (response.statusCode == 200) {
        return parseCbrXml(response.body);
      }
    } catch (_) {}
    return fallbackRates;
  }

  /// Parses CBR XML response into {Currency: rateInRub}.
  static Map<Currency, double> parseCbrXml(String xmlString) {
    final document = xml.XmlDocument.parse(xmlString);
    final rates = <Currency, double>{};

    for (final valute in document.findAllElements('Valute')) {
      final charCode = valute.findElements('CharCode').first.innerText;
      final valueStr = valute.findElements('Value').first.innerText;
      final nominal = int.parse(valute.findElements('Nominal').first.innerText);
      final value = double.parse(valueStr.replaceAll(',', '.'));

      final currency = Currency.values.where((c) => c.code == charCode).firstOrNull;
      if (currency != null) {
        rates[currency] = value / nominal;
      }
    }

    return rates;
  }

  /// Converts [amount] in [currency] to RUB using [rates].
  static double convertToRub(
    double amount,
    Currency currency,
    Map<Currency, double> rates,
  ) {
    if (currency == Currency.rub) return amount;
    final rate = rates[currency] ?? fallbackRates[currency] ?? 1.0;
    return amount * rate;
  }
}
```

- [ ] **Step 4: Create Riverpod provider**

```dart
// lib/core/currency/exchange_rate_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sub_tracker/core/currency/currency.dart';
import 'package:sub_tracker/core/currency/exchange_rate_service.dart';

part 'exchange_rate_provider.g.dart';

@riverpod
Future<Map<Currency, double>> exchangeRates(ExchangeRatesRef ref) async {
  return ExchangeRateService.fetchRates();
}
```

- [ ] **Step 5: Run code generation**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 6: Run test to verify it passes**

```bash
flutter test test/core/currency/exchange_rate_service_test.dart
```
Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/core/currency/ test/core/currency/
git commit -m "feat: add exchange rate service with CBR API and fallback rates"
```

---

### Task 6: Theme setup (Material 3 + Dynamic Color)

**Files:**
- Create: `lib/core/theme/app_theme.dart`

- [ ] **Step 1: Create theme file**

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light([ColorScheme? dynamicScheme]) {
    final scheme = dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.light,
        );
    return _build(scheme);
  }

  static ThemeData dark([ColorScheme? dynamicScheme]) {
    final scheme = dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.dark,
        );
    return _build(scheme);
  }

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: GoogleFonts.interTextTheme(),
      navigationBarTheme: const NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),
    );
  }
}
```

- [ ] **Step 2: Verify build**

```bash
flutter build apk --debug
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 3: Commit**

```bash
git add lib/core/theme/
git commit -m "feat: add Material 3 theme with dynamic color support"
```

---

### Task 7: App shell — MaterialApp, GoRouter, Bottom Navigation

**Files:**
- Create: `lib/app.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Create app.dart with GoRouter and shell**

```dart
// lib/app.dart
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sub_tracker/core/theme/app_theme.dart';
import 'package:sub_tracker/features/subscriptions/screens/subscriptions_list_screen.dart';
import 'package:sub_tracker/features/analytics/screens/analytics_screen.dart';
import 'package:sub_tracker/features/settings/screens/settings_screen.dart';
import 'package:sub_tracker/features/settings/providers/settings_provider.dart';
import 'package:sub_tracker/core/notifications/notification_service.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/subscriptions',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          ScaffoldWithNav(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/subscriptions', builder: (_, __) => const SubscriptionsListScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ]),
      ],
    ),
  ],
);

class SubTrackerApp extends ConsumerStatefulWidget {
  const SubTrackerApp({super.key});

  @override
  ConsumerState<SubTrackerApp> createState() => _SubTrackerAppState();
}

class _SubTrackerAppState extends ConsumerState<SubTrackerApp> {
  @override
  void initState() {
    super.initState();
    NotificationService.onNotificationTap = (payload) {
      if (payload != null) {
        goRouter.push('/subscriptions/$payload');
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeNotifierProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp.router(
          title: 'SubTracker',
          theme: AppTheme.light(lightDynamic),
          darkTheme: AppTheme.dark(darkDynamic),
          themeMode: themeMode,
          routerConfig: goRouter,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class ScaffoldWithNav extends StatelessWidget {
  const ScaffoldWithNav({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.subscriptions_outlined), selectedIcon: Icon(Icons.subscriptions), label: 'Подписки'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Аналитика'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Настройки'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Create placeholder screens**

Create minimal placeholder screens so the app compiles:

```dart
// lib/features/subscriptions/screens/subscriptions_list_screen.dart
import 'package:flutter/material.dart';

class SubscriptionsListScreen extends StatelessWidget {
  const SubscriptionsListScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Подписки')));
}
```

```dart
// lib/features/analytics/screens/analytics_screen.dart
import 'package:flutter/material.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Аналитика')));
}
```

```dart
// lib/features/settings/screens/settings_screen.dart
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Настройки')));
}
```

- [ ] **Step 3: Update main.dart**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sub_tracker/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SubTrackerApp()));
}
```

- [ ] **Step 4: Run app to verify navigation works**

```bash
flutter build apk --debug
```
Expected: BUILD SUCCESSFUL. App shows bottom navigation with 3 tabs.

- [ ] **Step 5: Commit**

```bash
git add lib/app.dart lib/main.dart lib/features/subscriptions/screens/ lib/features/analytics/screens/ lib/features/settings/screens/
git commit -m "feat: add app shell with GoRouter and bottom navigation"
```

---

### Task 8: Categories provider (CRUD + seed)

**Files:**
- Create: `lib/features/categories/providers/categories_provider.dart`
- Test: `test/features/categories/providers/categories_provider_test.dart`

- [ ] **Step 1: Write categories provider test**

```dart
// test/features/categories/providers/categories_provider_test.dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sub_tracker/core/database/app_database.dart';
import 'package:sub_tracker/features/categories/providers/categories_provider.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
  });

  tearDown(() async {
    await db.close();
    container.dispose();
  });

  test('watchCategories returns seed categories', () async {
    final categories = await container.read(watchCategoriesProvider.future);
    expect(categories.length, 5);
  });

  test('addCategory inserts a new category', () async {
    await container.read(categoriesNotifierProvider.notifier).add(
      name: 'Тест',
      color: 0xFF000000,
      icon: 'star',
    );
    final categories = await container.read(watchCategoriesProvider.future);
    expect(categories.any((c) => c.name == 'Тест'), isTrue);
  });

  test('deleteCategory removes a category', () async {
    await container.read(categoriesNotifierProvider.notifier).remove('cat-other');
    final categories = await container.read(watchCategoriesProvider.future);
    expect(categories.any((c) => c.id == 'cat-other'), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/categories/providers/categories_provider_test.dart
```
Expected: FAIL.

- [ ] **Step 3: Create database provider and categories provider**

First, add a Riverpod provider for the database. Create or update a file:

```dart
// lib/core/database/database_provider.dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:sub_tracker/core/database/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Override in main.dart');
});

Future<AppDatabase> createDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'subtracker.db'));
  return AppDatabase(NativeDatabase.createInBackground(file));
}
```

Then the categories provider:

```dart
// lib/features/categories/providers/categories_provider.dart
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:sub_tracker/core/database/app_database.dart';
import 'package:sub_tracker/core/database/database_provider.dart';

part 'categories_provider.g.dart';

@riverpod
Stream<List<Category>> watchCategories(WatchCategoriesRef ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.categories).watch();
}

@riverpod
class CategoriesNotifier extends _$CategoriesNotifier {
  @override
  FutureOr<void> build() {}

  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> add({required String name, required int color, required String icon}) async {
    await _db.into(_db.categories).insert(CategoriesCompanion.insert(
      id: const Uuid().v4(),
      name: name,
      color: color,
      icon: icon,
    ));
  }

  Future<void> update({required String id, required String name, required int color, required String icon}) async {
    await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(name: Value(name), color: Value(color), icon: Value(icon)),
    );
  }

  Future<void> remove(String id) async {
    await (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
  }
}
```

- [ ] **Step 4: Run code generation**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 5: Run test to verify it passes**

```bash
flutter test test/features/categories/providers/categories_provider_test.dart
```
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/database/database_provider.dart lib/features/categories/providers/ test/features/categories/providers/
git commit -m "feat: add categories provider with CRUD and seed data"
```

---

### Task 9: Subscriptions provider (CRUD + billing date advancement)

**Files:**
- Create: `lib/features/subscriptions/providers/subscriptions_provider.dart`
- Test: `test/features/subscriptions/providers/subscriptions_provider_test.dart`

- [ ] **Step 1: Write subscriptions provider test**

```dart
// test/features/subscriptions/providers/subscriptions_provider_test.dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sub_tracker/core/database/app_database.dart';
import 'package:sub_tracker/core/database/database_provider.dart';
import 'package:sub_tracker/features/subscriptions/providers/subscriptions_provider.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
  });

  tearDown(() async {
    await db.close();
    container.dispose();
  });

  test('add and watch subscription', () async {
    await container.read(subscriptionsNotifierProvider.notifier).add(
      name: 'Netflix',
      amount: 22.99,
      currency: 'USD',
      billingPeriod: 'monthly',
      nextBillingDate: DateTime(2026, 4, 1),
      startDate: DateTime(2026, 1, 1),
    );

    final subs = await container.read(watchActiveSubscriptionsProvider.future);
    expect(subs.length, 1);
    expect(subs.first.name, 'Netflix');
  });

  test('pause subscription excludes from active list', () async {
    await container.read(subscriptionsNotifierProvider.notifier).add(
      name: 'Spotify',
      amount: 10.99,
      currency: 'USD',
      billingPeriod: 'monthly',
      nextBillingDate: DateTime(2026, 4, 1),
      startDate: DateTime(2026, 1, 1),
    );

    var subs = await container.read(watchActiveSubscriptionsProvider.future);
    final id = subs.first.id;

    await container.read(subscriptionsNotifierProvider.notifier).updateStatus(id, 'paused');
    subs = await container.read(watchActiveSubscriptionsProvider.future);
    expect(subs.isEmpty, isTrue);
  });

  test('advanceBillingDates moves past dates forward', () async {
    await container.read(subscriptionsNotifierProvider.notifier).add(
      name: 'Test',
      amount: 100,
      currency: 'RUB',
      billingPeriod: 'monthly',
      nextBillingDate: DateTime(2026, 1, 1), // in the past
      startDate: DateTime(2025, 6, 1),
    );

    await container.read(subscriptionsNotifierProvider.notifier).advanceBillingDates();

    final subs = await container.read(watchActiveSubscriptionsProvider.future);
    expect(subs.first.nextBillingDate.isAfter(DateTime.now()), isTrue);
  });

  test('cancel subscription soft-deletes it', () async {
    await container.read(subscriptionsNotifierProvider.notifier).add(
      name: 'ToCancel',
      amount: 50,
      currency: 'RUB',
      billingPeriod: 'monthly',
      nextBillingDate: DateTime(2026, 4, 1),
      startDate: DateTime(2026, 1, 1),
    );

    var subs = await container.read(watchActiveSubscriptionsProvider.future);
    final id = subs.first.id;

    await container.read(subscriptionsNotifierProvider.notifier).updateStatus(id, 'cancelled');
    subs = await container.read(watchActiveSubscriptionsProvider.future);
    expect(subs.isEmpty, isTrue);

    // Still in DB
    final all = await db.select(db.subscriptions).get();
    expect(all.any((s) => s.id == id), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/subscriptions/providers/subscriptions_provider_test.dart
```
Expected: FAIL.

- [ ] **Step 3: Create subscriptions provider**

```dart
// lib/features/subscriptions/providers/subscriptions_provider.dart
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:sub_tracker/core/database/app_database.dart';
import 'package:sub_tracker/core/database/database_provider.dart';
import 'package:sub_tracker/features/subscriptions/models/billing_period.dart';
import 'package:sub_tracker/core/notifications/notification_service.dart';
import 'package:sub_tracker/core/currency/currency.dart';
import 'package:sub_tracker/core/currency/exchange_rate_service.dart';

part 'subscriptions_provider.g.dart';

@riverpod
Stream<List<Subscription>> watchActiveSubscriptions(WatchActiveSubscriptionsRef ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.subscriptions)
    ..where((t) => t.status.equals('active'))
    ..orderBy([(t) => OrderingTerm.asc(t.nextBillingDate)]))
      .watch();
}

@riverpod
Stream<List<Subscription>> watchVisibleSubscriptions(WatchVisibleSubscriptionsRef ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.subscriptions)
    ..where((t) => t.status.equals('active') | t.status.equals('paused'))
    ..orderBy([(t) => OrderingTerm.asc(t.nextBillingDate)]))
      .watch();
}

@riverpod
Stream<List<Subscription>> watchAllSubscriptions(WatchAllSubscriptionsRef ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.subscriptions).watch();
}

@riverpod
class SubscriptionsNotifier extends _$SubscriptionsNotifier {
  @override
  FutureOr<void> build() {}

  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> add({
    required String name,
    required double amount,
    required String currency,
    required String billingPeriod,
    required DateTime nextBillingDate,
    required DateTime startDate,
    String? icon,
    String? categoryId,
    int? customPeriodDays,
    int reminderDaysBefore = 1,
    String? note,
  }) async {
    final id = const Uuid().v4();
    await _db.into(_db.subscriptions).insert(SubscriptionsCompanion.insert(
      id: id,
      name: name,
      icon: Value(icon),
      amount: amount,
      currency: currency,
      billingPeriod: billingPeriod,
      customPeriodDays: Value(customPeriodDays),
      categoryId: Value(categoryId),
      nextBillingDate: nextBillingDate,
      reminderDaysBefore: Value(reminderDaysBefore),
      startDate: startDate,
      note: Value(note),
      createdAt: DateTime.now(),
    ));

    // Schedule notification
    if (reminderDaysBefore > 0) {
      final reminderDate = nextBillingDate.subtract(Duration(days: reminderDaysBefore));
      final curr = Currency.values.byName(currency.toLowerCase());
      final rubAmount = curr == Currency.rub
          ? amount
          : ExchangeRateService.convertToRub(amount, curr, ExchangeRateService.fallbackRates);
      await NotificationService.scheduleReminder(
        id: id.hashCode,
        title: name,
        body: curr == Currency.rub
            ? 'Списание ₽${amount.toStringAsFixed(0)} ${reminderDaysBefore == 1 ? "завтра" : "через $reminderDaysBefore дн."}'
            : 'Списание ₽${rubAmount.toStringAsFixed(0)} (~${curr.symbol}${amount.toStringAsFixed(2)}) ${reminderDaysBefore == 1 ? "завтра" : "через $reminderDaysBefore дн."}',
        scheduledDate: reminderDate,
        hour: 10,
        minute: 0,
        payload: id,
      );
    }
  }

  Future<void> updateSubscription(String id, SubscriptionsCompanion companion) async {
    await (_db.update(_db.subscriptions)..where((t) => t.id.equals(id))).write(companion);
  }

  Future<void> updateStatus(String id, String status) async {
    await (_db.update(_db.subscriptions)..where((t) => t.id.equals(id))).write(
      SubscriptionsCompanion(status: Value(status)),
    );
    if (status == 'paused' || status == 'cancelled') {
      await NotificationService.cancel(id.hashCode);
    }
  }

  /// Advances nextBillingDate for all active subscriptions where the date is in the past.
  /// Also reschedules notifications for each advanced subscription.
  Future<void> advanceBillingDates() async {
    final now = DateTime.now();
    final subs = await (_db.select(_db.subscriptions)
      ..where((t) => t.status.equals('active'))
      ..where((t) => t.nextBillingDate.isSmallerThanValue(now)))
        .get();

    for (final sub in subs) {
      final period = BillingPeriod.values.byName(sub.billingPeriod);
      var next = sub.nextBillingDate;
      while (next.isBefore(now)) {
        next = period == BillingPeriod.custom
            ? period.nextDateCustom(next, sub.customPeriodDays ?? 30)
            : period.nextDate(next);
      }
      await (_db.update(_db.subscriptions)..where((t) => t.id.equals(sub.id))).write(
        SubscriptionsCompanion(nextBillingDate: Value(next)),
      );

      // Reschedule notification
      if (sub.reminderDaysBefore > 0) {
        final reminderDate = next.subtract(Duration(days: sub.reminderDaysBefore));
        final curr = Currency.values.byName(sub.currency.toLowerCase());
        final rubAmount = curr == Currency.rub
            ? sub.amount
            : ExchangeRateService.convertToRub(sub.amount, curr, ExchangeRateService.fallbackRates);
        await NotificationService.scheduleReminder(
          id: sub.id.hashCode,
          title: sub.name,
          body: curr == Currency.rub
              ? 'Списание ₽${sub.amount.toStringAsFixed(0)} ${sub.reminderDaysBefore == 1 ? "завтра" : "через ${sub.reminderDaysBefore} дн."}'
              : 'Списание ₽${rubAmount.toStringAsFixed(0)} (~${curr.symbol}${sub.amount.toStringAsFixed(2)}) ${sub.reminderDaysBefore == 1 ? "завтра" : "через ${sub.reminderDaysBefore} дн."}',
          scheduledDate: reminderDate,
          hour: 10,
          minute: 0,
          payload: sub.id,
        );
      }
    }
  }

  /// Static version that works directly on the database (for calling before ProviderScope).
  static Future<void> advanceBillingDatesOnDb(AppDatabase db) async {
    final now = DateTime.now();
    final subs = await (db.select(db.subscriptions)
      ..where((t) => t.status.equals('active'))
      ..where((t) => t.nextBillingDate.isSmallerThanValue(now)))
        .get();

    for (final sub in subs) {
      final period = BillingPeriod.values.byName(sub.billingPeriod);
      var next = sub.nextBillingDate;
      while (next.isBefore(now)) {
        next = period == BillingPeriod.custom
            ? period.nextDateCustom(next, sub.customPeriodDays ?? 30)
            : period.nextDate(next);
      }
      await (db.update(db.subscriptions)..where((t) => t.id.equals(sub.id))).write(
        SubscriptionsCompanion(nextBillingDate: Value(next)),
      );

      if (sub.reminderDaysBefore > 0) {
        final reminderDate = next.subtract(Duration(days: sub.reminderDaysBefore));
        final curr = Currency.values.byName(sub.currency.toLowerCase());
        final rubAmount = curr == Currency.rub
            ? sub.amount
            : ExchangeRateService.convertToRub(sub.amount, curr, ExchangeRateService.fallbackRates);
        await NotificationService.scheduleReminder(
          id: sub.id.hashCode,
          title: sub.name,
          body: curr == Currency.rub
              ? 'Списание ₽${sub.amount.toStringAsFixed(0)} ${sub.reminderDaysBefore == 1 ? "завтра" : "через ${sub.reminderDaysBefore} дн."}'
              : 'Списание ₽${rubAmount.toStringAsFixed(0)} (~${curr.symbol}${sub.amount.toStringAsFixed(2)}) ${sub.reminderDaysBefore == 1 ? "завтра" : "через ${sub.reminderDaysBefore} дн."}',
          scheduledDate: reminderDate,
          hour: 10,
          minute: 0,
          payload: sub.id,
        );
      }
    }
  }
}
```

- [ ] **Step 4: Run code generation**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 5: Run test to verify it passes**

```bash
flutter test test/features/subscriptions/providers/subscriptions_provider_test.dart
```
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/subscriptions/providers/ test/features/subscriptions/providers/
git commit -m "feat: add subscriptions provider with CRUD and billing date advancement"
```

---

### Task 10: Subscription catalog data

**Files:**
- Create: `lib/features/subscriptions/catalog/catalog_data.dart`

- [ ] **Step 1: Create catalog data**

```dart
// lib/features/subscriptions/catalog/catalog_data.dart
import 'package:sub_tracker/core/currency/currency.dart';
import 'package:sub_tracker/features/subscriptions/models/billing_period.dart';

class CatalogEntry {
  final String name;
  final String icon; // Material icon name
  final Currency defaultCurrency;
  final BillingPeriod defaultPeriod;
  final String categoryId;

  const CatalogEntry({
    required this.name,
    required this.icon,
    required this.defaultCurrency,
    required this.defaultPeriod,
    required this.categoryId,
  });
}

const catalogData = <CatalogEntry>[
  // Стриминг
  CatalogEntry(name: 'Netflix', icon: 'movie', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-streaming'),
  CatalogEntry(name: 'YouTube Premium', icon: 'smart_display', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-streaming'),
  CatalogEntry(name: 'Spotify', icon: 'music_note', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-streaming'),
  CatalogEntry(name: 'Apple Music', icon: 'music_note', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-streaming'),
  CatalogEntry(name: 'Яндекс Музыка', icon: 'music_note', defaultCurrency: Currency.rub, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-streaming'),
  CatalogEntry(name: 'Кинопоиск', icon: 'movie', defaultCurrency: Currency.rub, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-streaming'),

  // AI-сервисы
  CatalogEntry(name: 'Claude', icon: 'smart_toy', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-ai'),
  CatalogEntry(name: 'ChatGPT', icon: 'smart_toy', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-ai'),
  CatalogEntry(name: 'Perplexity', icon: 'search', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-ai'),
  CatalogEntry(name: 'Google AI (Gemini)', icon: 'auto_awesome', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-ai'),

  // Связь
  CatalogEntry(name: 'МТС', icon: 'phone_android', defaultCurrency: Currency.rub, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-telecom'),
  CatalogEntry(name: 'Билайн', icon: 'phone_android', defaultCurrency: Currency.rub, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-telecom'),
  CatalogEntry(name: 'Мегафон', icon: 'phone_android', defaultCurrency: Currency.rub, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-telecom'),
  CatalogEntry(name: 'Tele2', icon: 'phone_android', defaultCurrency: Currency.rub, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-telecom'),
  CatalogEntry(name: 'Ростелеком', icon: 'wifi', defaultCurrency: Currency.rub, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-telecom'),

  // Развлечения
  CatalogEntry(name: 'PlayStation Plus', icon: 'sports_esports', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-entertainment'),
  CatalogEntry(name: 'Xbox Game Pass', icon: 'sports_esports', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-entertainment'),
  CatalogEntry(name: 'Steam', icon: 'sports_esports', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-entertainment'),
];
```

- [ ] **Step 2: Verify build**

```bash
flutter build apk --debug
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 3: Commit**

```bash
git add lib/features/subscriptions/catalog/
git commit -m "feat: add subscription catalog with predefined services"
```

---

### Task 11: Subscription list screen (UI)

**Files:**
- Modify: `lib/features/subscriptions/screens/subscriptions_list_screen.dart`
- Create: `lib/features/subscriptions/widgets/subscription_card.dart`
- Create: `lib/features/subscriptions/widgets/total_header.dart`
- Create: `lib/features/subscriptions/widgets/category_filter_chips.dart`
- Create: `lib/shared/widgets/currency_text.dart`

- [ ] **Step 1: Create CurrencyText widget**

```dart
// lib/shared/widgets/currency_text.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sub_tracker/core/currency/currency.dart';
import 'package:sub_tracker/core/currency/exchange_rate_provider.dart';
import 'package:sub_tracker/core/currency/exchange_rate_service.dart';

class CurrencyText extends ConsumerWidget {
  final double amount;
  final Currency currency;
  final TextStyle? style;
  final bool showRubEquivalent;

  const CurrencyText({
    super.key,
    required this.amount,
    required this.currency,
    this.style,
    this.showRubEquivalent = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratesAsync = ref.watch(exchangeRatesProvider);
    final formatted = '${currency.symbol}${amount.toStringAsFixed(2)}';

    if (currency == Currency.rub || !showRubEquivalent) {
      return Text(formatted, style: style);
    }

    return ratesAsync.when(
      data: (rates) {
        final rubAmount = ExchangeRateService.convertToRub(amount, currency, rates);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatted, style: style),
            Text(
              '≈ ₽${rubAmount.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
      loading: () => Text(formatted, style: style),
      error: (_, __) => Text(formatted, style: style),
    );
  }
}
```

- [ ] **Step 2: Create SubscriptionCard widget**

```dart
// lib/features/subscriptions/widgets/subscription_card.dart
import 'package:flutter/material.dart';
import 'package:sub_tracker/core/currency/currency.dart';
import 'package:sub_tracker/core/database/app_database.dart' as db;
import 'package:sub_tracker/shared/widgets/currency_text.dart';
import 'package:intl/intl.dart';

class SubscriptionCard extends StatelessWidget {
  final db.Subscription subscription;
  final VoidCallback? onTap;

  const SubscriptionCard({super.key, required this.subscription, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPaused = subscription.status == 'paused';
    final dateFormat = DateFormat('d MMM', 'ru');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: isPaused ? 0.5 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.subscriptions,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                // Name + date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subscription.name, style: theme.textTheme.titleMedium),
                      Text(
                        isPaused
                            ? 'Приостановлена'
                            : 'Списание ${dateFormat.format(subscription.nextBillingDate)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Amount
                CurrencyText(
                  amount: subscription.amount,
                  currency: Currency.values.byName(subscription.currency.toLowerCase()),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Create TotalHeader widget**

```dart
// lib/features/subscriptions/widgets/total_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sub_tracker/core/currency/currency.dart';
import 'package:sub_tracker/core/currency/exchange_rate_provider.dart';
import 'package:sub_tracker/core/currency/exchange_rate_service.dart';
import 'package:sub_tracker/core/database/app_database.dart' as db;
import 'package:sub_tracker/features/subscriptions/models/billing_period.dart';

class TotalHeader extends ConsumerWidget {
  final List<db.Subscription> subscriptions;

  const TotalHeader({super.key, required this.subscriptions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratesAsync = ref.watch(exchangeRatesProvider);
    final theme = Theme.of(context);

    return ratesAsync.when(
      data: (rates) {
        double totalMonthlyRub = 0;
        for (final sub in subscriptions) {
          if (sub.status != 'active') continue;
          final currency = Currency.values.byName(sub.currency.toLowerCase());
          final period = BillingPeriod.values.byName(sub.billingPeriod);
          final monthlyAmount = sub.amount * period.monthlyEquivalent;
          totalMonthlyRub += ExchangeRateService.convertToRub(monthlyAmount, currency, rates);
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Расходы в месяц', style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
              const SizedBox(height: 4),
              Text(
                '₽${totalMonthlyRub.toStringAsFixed(0)}',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Ошибка загрузки курсов'),
      ),
    );
  }
}
```

- [ ] **Step 4: Create CategoryFilterChips widget**

```dart
// lib/features/subscriptions/widgets/category_filter_chips.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sub_tracker/core/database/app_database.dart' as db;
import 'package:sub_tracker/features/categories/providers/categories_provider.dart';

class CategoryFilterChips extends ConsumerWidget {
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;

  const CategoryFilterChips({super.key, this.selectedCategoryId, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(watchCategoriesProvider);

    return categoriesAsync.when(
      data: (categories) => SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('Все'),
                selected: selectedCategoryId == null,
                onSelected: (_) => onSelected(null),
              ),
            ),
            ...categories.map((cat) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(cat.name),
                selected: selectedCategoryId == cat.id,
                onSelected: (_) => onSelected(cat.id),
              ),
            )),
          ],
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
```

- [ ] **Step 5: Update SubscriptionsListScreen**

```dart
// lib/features/subscriptions/screens/subscriptions_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sub_tracker/features/subscriptions/providers/subscriptions_provider.dart';
import 'package:sub_tracker/features/subscriptions/widgets/subscription_card.dart';
import 'package:sub_tracker/features/subscriptions/widgets/total_header.dart';
import 'package:sub_tracker/features/subscriptions/widgets/category_filter_chips.dart';

class SubscriptionsListScreen extends ConsumerStatefulWidget {
  const SubscriptionsListScreen({super.key});

  @override
  ConsumerState<SubscriptionsListScreen> createState() => _SubscriptionsListScreenState();
}

class _SubscriptionsListScreenState extends ConsumerState<SubscriptionsListScreen> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final subsAsync = ref.watch(watchVisibleSubscriptionsProvider);

    return Scaffold(
      body: subsAsync.when(
        data: (subscriptions) {
          final filtered = _selectedCategoryId == null
              ? subscriptions
              : subscriptions.where((s) => s.categoryId == _selectedCategoryId).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: SafeArea(child: TotalHeader(subscriptions: subscriptions))),
              SliverToBoxAdapter(
                child: CategoryFilterChips(
                  selectedCategoryId: _selectedCategoryId,
                  onSelected: (id) => setState(() => _selectedCategoryId = id),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: filtered.isEmpty
                    ? const SliverToBoxAdapter(
                        child: Center(child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Нет подписок'),
                        )),
                      )
                    : SliverList.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) => SubscriptionCard(
                          subscription: filtered[index],
                          onTap: () {}, // TODO: navigate to detail
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {}, // TODO: navigate to add form
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

- [ ] **Step 6: Verify build**

```bash
flutter build apk --debug
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 7: Commit**

```bash
git add lib/features/subscriptions/screens/ lib/features/subscriptions/widgets/ lib/shared/widgets/
git commit -m "feat: add subscription list screen with cards, total header, and category filter"
```

---

### Task 12: Subscription form screen (add/edit + catalog picker)

**Files:**
- Create: `lib/features/subscriptions/screens/subscription_form_screen.dart`
- Create: `lib/features/subscriptions/catalog/catalog_picker.dart`
- Modify: `lib/app.dart` — add route

- [ ] **Step 1: Create CatalogPicker bottom sheet**

```dart
// lib/features/subscriptions/catalog/catalog_picker.dart
import 'package:flutter/material.dart';
import 'package:sub_tracker/features/subscriptions/catalog/catalog_data.dart';

class CatalogPicker extends StatelessWidget {
  final ValueChanged<CatalogEntry> onSelected;

  const CatalogPicker({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Выберите сервис', style: theme.textTheme.titleLarge),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: catalogData.length,
                itemBuilder: (context, index) {
                  final entry = catalogData[index];
                  return ListTile(
                    leading: Icon(Icons.subscriptions),
                    title: Text(entry.name),
                    subtitle: Text('${entry.defaultCurrency.code} · ${entry.defaultPeriod.name}'),
                    onTap: () {
                      onSelected(entry);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create SubscriptionFormScreen**

```dart
// lib/features/subscriptions/screens/subscription_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sub_tracker/core/currency/currency.dart';
import 'package:sub_tracker/features/subscriptions/models/billing_period.dart';
import 'package:sub_tracker/features/subscriptions/providers/subscriptions_provider.dart';
import 'package:sub_tracker/features/subscriptions/catalog/catalog_picker.dart';
import 'package:sub_tracker/features/subscriptions/catalog/catalog_data.dart';
import 'package:sub_tracker/features/categories/providers/categories_provider.dart';
import 'package:intl/intl.dart';

class SubscriptionFormScreen extends ConsumerStatefulWidget {
  const SubscriptionFormScreen({super.key});

  @override
  ConsumerState<SubscriptionFormScreen> createState() => _SubscriptionFormScreenState();
}

class _SubscriptionFormScreenState extends ConsumerState<SubscriptionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  Currency _currency = Currency.rub;
  BillingPeriod _period = BillingPeriod.monthly;
  DateTime _nextBillingDate = DateTime.now().add(const Duration(days: 30));
  DateTime _startDate = DateTime.now();
  String? _categoryId;
  int _reminderDays = 1;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _fillFromCatalog(CatalogEntry entry) {
    setState(() {
      _nameController.text = entry.name;
      _currency = entry.defaultCurrency;
      _period = entry.defaultPeriod;
      _categoryId = entry.categoryId;
    });
  }

  Future<void> _pickDate(bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _nextBillingDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _nextBillingDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(subscriptionsNotifierProvider.notifier).add(
      name: _nameController.text,
      amount: double.parse(_amountController.text),
      currency: _currency.code,
      billingPeriod: _period.name,
      nextBillingDate: _nextBillingDate,
      startDate: _startDate,
      categoryId: _categoryId,
      reminderDaysBefore: _reminderDays,
      note: _noteController.text.isEmpty ? null : _noteController.text,
    );

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(watchCategoriesProvider);
    final dateFormat = DateFormat('d MMMM yyyy', 'ru');

    return Scaffold(
      appBar: AppBar(title: const Text('Новая подписка')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Catalog button
            FilledButton.tonalIcon(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => CatalogPicker(onSelected: _fillFromCatalog),
              ),
              icon: const Icon(Icons.list),
              label: const Text('Выбрать из каталога'),
            ),
            const SizedBox(height: 24),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder()),
              validator: (v) => v == null || v.isEmpty ? 'Введите название' : null,
            ),
            const SizedBox(height: 16),

            // Amount + Currency
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(labelText: 'Сумма', border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Введите сумму';
                      if (double.tryParse(v) == null) return 'Некорректная сумма';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<Currency>(
                    value: _currency,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: Currency.values.map((c) => DropdownMenuItem(value: c, child: Text(c.code))).toList(),
                    onChanged: (v) => setState(() => _currency = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Billing period
            DropdownButtonFormField<BillingPeriod>(
              value: _period,
              decoration: const InputDecoration(labelText: 'Период', border: OutlineInputBorder()),
              items: BillingPeriod.values
                  .where((p) => p != BillingPeriod.custom) // custom later if needed
                  .map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(switch (p) {
                      BillingPeriod.weekly => 'Еженедельно',
                      BillingPeriod.monthly => 'Ежемесячно',
                      BillingPeriod.quarterly => 'Ежеквартально',
                      BillingPeriod.semiannual => 'Раз в полгода',
                      BillingPeriod.annual => 'Ежегодно',
                      BillingPeriod.custom => 'Произвольный',
                    }),
                  ))
                  .toList(),
              onChanged: (v) => setState(() => _period = v!),
            ),
            const SizedBox(height: 16),

            // Category
            categoriesAsync.when(
              data: (categories) => DropdownButtonFormField<String?>(
                value: _categoryId,
                decoration: const InputDecoration(labelText: 'Категория', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Другое')),
                  ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Ошибка загрузки категорий'),
            ),
            const SizedBox(height: 16),

            // Dates
            ListTile(
              title: const Text('Дата начала'),
              subtitle: Text(dateFormat.format(_startDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(true),
            ),
            ListTile(
              title: const Text('Следующее списание'),
              subtitle: Text(dateFormat.format(_nextBillingDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(false),
            ),
            const SizedBox(height: 16),

            // Reminder
            DropdownButtonFormField<int>(
              value: _reminderDays,
              decoration: const InputDecoration(labelText: 'Напоминание', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Отключено')),
                DropdownMenuItem(value: 1, child: Text('За 1 день')),
                DropdownMenuItem(value: 3, child: Text('За 3 дня')),
                DropdownMenuItem(value: 7, child: Text('За 7 дней')),
              ],
              onChanged: (v) => setState(() => _reminderDays = v!),
            ),
            const SizedBox(height: 16),

            // Note
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Заметка', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Save button
            FilledButton(
              onPressed: _save,
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}

```

- [ ] **Step 3: Add route to GoRouter in app.dart**

Add inside the first `StatefulShellBranch` (subscriptions), after the list route:

```dart
GoRoute(path: '/subscriptions/add', builder: (_, __) => const SubscriptionFormScreen()),
```

Update the FAB in `subscriptions_list_screen.dart`:

```dart
onPressed: () => context.push('/subscriptions/add'),
```

Add import:
```dart
import 'package:sub_tracker/features/subscriptions/screens/subscription_form_screen.dart';
```

- [ ] **Step 4: Verify build**

```bash
flutter build apk --debug
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 5: Commit**

```bash
git add lib/features/subscriptions/ lib/app.dart
git commit -m "feat: add subscription form screen with catalog picker"
```

---

### Task 13: Subscription detail screen (view/edit/delete)

**Files:**
- Create: `lib/features/subscriptions/screens/subscription_detail_screen.dart`
- Modify: `lib/app.dart` — add route

- [ ] **Step 1: Create detail screen**

```dart
// lib/features/subscriptions/screens/subscription_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sub_tracker/core/currency/currency.dart';
import 'package:sub_tracker/features/subscriptions/models/billing_period.dart';
import 'package:sub_tracker/features/subscriptions/providers/subscriptions_provider.dart';
import 'package:sub_tracker/shared/widgets/currency_text.dart';

class SubscriptionDetailScreen extends ConsumerWidget {
  final String subscriptionId;
  const SubscriptionDetailScreen({super.key, required this.subscriptionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subsAsync = ref.watch(watchAllSubscriptionsProvider);
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d MMMM yyyy', 'ru');

    return subsAsync.when(
      data: (subs) {
        final sub = subs.where((s) => s.id == subscriptionId).firstOrNull;
        if (sub == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Подписка не найдена')),
          );
        }

        final currency = Currency.values.byName(sub.currency.toLowerCase());
        final periodName = switch (BillingPeriod.values.byName(sub.billingPeriod)) {
          BillingPeriod.weekly => 'Еженедельно',
          BillingPeriod.monthly => 'Ежемесячно',
          BillingPeriod.quarterly => 'Ежеквартально',
          BillingPeriod.semiannual => 'Раз в полгода',
          BillingPeriod.annual => 'Ежегодно',
          BillingPeriod.custom => 'Каждые ${sub.customPeriodDays} дн.',
        };

        return Scaffold(
          appBar: AppBar(
            title: Text(sub.name),
            actions: [
              PopupMenuButton<String>(
                onSelected: (action) async {
                  switch (action) {
                    case 'pause':
                      await ref.read(subscriptionsNotifierProvider.notifier)
                          .updateStatus(sub.id, sub.status == 'paused' ? 'active' : 'paused');
                    case 'delete':
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Удалить подписку?'),
                          content: Text('${sub.name} будет удалена из списка'),
                          actions: [
                            TextButton(onPressed: () => ctx.pop(false), child: const Text('Отмена')),
                            FilledButton(onPressed: () => ctx.pop(true), child: const Text('Удалить')),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        await ref.read(subscriptionsNotifierProvider.notifier).updateStatus(sub.id, 'cancelled');
                        context.pop();
                      }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'pause',
                    child: Text(sub.status == 'paused' ? 'Возобновить' : 'Приостановить'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Удалить')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CurrencyText(
                        amount: sub.amount,
                        currency: currency,
                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(periodName, style: theme.textTheme.bodyLarge),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _InfoTile(title: 'Следующее списание', value: dateFormat.format(sub.nextBillingDate)),
              _InfoTile(title: 'Дата начала', value: dateFormat.format(sub.startDate)),
              _InfoTile(title: 'Статус', value: switch (sub.status) {
                'active' => 'Активна',
                'paused' => 'Приостановлена',
                _ => sub.status,
              }),
              if (sub.note != null && sub.note!.isNotEmpty)
                _InfoTile(title: 'Заметка', value: sub.note!),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Ошибка: $e'))),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;
  const _InfoTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: Theme.of(context).textTheme.bodySmall),
      subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}
```

- [ ] **Step 2: Add route and wire up navigation**

In `app.dart`, add route inside subscriptions branch:

```dart
GoRoute(
  path: '/subscriptions/:id',
  builder: (_, state) => SubscriptionDetailScreen(subscriptionId: state.pathParameters['id']!),
),
```

In `subscriptions_list_screen.dart`, update `onTap`:

```dart
onTap: () => context.push('/subscriptions/${filtered[index].id}'),
```

- [ ] **Step 3: Verify build**

```bash
flutter build apk --debug
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Commit**

```bash
git add lib/features/subscriptions/screens/subscription_detail_screen.dart lib/app.dart lib/features/subscriptions/screens/subscriptions_list_screen.dart
git commit -m "feat: add subscription detail screen with pause/delete actions"
```

---

### Task 14: Analytics provider and screen

**Files:**
- Create: `lib/features/analytics/providers/analytics_provider.dart`
- Create: `lib/features/analytics/widgets/monthly_bar_chart.dart`
- Create: `lib/features/analytics/widgets/category_pie_chart.dart`
- Modify: `lib/features/analytics/screens/analytics_screen.dart`
- Test: `test/features/analytics/providers/analytics_provider_test.dart`

- [ ] **Step 1: Write analytics provider test**

```dart
// test/features/analytics/providers/analytics_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sub_tracker/core/currency/currency.dart';
import 'package:sub_tracker/features/analytics/providers/analytics_provider.dart';
import 'package:sub_tracker/features/subscriptions/models/billing_period.dart';

void main() {
  group('AnalyticsCalculator', () {
    test('calculates monthly totals for past months', () {
      final now = DateTime(2026, 3, 19);
      final sub = AnalyticsSubscription(
        amount: 1000,
        currency: Currency.rub,
        billingPeriod: BillingPeriod.monthly,
        customPeriodDays: null,
        startDate: DateTime(2025, 12, 1),
        nextBillingDate: DateTime(2026, 4, 1),
        status: 'active',
        categoryId: 'cat-1',
      );

      final months = AnalyticsCalculator.monthlyTotals(
        subscriptions: [sub],
        rates: {},
        pastMonths: 3,
        futureMonths: 0,
        now: now,
      );

      // Dec, Jan, Feb, Mar — 4 months with charges of 1000 each
      expect(months.length, 3);
      expect(months.every((m) => m.amount == 1000), isTrue);
    });

    test('calculates forecast for future months', () {
      final now = DateTime(2026, 3, 19);
      final sub = AnalyticsSubscription(
        amount: 10,
        currency: Currency.usd,
        billingPeriod: BillingPeriod.monthly,
        customPeriodDays: null,
        startDate: DateTime(2026, 1, 1),
        nextBillingDate: DateTime(2026, 4, 1),
        status: 'active',
        categoryId: null,
      );

      final rates = {Currency.usd: 90.0};
      final months = AnalyticsCalculator.monthlyTotals(
        subscriptions: [sub],
        rates: rates,
        pastMonths: 0,
        futureMonths: 3,
        now: now,
      );

      expect(months.length, 3);
      expect(months.every((m) => m.isForecast), isTrue);
      expect(months.first.amount, 900.0); // 10 USD * 90
    });

    test('groups totals by category', () {
      final subs = [
        AnalyticsSubscription(amount: 500, currency: Currency.rub, billingPeriod: BillingPeriod.monthly, customPeriodDays: null, startDate: DateTime(2026, 1, 1), nextBillingDate: DateTime(2026, 4, 1), status: 'active', categoryId: 'cat-a'),
        AnalyticsSubscription(amount: 300, currency: Currency.rub, billingPeriod: BillingPeriod.monthly, customPeriodDays: null, startDate: DateTime(2026, 1, 1), nextBillingDate: DateTime(2026, 4, 1), status: 'active', categoryId: 'cat-a'),
        AnalyticsSubscription(amount: 200, currency: Currency.rub, billingPeriod: BillingPeriod.monthly, customPeriodDays: null, startDate: DateTime(2026, 1, 1), nextBillingDate: DateTime(2026, 4, 1), status: 'active', categoryId: 'cat-b'),
      ];

      final breakdown = AnalyticsCalculator.categoryBreakdown(subs, {});
      expect(breakdown['cat-a'], 800);
      expect(breakdown['cat-b'], 200);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/analytics/providers/analytics_provider_test.dart
```
Expected: FAIL.

- [ ] **Step 3: Create analytics provider with calculator**

```dart
// lib/features/analytics/providers/analytics_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sub_tracker/core/currency/currency.dart';
import 'package:sub_tracker/core/currency/exchange_rate_service.dart';
import 'package:sub_tracker/features/subscriptions/models/billing_period.dart';

part 'analytics_provider.g.dart';

class AnalyticsSubscription {
  final double amount;
  final Currency currency;
  final BillingPeriod billingPeriod;
  final int? customPeriodDays;
  final DateTime startDate;
  final DateTime nextBillingDate;
  final String status;
  final String? categoryId;

  const AnalyticsSubscription({
    required this.amount,
    required this.currency,
    required this.billingPeriod,
    required this.customPeriodDays,
    required this.startDate,
    required this.nextBillingDate,
    required this.status,
    required this.categoryId,
  });
}

class MonthlyTotal {
  final DateTime month; // first day of month
  final double amount; // in RUB
  final bool isForecast;

  const MonthlyTotal({required this.month, required this.amount, required this.isForecast});
}

class AnalyticsCalculator {
  /// Returns monthly totals in RUB for [pastMonths] back and [futureMonths] forward.
  static List<MonthlyTotal> monthlyTotals({
    required List<AnalyticsSubscription> subscriptions,
    required Map<Currency, double> rates,
    required int pastMonths,
    required int futureMonths,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final results = <MonthlyTotal>[];

    for (int offset = -pastMonths; offset < futureMonths; offset++) {
      final monthStart = DateTime(today.year, today.month + offset, 1);
      final monthEnd = DateTime(today.year, today.month + offset + 1, 0);
      final isForecast = offset >= 0;

      double total = 0;
      for (final sub in subscriptions) {
        if (sub.status != 'active') continue;

        // Generate all billing dates that fall in this month
        var date = sub.startDate;
        while (date.isBefore(monthEnd) || date.isAtSameMomentAs(monthEnd)) {
          if (!date.isBefore(monthStart) && !date.isAfter(monthEnd)) {
            total += ExchangeRateService.convertToRub(sub.amount, sub.currency, rates);
          }
          date = sub.billingPeriod == BillingPeriod.custom
              ? sub.billingPeriod.nextDateCustom(date, sub.customPeriodDays ?? 30)
              : sub.billingPeriod.nextDate(date);
          if (date.isAfter(monthEnd)) break;
        }
      }

      results.add(MonthlyTotal(month: monthStart, amount: total, isForecast: isForecast));
    }

    return results;
  }

  /// Returns monthly amount in RUB per categoryId for active subscriptions.
  static Map<String?, double> categoryBreakdown(
    List<AnalyticsSubscription> subscriptions,
    Map<Currency, double> rates,
  ) {
    final result = <String?, double>{};
    for (final sub in subscriptions) {
      if (sub.status != 'active') continue;
      final monthlyAmount = sub.amount * sub.billingPeriod.monthlyEquivalent;
      final rubAmount = ExchangeRateService.convertToRub(monthlyAmount, sub.currency, rates);
      result[sub.categoryId] = (result[sub.categoryId] ?? 0) + rubAmount;
    }
    return result;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/features/analytics/providers/analytics_provider_test.dart
```
Expected: All tests PASS.

- [ ] **Step 5: Create MonthlyBarChart widget**

```dart
// lib/features/analytics/widgets/monthly_bar_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:sub_tracker/features/analytics/providers/analytics_provider.dart';
import 'package:intl/intl.dart';

class MonthlyBarChart extends StatelessWidget {
  final List<MonthlyTotal> data;

  const MonthlyBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) return const SizedBox.shrink();

    final maxY = data.map((d) => d.amount).reduce((a, b) => a > b ? a : b) * 1.2;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barGroups: data.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: d.amount,
                  color: d.isForecast
                      ? theme.colorScheme.primary.withValues(alpha: 0.3)
                      : theme.colorScheme.primary,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  borderDashArray: d.isForecast ? [4, 4] : null,
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                  return Text(
                    DateFormat('MMM', 'ru').format(data[idx].month),
                    style: theme.textTheme.bodySmall,
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Create CategoryPieChart widget**

```dart
// lib/features/analytics/widgets/category_pie_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CategoryPieChart extends StatelessWidget {
  final Map<String, double> data; // categoryName -> amount
  final Map<String, int> colors; // categoryName -> color

  const CategoryPieChart({super.key, required this.data, required this.colors});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) return const Center(child: Text('Нет данных'));

    final total = data.values.fold(0.0, (a, b) => a + b);
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: PieChart(
            PieChartData(
              sections: entries.map((e) {
                final color = Color(colors[e.key] ?? 0xFF9E9E9E);
                return PieChartSectionData(
                  value: e.value,
                  color: color,
                  radius: 24,
                  showTitle: false,
                );
              }).toList(),
              centerSpaceRadius: 30,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: entries.map((e) {
              final pct = (e.value / total * 100).toStringAsFixed(0);
              final color = Color(colors[e.key] ?? 0xFF9E9E9E);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.key, style: theme.textTheme.bodySmall)),
                    Text('$pct%', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 7: Update AnalyticsScreen**

```dart
// lib/features/analytics/screens/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sub_tracker/core/currency/currency.dart';
import 'package:sub_tracker/core/currency/exchange_rate_provider.dart';
import 'package:sub_tracker/core/database/database_provider.dart';
import 'package:sub_tracker/features/analytics/providers/analytics_provider.dart';
import 'package:sub_tracker/features/analytics/widgets/monthly_bar_chart.dart';
import 'package:sub_tracker/features/analytics/widgets/category_pie_chart.dart';
import 'package:sub_tracker/features/categories/providers/categories_provider.dart';
import 'package:sub_tracker/features/subscriptions/models/billing_period.dart';
import 'package:sub_tracker/features/subscriptions/providers/subscriptions_provider.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subsAsync = ref.watch(watchAllSubscriptionsProvider);
    final ratesAsync = ref.watch(exchangeRatesProvider);
    final categoriesAsync = ref.watch(watchCategoriesProvider);

    return Scaffold(
      body: SafeArea(
        child: subsAsync.when(
          data: (dbSubs) => ratesAsync.when(
            data: (rates) => categoriesAsync.when(
              data: (categories) {
                final subs = dbSubs
                    .where((s) => s.status == 'active')
                    .map((s) => AnalyticsSubscription(
                      amount: s.amount,
                      currency: Currency.values.byName(s.currency.toLowerCase()),
                      billingPeriod: BillingPeriod.values.byName(s.billingPeriod),
                      customPeriodDays: s.customPeriodDays,
                      startDate: s.startDate,
                      nextBillingDate: s.nextBillingDate,
                      status: s.status,
                      categoryId: s.categoryId,
                    ))
                    .toList();

                final monthlyData = AnalyticsCalculator.monthlyTotals(
                  subscriptions: subs,
                  rates: rates,
                  pastMonths: 6,
                  futureMonths: 6,
                );

                final categoryBreakdown = AnalyticsCalculator.categoryBreakdown(subs, rates);
                final catMap = {for (final c in categories) c.id: c};
                final namedBreakdown = <String, double>{};
                final colorMap = <String, int>{};
                for (final entry in categoryBreakdown.entries) {
                  final cat = entry.key != null ? catMap[entry.key] : null;
                  final name = cat?.name ?? 'Другое';
                  namedBreakdown[name] = (namedBreakdown[name] ?? 0) + entry.value;
                  colorMap[name] = cat?.color ?? 0xFF9E9E9E;
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Аналитика', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 24),
                    Text('Расходы по месяцам', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    MonthlyBarChart(data: monthlyData),
                    const SizedBox(height: 32),
                    Text('По категориям', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    CategoryPieChart(data: namedBreakdown, colors: colorMap),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
        ),
      ),
    );
  }
}
```

- [ ] **Step 8: Run code generation and verify build**

```bash
dart run build_runner build --delete-conflicting-outputs && flutter build apk --debug
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 9: Commit**

```bash
git add lib/features/analytics/ test/features/analytics/
git commit -m "feat: add analytics screen with bar chart, forecast, and category pie chart"
```

---

### Task 15: Notification service

**Files:**
- Create: `lib/core/notifications/notification_service.dart`
- Modify: `lib/main.dart` — init notifications

- [ ] **Step 1: Create NotificationService**

```dart
// lib/core/notifications/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static void Function(String? payload)? onNotificationTap;

  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response.payload);
      },
    );
  }

  static Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    final scheduled = tz.TZDateTime(
      tz.local,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      hour,
      minute,
    );

    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'subscription_reminders',
          'Напоминания о подписках',
          channelDescription: 'Напоминания о предстоящих списаниях',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  static Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
```

- [ ] **Step 2: Update main.dart to init notifications**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sub_tracker/app.dart';
import 'package:sub_tracker/core/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const ProviderScope(child: SubTrackerApp()));
}
```

- [ ] **Step 3: Verify build**

```bash
flutter build apk --debug
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Commit**

```bash
git add lib/core/notifications/ lib/main.dart
git commit -m "feat: add notification service for subscription reminders"
```

---

### Task 16: Settings screen (theme, categories, notifications)

**Files:**
- Create: `lib/features/settings/providers/settings_provider.dart`
- Create: `lib/features/categories/widgets/category_list_tile.dart`
- Modify: `lib/features/settings/screens/settings_screen.dart`

- [ ] **Step 1: Create settings provider**

```dart
// lib/features/settings/providers/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sub_tracker/core/notifications/notification_service.dart';

part 'settings_provider.g.dart';

@riverpod
class ThemeModeNotifier extends _$ThemeModeNotifier {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value != null) {
      state = ThemeMode.values.byName(value);
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

@riverpod
class RemindersEnabledNotifier extends _$RemindersEnabledNotifier {
  static const _key = 'reminders_enabled';

  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
    if (!state) {
      await NotificationService.cancelAll();
    }
  }
}

@riverpod
class ReminderTimeNotifier extends _$ReminderTimeNotifier {
  static const _hourKey = 'reminder_hour';
  static const _minuteKey = 'reminder_minute';

  @override
  TimeOfDay build() {
    _load();
    return const TimeOfDay(hour: 10, minute: 0);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_hourKey);
    final minute = prefs.getInt(_minuteKey);
    if (hour != null) {
      state = TimeOfDay(hour: hour, minute: minute ?? 0);
    }
  }

  Future<void> set(TimeOfDay time) async {
    state = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hourKey, time.hour);
    await prefs.setInt(_minuteKey, time.minute);
  }
}
```

- [ ] **Step 2: Create CategoryListTile widget**

```dart
// lib/features/categories/widgets/category_list_tile.dart
import 'package:flutter/material.dart';
import 'package:sub_tracker/core/database/app_database.dart' as db;

class CategoryListTile extends StatelessWidget {
  final db.Category category;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CategoryListTile({super.key, required this.category, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Color(category.color),
        child: Icon(Icons.category, color: Colors.white, size: 18),
      ),
      title: Text(category.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null) IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
          if (onDelete != null) IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Update SettingsScreen**

```dart
// lib/features/settings/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sub_tracker/core/database/database_provider.dart';
import 'package:sub_tracker/features/categories/providers/categories_provider.dart';
import 'package:sub_tracker/features/categories/widgets/category_list_tile.dart';
import 'package:sub_tracker/features/settings/providers/settings_provider.dart';
import 'package:sub_tracker/features/settings/widgets/export_import_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeNotifierProvider);
    final remindersEnabled = ref.watch(remindersEnabledNotifierProvider);
    final categoriesAsync = ref.watch(watchCategoriesProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Настройки', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 24),

            // Theme
            Text('Оформление', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Авто')),
                ButtonSegment(value: ThemeMode.light, label: Text('Светлая')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Тёмная')),
              ],
              selected: {themeMode},
              onSelectionChanged: (s) => ref.read(themeModeNotifierProvider.notifier).set(s.first),
            ),
            const SizedBox(height: 24),

            // Notifications
            Text('Уведомления', style: theme.textTheme.titleMedium),
            SwitchListTile(
              title: const Text('Напоминания о списаниях'),
              value: remindersEnabled,
              onChanged: (_) => ref.read(remindersEnabledNotifierProvider.notifier).toggle(),
            ),
            const SizedBox(height: 24),

            // Categories
            Text('Категории', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            categoriesAsync.when(
              data: (categories) => Column(
                children: [
                  ...categories.map((cat) => CategoryListTile(
                    category: cat,
                    onDelete: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Удалить категорию?'),
                          content: Text(cat.name),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        ref.read(categoriesNotifierProvider.notifier).remove(cat.id);
                      }
                    },
                  )),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Добавить категорию'),
                    onTap: () => _showAddCategoryDialog(context, ref),
                  ),
                ],
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
            const SizedBox(height: 24),

            // Export/Import placeholder
            Text('Данные', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.upload_outlined),
              title: const Text('Экспорт'),
              onTap: () {}, // Task 17
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Импорт'),
              onTap: () => ExportImportHelper.importFile(context, ref.read(databaseProvider)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая категория'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Название'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                ref.read(categoriesNotifierProvider.notifier).add(
                  name: nameController.text,
                  color: 0xFF9E9E9E,
                  icon: 'category',
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run code generation and verify build**

```bash
dart run build_runner build --delete-conflicting-outputs && flutter build apk --debug
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/ lib/features/categories/widgets/
git commit -m "feat: add settings screen with theme, notifications, and category management"
```

---

### Task 17: Export/Import

**Files:**
- Create: `lib/features/settings/widgets/export_import_section.dart`
- Test: `test/features/settings/export_import_test.dart`

- [ ] **Step 1: Write export/import test**

```dart
// test/features/settings/export_import_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sub_tracker/features/settings/widgets/export_import_section.dart';

void main() {
  group('BackupData', () {
    test('serializes and deserializes round-trip', () {
      final backup = BackupData(
        version: 1,
        exportedAt: DateTime(2026, 3, 19),
        subscriptions: [
          {'id': 'sub-1', 'name': 'Netflix', 'amount': 22.99},
        ],
        categories: [
          {'id': 'cat-1', 'name': 'Стриминг', 'color': 0xFF7C4DFF, 'icon': 'movie'},
        ],
        settings: {'reminderTime': '10:00'},
      );

      final json = jsonEncode(backup.toJson());
      final restored = BackupData.fromJson(jsonDecode(json));

      expect(restored.version, 1);
      expect(restored.subscriptions.length, 1);
      expect(restored.categories.length, 1);
      expect(restored.subscriptions.first['name'], 'Netflix');
    });

    test('rejects unknown version', () {
      final json = {'version': 999, 'exportedAt': '2026-03-19', 'subscriptions': [], 'categories': [], 'settings': {}};
      expect(() => BackupData.fromJson(json), throwsFormatException);
    });
  });

  group('CsvExporter', () {
    test('generates CSV with header and rows', () {
      final subs = [
        {'name': 'Netflix', 'amount': '22.99', 'currency': 'USD', 'billingPeriod': 'monthly'},
        {'name': 'МТС', 'amount': '890', 'currency': 'RUB', 'billingPeriod': 'monthly'},
      ];
      final csv = CsvExporter.generate(subs);
      final lines = csv.split('\n');
      expect(lines.first, contains('name'));
      expect(lines.length, 3); // header + 2 rows
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/settings/export_import_test.dart
```
Expected: FAIL.

- [ ] **Step 3: Create export/import logic**

```dart
// lib/features/settings/widgets/export_import_section.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:sub_tracker/core/database/app_database.dart';
import 'package:sub_tracker/core/database/database_provider.dart';

class BackupData {
  final int version;
  final DateTime exportedAt;
  final List<Map<String, dynamic>> subscriptions;
  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic> settings;

  BackupData({
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
    final version = json['version'] as int;
    if (version > 1) throw const FormatException('Неизвестная версия формата. Обновите приложение.');
    return BackupData(
      version: version,
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      subscriptions: List<Map<String, dynamic>>.from(json['subscriptions']),
      categories: List<Map<String, dynamic>>.from(json['categories']),
      settings: Map<String, dynamic>.from(json['settings']),
    );
  }
}

class CsvExporter {
  static String generate(List<Map<String, dynamic>> subscriptions) {
    if (subscriptions.isEmpty) return '';
    final headers = subscriptions.first.keys.join(',');
    final rows = subscriptions.map((s) => s.values.map((v) => '"$v"').join(',')).join('\n');
    return '$headers\n$rows';
  }
}

class ExportImportHelper {
  static Future<void> exportJson(AppDatabase db) async {
    final subs = await db.select(db.subscriptions).get();
    final cats = await db.select(db.categories).get();

    final backup = BackupData(
      version: 1,
      exportedAt: DateTime.now(),
      subscriptions: subs.map((s) => {
        'id': s.id, 'name': s.name, 'icon': s.icon, 'amount': s.amount,
        'currency': s.currency, 'billingPeriod': s.billingPeriod,
        'customPeriodDays': s.customPeriodDays, 'categoryId': s.categoryId,
        'nextBillingDate': s.nextBillingDate.toIso8601String(),
        'reminderDaysBefore': s.reminderDaysBefore, 'status': s.status,
        'startDate': s.startDate.toIso8601String(), 'note': s.note,
        'createdAt': s.createdAt.toIso8601String(),
      }).toList(),
      categories: cats.map((c) => {
        'id': c.id, 'name': c.name, 'color': c.color, 'icon': c.icon,
      }).toList(),
      settings: {},
    );

    final json = const JsonEncoder.withIndent('  ').convert(backup.toJson());
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/subtracker-backup-$date.json');
    await file.writeAsString(json);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  static Future<void> exportCsv(AppDatabase db) async {
    final subs = await db.select(db.subscriptions).get();
    final rows = subs.map((s) => {
      'name': s.name, 'amount': s.amount.toString(), 'currency': s.currency,
      'billingPeriod': s.billingPeriod, 'nextBillingDate': s.nextBillingDate.toIso8601String(),
      'status': s.status,
    }).toList();

    final csv = CsvExporter.generate(rows);
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/subtracker-$date.csv');
    await file.writeAsString(csv);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  static Future<String> importJson(AppDatabase db, String jsonString) async {
    final data = BackupData.fromJson(jsonDecode(jsonString));
    return data.toString(); // returns parsed data for merge/replace decision
  }

  static Future<void> importJsonReplace(AppDatabase db, String jsonString) async {
    final data = BackupData.fromJson(jsonDecode(jsonString));

    // Clear existing data
    await db.delete(db.subscriptions).go();
    await db.delete(db.categories).go();

    // Insert categories
    for (final cat in data.categories) {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: cat['id'] as String,
        name: cat['name'] as String,
        color: cat['color'] as int,
        icon: cat['icon'] as String,
      ));
    }

    // Insert subscriptions
    for (final sub in data.subscriptions) {
      await db.into(db.subscriptions).insert(SubscriptionsCompanion.insert(
        id: sub['id'] as String,
        name: sub['name'] as String,
        amount: (sub['amount'] as num).toDouble(),
        currency: sub['currency'] as String,
        billingPeriod: sub['billingPeriod'] as String,
        nextBillingDate: DateTime.parse(sub['nextBillingDate'] as String),
        startDate: DateTime.parse(sub['startDate'] as String),
        createdAt: DateTime.parse(sub['createdAt'] as String),
      ));
    }
  }

  static Future<void> importJsonMerge(AppDatabase db, String jsonString) async {
    final data = BackupData.fromJson(jsonDecode(jsonString));

    // Upsert categories
    for (final cat in data.categories) {
      await db.into(db.categories).insertOnConflictUpdate(CategoriesCompanion.insert(
        id: cat['id'] as String,
        name: cat['name'] as String,
        color: cat['color'] as int,
        icon: cat['icon'] as String,
      ));
    }

    // Upsert subscriptions (imported wins on conflict)
    for (final sub in data.subscriptions) {
      await db.into(db.subscriptions).insertOnConflictUpdate(SubscriptionsCompanion.insert(
        id: sub['id'] as String,
        name: sub['name'] as String,
        amount: (sub['amount'] as num).toDouble(),
        currency: sub['currency'] as String,
        billingPeriod: sub['billingPeriod'] as String,
        nextBillingDate: DateTime.parse(sub['nextBillingDate'] as String),
        startDate: DateTime.parse(sub['startDate'] as String),
        createdAt: DateTime.parse(sub['createdAt'] as String),
      ));
    }
  }

  static Future<void> importCsv(AppDatabase db, String csvContent) async {
    final lines = csvContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) return;

    final headers = lines.first.split(',').map((h) => h.replaceAll('"', '').trim()).toList();
    final nameIdx = headers.indexOf('name');
    final amountIdx = headers.indexOf('amount');
    final currencyIdx = headers.indexOf('currency');
    final periodIdx = headers.indexOf('billingPeriod');
    final dateIdx = headers.indexOf('nextBillingDate');

    if (nameIdx == -1 || amountIdx == -1) return;

    for (final line in lines.skip(1)) {
      final cols = line.split(',').map((c) => c.replaceAll('"', '').trim()).toList();
      if (cols.length <= nameIdx) continue;

      final name = cols[nameIdx];
      final amount = double.tryParse(cols[amountIdx]) ?? 0;
      final currency = currencyIdx >= 0 && cols.length > currencyIdx ? cols[currencyIdx] : 'RUB';
      final period = periodIdx >= 0 && cols.length > periodIdx ? cols[periodIdx] : 'monthly';
      final nextDate = dateIdx >= 0 && cols.length > dateIdx
          ? (DateTime.tryParse(cols[dateIdx]) ?? DateTime.now().add(const Duration(days: 30)))
          : DateTime.now().add(const Duration(days: 30));

      await db.into(db.subscriptions).insert(SubscriptionsCompanion.insert(
        id: const Uuid().v4(),
        name: name,
        amount: amount,
        currency: currency,
        billingPeriod: period,
        nextBillingDate: nextDate,
        startDate: DateTime.now(),
        createdAt: DateTime.now(),
      ));
    }
  }

  static Future<void> importFile(BuildContext context, AppDatabase db) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'csv'],
    );
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final isJson = file.path.endsWith('.json');

    if (!context.mounted) return;

    try {
      if (isJson) {
        final action = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Импорт данных'),
            content: const Text('Заменить все данные или объединить с существующими?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
              TextButton(onPressed: () => Navigator.pop(ctx, 'merge'), child: const Text('Объединить')),
              FilledButton(onPressed: () => Navigator.pop(ctx, 'replace'), child: const Text('Заменить')),
            ],
          ),
        );
        if (action == null) return;
        if (action == 'replace') {
          await importJsonReplace(db, content);
        } else {
          await importJsonMerge(db, content);
        }
      } else {
        await importCsv(db, content);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Импорт завершён')));
      }
    } on FormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/features/settings/export_import_test.dart
```
Expected: All tests PASS.

- [ ] **Step 5: Wire up export/import buttons in settings_screen.dart**

Update the export/import ListTile `onTap` callbacks:

```dart
// Export
onTap: () => showModalBottomSheet(
  context: context,
  builder: (ctx) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: const Text('JSON (полный бэкап)'),
          onTap: () {
            Navigator.pop(ctx);
            ExportImportHelper.exportJson(ref.read(databaseProvider));
          },
        ),
        ListTile(
          title: const Text('CSV (таблица)'),
          onTap: () {
            Navigator.pop(ctx);
            ExportImportHelper.exportCsv(ref.read(databaseProvider));
          },
        ),
      ],
    ),
  ),
),
```

- [ ] **Step 6: Verify build**

```bash
flutter build apk --debug
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 7: Commit**

```bash
git add lib/features/settings/ test/features/settings/
git commit -m "feat: add JSON/CSV export and import"
```

---

### Task 18: Wire up main.dart with database provider + billing date advancement

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Update main.dart**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sub_tracker/app.dart';
import 'package:sub_tracker/core/database/database_provider.dart';
import 'package:sub_tracker/core/notifications/notification_service.dart';
import 'package:sub_tracker/features/subscriptions/providers/subscriptions_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  await NotificationService.init();
  final db = await createDatabase();

  // Advance past billing dates and reschedule notifications
  await SubscriptionsNotifier.advanceBillingDatesOnDb(db);

  runApp(ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: const SubTrackerApp(),
  ));
}
```

- [ ] **Step 2: Verify build**

```bash
flutter build apk --debug
```
Expected: BUILD SUCCESSFUL.

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wire up database provider and locale initialization in main"
```

---

### Task 19: End-to-end smoke test

**Files:**
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Write basic smoke test**

```dart
// test/widget_test.dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sub_tracker/app.dart';
import 'package:sub_tracker/core/database/app_database.dart';
import 'package:sub_tracker/core/database/database_provider.dart';

void main() {
  testWidgets('App launches and shows bottom navigation', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const SubTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Подписки'), findsOneWidget);
    expect(find.text('Аналитика'), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);

    await db.close();
  });
}
```

- [ ] **Step 2: Run all tests**

```bash
flutter test
```
Expected: All tests PASS.

- [ ] **Step 3: Commit**

```bash
git add test/widget_test.dart
git commit -m "test: add end-to-end smoke test for app launch"
```

---

### Task 20: CLAUDE.md and .gitignore

**Files:**
- Create: `CLAUDE.md`
- Create/Modify: `.gitignore`

- [ ] **Step 1: Add .superpowers to .gitignore**

Append to `.gitignore`:
```
.superpowers/
```

- [ ] **Step 2: Create CLAUDE.md**

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

SubTracker — Flutter Android app for tracking recurring subscriptions with multi-currency support, analytics, and notifications.

## Build & Run

```bash
flutter pub get                    # install dependencies
dart run build_runner build --delete-conflicting-outputs  # code generation (Drift, freezed, Riverpod)
flutter build apk --debug         # build debug APK
flutter run                       # run on connected device/emulator
flutter test                      # run all tests
flutter test test/path/to_test.dart  # run single test file
```

Always run `build_runner` after modifying files with `part` directives (models, database, providers).

## Architecture

Feature-first + Riverpod. Code in `lib/features/{feature}/` with models/providers/screens/widgets. Core services in `lib/core/`.

- **State management**: Riverpod with code generation (`@riverpod` annotation)
- **Database**: Drift (SQLite) — schema in `lib/core/database/app_database.dart`
- **Models**: freezed + json_serializable — immutable, with `.freezed.dart` and `.g.dart` generated files
- **Navigation**: go_router with StatefulShellRoute for bottom nav
- **Theme**: Material 3 with dynamic_color

## Key Conventions

- Enums for Currency, BillingPeriod, SubscriptionStatus — not strings in app logic (strings only in DB layer)
- Exchange rates fetched from CBR XML API, cached locally, fallback hardcoded rates
- Subscription soft-delete: status changes to `cancelled`, row stays in DB for analytics
- Russian-only UI, no l10n
- All amounts displayed in original currency + RUB equivalent
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md .gitignore
git commit -m "docs: add CLAUDE.md and update .gitignore"
```
