/// Selektion → normalisierte Rects: y-Achsen-Drehung (PDF unten-links →
/// Marks oben-links), fragmentweise Zeilen-Rechtecke, `\s+`-Normalisierung,
/// Mindestlänge 2, Mini-Rect-Filter (2 px) und die 40er-Obergrenze.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:thesor/features/pdf/marks/selection_rects.dart';

/// Baut ein PdfPageText mit zirkulären Fragment-Referenzen.
PdfPageText _pageText(
  String fullText,
  List<PdfRect> charRects,
  List<(int index, int length)> fragSpec,
) {
  final fragments = <PdfPageTextFragment>[];
  final pt = PdfPageText(
    pageNumber: 1,
    fullText: fullText,
    charRects: charRects,
    fragments: fragments,
  );
  for (final (index, length) in fragSpec) {
    fragments.add(PdfPageTextFragment(
      pageText: pt,
      index: index,
      length: length,
      bounds: charRects
          .sublist(index, index + length)
          .reduce((a, b) => PdfRect(
                a.left < b.left ? a.left : b.left,
                a.top > b.top ? a.top : b.top,
                a.right > b.right ? a.right : b.right,
                a.bottom < b.bottom ? a.bottom : b.bottom,
              )),
      charRects: charRects.sublist(index, index + length),
      direction: PdfTextDirection.ltr,
    ));
  }
  return pt;
}

void main() {
  // Seite 100×200 Punkte; „Ab cd": Zeile 1 oben (y 180-190),
  // Zeile 2 weiter unten (y 80-90).
  final pt = _pageText(
    'Ab cd',
    const [
      PdfRect(10, 190, 20, 180), // A
      PdfRect(20, 190, 30, 180), // b
      PdfRect(30, 190, 32, 180), // ' '
      PdfRect(40, 90, 50, 80), // c
      PdfRect(50, 90, 60, 80), // d
    ],
    const [(0, 3), (3, 2)],
  );

  test('normRectFromPdf dreht die y-Achse (Ursprung oben links)', () {
    final r = normRectFromPdf(const PdfRect(10, 190, 20, 180), 100, 200);
    expect(r.x, closeTo(.1, 1e-9));
    expect(r.y, closeTo((200 - 190) / 200, 1e-9));
    expect(r.w, closeTo(.1, 1e-9));
    expect(r.h, closeTo(10 / 200, 1e-9));
  });

  test('captureRange: ein Zeilen-Rechteck je Fragment, Reihenfolge egal', () {
    final cap = captureRange(pt, 100, 200, 4, 0)!; // b < a erlaubt
    expect(cap.text, 'Ab cd');
    expect(cap.rects, hasLength(2));
    // Zeile 1: Chars 0..2 → (10..32, 180..190).
    expect(cap.rects[0].x, closeTo(.1, 1e-9));
    expect(cap.rects[0].y, closeTo(.05, 1e-9));
    expect(cap.rects[0].w, closeTo(.22, 1e-9));
    // Zeile 2 liegt UNTER Zeile 1 (größeres y).
    expect(cap.rects[1].y, greaterThan(cap.rects[0].y));
  });

  test('Whitespace wird zu einfachen Leerzeichen normalisiert', () {
    final multi = _pageText(
      'A\n  B',
      const [
        PdfRect(10, 190, 20, 180),
        PdfRect(20, 190, 21, 180),
        PdfRect(21, 190, 22, 180),
        PdfRect(22, 190, 23, 180),
        PdfRect(30, 190, 40, 180),
      ],
      const [(0, 5)],
    );
    expect(captureRange(multi, 100, 200, 0, 4)!.text, 'A B');
  });

  test('unter 2 Zeichen → null (js:1206)', () {
    expect(captureRange(pt, 100, 200, 0, 0), isNull);
  });

  test('Mini-Rects (< 2 px bei aktuellem Zoom) werden gefiltert', () {
    // Nur das 2-Punkte-breite Leerzeichen-Fragment auswählen: bei Zoom .5
    // ist es 1 px breit → gefiltert → keine Rects → null.
    final spaceOnly = _pageText(
      'ab',
      const [PdfRect(30, 190, 32, 180), PdfRect(32, 190, 34, 180)],
      const [(0, 2)],
    );
    expect(captureRange(spaceOnly, 100, 200, 0, 1, zoom: .4), isNull);
    expect(captureRange(spaceOnly, 100, 200, 0, 1, zoom: 10), isNotNull);
  });

  test('höchstens 40 Rechtecke (js:1213)', () {
    final rects = [
      for (var i = 0; i < 50; i++)
        PdfRect(i * 10.0, 500 - i * 10.0, i * 10.0 + 8, 500 - i * 10.0 - 8),
    ];
    final many = _pageText(
      List.filled(50, 'x').join(),
      rects,
      [for (var i = 0; i < 50; i++) (i, 1)],
    );
    final cap = captureRange(many, 1000, 1000, 0, 49)!;
    expect(cap.rects, hasLength(kMaxSelectionRects));
  });

  group('charIndexAt', () {
    test('Punkt in der Zeichenbox → Index', () {
      expect(charIndexAt(pt, 100, 200, .15, .075), 0); // in 'A'
      expect(charIndexAt(pt, 100, 200, .45, .575), 3); // in 'c'
    });

    test('daneben → nächstes Zeichen derselben Zeile gewinnt', () {
      // Rechts neben Zeile 1: nächstes ist das Zeilenende (Index 2).
      expect(charIndexAt(pt, 100, 200, .9, .06), 2);
    });

    test('leere Seite → null', () {
      final empty = _pageText('', const [], const []);
      expect(charIndexAt(empty, 100, 200, .5, .5), isNull);
    });
  });
}
