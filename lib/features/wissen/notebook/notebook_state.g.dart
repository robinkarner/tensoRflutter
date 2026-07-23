// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notebook_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `Notebook.get()`/`Notebook.set(md)` — null = kein eigenes Buch.

@ProviderFor(NotebookStore)
final notebookStoreProvider = NotebookStoreProvider._();

/// `Notebook.get()`/`Notebook.set(md)` — null = kein eigenes Buch.
final class NotebookStoreProvider
    extends $AsyncNotifierProvider<NotebookStore, String?> {
  /// `Notebook.get()`/`Notebook.set(md)` — null = kein eigenes Buch.
  NotebookStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notebookStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notebookStoreHash();

  @$internal
  @override
  NotebookStore create() => NotebookStore();
}

String _$notebookStoreHash() => r'2a7ca50e80985a18488d9b6bd100aea64f54865f';

/// `Notebook.get()`/`Notebook.set(md)` — null = kein eigenes Buch.

abstract class _$NotebookStore extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(erklaerbuchSource)
final erklaerbuchSourceProvider = ErklaerbuchSourceProvider._();

final class ErklaerbuchSourceProvider
    extends
        $FunctionalProvider<
          ErklaerbuchSource,
          ErklaerbuchSource,
          ErklaerbuchSource
        >
    with $Provider<ErklaerbuchSource> {
  ErklaerbuchSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'erklaerbuchSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$erklaerbuchSourceHash();

  @$internal
  @override
  $ProviderElement<ErklaerbuchSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ErklaerbuchSource create(Ref ref) {
    return erklaerbuchSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ErklaerbuchSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ErklaerbuchSource>(value),
    );
  }
}

String _$erklaerbuchSourceHash() => r'e0399fd8ed8a909f2599055d7e45fb0a2a409122';

/// Echte Zahlen der aktiven Arbeit — Grundlage der Rechenzellen (E4: nur
/// noch fürs 🤖-Prompt-Paket) und des Generier-Prompts.

@ProviderFor(notebookDataset)
final notebookDatasetProvider = NotebookDatasetProvider._();

/// Echte Zahlen der aktiven Arbeit — Grundlage der Rechenzellen (E4: nur
/// noch fürs 🤖-Prompt-Paket) und des Generier-Prompts.

final class NotebookDatasetProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, Object?>>,
          Map<String, Object?>,
          FutureOr<Map<String, Object?>>
        >
    with
        $FutureModifier<Map<String, Object?>>,
        $FutureProvider<Map<String, Object?>> {
  /// Echte Zahlen der aktiven Arbeit — Grundlage der Rechenzellen (E4: nur
  /// noch fürs 🤖-Prompt-Paket) und des Generier-Prompts.
  NotebookDatasetProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notebookDatasetProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notebookDatasetHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, Object?>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, Object?>> create(Ref ref) {
    return notebookDataset(ref);
  }
}

String _$notebookDatasetHash() => r'314c9b23a5a33dc9c78ce05b26118c7128db55ba';
