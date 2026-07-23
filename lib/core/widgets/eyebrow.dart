import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// `.eyebrow` — die kleine Display-Überzeile in Großbuchstaben.
///
/// Standard (theme.css:316): 600 12/1.3 Space Grotesk, tracking .09em, muted.
/// Leisten-Variante ([Eyebrow.bar], z. B. `.sf-bar-lbl`/Tab-Gruppen):
/// 700 10px — für Kopfzeilen von Spalten und Docks.
/// Farbe übersteuerbar (Wissen-Welt setzt wissen-ink).
class Eyebrow extends StatelessWidget {
  const Eyebrow(
    this.text, {
    super.key,
    this.color,
  })  : _size = 12,
        _weight = FontWeight.w600;

  /// Kompakte Leisten-Variante: 700 10px.
  const Eyebrow.bar(
    this.text, {
    super.key,
    this.color,
  })  : _size = 10,
        _weight = FontWeight.w700;

  final String text;
  final Color? color;
  final double _size;
  final FontWeight _weight;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: AppFonts.display,
        fontFamilyFallback: AppFonts.fallback,
        fontWeight: _weight,
        fontSize: _size,
        height: 1.3,
        letterSpacing: .09 * _size,
        color: color ?? t.muted,
      ),
    );
  }
}
