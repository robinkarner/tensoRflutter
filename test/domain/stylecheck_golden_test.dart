/// Golden-Test: StyleCheck gegen `js/stylecheck.js` — 20 Absätze
/// (8 echte DE, 6 echte EN aus dem Sensors-Parse, 6 synthetische mit
/// gezielter Regel-Abdeckung), Fixture aus tools/golden_gen.mjs.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/domain/stylecheck.dart';

import 'fixture_util.dart';

void main() {
  const check = StyleCheck();

  test('analyzePara liefert identische Treffer wie das JS-Original', () {
    final cases = loadFixture('stylecheck.json') as List;
    expect(cases, isNotEmpty);
    var flaggedTotal = 0;
    for (final c in cases.cast<Map<String, dynamic>>()) {
      final got = [for (final f in check.analyzePara(c['text'] as String)) f.toJson()];
      flaggedTotal += got.length;
      final diff = jsonDiff(c['flagged'], got);
      expect(diff, isNull,
          reason: 'Absatz: ${(c['text'] as String).substring(0, 60)}… → $diff');
    }
    // Sicherstellen, dass die Fixture wirklich Regeln abdeckt
    expect(flaggedTotal, greaterThan(8));
  });

  test('Regel-Details: Vage-Deckelung, Konnektor-Kette, Zitat-Schutz', () {
    // 3 vage Wörter → Score-Beitrag gedeckelt auf 1, nur 2 gelistet
    final vague = check.analyzeSentence(
        'Overall there are various and numerous aspects.', false);
    expect(vague.score, 1);
    expect(vague.hits.where((h) => h.startsWith('vage:')).length, 2);
    // Konnektor zählt erst in der KETTE (voriger Satz auch Konnektor)
    expect(check.analyzeSentence('Furthermore, this holds.', false).score, 0);
    expect(check.analyzeSentence('Furthermore, this holds.', true).score, 1);
    // Konnektor-Regex ist case-sensitiv (Satzanfang)
    expect(check.analyzeSentence('furthermore, this holds.', true).score, 0);
    // Einordnung MIT Beleg ([^N] im Rohtext) wird nicht angeschlagen
    expect(check.analyzeSentence('Das System ist wichtig.[^3]', false).score, 0);
    expect(
        check.analyzeSentence('Das System ist wichtig.', false).hits,
        contains('Einordnung ohne Beleg/Konkretes („ist wichtig/zentral“)'));
  });
}
