/// Projekt-Fachzustand der Quellen-Welt — synchron lesbarer Schnappschuss
/// ALLER 26 PROJECT_KEYS mit Write-Through und Live-Kohärenz.
///
/// Warum alle 26: `Levels.exportState()` (⭳ Sichern) bündelt 22 Bereiche,
/// `Levels.importState()` (⭱ Laden) schreibt sie alle zurück — der
/// [DomainStore]-Adapter der Bibliothek muss deshalb den kompletten
/// Prüfstand sehen. Zusätzlich abonniert der Schnappschuss jeden Key per
/// `kv.watchJson` (Drift-Streams): Schreibt eine ANDERE Welt (Studio,
/// PDF-Marks, KI), zieht die Bibliothek automatisch nach — das Pendant zum
/// gemeinsamen localStorage des Originals.
///
/// §0-Pflicht (CONTRACTS): Writes an `paraEdits`/`fnEdits`/`titleEdits`
/// ziehen [textOverridesProvider] sofort nach.
library;

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/bundles/indexes.dart';
import '../../../data/db/kv.dart';
import '../../../data/models/models.dart';
import '../../../domain/domain.dart';
import '../../pdf/marks/pdf_marks_store.dart';

part 'quellen_kv.g.dart';

@Riverpod(keepAlive: true)
class QuellenKv extends _$QuellenKv {
  @override
  Future<Map<String, Object?>> build() async {
    // Projektwechsel (neue Runtime) lädt den Schnappschuss im neuen Scope.
    ref.watch(activeRuntimeProvider);
    final kv = ref.watch(kvStoreProvider);

    final out = <String, Object?>{};
    for (final key in KvKeys.projectKeys) {
      final v = await kv.getJson(key);
      if (v != null) out[key] = v;
    }

    // Live-Kohärenz: jede Fremd-Änderung (Studio, PDF-Marks, Boot-Import)
    // aktualisiert den Schnappschuss reaktiv.
    final subs = <StreamSubscription<Object?>>[
      for (final key in KvKeys.projectKeys)
        kv.watchJson(key).listen((v) => _onExternal(key, v)),
    ];
    ref.onDispose(() {
      for (final s in subs) {
        s.cancel();
      }
    });

    return out;
  }

  Map<String, Object?> get snapshot => state.value ?? const {};

  /// Fremd-Änderung einmischen (Stream-Event) — nur wenn der Wert sich
  /// tatsächlich vom Schnappschuss unterscheidet (die eigenen Writes kommen
  /// über den Stream zurück; identische Werte lösen kein Re-Render aus).
  void _onExternal(String key, Object? value) {
    final cur = state.value;
    if (cur == null) return;
    if (identical(cur[key], value)) return;
    final next = {...cur};
    if (value == null) {
      if (!next.containsKey(key)) return;
      next.remove(key);
    } else {
      next[key] = value;
    }
    state = AsyncData(next);
  }

  /// Schreiben mit Write-Through — und §0-Pflicht: Text-Overrides nachziehen.
  void put(String key, Object? value) {
    final next = {...snapshot};
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    state = AsyncData(next);
    final kv = ref.read(kvStoreProvider);
    if (value == null) {
      kv.remove(key);
    } else {
      kv.setJson(key, value);
    }
    if (key == KvKeys.paraEdits ||
        key == KvKeys.fnEdits ||
        key == KvKeys.titleEdits) {
      _syncOverrides(next);
    }
  }

  /// `textOverridesProvider` aus dem Schnappschuss speisen (CONTRACTS §0).
  void _syncOverrides(Map<String, Object?> snap) {
    Map<String, String> str(Object? v) => v is Map
        ? {
            for (final e in v.entries)
              if (e.value is String) '${e.key}': e.value as String,
          }
        : const {};
    final fn = <int, String>{};
    final rawFn = snap[KvKeys.fnEdits];
    if (rawFn is Map) {
      for (final e in rawFn.entries) {
        final num = int.tryParse('${e.key}');
        if (num != null && e.value is String) fn[num] = e.value as String;
      }
    }
    ref.read(textOverridesProvider.notifier).set(TextOverrideState(
          paraEdits: str(snap[KvKeys.paraEdits]),
          fnEdits: fn,
          titleEdits: str(snap[KvKeys.titleEdits]),
        ));
  }

  /// Typisierte Lesehilfe.
  Map<String, Object?> readMap(String key) {
    final v = snapshot[key];
    if (v is Map) return v.map((k, val) => MapEntry('$k', val));
    return const {};
  }
}

/// [DomainStore]-Adapter über den Schnappschuss: synchron lesen, Schreiben
/// läuft durch [QuellenKv.put] (Write-Through + Invalidierung + §0).
class QuellenDomainStore implements DomainStore {
  final Map<String, Object?> _snapshot;
  final QuellenKv _notifier;

  QuellenDomainStore(this._snapshot, this._notifier);

  @override
  Object? read(String key) => _snapshot[key];

  @override
  void write(String key, Object? value) => _notifier.put(key, value);
}

// ---------------------------------------------------------------------------
// Link-Overrides (U.setSrcLink-Pendant)
// ---------------------------------------------------------------------------

/// `U.setSrcLink(srcId, kind, url)` (util.js:248-255): leerer Wert löscht
/// den Override; ein leer gewordenes Quell-Objekt fliegt ganz aus der Map.
Future<void> setSrcLink(KvStore kv, String srcId, String kind, String? url) async {
  final all = Map<String, dynamic>.from(await kv.getMap(KvKeys.linkOverrides));
  final entryRaw = all[srcId];
  final entry = entryRaw is Map
      ? entryRaw.map((k, v) => MapEntry('$k', v))
      : <String, Object?>{};
  final v = url?.trim() ?? '';
  if (v.isEmpty) {
    entry.remove(kind);
  } else {
    entry[kind] = v;
  }
  if (entry.isEmpty) {
    all.remove(srcId);
  } else {
    all[srcId] = entry;
  }
  await kv.setJson(KvKeys.linkOverrides, all);
}

// ---------------------------------------------------------------------------
// Domänen-Sicht der Bibliothek
// ---------------------------------------------------------------------------

/// Gebündelte Domänen-Objekte der Quellen-Welt — je Schnappschuss/Runtime
/// EIN Satz (Pendant zu den Globals Levels/Mentions + DATA_SOURCES).
class QuellenDomain {
  final DomainContext ctx;
  final Levels levels;
  final Mentions mentions;
  final ThesisRuntime runtime;

  /// srcNotes-Map (Smart-Filter „✎ Mit Notizen" — `U.getNote`-Basis).
  final Map<String, Object?> srcNotes;

  /// srcTexts-Map (Sektion „Text der Quelle").
  final Map<String, Object?> srcTexts;

  /// resolutions-Map (Auto-Übernahme-Prüfung, ✦ Durchlauf).
  final Map<String, Object?> resolutions;

  QuellenDomain({
    required this.ctx,
    required this.levels,
    required this.mentions,
    required this.runtime,
    required this.srcNotes,
    required this.srcTexts,
    required this.resolutions,
  });

  /// Quellen in Bundle-Reihenfolge (`window.DATA_SOURCES`).
  List<Source> get sources => ctx.sources;

  /// Hinterlegter Quellentext (`U.getSrcText`) — '' wenn keiner.
  String srcText(String srcId) {
    final v = srcTexts[srcId];
    return v is String ? v : '';
  }

  /// Eigene Notiz (`U.getNote`) — '' wenn keine.
  String note(String srcId) {
    final v = srcNotes[srcId];
    return v is String ? v : '';
  }
}

@Riverpod(keepAlive: true)
QuellenDomain? quellenDomain(Ref ref) {
  final runtime = ref.watch(activeRuntimeProvider);
  final thesis = ref.watch(effectiveThesisProvider);
  if (runtime == null || thesis == null) return null;

  final snapshot = ref.watch(quellenKvProvider).value ?? const <String, Object?>{};
  final store = QuellenDomainStore(snapshot, ref.read(quellenKvProvider.notifier));

  final ctx = DomainContext(
    thesis: thesis,
    unitIndex: ref.watch(unitIndexProvider),
    fnIndex: ref.watch(fnIndexProvider),
    sources: runtime.sources,
    srcById: ref.watch(srcByIdProvider),
    orderedUnitIds: ref.watch(orderedUnitsProvider),
    sections: runtime.sections,
    meta: runtime.meta,
  );

  Map<String, Object?> map(String key) {
    final v = snapshot[key];
    return v is Map ? v.map((k, val) => MapEntry('$k', val)) : const {};
  }

  return QuellenDomain(
    ctx: ctx,
    // Die PDF-Markierungs-Stufe der Levels-Kaskade hängt an S-1
    // (CONTRACTS §13.4) — solange der Marks-Store lädt, bleibt sie aus.
    levels: Levels(ctx, store, marksForFn: ref.watch(levelsMarksForFnProvider)),
    mentions: Mentions(ctx, store),
    runtime: runtime,
    srcNotes: map(KvKeys.srcNotes),
    srcTexts: map(KvKeys.srcTexts),
    resolutions: map(KvKeys.resolutions),
  );
}
