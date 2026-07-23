/// Datei-Auftrag-ZIP v1: auftrag.json-Inhalt, ANLEITUNG.txt zeichengenau,
/// STORE-only-ZIP (lesbar auch für die Web-App, deren ZipUtil DEFLATE nur
/// mit Browser-Unterstützung entpackt — STORE geht immer).
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/data/export/dateiauftrag.dart';
import 'package:thesor/data/models/models.dart';

Source _source(String id, {String? title, String? author, int? year, String? doi}) =>
    Source.fromJson({
      'id': id,
      'kind': 'artikel',
      'title': ?title,
      'author': ?author,
      'year': ?year,
      'doi': ?doi,
    });

void main() {
  test('Eintrag: Feldbelegung + Hash + Dateiname wie das Original', () {
    final e = Dateiauftrag.eintragFor(
      _source('cobrado2024',
          title: 'Access control solutions in electronic health record systems: A systematic review',
          author: 'Cobrado, Usha Nicole u.a.',
          year: 2024,
          doi: '10.1/x'),
      linkOffiziell: 'https://doi.org/10.1/x',
      venue: 'JMIR',
    );
    // Hash aus dem Node-Fixture (crc32_test.dart).
    expect(e.hash, 'ts-f12e5002');
    expect(e.dateiname, 'ts-f12e5002.pdf');
    final j = e.toJson();
    expect(j.keys.toList(), [
      'hash', 'dateiname', 'titel', 'autor', 'jahr', 'doi', 'venue',
      'linkOffiziell', 'linkDatei', 'openAccessBevorzugt',
    ]);
    expect(j['venue'], 'JMIR');
    expect(j['linkDatei'], isNull);
    expect(j['openAccessBevorzugt'], true);
  });

  test('ZIP: zwei Einträge, STORE-only, Inhalte exakt', () {
    final eintraege = [
      Dateiauftrag.eintragFor(_source('a1', title: 'Titel Eins', author: 'Autor', year: 2020)),
    ];
    final zip = Dateiauftrag.buildZip(eintraege);

    final archive = ZipDecoder().decodeBytes(zip);
    final names = [for (final f in archive) f.name];
    expect(names, ['auftrag.json', 'ANLEITUNG.txt']);

    // STORE erzwungen: unkomprimierte Größe == gespeicherte Größe.
    for (final f in archive) {
      expect(f.compression, CompressionType.none, reason: '${f.name} muss STORE sein');
    }

    final auftrag = json.decode(utf8.decode(archive.first.readBytes()!)) as Map<String, dynamic>;
    expect(auftrag['format'], 'thesis-studio-dateiauftrag');
    expect(auftrag['version'], 1);
    expect((auftrag['eintraege'] as List), hasLength(1));

    final anleitung = utf8.decode(archive.last.readBytes()!);
    expect(anleitung.split('\n'), hasLength(9), reason: '9 Zeilen wie das Original');
    expect(anleitung, startsWith('THESIS STUDIO — DATEI-AUFTRAG'));
    expect(anleitung, contains('ueber den Hash automatisch und eindeutig zu.'));
  });

  test('auftrag.json mit Einrückung 1 (JSON.stringify-Pendant)', () {
    final text = Dateiauftrag.auftragJson(const []);
    expect(text, startsWith('{\n "format": "thesis-studio-dateiauftrag",'));
  });

  test('readZip: Roundtrip + Fehlertext bei Nicht-ZIP', () {
    final zip = createStoreZip([
      ZipWriteEntry('ts-deadbeef.pdf', utf8.encode('%PDF-1.4 …')),
    ]);
    final entries = readZip(zip);
    expect(entries, hasLength(1));
    expect(entries.first.name, 'ts-deadbeef.pdf');
    expect(entries.first.error, isNull);
    expect(utf8.decode(entries.first.data!), startsWith('%PDF-'));

    expect(
      () => readZip(utf8.encode('kein zip')),
      throwsA(isA<FormatException>().having((e) => e.message, 'message',
          'Kein ZIP-Archiv (End-Signatur fehlt).')),
    );
  });
}
