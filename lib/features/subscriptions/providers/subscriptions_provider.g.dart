// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscriptions_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SubscriptionsNotifier)
final subscriptionsProvider = SubscriptionsNotifierProvider._();

final class SubscriptionsNotifierProvider
    extends $AsyncNotifierProvider<SubscriptionsNotifier, void> {
  SubscriptionsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscriptionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscriptionsNotifierHash();

  @$internal
  @override
  SubscriptionsNotifier create() => SubscriptionsNotifier();
}

String _$subscriptionsNotifierHash() =>
    r'1e85ac2c71c7a187a6ffbaed09f74e83b3b72acb';

abstract class _$SubscriptionsNotifier extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
