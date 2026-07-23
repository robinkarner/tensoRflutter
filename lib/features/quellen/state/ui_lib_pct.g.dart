// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ui_lib_pct.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UiLibPct)
final uiLibPctProvider = UiLibPctProvider._();

final class UiLibPctProvider extends $AsyncNotifierProvider<UiLibPct, int?> {
  UiLibPctProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'uiLibPctProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$uiLibPctHash();

  @$internal
  @override
  UiLibPct create() => UiLibPct();
}

String _$uiLibPctHash() => r'4b6e442261bac6ebafd872261e772b42423d93b0';

abstract class _$UiLibPct extends $AsyncNotifier<int?> {
  FutureOr<int?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<int?>, int?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<int?>, int?>,
              AsyncValue<int?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
