import 'package:kiper/core/currency/currency.dart';
import 'package:kiper/features/subscriptions/models/billing_period.dart';

class CatalogEntry {
  final String name;
  final String icon;
  final Currency defaultCurrency;
  final BillingPeriod defaultPeriod;
  final String categoryId;
  final String? logoUrl;

  const CatalogEntry({
    required this.name,
    required this.icon,
    required this.defaultCurrency,
    required this.defaultPeriod,
    required this.categoryId,
    this.logoUrl,
  });
}

/// Display names for catalog categories (mirrored from DB seeds).
const catalogCategoryNames = <String, String>{
  'cat-streaming': 'Стриминг',
  'cat-ai': 'AI-сервисы',
  'cat-telecom': 'Связь',
  'cat-entertainment': 'Развлечения',
};

const catalogData = <CatalogEntry>[
  // Стриминг
  CatalogEntry(name: 'Netflix', icon: 'movie', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-streaming', logoUrl: 'https://www.google.com/s2/favicons?domain=netflix.com&sz=128'),
  CatalogEntry(name: 'YouTube Premium', icon: 'smart_display', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-streaming', logoUrl: 'https://www.google.com/s2/favicons?domain=youtube.com&sz=128'),
  CatalogEntry(name: 'Spotify', icon: 'music_note', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-streaming', logoUrl: 'https://www.google.com/s2/favicons?domain=spotify.com&sz=128'),
  CatalogEntry(name: 'Apple Music', icon: 'music_note', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-streaming', logoUrl: 'https://www.google.com/s2/favicons?domain=music.apple.com&sz=128'),
  CatalogEntry(name: 'Яндекс Музыка', icon: 'music_note', defaultCurrency: Currency.rub, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-streaming', logoUrl: 'https://www.google.com/s2/favicons?domain=music.yandex.ru&sz=128'),
  CatalogEntry(name: 'Кинопоиск', icon: 'movie', defaultCurrency: Currency.rub, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-streaming', logoUrl: 'https://www.google.com/s2/favicons?domain=kinopoisk.ru&sz=128'),
  // AI-сервисы
  CatalogEntry(name: 'Claude', icon: 'smart_toy', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-ai', logoUrl: 'https://www.google.com/s2/favicons?domain=claude.ai&sz=128'),
  CatalogEntry(name: 'ChatGPT', icon: 'smart_toy', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-ai', logoUrl: 'https://www.google.com/s2/favicons?domain=chatgpt.com&sz=128'),
  CatalogEntry(name: 'Perplexity', icon: 'search', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-ai', logoUrl: 'https://www.google.com/s2/favicons?domain=perplexity.ai&sz=128'),
  CatalogEntry(name: 'Google AI (Gemini)', icon: 'auto_awesome', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-ai', logoUrl: 'https://www.google.com/s2/favicons?domain=gemini.google.com&sz=128'),
  // Связь
  CatalogEntry(name: 'МТС', icon: 'phone_android', defaultCurrency: Currency.rub, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-telecom', logoUrl: 'https://www.google.com/s2/favicons?domain=mts.ru&sz=128'),
  CatalogEntry(name: 'Билайн', icon: 'phone_android', defaultCurrency: Currency.rub, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-telecom', logoUrl: 'https://www.google.com/s2/favicons?domain=beeline.ru&sz=128'),
  CatalogEntry(name: 'Мегафон', icon: 'phone_android', defaultCurrency: Currency.rub, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-telecom', logoUrl: 'https://www.google.com/s2/favicons?domain=megafon.ru&sz=128'),
  CatalogEntry(name: 'Tele2', icon: 'phone_android', defaultCurrency: Currency.rub, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-telecom', logoUrl: 'https://www.google.com/s2/favicons?domain=tele2.ru&sz=128'),
  CatalogEntry(name: 'Ростелеком', icon: 'wifi', defaultCurrency: Currency.rub, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-telecom', logoUrl: 'https://www.google.com/s2/favicons?domain=rt.ru&sz=128'),
  // Развлечения
  CatalogEntry(name: 'PlayStation Plus', icon: 'sports_esports', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-entertainment', logoUrl: 'https://www.google.com/s2/favicons?domain=playstation.com&sz=128'),
  CatalogEntry(name: 'Xbox Game Pass', icon: 'sports_esports', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-entertainment', logoUrl: 'https://www.google.com/s2/favicons?domain=xbox.com&sz=128'),
  CatalogEntry(name: 'Steam', icon: 'sports_esports', defaultCurrency: Currency.usd, defaultPeriod: BillingPeriod.monthly, categoryId: 'cat-entertainment', logoUrl: 'https://www.google.com/s2/favicons?domain=steampowered.com&sz=128'),
];
