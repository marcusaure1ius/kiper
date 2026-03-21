class PaymentEvent {
  final String subscriptionId;
  final String name;
  final String? icon;
  final double amount;
  final String currency;
  final DateTime date;
  final String? categoryId;

  const PaymentEvent({
    required this.subscriptionId,
    required this.name,
    this.icon,
    required this.amount,
    required this.currency,
    required this.date,
    this.categoryId,
  });
}
