// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(analyticsSubscriptions)
final analyticsSubscriptionsProvider = AnalyticsSubscriptionsProvider._();

final class AnalyticsSubscriptionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AnalyticsSubscription>>,
          List<AnalyticsSubscription>,
          FutureOr<List<AnalyticsSubscription>>
        >
    with
        $FutureModifier<List<AnalyticsSubscription>>,
        $FutureProvider<List<AnalyticsSubscription>> {
  AnalyticsSubscriptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsSubscriptionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsSubscriptionsHash();

  @$internal
  @override
  $FutureProviderElement<List<AnalyticsSubscription>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AnalyticsSubscription>> create(Ref ref) {
    return analyticsSubscriptions(ref);
  }
}

String _$analyticsSubscriptionsHash() =>
    r'2eb865fad31451d8626edd1c29a5e1bbddc9e1cc';

@ProviderFor(monthlyTotals)
final monthlyTotalsProvider = MonthlyTotalsProvider._();

final class MonthlyTotalsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MonthlyTotal>>,
          List<MonthlyTotal>,
          FutureOr<List<MonthlyTotal>>
        >
    with
        $FutureModifier<List<MonthlyTotal>>,
        $FutureProvider<List<MonthlyTotal>> {
  MonthlyTotalsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'monthlyTotalsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$monthlyTotalsHash();

  @$internal
  @override
  $FutureProviderElement<List<MonthlyTotal>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MonthlyTotal>> create(Ref ref) {
    return monthlyTotals(ref);
  }
}

String _$monthlyTotalsHash() => r'92b0b6fe2f1affdb871220f754bea0d2b71f14d3';

@ProviderFor(categoryBreakdown)
final categoryBreakdownProvider = CategoryBreakdownProvider._();

final class CategoryBreakdownProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String?, double>>,
          Map<String?, double>,
          FutureOr<Map<String?, double>>
        >
    with
        $FutureModifier<Map<String?, double>>,
        $FutureProvider<Map<String?, double>> {
  CategoryBreakdownProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryBreakdownProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryBreakdownHash();

  @$internal
  @override
  $FutureProviderElement<Map<String?, double>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String?, double>> create(Ref ref) {
    return categoryBreakdown(ref);
  }
}

String _$categoryBreakdownHash() => r'7d104c129dd9f801be9740e2841bc47153e22c30';
