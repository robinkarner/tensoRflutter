// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quellen_kv.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(QuellenKv)
final quellenKvProvider = QuellenKvProvider._();

final class QuellenKvProvider
    extends $AsyncNotifierProvider<QuellenKv, Map<String, Object?>> {
  QuellenKvProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'quellenKvProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$quellenKvHash();

  @$internal
  @override
  QuellenKv create() => QuellenKv();
}

String _$quellenKvHash() => r'077e654b98e68710b668ac15b7ad99c8e9abcc7b';

abstract class _$QuellenKv extends $AsyncNotifier<Map<String, Object?>> {
  FutureOr<Map<String, Object?>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<Map<String, Object?>>, Map<String, Object?>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<Map<String, Object?>>,
                Map<String, Object?>
              >,
              AsyncValue<Map<String, Object?>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(quellenDomain)
final quellenDomainProvider = QuellenDomainProvider._();

final class QuellenDomainProvider
    extends $FunctionalProvider<QuellenDomain?, QuellenDomain?, QuellenDomain?>
    with $Provider<QuellenDomain?> {
  QuellenDomainProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'quellenDomainProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$quellenDomainHash();

  @$internal
  @override
  $ProviderElement<QuellenDomain?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  QuellenDomain? create(Ref ref) {
    return quellenDomain(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QuellenDomain? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QuellenDomain?>(value),
    );
  }
}

String _$quellenDomainHash() => r'27b988c3c4b6191a4b631e9907aedc17d881e5f9';
