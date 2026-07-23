/// Erklärbuch-Parser — der reine Datenteil der Notebook-Engine
/// (notebook.js:171-212 + 385-411): Markdown-Segmente + Fenced-Blöcke +
/// `$$…$$`-Display-Mathe, dazu die Tabellen-Zerlegung (CSV/TSV/Pipe/Semikolon)
/// und die Abbildungssuche. Alles UI-frei und direkt testbar.
library;

import '../../../data/models/models.dart';

/// Ein Block des Erklärbuchs: Markdown (`kind == 'md'`) oder Fenced-Code
/// (`kind == 'code'` mit [lang]/[meta]/[body]).
class NbBlock {
  final String kind;
  final String lang;
  final String meta;
  final String body;

  const NbBlock.md(this.body)
      : kind = 'md',
        lang = '',
        meta = '';

  const NbBlock.code({required this.lang, this.meta = '', required this.body})
      : kind = 'code';

  bool get isMd => kind == 'md';
}

final RegExp _fenceOpenRe = RegExp(r'^```(\w+)\s*(.*)$');
final RegExp _fenceCloseRe = RegExp(r'^```\s*$');
final RegExp _mathFenceRe = RegExp(r'^\$\$\s*$');

/// `Notebook.parse` (notebook.js:171-200): Zeilenweise; ``` öffnet einen
/// Code-Block bis zur schließenden ```-Zeile (oder Dateiende); `$$`-Zeilen
/// bilden math-Blöcke; alles andere sammelt sich zu Markdown-Segmenten.
List<NbBlock> parseNotebook(String? src) {
  final blocks = <NbBlock>[];
  final lines = (src ?? '').replaceAll('\r', '').split('\n');
  var md = <String>[];

  void flushMd() {
    if (md.isNotEmpty) {
      blocks.add(NbBlock.md(md.join('\n')));
      md = [];
    }
  }

  for (var i = 0; i < lines.length; i++) {
    final f = _fenceOpenRe.firstMatch(lines[i]);
    if (f != null) {
      final body = <String>[];
      var j = i + 1;
      for (; j < lines.length && !_fenceCloseRe.hasMatch(lines[j]); j++) {
        body.add(lines[j]);
      }
      flushMd();
      blocks.add(NbBlock.code(
        lang: f.group(1)!.toLowerCase(),
        meta: f.group(2)!.trim(),
        body: body.join('\n'),
      ));
      i = j;
      continue;
    }
    if (_mathFenceRe.hasMatch(lines[i])) {
      final body = <String>[];
      var j = i + 1;
      for (; j < lines.length && !_mathFenceRe.hasMatch(lines[j]); j++) {
        body.add(lines[j]);
      }
      flushMd();
      blocks.add(NbBlock.code(lang: 'math', body: body.join('\n')));
      i = j;
      continue;
    }
    md.add(lines[i]);
  }
  flushMd();
  return blocks;
}

// ---------------------------------------------------------------------------
// Tabellen (notebook.js:385-406)
// ---------------------------------------------------------------------------

/// Trennzeilen wie `|---|---|` (Markdown-Tabellen) werden verworfen.
final RegExp _tableSepRe = RegExp(r'^\|?[-:| ]+\|?$');

/// `Notebook.tableBlock`-Zerlegung: Delimiter-Auto `|` > Tab > `;` > `,`,
/// getrimmte Zellen, führende/abschließende Pipes entfernt.
/// Leere Eingabe → null (Aufrufer zeigt „table: leer.“).
List<List<String>>? parseTableRows(String? body) {
  final lines = (body ?? '')
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !_tableSepRe.hasMatch(l))
      .toList();
  if (lines.isEmpty) return null;
  final first = lines.first;
  final delim = first.contains('|')
      ? '|'
      : first.contains('\t')
          ? '\t'
          : first.contains(';')
              ? ';'
              : ',';
  return [
    for (final l in lines)
      l
          .replaceAll(RegExp(r'^\||\|$'), '')
          .split(delim)
          .map((c) => c.trim())
          .toList(),
  ];
}

/// Numerische Spalten (rechtsbündig + Summenfähig): jede Datenzelle leer
/// oder als Zahl lesbar (Komma → Punkt) — notebook.js:395.
List<bool> numericColumns(List<String> head, List<List<String>> data) => [
      for (var ci = 0; ci < head.length; ci++)
        data.isNotEmpty &&
            data.every((r) {
              final c = ci < r.length ? r[ci] : null;
              if (c == null || c.isEmpty) return true;
              return double.tryParse(c.replaceAll(',', '.')) != null;
            }),
    ];

/// Spaltensummen der Σ-Fußzeile (nur numerische Spalten ab Index 1);
/// nicht-summierbare Spalten → null — notebook.js:401.
List<double?> tableSums(
    List<String> head, List<List<String>> data, List<bool> numCol) => [
      for (var ci = 0; ci < head.length; ci++)
        (numCol[ci] && ci > 0)
            ? data.fold<double>(
                0,
                (a, r) =>
                    a +
                    (ci < r.length
                        ? (double.tryParse(r[ci].replaceAll(',', '.')) ?? 0)
                        : 0))
            : null,
    ];

/// Zahl wie `Math.round(sv*100)/100` formatieren (ohne überflüssige Nullen).
String roundedCell(double v) {
  final r = (v * 100).round() / 100;
  return r == r.roundToDouble() ? '${r.round()}' : '$r';
}

// ---------------------------------------------------------------------------
// Abbildungssuche (notebook.js:408-411)
// ---------------------------------------------------------------------------

/// `Notebook.findFigure`: id → Anzeige-Nummer → 1-basierter Index.
Figur? findNotebookFigure(List<Figur> figs, String key) {
  for (final f in figs) {
    if (f.id == key) return f;
  }
  for (final f in figs) {
    if (f.nummer == key) return f;
  }
  if (RegExp(r'^\d+$').hasMatch(key)) {
    final idx = int.parse(key) - 1;
    if (idx >= 0 && idx < figs.length) return figs[idx];
  }
  return null;
}
