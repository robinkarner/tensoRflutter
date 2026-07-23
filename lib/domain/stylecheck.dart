/// 🤖 GPT-Stil-Check (deterministisch, ohne KI) — Port von `js/stylecheck.js`.
///
/// Markiert Sätze, die nach generischem KI-Schreibstil klingen: Floskeln,
/// seichter Einordnungsstil („X spielt eine zentrale Rolle“), vage Mengen-
/// wörter, Konnektor-Ketten (Furthermore/Moreover/…) und wertende Sätze
/// ohne Beleg oder Konkretes. Je Satz ein Score mit Begründungen —
/// bewusst ein HINWEIS zum Selbst-Redigieren, kein Urteil.
///
/// Vollständig zustandslos (keine Persistenz).
library;

import '../core/util/sentences.dart';

/// Ergebnis für einen Satz.
class StyleVerdict {
  /// Kann durch die Vage-Deckelung halbzahlig sein (z. B. 0.5, 1.5).
  final double score;
  final List<String> hits;

  /// Beginnt dieser Satz mit einem Konnektor? (Zustand für den Folgesatz)
  final bool connector;

  const StyleVerdict({required this.score, required this.hits, required this.connector});
}

/// Ein auffälliger Satz eines Absatzes (Score ≥ 1) mit Roh-Offsets.
class FlaggedSentence {
  final int start;
  final int end;
  final String text;
  final double score;
  final List<String> hits;

  const FlaggedSentence({
    required this.start,
    required this.end,
    required this.text,
    required this.score,
    required this.hits,
  });

  Map<String, Object?> toJson() => {
        'start': start,
        'end': end,
        'text': text,
        // Golden-Kompatibilität: ganzzahlige Scores wie in JS als int (2
        // statt 2.0), halbe bleiben double.
        'score': score == score.roundToDouble() ? score.round() : score,
        'hits': hits,
      };
}

class StyleCheck {
  const StyleCheck();

  /// Floskeln/Füllphrasen (EN + DE) — je Treffer +1 (stylecheck.js:11-41).
  static final List<RegExp> filler = [
    RegExp(r'\bplays? an? (?:key|central|crucial|vital|significant|pivotal|important|essential) role\b', caseSensitive: false),
    RegExp(r'\bit is (?:important|worth|essential|crucial) to (?:note|mention|emphasi[sz]e|highlight|understand)\b', caseSensitive: false),
    RegExp(r"\bin (?:today'?s|the modern|the current) (?:world|era|landscape|society|age)\b", caseSensitive: false),
    RegExp(r'\bin recent years\b', caseSensitive: false),
    RegExp(r'\brapidly (?:evolving|changing|growing)\b', caseSensitive: false),
    RegExp(r'\bever-(?:evolving|changing|growing|increasing)\b', caseSensitive: false),
    RegExp(r'\ba wide (?:range|variety|array) of\b', caseSensitive: false),
    RegExp(r'\bvaluable insights?\b', caseSensitive: false),
    RegExp(r'\bcomprehensive (?:overview|understanding|analysis)\b', caseSensitive: false),
    RegExp(r'\bpaves? the way\b', caseSensitive: false),
    RegExp(r'\bholds? (?:great |significant |immense )?promise\b', caseSensitive: false),
    RegExp(r'\bseamless(?:ly)?\b', caseSensitive: false),
    RegExp(r'\bleverag(?:e|es|ing)\b', caseSensitive: false),
    RegExp(r'\bdelv(?:e|es|ing)\b', caseSensitive: false),
    RegExp(r'\bunderscor(?:e|es|ing)\b', caseSensitive: false),
    RegExp(r'\bhighlight(?:s|ing)? the (?:importance|need|potential|significance)\b', caseSensitive: false),
    RegExp(r'\bnot only\b[\s\S]{0,80}\bbut also\b', caseSensitive: false),
    RegExp(r'\bmore and more\b', caseSensitive: false),
    RegExp(r'\bincreasingly (?:important|relevant|popular|common|central)\b', caseSensitive: false),
    RegExp(r'\b(?:significant|tremendous|immense|enormous|vast) (?:potential|impact|importance)\b', caseSensitive: false),
    RegExp(r'\bcrucial\b', caseSensitive: false),
    RegExp(r'\bpivotal\b', caseSensitive: false),
    RegExp(r'\bspielt eine (?:zentrale|wichtige|entscheidende|bedeutende|immer größere) Rolle\b', caseSensitive: false),
    RegExp(r'\bvon (?:großer|zentraler|entscheidender|erheblicher) Bedeutung\b', caseSensitive: false),
    RegExp(r'\bimmer wichtiger\b', caseSensitive: false),
    RegExp(r'\bgewinnt (?:zunehmend|immer mehr) an Bedeutung\b', caseSensitive: false),
    RegExp(r'\bin der heutigen (?:Zeit|Gesellschaft|Welt)\b', caseSensitive: false),
    RegExp(r'\bes ist (?:wichtig|entscheidend|hervorzuheben|festzuhalten)\b', caseSensitive: false),
    RegExp(r'\bzusammenfassend lässt sich (?:sagen|festhalten)\b', caseSensitive: false),
  ];

  /// Vage Mengen-/Einordnungswörter — gedeckelt auf +1 gesamt
  /// (stylecheck.js:43-47).
  static final List<RegExp> vague = [
    RegExp(r'\bvarious\b', caseSensitive: false),
    RegExp(r'\bnumerous\b', caseSensitive: false),
    RegExp(r'\ba variety of\b', caseSensitive: false),
    RegExp(r'\bseveral aspects\b', caseSensitive: false),
    RegExp(r'\bdifferent aspects\b', caseSensitive: false),
    RegExp(r'\boverall\b', caseSensitive: false),
    RegExp(r'\bessentially\b', caseSensitive: false),
    RegExp(r'\bbroadly\b', caseSensitive: false),
    RegExp(r'\bverschiedenste[nr]?\b', caseSensitive: false),
    RegExp(r'\bzahlreiche[nr]?\b', caseSensitive: false),
    RegExp(r'\bvielfältig(?:e[nr]?)?\b', caseSensitive: false),
    RegExp(r'\bgrundsätzlich\b', caseSensitive: false),
  ];

  /// Konnektoren am Satzanfang — KETTEN davon sind der typische
  /// Gliederungsstil (case-SENSITIVE wie das Original).
  static final RegExp connect = RegExp(
      r'^(?:Furthermore|Moreover|Additionally|In addition|Overall|In conclusion|Notably|Importantly|Consequently|Darüber hinaus|Des Weiteren|Zudem|Außerdem|Insgesamt|Abschließend|Folglich|Somit)\b');

  static final RegExp _marker = RegExp(r'\[\^\d+\]');
  static final RegExp _ws = RegExp(r'\s+');
  static final RegExp _evaluative = RegExp(
    r'\b(?:is|are|remains?|becomes?|has become|ist|sind|wird|bleibt) (?:a |an |ein |eine |einen )?(?:key|central|essential|crucial|important|vital|major|fundamental|wichtig(?:er|es|e)?|zentral(?:er|es|e)?|entscheidend(?:er|es|e)?|wesentlich(?:er|es|e)?)\b',
    caseSensitive: false,
  );
  static final RegExp _yearParen = RegExp(r'\(\s*(?:19|20)\d{2}[a-z]?\s*\)');
  static final RegExp _concrete = RegExp(r'\d|%|\bFig\.|\bTab(?:elle)?\b|\bAbb\.');

  /// Einen Satz prüfen. [prevConnector]: begann der VORIGE Satz mit einem
  /// Konnektor? (nur dann zählt die Kette) — stylecheck.js:51-75.
  StyleVerdict analyzeSentence(String? text, bool prevConnector) {
    final raw = text ?? '';
    final t = raw.replaceAll(_marker, ' ').replaceAll(_ws, ' ').trim();
    final hits = <String>[];
    var score = 0.0;
    for (final re in filler) {
      final m = re.firstMatch(t);
      if (m != null) {
        score += 1;
        hits.add('Floskel: „${m.group(0)}“');
      }
    }
    var vagueCount = 0;
    for (final re in vague) {
      final m = re.firstMatch(t);
      if (m != null) {
        vagueCount++;
        if (vagueCount <= 2) hits.add('vage: „${m.group(0)}“');
      }
    }
    score += vagueCount * 0.5 > 1 ? 1 : vagueCount * 0.5;
    final isConn = connect.hasMatch(t);
    if (isConn && prevConnector) {
      score += 1;
      hits.add('Konnektor-Kette (Furthermore/Moreover/Zudem …)');
    }
    // Seichter Einordnungssatz: wertet („ist wichtig/zentral“), ohne Beleg
    // und ohne Konkretes (Zahl/Abbildung) — wenig eigene Substanz.
    // Achtung: hasCite prüft den ROHTEXT auf [^N]-Marker, die anderen
    // Prüfungen den bereinigten Text.
    final evaluative = _evaluative.hasMatch(t);
    final hasCite = _marker.hasMatch(raw) || _yearParen.hasMatch(t);
    final hasConcrete = _concrete.hasMatch(t);
    if (evaluative && !hasCite && !hasConcrete) {
      score += 1;
      hits.add('Einordnung ohne Beleg/Konkretes („ist wichtig/zentral“)');
    }
    return StyleVerdict(score: score, hits: hits, connector: isConn);
  }

  /// Absatztext → nur auffällige Sätze (Score ≥ 1); der Konnektor-Zustand
  /// wird über die Sätze hinweg weitergetragen — stylecheck.js:78-87.
  List<FlaggedSentence> analyzePara(String? text) {
    final out = <FlaggedSentence>[];
    var prevConn = false;
    for (final s in splitSentences(text ?? '')) {
      final r = analyzeSentence(s.text, prevConn);
      prevConn = r.connector;
      if (r.score >= 1) {
        out.add(FlaggedSentence(
          start: s.start,
          end: s.end,
          text: s.text,
          score: r.score,
          hits: r.hits,
        ));
      }
    }
    return out;
  }
}
