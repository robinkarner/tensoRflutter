/// Resolution-Format-Prüfung: tolerante Checker-Semantik (enhance.js:286-305)
/// + dynamische Fußnoten-Obergrenze statt hart 397 (W10).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/data/export/resolution.dart';

void main() {
  test('fehlendes stellen-Array wirft den Original-Fehlertext', () {
    expect(
      () => checkResolution(const {'formatVersion': '1.0'}, footnoteCount: 100),
      throwsA(isA<FormatException>()
          .having((e) => e.message, 'message', 'Feld "stellen" (Array) fehlt.')),
    );
  });

  test('Zählung: mitPos/mitZitat/ohneNum, footnote UND num zulässig', () {
    final r = checkResolution({
      'formatVersion': '1.0',
      'sourceId': 'cobrado2024',
      'stellen': [
        {'footnote': 12, 'seite': 4, 'zitat': 'Originalpassage'},
        {'num': 13, 'fundstelle': 'Art 5'},
        {'zitat': 'ohne Nummer'},
      ],
    }, activeSourceId: 'cobrado2024', footnoteCount: 100);
    expect(r.ok, isTrue);
    expect(r.stellen, 3);
    expect(r.mitPos, 2);
    expect(r.mitZitat, 1);
    expect(r.ohneNum, 1);
    expect(r.probleme, hasLength(1)); // nur die ohne-footnote-Meldung
  });

  test('W10: Obergrenze dynamisch gegen die aktive Arbeit', () {
    final r = checkResolution({
      'formatVersion': '1.0',
      'stellen': [
        {'footnote': 397, 'seite': 1},
        {'footnote': 42, 'seite': 2},
      ],
    }, footnoteCount: 90);
    expect(r.probleme.join(' '), contains('außerhalb 1..90'));
    expect(r.probleme.join(' '), contains('90 Fußnoten'));
  });

  test('tolerierte Probleme: fremde sourceId, fehlende formatVersion', () {
    final r = checkResolution({
      'sourceId': 'andere',
      'stellen': [
        {'footnote': 1, 'zitat': 'x'},
      ],
    }, activeSourceId: 'cobrado2024', footnoteCount: 10);
    expect(r.ok, isTrue);
    expect(r.probleme.join(' '), contains('≠ aktive Quelle'));
    expect(r.probleme.join(' '), contains('kein "formatVersion"'));
  });

  test('Import-Normalisierung: sourceId/generatedBy-Fallbacks, Rest roh', () {
    final out = normalizeResolutionForImport(
      {'formatVersion': '1.0', 'stellen': [], 'fremdesFeld': 42},
      sourceId: 'kraus2025',
    );
    expect(out['sourceId'], 'kraus2025');
    expect(out['generatedBy'], 'gpt');
    expect(out['fremdesFeld'], 42, reason: 'unbekannte Felder überleben');
  });
}
