/// Kernlogik-Tests des Studio-Zustands (S-2): Dock-/View-Logik,
/// StudioKv-Write-Through mit §0-Override-Sync, Prefs-Persistenz,
/// fileShow-Zustandsfluss.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thesor/data/bundles/indexes.dart';
import 'package:thesor/data/db/database.dart';
import 'package:thesor/data/db/kv.dart';
import 'package:thesor/data/models/models.dart';
import 'package:thesor/features/studio/layout/dock_state.dart';
import 'package:thesor/features/studio/layout/studio_state.dart';

/// Kleine Test-Arbeit: 1 Kapitel, 1 Abschnitt, 2 Absätze, 1 Fußnote.
ThesisRuntime testRuntime() {
  final thesis = Thesis.fromJson({
    'meta': {'title': 'Testarbeit'},
    'chapters': [
      {
        'id': '1',
        'num': 1,
        'title': 'Einleitung',
        'sections': [
          {
            'id': '1.1',
            'title': 'Motivation',
            'level': 2,
            'paragraphs': [
              {
                'id': '1.1-p1',
                'type': 'text',
                'text': 'Erster Satz. Zweiter Satz mit Beleg.[^1]',
                'footnotes': [
                  {'num': 1, 'text': 'Vgl. Kim 2023, S. 4.', 'sources': ['kim2023']},
                ],
              },
              {'id': '1.1-p2', 'type': 'text', 'text': 'Ohne Belege.'},
            ],
          },
        ],
      },
    ],
  });
  return ThesisRuntime(
    projectId: 'default',
    projectName: 'Testarbeit',
    thesis: thesis,
    sections: {
      '1_1': SectionAnalyse.fromJson({
        'sectionId': '1.1',
        'paragraphs': [
          {
            'id': '1.1-p1',
            'kernaussage': 'Kern von p1.',
            'uebersetzung': 'Translation p1.',
            'sentences': [
              {'text': 'Erster Satz.', 'einfach': 'Einfach eins.'},
              {
                'text': 'Zweiter Satz mit Beleg.[^1]',
                'einfach': 'Einfach zwei.',
                'marks': [
                  {'snippet': 'Beleg', 'kategorie': 'schlag'},
                ],
              },
            ],
            'belege': [
              {
                'num': 1,
                'quellen': ['kim2023'],
                'claim': 'Was belegt wird.',
                'fundstelle': 'S. 4',
                'suchHinweis': 'health data | secondary use',
              },
            ],
          },
        ],
      }),
    },
    sources: [
      Source.fromJson(const {
        'id': 'kim2023',
        'title': 'Health Data Paper',
        'author': 'Kim, J.',
        'year': 2023,
        'kind': 'artikel',
        'citations': [
          {'footnote': 1},
        ],
      }),
    ],
    instanzen: Instanzen.fromJson(const {
      'defs': [
        {'id': 'kritik', 'label': '🗯 Kritik', 'color': '#c05f5f'},
      ],
      'items': {
        'kritik': {'1.1-p1': '**Kritik** an p1'},
      },
    }),
  );
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    container.read(activeRuntimeProvider.notifier).activate(testRuntime());
    // Prefs + KV-Schnappschuss laden.
    await container.read(studioPrefsCtlProvider.future);
    await container.read(studioKvProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('dockDefs', () {
    test('Defaults + Projekt-Instanz vor „◻ Ohne“', () {
      final defs = container.read(dockDefsProvider);
      expect(defs.map((d) => d.id), [
        'schnell', 'connections', 'srcview', 'uebersetzung', 'erklaerung',
        'analyse', 'kritik', 'clear',
      ]);
      expect(defs.firstWhere((d) => d.id == 'kritik').project, isTrue);
      expect(defs.firstWhere((d) => d.id == 'schnell').special, isTrue);
    });

    test('gespeicherte instDefs übersteuern Reihenfolge, Spezials abgesichert',
        () async {
      container.read(studioKvProvider.notifier).put(StudioUiKeys.instDefs, [
        {'id': 'erklaerung', 'label': '✎ Meine Erklärung'},
      ]);
      final defs = container.read(dockDefsProvider);
      final ids = defs.map((d) => d.id).toList();
      // Umbenannte View + alle Spezial-/Projekt-Views vorhanden:
      expect(defs.firstWhere((d) => d.id == 'erklaerung').label,
          '✎ Meine Erklärung');
      // Farbe fällt auf die Default-Farbe zurück (base lookup).
      expect(defs.firstWhere((d) => d.id == 'erklaerung').color, 'var(--good)');
      for (final want in ['schnell', 'connections', 'srcview', 'clear', 'kritik']) {
        expect(ids, contains(want));
      }
      expect(ids.last, 'clear');
    });
  });

  group('dockModeFor', () {
    test('Abschnitts-Override (auch explizites null) > globaler Standard', () {
      // Default: 'connections'.
      expect(container.read(dockModeForProvider('1.1')), 'connections');
      // Explizit geschlossen (null-Override):
      container
          .read(studioKvProvider.notifier)
          .put(KvKeys.dockBySection, {'1.1': null});
      expect(container.read(dockModeForProvider('1.1')), isNull);
      // Anderer Abschnitt behält den globalen Standard.
      expect(container.read(dockModeForProvider('9.9')), 'connections');
    });

    test('setDock leert dockBySection („Auswahl gilt überall“)', () async {
      container
          .read(studioKvProvider.notifier)
          .put(KvKeys.dockBySection, {'1.1': 'analyse'});
      container.read(studioPrefsCtlProvider.notifier).setDock('erklaerung');
      expect(container.read(dockModeForProvider('1.1')), 'erklaerung');
    });
  });

  group('dockAuto', () {
    test('uebersetzung/erklaerung/analyse aus der Voranalyse', () {
      final domain = container.read(studioDomainProvider)!;
      final p = domain.ctx.unitIndex['1.1']!.unit.paragraphs.first;
      expect(dockAutoFor(domain, 'uebersetzung', '1.1', p), 'Translation p1.');
      expect(dockAutoFor(domain, 'erklaerung', '1.1', p),
          'Einfach eins. Einfach zwei.');
      expect(
        dockAutoFor(domain, 'analyse', '1.1', p),
        '**Kernaussage:** Kern von p1.\n\n**Belegt wird:** Was belegt wird.',
      );
    });

    test('mitgelieferte Projekt-Instanz-Inhalte', () {
      final domain = container.read(studioDomainProvider)!;
      final p = domain.ctx.unitIndex['1.1']!.unit.paragraphs.first;
      expect(dockAutoFor(domain, 'kritik', '1.1', p), '**Kritik** an p1');
      expect(dockAutoFor(domain, 'unbekannt', '1.1', p), '');
    });
  });

  group('StudioKv (§0 Override-Sync)', () {
    test('put(paraEdits) zieht textOverridesProvider nach', () {
      container
          .read(studioKvProvider.notifier)
          .put(KvKeys.paraEdits, {'1.1-p1': 'Neuer Text.[^1]'});
      final ov = container.read(textOverridesProvider);
      expect(ov.paraEdits['1.1-p1'], 'Neuer Text.[^1]');
      // Effektive Sicht übernimmt den Override:
      final eff = container.read(effectiveThesisProvider)!;
      expect(
        eff.chapters.first.sections.first.paragraphs.first.text,
        'Neuer Text.[^1]',
      );
    });

    test('put(fnEdits) mit String-Keys wird zu int-Keys der Overrides', () {
      container
          .read(studioKvProvider.notifier)
          .put(KvKeys.fnEdits, {'1': 'Editierter Fußnotentext'});
      expect(container.read(textOverridesProvider).fnEdits[1],
          'Editierter Fußnotentext');
      expect(container.read(fnIndexProvider)[1]!.text, 'Editierter Fußnotentext');
    });

    test('titleEdits: leeren = Original zurück', () {
      final kv = container.read(studioKvProvider.notifier);
      kv.put(KvKeys.titleEdits, {'ch1': 'Umbenannt'});
      expect(container.read(effectiveThesisProvider)!.chapters.first.title,
          'Umbenannt');
      kv.put(KvKeys.titleEdits, <String, Object?>{});
      expect(container.read(effectiveThesisProvider)!.chapters.first.title,
          'Einleitung');
    });

    test('Write-Through landet in der DB (Reload liest denselben Stand)',
        () async {
      container
          .read(studioKvProvider.notifier)
          .put(KvKeys.belegSpans, {'1': 2});
      // kurz warten, bis der async KV-Write durch ist
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final kv = container.read(kvStoreProvider);
      expect(await kv.getJson(KvKeys.belegSpans), {'1': 2});
    });
  });

  group('StudioDomain', () {
    test('sectionSources + paraBelege + Levels-Kaskade', () {
      final domain = container.read(studioDomainProvider)!;
      expect(domain.sectionSources('1.1'), {'kim2023': [1]});
      final p = domain.ctx.unitIndex['1.1']!.unit.paragraphs.first;
      final belege = domain.paraBelege('1.1', p);
      expect(belege.single.claim, 'Was belegt wird.');
      // KI-Beleg vorhanden → Stufe 1 (vermutet).
      expect(domain.levels.info(1).level, 1);
    });

    test('Levels.save über den Studio-Store hebt die Stufe reaktiv', () {
      final domain = container.read(studioDomainProvider)!;
      domain.levels.save(1, {'zitat': 'Originalpassage'});
      // Der Store-Write invalidiert studioKv → neue Domäne liest Stufe 2.
      final domain2 = container.read(studioDomainProvider)!;
      expect(domain2.levels.info(1).level, 2);
    });

    test('Mentions-Status wandert durch den Studio-Store', () {
      final domain = container.read(studioDomainProvider)!;
      domain.mentions.setStatus('1.1-p1|0', 'bestaetigt', 'kim2023');
      final snap = container.read(studioKvProvider).value!;
      final tm = snap[KvKeys.textMentions] as Map;
      expect((tm['1.1-p1|0'] as Map)['status'], 'bestaetigt');
    });
  });

  group('StudioFile / Selection', () {
    test('fileShow-Zustand: Auswahl + Generation-Token', () {
      final file = container.read(studioFileProvider.notifier);
      expect(container.read(studioFileProvider).gen, 0);
      file.show('kim2023', 1);
      expect(container.read(studioFileProvider).srcId, 'kim2023');
      expect(container.read(studioFileProvider).gen, 1);
      // Fn-Wechsel remountet NICHT (gen bleibt):
      file.setFn(1);
      expect(container.read(studioFileProvider).gen, 1);
      file.remount();
      expect(container.read(studioFileProvider).gen, 2);
    });
  });

  group('StudioPrefs', () {
    test('Persistenz-Roundtrip über die KV-Schicht', () async {
      final ctl = container.read(studioPrefsCtlProvider.notifier);
      ctl.setDichte('kompakt');
      ctl.toggleFast();
      ctl.toggleCat('norm');
      ctl.setTreeW(300);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final kv = container.read(kvStoreProvider);
      expect(await kv.getJson(StudioUiKeys.lesenDichte), 'kompakt');
      expect(await kv.getJson(StudioUiKeys.lesenFast), true);
      final cats = await kv.getJson(StudioUiKeys.cats);
      expect(cats, isA<List<Object?>>());
      expect(cats as List, isNot(contains('norm')));
      expect(await kv.getJson(StudioUiKeys.uiTreeW), 300);
    });

    test('uiDockMode: gespeichertes null heißt „∅ Ohne“', () async {
      await container.read(kvStoreProvider).setJson(StudioUiKeys.uiDockMode, null);
      container.invalidate(studioPrefsCtlProvider);
      final prefs = await container.read(studioPrefsCtlProvider.future);
      expect(prefs.dock, isNull);
    });
  });
}
