// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assign_panel_data.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AssignPanelData)
final assignPanelDataProvider = AssignPanelDataFamily._();

final class AssignPanelDataProvider
    extends $AsyncNotifierProvider<AssignPanelData, AssignPanelState> {
  AssignPanelDataProvider._({
    required AssignPanelDataFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'assignPanelDataProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$assignPanelDataHash();

  @override
  String toString() {
    return r'assignPanelDataProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AssignPanelData create() => AssignPanelData();

  @override
  bool operator ==(Object other) {
    return other is AssignPanelDataProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$assignPanelDataHash() => r'876f1437bf3decbe614a40f7a72dfa1cdcd04426';

final class AssignPanelDataFamily extends $Family
    with
        $ClassFamilyOverride<
          AssignPanelData,
          AsyncValue<AssignPanelState>,
          AssignPanelState,
          FutureOr<AssignPanelState>,
          String
        > {
  AssignPanelDataFamily._()
    : super(
        retry: null,
        name: r'assignPanelDataProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AssignPanelDataProvider call(String srcId) =>
      AssignPanelDataProvider._(argument: srcId, from: this);

  @override
  String toString() => r'assignPanelDataProvider';
}

abstract class _$AssignPanelData extends $AsyncNotifier<AssignPanelState> {
  late final _$args = ref.$arg as String;
  String get srcId => _$args;

  FutureOr<AssignPanelState> build(String srcId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<AssignPanelState>, AssignPanelState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AssignPanelState>, AssignPanelState>,
              AsyncValue<AssignPanelState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
