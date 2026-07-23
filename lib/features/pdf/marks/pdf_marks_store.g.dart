// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pdf_marks_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PdfMarks)
final pdfMarksProvider = PdfMarksProvider._();

final class PdfMarksProvider
    extends $AsyncNotifierProvider<PdfMarks, PdfMarksState> {
  PdfMarksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pdfMarksProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pdfMarksHash();

  @$internal
  @override
  PdfMarks create() => PdfMarks();
}

String _$pdfMarksHash() => r'7dab3dee31743ceb29928809d08c87c340c654e2';

abstract class _$PdfMarks extends $AsyncNotifier<PdfMarksState> {
  FutureOr<PdfMarksState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PdfMarksState>, PdfMarksState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PdfMarksState>, PdfMarksState>,
              AsyncValue<PdfMarksState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Die `MarksForFn`-Funktion für den [Levels]-Konstruktor — null, solange
/// der Store noch lädt (die Levels-Kaskade überspringt die Markierungsstufe
/// dann wie das Original ohne Engine).

@ProviderFor(levelsMarksForFn)
final levelsMarksForFnProvider = LevelsMarksForFnProvider._();

/// Die `MarksForFn`-Funktion für den [Levels]-Konstruktor — null, solange
/// der Store noch lädt (die Levels-Kaskade überspringt die Markierungsstufe
/// dann wie das Original ohne Engine).

final class LevelsMarksForFnProvider
    extends $FunctionalProvider<MarksForFn?, MarksForFn?, MarksForFn?>
    with $Provider<MarksForFn?> {
  /// Die `MarksForFn`-Funktion für den [Levels]-Konstruktor — null, solange
  /// der Store noch lädt (die Levels-Kaskade überspringt die Markierungsstufe
  /// dann wie das Original ohne Engine).
  LevelsMarksForFnProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'levelsMarksForFnProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$levelsMarksForFnHash();

  @$internal
  @override
  $ProviderElement<MarksForFn?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MarksForFn? create(Ref ref) {
    return levelsMarksForFn(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MarksForFn? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MarksForFn?>(value),
    );
  }
}

String _$levelsMarksForFnHash() => r'90a8f153f773ce31fecc0fd44e37d6ab82f86f46';
