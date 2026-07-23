/// MathRender — das LaTeX-Mathe-Subset des Erklärbuchs (notebook.js:27-151).
///
/// Das Original stapelt HTML-sup/sub selbst; in Flutter übernimmt
/// `flutter_math_fork` das echte TeX-Layout (Dossier-06-Hinweis 4: der
/// 1:1-Nachbau der HTML-Stapelung wäre schlechter als das Original-Ziel).
/// Beibehaltene Original-Signatur: Befehle AUSSERHALB des dokumentierten
/// Subsets werfen nicht, sondern erscheinen als ⚠-Chip mit Tooltip
/// „\cmd nicht unterstützt“ (kein stiller Ausfall, notebook.js:53); der
/// Rest der Formel rendert weiter. Auch echte Parse-Fehler des
/// TeX-Layouters enden im ⚠-Chip.
///
/// Optik: `.mth` läuft im Serif-Duktus (1.06em inline); `.mth-block`
/// zentriert bei 1.22em — der `.nb-math`-Rahmen (surface-2, Hairline)
/// liegt beim Block-Renderer des Notebooks.
library;

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';

/// Das dokumentierte Befehls-Subset (GREEK + SYM + BIGOPS + Strukturbefehle,
/// notebook.js:28-45 + 93-135). Nur Buchstaben-Befehle — `\,`/`\;`/`\\` und
/// maskierte Sonderzeichen prüft der Scanner nicht (immer erlaubt).
const Set<String> kMathKnownCommands = {
  // GREEK
  'alpha', 'beta', 'gamma', 'delta', 'epsilon', 'varepsilon', 'zeta', 'eta',
  'theta', 'iota', 'kappa', 'lambda', 'mu', 'nu', 'xi', 'pi', 'rho',
  'sigma', 'tau', 'upsilon', 'phi', 'varphi', 'chi', 'psi', 'omega',
  'Gamma', 'Delta', 'Theta', 'Lambda', 'Xi', 'Pi', 'Sigma', 'Upsilon',
  'Phi', 'Psi', 'Omega',
  // SYM
  'cdot', 'times', 'div', 'pm', 'mp', 'leq', 'le', 'geq', 'ge',
  'neq', 'ne', 'approx', 'sim', 'simeq', 'equiv', 'propto', 'infty',
  'rightarrow', 'to', 'leftarrow', 'Rightarrow', 'Leftarrow',
  'leftrightarrow', 'mapsto', 'in', 'notin', 'subset', 'subseteq',
  'cup', 'cap', 'forall', 'exists', 'partial', 'nabla', 'ldots', 'dots',
  'cdots', 'prime', 'circ', 'degree', 'ast', 'star', 'langle', 'rangle',
  'emptyset', 'mid', 'vert', 'quad', 'qquad',
  // BIGOPS
  'sum', 'prod', 'int', 'oint', 'bigcup', 'bigcap', 'lim', 'max', 'min',
  'argmax', 'argmin',
  // Struktur
  'frac', 'dfrac', 'tfrac', 'sqrt', 'text', 'mathrm', 'operatorname',
  'mathbb', 'mathbf', 'bm', 'mathcal', 'mathit', 'bar', 'overline',
  'hat', 'vec', 'left', 'right',
};

final RegExp _cmdRe = RegExp(r'\\([a-zA-Z]+)');

/// Scannt [tex] auf Befehle außerhalb des Subsets. Liefert den bereinigten
/// TeX-String (unbekannte Befehle entfernt — ihre Argument-Gruppen bleiben
/// als harmlose `{…}`-Gruppen stehen) plus die Liste der unbekannten Befehle.
({String tex, List<String> unknown}) mathSanitize(String tex) {
  final unknown = <String>[];
  final cleaned = tex.replaceAllMapped(_cmdRe, (m) {
    final cmd = m.group(1)!;
    if (kMathKnownCommands.contains(cmd)) return m.group(0)!;
    unknown.add(cmd);
    return '';
  });
  return (tex: cleaned, unknown: unknown);
}

/// `⚠`-Chip mit Tooltip (`.mth-err`: warn-Farbe, cursor help).
class MathErrChip extends StatelessWidget {
  const MathErrChip(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Tooltip(
      message: message,
      child: MouseRegion(
        cursor: SystemMouseCursors.help,
        child: Text(
          '⚠',
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontFamilyFallback: AppFonts.fallback,
            color: t.warn,
            fontSize: 14,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Gemeinsamer Kern: TeX säubern, layouten, ⚠-Chips anhängen.
class _MathTex extends StatelessWidget {
  const _MathTex(this.tex, {required this.display, required this.fontSize});

  final String tex;
  final bool display;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final source = tex.trim();
    final res = mathSanitize(source);

    final math = Math.tex(
      res.tex,
      mathStyle: display ? MathStyle.display : MathStyle.text,
      textStyle: TextStyle(fontSize: fontSize, color: t.ink),
      onErrorFallback: (err) => MathErrChip(err.message),
    );

    if (res.unknown.isEmpty) return math;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        math,
        for (final cmd in res.unknown) MathErrChip('\\$cmd nicht unterstützt'),
      ],
    );
  }
}

/// `MathRender.inline` — `$…$` im Fließtext (`.mth`, 1.06em der Umgebung).
class MathInline extends StatelessWidget {
  const MathInline(this.tex, {super.key, this.baseFontSize = 15});

  final String tex;
  final double baseFontSize;

  @override
  Widget build(BuildContext context) =>
      _MathTex(tex, display: false, fontSize: baseFontSize * 1.06);
}

/// `MathRender.block` — Display-Formel (`.mth-block`: zentriert, 1.22em);
/// horizontal scrollbar wie `overflow-x: auto`.
class MathBlockView extends StatelessWidget {
  const MathBlockView(this.tex, {super.key, this.baseFontSize = 15});

  final String tex;
  final double baseFontSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _MathTex(tex, display: true, fontSize: baseFontSize * 1.22),
        ),
      ),
    );
  }
}
