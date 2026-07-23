/// Reine Geometrie-/Zoom-Logik des Endlos-Scroll-Viewers — vom Widget
/// getrennt, damit die Original-Konstanten testbar bleiben (Dossier 05 §5):
/// Stack-Gap 14, Scroll-Padding 14, Fit-Abzug 26, Zoom ×/÷1.2 in 0.3–4,
/// fit-Minimum 0.35, Seitenzahl-Follow bei 35 % Viewporthöhe,
/// Speicherfreigabe-Distanz > 8 Seiten, A4-Fallback 595×842.
library;

import 'dart:math';
import 'dart:ui' show Size;

/// Feste Maße des Original-Viewers.
abstract final class PeMetrics {
  /// `.pe-stack { gap: 14px }`.
  static const double gap = 14;

  /// `.pe-scroll { padding: 14px }`.
  static const double padding = 14;

  /// Fit-Zoom-Abzug: `(clientWidth - 26) / baseDim.w` (pdfengine.js:925).
  static const double fitInset = 26;

  /// Zoom-Grenzen der Buttons/Tasten (pdfengine.js:1318-1319).
  static const double zoomMin = 0.3;
  static const double zoomMax = 4;

  /// Zoom-Schritt ×/÷1.2.
  static const double zoomStep = 1.2;

  /// Fit-Minimum (pdfengine.js:925).
  static const double fitMin = 0.35;

  /// Seitenzahl-Follow: Messlinie bei 35 % der Viewporthöhe (js:1053).
  static const double followFraction = 0.35;

  /// Seiten mit Abstand > 8 zur aktuellen werden freigegeben (js:1060).
  static const int releaseDistance = 8;

  /// A4-Fallback, falls Seite 1 nicht lesbar ist (js:913).
  static const Size a4 = Size(595, 842);

  /// Such-Flash-Dauer (js:1027) und Resize-Debounce (js:1303).
  static const Duration flashDuration = Duration(milliseconds: 2600);
  static const Duration resizeDebounce = Duration(milliseconds: 140);

  /// goto scrollt auf `offsetTop - 10` (js:1035).
  static const double gotoOffset = 10;
}

/// Zoom rein (×1.2, max 4) — `zoom || 1` wie das Original.
double zoomIn(double? zoom) => min(PeMetrics.zoomMax, (zoom ?? 1) * PeMetrics.zoomStep);

/// Zoom raus (÷1.2, min 0.3).
double zoomOut(double? zoom) => max(PeMetrics.zoomMin, (zoom ?? 1) / PeMetrics.zoomStep);

/// Fit-Zoom auf Breite: `(clientWidth − 26) / baseW`, min 0.35.
double fitZoom(double clientWidth, double baseWidth) =>
    max(PeMetrics.fitMin, (clientWidth - PeMetrics.fitInset) / baseWidth);

/// Der gespeicherte `pdfZoomPref`-Wert ist ein Typ-Mix: `"fit"` ODER Zahl
/// (Dossier 05 §3). Liefert null für fit (= Fit-Modus), sonst den Faktor.
double? zoomFromPref(Object? pref) => pref is num ? pref.toDouble() : null;

/// Umkehrung: zu persistierender Wert (`z === null ? 'fit' : z`, js:1291).
Object zoomToPref(double? zoom) => zoom ?? 'fit';

/// Seiten-Layout: alle Seitenhöhen bei Zoom 1 → obere Kanten (offsetTop-
/// Pendant) und Gesamthöhe des Stacks bei gegebenem Zoom.
class PageLayout {
  /// Obere Kante jeder Seite (Index 0 = Seite 1), inkl. Scroll-Padding.
  final List<double> tops;

  /// Seitenhöhen in Pixeln (bei diesem Zoom).
  final List<double> heights;

  /// Gesamthöhe inkl. unterem Padding.
  final double totalHeight;

  const PageLayout({required this.tops, required this.heights, required this.totalHeight});

  factory PageLayout.compute(List<Size> pageDims, double zoom) {
    final tops = <double>[];
    final heights = <double>[];
    var y = PeMetrics.padding;
    for (var i = 0; i < pageDims.length; i++) {
      tops.add(y);
      final h = pageDims[i].height * zoom;
      heights.add(h);
      y += h + PeMetrics.gap;
    }
    // Letzter Gap wird durch das untere Padding ersetzt.
    final total = pageDims.isEmpty
        ? 2 * PeMetrics.padding
        : y - PeMetrics.gap + PeMetrics.padding;
    return PageLayout(tops: tops, heights: heights, totalHeight: total);
  }

  int get pageCount => tops.length;

  /// offsetTop einer Seite (1-basiert).
  double topOf(int page) => tops[page - 1];

  /// Scroll-Ziel für `goto(page)`: `offsetTop − 10`, min 0.
  double gotoTarget(int page) => max(0, topOf(page) - PeMetrics.gotoOffset);

  /// Seitenzahl-Follow: letzte Seite mit `offsetTop <= scrollTop + 35 % h`
  /// (pdfengine.js:1053-1057).
  int pageAt(double scrollTop, double viewportHeight) {
    final y = scrollTop + viewportHeight * PeMetrics.followFraction;
    var cur = 1;
    for (var n = 1; n <= pageCount; n++) {
      if (topOf(n) <= y) {
        cur = n;
      } else {
        break;
      }
    }
    return cur;
  }

  /// Seiten im Render-Fenster — Pendant zu IO-rootMargin `160%` bzw.
  /// renderVisible (−1 … +2 Viewporthöhen, js:1011-1017): gerendert wird,
  /// was den Bereich `scrollTop ± margin·viewportHeight` schneidet.
  List<int> visiblePages(double scrollTop, double viewportHeight, {double margin = 1.6}) {
    final y0 = scrollTop - viewportHeight * margin;
    final y1 = scrollTop + viewportHeight * (1 + margin);
    return [
      for (var n = 1; n <= pageCount; n++)
        if (topOf(n) + heights[n - 1] >= y0 && topOf(n) <= y1) n,
    ];
  }

  /// Freizugebende Seiten: Abstand > 8 zur aktuellen (js:1059-1063).
  bool shouldRelease(int page, int currentPage) =>
      (page - currentPage).abs() > PeMetrics.releaseDistance;
}
