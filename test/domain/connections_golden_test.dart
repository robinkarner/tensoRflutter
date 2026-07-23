/// Golden-Test: Connections gegen `js/connections.js` — komplette
/// Kantenliste (Fazit + Text-Querverweise + seltene gemeinsame Quellen;
/// die eingebaute Arbeit hat kein KI-Bundle, W3) und Rang-Sortierung von
/// forSection; dazu Unit-Tests für importKi.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/domain/domain.dart';

import 'fixture_util.dart';

void main() {
  final ctx = builtinContext();

  test('all() liefert identische Kanten wie das JS-Original', () {
    final fix = loadFixtureMap('connections.json');
    final conn = Connections(ctx, MemoryDomainStore());
    final got = [for (final e in conn.all()) e.json];
    final diff = jsonDiff(fix['edges'], got);
    expect(diff, isNull, reason: '$diff');
    expect(got.length, greaterThan(40));
  });

  test('forSection sortiert stabil nach Typ-Rang wie das JS-Original', () {
    final fix = loadFixtureMap('connections.json');
    final conn = Connections(ctx, MemoryDomainStore());
    for (final e in (fix['forSection'] as Map<String, dynamic>).entries) {
      final r = conn.forSection(e.key);
      expect([for (final c in r.out) c.id], e.value['out'],
          reason: 'out-Kanten von ${e.key}');
      expect([for (final c in r.inbound) c.id], e.value['in'],
          reason: 'in-Kanten von ${e.key}');
    }
  });

  test('importKi: Validierung, Merge per id, Cache-Invalidierung', () {
    final store = MemoryDomainStore();
    final conn = Connections(ctx, store, nowMs: () => fixedNowMs);
    final a = ctx.orderedUnitIds.first;
    final b = ctx.orderedUnitIds[3];

    // Fehlerpfade mit den exakten deutschen Meldungen
    expect(
      () => conn.importKi('{"foo": 1}'),
      throwsA(predicate((e) =>
          e is FormatException && e.message == 'Feld "connections" (Array) fehlt.')),
    );
    expect(
      () => conn.importKi({
        'connections': [
          {'von': {'sectionId': 'gibtsnicht'}, 'nach': {'sectionId': a}},
        ],
      }),
      throwsA(predicate((e) =>
          e is FormatException &&
          e.message ==
              'Keine gültigen Einträge (1 übersprungen — von/nach.sectionId müssen existierende Abschnitte sein).')),
    );

    // Gültig + ungültig gemischt → Statustext mit Zählung
    final msg = conn.importKi({
      'connections': [
        {'id': 'c1', 'typ': 'folgerung', 'von': {'sectionId': a}, 'nach': {'sectionId': b}, 'label': 'L', 'text': 'T'},
        {'id': 'c2', 'typ': 'unbekannt', 'von': {'sectionId': a}, 'nach': {'sectionId': a}},
      ],
    });
    expect(msg, '1 übernommen, 1 übersprungen (ungültige/unbekannte Abschnitte)');

    // Kante taucht als KI-Kante auf; unbekannter typ wäre 'aufgriff' geworden
    final edge = conn.all().firstWhere((c) => c.id == 'c1');
    expect(edge.herkunft, 'ki');
    expect(edge.typ, 'folgerung');

    // Merge per id: Re-Import ersetzt statt dupliziert; Nur-Zahl-Statustext
    final msg2 = conn.importKi({
      'connections': [
        {'id': 'c1', 'typ': 'vergleich', 'von': {'sectionId': a}, 'nach': {'sectionId': b}},
      ],
    });
    expect(msg2, '1');
    final stored = store.readMap('kiConnections')['connections'] as List;
    expect(stored.length, 1);
    expect(conn.all().firstWhere((c) => c.id == 'c1').typ, 'vergleich');
  });

  test('regeneratePrompt enthält Vertragstexte und Gliederung', () {
    final conn = Connections(ctx, MemoryDomainStore());
    final prompt = conn.regeneratePrompt();
    expect(prompt, contains('Qualität vor Menge: 15–40 Verbindungen, jede mit kurzer Begründung.'));
    expect(prompt, contains('ANTWORTE NUR mit diesem JSON (importierbar unter Projekt → Connections):'));
    expect(prompt, contains('KAPITEL 1:'));
    expect(prompt, contains('(Überblick)'));
  });
}
