/// Quellen-Matcher für „norm“-Marks — Port von `U._srcPatterns` /
/// `U.matchSourceInText` (util.js:69-105).
///
/// Entscheidet, ob ein Markausschnitt der Kategorie „Quelle/Rechtsnorm“
/// WIRKLICH zu einer Quelle des Registers gehört: nur dann wird er als
/// klickbarer Quellen-Mark (`mk-src`) gerendert, sonst verworfen.
///
/// Muster je Quelle (alle normalisiert: lowercase + NFD ohne Diakritika):
///  * der Kurzname (`srcShort`, ≥ 3 Zeichen, nicht rein numerisch),
///  * Nummern-Muster aus Titel/longTitle („2016/679“ u. ä.),
///  * Klammer-Kürzel im Titel („(DSGVO)“, „(GTelG 2012)“),
///  * Autor-Nachname (≥ 4 Buchstaben).
/// Der LÄNGSTE passende Treffer über alle Quellen gewinnt.
library;

import '../../data/models/source.dart';

/// NFD-Diakritika-Strip + lowercase — exakt `norm` aus util.js:75.
/// (Ohne ICU-Abhängigkeit: die kombinierenden Zeichen U+0300–U+036F der
/// zerlegten Form werden entfernt; die deutschen Umlaute sind im Bundle
/// vorkombiniert und bleiben — identisch zum JS-Verhalten, das `ä` ebenfalls
/// unverändert lässt, solange der String NFC-kodiert ankommt.)
String _normalize(String? v) {
  final s = (v ?? '').toLowerCase();
  final b = StringBuffer();
  for (final r in s.runes) {
    // Häufigste vorkombinierte Zeichen zerlegen wie NFD (a..z + Diakritikum).
    final decomposed = _nfdMap[r];
    if (decomposed != null) {
      b.writeCharCode(decomposed);
      continue;
    }
    if (r >= 0x300 && r <= 0x36F) continue; // kombinierende Diakritika
    b.writeCharCode(r);
  }
  return b.toString();
}

/// Basis-Buchstabe der gängigen lateinischen Sonderzeichen (Kleinbuchstaben —
/// der Input ist bereits lowercase). Deckt die im Quellenbestand vorkommenden
/// Fälle (á é í ó ú à è ì ò ù â ê î ô û ã ñ õ ç ý) ab; Umlaute ä/ö/ü bleiben
/// wie im JS (NFD zerlegt sie zwar, aber `matchAll`/`includes` arbeiten dort
/// auf demselben zerlegten Text — entscheidend ist nur die Konsistenz
/// zwischen Muster und Snippet, die hier gegeben ist).
const Map<int, int> _nfdMap = {
  0xE1: 0x61, 0xE0: 0x61, 0xE2: 0x61, 0xE3: 0x61, 0xE5: 0x61, // á à â ã å
  0xE9: 0x65, 0xE8: 0x65, 0xEA: 0x65, 0xEB: 0x65, // é è ê ë
  0xED: 0x69, 0xEC: 0x69, 0xEE: 0x69, 0xEF: 0x69, // í ì î ï
  0xF3: 0x6F, 0xF2: 0x6F, 0xF4: 0x6F, 0xF5: 0x6F, // ó ò ô õ
  0xFA: 0x75, 0xF9: 0x75, 0xFB: 0x75, // ú ù û
  0xE7: 0x63, 0xF1: 0x6E, 0xFD: 0x79, // ç ñ ý
};

class _SourcePatterns {
  final String id;
  final List<String> pats;
  const _SourcePatterns(this.id, this.pats);
}

/// Vorberechnete Muster über eine Quellenliste — Pendant zu `U._srcPatCache`
/// (ein neuer Matcher = frischer Cache; der Projektwechsel baut ihn neu).
class SourceTextMatcher {
  final List<_SourcePatterns> _list;

  SourceTextMatcher(Iterable<Source> sources, String Function(String id) srcShort)
      : _list = _build(sources, srcShort);

  static final _numRe = RegExp(r'\b(\d{4}\/\d{2,4})\b');
  static final _bracketRe = RegExp(
      r'\(([A-Za-zÄÖÜ][A-Za-zÄÖÜäöü0-9-]{2,18}(?:\s\d{4})?)\)');
  static final _pureDigits = RegExp(r'^\d+$');
  static final _nonNameChars = RegExp(r'[^a-z-]');

  static List<_SourcePatterns> _build(
      Iterable<Source> sources, String Function(String id) srcShort) {
    final list = <_SourcePatterns>[];
    for (final s in sources) {
      final pats = <String>{};
      final short = _normalize(srcShort(s.id));
      if (short.length >= 3 && !_pureDigits.hasMatch(short)) pats.add(short);
      for (final t in [s.title, s.longTitle]) {
        final str = t ?? '';
        // Rechtsakte: Nummern-Muster „2016/679“ u. ä.
        for (final m in _numRe.allMatches(str)) {
          pats.add(m.group(1)!);
        }
        // Klammer-Kürzel im Titel: „(DSGVO)“, „(GTelG 2012)“ …
        for (final m in _bracketRe.allMatches(str)) {
          pats.add(_normalize(m.group(1)));
        }
      }
      // Autor-Nachname (Papers)
      final last = _normalize((s.author ?? '').split(RegExp(r'[,;]')).first.split(' ').first)
          .replaceAll(_nonNameChars, '');
      if (last.length >= 4) pats.add(last);
      if (pats.isNotEmpty) list.add(_SourcePatterns(s.id, pats.toList()));
    }
    return list;
  }

  /// Findet zu einem Textausschnitt die Quellen-id (längstes passendes
  /// Muster gewinnt) oder null — Port von `U.matchSourceInText`.
  String? match(String snippet) {
    final sn = _normalize(snippet);
    if (sn.length < 3) return null;
    String? bestId;
    var bestLen = -1;
    for (final s in _list) {
      for (final p in s.pats) {
        if (sn.contains(p) && p.length > bestLen) {
          bestId = s.id;
          bestLen = p.length;
        }
      }
    }
    return bestId;
  }
}
