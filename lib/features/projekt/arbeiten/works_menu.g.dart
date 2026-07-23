// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'works_menu.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Instanz-Liste aus der DB (`Projects.list()`); der Boot-Watch lädt sie
/// nach jedem Projektwechsel/Reboot frisch. keepAlive, weil das Menü
/// mehrmals pro Sitzung auf- und zugeht (Popover wird je Öffnung neu
/// gebaut — Original zeichnet die Karte ebenfalls je Öffnung neu).

@ProviderFor(worksList)
final worksListProvider = WorksListProvider._();

/// Instanz-Liste aus der DB (`Projects.list()`); der Boot-Watch lädt sie
/// nach jedem Projektwechsel/Reboot frisch. keepAlive, weil das Menü
/// mehrmals pro Sitzung auf- und zugeht (Popover wird je Öffnung neu
/// gebaut — Original zeichnet die Karte ebenfalls je Öffnung neu).

final class WorksListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ProjectRecord>>,
          List<ProjectRecord>,
          FutureOr<List<ProjectRecord>>
        >
    with
        $FutureModifier<List<ProjectRecord>>,
        $FutureProvider<List<ProjectRecord>> {
  /// Instanz-Liste aus der DB (`Projects.list()`); der Boot-Watch lädt sie
  /// nach jedem Projektwechsel/Reboot frisch. keepAlive, weil das Menü
  /// mehrmals pro Sitzung auf- und zugeht (Popover wird je Öffnung neu
  /// gebaut — Original zeichnet die Karte ebenfalls je Öffnung neu).
  WorksListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'worksListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$worksListHash();

  @$internal
  @override
  $FutureProviderElement<List<ProjectRecord>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ProjectRecord>> create(Ref ref) {
    return worksList(ref);
  }
}

String _$worksListHash() => r'bce5d5610c9baf10c6b16c1fd588e121d9118fce';
