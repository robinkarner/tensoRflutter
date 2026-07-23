/// Baustein-Referenz des Erklärbuchs — Inhalt von `docs/ERKLAERBUCH.md`
/// (wortwörtlich eingebettet).
///
/// Das Original verlinkt die Datei per `target="_blank"`; die App hat kein
/// mitgeliefertes docs-Verzeichnis, daher öffnet „Referenz ↗“ den Text in
/// einem Modal (gerendert über den Notebook-Markdown-Renderer).
library;

const String erklaerbuchReferenzMd = r'''# Erklärbuch — Referenz (Analyse → 📓 Erklärbuch)

Das Erklärbuch ist die Visualisierungs- und Inhaltsplattform von Thesis Studio:
**EIN Markdown-Dokument** als oberste Ebene, alles Weitere eingebettet — Diagramme,
Tabellen, Mathematik, LaTeX, Abbildungen und Textpassagen der Arbeit sowie
Rechenzellen (JavaScript sofort, Python auf Abruf). Es ist vollständig
**KI-generierbar**: der 🤖-Prompt im Erklärbuch-Tab enthält diese Referenz in
Kurzform plus das echte Datenpaket der aktiven Arbeit — ein Modell ab
**Claude Opus 4.8** erzeugt daraus das komplette Buch; ⭱ Import übernimmt es.

Gespeichert wird pro Arbeit (localStorage, im Belegstand-Export enthalten).
Ohne eigenes Buch rendert das Starter-Buch, das live mit den Daten der aktiven
Arbeit rechnet.

## Bausteine

### 1. Markdown (oberste Ebene)
`#`–`####` Überschriften, `**fett**`, `*kursiv*`, Listen (`-`/`1.`),
`> Zitat`, `[Text](https://…)`, `` `code` ``.

### 2. Mathematik (eigener Renderer, kein CDN)
- Inline: `$\bar{x} \pm s$` mitten im Text.
- Display: `$$ … $$` oder ein ```math-Block.
- Unterstütztes LaTeX-Subset: `\frac{a}{b}`, `\sqrt{x}`, `\sum/\prod/\int/\lim`
  (mit `^`/`_`-Grenzen, im Display gestapelt), griechische Buchstaben
  (`\alpha … \Omega`), `\bar \hat \vec \overline`, `\text{…}`, `\mathbb/\mathbf`,
  Relationen (`\leq \geq \neq \approx \equiv \propto`), Pfeile
  (`\rightarrow \Rightarrow \mapsto`), Mengen (`\in \subset \cup \cap`),
  `\infty \partial \nabla \cdot \times \pm`, `\left( \right)`.
- Nicht Unterstütztes erscheint als ⚠ mit Tooltip — kein stiller Ausfall.

### 3. ```chart — Diagramme (SVG, theme-aware, ohne Fremdbibliothek)
Body ist JSON:

```json
{
  "type": "bar | barh | line | area | scatter | pie | donut",
  "title": "Überschrift",
  "labels": ["A", "B", "C"],
  "series": [{ "name": "Serie", "values": [1, 2, 3], "color": "#b4552d" }],
  "stacked": false,
  "x": "Achsentext", "y": "Achsentext", "height": 300
}
```

Mehrere `series` ⇒ Legende und Gruppierung (bar) bzw. Mehrfachlinien;
`stacked: true` stapelt bar/area. `scatter` nimmt `values: [[x, y], …]`.
Farben kommen automatisch aus der Studio-Palette.

### 4. ```table — Tabellen
CSV-, `;`-, Tab- oder Pipe-Zeilen; erste Zeile = Kopf. Zahlkolonnen werden
rechtsbündig gesetzt; Meta-Flag `sum` (```table sum) ergänzt eine Summenzeile.

### 5. ```latex — derselbe Interpreter wie die Arbeit
Der Block läuft durch **denselben** Transformer wie der Studio-Editor
(Editor.preview / TexParse-Familie): `\section…\subsubsection`, `\textbf`,
`\textit/\emph`, `\enquote{}`, `\footnote{}`, `itemize/enumerate`, `\S`, `--`.
Nicht Erlaubtes meldet der Prüfbericht im Compiler-Stil direkt unter dem Block.

### 6. ```figure — Abbildungen der Arbeit
Body oder Meta = Abbildungs-id (siehe Datenpaket `abbildungen`) oder Nummer.
Rendert die bestehende Bildkarte inkl. Beschriftung und Lightbox.

### 7. ```include — Textpassagen der Arbeit
Body oder Meta = Abschnitts-id (z. B. `3.2`). Bettet die Originalabsätze im
Lesen-Stil ein (Ground Truth bleibt unberührt — reine Anzeige).

### 8. ```js — Rechenzelle (sofort, offline)
Läuft im Browser (`▶ ausführen`; Meta-Flag `auto` startet beim Rendern).
Verfügbare API (auch als `nb.*`):

| Funktion | Wirkung |
|---|---|
| `data` | das Datenpaket (s. u.) |
| `print(…)` | Ausgabezeile (wie Konsole) |
| `chart(spec)` | Diagramm wie ```chart |
| `table(rows, {sum})` | Tabelle aus `[[Kopf…], [Zeile…], …]` |
| `md("…")` | Markdown (inkl. `$…$`-Mathe) |
| `math("\\frac{a}{b}")` | Display-Formel |
| `show(html)` | eigenes HTML/SVG |
| `figure("id")` | Abbildung der Arbeit |

### 9. ```py — Python (Pyodide)
Erster `▶`-Klick lädt die Python-Umgebung einmalig vom CDN (~10 MB, braucht
Internet; danach gecacht). `import numpy/pandas/matplotlib/sklearn` lädt die
Pakete automatisch nach — damit sind **Statistik, ML/AI und wissenschaftliches
Rechnen** direkt im Buch möglich. API im Python-Namensraum:

- `data` — Datenpaket als dict
- `print()` — erscheint als Ausgabe der Zelle
- `chart(spec)` — Diagramm (dict wie ```chart)
- `show(html)` — eigenes HTML
- `show_plt()` — rendert die aktuelle matplotlib-Figur als Bild in die Zelle

Empfehlung an Generatoren: Kernaussagen zusätzlich als ```js auto oder
```chart ausgeben (sofort sichtbar, offline) — Python für Schweres/ML.

## Datenpaket (Schnittstelle zu den echten Zahlen)

`data` enthält für die aktive Arbeit:

```json
{
  "arbeit": { "titel", "autor", "universitaet" },
  "kapitel": [{ "num", "titel", "abschnitte", "absaetze", "fussnoten" }],
  "quellen": [{ "id", "titel", "kurz", "typ", "jahr", "zitierstellen" }],
  "belegStatus": { "offen", "vermutet", "original", "belegt", "gesamt" },
  "verbindungen": { "gesamt", "nachTyp": { "folgerung", "fazit", "xref", "quellen", … } },
  "abbildungen": [{ "id", "titel" }]
}
```

## Generieren mit einem KI-Modell (ab Opus 4.8)

1. Analyse → 📓 Erklärbuch → **🤖 Prompt** (kopiert Anleitung + Referenz +
   Datenpaket + Abschnitts-/Abbildungslisten).
2. Prompt an das Modell geben; Antwort = reines Markdown-Dokument.
3. **⭱ Import** — fertig. Jederzeit neu generierbar oder mit **✎ Bearbeiten**
   (Quelltext + Live-Vorschau) von Hand verfeinerbar; **⭳ Export** sichert als `.md`.

## Technologien

Alles läuft ohne Build und ohne Server: eigener Markdown-/Mathe-Renderer,
SVG-Chart-Engine (theme-aware), TexParse/Editor-Interpreter für LaTeX,
JS-Zellen über `Function` im Seitenkontext, Python über Pyodide (WebAssembly,
CDN-lazy). Einzige Online-Abhängigkeit ist Pyodide — alle anderen Bausteine
funktionieren auch über `file://`.
''';
