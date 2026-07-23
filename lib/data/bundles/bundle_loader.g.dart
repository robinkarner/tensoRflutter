// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bundle_loader.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Die geladenen Bundles als Provider — einmal pro App-Lauf (keepAlive);
/// der explizite Provider-Reboot (E8) invalidiert auch diesen Knoten.

@ProviderFor(thesisBundle)
final thesisBundleProvider = ThesisBundleProvider._();

/// Die geladenen Bundles als Provider — einmal pro App-Lauf (keepAlive);
/// der explizite Provider-Reboot (E8) invalidiert auch diesen Knoten.

final class ThesisBundleProvider
    extends
        $FunctionalProvider<
          AsyncValue<ThesisBundle>,
          ThesisBundle,
          FutureOr<ThesisBundle>
        >
    with $FutureModifier<ThesisBundle>, $FutureProvider<ThesisBundle> {
  /// Die geladenen Bundles als Provider — einmal pro App-Lauf (keepAlive);
  /// der explizite Provider-Reboot (E8) invalidiert auch diesen Knoten.
  ThesisBundleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'thesisBundleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$thesisBundleHash();

  @$internal
  @override
  $FutureProviderElement<ThesisBundle> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ThesisBundle> create(Ref ref) {
    return thesisBundle(ref);
  }
}

String _$thesisBundleHash() => r'd37c730e2fcb0171d25b9e3b66bf8b1b452ec043';
