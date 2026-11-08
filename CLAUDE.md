# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Кипер (Kiper) — subscription tracker with multi-currency support, analytics and notifications. **One product, three native apps** — no shared code, only a shared file-format contract:

| Folder | Platform | Stack |
|---|---|---|
| `android-native/` | Android | Kotlin 2.0 + Jetpack Compose, Glance widgets, minSdk 26 |
| `ios-native/` | iOS | SwiftUI (iOS 26, Liquid Glass), no dependencies |
| `web-native/` | Web | Next.js + TypeScript |

`logo_rounded.png` / `logo_rounded.svg` — brand logo, source for every platform's icon.

## Build & Run

```bash
# Android (JDK 17+, Android SDK 35; sdk.dir in android-native/local.properties)
cd android-native
./gradlew :app:assembleDebug        # APK → app/build/outputs/apk/debug/
./gradlew :app:testDebugUnitTest    # domain unit tests
./gradlew :app:installDebug         # install on connected device

# iOS (folder-synchronized groups: new files need no pbxproj edits)
cd ios-native
xcodebuild -project Kiper.xcodeproj -scheme Kiper -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project Kiper.xcodeproj -scheme Kiper -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Web
cd web-native && npm run dev
```

## Cross-platform contract (do not break)

The **backup JSON v1** format is the only link between platforms — an export from one app imports into any other losslessly:

- Roots: `version`, `exportedAt`, `subscriptions[]`, `categories[]`, `settings{budgetRub}`, `payments[]`
- Dates are **local** ISO strings `yyyy-MM-dd'T'HH:mm:ss.SSS` (no zone); a bare `yyyy-MM-dd` is also valid. Only zone-suffixed strings are instants
- Category color = ARGB int (`0xFF7C4DFF` = 4286336511); icon field stores SF Symbol names (iOS) — Android maps them to Material icons via `IconMap`
- `PaymentRecord.id = subscriptionId-yyyy-MM-dd` — stable key across devices; derived, never stored
- Android: `data/Backup.kt`; iOS: `Kiper/Data/Backup.swift`. Fix both sides together
- Category deletion must null `categoryId` on subscriptions first (all platforms)
- Subscription soft-delete: status → `cancelled`, row stays for analytics

## Shared conventions

- Russian-only UI, no l10n; money/dates/plurals via `Fmt` (`data/Fmt.kt` / `Kiper/Shared/Formatting.swift`)
- Amounts always shown in original currency + RUB equivalent
- Rates from CBR XML (`https://www.cbr.ru/scripts/XML_daily.asp`, windows-1251, decimal comma, `Nominal`-aware), cached ≤6 h, fallback USD 90 / EUR 98
- 6 background palettes (lavender/aurora/sunset/ocean/graphite/iris), each with light/dark accent — theme via reactive state, never hardcode an accent color
- Demo seed data on first launch in debug builds only
- Trials: status `trial` + `trialEndDate`; when the end passes, the app activates the subscription and starts paid history at the (old) `nextBillingDate` — trial days never produce phantom charges

## Android specifics (`android-native/`)

- State: singleton `AppStore` with Compose snapshot state; one `kiper.json` in filesDir (same format as backups), atomic write on every change
- Widgets (Glance) read `widget-snapshot.json` from filesDir — schema mirrors `KiperShared/WidgetSnapshot.swift`; widget metadata **must** keep `android:initialLayout="@layout/glance_default_loading_layout"` or the launcher silently drops the provider
- Reminders: full rebuild via `Reminders.plan()` (≤60, ≤3 per subscription) on every store change; AlarmManager exact-alarms with inexact fallback; `BootReceiver` re-arms after reboot
- No cloud sync — exports/imports + SAF-folder auto-backup play that role
