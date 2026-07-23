// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fig_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Der Abbildungs-Speicher als Provider (init einmal, wie FigStore.init()
/// beim Skript-Laden).

@ProviderFor(figStore)
final figStoreProvider = FigStoreProvider._();

/// Der Abbildungs-Speicher als Provider (init einmal, wie FigStore.init()
/// beim Skript-Laden).

final class FigStoreProvider
    extends
        $FunctionalProvider<AsyncValue<FigStore>, FigStore, FutureOr<FigStore>>
    with $FutureModifier<FigStore>, $FutureProvider<FigStore> {
  /// Der Abbildungs-Speicher als Provider (init einmal, wie FigStore.init()
  /// beim Skript-Laden).
  FigStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'figStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$figStoreHash();

  @$internal
  @override
  $FutureProviderElement<FigStore> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<FigStore> create(Ref ref) {
    return figStore(ref);
  }
}

String _$figStoreHash() => r'a97e59f75a5c95553c72149740d7fb4422181b8f';
