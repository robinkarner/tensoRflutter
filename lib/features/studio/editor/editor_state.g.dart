// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'editor_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `uiEdPct` — Spaltenverhältnis der linken Editor-Spalte in Prozent.

@ProviderFor(EditorSplitPct)
final editorSplitPctProvider = EditorSplitPctProvider._();

/// `uiEdPct` — Spaltenverhältnis der linken Editor-Spalte in Prozent.
final class EditorSplitPctProvider
    extends $AsyncNotifierProvider<EditorSplitPct, int> {
  /// `uiEdPct` — Spaltenverhältnis der linken Editor-Spalte in Prozent.
  EditorSplitPctProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editorSplitPctProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editorSplitPctHash();

  @$internal
  @override
  EditorSplitPct create() => EditorSplitPct();
}

String _$editorSplitPctHash() => r'58f1eaf73983dcde1ee602e09818206cf7ceb79c';

/// `uiEdPct` — Spaltenverhältnis der linken Editor-Spalte in Prozent.

abstract class _$EditorSplitPct extends $AsyncNotifier<int> {
  FutureOr<int> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<int>, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<int>, int>,
              AsyncValue<int>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
