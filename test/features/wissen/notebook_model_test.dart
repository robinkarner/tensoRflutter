/// Parser-Tests der Notebook-Engine (K-1): Block-Zerlegung, Tabellen-
/// Delimiter-Kaskade, Σ-Summen, Abbildungssuche — Verhalten exakt wie
/// notebook.js:171-211 / 385-411.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/data/models/models.dart';
import 'package:thesor/features/wissen/math/math_render.dart';
import 'package:thesor/features/wissen/notebook/notebook_model.dart';
import 'package:thesor/features/wissen/notebook/notebook_state.dart';

void main() {
  group('parseNotebook', () {
    test('Markdown + Fences + \$\$-Mathe in Blockfolge', () {
      final blocks = parseNotebook('''
# Titel

Absatz eins.

```chart
{"type":"bar"}
```

\$\$
\\bar{x}
\$\$

```js auto
print(1)
```

Schluss.
''');
      // Leerzeilen zwischen Fences werden — wie im Original — zu leeren
      // md-Segmenten (flushMd flusht jede nicht-leere Zeilenliste).
      expect(blocks.map((b) => b.isMd ? 'md' : b.lang).toList(),
          ['md', 'chart', 'md', 'math', 'md', 'js', 'md']);
      // Fence-Meta wird getrimmt übernommen.
      expect(blocks[5].meta, 'auto');
      expect(blocks[1].body, '{"type":"bar"}');
      expect(blocks[3].body, '\\bar{x}');
      // Markdown-Segmente behalten ihre Zeilen.
      expect(blocks[0].body, contains('# Titel'));
      expect(blocks[0].body, contains('Absatz eins.'));
    });

    test('unbeendeter Fence läuft bis Dateiende (kein Absturz)', () {
      final blocks = parseNotebook('```py\nx = 1\ny = 2');
      expect(blocks.single.lang, 'py');
      expect(blocks.single.body, 'x = 1\ny = 2');
    });

    test('Starter-Buch zerlegt sich in die dokumentierte Blockfolge', () {
      final blocks = parseNotebook(notebookStarter('Testarbeit'));
      final kinds = blocks.map((b) => b.isMd ? 'md' : b.lang).toList();
      expect(kinds, [
        'md', 'js', 'md', 'js', 'md', 'js', 'md', 'math', 'md', 'js',
        'md', 'latex', 'md', 'py', 'md',
      ]);
      expect(blocks.first.body, contains('# Erklärbuch — Testarbeit'));
      // Titel wird auf 60 Zeichen gekürzt.
      final long = notebookStarter('x' * 80);
      expect(parseNotebook(long).first.body, contains('x' * 60));
      expect(parseNotebook(long).first.body, isNot(contains('x' * 61)));
    });
  });

  group('parseTableRows', () {
    test('Delimiter-Kaskade: | > Tab > ; > ,', () {
      expect(parseTableRows('a|b\n1|2'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
      expect(parseTableRows('a\tb\n1\t2'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
      expect(parseTableRows('a;b\n1;2'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
      expect(parseTableRows('a,b\n1,2'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });

    test('Markdown-Trennzeilen und Rand-Pipes verschwinden', () {
      expect(parseTableRows('| a | b |\n|---|---|\n| 1 | 2 |'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });

    test('leer → null (Aufrufer zeigt „table: leer.“)', () {
      expect(parseTableRows(''), isNull);
      expect(parseTableRows('  \n \n'), isNull);
    });
  });

  group('numericColumns + tableSums', () {
    test('Zahlspalten (Komma toleriert), Summen nur ab Spalte 1', () {
      final head = ['Quelle', 'Typ', 'Zitierstellen'];
      final data = [
        ['EHDS-VO', 'recht-eu', '107'],
        ['DSGVO', 'recht-eu', '33,5'],
      ];
      final numCol = numericColumns(head, data);
      expect(numCol, [false, false, true]);
      final sums = tableSums(head, data, numCol);
      expect(sums, [null, null, 140.5]);
      expect(roundedCell(140.5), '140.5');
      expect(roundedCell(140.0), '140');
    });
  });

  group('findNotebookFigure', () {
    final figs = [
      Figur.fromJson(const {'id': 'abb-a', 'nummer': 'Abb. 1'}),
      Figur.fromJson(const {'id': 'abb-b', 'nummer': 'Abb. 2'}),
    ];

    test('id → Nummer → 1-basierter Index', () {
      expect(findNotebookFigure(figs, 'abb-b')!.id, 'abb-b');
      expect(findNotebookFigure(figs, 'Abb. 1')!.id, 'abb-a');
      expect(findNotebookFigure(figs, '2')!.id, 'abb-b');
      expect(findNotebookFigure(figs, '9'), isNull);
      expect(findNotebookFigure(figs, 'nix'), isNull);
    });
  });

  group('mathSanitize', () {
    test('Subset bleibt, Unbekanntes wird gesammelt und entfernt', () {
      final ok = mathSanitize(r'\frac{1}{n} \sum_{i=1}^{n} x_i');
      expect(ok.unknown, isEmpty);
      expect(ok.tex, r'\frac{1}{n} \sum_{i=1}^{n} x_i');

      final bad = mathSanitize(r'\frac{a}{b} \foo{x} + \xcancel{y}');
      expect(bad.unknown, ['foo', 'xcancel']);
      expect(bad.tex, isNot(contains(r'\foo')));
      expect(bad.tex, contains(r'\frac{a}{b}'));
    });
  });
}
