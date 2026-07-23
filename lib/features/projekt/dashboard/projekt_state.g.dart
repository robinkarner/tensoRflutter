// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'projekt_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ids der Dokument-Quellen mit vorhandener PDF (Speicher ODER gebündeltes
/// Asset — `await U.detectPdf(id)`). Speist die Statkachel „PDFs vorhanden“
/// UND den asynchronen Zeilen-Nachtrag des Quellen-Setups
/// (views_projekt.js:154-166).

@ProviderFor(ProjektDetectedPdfs)
final projektDetectedPdfsProvider = ProjektDetectedPdfsProvider._();

/// ids der Dokument-Quellen mit vorhandener PDF (Speicher ODER gebündeltes
/// Asset — `await U.detectPdf(id)`). Speist die Statkachel „PDFs vorhanden“
/// UND den asynchronen Zeilen-Nachtrag des Quellen-Setups
/// (views_projekt.js:154-166).
final class ProjektDetectedPdfsProvider
    extends $AsyncNotifierProvider<ProjektDetectedPdfs, Set<String>> {
  /// ids der Dokument-Quellen mit vorhandener PDF (Speicher ODER gebündeltes
  /// Asset — `await U.detectPdf(id)`). Speist die Statkachel „PDFs vorhanden“
  /// UND den asynchronen Zeilen-Nachtrag des Quellen-Setups
  /// (views_projekt.js:154-166).
  ProjektDetectedPdfsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projektDetectedPdfsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projektDetectedPdfsHash();

  @$internal
  @override
  ProjektDetectedPdfs create() => ProjektDetectedPdfs();
}

String _$projektDetectedPdfsHash() =>
    r'34737882b6de58c40be22b5a2ec2e063e437dc7f';

/// ids der Dokument-Quellen mit vorhandener PDF (Speicher ODER gebündeltes
/// Asset — `await U.detectPdf(id)`). Speist die Statkachel „PDFs vorhanden“
/// UND den asynchronen Zeilen-Nachtrag des Quellen-Setups
/// (views_projekt.js:154-166).

abstract class _$ProjektDetectedPdfs extends $AsyncNotifier<Set<String>> {
  FutureOr<Set<String>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Set<String>>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Set<String>>, Set<String>>,
              AsyncValue<Set<String>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
