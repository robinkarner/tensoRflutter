/// `Notebook.render` — das gerenderte Erklärbuch (notebook.js:215-265).
///
/// `.nb-doc`: max-width 900, zentriert; 14px Abstand zwischen den Blöcken.
/// JEDER Block wird einzeln gegen Fehler abgeschirmt — ein kaputter Block
/// wird zur Fehlerkarte „Block ({lang}) nicht darstellbar: {msg}“, das
/// Dokument bricht nie ganz ab (notebook.js:218-222).
///
/// Blocktypen (EXAKTE Syntax, Dossier 06 §7):
///  * md          → [NbMarkdown] (inkl. `$…$`-Inline-Mathe)
///  * math / $$   → `.nb-math` (surface-2, Hairline) + [MathBlockView]
///  * latex       → `.nb-latex` — DERSELBE Interpreter wie die Arbeit
///                  (`EditorLogic.preview`/`lint` + [TexPreview]); Lint-
///                  Fehler als „✗ LaTeX-Code nicht kompilierbar …“ (max 4)
///  * chart       → [NbChart] (JSON-Fehler → Hinweiskarte)
///  * table       → [NbTable] (Delimiter-Auto, Σ-Fußzeile bei `sum`)
///  * figure      → [FigureCard] über id | Nummer | 1-basierten Index
///  * include     → Blockquote mit max. 12 Absätzen im Lesen-Stil
///  * js / py     → [NbCell] (E4: rendern statt ausführen)
///  * unbekannt   → `pre.cmd.nb-pre` (max-height 320, Scroll)
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/richtext/richtext_builder.dart';
import '../../../core/router/routes.dart';
import '../../../core/shell/footnote_modal.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/models/models.dart';
import '../../pdf/figures/figure_card.dart';
import '../../studio/editor/editor_preview.dart';
import '../../studio/layout/rich_resolver.dart';
import '../../studio/layout/studio_state.dart';
import '../charts/chart_spec.dart';
import '../charts/nb_chart.dart';
import '../math/math_render.dart';
import 'nb_cell.dart';
import 'nb_markdown.dart';
import 'notebook_model.dart';

class NotebookDoc extends ConsumerWidget {
  const NotebookDoc(this.src, {super.key, this.maxWidth = 900});

  final String src;

  /// `.nb-doc { max-width: 900px }` — der Editor-Split rendert schmaler.
  final double? maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = parseNotebook(src);
    final children = <Widget>[];
    for (final b in blocks) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _GuardedBlock(block: b),
      ));
    }

    final doc = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    if (maxWidth == null) return doc;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: doc,
      ),
    );
  }
}

/// Fehler-Schutzschicht je Block: Build-Fehler enden in der Fehlerkarte
/// statt im roten Flutter-Error-Screen.
class _GuardedBlock extends StatelessWidget {
  const _GuardedBlock({required this.block});

  final NbBlock block;

  @override
  Widget build(BuildContext context) {
    try {
      return _NbBlockView(block: block);
    } catch (e) {
      return NbBlockError(
          'Block (${block.isMd ? 'md' : block.lang}) nicht darstellbar: $e');
    }
  }
}

/// `.notice.small`-Hinweiskarte der Blockfehler.
class NbBlockError extends StatelessWidget {
  const NbBlockError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
      decoration: BoxDecoration(
        color: t.surface2,
        border: Border(
          left: BorderSide(color: t.warn, width: 3),
          top: BorderSide(color: t.border),
          right: BorderSide(color: t.border),
          bottom: BorderSide(color: t.border),
        ),
      ),
      child: Text(message,
          style: AppTextStyles.small.copyWith(fontSize: 12.5, color: t.ink2)),
    );
  }
}

class _NbBlockView extends ConsumerWidget {
  const _NbBlockView({required this.block});

  final NbBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final b = block;
    if (b.isMd) return NbMarkdown(b.body);

    switch (b.lang) {
      case 'math':
        // `.nb-math`: surface-2-Fläche mit Hairline (app.css:1459).
        return Container(
          decoration: BoxDecoration(
            color: t.surface2,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
          ),
          child: MathBlockView(b.body),
        );

      case 'latex':
        return _LatexBlock(tex: b.body);

      case 'chart':
        Map<String, dynamic> spec;
        try {
          final decoded = jsonDecode(b.body);
          if (decoded is! Map) throw const FormatException('kein Objekt');
          spec = decoded.map((k, v) => MapEntry('$k', v));
        } catch (e) {
          return NbBlockError('chart: JSON ungültig — $e');
        }
        return NbChart(NbChartSpec.fromJson(spec));

      case 'table':
        return NbTable(body: b.body, meta: b.meta);

      case 'figure':
        final key = (b.meta.isNotEmpty ? b.meta : b.body).trim();
        final figs = ref.watch(activeRuntimeProvider)?.figures.figuren ??
            const <Figur>[];
        final f = findNotebookFigure(figs, key);
        if (f == null) {
          final ids = figs.map((x) => x.id).join(', ');
          return NbBlockError(
              'figure: „$key“ nicht gefunden — verfügbar: ${ids.isNotEmpty ? ids : 'keine'}');
        }
        return FigureCard(
          f,
          onQuelleTap: (srcId) => context.go(Routes.quellenPath(srcId)),
        );

      case 'include':
        return _IncludeBlock(sectionId: (b.meta.isNotEmpty ? b.meta : b.body).trim());

      case 'js':
        return NbCell(lang: 'js', body: b.body);
      case 'py':
      case 'python':
        return NbCell(lang: 'py', body: b.body);

      default:
        // `pre.cmd.nb-pre` — unbekannte Sprache als roher Code.
        return Container(
          constraints: const BoxConstraints(maxHeight: 320),
          decoration: BoxDecoration(
            color: t.surface2,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                b.body,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontFamilyFallback: AppFonts.fallback,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  height: 1.7,
                  color: t.ink,
                ),
              ),
            ),
          ),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// latex-Block — GLEICHER Interpreter wie die Arbeit (notebook.js:229-236)
// ---------------------------------------------------------------------------

class _LatexBlock extends ConsumerWidget {
  const _LatexBlock({required this.tex});

  final String tex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(studioDomainProvider);
    if (domain == null) return const SizedBox.shrink();

    final doc = domain.editor.preview(tex);
    final lint = domain.editor.lint(tex);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
        border: Border.all(color: t.border),
      ),
      foregroundDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: t.accentLine, width: 3)),
        borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TexPreview(document: doc),
          if (lint.errs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✗ LaTeX-Code nicht kompilierbar — Ausgabe des Prüfers:',
                    style: AppTextStyles.small.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: t.bad,
                    ),
                  ),
                  for (final e in lint.errs.take(4))
                    Text('· $e',
                        style: AppTextStyles.small
                            .copyWith(fontSize: 12.5, color: t.bad)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// table-Block (notebook.js:385-406)
// ---------------------------------------------------------------------------

class NbTable extends StatelessWidget {
  const NbTable({super.key, this.body, this.meta = '', this.rows});

  final String? body;
  final String meta;

  /// Direkte Zeilen (Zellen-API `table(rows, opts)` — hier für Tests).
  final List<List<String>>? rows;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final parsed = rows ?? parseTableRows(body);
    // tableBlock: leere Eingabe → „leer.“; tableFrom ohne Zeilen → „keine Zeilen.“
    if (parsed == null) return const NbBlockError('table: leer.');
    if (parsed.isEmpty) return const NbBlockError('table: keine Zeilen.');

    final head = parsed.first;
    final data = parsed.skip(1).toList();
    final numCol = numericColumns(head, data);
    final sum = RegExp(r'\bsum\b').hasMatch(meta);
    final sums = sum ? tableSums(head, data, numCol) : null;

    TextStyle cellStyle({bool headRow = false, bool bold = false}) => TextStyle(
          fontFamily: headRow ? AppFonts.display : AppFonts.ui,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: headRow ? 11 : 14,
          height: headRow ? 1.3 : 1.5,
          letterSpacing: headRow ? .08 * 11 : 0,
          fontWeight: headRow || bold ? FontWeight.w600 : FontWeight.w400,
          color: headRow ? t.muted : t.ink,
        );

    Widget cell(String text, int ci,
        {bool headRow = false, bool bold = false}) {
      return Padding(
        padding: headRow
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 7)
            : const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          headRow ? text.toUpperCase() : text,
          textAlign: !headRow && numCol[ci] ? TextAlign.right : TextAlign.left,
          style: cellStyle(headRow: headRow, bold: bold).copyWith(
            fontFeatures:
                !headRow && numCol[ci] ? const [FontFeature.tabularFigures()] : null,
          ),
        ),
      );
    }

    TableRow tr(List<Widget> cells, {BoxDecoration? deco}) =>
        TableRow(decoration: deco, children: cells);

    List<Widget> rowCells(List<String> r, {bool bold = false}) => [
          for (var ci = 0; ci < head.length; ci++)
            cell(ci < r.length ? r[ci] : '', ci, bold: bold),
        ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 300),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            tr(
              [for (var ci = 0; ci < head.length; ci++) cell(head[ci], ci, headRow: true)],
              deco: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.borderStrong)),
              ),
            ),
            for (final (i, r) in data.indexed)
              tr(
                rowCells(r),
                deco: i == data.length - 1 && sums == null
                    ? null
                    : BoxDecoration(
                        border: Border(bottom: BorderSide(color: t.border)),
                      ),
              ),
            if (sums != null)
              tr([
                for (var ci = 0; ci < head.length; ci++)
                  ci == 0
                      ? cell('Σ', ci, bold: true)
                      : cell(sums[ci] == null ? '' : roundedCell(sums[ci]!), ci,
                          bold: true),
              ]),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// include-Block (notebook.js:249-258)
// ---------------------------------------------------------------------------

class _IncludeBlock extends ConsumerWidget {
  const _IncludeBlock({required this.sectionId});

  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final entry = ref.watch(unitIndexProvider)[sectionId];
    if (entry == null) {
      return NbBlockError('include: Abschnitt „$sectionId“ existiert nicht.');
    }
    final domain = ref.watch(studioDomainProvider);
    final resolver = richResolverFor(domain);

    // `.lesen-p` im include: Serif 14.5.
    final lesenStyle = TextStyle(
      fontFamily: AppFonts.serif,
      fontFamilyFallback: AppFonts.fallback,
      fontSize: 14.5,
      height: 1.78,
      color: t.ink,
    );

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('AUS DER ARBEIT — ',
                style: AppTextStyles.eyebrow.copyWith(color: t.wissenInk)),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => context.go(Routes.studioPath(sec: sectionId)),
                child: Text('ABSCHNITT $sectionId',
                    style: AppTextStyles.eyebrow.copyWith(
                      color: t.accentInk,
                      decoration: TextDecoration.underline,
                    )),
              ),
            ),
          ],
        ),
      ),
    ];

    for (final p in entry.unit.paragraphs.take(12)) {
      if (p.typeEnum == ParagraphType.list) {
        children.add(Padding(
          padding: const EdgeInsets.only(left: 24, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final it in p.items)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('•  ', style: lesenStyle),
                  Expanded(
                    child: RichTextView(
                      it,
                      style: lesenStyle,
                      options: const RichTextOptions(fnStyle: FnStyle.mini),
                      resolver: resolver,
                      callbacks: RichTextCallbacks(
                        onFnTap: (fn) => showFootnoteModal(context, fn),
                      ),
                    ),
                  ),
                ]),
            ],
          ),
        ));
      } else if (p.typeEnum == ParagraphType.text) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RichTextView(
            p.text,
            style: lesenStyle,
            options: const RichTextOptions(fnStyle: FnStyle.mini),
            resolver: resolver,
            callbacks: RichTextCallbacks(
              onFnTap: (fn) => showFootnoteModal(context, fn),
            ),
          ),
        ));
      }
    }

    // blockquote.nb-include: cat-norm-Leiste links, surface-2.
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: t.surface2,
        border: Border(left: BorderSide(color: t.catNorm, width: 3)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(BookClothTokens.radiusSm),
          bottomRight: Radius.circular(BookClothTokens.radiusSm),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
