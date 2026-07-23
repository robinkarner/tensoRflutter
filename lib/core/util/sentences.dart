/// Satz-Zerlegung + Belegspannen — Port von `U.splitSentences`,
/// `U.sentenceIndexAt` und `U.belegSpan` (util.js:298-405).
///
/// Die Zerlegung ist deterministisch und abkürzungsfest; sie arbeitet auf dem
/// ROHEN Absatztext (mit `[^N]`-Markern). Fußnoten-Marker direkt nach dem
/// Satzende gehören noch zum Satz — das ist die Grundlage für Belegspannen
/// („Zitat erstreckt sich über mehrere Sätze“). Offsets sind UTF-16-Code-
/// Units und damit 1:1 kompatibel zu den JS-Indizes (Erwähnungs-Starts,
/// Mark-Snippets, Highlight-Spannen).
library;

/// Ein Satz mit seinen Roh-Offsets — Pendant zu `{start, end, text}`.
class SentenceSpan {
  final int start;
  final int end;
  final String text;

  const SentenceSpan({required this.start, required this.end, required this.text});

  Map<String, Object?> toJson() => {'start': start, 'end': end, 'text': text};

  @override
  String toString() => 'SentenceSpan($start..$end, "$text")';
}

// Satzende: .!? plus optionale schließende Anführungszeichen/Klammern.
final RegExp _terminator = RegExp('[.!?]+[”“"’\')\\]]*');

// Letztes Wort unmittelbar vor dem Punkt (max. 14 Zeichen Rückschau).
final RegExp _lastWord = RegExp(r'[A-Za-zÄÖÜäöüß]+$');

// Einzelbuchstabe = Initial („G.“) — außer A/I (englische Wörter).
final RegExp _singleLetter = RegExp(r'^[A-Za-zÄÖÜ]$');
final RegExp _aOrI = RegExp(r'^(A|I)$');

// Abkürzungen, nach denen KEIN Satzende liegt (EN + DE).
final RegExp _abbrev = RegExp(
  r'^(et al|al|e\.?g|i\.?e|cf|vs|ca|approx|etc|Fig|Tab|Eq|No|Nr|Dr|Prof|Mr|Mrs|Ms|St|Art|Abs|Abschn|Kap|bzw|inkl|ggf|zit|Aufl|Hrsg|Ed|eds|vgl|Vgl|sog|resp)$',
  caseSensitive: false,
);

// Fußnoten-Marker unmittelbar nach dem Satzende („… theories.[^2]“).
final RegExp _markerTail = RegExp(r'^(\s*\[\^\d+\])+');

// Beginnt der Folgetext mit Leerraum? (sonst „3.1“, „e.g.“ zusammenhalten)
final RegExp _leadingSpace = RegExp(r'^\s');
final RegExp _nextChar = RegExp(r'^\s+(.)');

// Womit ein neuer Satz beginnen darf: Großbuchstabe/Zahl/Anführung/Klammer.
final RegExp _sentenceStart = RegExp(r'[A-ZÄÖÜ0-9„“"(\[]');
final RegExp _leadingWs = RegExp(r'^\s*');

/// Deterministische, abkürzungsfeste Satz-Zerlegung — exakter Port von
/// `U.splitSentences` (util.js:302-330).
List<SentenceSpan> splitSentences(String? text) {
  final raw = text ?? '';
  final sents = <SentenceSpan>[];
  var start = 0;
  var scanFrom = 0;

  while (scanFrom <= raw.length) {
    final m = _firstMatchFrom(_terminator, raw, scanFrom);
    if (m == null) break;
    // Standard-Fortschritt wie `re.exec` (lastIndex nach dem Treffer) —
    // bei Ablehnung (continue im Original) sucht die Schleife hier weiter.
    scanFrom = m.end;

    // Wort unmittelbar vor dem Punkt: Abkürzung/Initial → kein Satzende
    final before = raw.substring(m.start < 14 ? 0 : m.start - 14, m.start);
    final w = _lastWord.firstMatch(before)?.group(0) ?? '';
    if (_singleLetter.hasMatch(w) && !_aOrI.hasMatch(w)) continue; // Initial „G.“
    if (_abbrev.hasMatch(w)) continue;

    var end = m.start + m.group(0)!.length;
    // Marker nach dem Satzende gehören noch dazu: „… theories .[^2]“
    final tail = _markerTail.firstMatch(raw.substring(end));
    if (tail != null) end += tail.group(0)!.length;

    // Satzgrenze nur vor Leerraum/Schluss („3.1“, „e.g.“ bleiben ganz) und
    // wenn danach Neues beginnt (Großbuchstabe/Zahl/Klammer)
    final rest = raw.substring(end);
    if (rest.isNotEmpty && !_leadingSpace.hasMatch(rest)) continue;
    final nx = _nextChar.firstMatch(rest);
    if (rest.trim().isNotEmpty && nx != null && !_sentenceStart.hasMatch(nx.group(1)!)) {
      continue;
    }

    if (raw.substring(start, end).trim().isNotEmpty) {
      sents.add(SentenceSpan(start: start, end: end, text: raw.substring(start, end)));
    }
    start = end + (_leadingWs.firstMatch(rest)?.group(0) ?? '').length;
    scanFrom = start;
  }

  if (start < raw.length && raw.substring(start).trim().isNotEmpty) {
    sents.add(SentenceSpan(start: start, end: raw.length, text: raw.substring(start)));
  }
  return sents;
}

Match? _firstMatchFrom(RegExp re, String s, int from) {
  if (from > s.length) return null;
  for (final m in re.allMatches(s, from)) {
    return m;
  }
  return null;
}

/// Satzindex zu einer Zeichenposition — Port von `U.sentenceIndexAt`
/// (util.js:331-334). Positionen hinter dem letzten Satz fallen auf den
/// letzten Satz zurück; leere Listen liefern -1.
int sentenceIndexAt(List<SentenceSpan> sents, int pos) {
  for (var i = 0; i < sents.length; i++) {
    if (pos >= sents[i].start && pos < sents[i].end) return i;
  }
  return sents.isNotEmpty ? sents.length - 1 : -1;
}

/// Erwähnungs-Eingabe für die Belegspannen-Heuristik: eine mit dem Beleg
/// zusammengeführte Erwähnung (`status == 'beleg'`, gleiche Fußnote) weiter
/// vorn im Absatz zieht die Spanne bis zu ihrem Satz auf.
class BelegSpanMention {
  final String status;
  final int? fn;
  final int start;

  const BelegSpanMention({required this.status, this.fn, required this.start});
}

/// Ergebnis von [belegSpan] — Pendant zu `{from, to, sents, text}`.
class BelegSpanResult {
  /// Erster Satz der Spanne (Index in [sents]).
  final int from;

  /// Satz mit dem Fußnoten-Marker (Index in [sents]).
  final int to;
  final List<SentenceSpan> sents;

  /// Umfasster Rohtext (von Satzanfang [from] bis Satzende [to]).
  final String text;

  const BelegSpanResult({
    required this.from,
    required this.to,
    required this.sents,
    required this.text,
  });
}

/// Belegspanne einer Fußnote im Absatztext — Port von `U.belegSpan`
/// (util.js:387-405).
///
/// Abweichung zum Original: Das JS liest den gespeicherten Spannen-Wert
/// selbst aus dem Store (`U.spanBack`); hier wird er als [storedBack]
/// hereingereicht (null = kein Eintrag → Heuristik greift), damit die
/// Funktion rein bleibt. Die Store-Anbindung (`belegSpans`-Key) liegt bei
/// der aufrufenden Schicht.
BelegSpanResult? belegSpan(
  String pText,
  int fnNum, {
  int? storedBack,
  Iterable<BelegSpanMention> mentions = const [],
}) {
  final sents = splitSentences(pText);
  if (sents.isEmpty) return null;
  final pos = pText.indexOf('[^$fnNum]');
  if (pos == -1) return null;
  final fnIdx = sentenceIndexAt(sents, pos);
  if (fnIdx < 0) return null;

  var back = storedBack ?? 0;
  if (storedBack == null) {
    for (final mt in mentions) {
      if (mt.status != 'beleg' || mt.fn != fnNum) continue;
      final mIdx = sentenceIndexAt(sents, mt.start);
      if (mIdx >= 0 && mIdx < fnIdx && fnIdx - mIdx > back) back = fnIdx - mIdx;
    }
  }
  final from = (fnIdx - back) < 0 ? 0 : fnIdx - back;
  return BelegSpanResult(
    from: from,
    to: fnIdx,
    sents: sents,
    text: pText.substring(sents[from].start, sents[fnIdx].end),
  );
}
