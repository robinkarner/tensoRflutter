// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_engine.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Engine als Provider — teilt FileStore + KV mit dem Rest der App.

@ProviderFor(downloadEngine)
final downloadEngineProvider = DownloadEngineProvider._();

/// Engine als Provider — teilt FileStore + KV mit dem Rest der App.

final class DownloadEngineProvider
    extends
        $FunctionalProvider<
          AsyncValue<DownloadEngine>,
          DownloadEngine,
          FutureOr<DownloadEngine>
        >
    with $FutureModifier<DownloadEngine>, $FutureProvider<DownloadEngine> {
  /// Engine als Provider — teilt FileStore + KV mit dem Rest der App.
  DownloadEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadEngineHash();

  @$internal
  @override
  $FutureProviderElement<DownloadEngine> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DownloadEngine> create(Ref ref) {
    return downloadEngine(ref);
  }
}

String _$downloadEngineHash() => r'65e414aa117c12185dbc93d62e6cce1762b24a78';
