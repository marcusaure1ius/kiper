// lib/core/currency/exchange_rate_service.dart
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:kiper/core/currency/currency.dart';

class ExchangeRateService {
  static const _cbrUrl = 'https://www.cbr.ru/scripts/XML_daily.asp';

  static final Map<Currency, double> fallbackRates = {
    Currency.usd: 90.0,
    Currency.eur: 98.0,
  };

  static Future<Map<Currency, double>> fetchRates() async {
    try {
      final response = await http.get(Uri.parse(_cbrUrl));
      if (response.statusCode == 200) {
        return parseCbrXml(response.body);
      }
    } catch (_) {}
    return fallbackRates;
  }

  static Map<Currency, double> parseCbrXml(String xmlString) {
    final document = xml.XmlDocument.parse(xmlString);
    final rates = <Currency, double>{};
    for (final valute in document.findAllElements('Valute')) {
      final charCode = valute.findElements('CharCode').first.innerText;
      final valueStr = valute.findElements('Value').first.innerText;
      final nominal = int.parse(valute.findElements('Nominal').first.innerText);
      final value = double.parse(valueStr.replaceAll(',', '.'));
      final currency = Currency.values.where((c) => c.code == charCode).firstOrNull;
      if (currency != null) {
        rates[currency] = value / nominal;
      }
    }
    return rates;
  }

  static double convertToRub(double amount, Currency currency, Map<Currency, double> rates) {
    if (currency == Currency.rub) return amount;
    final rate = rates[currency] ?? fallbackRates[currency] ?? 1.0;
    return amount * rate;
  }
}
