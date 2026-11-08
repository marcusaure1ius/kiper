# Кипер для Android (нативный)

Нативный Android-порт Кипера: **Kotlin 2.0 + Jetpack Compose**, Material 3,Glance-виджеты. Зеркалирует функциональность `../ios-native/` — тот же домен, тот же формат данных.

- **applicationId:** `ru.kiper.android`
- **minSdk 26** (Android 8.0), **target/compileSdk 35**
- Требуется **JDK 17+** и Android SDK (platform 35, build-tools 35)

## Сборка и запуск

```bash
cd android-native
# один раз: указать путь к SDK (или задать ANDROID_HOME)
echo "sdk.dir=/path/to/android-sdk" > local.properties

./gradlew :app:assembleDebug          # APK → app/build/outputs/apk/debug/
./gradlew :app:testDebugUnitTest      # юнит-тесты домена
./gradlew :app:installDebug           # установка на подключённое устройство/эмулятор
```

Установка конкретного APK на телефон:

```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

## Структура

```
app/src/main/kotlin/ru/kiper/android/
├── data/          # домен: Models, Schedule, Backup+CSV, AppStore,
│                  # StatementImport, ExchangeRates, Ics, AutoBackup,
│                  # Reminders, WidgetSnapshot, Persistence, SeedData, Catalog
├── notifications/ # AlarmManager-напоминания, BootReceiver
├── widgets/       # Glance-виджеты «Ближайшее списание» и «Месяц»
├── ui/            # Compose: theme (6 палитр), home, subs, analytics, settings
├── LockPolicy.kt  # логика био-замка (BiometricPrompt в MainActivity)
├── MainActivity.kt
└── KiperApp.kt    # Application + синглтон AppStore
```

## Кросс-платформенный контракт

Формат бэкапа **JSON v1** (`data/Backup.kt`) байт-совместим с iOS (`ios-native/Kiper/Data/Backup.swift`) и Flutter (`lib/`): поля `subscriptions/categories/settings/payments`, локальные даты `yyyy-MM-dd'T'HH:mm:ss.SSS`, ARGB-цвета, `PaymentRecord.id = subscriptionId-yyyy-MM-dd`. Файлы экспорта/импорта ходят между всеми тремя платформами без потерь.

## Особенности

- **Хранение:** один `kiper.json` в filesDir (атомарная запись), формат = бэкап
- **Виджеты** читают `widget-snapshot.json` (схема = `WidgetSnapshot.swift`); метадате виджета обязателен `android:initialLayout="@layout/glance_default_loading_layout"`
- **Напоминания:** AlarmManager (`setExactAndAllowWhileIdle`, откат к inexact без разрешения), полный rebuild набора при каждом изменении, BootReceiver перевзводит после ребута
- **Палитры:** 6 штук (лаванда/аврора/закат/океан/графит/ирис) — акцент светлая/тёмная тема применяются мгновенно (реактивное состояние в AppStore)
- **Без облака:** вместо CloudKit — экспорт/импорт файла и авто-бэкап в SAF-папку

## Отличия от iOS-версии

- Нет CloudKit-синхронизации (на Android нет CloudKit); контракт — файл бэкапа
- Вместо Face ID — BiometricPrompt (`FragmentActivity`-требование)
- Свайп-действия истории платежей заменены на диалог по тапу по строке
