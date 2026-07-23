/// 🤖 Generier-Prompt des Erklärbuchs — `Notebook.prompt()`
/// (notebook.js:653-695, wortwörtlich): Anleitung + Baustein-Referenz in
/// Kurzform + echtes Datenpaket + Abschnitts-/Abbildungslisten.
///
/// Konsument ist die GPT-Magic „Erklärbuch“ der AI-Schicht (K-3,
/// enhance.js:90-92) — dieser Provider ist ihr Andockpunkt.
library;

import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/bundles/indexes.dart';
import 'notebook_state.dart';

part 'notebook_prompt.g.dart';

@Riverpod(keepAlive: true)
Future<String> notebookPrompt(Ref ref) async {
  final d = await ref.watch(notebookDatasetProvider.future);
  final unitIndex = ref.watch(unitIndexProvider);
  final ordered = ref.watch(orderedUnitsProvider);
  final secList = [
    for (final id in ordered.take(80))
      '$id ${unitIndex[id]?.unit.title ?? ''}',
  ].join(' · ');

  final abbildungen = d['abbildungen'];
  final figIds = abbildungen is List
      ? [
          for (final f in abbildungen)
            if (f is Map) '${f['id']}',
        ].join(', ')
      : '';
  final figLine = figIds.isNotEmpty ? figIds : '(keine)';

  return [
    'Du erzeugst das ERKLÄRBUCH zu einer wissenschaftlichen Arbeit für „Thesis Studio“ —',
    'eine Visualisierungs- und Inhaltsplattform. Ausgabe: EIN Markdown-Dokument (nur der Inhalt,',
    'kein umschließender Codeblock). Zielniveau: verständliches, grafisch starkes Erklär-/Begleitbuch',
    'zur Arbeit — Kapitel für Kapitel, mit Diagrammen, Tabellen, Formeln und eingebetteten Passagen.',
    '',
    '== BAUSTEINE (alles, was die Plattform rendert) ==',
    r'1. Markdown: #/##/### Überschriften, **fett**, *kursiv*, Listen, > Zitate, [Link](https://…).',
    r'2. Inline-Mathe: $\bar{x}$ · Display-Mathe: $$ … $$ oder ```math — LaTeX-Subset:',
    r'   \frac \sqrt \sum \prod \int (mit ^ _-Grenzen), griechische Buchstaben, \bar \hat \vec,',
    r'   \text{}, \leq \geq \neq \approx \infty \rightarrow \cdot \times \pm …',
    '3. ```chart — SVG-Diagramm, Body = JSON:',
    '   {"type":"bar|barh|line|area|scatter|pie|donut","title":"…","labels":[…],',
    '    "series":[{"name":"…","values":[…]}],"stacked":false,"x":"…","y":"…"}',
    '4. ```table [sum] — CSV/;-/Tab-/Pipe-Tabelle; erste Zeile = Kopf; „sum“ ergänzt Summenzeile.',
    r'5. ```latex — LaTeX (derselbe Interpreter wie die Arbeit): \section, \textbf, \enquote,',
    r'   \footnote, itemize/enumerate, \S — KEINE anderen Pakete/Befehle.',
    '6. ```figure <id> — bestehende Abbildung der Arbeit einbetten. Verfügbare ids:',
    '   $figLine',
    '7. ```include <abschnitts-id> — Originalpassage der Arbeit einbetten.',
    '   Abschnitte: $secList',
    '8. ```js auto — Rechenzelle (läuft sofort): Variablen data/print/show/md/chart/table/figure/math.',
    '   data = das Datenpaket unten. Bevorzuge js-auto-Zellen für alles, was aus data berechenbar ist',
    '   (Diagramme bleiben dann automatisch aktuell).',
    '9. ```py — Python (Pyodide; numpy/pandas/matplotlib/scikit-learn nachladbar): data (dict),',
    '   print(), chart(spec), show(html), show_plt() nach matplotlib-Plots. Läuft erst auf ▶-Klick —',
    '   für Schweres/ML; Kernaussagen zusätzlich als js/chart, damit sie sofort sichtbar sind.',
    '',
    '== REGELN ==',
    '- Struktur: Titel, Kurzüberblick, dann je Kapitel der Arbeit ein Abschnitt (Kernaussagen,',
    '  passende Visualisierung, ggf. Formel/Tabelle), zum Schluss Gesamtbild + Ausblick.',
    '- JEDES Diagramm speist sich aus dem Datenpaket oder aus im Text genannten Zahlen — nichts erfinden.',
    r'- Mathematik/Statistik gerne: Mittelwert, Streuung, Anteile, Trends — mit $$-Formel UND Rechnung (js).',
    '- Sparsame, präzise Texte zwischen den Blöcken; das Buch soll sich lesen wie gutes Erklärmaterial.',
    '',
    '== DATENPAKET (echte Zahlen der Arbeit) ==',
    const JsonEncoder.withIndent(' ').convert(d),
    '',
    'Antworte NUR mit dem fertigen Markdown-Dokument.',
  ].join('\n');
}
