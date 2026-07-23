// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Der Router als langlebiger Provider. Er wird erst NACH dem Boot gebaut
/// (main.dart zeigt bis dahin den Splash), darf also synchron auf die
/// Index-Provider zugreifen.

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

/// Der Router als langlebiger Provider. Er wird erst NACH dem Boot gebaut
/// (main.dart zeigt bis dahin den Splash), darf also synchron auf die
/// Index-Provider zugreifen.

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// Der Router als langlebiger Provider. Er wird erst NACH dem Boot gebaut
  /// (main.dart zeigt bis dahin den Splash), darf also synchron auf die
  /// Index-Provider zugreifen.
  AppRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appRouterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$appRouterHash() => r'9f32002051c0ce73dc2d110bf42272e05a6b2308';
