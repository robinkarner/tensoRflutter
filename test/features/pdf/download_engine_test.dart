/// ⭳ Download-Engine: linkKind-Heuristik, dlLinkFor-Kaskade und tryDownload
/// (EIN Versuch, %PDF-Magic-Check, sofortige Zuordnung, dlStatus persistent,
/// Fehlertexte wörtlich — pdfengine.js:287-319, util.js:517-523).
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:thesor/data/db/database.dart';
import 'package:thesor/data/db/kv.dart';
import 'package:thesor/data/repos/file_store.dart';
import 'package:thesor/data/repos/project_repository.dart';
import 'package:thesor/features/pdf/assign_panel/download_engine.dart';
import 'package:thesor/features/pdf/assign_panel/src_kv.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('linkKind', () {
    test('Datei-Links: .pdf, /pdf/, arxiv, download/fulltext/…', () {
      expect(linkKind('https://x.org/paper.pdf'), 'file');
      expect(linkKind('https://x.org/paper.pdf?v=2'), 'file');
      expect(linkKind('https://x.org/content/pdf/123'), 'file');
      expect(linkKind('https://arxiv.org/pdf/2401.1'), 'file');
      expect(linkKind('https://x.org/fulltext/9'), 'file');
      expect(linkKind('https://doi.org/10.1/xyz'), 'page');
      expect(linkKind(null), isNull);
      expect(linkKind(''), isNull);
    });
  });

  group('dlLinkFor', () {
    test('file gewinnt; official nur wenn selbst Datei-Link', () {
      expect(
        dlLinkFor(const EffectiveSrcLinks(
            official: 'https://doi.org/10.1/x', file: 'https://x/y.pdf')),
        'https://x/y.pdf',
      );
      expect(
        dlLinkFor(const EffectiveSrcLinks(official: 'https://x/z.pdf')),
        'https://x/z.pdf',
      );
      expect(
        dlLinkFor(const EffectiveSrcLinks(official: 'https://doi.org/10.1/x')),
        isNull,
      );
    });
  });

  group('tryDownload', () {
    late AppDatabase db;
    late KvStore kv;
    late FileStore files;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      kv = KvStore(db.kvDao);
      files = FileStore(db.fileBlobsDao);
      await files.init();
    });

    tearDown(() async {
      files.dispose();
      await db.close();
    });

    DownloadEngine engine(MockClient client) =>
        DownloadEngine(files: files, kv: kv, client: client);

    final pdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2d, 0x31]);

    test('Erfolg: %PDF → sofort zugeordnet + Status persistiert', () async {
      final e = engine(MockClient((_) async => http.Response.bytes(pdfBytes, 200)));
      final r = await e.tryDownload('kraus2025', 'https://x/y.pdf');
      expect(r.ok, isTrue);
      expect(r.note, 'geladen & zugeordnet');
      expect(files.has('kraus2025'), isTrue);
      expect(files.pdfStatusCache['kraus2025'], isTrue);
      final stored = await kv.getDlStatus('kraus2025');
      expect(stored!.ok, isTrue);
    });

    test('kein Link: wörtlicher Fehlertext, Status persistiert', () async {
      final e = engine(MockClient((_) async => http.Response('', 200)));
      final r = await e.tryDownload('kraus2025', null);
      expect(r.ok, isFalse);
      expect(r.note,
          'kein öffentlicher Datei-Link bekannt — Link ↗ von Hand laden oder über 🤖 Ergänzung nachtragen');
      expect((await kv.getDlStatus('kraus2025'))!.ok, isFalse);
    });

    test('HTTP-Fehler mit Statuscode im Text', () async {
      final e = engine(MockClient((_) async => http.Response('nope', 403)));
      final r = await e.tryDownload('kraus2025', 'https://x/y.pdf');
      expect(r.note, 'HTTP 403 — Link ↗ von Hand laden, dann ⭱ Datei lokal wählen');
    });

    test('Antwort ohne %PDF-Magic wird abgelehnt', () async {
      final e =
          engine(MockClient((_) async => http.Response('<html>Seite</html>', 200)));
      final r = await e.tryDownload('kraus2025', 'https://x/y.pdf');
      expect(r.note, 'Antwort ist kein PDF (vermutlich HTML-Seite) — Link ↗ prüfen');
      expect(files.has('kraus2025'), isFalse);
    });

    test('Zeitüberschreitung (20 s) — wörtlich', () async {
      final e = engine(MockClient((_) => throw TimeoutException(null)));
      final r = await e.tryDownload('kraus2025', 'https://x/y.pdf');
      expect(r.note, 'Zeitüberschreitung (20 s)');
    });

    test('Netzwerkfehler → „blockiert (Netzwerk) …" (dokumentierte '
        'Abweichung: CORS entfällt außerhalb des Browsers)', () async {
      final e = engine(MockClient((_) => throw http.ClientException('kaputt')));
      final r = await e.tryDownload('kraus2025', 'https://x/y.pdf');
      expect(r.note,
          'blockiert (Netzwerk) — Link ↗ von Hand laden, dann ⭱ Datei lokal wählen');
    });
  });
}
