enum Currency {
  rub(symbol: '₽', code: 'RUB'),
  usd(symbol: '\$', code: 'USD'),
  eur(symbol: '€', code: 'EUR');

  const Currency({required this.symbol, required this.code});
  final String symbol;
  final String code;
}
