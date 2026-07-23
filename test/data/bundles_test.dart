/// Tests für Paket F-B: Bundle-Loader, Modelle und Indizes gegen die ECHTEN
/// Assets der eingebauten Arbeit (keine Fixtures — die Kennzahlen stammen
/// aus Master §5 bzw. Dossier 10 und sind aus den Realdaten extrahiert).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/data/bundles/bundle_loader.dart';
import 'package:thesor/data/bundles/indexes.dart';
import 'package:thesor/data/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ThesisBundle bundle;

  setUpAll(() async {
    bundle = await BundleLoader.load();
  });

  /// Alle Units einer Thesis flach (DFS, wie orderedUnits, aber komplett).
  List<Unit> allUnits(Thesis t) {
    final out = <Unit>[];
    void walk(List<Unit> units) {
      for (final u in units) {
        out.add(u);
        walk(u.children);
      }
    }

    for (final ch in t.chapters) {
      walk(ch.sections);
    }
    return out;
  }

  group('Bundle-Kennzahlen (eingebaute EHDS-Arbeit)', () {
    test('Struktur: 6 Kapitel, 69 Units, 233 Absätze, 397 Fußnoten', () {
      expect(bundle.thesis.chapters.length, 6);
      expect(bundle.thesis.meta.title, 'Primärnutzung von Gesundheitsdaten im EHDS');
      expect(bundle.thesis.meta.pageOffset, 10);

      final units = allUnits(bundle.thesis);
      expect(units.length, 69);
      expect(units.where((u) => u.isIntro).length, 5);

      final paras = [for (final u in units) ...u.paragraphs];
      expect(paras.length, 233);
      expect(paras.where((p) => p.typeEnum == ParagraphType.text).length, 226);
      expect(paras.where((p) => p.typeEnum == ParagraphType.list).length, 4);
      expect(paras.where((p) => p.typeEnum == ParagraphType.table).length, 2);
      expect(paras.where((p) => p.typeEnum == ParagraphType.figure).length, 1);

      final fns = [for (final p in paras) ...p.footnotes];
      expect(fns.length, 397);
      // Fußnote 1 hat drei Quellen (Mehrfachquellen-Beispiel des Dossiers).
      expect(fns.first.num, 1);
      expect(fns.first.sources, ['ehds-vo', 'cra', 'rl-2011-24']);
    });

    test('Sections: 68 Auflösungen, 688 Sätze, 1369 Marks, 397 Belege', () {
      expect(bundle.sections.length, 68);
      // Map-Keys sind Unterstrich-Notation, Inhalt Punkt-Notation.
      expect(bundle.sections['3_2_2_1']!.sectionId, '3.2.2.1');

      var saetze = 0, marks = 0, belege = 0;
      for (final sec in bundle.sections.values) {
        for (final p in sec.paragraphs) {
          belege += p.belege.length;
          for (final s in p.sentences) {
            saetze++;
            marks += s.marks.length;
          }
        }
      }
      expect(saetze, 688);
      expect(marks, 1369);
      expect(belege, 397);
    });

    test('Quellen: 74 Stück, Arten-Verteilung, Dossier-Fallbacks', () {
      expect(bundle.sources.length, 74);
      expect(bundle.sources.where((s) => s.dossierFallback).length, 66);
      final byKind = <String, int>{};
      for (final s in bundle.sources) {
        byKind[s.kind] = (byKind[s.kind] ?? 0) + 1;
      }
      expect(byKind, {
        'artikel': 20,
        'konferenz': 1,
        'norm': 1,
        'report': 8,
        'online': 28,
        'recht-eu': 10,
        'recht-at': 6,
      });
      // kind-Sonderlogik: Rechtsquellen belegen über Fundstellen.
      final dsgvo = bundle.sources.firstWhere((s) => s.id == 'dsgvo');
      expect(dsgvo.kindEnum, SourceKind.rechtEu);
      expect(dsgvo.zitiertNachFundstelle, isTrue);
      final artikel = bundle.sources.firstWhere((s) => s.kind == 'artikel');
      expect(artikel.zitiertNachFundstelle, isFalse);
    });

    test('Meta: Stats, Timeline (W2-Felder), Kapitel-Fluss, 13 Findings', () {
      final stats = bundle.meta.stats!;
      expect(stats.quellen, 74);
      expect(stats.fussnoten, 397);
      expect(stats.absaetze, 233);
      expect(stats.saetze, 688);
      expect(stats.belege, 397);
      expect(stats.kindLabels, kindLabels); // Bundle-Variante == App-Konstante (W5)

      // Timeline nutzt kategorie/status (NICHT das veraltete `typ` der Doku).
      final timeline = bundle.meta.gesamt!.timeline;
      expect(timeline.length, 14);
      expect(timeline.first.kategorie, anyOf('at', 'eu'));
      expect(timeline.first.isErledigt, isTrue);

      // Kapitel-Fluss nutzt from/to als Strings.
      final fluss = bundle.meta.fazit!.kapitelFluss;
      expect(fluss.length, 8);
      expect(fluss.first.from, '1');
      expect(fluss.first.to, '2');

      expect(bundle.meta.fazit!.findings.length, 13);
      expect(bundle.meta.erklaerbuch, startsWith('# 📓 Erklärbuch'));
      // W3: Die eingebaute Arbeit hat KEINE connections im Meta.
      expect(bundle.meta.connections, isNull);
      expect(bundle.meta.instanzen, isNull);
    });

    test('Figuren-Manifest: 4 Abbildungen (1× file null) + 2 Tabellen', () {
      expect(bundle.figures.figuren.length, 4);
      expect(bundle.figures.tabellen.length, 2);
      expect(
        bundle.figures.figuren.where((f) => f.file == null).map((f) => f.id),
        ['abb-3-4-2'],
      );
      expect(bundle.figures.tabellen.first.kopf, isNotEmpty);
      expect(bundle.figures.tabellen.first.zeilen, isNotEmpty);
    });

    test('Sensors-Projekt vorhanden (Builtin v6, 24 Quellen, 90 Fußnoten)', () {
      expect(bundle.builtinProjects.length, 1);
      final rec = bundle.builtinProjects.single;
      expect(rec.id, 'sensors-paper');
      expect(rec.name, 'Mobile Sensors in Education (Paper)');
      expect(rec.builtin, isTrue);
      expect(rec.builtinVersion, 6);
      expect(rec.tex, isNotEmpty);
      expect(rec.registry.length, 24);
      // Registry-Aliasse sind Regex-Strings und kompilierbar.
      expect(rec.registry.first.compileAliases(), isNotEmpty);
      expect(rec.parsed.footnotes.length, 90);
      expect(rec.generated.sections.length, 34);
      expect(rec.generated.connections!.connections.length, 14);
      expect(rec.generated.instanzen!.defs.length, 2);
    });
  });

  group('Invarianten', () {
    test('join(sentences.text) == Absatztext (whitespace-normalisiert)', () {
      // Gleiche Prüfung wie build_data.js:38-41 — hier über ALLE
      // Text-Absätze mit Auflösung (Stichprobe wäre unnötig kleinlich).
      String norm(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
      var checked = 0;
      for (final u in allUnits(bundle.thesis)) {
        final sec = bundle.sections[fileIdOf(u.id)];
        if (sec == null) continue;
        final byId = {for (final p in sec.paragraphs) p.id: p};
        for (final p in u.paragraphs) {
          final gp = byId[p.id];
          if (gp == null || !p.isText || gp.sentences.isEmpty) continue;
          expect(
            norm(gp.sentences.map((s) => s.text).join(' ')),
            norm(p.text),
            reason: 'Satz-Rekonstruktion weicht ab bei ${p.id}',
          );
          expect(gp.reconstructDivergent, isFalse, reason: p.id);
          checked++;
        }
      }
      expect(checked, greaterThan(200)); // praktisch alle 226 Text-Absätze
    });

    test('mark.snippet ist wörtlicher Teilstring seines Satzes', () {
      // Stichprobe über den ersten Abschnitt reicht — build_data hat beim
      // Bundle-Bau bereits alle ungültigen Marks entfernt.
      final sec = bundle.sections['1_1']!;
      for (final p in sec.paragraphs) {
        for (final s in p.sentences) {
          final plain = s.text.replaceAll(RegExp(r'\[\^\d+\]'), '');
          for (final m in s.marks) {
            expect(
              s.text.contains(m.snippet) || plain.contains(m.snippet),
              isTrue,
              reason: 'Mark nicht im Satz: "${m.snippet}"',
            );
          }
        }
      }
    });

    test('W2-Toleranz: kapitelFluss liest auch das Alt-Format von/nach', () {
      final kante = KapitelFlussKante.fromJson({'von': 1, 'nach': 3, 'label': 'x'});
      expect(kante.from, '1');
      expect(kante.to, '3');
    });
  });

  group('Indizes (Pendant zu rebuildDataIndexes)', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(activeRuntimeProvider.notifier)
          .activate(ThesisRuntime.fromBundle(bundle));
    });

    test('unitIndex: 69 Einträge, Lookup in beiden Notationen', () {
      final idx = container.read(unitIndexProvider);
      expect(idx.byId.length, 69);
      // Unterstrich- UND Punkt-Notation finden denselben Eintrag.
      final byFileId = idx['3_2_2'];
      final byDots = idx['3.2.2'];
      expect(byFileId, isNotNull);
      expect(identical(byFileId, byDots), isTrue);
      expect(byFileId!.sectionId, '3.2.2');
      expect(byFileId.fileId, '3_2_2');
      expect(byFileId.chapter.num, 3);
      expect(byFileId.unit.level, 3);
    });

    test('orderedUnits: 68 Abschnitte mit Inhalt, DFS-Reihenfolge', () {
      final ordered = container.read(orderedUnitsProvider);
      expect(ordered.length, 68);
      expect(ordered.first, '1.1');
      // Level-4-Kinder folgen direkt auf ihren Eltern-Abschnitt.
      expect(
        ordered.indexOf('3.2.2.1'),
        container.read(orderedUnitsProvider).indexOf('3.2.2') + 1,
      );
    });

    test('fnIndex: 397 Fußnoten mit Fundort; findBeleg liefert den Beleg', () {
      final idx = container.read(fnIndexProvider);
      expect(idx.length, 397);
      final fn1 = idx[1]!;
      expect(fn1.sectionId, '1.1');
      expect(fn1.paragraphId, '1.1-p2');
      expect(fn1.sources, contains('ehds-vo'));

      final beleg = container.read(findBelegProvider(1));
      expect(beleg, isNotNull);
      expect(beleg!.num, 1);
      expect(beleg.quellen, contains('ehds-vo'));
      expect(beleg.fundstelle, isNotEmpty);
    });

    test('srcById: 74 Quellen; Figuren-/Tabellen-Index nach Absatz', () {
      expect(container.read(srcByIdProvider).length, 74);
      expect(container.read(srcByIdProvider)['dsgvo']!.kind, 'recht-eu');
      expect(container.read(figByParaProvider).length, 4);
      expect(container.read(figByParaProvider)['3.3.2-p4']!.id, 'abb-3-3-2');
      expect(container.read(tabByParaProvider).length, 2);
    });

    test('srcShort: bekannte Kurznamen + Autor-/Online-Fallbacks', () {
      expect(srcShortKnown.length, 20);
      expect(container.read(srcShortProvider('ehds-vo')), 'EHDS-VO');
      expect(container.read(srcShortProvider('gtelg2012')), 'GTelG');
      // Autor-Fallback: "AlJarullah, Asma u.a." (2013) → "AlJarullah 2013".
      expect(container.read(srcShortProvider('aljarullah2013')), 'AlJarullah 2013');
      // Unbekannte id ohne Quelle → die id selbst.
      expect(container.read(srcShortProvider('gibtsnicht')), 'gibtsnicht');
    });

    test('TextOverrides: effektive Sicht + Wiederherstellen ohne Mutation', () {
      container.read(textOverridesProvider.notifier).set(const TextOverrideState(
            paraEdits: {'1.1-p1': 'Neuer Text.'},
            fnEdits: {1: 'Editierte Fußnote.'},
            titleEdits: {'ch1': 'Kapitel neu', '1.1': 'Abschnitt neu'},
          ));
      final idx = container.read(unitIndexProvider);
      expect(idx['1.1']!.unit.title, 'Abschnitt neu');
      expect(idx['1.1']!.chapter.title, 'Kapitel neu');
      expect(idx['1.1']!.unit.paragraphs.first.text, 'Neuer Text.');
      expect(container.read(fnIndexProvider)[1]!.text, 'Editierte Fußnote.');

      // Override entfernen → Original kommt zurück (kein _orig-Backup nötig,
      // die Runtime blieb unveränderlich).
      container.read(textOverridesProvider.notifier).set(TextOverrideState.empty);
      expect(container.read(unitIndexProvider)['1.1']!.unit.title, 'Aufgabenstellung');
      expect(container.read(fnIndexProvider)[1]!.text, startsWith('Verordnung (EU) 2025/327'));
    });

    test('Runtime einer Instanz-Arbeit: buildRuntime-Port (Sensors)', () {
      final rt = ThesisRuntime.fromProjectRecord(bundle.builtinProjects.single);
      expect(rt.projectId, 'sensors-paper');
      expect(rt.sources.length, 24);
      // Dossier-Kaskade: generierte Dossiers vorhanden → kein Fallback.
      final abowd = rt.sources.firstWhere((s) => s.id == 'abowd_towards_1999');
      expect(abowd.dossierFallback, isFalse);
      expect(abowd.stellen, isNotEmpty);
      // Berechnete Statistiken (nie gespeichert).
      final stats = rt.meta.stats!;
      expect(stats.quellen, 24);
      expect(stats.fussnoten, 90);
      expect(stats.saetze, greaterThan(0));
      expect(stats.kindLabels, kindLabels);
      expect(rt.meta.connections!.connections.length, 14);
      expect(rt.instanzen!.defs.map((d) => d.id), ['sensorblick', 'pruefungsfrage']);
      expect(rt.erklaerbuch, isNotNull);

      // Projektwechsel: aktivieren → Indizes bauen sich reaktiv neu.
      container.read(activeRuntimeProvider.notifier).activate(rt);
      expect(container.read(fnIndexProvider).length, 90);
      expect(container.read(unitIndexProvider)['0.0'], isNotNull);
    });
  });
}
