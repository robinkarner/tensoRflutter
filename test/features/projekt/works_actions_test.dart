/// Tests der Arbeiten-Aktionen (K-2): createFromTex (Record-Form + id-Schema
/// projects.js:105-113), applyRegistry (Re-Parse + userModified) und der
/// ISO-Zeitstempel im JS-Format.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/data/db/database.dart';
import 'package:thesor/data/repos/project_repository.dart';
import 'package:thesor/features/projekt/arbeiten/works_actions.dart';

/// Minimal ladbare Arbeit (1 Kapitel, 2 Abschnitte, 1 Fußnote).
const kMinimalTex = r'''
\documentclass{report}
\title{Testarbeit K2}
\author{Tester}
\begin{document}
\chapter{Einleitung}
\section{Motivation}
Erster Satz mit Beleg.\footnote{Vgl. Kim 2023, S. 4.} Zweiter Satz.
\section{Aufbau}
Noch ein Absatz ohne Fußnote, aber mit genug Text.
\end{document}
''';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late ProjectRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    repo = container.read(projectRepositoryProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('isoNowUtc: JS-toISOString-Format (Millisekunden + Z)', () {
    final iso = isoNowUtc(DateTime.utc(2026, 7, 23, 10, 0, 0, 1));
    expect(iso, '2026-07-23T10:00:00.001Z');
    expect(
      isoNowUtc(),
      matches(RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$')),
    );
  });

  test('createFromTex: id-Schema, Record-Form, Speicherung', () async {
    final r = await createFromTex(repo, 'Masterarbeit XY', kMinimalTex);
    expect(r.ok, isTrue);
    // id `p-<slug30>-<rand4>` (projects.js:105-106).
    expect(r.id, matches(RegExp(r'^p-masterarbeit-xy-[0-9a-z]{4}$')));

    final rec = r.rec!;
    expect(rec.name, 'Masterarbeit XY');
    expect(rec.tex, kMinimalTex);
    expect(rec.raw['registry'], isEmpty);
    // generated startet leer in der Original-Form (projects.js:111).
    final g = rec.raw['generated'] as Map;
    expect(g.keys.toSet(), {
      'sections', 'sources', 'chapters', 'gesamt', 'fazit', 'analyse',
      'connections',
    });
    expect(g['gesamt'], isNull);
    expect(rec.raw['figures'], {'figuren': [], 'tabellen': []});
    expect(rec.parsed.thesis.chapters, hasLength(1));
    expect(rec.parsed.footnotes, hasLength(1));

    // Gespeichert (Projects.save-Pendant).
    final loaded = await repo.get(r.id!);
    expect(loaded, isNotNull);
    expect(loaded!.name, 'Masterarbeit XY');
  });

  test('createFromTex: leerer Name → Titel aus dem Parse', () async {
    final r = await createFromTex(repo, '', kMinimalTex);
    expect(r.ok, isTrue);
    expect(r.rec!.name, 'Testarbeit K2');
    // Slug-Fallback 'arbeit' (name || 'arbeit', projects.js:105).
    expect(r.id, matches(RegExp(r'^p-arbeit-[0-9a-z]{4}$')));
  });

  test('createFromTex: Parse-Fehler → nichts gespeichert', () async {
    final r = await createFromTex(repo, 'Kaputt', 'zu kurz');
    expect(r.ok, isFalse);
    expect(r.id, isNull);
    expect(await repo.list(), isEmpty);
  });

  test('applyRegistry: Re-Parse, userModified, registry ersetzt', () async {
    final created = await createFromTex(repo, 'Reg-Test', kMinimalTex);
    final registry = <Object?>[
      {
        'id': 'kim2023',
        'kind': 'artikel',
        'author': 'Kim, J.',
        'year': 2023,
        'title': 'Health Data Paper',
        'aliases': ['Kim'],
      },
    ];
    final (r, updated) = await applyRegistry(repo, created.rec!, registry);
    expect(r.ok, isTrue);
    expect(updated.userModified, isTrue);
    expect(updated.raw['registry'], registry);
    // Die Fußnote „Vgl. Kim 2023“ matcht den Alias → Quelle zugeordnet.
    expect(updated.parsed.sources.map((s) => s.id), contains('kim2023'));
    // Persistiert.
    final loaded = await repo.get(updated.id);
    expect(loaded!.userModified, isTrue);
  });
}
