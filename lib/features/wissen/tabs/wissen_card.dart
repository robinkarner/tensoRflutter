/// Bausteine der Wissen-Welt: [WissenCard] (Card mit blauer 2px-Oberkante),
/// [WissenEyebrow] (Eyebrow in wissen-ink), [AutoGrid] (auto-fit/auto-fill-
/// Grid-Pendant) und [PunktRow] (`.punkt`-Zeilen).
///
/// Farbwelt (app.css:1241-1243): `.wissen-page .card { border-top: 2px solid
/// var(--wissen-line) }`, `.wissen-page .eyebrow { color: var(--wissen-ink) }`.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/eyebrow.dart';

/// `.card` innerhalb `.wissen-page`: surface, Hairline, radius 8,
/// Padding 16/20 (space-4/space-5), shadow-1 — plus die blaue Oberkante.
class WissenCard extends StatelessWidget {
  const WissenCard({super.key, required this.child, this.flat = false});

  final Widget child;

  /// `.card.flat`: ohne Schatten.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(BookClothTokens.radius),
        boxShadow: flat ? null : t.shadow1,
      ),
      foregroundDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.wissenLine, width: 2)),
        borderRadius: BorderRadius.circular(BookClothTokens.radius),
      ),
      child: child,
    );
  }
}

/// Eyebrow der Wissen-Welt (wissen-ink statt muted).
class WissenEyebrow extends StatelessWidget {
  const WissenEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Eyebrow(text, color: BookClothTokens.of(context).wissenInk);
}

/// CSS-Grid-Pendant: `repeat(auto-fit|auto-fill, minmax(minW, 1fr))` mit
/// gleicher Spaltenhöhe je Zeile ist hier bewusst NICHT nachgebaut — die
/// Karten sind selbsthoch (wie `align-items: start`-Verhalten der Seite).
class AutoGrid extends StatelessWidget {
  const AutoGrid({
    super.key,
    required this.minWidth,
    required this.children,
    this.gap = 14,
  });

  final double minWidth;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth.isFinite ? constraints.maxWidth : minWidth;
      final cols =
          ((w + gap) / (minWidth + gap)).floor().clamp(1, children.length);
      final colW = (w - gap * (cols - 1)) / cols;

      final rows = <Widget>[];
      for (var i = 0; i < children.length; i += cols) {
        final slice = children.sublist(
            i, (i + cols) > children.length ? children.length : i + cols);
        rows.add(Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (j, c) in slice.indexed) ...[
                if (j > 0) SizedBox(width: gap),
                SizedBox(width: colW, child: c),
              ],
            ],
          ),
        ));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      );
    });
  }
}

/// `.punkt`-Zeile (app.css:815-817): Icon-Slot + Text, 9px vertikal,
/// Trennlinie zwischen den Zeilen (letzte ohne).
class PunktRow extends StatelessWidget {
  const PunktRow({
    super.key,
    required this.icon,
    required this.child,
    this.last = false,
    this.onTap,
  });

  final Widget icon;
  final Widget child;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: t.border)),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
    if (onTap == null) return row;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
          behavior: HitTestBehavior.opaque, onTap: onTap, child: row),
    );
  }
}
