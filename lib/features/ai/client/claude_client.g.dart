// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'claude_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Client-Provider — Tests übersteuern mit einer Fake-http-Factory.

@ProviderFor(claudeClient)
final claudeClientProvider = ClaudeClientProvider._();

/// Client-Provider — Tests übersteuern mit einer Fake-http-Factory.

final class ClaudeClientProvider
    extends $FunctionalProvider<ClaudeClient, ClaudeClient, ClaudeClient>
    with $Provider<ClaudeClient> {
  /// Client-Provider — Tests übersteuern mit einer Fake-http-Factory.
  ClaudeClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'claudeClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$claudeClientHash();

  @$internal
  @override
  $ProviderElement<ClaudeClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ClaudeClient create(Ref ref) {
    return claudeClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClaudeClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClaudeClient>(value),
    );
  }
}

String _$claudeClientHash() => r'da1e093da046a59994a65f939563d1e7893b18d6';
