/// Live-Vorschau des Editors — rendert das [PreviewDocument] aus
/// `EditorLogic.preview` als Widgets (Pendant zum HTML der Original-
/// `Editor.preview`, editor.js:100-129, Optik `.tex-preview` app.css:858-860):
/// Überschriften h2/h3/h4, Fließtext-Absätze im Literatur-Satz (`.lesen-p.ff`),
/// Listen, `%`-Platzhalter-Kacheln und hochgestellte Fußnoten-Nummern mit
/// Tooltip (`.pv-fn`).
library;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/editor_logic.dart';

class TexPreview extends StatelessWidget {
  const TexPreview({super.key, required this.document});

  final PreviewDocument document;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);

    final children = <Widget>[];
    for (final block in document.blocks) {
      switch (block) {
        case PreviewHeadingBlock():
          children.add(Padding(
            padding: EdgeInsets.only(
                top: children.isEmpty ? 0 : 14, bottom: 6),
            child: Text.rich(
              TextSpan(children: _spans(context, t, block.spans)),
              style: switch (block.htmlLevel) {
                2 => AppTextStyles.h2.copyWith(color: t.ink),
                3 => AppTextStyles.h3.copyWith(color: t.ink),
                _ => AppTextStyles.h4.copyWith(color: t.ink),
              },
            ),
          ));
        case PreviewParagraphBlock():
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text.rich(
              TextSpan(children: _spans(context, t, block.spans)),
              style: _bodyStyle(t),
            ),
          ));
        case PreviewListBlock():
          var i = 0;
          for (final item in block.items) {
            i++;
            children.add(Padding(
              padding: const EdgeInsets.only(left: 18, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(block.ordered ? '$i. ' : '•  ', style: _bodyStyle(t)),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: _spans(context, t, item)),
                      style: _bodyStyle(t),
                    ),
                  ),
                ],
              ),
            ));
          }
          children.add(const SizedBox(height: 6));
        case PreviewPlaceholderBlock():
          // `%`-Zeile → `.fig-missing.small`-Kachel mit „Platzhalter“-Eyebrow.
          children.add(Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
            decoration: BoxDecoration(
              color: t.surface2,
              border: Border.all(color: t.borderStrong),
              borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PLATZHALTER',
                    style: AppTextStyles.eyebrow.copyWith(color: t.muted)),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(children: _spans(context, t, block.spans)),
                  style: AppTextStyles.small.copyWith(color: t.ink2),
                ),
              ],
            ),
          ));
      }
    }

    if (children.isEmpty) {
      children.add(Text('— leer —',
          style: AppTextStyles.small.copyWith(color: t.muted)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  /// `.tex-preview`: 14.5px/1.7 — Fließtext im Serif-Satz (`.lesen-p.ff`).
  TextStyle _bodyStyle(BookClothTokens t) => TextStyle(
        fontFamily: AppFonts.serif,
        fontFamilyFallback: AppFonts.fallback,
        fontSize: 14.5,
        height: 1.7,
        color: t.ink,
      );

  List<InlineSpan> _spans(
      BuildContext context, BookClothTokens t, List<PreviewSpan> spans) {
    final out = <InlineSpan>[];
    for (final s in spans) {
      switch (s) {
        case PreviewTextSpan():
          out.add(TextSpan(
            text: s.text,
            style: TextStyle(
              fontWeight: s.bold ? FontWeight.w700 : null,
              fontStyle: s.italic ? FontStyle.italic : null,
            ),
          ));
        case PreviewFootnoteSpan():
          // `<sup class="pv-fn" title="…">n</sup>`
          out.add(WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: Tooltip(
              message: s.tooltip.isEmpty ? 'Fußnote ${s.num}' : s.tooltip,
              child: Text(
                '${s.num}',
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: 10.5,
                  height: 1,
                  color: t.accentInk,
                ),
              ),
            ),
          ));
      }
    }
    return out;
  }
}
