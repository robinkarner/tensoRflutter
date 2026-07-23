// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'topbar.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Anzeigename der aktiven Arbeit (app.js:46-49): Meta-Titel, außer er ist
/// leer oder „Unbenannte Arbeit“ — dann der Projekt-Name. Vor Boot-Ende
/// steht wie im HTML der Platzhalter „…“.

@ProviderFor(activeWorkTitle)
final activeWorkTitleProvider = ActiveWorkTitleProvider._();

/// Anzeigename der aktiven Arbeit (app.js:46-49): Meta-Titel, außer er ist
/// leer oder „Unbenannte Arbeit“ — dann der Projekt-Name. Vor Boot-Ende
/// steht wie im HTML der Platzhalter „…“.

final class ActiveWorkTitleProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// Anzeigename der aktiven Arbeit (app.js:46-49): Meta-Titel, außer er ist
  /// leer oder „Unbenannte Arbeit“ — dann der Projekt-Name. Vor Boot-Ende
  /// steht wie im HTML der Platzhalter „…“.
  ActiveWorkTitleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeWorkTitleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeWorkTitleHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return activeWorkTitle(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$activeWorkTitleHash() => r'546e967e7dccbcc6cc21a1aceec64f632b770e3c';
