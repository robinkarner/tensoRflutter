/// Datei-Auftrag-ZIP `thesis-studio-dateiauftrag` v1 (views_quellen.js:867-903)
/// + ZIP-Lesen für den Import-Weg (ZipUtil-Pendant).
///
/// Der Auftrag ist der „Download-Transformator": auftrag.json listet alle
/// Quellen ohne Datei, je mit stabilem Referenz-Hash (`ts-…`); extern besorgte
/// Dateien kommen als `<hash>.pdf` im ZIP zurück und werden beim Import allein
/// über den Hash zugeordnet. Kompatibilitätspflichten:
///  * Hash bit-identisch (lib/core/util/crc32.dart),
///  * auftrag.json mit `JSON.stringify(…, null, 1)`-Einrückung,
///  * ANLEITUNG.txt zeichengenau (bewusst ohne Umlaute),
///  * ZIP-Einträge unkomprimiert (STORE) wie ZipUtil.create — PDFs sind
///    ohnehin komprimiert.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../core/util/crc32.dart';
import '../models/models.dart';

// ---------------------------------------------------------------------------
// Auftrag bauen
// ---------------------------------------------------------------------------

/// Ein Eintrag der auftrag.json (Feld-Reihenfolge wie das Original).
class DateiauftragEintrag {
  final String hash;
  final String? titel;
  final String? autor;
  final int? jahr;
  final String? doi;
  final String? venue;
  final String? linkOffiziell;
  final String? linkDatei;

  const DateiauftragEintrag({
    required this.hash,
    this.titel,
    this.autor,
    this.jahr,
    this.doi,
    this.venue,
    this.linkOffiziell,
    this.linkDatei,
  });

  String get dateiname => '$hash.pdf';

  Map<String, Object?> toJson() => {
        'hash': hash,
        'dateiname': dateiname,
        'titel': titel,
        'autor': autor,
        'jahr': jahr,
        'doi': doi,
        'venue': venue,
        'linkOffiziell': linkOffiziell,
        'linkDatei': linkDatei,
        'openAccessBevorzugt': true,
      };
}

abstract final class Dateiauftrag {
  static const format = 'thesis-studio-dateiauftrag';
  static const version = 1;
  static const zipName = 'datei-auftrag.zip';

  /// ANLEITUNG.txt — 9 Zeilen, zeichengenau (views_quellen.js:883-893).
  static const anleitung = 'THESIS STUDIO — DATEI-AUFTRAG\n'
      '\n'
      'auftrag.json enthaelt alle Quellen ohne Datei, je mit stabilem Referenz-Hash.\n'
      'Aufgabe (Mensch, KI oder automatisierte Download-Engine):\n'
      '  1. Datei je Eintrag besorgen — freie/Open-Access-Quellen bevorzugen.\n'
      '  2. Datei exakt als <hash>.pdf benennen (Feld "dateiname").\n'
      '  3. Alle Dateien als ZIP zurueckgeben.\n'
      'Der Import in Thesis Studio (Quellen -> Import PDF/ZIP) ordnet die Dateien\n'
      'ueber den Hash automatisch und eindeutig zu.';

  /// Eintrag aus einer Quelle — Feldbelegung wie views_quellen.js:871-881:
  /// titel = longTitle||title, venue = fileSearch.venue||container,
  /// Links kommen aufgelöst herein (Overrides > Vorschlag, `U.srcLinks`).
  static DateiauftragEintrag eintragFor(
    Source s, {
    String? linkOffiziell,
    String? linkDatei,
    String? venue,
  }) =>
      DateiauftragEintrag(
        hash: srcHashOf(
          id: s.id,
          title: s.title,
          longTitle: s.longTitle,
          author: s.author,
          year: s.year,
        ),
        titel: (s.longTitle != null && s.longTitle!.isNotEmpty)
            ? s.longTitle
            : (s.title.isNotEmpty ? s.title : null),
        autor: _orNull(s.author),
        jahr: (s.year != null && s.year != 0) ? s.year : null,
        doi: _orNull(s.doi),
        venue: _orNull(venue) ?? _orNull(s.container),
        linkOffiziell: _orNull(linkOffiziell),
        linkDatei: _orNull(linkDatei),
      );

  /// Inhalt der auftrag.json (mit Einrückung 1, wie das Original).
  static String auftragJson(List<DateiauftragEintrag> eintraege) =>
      const JsonEncoder.withIndent(' ').convert({
        'format': format,
        'version': version,
        'eintraege': [for (final e in eintraege) e.toJson()],
      });

  /// Das komplette ZIP (auftrag.json + ANLEITUNG.txt), STORE-only.
  static Uint8List buildZip(List<DateiauftragEintrag> eintraege) =>
      createStoreZip([
        ZipWriteEntry('auftrag.json', Uint8List.fromList(utf8.encode(auftragJson(eintraege)))),
        ZipWriteEntry('ANLEITUNG.txt', Uint8List.fromList(utf8.encode(anleitung))),
      ]);

  static String? _orNull(String? v) => (v == null || v.isEmpty) ? null : v;
}

// ---------------------------------------------------------------------------
// ZIP schreiben/lesen (ZipUtil-Pendant über package:archive)
// ---------------------------------------------------------------------------

/// Zu schreibender ZIP-Eintrag.
class ZipWriteEntry {
  final String name;
  final Uint8List data;

  const ZipWriteEntry(this.name, this.data);
}

/// ZIP erzeugen — STORE erzwungen (Pendant zu ZipUtil.create: unkomprimiert,
/// UTF-8-Dateinamen; die festen 1980er-Zeitstempel des Originals sind mit
/// archive nicht exakt reproduzierbar und für die Zuordnung irrelevant).
Uint8List createStoreZip(List<ZipWriteEntry> entries) {
  final archive = Archive();
  for (final e in entries) {
    archive.addFile(
      ArchiveFile.bytes(e.name, e.data)..compression = CompressionType.none,
    );
  }
  return ZipEncoder().encodeBytes(archive);
}

/// Gelesener ZIP-Eintrag: entweder [data] oder [error] (deutsche Meldung) —
/// Aufrufer prüfen `error`, genau wie beim Original (ziputil.js:61-113).
class ZipReadEntry {
  final String name;
  final Uint8List? data;
  final String? error;

  const ZipReadEntry(this.name, {this.data, this.error});
}

/// ZIP lesen — nur reguläre Dateien, Ordner werden übersprungen.
/// Gesamtfehler (kein ZIP) wirft [FormatException] mit dem Original-Text;
/// Einzelfehler landen als [ZipReadEntry.error] in der Liste. STORE und
/// DEFLATE deckt package:archive nativ ab — die Browser-Kompatibilitäts-
/// Warnung des Originals entfällt damit.
List<ZipReadEntry> readZip(Uint8List bytes) {
  // End-of-Central-Directory-Suche wie ziputil.js:65-69 (letzte 64 KB) —
  // package:archive liefert bei Nicht-ZIPs stillschweigend ein leeres
  // Archiv, das Original wirft; wir bilden das Werfen exakt nach.
  if (!_hasEndOfCentralDirectory(bytes)) {
    throw const FormatException('Kein ZIP-Archiv (End-Signatur fehlt).');
  }
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('Kein ZIP-Archiv (End-Signatur fehlt).');
  }
  final out = <ZipReadEntry>[];
  for (final f in archive) {
    if (!f.isFile || f.name.endsWith('/')) continue;
    try {
      final content = f.readBytes();
      if (content == null) {
        out.add(ZipReadEntry(f.name, error: 'nicht entpackbar: leerer Inhalt'));
      } else {
        out.add(ZipReadEntry(f.name, data: content));
      }
    } catch (e) {
      out.add(ZipReadEntry(f.name, error: 'nicht entpackbar: $e'));
    }
  }
  return out;
}

/// EOCD-Signatur `0x06054b50` (little-endian `PK\x05\x06`) in den letzten
/// 65 558 Bytes suchen — exakt der Suchbereich des Originals.
bool _hasEndOfCentralDirectory(Uint8List b) {
  final lowest = b.length - 65558 > 0 ? b.length - 65558 : 0;
  for (var i = b.length - 22; i >= lowest; i--) {
    if (b[i] == 0x50 && b[i + 1] == 0x4b && b[i + 2] == 0x05 && b[i + 3] == 0x06) {
      return true;
    }
  }
  return false;
}
