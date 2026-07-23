/// Daten-Indizes der aktiven Arbeit — Pendant zu `rebuildDataIndexes()`
/// samt der Index-Globals `UNIT_INDEX`, `FN_INDEX`, `SRC_BY_ID`,
/// `FIG_BY_PARA`, `TAB_BY_PARA` und `orderedUnits()` (util.js:934-1013).
///
/// Architektur statt Mutation (Master §7.9/§9.12, E8): Das Original leert
/// die Index-Objekte in-place und MUTIERT die DATA_*-Daten (Overrides mit
/// `_orig`-Sicherungskopien). Hier bleiben die Quelldaten unveränderlich;
/// die Overrides (paraEdits/fnEdits/titleEdits) liegen in einem eigenen
/// Provider, und [effectiveThesis] berechnet die "effektive" Sicht daraus.
/// Ein Projektwechsel tauscht einfach die [ActiveRuntime] aus — alle
/// Indizes bauen sich reaktiv neu (kein Stale-Cache-Bug L2, kein reload).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import 'runtime.dart';

export 'kind_labels.dart';
export 'runtime.dart';

part 'indexes.g.dart';

// ---------------------------------------------------------------------------
// ID-Konvertierung
// ---------------------------------------------------------------------------

/// "3.2.2" → "3_2_2" (Key in DATA_SECTIONS/Dateinamen) — Pendant zu
/// `fileIdOf` (util.js:942).
String fileIdOf(String sectionId) => sectionId.replaceAll('.', '_');

/// "3_2_2" → "3.2.2" (Umkehrung; Punkt- und Unterstrich-Notation kommen
/// in Routen bzw. Section-Maps gemischt vor).
String sectionIdOf(String fileId) => fileId.replaceAll('_', '.');

// ---------------------------------------------------------------------------
// Aktive Arbeit + Text-Overrides
// ---------------------------------------------------------------------------

/// Die Daten der aktiven Arbeit. `null` bedeutet "Boot noch nicht fertig" —
/// alle abgeleiteten Indizes liefern dann leere Strukturen (das Original
/// ist mit `window.DATA_* || []` genauso null-tolerant).
///
/// Boot (F-E) lädt das Bundle und ruft [activate]; ein Projektwechsel
/// (spätere Wellen) aktiviert die Runtime des neuen Records.
@Riverpod(keepAlive: true)
class ActiveRuntime extends _$ActiveRuntime {
  @override
  ThesisRuntime? build() => null;

  /// Neue aktive Arbeit setzen (Pendant zu buildRuntime + rebuildDataIndexes).
  void activate(ThesisRuntime runtime) => state = runtime;

  /// Kompletter Reset (Teil des expliziten Reboots, E8).
  void clear() => state = null;
}

/// Text-Overrides des Prüfstands: bearbeitete Absätze, Fußnoten und Titel.
/// Pendant zur Override-Anwendung in rebuildDataIndexes (util.js:952-996).
///
/// Schlüssel-Konventionen wie im Original: [paraEdits] paragraphId → Text
/// (wirkt nur auf `type == text`-Absätze), [fnEdits] Fußnotennummer → Text,
/// [titleEdits] `"ch<num>"` für Kapitel bzw. sectionId für Units → Titel.
class TextOverrideState {
  final Map<String, String> paraEdits;
  final Map<int, String> fnEdits;
  final Map<String, String> titleEdits;

  const TextOverrideState({
    this.paraEdits = const {},
    this.fnEdits = const {},
    this.titleEdits = const {},
  });

  static const empty = TextOverrideState();

  bool get isEmpty => paraEdits.isEmpty && fnEdits.isEmpty && titleEdits.isEmpty;
}

/// Welle 0 liefert leere Overrides; die KV-Schicht (F-C) lädt hier die
/// gespeicherten Edits des aktiven Projekts hinein (und bei jedem Edit neu).
@Riverpod(keepAlive: true)
class TextOverrides extends _$TextOverrides {
  @override
  TextOverrideState build() => TextOverrideState.empty;

  void set(TextOverrideState overrides) => state = overrides;
}

// ---------------------------------------------------------------------------
// Effektive Thesis-Sicht (Quelldaten + Overrides)
// ---------------------------------------------------------------------------

/// Struktur der aktiven Arbeit MIT angewandten Overrides. Das ist die
/// Sicht, die alle Views konsumieren — das "↺ Original wiederherstellen"
/// des Originals entspricht hier schlicht dem Entfernen des Overrides
/// (die unveränderte Runtime hält immer das Original).
@Riverpod(keepAlive: true)
Thesis? effectiveThesis(Ref ref) {
  final runtime = ref.watch(activeRuntimeProvider);
  if (runtime == null) return null;
  final ov = ref.watch(textOverridesProvider);
  if (ov.isEmpty) return runtime.thesis;

  Paragraph mapPara(Paragraph p) {
    final textEdit = p.isText ? ov.paraEdits[p.id] : null;
    final fns = [
      for (final f in p.footnotes)
        ov.fnEdits.containsKey(f.num)
            ? FootnoteRef(num: f.num, text: ov.fnEdits[f.num]!, sources: f.sources)
            : f,
    ];
    if (textEdit == null &&
        !p.footnotes.any((f) => ov.fnEdits.containsKey(f.num))) {
      return p;
    }
    return Paragraph(
      id: p.id,
      type: p.type,
      text: textEdit ?? p.text,
      items: p.items,
      footnotes: fns,
    );
  }

  Unit mapUnit(Unit u) => Unit(
        id: u.id,
        title: ov.titleEdits[u.id] ?? u.title,
        level: u.level,
        page: u.page,
        pdfPage: u.pdfPage,
        isIntro: u.isIntro,
        paragraphs: [for (final p in u.paragraphs) mapPara(p)],
        children: [for (final c in u.children) mapUnit(c)],
      );

  return Thesis(
    meta: runtime.thesis.meta,
    chapters: [
      for (final ch in runtime.thesis.chapters)
        Chapter(
          id: ch.id,
          num: ch.num,
          title: ov.titleEdits['ch${ch.num}'] ?? ch.title,
          page: ch.page,
          pdfPage: ch.pdfPage,
          sections: [for (final u in ch.sections) mapUnit(u)],
        ),
    ],
  );
}

// ---------------------------------------------------------------------------
// UNIT_INDEX
// ---------------------------------------------------------------------------

/// Eintrag des Abschnitts-Index: die Unit samt ihrem Kapitel.
class UnitIndexEntry {
  final Unit unit;
  final Chapter chapter;

  const UnitIndexEntry({required this.unit, required this.chapter});

  /// Punkt-Notation ("3.2.2").
  String get sectionId => unit.id;

  /// Unterstrich-Notation ("3_2_2") — Key in den Section-Analysen.
  String get fileId => fileIdOf(unit.id);
}

/// Abschnitts-Index mit toleranter Schlüssel-Normalisierung: Lookup
/// akzeptiert Punkt- UND Unterstrich-Notation ("3.2.2" wie "3_2_2").
class UnitIndex {
  /// Alle Einträge, Key = Punkt-Notation (wie das Original-UNIT_INDEX).
  final Map<String, UnitIndexEntry> byId;

  const UnitIndex(this.byId);

  static const empty = UnitIndex({});

  UnitIndexEntry? operator [](String id) => byId[sectionIdOf(id)];

  bool contains(String id) => byId.containsKey(sectionIdOf(id));
}

/// UNIT_INDEX: sectionId → {unit, chapter} über alle Ebenen (rekursiv
/// inkl. children), auf Basis der effektiven Sicht.
@Riverpod(keepAlive: true)
UnitIndex unitIndex(Ref ref) {
  final thesis = ref.watch(effectiveThesisProvider);
  if (thesis == null) return UnitIndex.empty;
  final byId = <String, UnitIndexEntry>{};
  for (final ch in thesis.chapters) {
    void walk(List<Unit> units) {
      for (final u in units) {
        byId[u.id] = UnitIndexEntry(unit: u, chapter: ch);
        walk(u.children);
      }
    }

    walk(ch.sections);
  }
  return UnitIndex(byId);
}

/// Reihenfolge aller Abschnitte MIT Absätzen (DFS) — Pendant zu
/// `orderedUnits()` (util.js:1005-1013); Basis für Vor/Zurück-Navigation,
/// Router-Fallbacks und die Command-Palette.
@Riverpod(keepAlive: true)
List<String> orderedUnits(Ref ref) {
  final thesis = ref.watch(effectiveThesisProvider);
  if (thesis == null) return const [];
  final out = <String>[];
  for (final ch in thesis.chapters) {
    void walk(List<Unit> units) {
      for (final u in units) {
        if (u.paragraphs.isNotEmpty) out.add(u.id);
        walk(u.children);
      }
    }

    walk(ch.sections);
  }
  return out;
}

// ---------------------------------------------------------------------------
// FN_INDEX
// ---------------------------------------------------------------------------

/// Eintrag des Fußnoten-Index: die Fußnote plus ihr Fundort
/// (Pendant zu `FN_INDEX[num] = {...f, sectionId, paragraphId}`).
class FnIndexEntry {
  final int num;

  /// Effektiver Fußnotentext (fnEdits bereits angewandt).
  final String text;

  /// Quellen-IDs (Alias-Match).
  final List<String> sources;
  final String sectionId;
  final String paragraphId;

  const FnIndexEntry({
    required this.num,
    required this.text,
    this.sources = const [],
    required this.sectionId,
    required this.paragraphId,
  });
}

/// FN_INDEX: globale Fußnotennummer → Fußnote mit Fundort.
@Riverpod(keepAlive: true)
Map<int, FnIndexEntry> fnIndex(Ref ref) {
  final thesis = ref.watch(effectiveThesisProvider);
  if (thesis == null) return const {};
  final out = <int, FnIndexEntry>{};
  for (final ch in thesis.chapters) {
    void walk(List<Unit> units) {
      for (final u in units) {
        for (final p in u.paragraphs) {
          for (final f in p.footnotes) {
            out[f.num] = FnIndexEntry(
              num: f.num,
              text: f.text,
              sources: f.sources,
              sectionId: u.id,
              paragraphId: p.id,
            );
          }
        }
        walk(u.children);
      }
    }

    walk(ch.sections);
  }
  return out;
}

/// Beleg zu einer Fußnote finden — Pendant zu `U.findBeleg` (util.js:614-623):
/// über den Fundort der Fußnote in die Section-Analyse und dort in die
/// belege-Liste des Absatzes.
@Riverpod(keepAlive: true)
Beleg? findBeleg(Ref ref, int num) {
  final fn = ref.watch(fnIndexProvider)[num];
  if (fn == null) return null;
  final runtime = ref.watch(activeRuntimeProvider);
  final sec = runtime?.sections[fileIdOf(fn.sectionId)];
  if (sec == null) return null;
  for (final p in sec.paragraphs) {
    if (p.id != fn.paragraphId) continue;
    for (final b in p.belege) {
      if (b.num == num) return b;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// SRC_BY_ID + FIG/TAB_BY_PARA
// ---------------------------------------------------------------------------

/// SRC_BY_ID: Quellen-Index der aktiven Arbeit.
@Riverpod(keepAlive: true)
Map<String, Source> srcById(Ref ref) {
  final runtime = ref.watch(activeRuntimeProvider);
  if (runtime == null) return const {};
  return {for (final s in runtime.sources) s.id: s};
}

/// FIG_BY_PARA: Abbildungen nach Anker-Absatz.
@Riverpod(keepAlive: true)
Map<String, Figur> figByPara(Ref ref) {
  final runtime = ref.watch(activeRuntimeProvider);
  if (runtime == null) return const {};
  return {for (final f in runtime.figures.figuren) f.paragraphId: f};
}

/// TAB_BY_PARA: Tabellen nach Anker-Absatz.
@Riverpod(keepAlive: true)
Map<String, Tabelle> tabByPara(Ref ref) {
  final runtime = ref.watch(activeRuntimeProvider);
  if (runtime == null) return const {};
  return {for (final t in runtime.figures.tabellen) t.paragraphId: t};
}

// ---------------------------------------------------------------------------
// srcShort — Kurzname einer Quelle
// ---------------------------------------------------------------------------

/// Feste Kurznamen der 20 bekannten (Rechts-)Quellen — exakt util.js:48-55.
const Map<String, String> srcShortKnown = {
  'ehds-vo': 'EHDS-VO',
  'dsgvo': 'DSGVO',
  'gtelg2012': 'GTelG',
  'elga-vo2015': 'ELGA-VO',
  'nis2': 'NIS-2',
  'dga': 'DGA',
  'datenverordnung': 'Data Act',
  'cra': 'CRA',
  'eidas': 'eIDAS',
  'rl-2011-24': 'RL 2011/24',
  'aeuv': 'AEUV',
  'asvg': 'ASVG',
  'nisg': 'NISG',
  'aerzteg1998': 'ÄrzteG',
  'elga-gesamtarchitektur2017': 'ELGA-Architektur',
  'rh-elga2024': 'RH 2024',
  'ihe-iti2026': 'IHE ITI',
  'iso13606': 'ISO 13606',
  'empfehlung2019-243': 'Empf. 2019/243',
  'erlaeuterungen38me': 'ErlME 38',
};

/// Kurzname einer Quelle als reine Funktion — Port von `U.srcShort`
/// (util.js:46-66): bekannte Map > Autor-Nachname (+Jahr) > bei online
/// Titel auf 16 Zeichen > die id selbst.
String computeSrcShort(String id, Source? s) {
  final known = srcShortKnown[id];
  if (known != null) return known;
  if (s != null && (s.author ?? '').isNotEmpty) {
    final last = s.author!
        .split(',')
        .first
        .split(' ')
        .first
        .replaceAll(RegExp(r'u\.a\.|et al\.'), '')
        .trim();
    return '$last${s.year != null ? ' ${s.year}' : ''}'.trim();
  }
  if (s != null && s.kind == 'online') {
    final t = s.title.isNotEmpty ? s.title : id;
    return t.length > 16 ? t.substring(0, 16) : t;
  }
  return id;
}

/// srcShort als Provider-Familie — der Ersatz für den `U._shortCache`
/// (Riverpod cached je id; ein Runtime-Wechsel invalidiert automatisch,
/// womit der Stale-Cache des Originals gleich mit gefixt ist).
@Riverpod(keepAlive: true)
String srcShort(Ref ref, String srcId) =>
    computeSrcShort(srcId, ref.watch(srcByIdProvider)[srcId]);
