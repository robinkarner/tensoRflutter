/// Golden-Test: splitSentences gegen `U.splitSentences` (util.js) —
/// 30 echte Absätze der eingebauten Arbeit, Fixture aus tools/golden_gen.mjs.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/core/util/sentences.dart';

import 'fixture_util.dart';

void main() {
  test('splitSentences liefert identische Spannen wie das JS-Original', () {
    final cases = loadFixture('sentences.json') as List;
    expect(cases, isNotEmpty);
    for (final c in cases.cast<Map<String, dynamic>>()) {
      final got = [for (final s in splitSentences(c['text'] as String)) s.toJson()];
      final diff = jsonDiff(c['sents'], got);
      expect(diff, isNull, reason: 'Absatz: ${(c['text'] as String).substring(0, 60)}… → $diff');
    }
  });

  test('sentenceIndexAt: Treffer, Rand und leere Liste', () {
    final sents = splitSentences('Erster Satz. Zweiter Satz. Dritter.');
    expect(sents.length, 3);
    expect(sentenceIndexAt(sents, 0), 0);
    expect(sentenceIndexAt(sents, sents[1].start), 1);
    // Position hinter dem letzten Satz → letzter Satz (JS-Fallback)
    expect(sentenceIndexAt(sents, 9999), sents.length - 1);
    expect(sentenceIndexAt(const [], 0), -1);
  });

  test('Abkürzungen und Marker-Tails bleiben satzintern', () {
    // „z. B." als Einzelbuchstabe + Abkürzungsliste, Marker am Satzende
    final s1 = splitSentences('Vgl. dazu die Norm. Danach folgt mehr.');
    expect(s1.length, 2, reason: '„Vgl." darf den ersten Satz nicht beenden');
    final s2 = splitSentences('Das ist belegt.[^12] Nächster Satz beginnt.');
    expect(s2.first.text, 'Das ist belegt.[^12]');
    final s3 = splitSentences('Siehe Abschnitt 3.1 der Arbeit.');
    expect(s3.length, 1, reason: '„3.1" ist kein Satzende');
  });

  test('belegSpan: Marker-Satz, gespeicherte und heuristische Spanne', () {
    const text = 'Satz eins ist hier. Satz zwei sagt mehr. Satz drei belegt es.[^7]';
    // Ohne Heuristik/Speicher: nur der Marker-Satz
    final plain = belegSpan(text, 7);
    expect(plain, isNotNull);
    expect(plain!.from, 2);
    expect(plain.to, 2);
    expect(plain.text, 'Satz drei belegt es.[^7]');
    // Gespeicherter Wert zieht die Spanne auf
    final stored = belegSpan(text, 7, storedBack: 2)!;
    expect(stored.from, 0);
    expect(stored.text, text);
    // Heuristik: zusammengeführte Erwähnung (status beleg, gleiche fn) vorn
    final merged = belegSpan(text, 7, mentions: [
      const BelegSpanMention(status: 'beleg', fn: 7, start: 20),
    ])!;
    expect(merged.from, 1);
    // Fremde Fußnote/Status zählt nicht
    final foreign = belegSpan(text, 7, mentions: [
      const BelegSpanMention(status: 'bestaetigt', fn: 7, start: 0),
      const BelegSpanMention(status: 'beleg', fn: 9, start: 0),
    ])!;
    expect(foreign.from, 2);
    // Marker fehlt → null
    expect(belegSpan(text, 99), isNull);
  });
}
