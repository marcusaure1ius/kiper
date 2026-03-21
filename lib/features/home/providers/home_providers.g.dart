// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Total monthly cost of all active subscriptions in RUB.

@ProviderFor(monthlyTotalRub)
final monthlyTotalRubProvider = MonthlyTotalRubProvider._();

/// Total monthly cost of all active subscriptions in RUB.

final class MonthlyTotalRubProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  /// Total monthly cost of all active subscriptions in RUB.
  MonthlyTotalRubProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'monthlyTotalRubProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$monthlyTotalRubHash();

  @$internal
  @override
  $FutureProviderElement<double> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double> create(Ref ref) {
    return monthlyTotalRub(ref);
  }
}

String _$monthlyTotalRubHash() => r'd34fc8dff2e6dd5b7efc21669943bedfa2d302d1';

/// Progress through the current month: paid vs remaining amounts in RUB.

@ProviderFor(monthProgress)
final monthProgressProvider = MonthProgressProvider._();

/// Progress through the current month: paid vs remaining amounts in RUB.

final class MonthProgressProvider
    extends
        $FunctionalProvider<
          AsyncValue<({double paid, double remaining})>,
          ({double paid, double remaining}),
          FutureOr<({double paid, double remaining})>
        >
    with
        $FutureModifier<({double paid, double remaining})>,
        $FutureProvider<({double paid, double remaining})> {
  /// Progress through the current month: paid vs remaining amounts in RUB.
  MonthProgressProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'monthProgressProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$monthProgressHash();

  @$internal
  @override
  $FutureProviderElement<({double paid, double remaining})> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<({double paid, double remaining})> create(Ref ref) {
    return monthProgress(ref);
  }
}

String _$monthProgressHash() => r'9b1d2bb20f33906c03744a427cd359e4a787d27b';

/// Payment events from the last 90 days, sorted newest-first.

@ProviderFor(pastPayments)
final pastPaymentsProvider = PastPaymentsProvider._();

/// Payment events from the last 90 days, sorted newest-first.

final class PastPaymentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PaymentEvent>>,
          List<PaymentEvent>,
          FutureOr<List<PaymentEvent>>
        >
    with
        $FutureModifier<List<PaymentEvent>>,
        $FutureProvider<List<PaymentEvent>> {
  /// Payment events from the last 90 days, sorted newest-first.
  PastPaymentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pastPaymentsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pastPaymentsHash();

  @$internal
  @override
  $FutureProviderElement<List<PaymentEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PaymentEvent>> create(Ref ref) {
    return pastPayments(ref);
  }
}

String _$pastPaymentsHash() => r'741b6d9499dec740d577710113a7ac20d0493a2f';

/// Payment events for the next 90 days, sorted soonest-first.

@ProviderFor(futurePayments)
final futurePaymentsProvider = FuturePaymentsProvider._();

/// Payment events for the next 90 days, sorted soonest-first.

final class FuturePaymentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PaymentEvent>>,
          List<PaymentEvent>,
          FutureOr<List<PaymentEvent>>
        >
    with
        $FutureModifier<List<PaymentEvent>>,
        $FutureProvider<List<PaymentEvent>> {
  /// Payment events for the next 90 days, sorted soonest-first.
  FuturePaymentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'futurePaymentsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$futurePaymentsHash();

  @$internal
  @override
  $FutureProviderElement<List<PaymentEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PaymentEvent>> create(Ref ref) {
    return futurePayments(ref);
  }
}

String _$futurePaymentsHash() => r'190becf821546b5a1fc6af493758422f7fb37a24';
