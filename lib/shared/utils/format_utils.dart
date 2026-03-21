import 'package:intl/intl.dart';

/// Format a number with Russian-style thousands separators (spaces).
/// [decimals] controls the number of decimal digits (default 2).
String formatAmount(double value, {int decimals = 2}) {
  return NumberFormat.decimalPatternDigits(
    locale: 'ru',
    decimalDigits: decimals,
  ).format(value);
}
