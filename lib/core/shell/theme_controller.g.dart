// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Persistierter Theme-Zustand. Lesen ist asynchron (DB); bis dahin gilt
/// `auto` — sichtbar identisch mit dem Original, das vor dem ersten
/// `applyTheme` ebenfalls die System-Präferenz zeigt.

@ProviderFor(ThemeController)
final themeControllerProvider = ThemeControllerProvider._();

/// Persistierter Theme-Zustand. Lesen ist asynchron (DB); bis dahin gilt
/// `auto` — sichtbar identisch mit dem Original, das vor dem ersten
/// `applyTheme` ebenfalls die System-Präferenz zeigt.
final class ThemeControllerProvider
    extends $AsyncNotifierProvider<ThemeController, ThemeSetting> {
  /// Persistierter Theme-Zustand. Lesen ist asynchron (DB); bis dahin gilt
  /// `auto` — sichtbar identisch mit dem Original, das vor dem ersten
  /// `applyTheme` ebenfalls die System-Präferenz zeigt.
  ThemeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeControllerHash();

  @$internal
  @override
  ThemeController create() => ThemeController();
}

String _$themeControllerHash() => r'befc1272db4a39d1584b4a0520e792ffc07110b2';

/// Persistierter Theme-Zustand. Lesen ist asynchron (DB); bis dahin gilt
/// `auto` — sichtbar identisch mit dem Original, das vor dem ersten
/// `applyTheme` ebenfalls die System-Präferenz zeigt.

abstract class _$ThemeController extends $AsyncNotifier<ThemeSetting> {
  FutureOr<ThemeSetting> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ThemeSetting>, ThemeSetting>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ThemeSetting>, ThemeSetting>,
              AsyncValue<ThemeSetting>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
