// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Gesamter App-Boot: Dateispeicher → Projekt-Boot. Liefert das
/// [BootResult] (Runtime, Name, Warnungen) für Titel/Topbar.

@ProviderFor(appBoot)
final appBootProvider = AppBootProvider._();

/// Gesamter App-Boot: Dateispeicher → Projekt-Boot. Liefert das
/// [BootResult] (Runtime, Name, Warnungen) für Titel/Topbar.

final class AppBootProvider
    extends
        $FunctionalProvider<
          AsyncValue<BootResult>,
          BootResult,
          FutureOr<BootResult>
        >
    with $FutureModifier<BootResult>, $FutureProvider<BootResult> {
  /// Gesamter App-Boot: Dateispeicher → Projekt-Boot. Liefert das
  /// [BootResult] (Runtime, Name, Warnungen) für Titel/Topbar.
  AppBootProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appBootProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appBootHash();

  @$internal
  @override
  $FutureProviderElement<BootResult> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<BootResult> create(Ref ref) {
    return appBoot(ref);
  }
}

String _$appBootHash() => r'e974ff621bda219730250ca9c7355f8edfedffc5';
