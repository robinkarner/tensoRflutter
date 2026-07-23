/// CRC-32 + Quell-Referenz-Hash `ts-xxxxxxxx`.
///
/// Bit-Kompatibilität ist hier PFLICHT (Master §7 Risiko 8): Der Hash ist die
/// Identität des Datei-Auftrags — extern besorgte Dateien heißen
/// `<hash>.pdf` und werden beim Import allein darüber zugeordnet. Bestehende
/// ZIP-Rückläufe aus der Web-App müssen weiter matchen, deshalb wird hier
/// exakt der Original-Algorithmus nachgebaut:
///
///  * CRC-32 mit Polynom 0xedb88320 (ziputil.js:9-22),
///  * Normalisierung = lowercase → NFD → Diakritika weg → nur `[a-z0-9]`
///    (util.js:261),
///  * Basis = `norm(longTitle||title) | norm(author) | jahr` (leere Teile
///    fallen weg), Fallback `norm(id)`; Ergebnis `'ts-' + hex8` (util.js:262).
///
/// Verifiziert gegen Node-generierte Testvektoren aus den echten Quellen
/// (test/data/crc32_test.dart).
library;

import 'dart:convert';

// ---------------------------------------------------------------------------
// CRC-32
// ---------------------------------------------------------------------------

/// CRC-32 (Polynom 0xedb88320, reflektiert) — identisch zu `ZipUtil.crc32`.
abstract final class Crc32 {
  static final List<int> _table = _buildTable();

  static List<int> _buildTable() {
    final t = List<int>.filled(256, 0);
    for (var n = 0; n < 256; n++) {
      var c = n;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? (0xedb88320 ^ (c >> 1)) : (c >> 1);
      }
      t[n] = c;
    }
    return t;
  }

  /// CRC über rohe Bytes (vorzeichenlos, 0..2^32-1).
  static int ofBytes(List<int> bytes) {
    var c = 0xffffffff;
    for (final b in bytes) {
      c = _table[(c ^ b) & 0xff] ^ (c >> 8);
    }
    return (c ^ 0xffffffff) & 0xffffffff;
  }

  /// CRC über den UTF-8-codierten String (Pendant zu `TextEncoder`).
  static int ofString(String s) => ofBytes(utf8.encode(s));

  /// 8-stellige Hex-Darstellung (Pendant zu `.toString(16).padStart(8,'0')`).
  static String hex8(int crc) => crc.toRadixString(16).padLeft(8, '0');
}

// ---------------------------------------------------------------------------
// Normalisierung für den srcHash
// ---------------------------------------------------------------------------

/// Basis-Buchstabe je vorkomponiertem Latin-Zeichen. Dart hat keine
/// NFD-Normalisierung in der Standardbibliothek — für den Hash reicht aber
/// die Wirkung der Original-Kette „NFD + Combining-Marks (U+0300–U+036F)
/// strippen + `[^a-z0-9]` entfernen": Jedes kanonisch zerlegbare Zeichen
/// kollabiert auf seinen ASCII-Basisbuchstaben, alles andere fällt weg.
/// Wichtig für die Bit-Treue: NICHT zerlegbare Zeichen (ß æ ø ł đ þ ð …)
/// haben in NFD keine Basis und verschwinden im Original ersatzlos — sie
/// stehen deshalb bewusst NICHT in dieser Tabelle (kein „ß→ss"!).
const Map<String, String> _latinDecomposable = {
  'a': 'àáâãäåāăąǎǟǡǻȁȃȧạảấầẩẫậắằẳẵặ',
  'b': 'ḃḅḇ',
  'c': 'çćĉċč',
  'd': 'ďḋḍḏḑḓ',
  'e': 'èéêëēĕėęěȅȇȩḕḗḙḛḝẹẻẽếềểễệ',
  'f': 'ḟ',
  'g': 'ĝğġģǧǵḡ',
  'h': 'ĥȟḣḥḧḩḫẖ',
  'i': 'ìíîïĩīĭįǐȉȋḭḯỉị',
  'j': 'ĵǰ',
  'k': 'ķǩḱḳḵ',
  'l': 'ĺļľḷḹḻḽ',
  'm': 'ḿṁṃ',
  'n': 'ñńņňǹṅṇṉṋ',
  'o': 'òóôõöōŏőơǒǫǭȍȏȫȭȯȱṍṏṑṓọỏốồổỗộớờởỡợ',
  'p': 'ṕṗ',
  'r': 'ŕŗřȑȓṙṛṝṟ',
  's': 'śŝşšșṡṣṥṧṩ',
  't': 'ţťțṫṭṯṱẗ',
  'u': 'ùúûüũūŭůűųưǔǖǘǚǜȕȗṳṵṷṹṻụủứừửữự',
  'v': 'ṽṿ',
  'w': 'ŵẁẃẅẇẉẘ',
  'x': 'ẋẍ',
  'y': 'ýÿŷȳẏẙỳỵỷỹ',
  'z': 'źżžẑẓẕ',
};

/// rune → ASCII-Basis, einmalig aus [_latinDecomposable] aufgebaut.
final Map<int, int> _baseOfRune = () {
  final map = <int, int>{};
  for (final entry in _latinDecomposable.entries) {
    final base = entry.key.codeUnitAt(0);
    for (final rune in entry.value.runes) {
      map[rune] = base;
    }
  }
  return map;
}();

/// Normalisierung des Original-`norm` (util.js:261): lowercase, Diakritika
/// auf die Basis reduzieren, alles außer `[a-z0-9]` entfernen.
String srcHashNorm(Object? value) {
  final lower = (value ?? '').toString().toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final isAsciiKeep = (rune >= 0x61 && rune <= 0x7a) || (rune >= 0x30 && rune <= 0x39);
    if (isAsciiKeep) {
      out.writeCharCode(rune);
    } else {
      final base = _baseOfRune[rune];
      if (base != null) out.writeCharCode(base);
    }
  }
  return out.toString();
}

// ---------------------------------------------------------------------------
// srcHash
// ---------------------------------------------------------------------------

/// Hash-Basis-String — exakt util.js:262: die drei normalisierten Teile
/// (Titel bevorzugt longTitle, Autor, Jahr) mit `|` verbunden, leere Teile
/// fallen weg (JS `filter(Boolean)`); sind alle leer, greift `norm(id)`.
String srcHashBasis({
  required String id,
  String? title,
  String? longTitle,
  String? author,
  int? year,
}) {
  // JS: `s.longTitle || s.title` — leerer longTitle fällt auf title zurück.
  final effTitle = (longTitle != null && longTitle.isNotEmpty) ? longTitle : title;
  final parts = <String>[
    srcHashNorm(effTitle),
    srcHashNorm(author),
    // JS: `s.year || ''` — 0/null werden zu '' und damit gefiltert.
    (year != null && year != 0) ? year.toString() : '',
  ].where((p) => p.isNotEmpty).toList();
  final basis = parts.join('|');
  return basis.isNotEmpty ? basis : srcHashNorm(id);
}

/// Referenz-Hash `ts-xxxxxxxx` einer Quelle (Pendant zu `U.srcHash`).
/// Bewusst OHNE globalen Cache — der `U._hashCache` des Originals wurde beim
/// Projektwechsel nicht geleert (Stale-Cache-Bug L2); die Berechnung ist
/// billig genug, um sie einfach immer frisch zu machen.
String srcHashOf({
  required String id,
  String? title,
  String? longTitle,
  String? author,
  int? year,
}) {
  final basis = srcHashBasis(
    id: id,
    title: title,
    longTitle: longTitle,
    author: author,
    year: year,
  );
  return 'ts-${Crc32.hex8(Crc32.ofString(basis))}';
}

/// Referenz-Hash `ts-[0-9a-f]{8}` in einem (Datei-)Namen finden —
/// Grundlage der automatischen Import-Zuordnung (views_quellen.js:793).
final RegExp srcHashPattern = RegExp(r'ts-[0-9a-f]{8}');

/// Erster Referenz-Hash im (lowercased) Dateinamen oder null.
String? srcHashInFilename(String filename) =>
    srcHashPattern.firstMatch(filename.toLowerCase())?.group(0);
