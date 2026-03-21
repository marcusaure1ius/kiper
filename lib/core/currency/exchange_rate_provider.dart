// lib/core/currency/exchange_rate_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:kiper/core/currency/currency.dart';
import 'package:kiper/core/currency/exchange_rate_service.dart';

part 'exchange_rate_provider.g.dart';

@riverpod
Future<Map<Currency, double>> exchangeRates(Ref ref) async {
  return ExchangeRateService.fetchRates();
}
