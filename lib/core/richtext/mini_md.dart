/// Mini-Markdown — Port von `U.md` (util.js:16-43) als Widget-Renderer.
///
/// Regeln exakt wie im Original: `#`–`####` → Überschriften (Level + 1!),
/// `` `code` ``, `**fett**`, `*kursiv*`, `[Text](https?:…)` → Link,
/// `- `/`* ` → ungeordnete Liste, `1. ` → geordnete Liste, `> ` → Blockquote,
/// Leerzeile trennt Absätze, aufeinanderfolgende Zeilen verbinden sich mit
/// Leerzeichen zu EINEM Absatz. (HTML-Escaping entfällt — Flutter rendert
/// Text, kein HTML.)
///
/// Konsumenten: Instanz-/View-Inhalte (lesen-inst, para-side, S-3),
/// Dossiers, Erklärbuch-Markdown-Blöcke (K-1).
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../theme/tokens.dart';
import '../theme/typography.dart';

// ---------------------------------------------------------------------------
// Inline-Parsing (`code`, **strong**, *em*, [Link](https?:…))
// ---------------------------------------------------------------------------

final RegExp _inlineToken = RegExp(
    r'`([^`]+)`|\*\*([^*]+)\*\*|\*([^*\n]+)\*|\[([^\]]+)\]\((https?:[^)]+)\)');

/// Inline-Markdown → Spans. [recognizers] sammelt die Link-Recognizer,
/// damit der aufrufende State sie entsorgen kann.
List<InlineSpan> miniMdInline(
  String text, {
  required BookClothTokens tokens,
  List<GestureRecognizer>? recognizers,
}) {
  final spans = <InlineSpan>[];
  var pos = 0;
  for (final m in _inlineToken.allMatches(text)) {
    if (m.start > pos) spans.add(TextSpan(text: text.substring(pos, m.start)));
    if (m.group(1) != null) {
      // `code` — Mono auf surface-3 (theme.css code-Stil).
      spans.add(TextSpan(
        text: m.group(1),
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 12.5,
          backgroundColor: tokens.surface3,
        ),
      ));
    } else if (m.group(2) != null) {
      spans.add(TextSpan(
          text: m.group(2),
          style: const TextStyle(fontWeight: FontWeight.w700)));
    } else if (m.group(3) != null) {
      spans.add(TextSpan(
          text: m.group(3), style: const TextStyle(fontStyle: FontStyle.italic)));
    } else {
      final url = m.group(5)!;
      final rec = TapGestureRecognizer()
        ..onTap = () => launcher.launchUrl(Uri.parse(url),
            mode: launcher.LaunchMode.externalApplication);
      recognizers?.add(rec);
      spans.add(TextSpan(
        text: m.group(4),
        style: TextStyle(color: tokens.accentInk),
        recognizer: rec,
      ));
    }
    pos = m.end;
  }
  if (pos < text.length) spans.add(TextSpan(text: text.substring(pos)));
  return spans;
}

// ---------------------------------------------------------------------------
// Block-Renderer
// ---------------------------------------------------------------------------

/// Markdown-Block als Widget-Spalte — der `<div class="md">`-Ersatz.
/// [baseStyle] bestimmt Schrift/Farbe des Fließtexts (Aufrufer-Kontext).
class MiniMd extends StatefulWidget {
  const MiniMd(this.source, {super.key, this.baseStyle});

  final String source;
  final TextStyle? baseStyle;

  @override
  State<MiniMd> createState() => _MiniMdState();
}

class _MiniMdState extends State<MiniMd> {
  final List<GestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final t = BookClothTokens.of(context);
    final base = widget.baseStyle ??
        AppTextStyles.body.copyWith(color: t.ink2, fontSize: 13.5, height: 1.65);

    Text inline(String s, [TextStyle? style]) => Text.rich(
          TextSpan(
            style: style ?? base,
            children: miniMdInline(s, tokens: t, recognizers: _recognizers),
          ),
        );

    final blocks = <Widget>[];
    final para = <String>[];
    var listKind = ''; // '' | 'ul' | 'ol'
    var listIndex = 0;

    void flushPara() {
      if (para.isEmpty) return;
      blocks.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: inline(para.join(' ')),
      ));
      para.clear();
    }

    void flushList() {
      listKind = '';
      listIndex = 0;
    }

    void addListItem(String text, {required bool ordered}) {
      flushPara();
      final kind = ordered ? 'ol' : 'ul';
      if (listKind != kind) {
        flushList();
        listKind = kind;
      }
      listIndex++;
      blocks.add(Padding(
        padding: const EdgeInsets.only(left: 14, bottom: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 18,
              child: Text(ordered ? '$listIndex.' : '•', style: base),
            ),
            Expanded(child: inline(text)),
          ],
        ),
      ));
    }

    final headingRe = RegExp(r'^(#{1,4})\s+(.*)');
    final ulRe = RegExp(r'^[-*]\s+(.*)');
    final olRe = RegExp(r'^\d+\.\s+(.*)');
    final bqRe = RegExp(r'^>\s?(.*)');

    for (final raw in widget.source.replaceAll('\r', '').split('\n')) {
      final l = raw.trim();
      final h = headingRe.firstMatch(l);
      if (h != null) {
        flushPara();
        flushList();
        // `#` wird <h2>, `##` <h3> … (Level + 1 wie im Original).
        final level = h.group(1)!.length + 1;
        final style = switch (level) {
          2 => AppTextStyles.h2.copyWith(color: t.ink),
          3 => AppTextStyles.h3.copyWith(color: t.ink),
          _ => AppTextStyles.h4.copyWith(color: t.ink),
        };
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: inline(h.group(2)!, style),
        ));
        continue;
      }
      final li = ulRe.firstMatch(l);
      if (li != null) {
        addListItem(li.group(1)!, ordered: false);
        continue;
      }
      final oli = olRe.firstMatch(l);
      if (oli != null) {
        addListItem(oli.group(1)!, ordered: true);
        continue;
      }
      final bq = bqRe.firstMatch(l);
      if (bq != null) {
        flushPara();
        flushList();
        blocks.add(Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: t.accentLine, width: 3)),
          ),
          child: inline(bq.group(1)!,
              base.copyWith(color: t.muted, fontStyle: FontStyle.italic)),
        ));
        continue;
      }
      if (l.isEmpty) {
        flushPara();
        flushList();
        continue;
      }
      para.add(l);
    }
    flushPara();
    flushList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }
}
