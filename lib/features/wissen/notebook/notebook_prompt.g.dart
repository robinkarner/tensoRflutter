// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notebook_prompt.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(notebookPrompt)
final notebookPromptProvider = NotebookPromptProvider._();

final class NotebookPromptProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  NotebookPromptProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notebookPromptProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notebookPromptHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return notebookPrompt(ref);
  }
}

String _$notebookPromptHash() => r'815d8cba2e20c427cb8ea20723a66b8d4ef6567e';
