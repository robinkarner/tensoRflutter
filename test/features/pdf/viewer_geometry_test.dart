/// Geometrie-/Zoom-Logik des Viewers: Original-Konstanten (Fit-Abzug 26,
/// min 0.35, Schritt ×1.2 in 0.3–4, Follow-Linie 35 %, Freigabe > 8,
/// goto-Offset −10) und der pdfZoomPref-Typ-Mix `"fit"`|Zahl.
library;

import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/features/pdf/viewer/viewer_geometry.dart';

void main() {
  group('Zoom', () {
    test('fitZoom: (Breite − 26) / Seitenbreite, min 0.35', () {
      expect(fitZoom(621, 595), (621 - 26) / 595);
      expect(fitZoom(100, 595), 0.35); // Untergrenze
    });

    test('zoomIn/zoomOut: ×/÷1.2, geklemmt 0.3–4; null → Basis 1', () {
      expect(zoomIn(1), closeTo(1.2, 1e-9));
      expect(zoomIn(null), closeTo(1.2, 1e-9));
      expect(zoomIn(3.9), 4);
      expect(zoomOut(1), closeTo(1 / 1.2, 1e-9));
      expect(zoomOut(0.31), 0.3);
    });

    test('pdfZoomPref-Typ-Mix: "fit" ↔ null, Zahl ↔ Faktor', () {
      expect(zoomFromPref('fit'), isNull);
      expect(zoomFromPref(1.44), 1.44);
      expect(zoomFromPref(2), 2.0); // int toleriert
      expect(zoomFromPref(null), isNull);
      expect(zoomToPref(null), 'fit');
      expect(zoomToPref(1.44), 1.44);
    });
  });

  group('PageLayout', () {
    // 3 Seiten à 100×200 Punkte bei Zoom 1.
    final layout = PageLayout.compute(
      const [Size(100, 200), Size(100, 200), Size(100, 200)],
      1,
    );

    test('offsetTop: Padding 14 + Höhen + Gap 14', () {
      expect(layout.topOf(1), 14);
      expect(layout.topOf(2), 14 + 200 + 14);
      expect(layout.topOf(3), 14 + 2 * (200 + 14));
      expect(layout.totalHeight, 14 + 3 * 200 + 2 * 14 + 14);
    });

    test('gotoTarget: offsetTop − 10, min 0', () {
      expect(layout.gotoTarget(1), 4);
      expect(layout.gotoTarget(2), 14 + 214 - 10);
    });

    test('Seitenzahl-Follow: letzte Seite mit Kante über der 35 %-Linie', () {
      // scrollTop 0, Viewport 400 → Linie bei 140 → Seite 1.
      expect(layout.pageAt(0, 400), 1);
      // scrollTop 100 → Linie bei 240 → Seite 2 beginnt bei 228 → Seite 2.
      expect(layout.pageAt(100, 400), 2);
    });

    test('Speicherfreigabe erst ab Abstand > 8', () {
      expect(layout.shouldRelease(10, 1), isTrue);
      expect(layout.shouldRelease(9, 1), isFalse);
      expect(layout.shouldRelease(1, 9), isFalse);
    });

    test('visiblePages: Bereich ± margin·Viewport', () {
      // Viewport 200 hoch, scrollTop 0, margin 1.6 → bis y=520 → Seiten 1-3?
      // Seite 3 beginnt bei 442 < 520 → sichtbar.
      expect(layout.visiblePages(0, 200), [1, 2, 3]);
      // Enges Fenster ohne Margin: nur Seite 1 (+2 ab Kante 228).
      expect(layout.visiblePages(0, 200, margin: 0), [1]);
    });
  });

  test('Original-Konstanten bleiben fixiert', () {
    expect(PeMetrics.gap, 14);
    expect(PeMetrics.padding, 14);
    expect(PeMetrics.fitInset, 26);
    expect(PeMetrics.zoomMin, 0.3);
    expect(PeMetrics.zoomMax, 4);
    expect(PeMetrics.fitMin, 0.35);
    expect(PeMetrics.followFraction, 0.35);
    expect(PeMetrics.releaseDistance, 8);
    expect(PeMetrics.a4, const Size(595, 842));
    expect(PeMetrics.flashDuration, const Duration(milliseconds: 2600));
  });
}
