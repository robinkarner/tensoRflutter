/// Projekt-Repository: Builtin-Seeding (Tombstones, Versions-/userModified-
/// Logik), Boot-Fluss (Scope-Reihenfolge, Fallback-Warnungen), Import mit
/// Kollisions-Semantik und Analysen-Import-Routing.
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/data/bundles/bundle_loader.dart';
import 'package:thesor/data/db/database.dart';
import 'package:thesor/data/db/kv.dart';
import 'package:thesor/data/db/seed.dart';
import 'package:thesor/data/export/projekt_format.dart';
import 'package:thesor/data/models/models.dart';
import 'package:thesor/data/repos/project_repository.dart';

/// Minimale, aber strukturell echte Thesis der Default-Arbeit.
final _defaultThesis = Thesis.fromJson({
  'meta': {'title': 'EHDS-Testarbeit', 'author': 'Robin'},
  'chapters': [
    {
      'id': '1',
      'num': 1,
      'title': 'Einleitung',
      'sections': [
        {
          'id': '1.1',
          'title': 'Aufgabenstellung',
          'level': 2,
          'paragraphs': [
            {'id': '1.1-p1', 'type': 'text', 'text': 'Hallo Welt.', 'footnotes': []},
          ],
          'children': [],
        },
      ],
    },
  ],
});

/// Builtin-Record (Pendant zum Sensors-Paper) mit gegebener Version.
ProjectRecord _builtin({int version = 6, bool userModified = false, String name = 'Sensors'}) =>
    ProjectRecord.fromJson({
      'id': 'sensors-paper',
      'name': name,
      'created': '2026-07-18T00:00:00.000Z',
      'builtin': true,
      'builtinVersion': version,
      if (userModified) 'userModified': true,
      'tex': '\\chapter{X}',
      'registry': [],
      'parsed': {
        'thesis': {
          'meta': {'title': 'Mobile Sensors'},
          'chapters': [
            {
              'id': '1',
              'num': 1,
              'title': 'Intro',
              'sections': [
                {
                  'id': '1.0',
                  'title': 'Überblick',
                  'level': 2,
                  'isIntro': true,
                  'paragraphs': [
                    {'id': '1.0-p1', 'type': 'text', 'text': 'Text.', 'footnotes': []},
                  ],
                  'children': [],
                },
              ],
            },
          ],
        },
        'footnotes': [],
        'sources': [],
      },
      'generated': {
        'sections': {},
        'sources': {},
        'chapters': {},
        'gesamt': null,
        'fazit': null,
        'analyse': {},
        'connections': null,
      },
      'figures': {'figuren': [], 'tabellen': []},
    });

ThesisBundle _bundle({List<ProjectRecord> builtins = const []}) => ThesisBundle(
      thesis: _defaultThesis,
      sections: const {},
      sources: const [],
      meta: const DataMeta(),
      figures: FiguresManifest.empty,
      builtinProjects: builtins,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late KvStore kv;
  late ProjectRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    kv = KvStore(db.kvDao);
    repo = ProjectRepository(db: db, kv: kv);
  });

  tearDown(() => db.close());

  group('seedBuiltinProjects', () {
    test('neuer Builtin wird eingespielt', () async {
      await seedBuiltinProjects(dao: db.projectsDao, kv: kv, builtins: [_builtin()]);
      expect((await repo.get('sensors-paper'))?.builtinVersion, 6);
    });

    test('Tombstone gewinnt immer', () async {
      await kv.setJson(KvKeys.builtinDeleted, ['sensors-paper']);
      await seedBuiltinProjects(dao: db.projectsDao, kv: kv, builtins: [_builtin()]);
      expect(await repo.get('sensors-paper'), isNull);
    });

    test('Update nur bei höherer Version und !userModified', () async {
      await repo.save(_builtin(version: 5, name: 'Alt'));
      await seedBuiltinProjects(
          dao: db.projectsDao, kv: kv, builtins: [_builtin(version: 6, name: 'Neu')]);
      expect((await repo.get('sensors-paper'))?.name, 'Neu');

      // userModified blockiert das Update trotz höherer Version.
      await repo.save(_builtin(version: 6, userModified: true, name: 'Meins'));
      await seedBuiltinProjects(
          dao: db.projectsDao, kv: kv, builtins: [_builtin(version: 7, name: 'Update')]);
      expect((await repo.get('sensors-paper'))?.name, 'Meins');
    });
  });

  group('boot', () {
    test('ohne activeProject: Default-Arbeit aus dem Bundle, Scope ""', () async {
      final r = await repo.boot(_bundle(builtins: [_builtin()]));
      expect(r.activeId, 'default');
      expect(r.activeName, ProjectRepository.defaultActiveName);
      expect(r.runtime.thesis.meta.title, 'EHDS-Testarbeit');
      expect(r.warnings, isEmpty);
      expect(kv.storeProject, '');
      // Seeding lief mit: der Builtin liegt in der DB.
      expect(await repo.get('sensors-paper'), isNotNull);
    });

    test('aktive Instanz-Arbeit: Runtime aus dem Record, Scope = id', () async {
      await kv.setRawGlobal(KvKeys.activeProject, 'sensors-paper');
      final r = await repo.boot(_bundle(builtins: [_builtin()]));
      expect(r.activeId, 'sensors-paper');
      expect(r.activeName, 'Sensors');
      expect(r.runtime.thesis.meta.title, 'Mobile Sensors');
      expect(kv.storeProject, 'sensors-paper');
    });

    test('unbekannte aktive Arbeit: Warnung + Rückfall auf default', () async {
      await kv.setRawGlobal(KvKeys.activeProject, 'p-weg-1234');
      final r = await repo.boot(_bundle());
      expect(r.activeId, 'default');
      expect(r.warnings.single,
          'Aktive Arbeit „p-weg-1234“ nicht gefunden — zurück zur eingebauten Arbeit.');
      // Der RAW-Key wurde zurückgesetzt (projects.js:38).
      expect(await kv.getRawGlobal(KvKeys.activeProject), 'default');
    });

    test('Custom-Quellen werden gemerged (projekt-gescoped gelesen)', () async {
      await kv.setJson(KvKeys.customSources, [
        {'id': 'mueller2023', 'title': 'Manuelle Quelle', 'kind': 'artikel'},
      ]);
      final r = await repo.boot(_bundle());
      expect(r.runtime.sources.map((s) => s.id), contains('mueller2023'));
    });

    test('Text-Overrides des Prüfstands werden geladen', () async {
      await kv.setJson(KvKeys.paraEdits, {'1.1-p1': 'Neuer Text.'});
      await kv.setJson(KvKeys.fnEdits, {'12': 'Neue Fußnote.'});
      final r = await repo.boot(_bundle());
      expect(r.overrides.paraEdits['1.1-p1'], 'Neuer Text.');
      expect(r.overrides.fnEdits[12], 'Neue Fußnote.');
    });

    test('Import-Once: ohne Asset kein Import, Flag bleibt ungesetzt', () async {
      final r = await repo.boot(_bundle());
      expect(r.importedBelegstand, isFalse);
      expect(await kv.getJson(KvKeys.belegstandImported), isNull);
    });
  });

  group('importRepoBelegstandOnce', () {
    test('importiert einmal aus dem Asset und setzt das Flag', () async {
      final assets = _MemoryAssetBundle({
        belegstandAsset:
            '{"format":"ehds-belegstand","version":2,"belegLevels":{"3":{"level":2,"zitat":"x"}}}',
      });
      expect(await importRepoBelegstandOnce(kv, bundle: assets), isTrue);
      expect((await kv.getMap(KvKeys.belegLevels))['3'], isNotNull);
      // Zweiter Lauf: Flag gesetzt → kein erneuter Import.
      expect(await importRepoBelegstandOnce(kv, bundle: assets), isFalse);
    });

    test('lokaler Fachzustand gewinnt — kein Import', () async {
      await kv.setJson(KvKeys.belegLevels, {'1': {'level': 3, 'seite': 2}});
      final assets = _MemoryAssetBundle({
        belegstandAsset: '{"format":"ehds-belegstand","version":2,"belegLevels":{"9":{}}}',
      });
      expect(await importRepoBelegstandOnce(kv, bundle: assets), isFalse);
      expect((await kv.getMap(KvKeys.belegLevels)).keys, ['1']);
    });
  });

  group('importProject', () {
    test('Kollision: Abbrechen importiert als Kopie', () async {
      await repo.save(_builtin());
      final jsonText = exportProjectJson(_builtin(name: 'Zweitimport'));
      final rec =
          await repo.importProject(jsonText, confirmOverwrite: (_, _) async => false);
      expect(rec.id, startsWith('sensors-paper-kopie-'));
      expect(rec.name, 'Zweitimport (Kopie)');
      expect(await repo.get(rec.id), isNotNull);
      // Das Original bleibt unangetastet.
      expect((await repo.get('sensors-paper'))?.name, 'Sensors');
    });

    test('fremdes Format: deutscher Original-Fehlertext', () {
      expect(
        () => repo.importProject('{"format":"x"}', confirmOverwrite: (_, _) async => true),
        throwsA(isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Unbekanntes Format — erwartet "thesis-studio-projekt" mit parsed.thesis.')),
      );
    });
  });

  group('applyGeneratedFile', () {
    test('Dateiname-Routing + userModified', () {
      final rec = _builtin();
      final r1 = repo.applyGeneratedFile(rec, '3_2_1.json', {
        'sectionId': '3.2.1',
        'paragraphs': [],
      });
      expect(r1.label, 'Abschnitt 3_2_1.json');
      expect(r1.rec.userModified, isTrue);
      expect(r1.rec.generated.sections.containsKey('3_2_1'), isTrue);
      // Der Ausgangs-Record bleibt unverändert (tiefe Kopie).
      expect(rec.raw['userModified'], isNot(true));

      final r2 = repo.applyGeneratedFile(rec, 'registry.json', {'kein': 'array'});
      expect(r2.registryError, 'registry.json muss ein ARRAY von Quellen sein');

      final r3 = repo.applyGeneratedFile(rec, 'registry.json', [
        {'id': 'a', 'aliases': ['a']},
      ]);
      expect(r3.registry, hasLength(1));

      final r4 = repo.applyGeneratedFile(rec, 'unbekannt.txt', {'x': 1});
      expect(r4.unknown, isTrue);

      // Inhaltsbasiert: Dossier ohne passenden Dateinamen.
      final r5 = repo.applyGeneratedFile(rec, 'irgendwas.json', {
        'sourceId': 'dsgvo',
        'dossier': '## Was ist diese Quelle?',
      });
      expect(r5.label, 'Dossier dsgvo');
    });
  });

  group('effectiveSrcLinks', () {
    test('DOI-Fallback und Override-Vorrang (util.js:236-245)', () {
      final s = Source.fromJson({'id': 'x', 'kind': 'artikel', 'doi': '10.1/y'});
      final auto = effectiveSrcLinks(s, const {});
      expect(auto.official, 'https://doi.org/10.1/y');
      expect(auto.isOverride, isFalse);

      final ov = effectiveSrcLinks(s, const {'official': 'https://manuell.example'});
      expect(ov.official, 'https://manuell.example');
      expect(ov.isOverride, isTrue);
    });
  });
}

/// Kleiner In-Memory-AssetBundle für den Import-Once-Test.
class _MemoryAssetBundle extends CachingAssetBundle {
  _MemoryAssetBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final text = files[key];
    if (text == null) {
      throw FlutterError('Asset nicht gefunden: $key');
    }
    final bytes = utf8.encode(text);
    return ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
  }
}
