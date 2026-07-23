/// js-/py-Rechenzellen des Erklärbuchs (`.nb-cell`, notebook.js:458-567) —
/// nach E4: **rendern, nicht ausführen**.
///
/// `new Function` (js) und Pyodide vom CDN (py) sind nicht portierbar
/// (Master §7 Risiko 3). Der UI-Rahmen bleibt originalgetreu erhalten
/// (Sprachen-Badge, ▶-Knopf, ⌄/⌃-Code-Toggle, py-Status-Slot); statt der
/// Ausgabe steht im Output-Bereich ein dezenter Hinweis. Abweichung zur
/// Web-App: Der Code ist hier von Anfang an SICHTBAR (im Original initial
/// `hidden`) — ohne Ausführung ist der Code der Inhalt der Zelle.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/color_mix.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';

class NbCell extends StatefulWidget {
  const NbCell({super.key, required this.lang, required this.body});

  /// 'js' | 'py' (python-Fence läuft als py).
  final String lang;
  final String body;

  @override
  State<NbCell> createState() => _NbCellState();
}

class _NbCellState extends State<NbCell> {
  /// E4-Abweichung: Code startet sichtbar (Original: `hidden`).
  bool _codeVisible = true;

  bool get _isPy => widget.lang != 'js';

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);

    // `.nb-lang`: mono 700 10.5 uppercase; js accent-getönt, py in cat-norm
    // auf 12%-Mix (app.css:1447-1448).
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: _isPy ? t.catNorm.alphaPct(12) : t.accentSoft,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _isPy ? 'PY' : 'JS',
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontFamilyFallback: AppFonts.fallback,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
          height: 1,
          letterSpacing: .06 * 10.5,
          color: _isPy ? t.catNorm : t.accentInk,
        ),
      ),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(BookClothTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kopfzeile `.nb-cell-h`.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: t.surface2,
              border: Border(bottom: BorderSide(color: t.border)),
            ),
            child: Row(children: [
              badge,
              const SizedBox(width: 8),
              // ▶ bleibt sichtbar, ist aber ohne Laufzeit deaktiviert (E4).
              AppButton(
                small: true,
                onPressed: null,
                tooltip: 'Ausführung in dieser Version nicht verfügbar',
                child: const Text('▶ ausführen'),
              ),
              const SizedBox(width: 8),
              AppButton(
                small: true,
                variant: AppButtonVariant.ghost,
                tooltip: 'Code ein-/ausblenden',
                onPressed: () => setState(() => _codeVisible = !_codeVisible),
                child: Text(_codeVisible ? '⌃ Code' : '⌄ Code'),
              ),
            ]),
          ),
          // Code (`pre.cmd.nb-code`: mono 12/1.7, max-height 300, Scroll).
          if (_codeVisible)
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: t.surface2,
                border: Border(bottom: BorderSide(color: t.border)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    widget.body,
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontFamilyFallback: AppFonts.fallback,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      height: 1.7,
                      color: t.ink,
                    ),
                  ),
                ),
              ),
            ),
          // Output-Bereich `.nb-cell-out` — der dezente E4-Hinweis.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Text(
              'Ausführung in dieser Version nicht verfügbar',
              style: AppTextStyles.small.copyWith(
                fontSize: 12.5,
                color: t.muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
