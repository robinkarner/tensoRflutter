/// Integrationstests des Quellen-Fachzustands (S-4): QuellenKv-Write-Through
/// mit §0-Override-Sync, der DomainStore-Adapter (Levels schreiben durch)
/// und die Smart-Filter der Rail.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thesor/data/bundles/indexes.dart';
import 'package:thesor/data/db/database.dart';
import 'package:thesor/data/db/kv.dart';
import 'package:thesor/data/models/models.dart';
import 'package:thesor/features/quellen/library/lib_rail.dart';
import 'package:thesor/features/quellen/state/quellen_kv.dart';

/// Kleine Test-Arbeit: 1 Abschnitt, 1 Absatz, 2 Fußnoten, 2 Quellen
/// (Dokument-Quelle + EU-Rechtsquelle).
ThesisRuntime quellenTestRuntime() {
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
                'text': 'Satz mit Beleg.[^1] Und Rechtsgrundlage.[^2]',
                'footnotes': [
                  {'num': 1, 'text': 'Vgl. Kim 2023, S. 4.', 'sources': ['kim2023']},
                  {'num': 2, 'text': 'Art 5 DSGVO.', 'sources': ['dsgvo']},
                ],
              },
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
            'kernaussage': 'Kern.',
            'sentences': [
              {'text': 'Satz mit Beleg.[^1] Und Rechtsgrundlage.[^2]'},
            ],
            'belege': [
              {
                'num': 1,
                'quellen': ['kim2023'],
                'claim': 'Was belegt wird.',
                'fundstelle': 'S. 4',
              },
              {
                'num': 2,
                'quellen': ['dsgvo'],
                'claim': 'Rechtsgrundlage.',
                'fundstelle': 'Art 5',
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
          {'footnote': 1, 'sectionId': '1.1'},
        ],
      }),
      Source.fromJson(const {
        'id': 'dsgvo',
        'title': 'DSGVO',
        'kind': 'recht-eu',
        'citations': [
          {'footnote': 2, 'sectionId': '1.1'},
        ],
      }),
    ],
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
    container.read(activeRuntimeProvider.notifier).activate(quellenTestRuntime());
    await container.read(quellenKvProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('put → Write-Through in den KvStore + Schnappschuss', () async {
    final notifier = container.read(quellenKvProvider.notifier);
    notifier.put(KvKeys.srcNotes, {'kim2023': 'Noch prüfen'});

    expect(notifier.snapshot[KvKeys.srcNotes], {'kim2023': 'Noch prüfen'});
    final kv = container.read(kvStoreProvider);
    expect(await kv.getJson(KvKeys.srcNotes), {'kim2023': 'Noch prüfen'});
  });

  test('§0: put(paraEdits) zieht textOverridesProvider sofort nach', () {
    final notifier = container.read(quellenKvProvider.notifier);
    notifier.put(KvKeys.paraEdits, {'1.1-p1': 'Editierter Text.'});
    notifier.put(KvKeys.fnEdits, {'1': 'Neue Fußnote.'});

    final ov = container.read(textOverridesProvider);
    expect(ov.paraEdits['1.1-p1'], 'Editierter Text.');
    expect(ov.fnEdits[1], 'Neue Fußnote.');
  });

  test('DomainStore-Adapter: Levels.save läuft durch bis in den Store', () async {
    var domain = container.read(quellenDomainProvider)!;
    expect(domain.levels.info(1).level, 1); // KI-Vermutung (Kaskaden-Boden)

    domain.levels.save(1, {'seite': 4, 'zitat': 'Original.'});

    // Der Schnappschuss ist synchron aktuell → neue Domain-Sicht lesen.
    domain = container.read(quellenDomainProvider)!;
    expect(domain.levels.info(1).level, 3); // Seite ⇒ Stufe 3
    final counts = domain.levels.countsFor(domain.levels.numsForSource('kim2023'));
    expect(counts.total, 1);
    expect(counts.l3, 1);

    final kv = container.read(kvStoreProvider);
    final stored = await kv.getMap(KvKeys.belegLevels);
    expect(stored.containsKey('1'), isTrue);
  });

  test('Smart-Filter der Rail (offen/fertig/notizen/custom/pdf-fehlt)', () {
    var domain = container.read(quellenDomainProvider)!;
    final kim = domain.ctx.srcById['kim2023']!;
    final dsgvo = domain.ctx.srcById['dsgvo']!;

    // Ausgangslage: kim offen, nichts fertig, keine Notizen, kein custom.
    expect(quellenSmartFilter('offen', kim, domain, null), isTrue);
    expect(quellenSmartFilter('fertig', kim, domain, null), isFalse);
    expect(quellenSmartFilter('notizen', kim, domain, null), isFalse);
    expect(quellenSmartFilter('custom', kim, domain, null), isFalse);
    // Dokument-Quelle ohne Datei → „PDF fehlt"; Rechtsquelle nie.
    expect(quellenSmartFilter('pdf-fehlt', kim, domain, null), isTrue);
    expect(quellenSmartFilter('pdf-fehlt', dsgvo, domain, null), isFalse);

    // Beleg auf Stufe 3 + Notiz → fertig/notizen springen um.
    domain.levels.save(1, {'seite': 4});
    container.read(quellenKvProvider.notifier).put(KvKeys.srcNotes, {'kim2023': 'x'});
    domain = container.read(quellenDomainProvider)!;
    expect(quellenSmartFilter('offen', domain.ctx.srcById['kim2023']!, domain, null), isFalse);
    expect(quellenSmartFilter('fertig', domain.ctx.srcById['kim2023']!, domain, null), isTrue);
    expect(quellenSmartFilter('notizen', domain.ctx.srcById['kim2023']!, domain, null), isTrue);
  });

  test('setSrcLink: setzen, überschreiben, leeren räumt die Map auf', () async {
    final kv = container.read(kvStoreProvider);
    await setSrcLink(kv, 'kim2023', 'official', 'https://example.org/a');
    expect(await kv.getMap(KvKeys.linkOverrides), {
      'kim2023': {'official': 'https://example.org/a'},
    });

    await setSrcLink(kv, 'kim2023', 'file', 'https://example.org/a.pdf');
    await setSrcLink(kv, 'kim2023', 'official', '');
    expect(await kv.getMap(KvKeys.linkOverrides), {
      'kim2023': {'file': 'https://example.org/a.pdf'},
    });

    // Letzter Override weg → Quelle fliegt ganz aus der Map.
    await setSrcLink(kv, 'kim2023', 'file', null);
    expect(await kv.getMap(KvKeys.linkOverrides), isEmpty);
  });
}
