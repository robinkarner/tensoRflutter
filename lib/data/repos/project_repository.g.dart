// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Das Repository als Provider.

@ProviderFor(projectRepository)
final projectRepositoryProvider = ProjectRepositoryProvider._();

/// Das Repository als Provider.

final class ProjectRepositoryProvider
    extends
        $FunctionalProvider<
          ProjectRepository,
          ProjectRepository,
          ProjectRepository
        >
    with $Provider<ProjectRepository> {
  /// Das Repository als Provider.
  ProjectRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProjectRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProjectRepository create(Ref ref) {
    return projectRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectRepository>(value),
    );
  }
}

String _$projectRepositoryHash() => r'68c5f9386c2dd3d3d00b4292ea88ce251d7a6516';

/// Der Boot-Fluss als Provider: Bundle laden → Repository booten →
/// Runtime + Overrides in die Daten-Notifier der Index-Schicht einspielen.
/// main.dart (F-E) wartet auf `projectBootProvider.future`, bevor die
/// Shell rendert.
///
/// **Reboot statt reload (E8):** [reboot] invalidiert diesen Knoten —
/// build() läuft komplett neu (liest den frischen activeProject-Key,
/// scoped den KV-Store um, baut die Runtime) und ersetzt die ActiveRuntime;
/// alle abgeleiteten Indizes/Provider bauen sich reaktiv neu auf.

@ProviderFor(ProjectBoot)
final projectBootProvider = ProjectBootProvider._();

/// Der Boot-Fluss als Provider: Bundle laden → Repository booten →
/// Runtime + Overrides in die Daten-Notifier der Index-Schicht einspielen.
/// main.dart (F-E) wartet auf `projectBootProvider.future`, bevor die
/// Shell rendert.
///
/// **Reboot statt reload (E8):** [reboot] invalidiert diesen Knoten —
/// build() läuft komplett neu (liest den frischen activeProject-Key,
/// scoped den KV-Store um, baut die Runtime) und ersetzt die ActiveRuntime;
/// alle abgeleiteten Indizes/Provider bauen sich reaktiv neu auf.
final class ProjectBootProvider
    extends $AsyncNotifierProvider<ProjectBoot, BootResult> {
  /// Der Boot-Fluss als Provider: Bundle laden → Repository booten →
  /// Runtime + Overrides in die Daten-Notifier der Index-Schicht einspielen.
  /// main.dart (F-E) wartet auf `projectBootProvider.future`, bevor die
  /// Shell rendert.
  ///
  /// **Reboot statt reload (E8):** [reboot] invalidiert diesen Knoten —
  /// build() läuft komplett neu (liest den frischen activeProject-Key,
  /// scoped den KV-Store um, baut die Runtime) und ersetzt die ActiveRuntime;
  /// alle abgeleiteten Indizes/Provider bauen sich reaktiv neu auf.
  ProjectBootProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectBootProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectBootHash();

  @$internal
  @override
  ProjectBoot create() => ProjectBoot();
}

String _$projectBootHash() => r'2e2549ee1e158f95d6ba925320fa2b0dc25faace';

/// Der Boot-Fluss als Provider: Bundle laden → Repository booten →
/// Runtime + Overrides in die Daten-Notifier der Index-Schicht einspielen.
/// main.dart (F-E) wartet auf `projectBootProvider.future`, bevor die
/// Shell rendert.
///
/// **Reboot statt reload (E8):** [reboot] invalidiert diesen Knoten —
/// build() läuft komplett neu (liest den frischen activeProject-Key,
/// scoped den KV-Store um, baut die Runtime) und ersetzt die ActiveRuntime;
/// alle abgeleiteten Indizes/Provider bauen sich reaktiv neu auf.

abstract class _$ProjectBoot extends $AsyncNotifier<BootResult> {
  FutureOr<BootResult> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<BootResult>, BootResult>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<BootResult>, BootResult>,
              AsyncValue<BootResult>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
