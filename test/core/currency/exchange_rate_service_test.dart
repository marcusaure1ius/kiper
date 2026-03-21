// test/core/currency/exchange_rate_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kiper/core/currency/currency.dart';
import 'package:kiper/core/currency/exchange_rate_service.dart';

void main() {
  group('ExchangeRateService', () {
    test('parseCbrXml extracts USD and EUR rates', () {
      const xml = '<?xml version="1.0" encoding="windows-1251"?><ValCurs Date="19.03.2026" name="Foreign Currency Market"><Valute ID="R01235"><NumCode>840</NumCode><CharCode>USD</CharCode><Nominal>1</Nominal><Name>Доллар США</Name><Value>92,5000</Value><VunitRate>92,5000</VunitRate></Valute><Valute ID="R01239"><NumCode>978</NumCode><CharCode>EUR</CharCode><Nominal>1</Nominal><Name>Евро</Name><Value>100,5000</Value><VunitRate>100,5000</VunitRate></Valute></ValCurs>';
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
