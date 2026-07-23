// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'claude_cfg.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Store des globalen `claudeCfg`-Keys mit Write-Through (E10 s. oben).

@ProviderFor(ClaudeCfgStore)
final claudeCfgStoreProvider = ClaudeCfgStoreProvider._();

/// Store des globalen `claudeCfg`-Keys mit Write-Through (E10 s. oben).
final class ClaudeCfgStoreProvider
    extends $AsyncNotifierProvider<ClaudeCfgStore, ClaudeCfg> {
  /// Store des globalen `claudeCfg`-Keys mit Write-Through (E10 s. oben).
  ClaudeCfgStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'claudeCfgStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$claudeCfgStoreHash();

  @$internal
  @override
  ClaudeCfgStore create() => ClaudeCfgStore();
}

String _$claudeCfgStoreHash() => r'1c66e8438617019d61381819d4ddd2d112e9a150';

/// Store des globalen `claudeCfg`-Keys mit Write-Through (E10 s. oben).

abstract class _$ClaudeCfgStore extends $AsyncNotifier<ClaudeCfg> {
  FutureOr<ClaudeCfg> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ClaudeCfg>, ClaudeCfg>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ClaudeCfg>, ClaudeCfg>,
              AsyncValue<ClaudeCfg>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Store des globalen `enhCfg`-Keys (`{"<flowId>": {model, instruction}}`).

@ProviderFor(EnhCfgStore)
final enhCfgStoreProvider = EnhCfgStoreProvider._();

/// Store des globalen `enhCfg`-Keys (`{"<flowId>": {model, instruction}}`).
final class EnhCfgStoreProvider
    extends $AsyncNotifierProvider<EnhCfgStore, Map<String, Object?>> {
  /// Store des globalen `enhCfg`-Keys (`{"<flowId>": {model, instruction}}`).
  EnhCfgStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'enhCfgStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$enhCfgStoreHash();

  @$internal
  @override
  EnhCfgStore create() => EnhCfgStore();
}

String _$enhCfgStoreHash() => r'f5226e03aba1e2ad5d332a369ee8aa55f5a5298a';

/// Store des globalen `enhCfg`-Keys (`{"<flowId>": {model, instruction}}`).

abstract class _$EnhCfgStore extends $AsyncNotifier<Map<String, Object?>> {
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
