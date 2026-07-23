// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wissen_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `U.storeGet('wissenLens', 'erklaerung')` + Persistenz beim Klick
/// (views_analyse.js:129/143).

@ProviderFor(WissenLens)
final wissenLensProvider = WissenLensProvider._();

/// `U.storeGet('wissenLens', 'erklaerung')` + Persistenz beim Klick
/// (views_analyse.js:129/143).
final class WissenLensProvider
    extends $AsyncNotifierProvider<WissenLens, String> {
  /// `U.storeGet('wissenLens', 'erklaerung')` + Persistenz beim Klick
  /// (views_analyse.js:129/143).
  WissenLensProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wissenLensProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wissenLensHash();

  @$internal
  @override
  WissenLens create() => WissenLens();
}

String _$wissenLensHash() => r'2456b943cb2ce7ecaf9b89dc5893168929f6a3e3';

/// `U.storeGet('wissenLens', 'erklaerung')` + Persistenz beim Klick
/// (views_analyse.js:129/143).

abstract class _$WissenLens extends $AsyncNotifier<String> {
  FutureOr<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String>, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String>, String>,
              AsyncValue<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Kennzahlen: `DATA_META.stats` der aktiven Arbeit — Stats werden NIE
/// gespeichert, immer berechnet (Dossier 10 §9.9): fehlen sie im Meta
/// (z. B. frisch importierte Arbeit), rechnet [ThesisRuntime.computeStats]
/// sie hier deterministisch nach.

@ProviderFor(wissenStats)
final wissenStatsProvider = WissenStatsProvider._();

/// Kennzahlen: `DATA_META.stats` der aktiven Arbeit — Stats werden NIE
/// gespeichert, immer berechnet (Dossier 10 §9.9): fehlen sie im Meta
/// (z. B. frisch importierte Arbeit), rechnet [ThesisRuntime.computeStats]
/// sie hier deterministisch nach.

final class WissenStatsProvider
    extends $FunctionalProvider<StatsMeta?, StatsMeta?, StatsMeta?>
    with $Provider<StatsMeta?> {
  /// Kennzahlen: `DATA_META.stats` der aktiven Arbeit — Stats werden NIE
  /// gespeichert, immer berechnet (Dossier 10 §9.9): fehlen sie im Meta
  /// (z. B. frisch importierte Arbeit), rechnet [ThesisRuntime.computeStats]
  /// sie hier deterministisch nach.
  WissenStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wissenStatsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wissenStatsHash();

  @$internal
  @override
  $ProviderElement<StatsMeta?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StatsMeta? create(Ref ref) {
    return wissenStats(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StatsMeta? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StatsMeta?>(value),
    );
  }
}

String _$wissenStatsHash() => r'524ed5ccb62ed603d22650d2c38a6efcc5922e7d';
