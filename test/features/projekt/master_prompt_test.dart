/// Zeichengenauigkeits-Tests des Master-Prompts (views_projekt.js:493-563)
/// und des Anhang-Trenners (views_projekt.js:297).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/features/projekt/arbeiten/master_prompt.dart';

void main() {
  test('masterPrompt: Anfang, Ende, Kernzeilen zeichengenau', () {
    final p = masterPrompt();
    expect(
        p,
        startsWith('Du bist die Setup-Pipeline für „Thesis Studio“ — eine '
            'lokale Web-App für KI-gestützte\n'));
    expect(p, endsWith('Die vollständige Spezifikation liegt in docs/PROJEKT-FORMAT.md.'));
    // ```json-Nennung (im Original per Backtick-Escape).
    expect(p, contains('jeweils als ```json-Block mit vorangestelltem Dateinamen.'));
    // Die 11 Datei-Abschnitte.
    expect(p, contains('\n1. registry.json — Quellen-Registry aus dem Literaturverzeichnis:'));
    expect(p, contains('\n2. <abschnitt>.json je Abschnitt (Punkt→Unterstrich, z. B. 3_2_1.json):'));
    expect(p, contains('\n7. connections.json — KI-erkannte inhaltliche Verbindungen zwischen Abschnitten:'));
    expect(p, contains('\n11. erklaerbuch.md (optional, eingebautes Buch): reines Markdown nach docs/ERKLAERBUCH.md —'));
    // suchHinweis-Vertragszeile (ASCII-Schreibweisen!).
    expect(
        p,
        contains('"suchHinweis": "<2-4 WOERTLICH im Original vorkommende '
            'Zeichenketten (je 2-6 Woerter, exakte Schreibweise und Sprache '
            'des Originals, KEINE Umformulierung), mit | getrennt - jede muss '
            'ueber die PDF-Volltextsuche 1:1 auffindbar sein>"'));
    // kind-Enumeration wörtlich.
    expect(p, contains('"kind": "artikel|konferenz|norm|report|online|recht-eu|recht-at"'));
    // Backtick um `data` (Erklärbuch-Zellen).
    expect(p, contains('die Zellen greifen über `data` auf die'));
  });

  test('masterPromptWithTex: Trenner exakt wie das Original', () {
    final line = '=' * 60;
    final out = masterPromptWithTex(r'\chapter{X}');
    expect(
        out,
        endsWith('\n\n$line\nHIER DER LATEX-QUELLTEXT DER ARBEIT:\n$line\n\n'
            r'\chapter{X}'));
    expect(out, startsWith(masterPrompt()));
  });
}
