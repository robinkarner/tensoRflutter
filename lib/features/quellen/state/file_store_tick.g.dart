// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_store_tick.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(fileStoreTick)
final fileStoreTickProvider = FileStoreTickProvider._();

final class FileStoreTickProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  FileStoreTickProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fileStoreTickProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fileStoreTickHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return fileStoreTick(ref);
  }
}

String _$fileStoreTickHash() => r'e8a60e5ac9407b4a30bc62e2807b435c10e8da51';
