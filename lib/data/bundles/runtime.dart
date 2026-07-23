/// ThesisRuntime — die Daten der AKTIVEN Arbeit als ein unveränderliches
/// Objekt. Pendant zu den `window.DATA_*`-Globals der Web-App, die
/// `Projects.buildRuntime()` beim Projektwechsel komplett überschreibt
/// (Dossier 10 §2: der ProjectRecord ist das kanonische Modell, die
/// statischen Bundles sind nur die Materialisierung der eingebauten Arbeit).
///
/// Statt Globals zu mutieren, wird hier je Arbeit eine neue Runtime gebaut
/// und über den Provider-Graphen ausgetauscht (E8: expliziter Reboot).
library;

import '../models/json_utils.dart';
import '../models/models.dart';
import 'bundle_loader.dart';
import 'kind_labels.dart';

/// Daten-Sicht der aktiven Arbeit.
class ThesisRuntime {
  /// "default" für die eingebaute Arbeit, sonst die Projekt-ID.
  final String projectId;

  /// Anzeigename der Arbeit (Projects.activeName; bei der eingebauten
  /// Arbeit der Meta-Titel).
  final String projectName;

  /// Pendant zu DATA_THESIS.
  final Thesis thesis;

  /// Pendant zu DATA_SECTIONS (Key = "3_2_2_1"-Unterstrich-Notation).
  final Map<String, SectionAnalyse> sections;

  /// Pendant zu DATA_SOURCES — Custom-Quellen werden von der Projekt-
  /// Schicht per [withMergedCustomSources] ergänzt.
  final List<Source> sources;

  /// Pendant zu DATA_META (inkl. connections bei Instanz-Arbeiten).
  final DataMeta meta;

  /// Pendant zu DATA_FIGURES.
  final FiguresManifest figures;

  /// Pendant zu PROJECT_ERKLAERBUCH (null = Starter-Buch zeigen).
  final String? erklaerbuch;

  /// Pendant zu PROJECT_INSTANZEN.
  final Instanzen? instanzen;

  const ThesisRuntime({
    required this.projectId,
    required this.projectName,
    required this.thesis,
    this.sections = const {},
    this.sources = const [],
    this.meta = const DataMeta(),
    this.figures = FiguresManifest.empty,
    this.erklaerbuch,
    this.instanzen,
  });

  /// Runtime der eingebauten Arbeit aus den statischen Bundles —
  /// Pendant zum Default-Zweig von Projects.boot() (projects.js:53-59):
  /// Erklärbuch/Instanzen liegen dort in DATA_META.
  factory ThesisRuntime.fromBundle(ThesisBundle bundle) {
    final erklaerbuch = bundle.meta.erklaerbuch;
    return ThesisRuntime(
      projectId: ProjectRecord.defaultId,
      projectName: bundle.thesis.meta.title,
      thesis: bundle.thesis,
      sections: bundle.sections,
      sources: bundle.sources,
      meta: bundle.meta,
      figures: bundle.figures,
      erklaerbuch:
          (erklaerbuch != null && erklaerbuch.trim().isNotEmpty) ? erklaerbuch : null,
      instanzen: bundle.meta.instanzen,
    );
  }

  /// Laufzeitdaten einer Instanz-Arbeit aufbauen — wortgetreuer Port von
  /// Projects.buildRuntime (projects.js:154-224): Dossier-Fallbacks,
  /// stellen = citations ⨝ belege, Link-Kaskade, berechnete Statistiken.
  factory ThesisRuntime.fromProjectRecord(ProjectRecord rec) {
    final gen = rec.generated;
    final parsed = rec.parsed;

    // Belege aus den generierten Abschnitten je Fußnote.
    final belegIndex = <int, Beleg>{};
    for (final sec in gen.sections.values) {
      for (final p in sec.paragraphs) {
        for (final b in p.belege) {
          belegIndex[b.num] = b;
        }
      }
    }

    // Quellen anreichern: Dossier (oder Fallback), stellen, Links.
    final sources = <Source>[];
    for (final src in parsed.sources) {
      final d = gen.sources[src.id];
      final stellen = [
        for (final c in src.citations)
          Stelle.fromCitation(
            c,
            claim: belegIndex[c.footnote]?.claim ?? '',
            fundstelle: belegIndex[c.footnote]?.fundstelle ?? '',
            suchHinweis: belegIndex[c.footnote]?.suchHinweis ?? '',
          ),
      ];
      sources.add(Source(
        id: src.id,
        kind: src.kind,
        author: src.author,
        year: src.year,
        title: src.title,
        longTitle: src.longTitle,
        container: src.container,
        doi: src.doi,
        url: src.url,
        file: src.file,
        expectedFile: src.expectedFile,
        citations: src.citations,
        stellen: stellen,
        dossier: d?.dossier ?? Source.fallbackDossier(src),
        keyPoints: d?.keyPoints ?? const [],
        zitierweise: d?.zitierweise ?? Source.defaultZitierweise(src),
        hinweisOhnePdf: d?.hinweisOhnePdf,
        dossierFallback: d == null,
        links: SourceLinks(
          official: src.doi != null ? 'https://doi.org/${src.doi}' : src.url,
          file: src.file,
          vorschlag: true,
        ),
        custom: src.custom,
      ));
    }

    final erklaerbuch = gen.erklaerbuch;
    return ThesisRuntime(
      projectId: rec.id,
      projectName: rec.name,
      thesis: parsed.thesis,
      sections: gen.sections,
      sources: sources,
      meta: DataMeta(
        kapitel: gen.chapters,
        gesamt: gen.gesamt,
        fazit: gen.fazit,
        analyse: gen.analyse,
        connections: gen.connections,
        stats: computeStats(
          thesis: parsed.thesis,
          sections: gen.sections,
          sources: sources,
          fussnoten: parsed.footnotes.length,
        ),
      ),
      figures: rec.figures,
      erklaerbuch:
          (erklaerbuch != null && erklaerbuch.trim().isNotEmpty) ? erklaerbuch : null,
      instanzen: gen.instanzen,
    );
  }

  /// Custom-Quellen (aus dem `customSources`-Store) einmischen — Pendant zu
  /// Projects.mergeCustomSources (projects.js:240-256): vorhandene IDs
  /// gewinnen, Customs werden hinten angehängt. Ruft die Projekt-Schicht
  /// nach dem Runtime-Aufbau auf.
  ThesisRuntime withMergedCustomSources(List<Map<String, dynamic>> customs) {
    if (customs.isEmpty) return this;
    final known = {for (final s in sources) s.id};
    final merged = [
      ...sources,
      for (final c in customs)
        if (!known.contains(asString(c['id']))) Source.fromCustom(c),
    ];
    if (merged.length == sources.length) return this;
    return ThesisRuntime(
      projectId: projectId,
      projectName: projectName,
      thesis: thesis,
      sections: sections,
      sources: merged,
      meta: meta,
      figures: figures,
      erklaerbuch: erklaerbuch,
      instanzen: instanzen,
    );
  }

  /// Kennzahlen deterministisch berechnen — Port des Statistik-Teils von
  /// buildRuntime (projects.js:187-222). Stats werden NIE gespeichert,
  /// immer berechnet (Dossier 10 §9.9); für die eingebaute Arbeit liefert
  /// das Bundle sie fertig mit (identische Formel in build_data.js).
  static StatsMeta computeStats({
    required Thesis thesis,
    required Map<String, SectionAnalyse> sections,
    required List<Source> sources,
    required int fussnoten,
  }) {
    final fnPerChapter = <String, int>{};
    final paraPerChapter = <String, int>{};
    for (final ch in thesis.chapters) {
      final key = ch.num.toString();
      void walk(List<Unit> units) {
        for (final u in units) {
          for (final p in u.paragraphs) {
            paraPerChapter[key] = (paraPerChapter[key] ?? 0) + 1;
            fnPerChapter[key] = (fnPerChapter[key] ?? 0) + p.footnotes.length;
          }
          walk(u.children);
        }
      }

      walk(ch.sections);
    }

    var saetze = 0;
    for (final sec in sections.values) {
      for (final p in sec.paragraphs) {
        saetze += p.sentences.length;
      }
    }

    final byKind = <String, int>{};
    for (final s in sources) {
      byKind[s.kind] = (byKind[s.kind] ?? 0) + 1;
    }

    final top = [...sources]
      ..sort((a, b) => b.citations.length.compareTo(a.citations.length));

    return StatsMeta(
      quellen: sources.length,
      fussnoten: fussnoten,
      absaetze: paraPerChapter.values.fold(0, (a, b) => a + b),
      saetze: saetze,
      // Im Original fehlt `belege` bei Instanz-Arbeiten (buildRuntime setzt
      // es nicht) — der StatsMeta-Default 0 bildet das ab.
      fnPerChapter: fnPerChapter,
      paraPerChapter: paraPerChapter,
      byKind: byKind,
      kindLabels: kindLabels,
      topSources: [
        for (final s in top.take(10))
          TopSource(id: s.id, title: s.title, kind: s.kind, cites: s.citations.length),
      ],
    );
  }
}
