/// FileStore: Schlüsselschema, Ablage-Workflow, clearAll und die
/// Import-Kandidaten-Suche (Referenz-Hash → id → Dateinamen-Matching mit
/// dem Original-Scoring 25/60/100).
library;

import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/data/db/database.dart';
import 'package:thesor/data/models/models.dart';
import 'package:thesor/data/repos/file_store.dart';

Uint8List _pdf() => Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2d]); // %PDF-

Source _source(String id, {String? title, String? author, int? year}) =>
    Source.fromJson({
      'id': id,
      'kind': 'artikel',
      'title': ?title,
      'author': ?author,
      'year': ?year,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FileStore store;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    store = FileStore(db.fileBlobsDao);
    await store.init();
  });

  tearDown(() async {
    store.dispose();
    await db.close();
  });

  test('addFiles: Dateiname ohne .pdf wird zum Schlüssel; nur PDFs', () async {
    final n = await store.addFiles([
      ('cobrado2024.pdf', _pdf()),
      ('notizen.txt', _pdf()),
    ]);
    expect(n, 1);
    expect(store.has('cobrado2024'), isTrue);
    expect(await store.getData('cobrado2024'), isNotNull);
  });

  test('Ablage: addInbox → assignInbox kopiert auf die Quellen-id', () async {
    await store.addInbox('Study_Health_2024.pdf', _pdf());
    expect(store.listInbox(), ['Study_Health_2024.pdf']);
    expect(await store.assignInbox('Study_Health_2024.pdf', 'kraus2025'), isTrue);
    expect(store.listInbox(), isEmpty);
    expect(store.has('kraus2025'), isTrue);
  });

  test('Bild-Quellen unter img:<id>, getrennt von PDFs', () async {
    await store.putImage('foto1', _pdf(), mime: 'image/png');
    expect(store.hasImage('foto1'), isTrue);
    expect(store.has('foto1'), isFalse);
    final img = await store.getImage('foto1');
    expect(img?.$2, 'image/png');
  });

  test('Klassifikation überlebt Neustart (init aus der DB)', () async {
    await store.putData('a1', _pdf());
    await store.addInbox('x.pdf', _pdf());
    await store.putImage('b2', _pdf());

    final fresh = FileStore(db.fileBlobsDao);
    await fresh.init();
    expect(fresh.has('a1'), isTrue);
    expect(fresh.listInbox(), ['x.pdf']);
    expect(fresh.hasImage('b2'), isTrue);
    fresh.dispose();
  });

  test('clearAll löscht alles inkl. Ablage und Bilder', () async {
    await store.putData('a1', _pdf());
    await store.addInbox('x.pdf', _pdf());
    await store.putImage('b2', _pdf());
    await store.clearAll();
    expect(store.count(), 0);
    expect(store.listInbox(), isEmpty);
    expect(store.hasImage('b2'), isFalse);
  });

  test('extraKey-Schema <srcId>~x…', () {
    final key = FileKeys.extra('dsgvo');
    expect(key, startsWith('dsgvo~x'));
  });

  group('Kandidaten-Suche', () {
    final sources = [
      _source('cobrado2024',
          title: 'Access control solutions in electronic health record systems: A systematic review',
          author: 'Cobrado, Usha Nicole u.a.',
          year: 2024),
      _source('kraus2025', title: 'Health Data Sharing in Europe', author: 'Kraus, M.', year: 2025),
    ];

    test('srcIdByHash findet die Quelle zum ts-Hash', () {
      // Hash aus dem Node-Fixture (crc32_test.dart).
      expect(srcIdByHash('ts-f12e5002', sources), 'cobrado2024');
      expect(srcIdByHash('ts-00000000', sources), isNull);
    });

    test('matchFilename: exakte id = 100 (sure)', () {
      final m = matchFilename('cobrado2024.pdf', sources)!;
      expect(m.id, 'cobrado2024');
      expect(m.score, greaterThanOrEqualTo(100));
      expect(m.sure, isTrue);
    });

    test('matchFilename: Titel-Tokens + Jahr ergeben Vorschlag', () {
      final m = matchFilename('access-control-solutions-2024.pdf', sources);
      expect(m?.id, 'cobrado2024');
    });

    test('matchFilename: unter Score 25 → null', () {
      expect(matchFilename('voellig-anderes-dokument.pdf', sources), isNull);
    });
  });
}
