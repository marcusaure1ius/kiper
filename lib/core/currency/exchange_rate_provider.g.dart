// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exchange_rate_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(exchangeRates)
final exchangeRatesProvider = ExchangeRatesProvider._();

final class ExchangeRatesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<Currency, double>>,
          Map<Currency, double>,
          FutureOr<Map<Currency, double>>
        >
    with
        $FutureModifier<Map<Currency, double>>,
        $FutureProvider<Map<Currency, double>> {
  ExchangeRatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exchangeRatesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exchangeRatesHash();

  @$internal
  @override
  $FutureProviderElement<Map<Currency, double>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<Currency, double>> create(Ref ref) {
    return exchangeRates(ref);
  }
}

String _$exchangeRatesHash() => r'9da1c5146c8eff96fb2018902070b9412d8e7268';
