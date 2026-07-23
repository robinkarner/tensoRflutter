// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'indexes.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Die Daten der aktiven Arbeit. `null` bedeutet "Boot noch nicht fertig" —
/// alle abgeleiteten Indizes liefern dann leere Strukturen (das Original
/// ist mit `window.DATA_* || []` genauso null-tolerant).
///
/// Boot (F-E) lädt das Bundle und ruft [activate]; ein Projektwechsel
/// (spätere Wellen) aktiviert die Runtime des neuen Records.

@ProviderFor(ActiveRuntime)
final activeRuntimeProvider = ActiveRuntimeProvider._();

/// Die Daten der aktiven Arbeit. `null` bedeutet "Boot noch nicht fertig" —
/// alle abgeleiteten Indizes liefern dann leere Strukturen (das Original
/// ist mit `window.DATA_* || []` genauso null-tolerant).
///
/// Boot (F-E) lädt das Bundle und ruft [activate]; ein Projektwechsel
/// (spätere Wellen) aktiviert die Runtime des neuen Records.
final class ActiveRuntimeProvider
    extends $NotifierProvider<ActiveRuntime, ThesisRuntime?> {
  /// Die Daten der aktiven Arbeit. `null` bedeutet "Boot noch nicht fertig" —
  /// alle abgeleiteten Indizes liefern dann leere Strukturen (das Original
  /// ist mit `window.DATA_* || []` genauso null-tolerant).
  ///
  /// Boot (F-E) lädt das Bundle und ruft [activate]; ein Projektwechsel
  /// (spätere Wellen) aktiviert die Runtime des neuen Records.
  ActiveRuntimeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeRuntimeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeRuntimeHash();

  @$internal
  @override
  ActiveRuntime create() => ActiveRuntime();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThesisRuntime? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThesisRuntime?>(value),
    );
  }
}

String _$activeRuntimeHash() => r'73a115f34507d3589af2ec45744fe3ba3d495f75';

/// Die Daten der aktiven Arbeit. `null` bedeutet "Boot noch nicht fertig" —
/// alle abgeleiteten Indizes liefern dann leere Strukturen (das Original
/// ist mit `window.DATA_* || []` genauso null-tolerant).
///
/// Boot (F-E) lädt das Bundle und ruft [activate]; ein Projektwechsel
/// (spätere Wellen) aktiviert die Runtime des neuen Records.

abstract class _$ActiveRuntime extends $Notifier<ThesisRuntime?> {
  ThesisRuntime? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ThesisRuntime?, ThesisRuntime?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThesisRuntime?, ThesisRuntime?>,
              ThesisRuntime?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Welle 0 liefert leere Overrides; die KV-Schicht (F-C) lädt hier die
/// gespeicherten Edits des aktiven Projekts hinein (und bei jedem Edit neu).

@ProviderFor(TextOverrides)
final textOverridesProvider = TextOverridesProvider._();

/// Welle 0 liefert leere Overrides; die KV-Schicht (F-C) lädt hier die
/// gespeicherten Edits des aktiven Projekts hinein (und bei jedem Edit neu).
final class TextOverridesProvider
    extends $NotifierProvider<TextOverrides, TextOverrideState> {
  /// Welle 0 liefert leere Overrides; die KV-Schicht (F-C) lädt hier die
  /// gespeicherten Edits des aktiven Projekts hinein (und bei jedem Edit neu).
  TextOverridesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'textOverridesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$textOverridesHash();

  @$internal
  @override
  TextOverrides create() => TextOverrides();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TextOverrideState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TextOverrideState>(value),
    );
  }
}

String _$textOverridesHash() => r'21b00fb4ce0ac7dbd4e2155a2ebe45e59751e267';

/// Welle 0 liefert leere Overrides; die KV-Schicht (F-C) lädt hier die
/// gespeicherten Edits des aktiven Projekts hinein (und bei jedem Edit neu).

abstract class _$TextOverrides extends $Notifier<TextOverrideState> {
  TextOverrideState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TextOverrideState, TextOverrideState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TextOverrideState, TextOverrideState>,
              TextOverrideState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Struktur der aktiven Arbeit MIT angewandten Overrides. Das ist die
/// Sicht, die alle Views konsumieren — das "↺ Original wiederherstellen"
/// des Originals entspricht hier schlicht dem Entfernen des Overrides
/// (die unveränderte Runtime hält immer das Original).

@ProviderFor(effectiveThesis)
final effectiveThesisProvider = EffectiveThesisProvider._();

/// Struktur der aktiven Arbeit MIT angewandten Overrides. Das ist die
/// Sicht, die alle Views konsumieren — das "↺ Original wiederherstellen"
/// des Originals entspricht hier schlicht dem Entfernen des Overrides
/// (die unveränderte Runtime hält immer das Original).

final class EffectiveThesisProvider
    extends $FunctionalProvider<Thesis?, Thesis?, Thesis?>
    with $Provider<Thesis?> {
  /// Struktur der aktiven Arbeit MIT angewandten Overrides. Das ist die
  /// Sicht, die alle Views konsumieren — das "↺ Original wiederherstellen"
  /// des Originals entspricht hier schlicht dem Entfernen des Overrides
  /// (die unveränderte Runtime hält immer das Original).
  EffectiveThesisProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'effectiveThesisProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$effectiveThesisHash();

  @$internal
  @override
  $ProviderElement<Thesis?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Thesis? create(Ref ref) {
    return effectiveThesis(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Thesis? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Thesis?>(value),
    );
  }
}

String _$effectiveThesisHash() => r'21a026d2b3bf274f47cec3b79de68cf33ca28aec';

/// UNIT_INDEX: sectionId → {unit, chapter} über alle Ebenen (rekursiv
/// inkl. children), auf Basis der effektiven Sicht.

@ProviderFor(unitIndex)
final unitIndexProvider = UnitIndexProvider._();

/// UNIT_INDEX: sectionId → {unit, chapter} über alle Ebenen (rekursiv
/// inkl. children), auf Basis der effektiven Sicht.

final class UnitIndexProvider
    extends $FunctionalProvider<UnitIndex, UnitIndex, UnitIndex>
    with $Provider<UnitIndex> {
  /// UNIT_INDEX: sectionId → {unit, chapter} über alle Ebenen (rekursiv
  /// inkl. children), auf Basis der effektiven Sicht.
  UnitIndexProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unitIndexProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unitIndexHash();

  @$internal
  @override
  $ProviderElement<UnitIndex> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UnitIndex create(Ref ref) {
    return unitIndex(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UnitIndex value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UnitIndex>(value),
    );
  }
}

String _$unitIndexHash() => r'0a1d2fccddd3a53f2963a5a492341914e72eb413';

/// Reihenfolge aller Abschnitte MIT Absätzen (DFS) — Pendant zu
/// `orderedUnits()` (util.js:1005-1013); Basis für Vor/Zurück-Navigation,
/// Router-Fallbacks und die Command-Palette.

@ProviderFor(orderedUnits)
final orderedUnitsProvider = OrderedUnitsProvider._();

/// Reihenfolge aller Abschnitte MIT Absätzen (DFS) — Pendant zu
/// `orderedUnits()` (util.js:1005-1013); Basis für Vor/Zurück-Navigation,
/// Router-Fallbacks und die Command-Palette.

final class OrderedUnitsProvider
    extends $FunctionalProvider<List<String>, List<String>, List<String>>
    with $Provider<List<String>> {
  /// Reihenfolge aller Abschnitte MIT Absätzen (DFS) — Pendant zu
  /// `orderedUnits()` (util.js:1005-1013); Basis für Vor/Zurück-Navigation,
  /// Router-Fallbacks und die Command-Palette.
  OrderedUnitsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'orderedUnitsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$orderedUnitsHash();

  @$internal
  @override
  $ProviderElement<List<String>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<String> create(Ref ref) {
    return orderedUnits(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$orderedUnitsHash() => r'a61b9bd280fcfc2cd17e8a26a0e5bdc5890c2087';

/// FN_INDEX: globale Fußnotennummer → Fußnote mit Fundort.

@ProviderFor(fnIndex)
final fnIndexProvider = FnIndexProvider._();

/// FN_INDEX: globale Fußnotennummer → Fußnote mit Fundort.

final class FnIndexProvider
    extends
        $FunctionalProvider<
          Map<int, FnIndexEntry>,
          Map<int, FnIndexEntry>,
          Map<int, FnIndexEntry>
        >
    with $Provider<Map<int, FnIndexEntry>> {
  /// FN_INDEX: globale Fußnotennummer → Fußnote mit Fundort.
  FnIndexProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fnIndexProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fnIndexHash();

  @$internal
  @override
  $ProviderElement<Map<int, FnIndexEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<int, FnIndexEntry> create(Ref ref) {
    return fnIndex(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<int, FnIndexEntry> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<int, FnIndexEntry>>(value),
    );
  }
}

String _$fnIndexHash() => r'54c77c3450fa0c5ff464b5fc2a04c781841af811';

/// Beleg zu einer Fußnote finden — Pendant zu `U.findBeleg` (util.js:614-623):
/// über den Fundort der Fußnote in die Section-Analyse und dort in die
/// belege-Liste des Absatzes.

@ProviderFor(findBeleg)
final findBelegProvider = FindBelegFamily._();

/// Beleg zu einer Fußnote finden — Pendant zu `U.findBeleg` (util.js:614-623):
/// über den Fundort der Fußnote in die Section-Analyse und dort in die
/// belege-Liste des Absatzes.

final class FindBelegProvider
    extends $FunctionalProvider<Beleg?, Beleg?, Beleg?>
    with $Provider<Beleg?> {
  /// Beleg zu einer Fußnote finden — Pendant zu `U.findBeleg` (util.js:614-623):
  /// über den Fundort der Fußnote in die Section-Analyse und dort in die
  /// belege-Liste des Absatzes.
  FindBelegProvider._({
    required FindBelegFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'findBelegProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$findBelegHash();

  @override
  String toString() {
    return r'findBelegProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<Beleg?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Beleg? create(Ref ref) {
    final argument = this.argument as int;
    return findBeleg(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Beleg? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Beleg?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FindBelegProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$findBelegHash() => r'03ff9ac833d36b73f7d5973d27460194a757db39';

/// Beleg zu einer Fußnote finden — Pendant zu `U.findBeleg` (util.js:614-623):
/// über den Fundort der Fußnote in die Section-Analyse und dort in die
/// belege-Liste des Absatzes.

final class FindBelegFamily extends $Family
    with $FunctionalFamilyOverride<Beleg?, int> {
  FindBelegFamily._()
    : super(
        retry: null,
        name: r'findBelegProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Beleg zu einer Fußnote finden — Pendant zu `U.findBeleg` (util.js:614-623):
  /// über den Fundort der Fußnote in die Section-Analyse und dort in die
  /// belege-Liste des Absatzes.

  FindBelegProvider call(int num) =>
      FindBelegProvider._(argument: num, from: this);

  @override
  String toString() => r'findBelegProvider';
}

/// SRC_BY_ID: Quellen-Index der aktiven Arbeit.

@ProviderFor(srcById)
final srcByIdProvider = SrcByIdProvider._();

/// SRC_BY_ID: Quellen-Index der aktiven Arbeit.

final class SrcByIdProvider
    extends
        $FunctionalProvider<
          Map<String, Source>,
          Map<String, Source>,
          Map<String, Source>
        >
    with $Provider<Map<String, Source>> {
  /// SRC_BY_ID: Quellen-Index der aktiven Arbeit.
  SrcByIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'srcByIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$srcByIdHash();

  @$internal
  @override
  $ProviderElement<Map<String, Source>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<String, Source> create(Ref ref) {
    return srcById(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, Source> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, Source>>(value),
    );
  }
}

String _$srcByIdHash() => r'db1e13cede641fb1e374ea819e1e2bf713720a40';

/// FIG_BY_PARA: Abbildungen nach Anker-Absatz.

@ProviderFor(figByPara)
final figByParaProvider = FigByParaProvider._();

/// FIG_BY_PARA: Abbildungen nach Anker-Absatz.

final class FigByParaProvider
    extends
        $FunctionalProvider<
          Map<String, Figur>,
          Map<String, Figur>,
          Map<String, Figur>
        >
    with $Provider<Map<String, Figur>> {
  /// FIG_BY_PARA: Abbildungen nach Anker-Absatz.
  FigByParaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'figByParaProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$figByParaHash();

  @$internal
  @override
  $ProviderElement<Map<String, Figur>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<String, Figur> create(Ref ref) {
    return figByPara(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, Figur> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, Figur>>(value),
    );
  }
}

String _$figByParaHash() => r'4a87e299129f38f427cd4d2b99ed56c1280e2986';

/// TAB_BY_PARA: Tabellen nach Anker-Absatz.

@ProviderFor(tabByPara)
final tabByParaProvider = TabByParaProvider._();

/// TAB_BY_PARA: Tabellen nach Anker-Absatz.

final class TabByParaProvider
    extends
        $FunctionalProvider<
          Map<String, Tabelle>,
          Map<String, Tabelle>,
          Map<String, Tabelle>
        >
    with $Provider<Map<String, Tabelle>> {
  /// TAB_BY_PARA: Tabellen nach Anker-Absatz.
  TabByParaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tabByParaProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tabByParaHash();

  @$internal
  @override
  $ProviderElement<Map<String, Tabelle>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<String, Tabelle> create(Ref ref) {
    return tabByPara(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, Tabelle> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, Tabelle>>(value),
    );
  }
}

String _$tabByParaHash() => r'98603308c850f8eb164f111b9ad9e37fdf5eaf21';

/// srcShort als Provider-Familie — der Ersatz für den `U._shortCache`
/// (Riverpod cached je id; ein Runtime-Wechsel invalidiert automatisch,
/// womit der Stale-Cache des Originals gleich mit gefixt ist).

@ProviderFor(srcShort)
final srcShortProvider = SrcShortFamily._();

/// srcShort als Provider-Familie — der Ersatz für den `U._shortCache`
/// (Riverpod cached je id; ein Runtime-Wechsel invalidiert automatisch,
/// womit der Stale-Cache des Originals gleich mit gefixt ist).

final class SrcShortProvider extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// srcShort als Provider-Familie — der Ersatz für den `U._shortCache`
  /// (Riverpod cached je id; ein Runtime-Wechsel invalidiert automatisch,
  /// womit der Stale-Cache des Originals gleich mit gefixt ist).
  SrcShortProvider._({
    required SrcShortFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'srcShortProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$srcShortHash();

  @override
  String toString() {
    return r'srcShortProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    final argument = this.argument as String;
    return srcShort(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SrcShortProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$srcShortHash() => r'b7554fa39e842911c05cb844af7064a26633e60b';

/// srcShort als Provider-Familie — der Ersatz für den `U._shortCache`
/// (Riverpod cached je id; ein Runtime-Wechsel invalidiert automatisch,
/// womit der Stale-Cache des Originals gleich mit gefixt ist).

final class SrcShortFamily extends $Family
    with $FunctionalFamilyOverride<String, String> {
  SrcShortFamily._()
    : super(
        retry: null,
        name: r'srcShortProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// srcShort als Provider-Familie — der Ersatz für den `U._shortCache`
  /// (Riverpod cached je id; ein Runtime-Wechsel invalidiert automatisch,
  /// womit der Stale-Cache des Originals gleich mit gefixt ist).

  SrcShortProvider call(String srcId) =>
      SrcShortProvider._(argument: srcId, from: this);

  @override
  String toString() => r'srcShortProvider';
}
