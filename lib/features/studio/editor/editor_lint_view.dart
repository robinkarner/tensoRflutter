/// Prüfbericht des Editors (`.tex-lint`, editor.js:223-227): Fehler-Kopf
/// „✗ LaTeX-Code nicht kompilierbar …“, je Fehler „· {msg}“; ohne Fehler die
/// grüne ✓-Zeile; Hinweise als „⚠ {msg}“ — Texte wörtlich, Farben aus den
/// Tokens (err = bad, warn = warn, ok = good).
library;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/editor_logic.dart';

class EditorLintView extends StatelessWidget {
  const EditorLintView({super.key, required this.result});

  final LintResult result;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final style = AppTextStyles.small.copyWith(fontSize: 12.5, height: 1.6);

    final lines = <Widget>[];
    if (result.errs.isNotEmpty) {
      lines.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '✗ LaTeX-Code nicht kompilierbar — Ausgabe des Prüfers:',
          style: style.copyWith(color: t.bad, fontWeight: FontWeight.w700),
        ),
      ));
      for (final e in result.errs) {
        lines.add(Text('· $e', style: style.copyWith(color: t.bad)));
      }
    } else {
      lines.add(Text(
        '✓ Kompilierbar: nur erlaubte Befehle, Klammern und Umgebungen balanciert.',
        style: style.copyWith(color: t.good),
      ));
    }
    for (final w in result.warns) {
      lines.add(Text('⚠ $w', style: style.copyWith(color: t.warn)));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines,
      ),
    );
  }
}
