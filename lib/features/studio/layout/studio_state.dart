/// Studio-Zustand — Pendant zum globalen `Studio`-Objekt samt seiner
/// localStorage-Keys (views_studio.js:16-36 + §3 des Dossiers 03).
///
/// Drei Schichten:
///  1. [StudioPrefs] — die globalen UI-Einstellungen (Modus, Dichte, ⚡/🖍,
///     View-Auswahl, Spalten-Breiten/-Zustände) als EIN persistierter
///     Notifier-Zustand; jede Mutation schreibt sofort in die KV-Schicht.
///  2. [StudioKv] — der projekt-gescopte Fachzustand (belegLevels,
///     textMentions, belegSpans, paraEdits, …) als synchron lesbarer
///     Schnappschuss mit Write-Through. §0-Pflicht: Schreiben an
///     `paraEdits`/`fnEdits`/`titleEdits` zieht [textOverridesProvider]
///     selbst nach.
///  3. [studioDomainProvider] — die daraus gebaute Domänen-Sicht
///     (DomainContext + Levels + Mentions + Voranalyse-Zugriff).
///
/// Dazu: aktiver Beleg ([StudioSelection] = `Studio.sel`), Quellen-Spalten-
/// Zustand mit Generation-Token ([StudioFile] = `Studio.file`), Scroll-
/// Gedächtnis je `modus|abschnitt` (`Studio._scroll`).
library;

import 'dart:async';

import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/richtext/categories.dart';
import '../../../core/richtext/source_matcher.dart';
import '../../../core/router/routes.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/db/kv.dart';
import '../../../data/models/models.dart';
import '../../../domain/domain.dart';
import 'studio_slots.dart';

part 'studio_state.g.dart';

// ---------------------------------------------------------------------------
// 1. UI-Einstellungen (global, KV-persistiert)
// ---------------------------------------------------------------------------

/// Store-Keys der Studio-UI (alle GLOBAL — nicht in PROJECT_KEYS).
abstract final class StudioUiKeys {
  static const cats = 'cats';
  static const studioMode = 'studioMode';
  static const lesenDichte = 'lesenDichte';
  static const lesenFast = 'lesenFast';
  static const lesenMarks = 'lesenMarks';
  static const uiDockMode = 'uiDockMode';
  static const uiSfDockClosed = 'uiSfDockClosed';
  static const uiStyleCheck = 'uiStyleCheck';
  static const uiFileOff = 'uiFileOff';
  static const uiTreeOff = 'uiTreeOff';
  static const uiFileW = 'uiFileW';
  static const uiTreeW = 'uiTreeW';
  static const uiPsW = 'uiPsW';
  static const uiSfDockH = 'uiSfDockH';
  static const instDefs = 'instDefs';
}

/// Die Studio-UI-Einstellungen als unveränderlicher Wert.
class StudioPrefs {
  /// `lesen` | `pruefen` | `editor` (Default `pruefen`).
  final String mode;

  /// `normal` | `kompakt`.
  final String dichte;

  /// ⚡ Schnelllese-Anstrich im Lesen-Modus.
  final bool fast;

  /// 🖍 dezente Markierungen im Lesen-Modus.
  final bool lesenMarks;

  /// Globale View-Auswahl (`uiDockMode`) — View-id oder null (∅ Ohne).
  final String? dock;

  /// Beleg-Dock eingeklappt.
  final bool dockClosed;

  /// 🤖 Stil-Check an (geschaltet von K-3/enhance).
  final bool styleCheck;

  /// Aktive Mark-Kategorien.
  final Set<String> activeCats;

  final bool fileOff;
  final bool treeOff;

  /// Gespeicherte Breiten in px (null = CSS-Default).
  final int? fileW;
  final int? treeW;
  final int? psW;
  final int? sfDockH;

  const StudioPrefs({
    this.mode = 'pruefen',
    this.dichte = 'normal',
    this.fast = false,
    this.lesenMarks = false,
    this.dock = 'connections',
    this.dockClosed = false,
    this.styleCheck = false,
    this.activeCats = const {...catOrderSet},
    this.fileOff = false,
    this.treeOff = false,
    this.fileW,
    this.treeW,
    this.psW,
    this.sfDockH,
  });

  static const defaults = StudioPrefs();

  StudioPrefs copyWith({
    String? mode,
    String? dichte,
    bool? fast,
    bool? lesenMarks,
    Object? dock = _sentinel,
    bool? dockClosed,
    bool? styleCheck,
    Set<String>? activeCats,
    bool? fileOff,
    bool? treeOff,
    Object? fileW = _sentinel,
    Object? treeW = _sentinel,
    Object? psW = _sentinel,
    Object? sfDockH = _sentinel,
  }) =>
      StudioPrefs(
        mode: mode ?? this.mode,
        dichte: dichte ?? this.dichte,
        fast: fast ?? this.fast,
        lesenMarks: lesenMarks ?? this.lesenMarks,
        dock: dock == _sentinel ? this.dock : dock as String?,
        dockClosed: dockClosed ?? this.dockClosed,
        styleCheck: styleCheck ?? this.styleCheck,
        activeCats: activeCats ?? this.activeCats,
        fileOff: fileOff ?? this.fileOff,
        treeOff: treeOff ?? this.treeOff,
        fileW: fileW == _sentinel ? this.fileW : fileW as int?,
        treeW: treeW == _sentinel ? this.treeW : treeW as int?,
        psW: psW == _sentinel ? this.psW : psW as int?,
        sfDockH: sfDockH == _sentinel ? this.sfDockH : sfDockH as int?,
      );

  static const _sentinel = Object();
}

/// `CAT_ORDER` als Set (Default der aktiven Kategorien).
const Set<String> catOrderSet = {
  'norm', 'frist', 'akteur', 'tech', 'these', 'luecke', 'zahl', 'abk', 'schlag',
};

@Riverpod(keepAlive: true)
class StudioPrefsCtl extends _$StudioPrefsCtl {
  @override
  Future<StudioPrefs> build() async {
    final kv = ref.watch(kvStoreProvider);
    Future<Object?> g(String key, [Object? fallback]) => kv.getJson(key, fallback);

    final cats = await g(StudioUiKeys.cats);
    final mode = await g(StudioUiKeys.studioMode, 'pruefen');
    // uiDockMode: gespeichertes JSON-`null` heißt „∅ Ohne“ — nur ein ganz
    // fehlender Eintrag fällt auf 'connections' zurück (storeGet-Semantik).
    final dock = await g(StudioUiKeys.uiDockMode, 'connections');

    int? px(Object? v) {
      final n = v is num ? v.toInt() : int.tryParse('$v');
      return (n != null && n > 0) ? n : null;
    }

    return StudioPrefs(
      mode: mode is String && mode.isNotEmpty ? mode : 'pruefen',
      dichte: (await g(StudioUiKeys.lesenDichte, 'normal')) == 'kompakt'
          ? 'kompakt'
          : 'normal',
      fast: jsTruthy(await g(StudioUiKeys.lesenFast, false)),
      lesenMarks: jsTruthy(await g(StudioUiKeys.lesenMarks, false)),
      dock: dock is String && dock.isNotEmpty ? dock : null,
      dockClosed: jsTruthy(await g(StudioUiKeys.uiSfDockClosed, false)),
      styleCheck: jsTruthy(await g(StudioUiKeys.uiStyleCheck, false)),
      activeCats: cats is List
          ? {for (final c in cats) '$c'}
          : {...catOrderSet},
      fileOff: jsTruthy(await g(StudioUiKeys.uiFileOff, false)),
      treeOff: jsTruthy(await g(StudioUiKeys.uiTreeOff, false)),
      fileW: px(await g(StudioUiKeys.uiFileW)),
      treeW: px(await g(StudioUiKeys.uiTreeW)),
      psW: px(await g(StudioUiKeys.uiPsW)),
      sfDockH: px(await g(StudioUiKeys.uiSfDockH)),
    );
  }

  StudioPrefs get _cur => state.value ?? StudioPrefs.defaults;

  void _apply(StudioPrefs next, String key, Object? stored) {
    state = AsyncData(next);
    // Fire-and-forget wie storeSet (Fehler wären echte DB-Fehler).
    ref.read(kvStoreProvider).setJson(key, stored);
  }

  /// Gültiger Modus wird persistiert (renderStudio :43).
  void setMode(String mode) {
    if (!const {'lesen', 'pruefen', 'editor'}.contains(mode)) return;
    if (_cur.mode == mode) return;
    _apply(_cur.copyWith(mode: mode), StudioUiKeys.studioMode, mode);
  }

  void setDichte(String dichte) =>
      _apply(_cur.copyWith(dichte: dichte), StudioUiKeys.lesenDichte, dichte);

  void toggleFast() =>
      _apply(_cur.copyWith(fast: !_cur.fast), StudioUiKeys.lesenFast, !_cur.fast);

  void toggleLesenMarks() => _apply(_cur.copyWith(lesenMarks: !_cur.lesenMarks),
      StudioUiKeys.lesenMarks, !_cur.lesenMarks);

  /// Globale View-Auswahl — leert zusätzlich `dockBySection` („Auswahl gilt
  /// überall“, :673).
  void setDock(String? id) {
    _apply(_cur.copyWith(dock: id), StudioUiKeys.uiDockMode, id);
    ref.read(studioKvProvider.notifier).put(KvKeys.dockBySection, <String, Object?>{});
  }

  void setDockClosed(bool closed) => _apply(
      _cur.copyWith(dockClosed: closed), StudioUiKeys.uiSfDockClosed, closed);

  void setStyleCheck(bool on) =>
      _apply(_cur.copyWith(styleCheck: on), StudioUiKeys.uiStyleCheck, on);

  /// Kategorie global ein-/ausblenden (Kategorie-Chip-Klick, :744-750).
  void toggleCat(String cat) {
    final next = {..._cur.activeCats};
    next.contains(cat) ? next.remove(cat) : next.add(cat);
    _apply(_cur.copyWith(activeCats: next), StudioUiKeys.cats, next.toList());
  }

  void setFileOff(bool off) =>
      _apply(_cur.copyWith(fileOff: off), StudioUiKeys.uiFileOff, off);

  void setTreeOff(bool off) =>
      _apply(_cur.copyWith(treeOff: off), StudioUiKeys.uiTreeOff, off);

  void setFileW(int? px) =>
      _apply(_cur.copyWith(fileW: px), StudioUiKeys.uiFileW, px);

  void setTreeW(int? px) =>
      _apply(_cur.copyWith(treeW: px), StudioUiKeys.uiTreeW, px);

  void setPsW(int? px) => _apply(_cur.copyWith(psW: px), StudioUiKeys.uiPsW, px);

  void setSfDockH(int? px) =>
      _apply(_cur.copyWith(sfDockH: px), StudioUiKeys.uiSfDockH, px);
}

// ---------------------------------------------------------------------------
// 2. Projekt-Fachzustand (Schnappschuss + Write-Through)
// ---------------------------------------------------------------------------

/// Keys, die das Studio synchron braucht. `instDefs` ist global, der Rest
/// projekt-gescopt (das Scoping erledigt die KV-Schicht). `kiConnections`
/// braucht das ⤳-Fenster (side_graph) — Gate-2-Fix: der Key fehlte, KI-
/// importierte Kanten erschienen im Studio nie ohne Reboot.
const List<String> _studioKvKeys = [
  KvKeys.belegLevels,
  KvKeys.annotations,
  KvKeys.resolutions,
  KvKeys.textMentions,
  KvKeys.belegSpans,
  KvKeys.paraEdits,
  KvKeys.fnEdits,
  KvKeys.titleEdits,
  KvKeys.marksExtra,
  KvKeys.paraDock,
  KvKeys.dockBySection,
  KvKeys.texEdits,
  KvKeys.studioLast,
  KvKeys.kiConnections,
  StudioUiKeys.instDefs,
];

@Riverpod(keepAlive: true)
class StudioKv extends _$StudioKv {
  @override
  Future<Map<String, Object?>> build() async {
    // Projektwechsel (neue Runtime) lädt den Schnappschuss neu.
    ref.watch(activeRuntimeProvider);
    final kv = ref.watch(kvStoreProvider);
    final out = <String, Object?>{};
    for (final key in _studioKvKeys) {
      final v = await kv.getJson(key);
      if (v != null) out[key] = v;
    }

    // Live-Kohärenz (Gate-2-Fix, Pendant zu QuellenKv): Schreibt eine ANDERE
    // Welt (Quellen-Detail „✦ Durchlauf“ → resolutions, KI-Import →
    // kiConnections, Beleg-Prüfung in der Bibliothek → belegLevels …), zieht
    // der warme Studio-Schnappschuss automatisch nach — im Original las jede
    // Render-Runde localStorage frisch. Eigene Writes kommen als Echo über
    // den Stream zurück und werden per Deep-Equality verworfen.
    final subs = <StreamSubscription<Object?>>[
      for (final key in _studioKvKeys)
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

  /// Fremd-Änderung einmischen (Stream-Event) — nur bei ECHTER Änderung
  /// (Deep-Equality), damit die Write-Through-Echos der eigenen `put`s
  /// keine Studio-Rebuilds auslösen.
  void _onExternal(String key, Object? value) {
    final cur = state.value;
    if (cur == null) return;
    if (const DeepCollectionEquality().equals(cur[key], value)) return;
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
/// läuft durch [StudioKv.put] (Write-Through + Invalidierung + §0).
class StudioDomainStore implements DomainStore {
  final Map<String, Object?> _snapshot;
  final StudioKv _notifier;

  StudioDomainStore(this._snapshot, this._notifier);

  @override
  Object? read(String key) => _snapshot[key];

  @override
  void write(String key, Object? value) => _notifier.put(key, value);
}

// ---------------------------------------------------------------------------
// 3. Domänen-Sicht
// ---------------------------------------------------------------------------

/// Gebündelte Domänen-Objekte des Studios — je Snapshot/Runtime EIN Satz.
class StudioDomain {
  final DomainContext ctx;
  final Levels levels;
  final Mentions mentions;
  final EditorLogic editor;
  final SourceTextMatcher matcher;
  final ThesisRuntime runtime;

  StudioDomain({
    required this.ctx,
    required this.levels,
    required this.mentions,
    required this.editor,
    required this.matcher,
    required this.runtime,
  });

  /// Voranalyse eines Abschnitts (`Studio.genFor`).
  SectionAnalyse? genFor(String sectionId) =>
      runtime.sections[fileIdOf(sectionId)];

  /// Voranalyse eines Absatzes (`Studio.genPara`).
  ParagraphAnalyse? genPara(String sectionId, String paraId) {
    final g = genFor(sectionId);
    if (g == null) return null;
    for (final p in g.paragraphs) {
      if (p.id == paraId) return p;
    }
    return null;
  }

  /// Quellen ↔ Fußnoten eines Abschnitts (`sectionSources`, :1202-1211).
  Map<String, List<int>> sectionSources(String sectionId) {
    final bySrc = <String, List<int>>{};
    for (final n in levels.numsForSection(sectionId)) {
      for (final srcId in ctx.fnIndex[n]?.sources ?? const <String>[]) {
        bySrc.putIfAbsent(srcId, () => []).add(n);
      }
    }
    return bySrc;
  }

  /// Belege eines Absatzes: Voranalyse, sonst nackte Fußnoten
  /// (`paraBelege`, :897-900).
  List<Beleg> paraBelege(String sectionId, Paragraph p) {
    final gp = genPara(sectionId, p.id);
    if (gp != null && gp.belege.isNotEmpty) return gp.belege;
    return [
      for (final f in p.footnotes)
        Beleg(num: f.num, quellen: f.sources),
    ];
  }

  /// Marks eines Absatzes: Voranalyse-Sätze + `marksExtra` (`paraMarks`,
  /// :681-686). [marksExtra] reicht der Aufrufer aus dem Snapshot herein.
  List<Mark> paraMarks(String sectionId, String paraId,
      Map<String, Object?> marksExtra) {
    final gp = genPara(sectionId, paraId);
    final base = <Mark>[
      for (final s in gp?.sentences ?? const <SentenceAnalyse>[]) ...s.marks,
    ];
    final extraRaw = marksExtra[paraId];
    if (extraRaw is List) {
      for (final e in extraRaw) {
        if (e is Map) {
          final snippet = e['snippet'];
          final kategorie = e['kategorie'];
          if (snippet is String &&
              snippet.isNotEmpty &&
              catLabels.containsKey(kategorie)) {
            base.add(Mark(snippet: snippet, kategorie: '$kategorie'));
          }
        }
      }
    }
    return base;
  }

  /// Original-Fußnotentext VOR fnEdits (`fn._origText`) — aus der
  /// UN-überschriebenen Runtime.
  String? fnOrigText(int num) => ctx.fnOrigTexts[num];
}

@Riverpod(keepAlive: true)
StudioDomain? studioDomain(Ref ref) {
  final runtime = ref.watch(activeRuntimeProvider);
  final thesis = ref.watch(effectiveThesisProvider);
  if (runtime == null || thesis == null) return null;

  final snapshot =
      ref.watch(studioKvProvider).value ?? const <String, Object?>{};
  final store = StudioDomainStore(snapshot, ref.read(studioKvProvider.notifier));

  // Original-Fußnotentexte für aktive fnEdits (Editor-Regel: Overrides
  // sickern NIE ins LaTeX; ✎-Dock vergleicht gegen das Original).
  final fnOrig = <int, String>{};
  final fnEditsRaw = snapshot[KvKeys.fnEdits];
  if (fnEditsRaw is Map && fnEditsRaw.isNotEmpty) {
    final wanted = {
      for (final k in fnEditsRaw.keys) int.tryParse('$k'),
    }..remove(null);
    for (final ch in runtime.thesis.chapters) {
      void walk(List<Unit> units) {
        for (final u in units) {
          for (final p in u.paragraphs) {
            for (final f in p.footnotes) {
              if (wanted.contains(f.num)) fnOrig[f.num] = f.text;
            }
          }
          walk(u.children);
        }
      }

      walk(ch.sections);
    }
  }

  final ctx = DomainContext.build(
    thesis: thesis,
    sources: runtime.sources,
    sections: runtime.sections,
    meta: runtime.meta,
    fnOrigTexts: fnOrig,
  );

  return StudioDomain(
    ctx: ctx,
    levels: Levels(ctx, store, marksForFn: StudioSlots.marksForFn),
    mentions: Mentions(ctx, store),
    editor: EditorLogic(ctx, store),
    matcher: SourceTextMatcher(runtime.sources, ctx.srcShort),
    runtime: runtime,
  );
}

// ---------------------------------------------------------------------------
// Aktiver Beleg + Quellen-Spalte
// ---------------------------------------------------------------------------

/// `Studio.sel` — der aktive Beleg (Ziel der PDF-Markierung); überlebt
/// Re-Render und Moduswechsel.
class StudioSel {
  final String? srcId;
  final int? fn;

  const StudioSel({this.srcId, this.fn});
}

@Riverpod(keepAlive: true)
class StudioSelection extends _$StudioSelection {
  @override
  StudioSel? build() => null;

  void select(String? srcId, int? fn) => state = StudioSel(srcId: srcId, fn: fn);

  void clear() => state = null;
}

/// `Studio.file` — Zustand der Quellen-Spalte: aktive Quelle/Fußnote +
/// Generation-Token gegen Async-Races (:1348-1366): nur der jüngste
/// mount()-Lauf darf den Slot behalten.
class StudioFileState {
  final String? srcId;
  final int? fn;
  final int gen;

  const StudioFileState({this.srcId, this.fn, this.gen = 0});
}

@Riverpod(keepAlive: true)
class StudioFile extends _$StudioFile {
  @override
  StudioFileState build() => const StudioFileState();

  /// Quelle (und ggf. Fußnote) setzen — zählt das Generation-Token hoch.
  void show(String? srcId, int? fn) =>
      state = StudioFileState(srcId: srcId, fn: fn, gen: state.gen + 1);

  /// Nur die Fußnote wechseln (Dropdown) — KEIN Re-Mount des PDFs.
  void setFn(int? fn) =>
      state = StudioFileState(srcId: state.srcId, fn: fn, gen: state.gen);

  /// Re-Mount erzwingen (z. B. nach Datei-Zuordnung).
  void remount() =>
      state = StudioFileState(srcId: state.srcId, fn: state.fn, gen: state.gen + 1);
}

/// `fileShow(srcId, fnNum)` (:1479-1493): aktive Auswahl setzen; im
/// Lesen-Modus stattdessen in den Analyse-Modus navigieren (die Auswahl wird
/// vom nächsten Render aufgenommen); sonst die Spalte ggf. aufklappen.
void studioFileShow(WidgetRef ref, BuildContext context, String? srcId, int? fn,
    {required String sectionId}) {
  ref.read(studioSelectionProvider.notifier).select(srcId, fn);
  ref.read(studioFileProvider.notifier).show(srcId, fn);
  final prefs =
      ref.read(studioPrefsCtlProvider).value ?? StudioPrefs.defaults;
  if (prefs.mode == 'lesen') {
    context.go(Routes.studioPath(sec: sectionId, modus: StudioModes.pruefen));
    return;
  }
  if (prefs.fileOff) {
    ref.read(studioPrefsCtlProvider.notifier).setFileOff(false);
  }
}

/// 🔎-Chip-Fluss: Beleg aktivieren, dann suchen, sobald die Engine steht
/// (Original: Polling 20×200ms, :1090-1094 — Zeitbudget beibehalten).
Future<void> studioPdfSearchWhenReady(String srcId, String term) async {
  for (var tries = 0; tries <= 20; tries++) {
    final handle = StudioSlots.pdfHandle;
    if (handle != null && handle.srcId == srcId) {
      handle.search(term);
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

// ---------------------------------------------------------------------------
// Scroll-Gedächtnis (`Studio._scroll`)
// ---------------------------------------------------------------------------

/// Scrollstand je `"<modus>|<abschnitt>"` — reiner Sitzungszustand.
@Riverpod(keepAlive: true)
class StudioScrollMemory extends _$StudioScrollMemory {
  final Map<String, double> _offsets = {};

  @override
  Object? build() => null;

  void save(String mode, String sectionId, double offset) =>
      _offsets['$mode|$sectionId'] = offset;

  double? restore(String mode, String sectionId) => _offsets['$mode|$sectionId'];
}
