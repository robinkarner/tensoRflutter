// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dock_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Effektive View-Definitionen: Defaults + Projekt-Instanzen (vor „◻ Ohne“)
/// + gespeicherte `instDefs`-Overrides (Reihenfolge/Namen), mit Absicherung
/// der Spezial-/Projekt-Views — Port von `dockDefs()` (:2143-2162).

@ProviderFor(dockDefs)
final dockDefsProvider = DockDefsProvider._();

/// Effektive View-Definitionen: Defaults + Projekt-Instanzen (vor „◻ Ohne“)
/// + gespeicherte `instDefs`-Overrides (Reihenfolge/Namen), mit Absicherung
/// der Spezial-/Projekt-Views — Port von `dockDefs()` (:2143-2162).

final class DockDefsProvider
    extends $FunctionalProvider<List<DockDef>, List<DockDef>, List<DockDef>>
    with $Provider<List<DockDef>> {
  /// Effektive View-Definitionen: Defaults + Projekt-Instanzen (vor „◻ Ohne“)
  /// + gespeicherte `instDefs`-Overrides (Reihenfolge/Namen), mit Absicherung
  /// der Spezial-/Projekt-Views — Port von `dockDefs()` (:2143-2162).
  DockDefsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dockDefsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dockDefsHash();

  @$internal
  @override
  $ProviderElement<List<DockDef>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<DockDef> create(Ref ref) {
    return dockDefs(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<DockDef> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<DockDef>>(value),
    );
  }
}

String _$dockDefsHash() => r'a2d3878fd09a8f0e3f39c0556d5b888a18dfa00b';

/// Effektive View eines Abschnitts: Abschnitts-Override (auch explizites
/// `null` = geschlossen!) > globaler Standard — Port von `dockModeFor`
/// (:2177-2180).

@ProviderFor(dockModeFor)
final dockModeForProvider = DockModeForFamily._();

/// Effektive View eines Abschnitts: Abschnitts-Override (auch explizites
/// `null` = geschlossen!) > globaler Standard — Port von `dockModeFor`
/// (:2177-2180).

final class DockModeForProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// Effektive View eines Abschnitts: Abschnitts-Override (auch explizites
  /// `null` = geschlossen!) > globaler Standard — Port von `dockModeFor`
  /// (:2177-2180).
  DockModeForProvider._({
    required DockModeForFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'dockModeForProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dockModeForHash();

  @override
  String toString() {
    return r'dockModeForProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    final argument = this.argument as String;
    return dockModeFor(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DockModeForProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dockModeForHash() => r'58bf67b4bd3aed4808d4cf9e52b5038c4e731212';

/// Effektive View eines Abschnitts: Abschnitts-Override (auch explizites
/// `null` = geschlossen!) > globaler Standard — Port von `dockModeFor`
/// (:2177-2180).

final class DockModeForFamily extends $Family
    with $FunctionalFamilyOverride<String?, String> {
  DockModeForFamily._()
    : super(
        retry: null,
        name: r'dockModeForProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Effektive View eines Abschnitts: Abschnitts-Override (auch explizites
  /// `null` = geschlossen!) > globaler Standard — Port von `dockModeFor`
  /// (:2177-2180).

  DockModeForProvider call(String sectionId) =>
      DockModeForProvider._(argument: sectionId, from: this);

  @override
  String toString() => r'dockModeForProvider';
}
