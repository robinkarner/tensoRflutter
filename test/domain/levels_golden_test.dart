/// Golden-Test: Levels gegen `js/levels.js` — die info()-Kaskade auf leerem
/// und geseedetem Store, save()-Ableitungslogik und der Belegstand-Export
/// `ehds-belegstand` v2 (inkl. Import-Roundtrip mit `notes`↔`srcNotes`).
///
/// Das Seed-Szenario wird exakt aus der Fixture nachgespielt (dieselben
/// save()-Aufrufe; resolutions/annotations kommen aus dem im Generator
/// exportierten Stand) — die Uhr ist auf [fixedNowMs] eingefroren.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/domain/domain.dart';

import 'fixture_util.dart';

void main() {
  final ctx = builtinContext();

  test('info()-Kaskade auf leerem Store: KI-Beleg → 1, sonst 0', () {
    final fix = loadFixtureMap('levels.json')['empty'] as Map<String, dynamic>;
    final levels = Levels(ctx, MemoryDomainStore(), nowMs: () => fixedNowMs);
    final per = fix['per'] as Map<String, dynamic>;
    expect(per.length, 397, reason: 'eingebaute Arbeit hat 397 Fußnoten');
    for (final e in per.entries) {
      expect(levels.info(int.parse(e.key)).level, e.value, reason: 'Fußnote ${e.key}');
    }
    final counts = levels.countsFor(levels.allNums()).toJson();
    expect(jsonDiff(fix['counts'], counts), isNull);
  });

  test('Seed-Szenario: save()-Ableitung, Kaskade, Export identisch', () {
    final fix = loadFixtureMap('levels.json')['seeded'] as Map<String, dynamic>;
    final store = MemoryDomainStore();
    final levels = Levels(ctx, store, nowMs: () => fixedNowMs);

    // 1. dieselben save()-Aufrufe wie der Generator (aus der Fixture)
    final returns = <int>[];
    for (final s in (fix['saves'] as List)) {
      final num = (s as List)[0] as int;
      final data = (s[1] as Map).map((k, v) => MapEntry(k.toString(), v as Object?));
      returns.add(levels.save(num, data));
    }
    expect(returns, fix['returns']);

    // 2. resolutions/annotations aus dem im Generator entstandenen Export
    final exported = jsonDecode(fix['exportState'] as String) as Map<String, dynamic>;
    store.write('resolutions', exported['resolutions']);
    store.write('annotations', exported['annotations']);

    // 3. Kaskade je Fußnote (gespeichert > Resolution/Annotation > KI)
    for (final e in (fix['infos'] as Map<String, dynamic>).entries) {
      final got = levels.info(int.parse(e.key)).json;
      final diff = jsonDiff(e.value, got);
      expect(diff, isNull, reason: 'info(${e.key}) → $diff');
    }

    // 4. Store-Inhalt und Zählung
    expect(jsonDiff(fix['belegLevels'], store.readMap('belegLevels')), isNull);
    expect(jsonDiff(fix['counts'], levels.countsFor(levels.allNums()).toJson()), isNull);

    // 5. Export bit-kompatibel (als geparstes JSON verglichen — die
    //    Feld-REIHENFOLGE ist im Original identisch, nur die Einrückung
    //    von JSON.stringify vs. JsonEncoder kann minimal abweichen)
    final gotExport = jsonDecode(levels.exportState());
    expect(jsonDiff(exported, gotExport), isNull);

    // 6. Auto-Farbrotation deterministisch wie im Original
    final src50 = fix['src50'] as String?;
    if (src50 != null) {
      expect(levels.autoFarbe(src50, 50), (fix['farben'] as Map)['auto50']);
    }
  });

  test('Import-Roundtrip: notes↔srcNotes, truthy-Overwrite-Semantik', () {
    final fix = loadFixtureMap('levels.json')['seeded'] as Map<String, dynamic>;
    final store = MemoryDomainStore({
      'srcNotes': {'bleibt': 'alter Stand'},
      'dlStatus': {'alt': true},
    });
    final levels = Levels(ctx, store, nowMs: () => fixedNowMs);

    // Export-Feld `notes` landet im Store-Key `srcNotes` (W7)
    final json = jsonDecode(fix['exportState'] as String) as Map<String, dynamic>;
    json['notes'] = {'kim2023': 'Notiz aus Export'};
    json['dlStatus'] = null; // null/fehlend lässt Bestand stehen (falsy)
    final count = levels.importState(jsonEncode(json));
    expect(count, (json['belegLevels'] as Map).length);
    expect(store.readMap('srcNotes'), {'kim2023': 'Notiz aus Export'});
    expect(store.readMap('dlStatus'), {'alt': true}, reason: 'null überschreibt nicht');
    // {} ist truthy und überschreibt sehr wohl (JS-Semantik!)
    json['dlStatus'] = <String, Object?>{};
    levels.importState(jsonEncode(json));
    expect(store.readMap('dlStatus'), isEmpty);

    expect(
      () => levels.importState('{"format": "anders"}'),
      throwsA(predicate((e) =>
          e is FormatException &&
          e.message == 'Unbekanntes Format — erwartet "ehds-belegstand".')),
    );
  });

  test('save(): Aufräumen leerer Felder und Eintrag-Entfernung', () {
    final store = MemoryDomainStore();
    final levels = Levels(ctx, store, nowMs: () => fixedNowMs);
    expect(levels.save(300, {'zitat': 'Z', 'seite': 12}), 3);
    // Position entfernen → Original (2); alles leeren → Eintrag weg (0)
    expect(levels.save(300, {'seite': ''}), 2);
    expect(levels.save(300, {'zitat': null}), 0);
    expect(levels.entry(300), isNull);
    // Nur Farbe → Level 0, Eintrag bleibt (blockiert die Kaskade nicht)
    expect(levels.save(301, {'farbe': 'rot'}), 0);
    expect(levels.entry(301)!['farbe'], 'rot');
    expect(levels.info(301).level, anyOf(0, 1), reason: 'Kaskade läuft weiter');
    expect(levels.info(301).farbe, 'rot');
  });

  test('Stufen-Definition und Farb-Palette exakt (Hex, Icons, Labels)', () {
    expect(Levels.levelDefs[1]!.icon, '✦');
    expect(Levels.levelDefs[2]!.icon, '❝');
    expect(Levels.levelDefs[3]!.icon, '✓');
    expect(Levels.levelDefs[3]!.label, 'belegt');
    expect(Levels.farben.map((f) => f.hex).toList(), [
      '#e8c33f', '#5f8fc7', '#7cab54', '#d77aa4',
      '#dd8a3e', '#9779c9', '#4fb3a5', '#cf6d5c',
    ]);
    expect(Levels.farbHex('blau'), '#5f8fc7');
    expect(Levels.farbHex('gibtsnicht'), isNull);
  });

  test('positionType/-Label: Fundstelle bei Recht/Online/Norm, sonst Seite', () {
    final levels = Levels(ctx, MemoryDomainStore(), nowMs: () => fixedNowMs);
    expect(levels.positionType('dsgvo'), 'fundstelle');
    expect(levels.positionLabel('dsgvo'), 'Fundstelle (Art/§/Abschnitt)');
    expect(levels.positionType('unbekannt'), 'seite');
    expect(levels.positionLabel('kim2023'), 'Seite im PDF');
  });

  test('PDF-Markierungs-Zweig der Kaskade (injizierter marksForFn)', () {
    final store = MemoryDomainStore();
    // Fußnote mit Quelle finden, die nach Seite zitiert wird
    late int fnSeite;
    late String srcSeite;
    for (final e in ctx.fnIndex.entries) {
      final src = e.value.sources.isNotEmpty ? ctx.srcById[e.value.sources.first] : null;
      if (src != null && !src.zitiertNachFundstelle) {
        fnSeite = e.key;
        srcSeite = src.id;
        break;
      }
    }
    final levels = Levels(ctx, store, nowMs: () => fixedNowMs, marksForFn: (srcId, fnNum) {
      if (srcId == srcSeite && fnNum == fnSeite) {
        return const [PdfMarkLevelInput(zitat: 'Markiertes Zitat', page: 4, farbe: 'gruen')];
      }
      return const [];
    });
    final inf = levels.info(fnSeite);
    expect(inf.level, 3, reason: 'Seite + positionType seite → belegt');
    expect(inf.herkunft, 'markierung');
    expect(inf.farbe, 'gruen', reason: 'Markierungsfarbe, solange keine manuelle gesetzt ist');
    expect(inf.derived, isTrue);
  });
}
