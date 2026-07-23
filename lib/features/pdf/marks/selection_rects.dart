/// Text-Selektion → normalisierte Markierungs-Rechtecke.
///
/// Ersatz für die Browser-Selektion des Originals (pdfengine.js:1196-1229):
/// dort liefert `getRangeAt(0).getClientRects()` zeilenweise Rechtecke, die
/// auf 0..1 normalisiert werden (Ursprung oben links, max 40, Mini-Rects
/// < 2 px gefiltert, seitenübergreifende Auswahl auf die Ankerseite
/// beschnitten). Hier kommen die Rechtecke aus den pdfrx-Zeichenboxen
/// (PDF-Koordinaten, Ursprung UNTEN links) — [normRectFromPdf] dreht die
/// y-Achse; [rectsForRange] gruppiert Zeichen fragment-weise zu Zeilen-
/// Rechtecken. Der Ankerseiten-Beschnitt ist konstruktiv erledigt: Gesten
/// laufen pro Seite, eine Auswahl KANN keine fremde Seite enthalten.
library;

import 'dart:math';

import 'package:pdfrx/pdfrx.dart';

import 'pdf_mark.dart';

/// Obergrenze der Auswahl-Rechtecke (pdfengine.js:1213).
const int kMaxSelectionRects = 40;

/// Mindestgröße eines Rechtecks in Bildschirm-Pixeln (js:1209).
const double kMinRectPx = 2;

/// PDF-Rechteck (Ursprung unten links) → normalisiertes Mark-Rechteck
/// (0..1, Ursprung oben links) für eine Seite der Größe [pageW]×[pageH]
/// (in PDF-Punkten).
MarkRect normRectFromPdf(PdfRect r, double pageW, double pageH) => MarkRect(
      x: r.left / pageW,
      y: (pageH - r.top) / pageH,
      w: r.width / pageW,
      h: r.height / pageH,
    );

/// Zeichenindex zu einem Punkt in normalisierten Seitenkoordinaten
/// (0..1, oben links). Trifft der Punkt keine Zeichenbox direkt, gewinnt
/// das nächstgelegene Zeichen (Zeilenabstand dominiert, wie eine Browser-
/// Selektion den nächsten Einfügepunkt wählt). null bei leerer Seite.
int? charIndexAt(PdfPageText text, double pageW, double pageH, double nx, double ny) {
  if (text.charRects.isEmpty) return null;
  final px = nx * pageW;
  final py = (1 - ny) * pageH; // zurück in PDF-Koordinaten (y nach oben)
  int? best;
  double bestScore = double.infinity;
  for (var i = 0; i < text.charRects.length; i++) {
    final r = text.charRects[i];
    if (r.isEmpty) continue;
    if (px >= r.left && px <= r.right && py >= r.bottom && py <= r.top) return i;
    // Abstand: vertikal (Zeile) stark gewichtet, horizontal schwach.
    final cy = (r.top + r.bottom) / 2;
    final dy = (py - cy).abs();
    final dx = px < r.left ? r.left - px : (px > r.right ? px - r.right : 0.0);
    final score = dy * 4 + dx;
    if (score < bestScore) {
      bestScore = score;
      best = i;
    }
  }
  return best;
}

/// Auswahl-Ergebnis: whitespace-normalisierter Text + Zeilen-Rechtecke.
class SelectionCapture {
  final String text;
  final List<MarkRect> rects;

  const SelectionCapture({required this.text, required this.rects});
}

/// Zeichenbereich [a]..[b] (inklusive, beliebige Reihenfolge) →
/// Markierungs-Rechtecke + Text. Fragmente sind pdfrx-Zeilensegmente:
/// pro Fragment wird der überdeckte Zeichenbereich zu EINEM Rechteck
/// vereinigt (Pendant zu den zeilenweisen ClientRects des Browsers).
///
/// [zoom] dient dem Mini-Rect-Filter: Rechtecke unter 2 Bildschirm-Pixeln
/// Breite/Höhe fliegen raus (js:1209). Maximal [kMaxSelectionRects].
SelectionCapture? captureRange(
  PdfPageText text,
  double pageW,
  double pageH,
  int a,
  int b, {
  double zoom = 1,
}) {
  if (text.fullText.isEmpty) return null;
  final start = min(a, b).clamp(0, text.fullText.length - 1);
  final end = max(a, b).clamp(0, text.fullText.length - 1);

  // Text wie das Original: `\s+` → ' ', trim, mindestens 2 Zeichen.
  final raw = text.fullText.substring(start, end + 1);
  final norm = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (norm.length < 2) return null;

  final rects = <MarkRect>[];
  for (final frag in text.fragments) {
    if (frag.end <= start || frag.index > end) continue;
    final from = max(frag.index, start);
    final to = min(frag.end - 1, end);
    PdfRect? bounds;
    for (var i = from; i <= to; i++) {
      final r = text.charRects[i];
      if (r.isEmpty) continue;
      bounds = bounds == null
          ? r
          : PdfRect(
              min(bounds.left, r.left),
              max(bounds.top, r.top),
              max(bounds.right, r.right),
              min(bounds.bottom, r.bottom),
            );
    }
    if (bounds == null) continue;
    if (bounds.width * zoom <= kMinRectPx || bounds.height * zoom <= kMinRectPx) {
      continue; // Mini-Rects (Umbruchsartefakte) filtern
    }
    rects.add(normRectFromPdf(bounds, pageW, pageH));
    if (rects.length >= kMaxSelectionRects) break;
  }
  if (rects.isEmpty) return null;
  return SelectionCapture(text: norm, rects: rects);
}
