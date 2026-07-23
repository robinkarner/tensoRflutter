/// Belegstand v2 — Roundtrip + Format-Eigenheiten. Das Beispiel-Export-JSON
/// ist nach dem Original-Schema (levels.js:192-220) konstruiert: alle 22
/// Bereiche, Feld `notes` ↔ Store `srcNotes` (W7), Truthy-Overwrite-Import.
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/data/db/database.dart';
import 'package:thesor/data/db/kv.dart';
import 'package:thesor/data/export/belegstand.dart';

/// Realistisch befüllter Beispiel-Export (wie ihn die Web-App schreibt).
const _webAppExport = '''
{
 "format": "ehds-belegstand",
 "version": 2,
 "exportiert": "2026-07-20T10:00:00.000Z",
 "belegLevels": {
  "17": {
   "zitat": "The processing of personal electronic health data …",
   "seite": 14,
   "kommentar": "Wortlaut leicht gekürzt",
   "herkunft": "manuell",
   "farbe": "blau",
   "level": 3,
   "ts": 1753222000000
  },
  "23": { "farbe": "gelb", "level": 0, "ts": 1753222000001 }
 },
 "annotations": { "cobrado2024": [ { "footnote": 12, "seite": 4, "zitat": "…", "status": "bestaetigt" } ] },
 "resolutions": { "cobrado2024": { "formatVersion": "1.0", "sourceId": "cobrado2024", "stellen": [] } },
 "pdfManual": { "dsgvo": true },
 "linkOverrides": { "kraus2025": { "official": "https://example.org", "file": null } },
 "notes": { "kraus2025": "Noch prüfen: Kap. 3" },
 "srcTexts": { "gtelg2012": "§ 1. (1) Dieses Bundesgesetz…" },
 "pdfMarks": { "cobrado2024": [ { "page": 3, "rects": [[0.1, 0.2, 0.5, 0.03]], "farbe": "gelb", "fn": 12 } ] },
 "kiConnections": null,
 "customSources": [ { "id": "mueller2023", "title": "Testquelle", "year": 2023 } ],
 "textMentions": { "3.2.1-p4|127": { "status": "bestaetigt", "srcId": "abowd1999" } },
 "fileSearch": { "kraus2025": { "venue": "JMIR", "openAccess": true } },
 "dlStatus": { "cobrado2024": { "ok": false, "note": "CORS blockiert — von Hand laden" } },
 "paraDock": {},
 "paraEdits": { "1.1-p2": "Überarbeiteter Absatztext." },
 "dockBySection": {},
 "marksExtra": {},
 "notebook": null,
 "texEdits": { "3.2.1": "\\\\subsection{…}" },
 "fnEdits": { "12": "Vgl. Cobrado u.a. (2024), S. 4." },
 "belegSpans": { "17": 1 },
 "titleEdits": { "ch1": "Einleitung (neu)" }
}
''';

void main() {
  late AppDatabase db;
  late KvStore kv;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    kv = KvStore(db.kvDao);
  });

  tearDown(() => db.close());

  test('Import eines Web-App-Exports: alle Bereiche landen in den Stores', () async {
    final count = await Belegstand.importState(kv, _webAppExport);
    expect(count, 2, reason: 'Rückgabe = Anzahl belegLevels-Einträge');

    // Die Umbenennung (W7): Export-Feld notes → Store srcNotes.
    expect((await kv.getMap(KvKeys.srcNotes))['kraus2025'], 'Noch prüfen: Kap. 3');
    // Stichproben der übrigen Bereiche.
    final levels = await kv.getMap(KvKeys.belegLevels);
    expect((levels['17'] as Map)['seite'], 14);
    expect((await kv.getMap(KvKeys.pdfManual))['dsgvo'], true);
    expect(await kv.getList(KvKeys.customSources), hasLength(1));
    expect((await kv.getMap(KvKeys.fnEdits))['12'], 'Vgl. Cobrado u.a. (2024), S. 4.');
    // kiConnections war null → Bereich bleibt unangetastet (nicht angelegt).
    expect(await kv.getJson(KvKeys.kiConnections), isNull);
  });

  test('Export: Format-Kopf, Feld-Reihenfolge, notes-Mapping, Indent 1', () async {
    await Belegstand.importState(kv, _webAppExport);
    final out = await Belegstand.exportState(kv,
        now: DateTime.utc(2026, 7, 23, 12));
    final decoded = json.decode(out) as Map<String, dynamic>;

    expect(decoded['format'], 'ehds-belegstand');
    expect(decoded['version'], 2);
    expect(decoded['exportiert'], '2026-07-23T12:00:00.000Z');
    // Exakt die Original-Reihenfolge (levels.js:193-219).
    expect(decoded.keys.toList(), [
      'format', 'version', 'exportiert',
      'belegLevels', 'annotations', 'resolutions', 'pdfManual',
      'linkOverrides', 'notes', 'srcTexts', 'pdfMarks', 'kiConnections',
      'customSources', 'textMentions', 'fileSearch', 'dlStatus', 'paraDock',
      'paraEdits', 'dockBySection', 'marksExtra', 'notebook', 'texEdits',
      'fnEdits', 'belegSpans', 'titleEdits',
    ]);
    // Store srcNotes → Export-Feld notes.
    expect((decoded['notes'] as Map)['kraus2025'], 'Noch prüfen: Kap. 3');
    // Einrückung 1 wie JSON.stringify(…, null, 1).
    expect(out, startsWith('{\n "format": "ehds-belegstand",'));
  });

  test('Roundtrip: Import → Export → Import ist verlustfrei', () async {
    await Belegstand.importState(kv, _webAppExport);
    final exported = await Belegstand.exportState(kv);

    final db2 = AppDatabase(NativeDatabase.memory());
    final kv2 = KvStore(db2.kvDao);
    await Belegstand.importState(kv2, exported);
    for (final key in [
      KvKeys.belegLevels, KvKeys.annotations, KvKeys.resolutions,
      KvKeys.pdfManual, KvKeys.linkOverrides, KvKeys.srcNotes,
      KvKeys.srcTexts, KvKeys.pdfMarks, KvKeys.customSources,
      KvKeys.textMentions, KvKeys.fileSearch, KvKeys.dlStatus,
      KvKeys.paraEdits, KvKeys.texEdits, KvKeys.fnEdits, KvKeys.belegSpans,
      KvKeys.titleEdits,
    ]) {
      expect(await kv2.getJson(key), await kv.getJson(key), reason: key);
    }
    await db2.close();
  });

  test('Truthy-Overwrite: {} überschreibt, null/fehlend lässt Bestand stehen', () async {
    await kv.setJson(KvKeys.srcNotes, {'a': 'bleibt?'});
    await kv.setJson(KvKeys.notebook, '# Mein Buch');
    // Import: notes = {} (truthy → überschreibt), notebook fehlt (→ bleibt).
    await Belegstand.importState(
        kv, '{"format":"ehds-belegstand","version":2,"notes":{}}');
    expect(await kv.getMap(KvKeys.srcNotes), isEmpty, reason: '{} ist truthy');
    expect(await kv.getJson(KvKeys.notebook), '# Mein Buch',
        reason: 'fehlender Bereich lässt Bestand stehen');
  });

  test('fremdes Format wird abgelehnt (Original-Fehlertext)', () {
    expect(
      () => Belegstand.importState(kv, '{"format":"was-anderes"}'),
      throwsA(isA<FormatException>().having((e) => e.message, 'message',
          'Unbekanntes Format — erwartet "ehds-belegstand".')),
    );
  });

  test('importState prüft nur format, nicht version (wie das Original)', () async {
    final n = await Belegstand.importState(
        kv, '{"format":"ehds-belegstand","version":99,"belegLevels":{"5":{"level":1}}}');
    expect(n, 1);
  });
}
