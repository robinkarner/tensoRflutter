/// Markierungs-Modell: JSON-Passthrough (Migrations-Garantie — unbekannte
/// Felder überleben jede Lese-Schreib-Runde), tolerante Getter, Hit-Test
/// und die Levels-Verdrahtung über PdfMarkLevelInput.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/data/models/models.dart';
import 'package:thesor/domain/domain.dart';
import 'package:thesor/features/pdf/marks/pdf_mark.dart';

/// Original-Mark aus dem Dossier-Beispiel (05 §3) — Datenform-Vertrag.
Map<String, Object?> _webAppMark() => {
      'id': 'mlxq3f8abc',
      'ts': 1753257600000,
      'fn': 42,
      'page': 15,
      'farbe': 'blau',
      'zitat': 'Der ausgewählte Text …',
      'rects': [
        {'x': 0.1523, 'y': 0.3311, 'w': 0.68, 'h': 0.0182},
      ],
      'comment': {'x': 0.94, 'y': 0.3261, 'text': '[42] Beleg-Label'},
      // Unbekanntes Zukunftsfeld — muss den Roundtrip überleben.
      'zukunft': {'x': 1},
    };

void main() {
  test('bestehende Web-App-Marks werden 1:1 gelesen', () {
    final m = PdfMark(_webAppMark());
    expect(m.id, 'mlxq3f8abc');
    expect(m.fn, 42);
    expect(m.page, 15);
    expect(m.farbe, 'blau');
    expect(m.zitat, 'Der ausgewählte Text …');
    expect(m.rects, hasLength(1));
    expect(m.rects.first.x, 0.1523);
    expect(m.comment!.x, 0.94);
    expect(m.comment!.text, '[42] Beleg-Label');
  });

  test('patched(): flaches Mischen, unbekannte Felder bleiben erhalten', () {
    final m = PdfMark(_webAppMark());
    final p = m.patched({'comment': null});
    expect(p.comment, isNull);
    expect(p.json['zukunft'], {'x': 1}); // Migrations-Garantie
    expect(p.json['zitat'], 'Der ausgewählte Text …');
  });

  test('tolerante Typen: fn als String, fehlende Felder', () {
    final m = PdfMark(const {'fn': '42', 'page': 3, 'rects': [], 'farbe': null});
    expect(m.fn, 42);
    expect(m.farbe, isNull);
    expect(m.comment, isNull);
    expect(m.zitat, '');
    // Freier Kommentar-Pin: fn null.
    expect(PdfMark(const {'fn': null, 'page': 1}).fn, isNull);
  });

  test('hitTest: Punkt-in-Rect über alle Flächen', () {
    final m = PdfMark(_webAppMark());
    expect(m.hitTest(0.2, 0.34), isTrue);
    expect(m.hitTest(0.2, 0.5), isFalse);
    expect(m.hitTest(0.1523, 0.3311), isTrue); // Kante inklusive
  });

  test('Levels-Kaskade: Markierung mit Zitat+Seite ⇒ Stufe 3 (Seite)', () {
    // Minimaler Kontext: 1 Quelle (artikel → positionType 'seite'),
    // 1 Fußnote 42 auf diese Quelle.
    final thesis = Thesis.fromJson({
      'meta': {'title': 'T'},
      'chapters': [
        {
          'id': 'ch3', 'num': 3, 'title': 'K',
          'sections': [
            {
              'id': '3.1', 'title': 'A', 'level': 2,
              'paragraphs': [
                {
                  'id': '3_1-p1', 'type': 'text', 'text': 'X',
                  'footnotes': [
                    {'num': 42, 'text': 'Fn', 'sources': ['kraus2025']},
                  ],
                }
              ],
            }
          ],
        }
      ],
    });
    final ctx = DomainContext.build(
      thesis: thesis,
      sources: [
        Source.fromJson({'id': 'kraus2025', 'kind': 'artikel', 'title': 'K'}),
      ],
    );

    final mark = PdfMark(_webAppMark());
    List<PdfMarkLevelInput> marksForFn(String srcId, int fn) => [
          if (srcId == 'kraus2025' && mark.fn == fn)
            PdfMarkLevelInput(
              zitat: mark.json['zitat'] is String ? mark.zitat : null,
              page: mark.json['page'],
              farbe: mark.farbe,
            ),
        ];

    final levels = Levels(ctx, MemoryDomainStore(), marksForFn: marksForFn);
    final info = levels.info(42);
    expect(info.level, 3); // Zitat + Seite bei positionType 'seite'
    expect(info.zitat, 'Der ausgewählte Text …');
    expect(info.seite, 15);
    expect(info.herkunft, 'markierung');
    expect(info.farbe, 'blau');
    expect(info.derived, isTrue);
  });

  test('Levels-Kaskade: ohne marksForFn (S-1 nicht verdrahtet) bleibt es bei 0',
      () {
    final thesis = Thesis.fromJson({
      'meta': {'title': 'T'},
      'chapters': [
        {
          'id': 'ch3', 'num': 3, 'title': 'K',
          'sections': [
            {
              'id': '3.1', 'title': 'A', 'level': 2,
              'paragraphs': [
                {
                  'id': '3_1-p1', 'type': 'text', 'text': 'X',
                  'footnotes': [
                    {'num': 42, 'text': 'Fn', 'sources': ['kraus2025']},
                  ],
                }
              ],
            }
          ],
        }
      ],
    });
    final ctx = DomainContext.build(
      thesis: thesis,
      sources: [
        Source.fromJson({'id': 'kraus2025', 'kind': 'artikel', 'title': 'K'}),
      ],
    );
    expect(Levels(ctx, MemoryDomainStore()).info(42).level, 0);
  });
}
