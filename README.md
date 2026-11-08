# Кипер

Приложение для учёта подписок. Нативные порты по платформам:

| Папка | Платформа | Стек |
|---|---|---|
| [`ios-native/`](ios-native/) | iOS | SwiftUI, iOS 26 |
| [`android-native/`](android-native/) | Android | Kotlin + Jetpack Compose, minSdk 26 |
| [`web-native/`](web-native/) | Web | Next.js + TypeScript |

**Кросс-платформенный контракт** — формат бэкапа JSON v1: файл экспорта из одного
приложения импортируется в любое другое без потерь (подписки, категории,
история платежей, триалы, бюджет). Детали в `android-native/README.md` и
`ios-native/README.md`.

Брендовый логотип: `logo_rounded.png` / `logo_rounded.svg` (источник иконок всех платформ).
