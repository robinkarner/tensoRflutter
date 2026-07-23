// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kv.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Der Store als Provider — teilt sich die App-Datenbank.

@ProviderFor(kvStore)
final kvStoreProvider = KvStoreProvider._();

/// Der Store als Provider — teilt sich die App-Datenbank.

final class KvStoreProvider
    extends $FunctionalProvider<KvStore, KvStore, KvStore>
    with $Provider<KvStore> {
  /// Der Store als Provider — teilt sich die App-Datenbank.
  KvStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'kvStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$kvStoreHash();

  @$internal
  @override
  $ProviderElement<KvStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  KvStore create(Ref ref) {
    return kvStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KvStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KvStore>(value),
    );
  }
}

String _$kvStoreHash() => r'58d9f93b6be35e8f13e06a24720666934f016b7b';
