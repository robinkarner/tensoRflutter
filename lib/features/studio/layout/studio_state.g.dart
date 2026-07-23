// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'studio_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(StudioPrefsCtl)
final studioPrefsCtlProvider = StudioPrefsCtlProvider._();

final class StudioPrefsCtlProvider
    extends $AsyncNotifierProvider<StudioPrefsCtl, StudioPrefs> {
  StudioPrefsCtlProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'studioPrefsCtlProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$studioPrefsCtlHash();

  @$internal
  @override
  StudioPrefsCtl create() => StudioPrefsCtl();
}

String _$studioPrefsCtlHash() => r'345ff18570f1e3497e86cd2bac0002b1c9969d16';

abstract class _$StudioPrefsCtl extends $AsyncNotifier<StudioPrefs> {
  FutureOr<StudioPrefs> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<StudioPrefs>, StudioPrefs>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<StudioPrefs>, StudioPrefs>,
              AsyncValue<StudioPrefs>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(StudioKv)
final studioKvProvider = StudioKvProvider._();

final class StudioKvProvider
    extends $AsyncNotifierProvider<StudioKv, Map<String, Object?>> {
  StudioKvProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'studioKvProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$studioKvHash();

  @$internal
  @override
  StudioKv create() => StudioKv();
}

String _$studioKvHash() => r'd6b97f763aaff89d5da5c50b4cea6a50336a4a14';

abstract class _$StudioKv extends $AsyncNotifier<Map<String, Object?>> {
  FutureOr<Map<String, Object?>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<Map<String, Object?>>, Map<String, Object?>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<Map<String, Object?>>,
                Map<String, Object?>
              >,
              AsyncValue<Map<String, Object?>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(studioDomain)
final studioDomainProvider = StudioDomainProvider._();

final class StudioDomainProvider
    extends $FunctionalProvider<StudioDomain?, StudioDomain?, StudioDomain?>
    with $Provider<StudioDomain?> {
  StudioDomainProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'studioDomainProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$studioDomainHash();

  @$internal
  @override
  $ProviderElement<StudioDomain?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StudioDomain? create(Ref ref) {
    return studioDomain(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StudioDomain? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StudioDomain?>(value),
    );
  }
}

String _$studioDomainHash() => r'f89bbc05f72db034cb0738ae197f85af0850f14e';

@ProviderFor(StudioSelection)
final studioSelectionProvider = StudioSelectionProvider._();

final class StudioSelectionProvider
    extends $NotifierProvider<StudioSelection, StudioSel?> {
  StudioSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'studioSelectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$studioSelectionHash();

  @$internal
  @override
  StudioSelection create() => StudioSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StudioSel? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StudioSel?>(value),
    );
  }
}

String _$studioSelectionHash() => r'444da400f187d8f98b774b615be591e8a0ecf597';

abstract class _$StudioSelection extends $Notifier<StudioSel?> {
  StudioSel? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<StudioSel?, StudioSel?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<StudioSel?, StudioSel?>,
              StudioSel?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(StudioFile)
final studioFileProvider = StudioFileProvider._();

final class StudioFileProvider
    extends $NotifierProvider<StudioFile, StudioFileState> {
  StudioFileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'studioFileProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$studioFileHash();

  @$internal
  @override
  StudioFile create() => StudioFile();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StudioFileState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StudioFileState>(value),
    );
  }
}

String _$studioFileHash() => r'357083ea04e85f431f597b1bce6f3b54e3df2880';

abstract class _$StudioFile extends $Notifier<StudioFileState> {
  StudioFileState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<StudioFileState, StudioFileState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<StudioFileState, StudioFileState>,
              StudioFileState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Scrollstand je `"<modus>|<abschnitt>"` — reiner Sitzungszustand.

@ProviderFor(StudioScrollMemory)
final studioScrollMemoryProvider = StudioScrollMemoryProvider._();

/// Scrollstand je `"<modus>|<abschnitt>"` — reiner Sitzungszustand.
final class StudioScrollMemoryProvider
    extends $NotifierProvider<StudioScrollMemory, Object?> {
  /// Scrollstand je `"<modus>|<abschnitt>"` — reiner Sitzungszustand.
  StudioScrollMemoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'studioScrollMemoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$studioScrollMemoryHash();

  @$internal
  @override
  StudioScrollMemory create() => StudioScrollMemory();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Object? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Object?>(value),
    );
  }
}

String _$studioScrollMemoryHash() =>
    r'f647f7e579bf64300a6872b52b7e9e6a25d3740a';

/// Scrollstand je `"<modus>|<abschnitt>"` — reiner Sitzungszustand.

abstract class _$StudioScrollMemory extends $Notifier<Object?> {
  Object? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Object?, Object?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Object?, Object?>,
              Object?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
