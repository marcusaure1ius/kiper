import 'package:kiper/core/currency/currency.dart';
import 'package:kiper/features/subscriptions/models/billing_period.dart';

class CatalogEntry {
  final String name;
  final String icon;
  final Currency defaultCurrency;
  final BillingPeriod defaultPeriod;
  final String categoryId;

  const CatalogEntry({required this.name, required this.icon, required this.defaultCurrency, required this.defaultPeriod, required this.categoryId});
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
