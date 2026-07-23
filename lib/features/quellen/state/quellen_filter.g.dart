// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quellen_filter.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(QuellenFilterCtl)
final quellenFilterCtlProvider = QuellenFilterCtlProvider._();

final class QuellenFilterCtlProvider
    extends $AsyncNotifierProvider<QuellenFilterCtl, QuellenFilter> {
  QuellenFilterCtlProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'quellenFilterCtlProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$quellenFilterCtlHash();

  @$internal
  @override
  QuellenFilterCtl create() => QuellenFilterCtl();
}

String _$quellenFilterCtlHash() => r'aad97f6b4009476c81e136871886ec0acfddeee2';

abstract class _$QuellenFilterCtl extends $AsyncNotifier<QuellenFilter> {
  FutureOr<QuellenFilter> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<QuellenFilter>, QuellenFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<QuellenFilter>, QuellenFilter>,
              AsyncValue<QuellenFilter>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
