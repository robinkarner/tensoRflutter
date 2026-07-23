/// Golden-Test: TexParse gegen `js/texparse.js` — die komplette 14-stufige
/// Pipeline auf beiden echten Arbeiten plus synthetische Randfälle.
///
/// Verglichen wird das GESAMTE Ergebnis-JSON (Struktur-Baum, Absätze,
/// Fußnoten, Quellen, Fehler-/Warnungstexte) strikt; die Pflicht-
/// Invarianten (397 Fußnoten, 74 Quellen, identische Absatz-Zerlegung)
/// stecken damit automatisch mit drin und werden zusätzlich explizit
/// geprüft.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/domain/texparse.dart';

import 'fixture_util.dart';

void main() {
  test('thesis-source.tex mit Registry: Ergebnis identisch (397 Fn, 74 Quellen)', () {
    final fix = loadFixtureMap('texparse_thesis.json');
    final registry = [
      for (final r in fix['registry'] as List) Map<String, dynamic>.from(r as Map),
    ];
    final tex = _readData('thesis-source.tex');
    final got = TexParse.parse(tex, registry: registry);

    // Pflicht-Invarianten explizit
    expect(got.ok, isTrue);
    expect(got.stats!['fussnoten'], 397);
    expect(got.stats!['quellen'], 74);

    final diff = jsonDiff(fix['result'], got.toJson());
    expect(diff, isNull, reason: '$diff');
  });

  test('sensors-paper.tex ohne Registry: \\cite-Modus identisch', () {
    final fix = loadFixtureMap('texparse_sensors.json');
    final got = TexParse.parse(_readData('sensors-paper.tex'));
    expect(got.ok, isTrue);
    // Auto-Registry aus den Bib-Keys
    expect(got.stats!['quellen'], greaterThan(0));
    expect(
        got.warnings.any((w) => w.startsWith('\\cite-basierte Arbeit erkannt:')), isTrue);
    final diff = jsonDiff(fix['result'], got.toJson());
    expect(diff, isNull, reason: '$diff');
  });

  test('synthetische Randfälle: Fehlerpfade und Level-Shift identisch', () {
    final cases = loadFixture('texparse_cases.json') as List;
    expect(cases, isNotEmpty);
    for (final c in cases.cast<Map<String, dynamic>>()) {
      final got = TexParse.parse(c['tex'] as String);
      final diff = jsonDiff(c['result'], got.toJson());
      expect(diff, isNull, reason: 'Fall "${c['name']}" → $diff');
    }
  });

  test('typisierte Sicht: thesisModel/sourceModels sind konsistent', () {
    final fix = loadFixtureMap('texparse_thesis.json');
    final registry = [
      for (final r in fix['registry'] as List) Map<String, dynamic>.from(r as Map),
    ];
    final got = TexParse.parse(_readData('thesis-source.tex'), registry: registry);
    final thesis = got.thesisModel!;
    // thesis-source.tex enthält KEIN \settitle/\title — auch das JS-Original
    // fällt hier auf „Unbenannte Arbeit“ zurück (mit Warnung); der echte
    // Titel der eingebauten Arbeit kommt aus dem Bundle, nicht aus TexParse.
    expect(thesis.meta.title, 'Unbenannte Arbeit');
    expect(got.warnings,
        contains('Kein Titel gefunden (\\settitle/\\title) — „Unbenannte Arbeit“ verwendet.'));
    expect(thesis.chapters.length, got.stats!['kapitel']);
    final sources = got.sourceModels;
    expect(sources.length, 74);
    expect(sources.first.citations, isNotEmpty);
  });

  test('cleanTex: Akzente, Sonderzeichen, Kommentare', () {
    // Akzentmakros (ohne/mit Braces) — Leerzeichen-Verhalten wie im JS:
    // cleanTex schluckt das Leerzeichen nach \ss NICHT (LaTeX täte es)
    expect(TexParse.cleanTex('caf\\\'e und gar\\c{c}on'), 'café und garçon');
    expect(TexParse.cleanTex(r'\enquote{Zitat} mit \S~5 und 100\,\%'), '„Zitat“ mit § 5 und 100 %');
    expect(TexParse.cleanTex('Text % Kommentar\nweiter'), 'Text weiter');
    expect(TexParse.cleanTex(r'50\% bleiben'), '50% bleiben');
    expect(TexParse.cleanTex(r'\href{http://x}{Linktext} und \url{http://y}'),
        'Linktext und http://y');
  });

  test('sourceFromKey: Bib-Key-Raten wie im Original', () {
    final s = TexParse.sourceFromKey('abu-rasheed_context_2023');
    expect(s['id'], 'abu-rasheed_context_2023');
    expect(s['author'], 'Abu-Rasheed');
    expect(s['year'], 2023);
    expect(s['title'], 'Context');
    expect(s['keyGuessed'], true);
    expect(s['aliases'], [RegExp.escape('abu-rasheed_context_2023')]);
  });
}

// Die .tex-Quellen liegen als Assets im Projekt (identisch zu data/ im
// Original-Repo, aus dem der Generator liest).
String _readData(String name) => readAssetData(name);
