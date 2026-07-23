/// Daten-Sicht der Domänenlogik — bündelt die Index-Strukturen, die die
/// JS-Module als Globals konsumieren (`UNIT_INDEX`, `FN_INDEX`, `SRC_BY_ID`,
/// `orderedUnits()`, `DATA_SECTIONS`, `DATA_META`, `U.findBeleg`,
/// `U.srcShort`) in EIN unveränderliches Objekt.
///
/// Die Riverpod-Provider (data/bundles/indexes.dart) berechnen dieselben
/// Indizes reaktiv für die UI; die Domänenklassen (Levels, Connections,
/// Mentions, Editor) bleiben aber Riverpod-frei und testbar, indem sie nur
/// diesen Kontext nehmen. Spätere Wellen bauen ihn aus den Providern
/// (ein Provider `domainContext` genügt), Tests direkt aus den Bundles.
library;

import '../data/bundles/indexes.dart' show UnitIndex, UnitIndexEntry, FnIndexEntry, computeSrcShort, fileIdOf;
import '../data/models/models.dart';

export '../data/bundles/indexes.dart' show UnitIndex, UnitIndexEntry, FnIndexEntry, fileIdOf;

/// Unveränderliche Daten-Sicht der aktiven Arbeit für die Domänenlogik.
class DomainContext {
  /// Struktur der Arbeit (effektive Sicht — Overrides bereits angewandt).
  final Thesis? thesis;

  /// sectionId → Unit + Kapitel (Pendant zu UNIT_INDEX).
  final UnitIndex unitIndex;

  /// Fußnotennummer → Fußnote mit Fundort (Pendant zu FN_INDEX).
  final Map<int, FnIndexEntry> fnIndex;

  /// Quellen in Bundle-Reihenfolge (Pendant zu DATA_SOURCES) — die
  /// Reihenfolge trägt Semantik (Mentions-Muster, Kandidaten-Ties).
  final List<Source> sources;

  /// Quellen-Index (Pendant zu SRC_BY_ID).
  final Map<String, Source> srcById;

  /// Abschnitte mit Inhalt in Dokumentreihenfolge (Pendant zu orderedUnits()).
  final List<String> orderedUnitIds;

  /// GPT-Voranalyse je Abschnitt, Key = Unterstrich-Notation "3_2_2"
  /// (Pendant zu DATA_SECTIONS).
  final Map<String, SectionAnalyse> sections;

  /// Pendant zu DATA_META (connections/fazit null-tolerant, W3).
  final DataMeta meta;

  /// Original-Fußnotentexte VOR fnEdits-Overrides (`_origText`), Key =
  /// Fußnotennummer. Nur gefüllt, wenn Overrides aktiv sind — der Editor
  /// braucht sie, damit Anzeige-Overrides nie ins LaTeX einsickern.
  final Map<int, String> fnOrigTexts;

  final Map<String, String> _srcShortCache = {};

  DomainContext({
    this.thesis,
    this.unitIndex = UnitIndex.empty,
    this.fnIndex = const {},
    this.sources = const [],
    Map<String, Source>? srcById,
    this.orderedUnitIds = const [],
    this.sections = const {},
    this.meta = const DataMeta(),
    this.fnOrigTexts = const {},
  }) : srcById = srcById ?? {for (final s in sources) s.id: s};

  /// Kontext aus den Rohdaten einer Arbeit bauen — derselbe Walk wie
  /// `rebuildDataIndexes()`/`orderedUnits()` (util.js:944-1013), nur ohne
  /// Mutation der Quelldaten.
  factory DomainContext.build({
    required Thesis thesis,
    List<Source> sources = const [],
    Map<String, SectionAnalyse> sections = const {},
    DataMeta meta = const DataMeta(),
    Map<int, String> fnOrigTexts = const {},
  }) {
    final byId = <String, UnitIndexEntry>{};
    final fnIndex = <int, FnIndexEntry>{};
    final ordered = <String>[];
    for (final ch in thesis.chapters) {
      void walk(List<Unit> units) {
        for (final u in units) {
          byId[u.id] = UnitIndexEntry(unit: u, chapter: ch);
          if (u.paragraphs.isNotEmpty) ordered.add(u.id);
          for (final p in u.paragraphs) {
            for (final f in p.footnotes) {
              fnIndex[f.num] = FnIndexEntry(
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
    return DomainContext(
      thesis: thesis,
      unitIndex: UnitIndex(byId),
      fnIndex: fnIndex,
      sources: sources,
      orderedUnitIds: ordered,
      sections: sections,
      meta: meta,
      fnOrigTexts: fnOrigTexts,
    );
  }

  /// Beleg (claim/fundstelle/suchHinweis) zu einer Fußnote — Port von
  /// `U.findBeleg` (util.js:614-623). Wichtig für die Levels-Kaskade
  /// (Stufe „✦ vermutet“).
  Beleg? findBeleg(int num) {
    final fn = fnIndex[num];
    if (fn == null) return null;
    final gen = sections[fileIdOf(fn.sectionId)];
    if (gen == null) return null;
    for (final p in gen.paragraphs) {
      for (final b in p.belege) {
        if (b.num == num) return b;
      }
    }
    return null;
  }

  /// Kurzname einer Quelle (Pendant zu `U.srcShort` inkl. `_shortCache`).
  /// Ein neuer Kontext = frischer Cache — der Stale-Cache-Bug des Originals
  /// (L2, `_shortCache` nach Projektwechsel) ist damit strukturell gefixt.
  String srcShort(String id) =>
      _srcShortCache[id] ??= computeSrcShort(id, srcById[id]);
}
