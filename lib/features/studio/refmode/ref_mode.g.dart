// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ref_mode.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `uiRefW` — Breite der Zitierelemente-Spalte (px, null = Standard 360).

@ProviderFor(RefWidth)
final refWidthProvider = RefWidthProvider._();

/// `uiRefW` — Breite der Zitierelemente-Spalte (px, null = Standard 360).
final class RefWidthProvider extends $AsyncNotifierProvider<RefWidth, int?> {
  /// `uiRefW` — Breite der Zitierelemente-Spalte (px, null = Standard 360).
  RefWidthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'refWidthProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$refWidthHash();

  @$internal
  @override
  RefWidth create() => RefWidth();
}

String _$refWidthHash() => r'90c0c1e7ed329bda4bd7444b67d4dbcfb346fce7';

/// `uiRefW` — Breite der Zitierelemente-Spalte (px, null = Standard 360).

abstract class _$RefWidth extends $AsyncNotifier<int?> {
  FutureOr<int?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<int?>, int?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<int?>, int?>,
              AsyncValue<int?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
