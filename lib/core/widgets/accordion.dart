import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// details/summary-Pendant mit ▸-Caret-Rotation.
///
/// Das Original nutzt native `<details>`-Akkordeons in zwei Ausprägungen:
///  * `details.acc` (app.css:816–822): surface, radius-sm, Kopf 600 13.5,
///    Padding 11/14, Body 2/16/14 — Wissen/Analyse-Karten.
///  * `details.libd-sec` (app.css:776–787): surface-2, radius 8, Kopf 600 13,
///    Padding 10/13, Body auf surface mit border-top — Quellen-Detailpanel.
///
/// Wie im Web klappt der Inhalt OHNE Größenanimation um; nur der Caret dreht
/// sich (.13–.15s) — das ist die originale Interaktionssignatur.
enum AccordionVariant { acc, section }

class Accordion extends StatefulWidget {
  const Accordion({
    super.key,
    required this.title,
    required this.body,
    this.variant = AccordionVariant.acc,
    this.initiallyOpen = false,
    this.onChanged,
    this.trailing,
  });

  /// Kopfzeileninhalt (meist [Text]; Stil kommt von hier).
  final Widget title;
  final Widget body;
  final AccordionVariant variant;
  final bool initiallyOpen;
  final ValueChanged<bool>? onChanged;

  /// Optionaler Inhalt rechts in der Kopfzeile (Zähler-Chips u. ä.).
  final Widget? trailing;

  @override
  State<Accordion> createState() => _AccordionState();
}

class _AccordionState extends State<Accordion> {
  late bool _open = widget.initiallyOpen;

  void _toggle() {
    setState(() => _open = !_open);
    widget.onChanged?.call(_open);
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final section = widget.variant == AccordionVariant.section;

    final header = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: Padding(
          padding: section
              ? const EdgeInsets.symmetric(horizontal: 13, vertical: 10)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              AnimatedRotation(
                turns: _open ? .25 : 0,
                duration: Duration(milliseconds: section ? 130 : 150),
                child: Text(
                  '▸',
                  style: TextStyle(
                    color: t.muted,
                    fontSize: section ? 10 : 11,
                    height: 1,
                    fontFamilyFallback: AppFonts.fallback,
                  ),
                ),
              ),
              SizedBox(width: section ? 8 : 9),
              Expanded(
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontWeight: FontWeight.w600,
                    fontSize: section ? 13 : 13.5,
                    height: 1.3,
                    color: t.ink,
                  ),
                  child: widget.title,
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
      ),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: section ? t.surface2 : t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(
            section ? BookClothTokens.radius : BookClothTokens.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          if (_open)
            section
                ? Container(
                    decoration: BoxDecoration(
                      color: t.surface,
                      border: Border(top: BorderSide(color: t.border)),
                    ),
                    padding: const EdgeInsets.fromLTRB(13, 6, 13, 13),
                    child: widget.body,
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
                    child: widget.body,
                  ),
        ],
      ),
    );
  }
}
