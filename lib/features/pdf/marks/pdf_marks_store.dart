/// Marks-Persistenz — Port der `PdfEngine.marks/addMark/updateMark/
/// removeMark/marksForFn`-API (pdfengine.js:197-221) auf den KV-Key
/// `pdfMarks` (projekt-gescoped).
///
/// Der Store hält den kompletten Key im Speicher (Form `{srcId: Mark[]}`,
/// 1:1 wie das Original — bestehende Web-App-Daten sind ohne Migration
/// gültig) und schreibt bei jeder Änderung zurück. Alle Viewer-Overlays
/// watchen den Provider und zeichnen reaktiv neu (das `refreshMarks()` des
/// Originals entfällt als expliziter Schritt).
///
/// **Levels-Verdrahtung (Gate-0-Risiko 5 / CONTRACTS §13.4):**
/// [levelsMarksForFnProvider] liefert die `MarksForFn`-Funktion für den
/// `Levels`-Konstruktor — S-2/S-3/S-4 hängen sie ein:
/// ```dart
/// Levels(ctx, store, marksForFn: ref.watch(levelsMarksForFnProvider))
/// ```
library;

import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/db/kv.dart';
import '../../../data/repos/project_repository.dart';
import '../../../domain/levels.dart';
import 'pdf_mark.dart';

part 'pdf_marks_store.g.dart';

/// Zustand: srcId → Markierungsliste (rohe JSON-Wahrheit in den Marks).
typedef PdfMarksState = Map<String, List<PdfMark>>;

@Riverpod(keepAlive: true)
class PdfMarks extends _$PdfMarks {
  final Random _rng = Random();

  @override
  Future<PdfMarksState> build() async {
    // Nach jedem (Re-)Boot neu laden — der KV-Scope kann gewechselt haben.
    await ref.watch(projectBootProvider.future);
    final all = await ref.read(kvStoreProvider).getMap(KvKeys.pdfMarks);
    return {
      for (final e in all.entries)
        e.key: [
          for (final m in (e.value is List ? e.value as List : const []))
            if (m is Map) PdfMark(m.map((k, v) => MapEntry(k.toString(), v))),
        ],
    };
  }

  PdfMarksState get _current => state.value ?? const {};

  /// Markierungen einer Quelle (leere Liste solange der Store lädt).
  List<PdfMark> marks(String srcId) => _current[srcId] ?? const [];

  /// Marks einer Fußnote — `Number(m.fn) === Number(fn)` (pdfengine.js:221).
  List<PdfMark> marksForFn(String srcId, int fn) =>
      [for (final m in marks(srcId)) if (m.fn == fn) m];

  /// Markierung anlegen: id `'m'+ts36+rand3` + ts (pdfengine.js:204-210).
  PdfMark addMark(String srcId, PdfMark mark) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = asNonEmpty(mark.json['id']) ??
        'm${now.toRadixString(36)}${_rand3()}';
    final complete = mark.patched({'id': id, 'ts': now});
    _mutate(srcId, (list) => [...list, complete]);
    return complete;
  }

  /// Patch per flachem Mischen (`Object.assign`, pdfengine.js:212-217).
  PdfMark? updateMark(String srcId, String id, Map<String, Object?> patch) {
    PdfMark? updated;
    _mutate(srcId, (list) => [
          for (final m in list) m.id == id ? updated = m.patched(patch) : m,
        ]);
    return updated;
  }

  void removeMark(String srcId, String id) =>
      _mutate(srcId, (list) => [for (final m in list) if (m.id != id) m]);

  // --- intern ---

  String _rand3() {
    // Math.random().toString(36).slice(2, 5) — 3 base36-Zeichen.
    final b = StringBuffer();
    for (var i = 0; i < 3; i++) {
      b.write(_rng.nextInt(36).toRadixString(36));
    }
    return b.toString();
  }

  void _mutate(String srcId, List<PdfMark> Function(List<PdfMark>) fn) {
    final next = Map<String, List<PdfMark>>.from(_current);
    final list = fn(next[srcId] ?? const []);
    // Leere Listen werden aus dem Objekt gelöscht (pdfengine.js:201).
    if (list.isEmpty) {
      next.remove(srcId);
    } else {
      next[srcId] = list;
    }
    state = AsyncData(next);
    _persist(next);
  }

  Future<void> _persist(PdfMarksState snapshot) =>
      ref.read(kvStoreProvider).setJson(KvKeys.pdfMarks, {
        for (final e in snapshot.entries) e.key: [for (final m in e.value) m.json],
      });

  static String? asNonEmpty(Object? v) =>
      v is String && v.isNotEmpty ? v : null;
}

/// Die `MarksForFn`-Funktion für den [Levels]-Konstruktor — null, solange
/// der Store noch lädt (die Levels-Kaskade überspringt die Markierungsstufe
/// dann wie das Original ohne Engine).
@Riverpod(keepAlive: true)
MarksForFn? levelsMarksForFn(Ref ref) {
  final marks = ref.watch(pdfMarksProvider).value;
  if (marks == null) return null;
  return (String srcId, int fnNum) => [
        for (final m in marks[srcId] ?? const <PdfMark>[])
          if (m.fn == fnNum)
            PdfMarkLevelInput(
              zitat: m.json['zitat'] is String ? m.zitat : null,
              page: m.json['page'],
              farbe: m.farbe,
            ),
      ];
}
