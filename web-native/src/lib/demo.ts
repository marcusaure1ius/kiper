// Development-only demo data (mirrors ios SeedData.subscriptions) so the UI can
// be exercised without importing a backup by hand. Never shipped to production.

import { addDays, startOfDay } from "./date";
import { BackupFileV1 } from "./backup";
import { seedCategories } from "./catalog";
import { BillingPeriod, Currency, Subscription, SubscriptionStatus } from "./models";
import { makeBackupFile } from "./backup";

interface DemoSpec {
  id: string;
  name: string;
  amount: number;
  currency: Currency;
  period?: BillingPeriod;
  cat: string;
  inDays: number;
  start: [number, number, number];
  domain?: string;
  status?: SubscriptionStatus;
  trialDays?: number;
}

const specs: DemoSpec[] = [
  { id: "test-1", name: "Netflix", amount: 22.99, currency: "USD", cat: "cat-streaming", inDays: 5, start: [2024, 3, 1], domain: "netflix.com" },
  { id: "test-2", name: "YouTube Premium", amount: 13.99, currency: "USD", cat: "cat-streaming", inDays: 12, start: [2023, 8, 15], domain: "youtube.com" },
  { id: "test-3", name: "Spotify", amount: 10.99, currency: "USD", cat: "cat-streaming", inDays: 8, start: [2022, 1, 10], domain: "spotify.com" },
  { id: "test-5", name: "Яндекс Музыка", amount: 299, currency: "RUB", cat: "cat-streaming", inDays: 3, start: [2023, 11, 1], domain: "music.yandex.ru" },
  { id: "test-6", name: "Кинопоиск", amount: 269, currency: "RUB", cat: "cat-streaming", inDays: 15, start: [2024, 1, 20], domain: "kinopoisk.ru" },
  { id: "test-7", name: "Claude Pro", amount: 20, currency: "USD", cat: "cat-ai", inDays: 2, start: [2024, 5, 1], domain: "claude.ai" },
  { id: "test-8", name: "ChatGPT Plus", amount: 20, currency: "USD", cat: "cat-ai", inDays: 7, start: [2023, 3, 15], domain: "chatgpt.com" },
  { id: "test-9", name: "Perplexity Pro", amount: 20, currency: "USD", cat: "cat-ai", inDays: 18, start: [2024, 9, 1], domain: "perplexity.ai" },
  { id: "test-12", name: "МТС", amount: 890, currency: "RUB", cat: "cat-telecom", inDays: 1, start: [2020, 6, 1], domain: "mts.ru" },
  { id: "test-13", name: "Домашний интернет", amount: 750, currency: "RUB", cat: "cat-telecom", inDays: 10, start: [2021, 3, 1] },
  { id: "test-16", name: "PlayStation Plus", amount: 59.99, currency: "USD", period: "annual", cat: "cat-entertainment", inDays: 90, start: [2023, 6, 1], domain: "playstation.com" },
  { id: "test-17", name: "Xbox Game Pass", amount: 14.99, currency: "USD", cat: "cat-entertainment", inDays: 6, start: [2024, 2, 1], domain: "xbox.com" },
  { id: "test-19", name: "Notion Plus", amount: 10, currency: "USD", cat: "cat-other", inDays: 4, start: [2024, 4, 1], domain: "notion.so" },
  { id: "test-21", name: "Фитнес клуб", amount: 3500, currency: "RUB", cat: "cat-other", inDays: 13, start: [2025, 1, 1] },
  { id: "test-trial", name: "Apple Music", amount: 10.99, currency: "USD", cat: "cat-streaming", inDays: 9, start: [2026, 11, 1], domain: "music.apple.com", status: "trial" },
  { id: "test-paused", name: "Hulu", amount: 17.99, currency: "USD", cat: "cat-streaming", inDays: 30, start: [2024, 2, 1], domain: "hulu.com", status: "paused" },
];

function localDate(y: number, m: number, d: number): Date {
  return new Date(y, m - 1, d);
}

export function buildDemoFile(now: Date = new Date()): BackupFileV1 {
  const today = startOfDay(now);
  const subscriptions: Subscription[] = specs.map((spec) => ({
    id: spec.id,
    name: spec.name,
    amount: spec.amount,
    currency: spec.currency,
    billingPeriod: spec.period ?? "monthly",
    customPeriodDays: null,
    categoryId: spec.cat,
    nextBillingDate: addDays(today, spec.inDays),
    reminderDaysBefore: 1,
    status: spec.status ?? "active",
    trialEndDate: spec.status === "trial" ? addDays(today, spec.inDays) : null,
    startDate: localDate(spec.start[0], spec.start[1], spec.start[2]),
    note: null,
    domain: spec.domain ?? null,
    createdAt: now,
    icon: null,
  }));
  return makeBackupFile({ subscriptions, categories: seedCategories(), payments: [] }, now);
}

export const demoFile = buildDemoFile();
