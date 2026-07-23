/// Golden-Test: Mentions gegen `js/mentions.js` — forPara für 10 Abschnitte
/// der eingebauten Arbeit + synthetische detect-Fälle (Fenster,
/// Nähe-Unterdrückung, Mehrdeutigkeit); dazu Unit-Tests für die
/// Alt-Format-Migration und mergeTarget.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/data/models/models.dart';
import 'package:thesor/domain/domain.dart';

import 'fixture_util.dart';

void main() {
  final ctx = builtinContext();

  test('forPara liefert identische Erwähnungen wie das JS-Original', () {
    final fix = loadFixtureMap('mentions.json');
    final mentions = Mentions(ctx, MemoryDomainStore());
    for (final sec in (fix['sections'] as List).cast<Map<String, dynamic>>()) {
      final sectionId = sec['sectionId'] as String;
      final unit = ctx.unitIndex[sectionId]!.unit;
      final byId = {for (final p in unit.paragraphs) p.id: p};
      for (final pFix in (sec['paragraphs'] as List).cast<Map<String, dynamic>>()) {
        final p = byId[pFix['id']]!;
        final got = [for (final m in mentions.forPara(sectionId, p)) m.toJson()];
        final diff = jsonDiff(pFix['mentions'], got);
        expect(diff, isNull, reason: 'Absatz ${p.id} → $diff');
      }
    }
  });

  test('detect: synthetische Fälle (Treffer + Unterdrückung) identisch', () {
    final fix = loadFixtureMap('mentions.json');
    final mentions = Mentions(ctx, MemoryDomainStore());
    final cases = (fix['detect'] as List).cast<Map<String, dynamic>>();
    expect(cases, isNotEmpty);
    for (final c in cases) {
      final got = [for (final h in mentions.detect(c['text'] as String, const [])) h.toJson()];
      final diff = jsonDiff(c['hits'], got);
      expect(diff, isNull, reason: 'Text: ${c['text']} → $diff');
    }
  });

  test('Alt-Format-Migration: "paraId|srcId|start" wird verlustfrei überführt', () {
    final mentions0 = Mentions(ctx, MemoryDomainStore());
    // Einen sicheren Treffer aus den Mustern der echten Quellen bauen
    final pat = mentions0.patterns().first;
    final text = 'Wie ${pat.names.first} (${pat.year}) zeigt, gilt das.';
    final para = Paragraph(id: 'X-p1', type: 'text', text: text);
    final hit = mentions0.detect(text, const []).first;

    final store = MemoryDomainStore({
      'textMentions': {'X-p1|${hit.srcId}|${hit.start}': 'bestaetigt'},
    });
    final mentions = Mentions(ctx, store);
    final enriched = mentions.forPara('X', para).first;
    expect(enriched.status, 'bestaetigt');
    expect(enriched.srcId, hit.srcId);
    // Store wurde in-place migriert: neuer Key da, alter weg
    final tm = store.readMap('textMentions');
    expect(tm.containsKey('X-p1|${hit.start}'), isTrue);
    expect(tm.containsKey('X-p1|${hit.srcId}|${hit.start}'), isFalse);
  });

  test('setStatus/mergeTarget: beleg-Merge und Zurücksetzen', () {
    final store = MemoryDomainStore();
    final mentions = Mentions(ctx, store);
    final pat = mentions.patterns().first;
    // Fußnote derselben Quelle für den Merge suchen
    int? fnNum;
    for (final e in ctx.fnIndex.entries) {
      if (e.value.sources.contains(pat.srcId)) {
        fnNum = e.key;
        break;
      }
    }
    expect(fnNum, isNotNull, reason: 'Muster-Quelle braucht eine Fußnote');
    // Marker liegt >320 Zeichen hinter der Nennung → keine Unterdrückung
    final filler = 'x' * 330;
    final text = 'Wie ${pat.names.first} (${pat.year}) zeigt, gilt das. $filler [^$fnNum]';
    final para = Paragraph(id: 'Y-p1', type: 'text', text: text);
    final hit = mentions.forPara('Y', para).first;
    expect(hit.status, 'offen');
    expect(mentions.mergeTarget(para, hit), fnNum);

    mentions.setStatus(hit.key, 'beleg', hit.srcId, fnNum);
    mentions.invalidate();
    final merged = mentions.forPara('Y', para).first;
    expect(merged.status, 'beleg');
    expect(merged.fn, fnNum);

    mentions.setStatus(hit.key, 'offen', hit.srcId);
    expect(store.readMap('textMentions'), isEmpty);
  });
}
