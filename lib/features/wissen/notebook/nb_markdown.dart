/// Markdown-Segmente des Erklärbuchs (`.nb-md`) — flutter_markdown_plus mit
/// Inline-Mathe-Interception.
///
/// Das Original schleust `$…$`-Formeln VOR `U.md` über Platzhalter aus und
/// setzt sie danach wieder ein (`Notebook._mdWithMath`, notebook.js:203-212).
/// Hier übernimmt eine eigene [md.InlineSyntax] denselben Regex
/// (`\$([^$\n]+)\$`) und ein Element-Builder rendert [MathInline] — die
/// Interception bleibt, nur der Mechanismus ist idiomatisch.
///
/// Optik `.nb-md` (app.css:1427): 15px/1.75, volle Breite; Links in
/// accent-ink; `code` mono auf surface-3; Blockquote mit accent-line.
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../math/math_render.dart';

/// `$…$` → `<nbmath>`-Inline-Element (Regex exakt notebook.js:205).
class NbMathSyntax extends md.InlineSyntax {
  NbMathSyntax() : super(r'\$([^$\n]+)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('nbmath', match.group(1)!));
    return true;
  }
}

class _NbMathBuilder extends MarkdownElementBuilder {
  _NbMathBuilder(this.baseFontSize);

  final double baseFontSize;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) =>
      MathInline(element.textContent, baseFontSize: baseFontSize);
}

class NbMarkdown extends StatelessWidget {
  const NbMarkdown(this.source, {super.key, this.baseFontSize = 15});

  final String source;
  final double baseFontSize;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final base = TextStyle(
      fontFamily: AppFonts.ui,
      fontFamilyFallback: AppFonts.fallback,
      fontSize: baseFontSize,
      height: 1.75,
      color: t.ink,
    );

    return MarkdownBody(
      data: source,
      selectable: false,
      inlineSyntaxes: [NbMathSyntax()],
      builders: {'nbmath': _NbMathBuilder(baseFontSize)},
      onTapLink: (text, href, title) {
        if (href == null) return;
        launcher.launchUrl(Uri.parse(href),
            mode: launcher.LaunchMode.externalApplication);
      },
      styleSheet: MarkdownStyleSheet(
        p: base,
        h1: AppTextStyles.h2.copyWith(color: t.ink),
        h2: AppTextStyles.h2
            .copyWith(color: t.ink, fontSize: AppFontSizes.h3 + 1),
        h3: AppTextStyles.h3.copyWith(color: t.ink),
        h4: AppTextStyles.h4.copyWith(color: t.ink),
        h5: AppTextStyles.h4.copyWith(color: t.ink, fontSize: 15),
        h6: AppTextStyles.h4.copyWith(color: t.ink, fontSize: 14),
        a: TextStyle(color: t.accentInk),
        em: const TextStyle(fontStyle: FontStyle.italic),
        strong: const TextStyle(fontWeight: FontWeight.w700),
        listBullet: base,
        blockquotePadding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: t.accentLine, width: 3)),
        ),
        code: TextStyle(
          fontFamily: AppFonts.mono,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: baseFontSize * .86,
          backgroundColor: t.surface3,
          color: t.ink,
        ),
        codeblockDecoration: BoxDecoration(
          color: t.surface2,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.border)),
        ),
        tableBorder: TableBorder.all(color: t.border),
        tableHead: AppTextStyles.small.copyWith(
          fontWeight: FontWeight.w600,
          color: t.ink2,
        ),
        tableBody: AppTextStyles.small.copyWith(color: t.ink),
      ),
    );
  }
}
