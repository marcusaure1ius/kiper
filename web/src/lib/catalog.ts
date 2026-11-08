// Port of ios-native/Kiper/Features/Subscriptions/CatalogData.swift and
// Data/SeedData.swift (seed categories) plus the category editor palette.

import { Category } from "./models";

export interface CatalogEntry {
  name: string;
  currency: "RUB" | "USD" | "EUR";
  period: "weekly" | "monthly" | "quarterly" | "semiannual" | "annual" | "custom";
  categoryId: string;
  domain: string;
}

export const catalogGroups: { id: string; name: string }[] = [
  { id: "cat-streaming", name: "Стриминг" },
  { id: "cat-ai", name: "AI-сервисы" },
  { id: "cat-telecom", name: "Связь" },
  { id: "cat-entertainment", name: "Развлечения" },
];

export const catalog: CatalogEntry[] = [
  { name: "Netflix", currency: "USD", period: "monthly", categoryId: "cat-streaming", domain: "netflix.com" },
  { name: "YouTube Premium", currency: "USD", period: "monthly", categoryId: "cat-streaming", domain: "youtube.com" },
  { name: "Spotify", currency: "USD", period: "monthly", categoryId: "cat-streaming", domain: "spotify.com" },
  { name: "Apple Music", currency: "USD", period: "monthly", categoryId: "cat-streaming", domain: "music.apple.com" },
  { name: "Яндекс Музыка", currency: "RUB", period: "monthly", categoryId: "cat-streaming", domain: "music.yandex.ru" },
  { name: "Кинопоиск", currency: "RUB", period: "monthly", categoryId: "cat-streaming", domain: "kinopoisk.ru" },
  { name: "Claude", currency: "USD", period: "monthly", categoryId: "cat-ai", domain: "claude.ai" },
  { name: "ChatGPT", currency: "USD", period: "monthly", categoryId: "cat-ai", domain: "chatgpt.com" },
  { name: "Perplexity", currency: "USD", period: "monthly", categoryId: "cat-ai", domain: "perplexity.ai" },
  { name: "Google AI (Gemini)", currency: "USD", period: "monthly", categoryId: "cat-ai", domain: "gemini.google.com" },
  { name: "МТС", currency: "RUB", period: "monthly", categoryId: "cat-telecom", domain: "mts.ru" },
  { name: "Билайн", currency: "RUB", period: "monthly", categoryId: "cat-telecom", domain: "beeline.ru" },
  { name: "Мегафон", currency: "RUB", period: "monthly", categoryId: "cat-telecom", domain: "megafon.ru" },
  { name: "Tele2", currency: "RUB", period: "monthly", categoryId: "cat-telecom", domain: "tele2.ru" },
  { name: "Ростелеком", currency: "RUB", period: "monthly", categoryId: "cat-telecom", domain: "rt.ru" },
  { name: "PlayStation Plus", currency: "USD", period: "monthly", categoryId: "cat-entertainment", domain: "playstation.com" },
  { name: "Xbox Game Pass", currency: "USD", period: "monthly", categoryId: "cat-entertainment", domain: "xbox.com" },
  { name: "Steam", currency: "USD", period: "monthly", categoryId: "cat-entertainment", domain: "steampowered.com" },
];

export function catalogEntryByName(name: string): CatalogEntry | undefined {
  const lower = name.toLowerCase();
  return catalog.find((e) => e.name.toLowerCase() === lower);
}

/// Same seed as AppDatabase._seedCategories (iOS SeedData.categories).
export function seedCategories(): Category[] {
  return [
    { id: "cat-streaming", name: "Стриминг", colorHex: 0x7C4DFF, symbol: "play.tv.fill" },
    { id: "cat-ai", name: "AI-сервисы", colorHex: 0x2196F3, symbol: "sparkles" },
    { id: "cat-telecom", name: "Связь", colorHex: 0xFF6B35, symbol: "antenna.radiowaves.left.and.right" },
    { id: "cat-entertainment", name: "Развлечения", colorHex: 0xE50914, symbol: "gamecontroller.fill" },
    { id: "cat-other", name: "Другое", colorHex: 0x9E9E9E, symbol: "square.grid.2x2.fill" },
  ];
}

/// Category editor palette (CategoryEditorSheet.swift), 0xRRGGBB.
export const editorColors: number[] = [
  0x7C4DFF, 0x5856D6, 0x2196F3, 0x00B8D4, 0x00C853, 0x8BC34A,
  0xFFC107, 0xFF9800, 0xFF6B35, 0xE50914, 0xFF2D78, 0x9E9E9E,
];

/// The 30 SF Symbols offered in the category editor.
export const editorSymbols: string[] = [
  "play.tv.fill", "music.note", "sparkles", "brain.head.profile", "antenna.radiowaves.left.and.right", "wifi",
  "gamecontroller.fill", "film.fill", "book.fill", "newspaper.fill", "cloud.fill", "lock.shield.fill",
  "cart.fill", "bag.fill", "fork.knife", "cup.and.saucer.fill", "car.fill", "tram.fill",
  "figure.run", "heart.fill", "graduationcap.fill", "briefcase.fill", "house.fill", "pawprint.fill",
  "creditcard.fill", "gift.fill", "paintbrush.fill", "camera.fill", "airplane", "square.grid.2x2.fill",
];
