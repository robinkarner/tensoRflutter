/// KV-Scoping — die Namensraum-Regeln des Originals (util.js:195-211):
/// Default-Arbeit unpräfixiert, Instanz-Arbeiten gescoped, globale Keys nie,
/// RAW-Keys ohne JSON-Hülle. Bruch hier = Datenverlust bei der Migration
/// (Master §7 Risiko 7).
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/data/db/database.dart';
import 'package:thesor/data/db/kv.dart';

void main() {
  late AppDatabase db;
  late KvStore kv;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    kv = KvStore(db.kvDao);
  });

  tearDown(() => db.close());

  test('PROJECT_KEYS-Whitelist hat exakt die 26 Original-Einträge (W1)', () {
    expect(KvKeys.projectKeys, const [
      'belegLevels', 'annotations', 'resolutions', 'pdfManual', 'linkOverrides',
      'srcNotes', 'srcTexts', 'texEdits', 'pdfMarks', 'customSources',
      'kiConnections', 'textMentions', 'fileSearch', 'dlStatus', 'paraDock',
      'paraEdits', 'dockBySection', 'marksExtra', 'notebook', 'studioLast',
      'assignDismissed', 'fnEdits', 'belegSpans', 'titleEdits', 'srcDoc',
      'srcExtras',
    ]);
    expect(KvKeys.projectKeys.length, 26);
  });

  test('Default-Arbeit schreibt unpräfixiert (Scope "")', () async {
    kv.storeProject = '';
    await kv.setJson(KvKeys.belegLevels, {'17': {'level': 3}});
    expect(kv.scopeFor(KvKeys.belegLevels), '');
    expect(await db.kvDao.read('', KvKeys.belegLevels), isNotNull);
  });

  test('Instanz-Arbeit scoped Projekt-Keys, globale Keys bleiben global', () async {
    kv.storeProject = 'p-test-abcd';
    await kv.setJson(KvKeys.belegLevels, {'1': {'level': 2}});
    await kv.setJson(KvKeys.theme, 'dark');

    // Projekt-Key liegt unter der Projekt-id …
    expect(await db.kvDao.read('p-test-abcd', KvKeys.belegLevels), isNotNull);
    expect(await db.kvDao.read('', KvKeys.belegLevels), isNull);
    // … globaler Key (nicht auf der Whitelist) bleibt unpräfixiert.
    expect(await db.kvDao.read('', KvKeys.theme), isNotNull);
    expect(await db.kvDao.read('p-test-abcd', KvKeys.theme), isNull);
  });

  test('Default- und Instanz-Prüfstand sind getrennt', () async {
    kv.storeProject = '';
    await kv.setJson(KvKeys.srcNotes, {'dsgvo': 'Notiz default'});
    kv.storeProject = 'p-x';
    expect(await kv.getMap(KvKeys.srcNotes), isEmpty);
    await kv.setJson(KvKeys.srcNotes, {'dsgvo': 'Notiz p-x'});
    kv.storeProject = '';
    expect((await kv.getMap(KvKeys.srcNotes))['dsgvo'], 'Notiz default');
  });

  test('getJson: Fallback nur bei fehlendem Eintrag, gespeichertes false/null zählt', () async {
    expect(await kv.getJson('nix', 'fb'), 'fb');
    await kv.setJson(KvKeys.belegstandImported, false);
    expect(await kv.getJson(KvKeys.belegstandImported, 'fb'), false);
    await kv.setJson(KvKeys.notebook, null);
    expect(await kv.getJson(KvKeys.notebook, 'fb'), isNull);
  });

  test('RAW-Key activeProject: nackter String ohne JSON-Hülle', () async {
    await kv.setRawGlobal(KvKeys.activeProject, 'sensors-paper');
    expect(await kv.getRawGlobal(KvKeys.activeProject), 'sensors-paper');
    // Roh in der DB: kein JSON-String mit Anführungszeichen.
    expect(await db.kvDao.read('', KvKeys.activeProject), 'sensors-paper');
  });

  test('hasAnyProjectState ignoriert studioLast und leere Container', () async {
    kv.storeProject = '';
    expect(await kv.hasAnyProjectState(), isFalse);
    await kv.setJson(KvKeys.studioLast, '3.2.1');
    expect(await kv.hasAnyProjectState(), isFalse, reason: 'studioLast zählt nicht');
    await kv.setJson(KvKeys.pdfMarks, <String, Object?>{});
    await kv.setJson(KvKeys.customSources, <Object?>[]);
    expect(await kv.hasAnyProjectState(), isFalse, reason: 'leere Container zählen nicht');
    await kv.setJson(KvKeys.belegLevels, {'12': {'level': 2}});
    expect(await kv.hasAnyProjectState(), isTrue);
  });
}
