/// id-Vorschläge und Slug-Sanitizing der Quellen-Anlage — reine Funktionen
/// aus `newSourceModal` (views_quellen.js:166-179) und `sourceFromFile`
/// (js:294-295).
library;

import '../../../core/util/crc32.dart';

/// Live-id-Vorschlag im „＋ Neue Quelle"-Modal (js:166-171): erster Token
/// des Autors (Split an Space/Komma), sonst erstes Titelwort, sonst
/// „quelle" — lowercased, nur `[a-z0-9]`, plus Jahr, max 30 Zeichen.
String suggestNewSourceId({String author = '', String title = '', String year = ''}) {
  String firstToken(String s, Pattern sep) {
    final parts = s.split(sep);
    return parts.isEmpty ? '' : parts.first;
  }

  var base = firstToken(author, RegExp(r'[ ,]'));
  if (base.isEmpty) base = firstToken(title, ' ');
  if (base.isEmpty) base = 'quelle';
  base = base.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final id = base + year;
  return id.length > 30 ? id.substring(0, 30) : id;
}

/// Eingegebene id säubern (js:179/309): lowercase, nur `[a-z0-9-]`.
String sanitizeSourceId(String raw) =>
    raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '');

/// Titel-Vorschlag aus einem Dateinamen (js:294): `.pdf` weg, `[_-]+` zu
/// Leerzeichen, Mehrfach-Spaces kollabiert.
String guessTitleFromFilename(String name) => name
    .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
    .replaceAll(RegExp(r'[_-]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// id-Vorschlag aus einem Titel (js:295): lowercase → NFD ohne Diakritika →
/// `[^a-z0-9]+` zu `-` → Rand-Bindestriche weg → max 30 → Fallback „quelle".
///
/// Dart hat keine NFD-Normalisierung in der Stdlib — [srcHashNorm] liefert
/// exakt die Wirkung der Original-Kette je Zeichen (Basis-Buchstabe bzw.
/// nichts); Nicht-Zerlegbares wird hier zum `-`-Trenner wie jedes andere
/// Nicht-Alphanumerikum.
String guessIdFromTitle(String title) {
  final out = StringBuffer();
  for (final rune in title.toLowerCase().runes) {
    // Nackte Combining-Marks (bereits zerlegte Eingabe) verschwinden im
    // Original ersatzlos — hier ebenfalls kein `-`-Trenner dafür.
    if (rune >= 0x300 && rune <= 0x36f) continue;
    final ch = String.fromCharCode(rune);
    final mapped = srcHashNorm(ch);
    out.write(mapped.isNotEmpty ? mapped : '-');
  }
  var slug = out
      .toString()
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.length > 30) slug = slug.substring(0, 30);
  return slug.isEmpty ? 'quelle' : slug;
}
