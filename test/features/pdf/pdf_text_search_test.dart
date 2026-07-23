/// Volltextsuche: lazy Seitentext-Cache, zirkuläre Suche ab der NÄCHSTEN
/// Seite, Mindestlänge 2, Trefferseiten-Zählung nur aus dem Cache
/// („{k}+ Seiten") — Port-Parität zu pdfengine.js:1068-1108.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/features/pdf/search/pdf_text_search.dart';

void main() {
  PdfTextSearch build(List<String> pages, List<int> loads) => PdfTextSearch(
        pageCount: pages.length,
        loadPageText: (n) async {
          loads.add(n);
          return pages[n - 1];
        },
      );

  test('sucht ab der NÄCHSTEN Seite, zirkulär', () async {
    final loads = <int>[];
    final s = build(['Treffer hier', 'nichts', 'auch nichts'], loads);
    // Aktuelle Seite 1 → Suche beginnt bei 2, findet zirkulär auf 1.
    final r = await s.next('treffer', 1);
    expect(r!.page, 1);
    expect(loads, [2, 3, 1]); // lazy, in Suchreihenfolge
    expect(r.info, 'S. 1');
  });

  test('Cache: zweite Suche lädt keine Seiten nach', () async {
    final loads = <int>[];
    final s = build(['abc', 'Wort hier', 'Wort dort'], loads);
    // Von Seite 3 aus: lädt 1 (kein Treffer) und 2 (Treffer).
    await s.next('wort', 3);
    expect(loads, [1, 2]);
    loads.clear();
    // Von Seite 1 aus: Seite 2 kommt aus dem Cache.
    final r = await s.next('wort', 1);
    expect(r!.page, 2);
    expect(loads, isEmpty);
  });

  test('Trefferseiten-Zählung nur aus dem bisherigen Cache', () async {
    final s = build(['x', 'Wort', 'Wort', 'Wort'], []);
    // Von Seite 1: findet Seite 2; Cache kennt da nur Seite 2 → 'S. 2'.
    final r1 = await s.next('wort', 1);
    expect(r1!.info, 'S. 2');
    // Von Seite 2: findet Seite 3; Cache kennt 2+3 → '2+ Seiten'.
    final r2 = await s.next('wort', 2);
    expect(r2!.info, 'S. 3 · 2+ Seiten');
  });

  test('unter 2 Zeichen: keine Suche', () async {
    final loads = <int>[];
    final s = build(['a', 'b'], loads);
    expect(await s.next('a', 1), isNull);
    expect(loads, isEmpty);
  });

  test('kein Treffer → null; Fehler beim Laden zählen als leer', () async {
    final s = PdfTextSearch(
      pageCount: 2,
      loadPageText: (n) async => n == 1 ? throw StateError('kaputt') : 'ok',
    );
    expect(await s.next('fehlt', 1), isNull);
    expect(s.cache[1], ''); // Fehler → leerer Cache-Eintrag
  });

  test('Suche ist case-insensitiv (lowercase-Cache)', () async {
    final s = build(['GROSS geschrieben'], []);
    final r = await s.next('gross', 1);
    expect(r!.page, 1);
  });
}
