/// Chart-Spezifikations-Tests (K-1): nice-Ticks, Spec-Parsing und das
/// de-AT-Zahlformat — Algorithmen exakt wie notebook.js:268-320.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/features/wissen/charts/chart_spec.dart';

void main() {
  group('niceTicks', () {
    test('96 Fußnoten → 0..100 in 20er-Schritten', () {
      final r = niceTicks(0, 96);
      expect(r.vMin, 0);
      expect(r.vMax, 100);
      expect(r.step, 20);
    });

    test('kleine Spanne → Dezimalschritte', () {
      final r = niceTicks(0, 3);
      expect(r.step, .5);
      expect(r.vMax, 3);
      expect(r.vMin, 0);
    });

    test('negative Werte senken vMin auf ein Schritt-Vielfaches', () {
      final r = niceTicks(-3, 10);
      expect(r.vMin <= -3, isTrue);
      expect(r.vMin % r.step, 0);
      expect(r.vMax >= 10, isTrue);
    });
  });

  group('NbChartSpec.fromJson', () {
    test('Defaults: type bar, Serie N, durchgezählte Labels', () {
      final s = NbChartSpec.fromJson({
        'series': [
          {'values': [1, 2, 3]},
          {'name': 'B', 'values': [4, 5, 6], 'color': '#2e6b74'},
        ],
      });
      expect(s.type, 'bar');
      expect(s.series[0].name, 'Serie 1');
      expect(s.series[1].name, 'B');
      expect(s.series[1].color, '#2e6b74');
      expect(s.labels, ['1', '2', '3']);
      expect(s.effectiveStacked, isFalse);
    });

    test('stacked zählt nur bei bar/area', () {
      expect(
        NbChartSpec.fromJson({'type': 'line', 'stacked': true, 'series': []})
            .effectiveStacked,
        isFalse,
      );
      expect(
        NbChartSpec.fromJson({'type': 'area', 'stacked': true, 'series': []})
            .effectiveStacked,
        isTrue,
      );
    });

    test('axisRange stapelt Summen bei stacked', () {
      final s = NbChartSpec.fromJson({
        'type': 'bar',
        'stacked': true,
        'labels': ['a', 'b'],
        'series': [
          {'values': [10, 20]},
          {'values': [5, 30]},
        ],
      });
      final r = axisRange(s);
      // max Stapel = 50 → vMax rundet auf ein nice-Vielfaches ≥ 50.
      expect(r.vMax >= 50, isTrue);
    });
  });

  group('nbChartFmt', () {
    test('unter 1000: auf 2 Nachkommastellen, ohne überflüssige Nullen', () {
      expect(nbChartFmt(2.456), '2.46');
      expect(nbChartFmt(2.0), '2');
      expect(nbChartFmt(0), '0');
    });

    test('Nicht-Zahlen als String', () {
      expect(nbChartFmt('abc'), 'abc');
    });

    test('ab 1000 gruppiert (de-AT)', () {
      final s = nbChartFmt(1234);
      // Gruppierungszeichen je nach CLDR (U+00A0) — Ziffernfolge bleibt.
      expect(s.replaceAll(RegExp(r'\D'), ''), '1234');
      expect(s.length > 4, isTrue);
    });
  });
}
