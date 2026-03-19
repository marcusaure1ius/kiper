enum BillingPeriod {
  weekly,
  monthly,
  quarterly,
  semiannual,
  annual,
  custom;

  double get monthlyEquivalent => switch (this) {
    weekly => 52 / 12,
    monthly => 1.0,
    quarterly => 1 / 3,
    semiannual => 1 / 6,
    annual => 1 / 12,
    custom => 1.0,
  };

  DateTime nextDate(DateTime current) => switch (this) {
    weekly => current.add(const Duration(days: 7)),
    monthly => DateTime(current.year, current.month + 1, current.day),
    quarterly => DateTime(current.year, current.month + 3, current.day),
    semiannual => DateTime(current.year, current.month + 6, current.day),
    annual => DateTime(current.year + 1, current.month, current.day),
    custom => current,
  };

  DateTime nextDateCustom(DateTime current, int days) =>
      current.add(Duration(days: days));
}
