/// Gemeinsame UI-Bausteine der KI-Schicht: ✓-Check-Box (`.enh-check`),
/// Referenz-Ansicht (`.enh-ref-sum`/`.enh-chips`/`.enh-ref-prev`),
/// Antwort-Textarea (`.enh-answer`), Aktions-Knöpfe (`.enh-act[.magic]`)
/// und der Datenpaket-Strip (`.enh-paket`).
///
/// Maße/Farben aus Dossier 02 (app.css:2076-2160) — Farben ausschließlich
/// über [BookClothTokens].
library;

import 'package:flutter/material.dart';

import '../../../core/richtext/mini_md.dart';
import '../../../core/theme/color_mix.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../flows/ai_flow.dart';

// ---------------------------------------------------------------------------
// RichBit-Rendering
// ---------------------------------------------------------------------------

/// [RichBit]-Liste → Spans (`<b>`-Auszeichnung; Fett-Bits in Ink).
List<InlineSpan> richBitSpans(List<RichBit> bits, {Color? boldColor}) => [
      for (final b in bits)
        TextSpan(
          text: b.text,
          style: b.bold
              ? TextStyle(fontWeight: FontWeight.w700, color: boldColor)
              : null,
        ),
    ];

// ---------------------------------------------------------------------------
// ✓ Format-Check-Box (`.enh-check.ok/.err`, app.css:2145-2151)
// ---------------------------------------------------------------------------

class AiCheckBox extends StatelessWidget {
  const AiCheckBox(this.result, {super.key});

  final AiCheckResult result;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final fg = result.ok ? t.good : t.bad;
    final bg = result.ok ? t.goodSoft : t.badSoft;
    final border = fg.mix(t.border, result.ok ? 40 : 34);
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(children: [
              if (result.ok) const TextSpan(text: '✓ '),
              ...richBitSpans(result.head, boldColor: t.ink),
              if (result.bereit && result.problems.isEmpty)
                const TextSpan(text: ' Bereit für „⭱ Übernehmen“.'),
            ]),
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w500,
              fontSize: 12.5,
              height: 1.5,
              color: fg,
            ),
          ),
          for (final p in result.problems)
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 2),
              child: Text(
                '• $p',
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontFamilyFallback: AppFonts.fallback,
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5,
                  height: 1.5,
                  color: fg,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Referenz-Ansicht (`Enhance._wrap` + Chips/Preview)
// ---------------------------------------------------------------------------

class AiReferenceView extends StatelessWidget {
  const AiReferenceView(this.reference, {super.key});

  final AiReference reference;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // `.enh-ref-sum`: 13.5/1.5 Ink.
        Text.rich(
          TextSpan(children: richBitSpans(reference.summary)),
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: 13.5,
            height: 1.5,
            color: t.ink,
          ),
        ),
        // `.enh-chips`: chip mini mit `--c`-Kategorie-Färbung.
        if (reference.chips.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final chip in reference.chips) _refChip(t, chip),
              ],
            ),
          ),
        if (reference.hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              reference.hint!,
              style: AppTextStyles.small.copyWith(color: t.muted),
            ),
          ),
        // `.enh-ref-prev`: max-height 220, scrollbar, 12.5px.
        if (reference.mdPreview != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MiniMd(
                    reference.mdPreview!,
                    baseStyle: AppTextStyles.small.copyWith(fontSize: 12.5, color: t.ink2),
                  ),
                  if (reference.mdTruncated)
                    Text('…', style: AppTextStyles.small.copyWith(color: t.muted)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _refChip(BookClothTokens t, AiRefChip chip) {
    // `.enh-chips .chip.mini`: --c = Kategorie-Farbe (Fallback muted),
    // Border 45 % zu border, Text 65 % zu ink (app.css:2085).
    final c = (chip.catKey != null ? t.cat(chip.catKey!) : null) ?? t.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.5),
      decoration: BoxDecoration(
        color: t.surface3,
        border: Border.all(color: c.mix(t.border, 45)),
        borderRadius: BorderRadius.circular(BookClothTokens.radiusPill),
      ),
      child: Text(
        chip.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontFamilyFallback: AppFonts.fallback,
          fontWeight: FontWeight.w500,
          fontSize: 10.5,
          height: 1,
          color: c.mix(t.ink, 65),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Antwort-Textarea (`.enh-answer`: Mono 11.5, min-height 150)
// ---------------------------------------------------------------------------

class AiAnswerField extends StatelessWidget {
  const AiAnswerField({
    super.key,
    required this.controller,
    this.placeholder,
    this.onChanged,
    this.readOnly = false,
    this.minLines = 7,
  });

  final TextEditingController controller;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      readOnly: readOnly,
      minLines: minLines,
      maxLines: 16,
      style: TextStyle(
        fontFamily: AppFonts.mono,
        fontFamilyFallback: AppFonts.fallback,
        fontSize: 11.5,
        height: 1.5,
        color: t.ink,
      ),
      decoration: InputDecoration(
        hintText: placeholder ?? 'Antwort hier einfügen …',
        hintStyle: TextStyle(
          fontFamily: AppFonts.mono,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 11.5,
          color: t.muted,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// `.enh-act` — Aktions-Knopf der Werkbank (+ `.magic`-Variante)
// ---------------------------------------------------------------------------

class EnhActButton extends StatefulWidget {
  const EnhActButton({
    super.key,
    required this.child,
    this.onPressed,
    this.tooltip,
    this.magic = false,
    this.magicOff = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final String? tooltip;

  /// `.enh-act.magic`: Block-Stil (magic-top, 2px-Kante, Sockel 0 2 0).
  final bool magic;

  /// `.enh-act.magic.off`: gestrichelt, surface-2, muted (kein Zugang).
  final bool magicOff;

  @override
  State<EnhActButton> createState() => _EnhActButtonState();
}

class _EnhActButtonState extends State<EnhActButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);

    Widget inner;
    if (widget.magic && !widget.magicOff) {
      final down = _pressed && widget.onPressed != null;
      inner = Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        transform: Matrix4.translationValues(0, down ? 2 : 0, 0),
        decoration: BoxDecoration(
          color: t.magicTop,
          border: Border.all(color: t.magicEdge, width: 2),
          borderRadius: BorderRadius.circular(7),
          boxShadow: down
              ? const []
              : [BoxShadow(offset: const Offset(0, 2), color: t.magicEdge)],
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontFamily: AppFonts.magic,
            fontFamilyFallback: AppFonts.magicFallbackChain,
            fontWeight: FontWeight.w500,
            fontSize: 12.5,
            height: 1,
            color: _hover ? Colors.white : BookClothTokens.magicText,
          ),
          child: widget.child,
        ),
      );
    } else if (widget.magic && widget.magicOff) {
      inner = Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: t.surface2,
          border: Border.all(color: t.borderStrong, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(7),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontFamily: AppFonts.magic,
            fontFamilyFallback: AppFonts.magicFallbackChain,
            fontWeight: FontWeight.w500,
            fontSize: 12.5,
            height: 1,
            color: t.muted,
          ),
          child: widget.child,
        ),
      );
    } else {
      inner = Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: _hover ? t.surface3 : t.surface,
          border: Border.all(color: t.borderStrong),
          borderRadius: BorderRadius.circular(9),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontFamilyFallback: AppFonts.fallback,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
            height: 1,
            color: _hover ? t.ink : t.ink2,
          ),
          child: widget.child,
        ),
      );
    }

    Widget result = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = _pressed = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: inner,
      ),
    );
    if (widget.tooltip != null) {
      result = Tooltip(message: widget.tooltip!, child: result);
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Datenpaket-Strip (`.enh-paket`, app.css:2124-2141)
// ---------------------------------------------------------------------------

class AiPaketStrip extends StatelessWidget {
  const AiPaketStrip({super.key, required this.flow});

  final AiFlow flow;

  @override
  Widget build(BuildContext context) {
    final paket = flow.paket;
    if (paket == null) return const SizedBox.shrink();
    final t = BookClothTokens.of(context);
    // `gt = t => /LaTeX/i.test(t)` — LaTeX-Eingaben in Akzent (enhance.js:433).
    bool isGt(String s) => s.toLowerCase().contains('latex');
    return Tooltip(
      message:
          'Das Datenpaket dieser Funktion: genau DIESE Eingaben gehen in den Prompt, genau DORTHIN fließt die Antwort.',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: t.surface2,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Wrap(
          spacing: 5,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Text(
                'PAKET',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontFamilyFallback: AppFonts.fallback,
                  fontWeight: FontWeight.w700,
                  fontSize: 9.5,
                  height: 1,
                  letterSpacing: .09 * 9.5,
                  color: t.muted,
                ),
              ),
            ),
            for (final input in paket.input) _epChip(t, input, gt: isGt(input)),
            _arrow(t),
            _epChip(t, flow.toggle ? 'Heuristik (lokal)' : 'GPT / Claude'),
            _arrow(t),
            _epChip(t, paket.out),
            _arrow(t),
            _epChip(t, paket.ziel, out: true),
          ],
        ),
      ),
    );
  }

  Widget _arrow(BookClothTokens t) => Text(
        '→',
        style: TextStyle(fontSize: 12, height: 1, color: t.muted),
      );

  Widget _epChip(BookClothTokens t, String label, {bool gt = false, bool out = false}) {
    final (Color fg, Color bg, Color border) = gt
        ? (t.accentInk, t.accentSoft, t.accentLine)
        : out
            ? (t.good, t.goodSoft, t.good.mix(t.border, 45))
            : (t.ink2, t.surface, t.borderStrong);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(BookClothTokens.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontFamilyFallback: AppFonts.fallback,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          height: 1.3,
          color: fg,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status-Meldung (`.small.ok/.err/.mut`)
// ---------------------------------------------------------------------------

/// Ton der Import-Meldung neben „⭱ Übernehmen“.
enum AiMsgTone { ok, err, mut }

class AiMsgText extends StatelessWidget {
  const AiMsgText(this.text, this.tone, {super.key});

  final String text;
  final AiMsgTone tone;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final (color, weight) = switch (tone) {
      AiMsgTone.ok => (t.good, FontWeight.w600),
      AiMsgTone.err => (t.bad, FontWeight.w600),
      AiMsgTone.mut => (t.muted, FontWeight.w400),
    };
    return Text(
      text,
      style: AppTextStyles.small.copyWith(color: color, fontWeight: weight),
    );
  }
}
