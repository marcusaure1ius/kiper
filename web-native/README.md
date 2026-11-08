# Кипер для веб (`web-native`)

Веб-версия приложения «Кипер» (учёт подписок) — четвёртый клиент рядом с
`ios-native` и `android-native`. Мобильная версия — точная копия iOS-приложения
(Liquid Glass, анимированный меш-фон, нижний таб-бар); на десктопе ≥900 px —
сайдбар и контент в две колонки.

## Стек

- Next.js 15 (App Router) + TypeScript + Tailwind CSS 4
- zustand-стор, вся логика — чистый TS-порт `ios-native/Kiper`:
  - `src/lib/schedule.ts` ← `Data/Schedule.swift` (anchor + n × период, кламп дня 31→28/29)
  - `src/lib/backup.ts` ← `Data/Backup.swift` (**формат бэкапа v1**, совместим с iOS/Android в обе стороны)
  - `src/lib/store.ts` ← `Data/AppStore.swift` (мутации, advanceBillingDates, аналитика)
  - `src/lib/format.ts` ← `Shared/Formatting.swift` (ru_RU деньги/даты/плюрализмы)
  - `src/lib/palette.ts` ← `Shared/Background.swift` (6 палитр, точные hex мешей)
- Иконки: Phosphor (маппинг SF Symbols → Phosphor в `src/components/Sym.tsx`)
- Данные: localStorage (`kiper.data.v1` — тот же JSON, что и экспорт)
- Курсы: `/api/rates` — серверный прокси ЦБ РФ (XML, кэш 6 ч) с зеркалом
  `cbr-xml-daily.ru` как резервом; фолбэк 90 $/98 €

## Запуск

```bash
cd web-native
npm install
npm run dev        # http://localhost:3000
npm test           # vitest: schedule/backup/csv/format (32 теста)
npm run build      # прод-сборка
```

В dev-сборке доступен хук `window.__kiperDemo()` в консоли браузера — загружает
демо-данные (16 подписок + триал + пауза).

## Деплой на Vercel

1. Импортируйте репозиторий в Vercel (New Project → Git).
2. **Root Directory**: `web-native` — Vercel сам определит Next.js.
3. Ничего больше настраивать не нужно: нет переменных окружения и базы;
   данные пользователей живут в их браузерах, `/api/rates` — serverless-функция.

Или через CLI:

```bash
npm i -g vercel
cd web-native
vercel            # превью
vercel --prod     # продакшен
```

## Что есть / чего нет

Есть: подписки (каталог 18 сервисов, триал, пауза, отмена), история платежей
(авто-бэкфилл, отметка оплат/пропусков), бюджет месяца, аналитика (график
месяц/неделя, кольца категорий, месяц-к-месяцу, годовой прогноз, дубликаты),
курсы ЦБ, темы (авто/светлая/тёмная), 6 палитр, редактор категорий,
экспорт JSON/CSV/.ics, импорт JSON/CSV, PWA-манифест.

Нет (iOS-only): Face ID, локальные напоминания, автокопия в Files,
iCloud/CloudKit, импорт банковской выписки. Облако — следующая итерация;
перенос данных между устройствами — через «Экспорт в JSON»/«Импорт из файла»
в Настройках.
