// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Der Datei-Speicher als Provider — das `PdfStore.ready`-Pendant: alle
/// Konsumenten warten auf `fileStoreProvider.future`, bevor sie zugreifen
/// (verhindert das Boot-Race „zugeordnete PDFs wirken fehlend", app.js:10-13).

@ProviderFor(fileStore)
final fileStoreProvider = FileStoreProvider._();

/// Der Datei-Speicher als Provider — das `PdfStore.ready`-Pendant: alle
/// Konsumenten warten auf `fileStoreProvider.future`, bevor sie zugreifen
/// (verhindert das Boot-Race „zugeordnete PDFs wirken fehlend", app.js:10-13).

final class FileStoreProvider
    extends
        $FunctionalProvider<
          AsyncValue<FileStore>,
          FileStore,
          FutureOr<FileStore>
        >
    with $FutureModifier<FileStore>, $FutureProvider<FileStore> {
  /// Der Datei-Speicher als Provider — das `PdfStore.ready`-Pendant: alle
  /// Konsumenten warten auf `fileStoreProvider.future`, bevor sie zugreifen
  /// (verhindert das Boot-Race „zugeordnete PDFs wirken fehlend", app.js:10-13).
  FileStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fileStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fileStoreHash();

  @$internal
  @override
  $FutureProviderElement<FileStore> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<FileStore> create(Ref ref) {
    return fileStore(ref);
  }
}

String _$fileStoreHash() => r'27c09ff1ed886712d88c56b1d4fac18d835fa3b1';
