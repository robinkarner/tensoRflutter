/// Golden-Test: EditorLogic gegen `js/editor.js` — reconstruct für alle 68
/// Abschnitte, fullDocument, Lint-Meldungen und die Vorschau (als
/// normalisierte Blockform).
///
/// Dokumentierte Abweichungen zum Original:
/// - W9-Fix (E9): `cite` steht in ALLOWED — der Lint-Vergleich normalisiert
///   deshalb den „erlaubt sind: …“-Anhang der Fehlermeldung (die Liste
///   selbst unterscheidet sich bewusst um \cite).
/// - preview() liefert ein strukturiertes Modell statt HTML; verglichen wird
///   die normalisierte Blockform (Text, Block-Grenzen, Fußnoten-Nummern und
///   -Tooltips). Fett/Kursiv-Verschachtelung prüft ein eigener Unit-Test.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/domain/domain.dart';

import 'fixture_util.dart';

/// Fehlermeldungen vergleichbar machen: der „erlaubt sind: …“-Anhang hängt
/// von ALLOWED ab (W9-Fix ergänzt \cite) und wird deshalb abgeschnitten.
String _normalizeErr(String e) =>
    e.replaceAll(RegExp('— erlaubt sind: .*'), '— erlaubt sind: <LISTE>.');

/// Das Vorschau-Modell in dieselbe normalisierte Blockform bringen wie
/// `normalizePreview` im Generator (tools/golden_gen.mjs).
List<String> _normalizeModel(PreviewDocument doc) {
  final lines = <String>[];
  String spans(List<PreviewSpan> ss) {
    final b = StringBuffer();
    for (final s in ss) {
      switch (s) {
        case PreviewTextSpan t:
          b.write(t.text);
        case PreviewFootnoteSpan f:
          b.write('\u27e6fn${f.num}|${f.tooltip}\u27e7');
      }
    }
    return b.toString();
  }

  for (final block in doc.blocks) {
    switch (block) {
      case PreviewHeadingBlock h:
        lines.add('h${h.htmlLevel}|${spans(h.spans)}');
      case PreviewParagraphBlock p:
        lines.add('p|${spans(p.spans)}');
      case PreviewListBlock l:
        lines.add(l.ordered ? 'ol|' : 'ul|');
        for (final it in l.items) {
          lines.add('li|${spans(it)}');
        }
        lines.add('/list|');
      case PreviewPlaceholderBlock ph:
        lines.add('ph|${spans(ph.spans)}');
    }
  }
  return [for (final l in lines) l.trimRight()].where((l) => l.isNotEmpty).toList();
}

void main() {
  final ctx = builtinContext();
  final fix = loadFixtureMap('editor.json');

  test('reconstruct: alle Abschnitte zeichengleich zum JS-Original', () {
    final editor = EditorLogic(ctx, MemoryDomainStore());
    final rec = fix['reconstruct'] as Map<String, dynamic>;
    expect(rec.length, ctx.orderedUnitIds.length);
    for (final e in rec.entries) {
      expect(editor.reconstruct(e.key), e.value, reason: 'Abschnitt ${e.key}');
    }
  });

  test('fullDocument: komplettes Dokument zeichengleich', () {
    final editor = EditorLogic(ctx, MemoryDomainStore());
    expect(editor.fullDocument(), fix['fullDocument']);
  });

  test('lint: Meldungen identisch (erlaubt-Liste normalisiert, W9)', () {
    final editor = EditorLogic(ctx, MemoryDomainStore());
    for (final c in (fix['lint'] as List).cast<Map<String, dynamic>>()) {
      final got = editor.lint(c['tex'] as String);
      expect(
        [for (final e in got.errs) _normalizeErr(e)],
        [for (final e in (c['errs'] as List)) _normalizeErr(e as String)],
        reason: 'errs für: ${c['tex']}',
      );
      expect(got.warns, c['warns'], reason: 'warns für: ${c['tex']}');
    }
  });

  test('W9-Fix: \\cite ist erlaubt (bewusste Abweichung vom Original)', () {
    final editor = EditorLogic(ctx, MemoryDomainStore());
    expect(editor.lint(r'Beleg \cite{kim2023} im Satz.').errs, isEmpty);
    // Das Original hätte hier "Unbekannter/nicht erlaubter Befehl \cite" gemeldet.
  });

  test('preview: normalisierte Blockform identisch zum JS-HTML', () {
    final editor = EditorLogic(ctx, MemoryDomainStore());
    for (final p in (fix['preview'] as List).cast<Map<String, dynamic>>()) {
      final tex = p['id'] == '_synth' ? p['tex'] as String : editor.reconstruct(p['id'] as String);
      final got = _normalizeModel(editor.preview(tex));
      expect(got, (p['blocks'] as List).cast<String>(), reason: 'Vorschau ${p['id']}');
    }
  });

  test('preview: Stil-Flags verschachteln (Modell-Detail ohne JS-Pendant)', () {
    final editor = EditorLogic(ctx, MemoryDomainStore());
    final doc = editor.preview(r'A \textbf{fett \textit{beides}} \emph{kursiv}');
    final para = doc.blocks.single as PreviewParagraphBlock;
    final texts = para.spans.whereType<PreviewTextSpan>().toList();
    expect(texts.firstWhere((t) => t.text.contains('fett ')).bold, isTrue);
    final both = texts.firstWhere((t) => t.text == 'beides');
    expect(both.bold, isTrue);
    expect(both.italic, isTrue);
    expect(texts.firstWhere((t) => t.text == 'kursiv').italic, isTrue);
  });

  test('texEdits: save/clear und Verwendung in fullDocument', () {
    final store = MemoryDomainStore();
    final editor = EditorLogic(ctx, store);
    final first = ctx.orderedUnitIds.first;
    editor.saveEdit(first, '\\section{Ersetzt}\n\nNeuer Text.');
    expect(editor.edits()[first], contains('Ersetzt'));
    expect(editor.fullDocument(), contains('Neuer Text.'));
    editor.clearEdit(first);
    expect(editor.edits(), isEmpty);
    expect(editor.fullDocument(), fix['fullDocument']);
  });

  test('inlineToTex: Original-Fußnotentext, nie der Anzeige-Override', () {
    // Kontext mit fnEdits-Override simulieren: fnOrigTexts trägt Original
    final num = ctx.fnIndex.keys.first;
    final orig = ctx.fnIndex[num]!.text;
    final edited = DomainContext(
      thesis: ctx.thesis,
      unitIndex: ctx.unitIndex,
      fnIndex: {
        for (final e in ctx.fnIndex.entries)
          e.key: e.key == num
              ? FnIndexEntry(
                  num: e.key,
                  text: 'ANZEIGE-OVERRIDE',
                  sources: e.value.sources,
                  sectionId: e.value.sectionId,
                  paragraphId: e.value.paragraphId)
              : e.value,
      },
      sources: ctx.sources,
      orderedUnitIds: ctx.orderedUnitIds,
      sections: ctx.sections,
      meta: ctx.meta,
      fnOrigTexts: {num: orig},
    );
    final editor = EditorLogic(edited, MemoryDomainStore());
    expect(editor.inlineToTex('Text [^$num] Ende'), 'Text \\footnote{$orig} Ende');
    expect(editor.inlineToTex('[^999999]'), '\\footnote{Fußnote 999999}');
  });

  test('Export-Dateinamen wie im Original', () {
    expect(EditorLogic.exportAllName, 'thesis-export.tex');
    expect(EditorLogic.sectionExportName('3.2.1'), 'abschnitt-3_2_1.tex');
  });
}
