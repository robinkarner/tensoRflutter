/// `.card`-Baustein der Projekt-Seite (theme.css:306-312): surface,
/// Hairline, radius 8, Padding 16 / clamp(18..26), Schatten Stufe 1.
/// Die Karten des Dashboards beginnen alle mit einer [Eyebrow]-Überzeile.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/eyebrow.dart';

class ProjektCard extends StatelessWidget {
  const ProjektCard({
    super.key,
    required this.eyebrow,
    required this.children,
    this.eyebrowTrailing,
  });

  /// Text der `.eyebrow`-Überzeile.
  final String eyebrow;

  /// Inhalt rechts neben der Überzeile (`.row.spread`, z. B. Zähler+Knopf).
  final Widget? eyebrowTrailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(BookClothTokens.radius),
        boxShadow: t.shadow1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (eyebrowTrailing == null)
            Align(alignment: Alignment.centerLeft, child: Eyebrow(eyebrow))
          else
            Row(children: [
              Expanded(child: Eyebrow(eyebrow)),
              eyebrowTrailing!,
            ]),
          ...children,
        ],
      ),
    );
  }
}
