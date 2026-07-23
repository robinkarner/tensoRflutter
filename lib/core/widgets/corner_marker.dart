import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Kubischer Eck-Marker — Kern der visuellen Sprache.
///
/// Die Arbeits-Panels (Kapitelbaum, Quellen-Spalte, Datei-Karten) tragen
/// oben links ein kleines QUADRAT in Akzentfarbe (app.css:227/445:
/// `::before` 8×8px bei top/left −1px). Die Konvention: QUADRATISCH =
/// Struktur/Datei — im Gegensatz zu den RUNDEN Belegstatus-Punkten.
/// Datei-Karten mit vorhandener Datei nutzen die good-Variante.
class CornerMarker extends StatelessWidget {
  const CornerMarker({super.key, this.color, this.size = 8});

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: ColoredBox(color: color ?? t.accent),
    );
  }
}

/// Hüllt [child] in einen Stack und setzt den Eck-Marker auf (−1,−1) —
/// exakt über die Panel-Border, wie das `::before` des Originals.
class CornerMarked extends StatelessWidget {
  const CornerMarked({
    super.key,
    required this.child,
    this.color,
    this.size = 8,
  });

  final Widget child;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -1,
          left: -1,
          child: CornerMarker(color: color, size: size),
        ),
      ],
    );
  }
}
