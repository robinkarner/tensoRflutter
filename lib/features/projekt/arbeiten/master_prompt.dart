/// Master-Prompt der Pre-Pipe — Port von `masterPrompt()`
/// (views_projekt.js:493-563). Der Text ist VERTRAGSTEXT gegenüber dem
/// externen GPT-Modell (definiert das JSON-Austauschformat der kompletten
/// Voranalyse) und wird deshalb ZEICHENGENAU übernommen — inklusive der
/// Zeilenumbrüche, der ```json-Nennung und der ASCII-Schreibweisen im
/// suchHinweis-Feld.
library;

/// Formatvorgabe für die externe GPT-Pipeline (11 Dateien).
String masterPrompt() {
  return r'''Du bist die Setup-Pipeline für „Thesis Studio“ — eine lokale Web-App für KI-gestützte
Quellen- und Belegarbeit an wissenschaftlichen Arbeiten. Unten bekommst du den LaTeX-Quelltext
einer Arbeit. Erzeuge daraus die komplette GPT-Voranalyse als einzelne JSON-Dateien
(UTF-8, deutsch), jeweils als ```json-Block mit vorangestelltem Dateinamen.

MOTIVATION: Die App löst jede Aussage der Arbeit in prüfbare Belege auf (Fußnote → Claim +
vermutete Fundstelle + Suchbegriffe), verbindet sie mit den Quellen (Dossiers, Links) und
zeigt inhaltliche Connections. Nichts erfinden: Fundstellen sind VERMUTUNGEN aus dem
Fußnotentext — so präzise wie dort genannt (Seiten/Art/§), ohne echte Datei-Analyse.

DATEIEN:

1. registry.json — Quellen-Registry aus dem Literaturverzeichnis:
   [{ "id": "cobrado2024",            ← kurz, stabil, kleingeschrieben (autor+jahr bzw. Kürzel wie "dsgvo")
      "kind": "artikel|konferenz|norm|report|online|recht-eu|recht-at",
      "author": "…", "year": 2024, "title": "…", "container": "…", "doi": "…", "url": "…",
      "links": { "official": "<offizielle Seite (DOI/Verlag/EUR-Lex/RIS)>",
                 "file": "<IMMER versuchen: realistischster OEFFENTLICH zugänglicher Direkt-Download-Link
                          zum PDF (Open Access, Preprint, arXiv, Autoren-/Instituts-Repositorium) —
                          nur wenn nichts frei verfügbar ist: null>" },
      "aliases": ["Cobrado"] }]       ← Regex-Strings, die Fußnotentexte dieser Quelle matchen

2. <abschnitt>.json je Abschnitt (Punkt→Unterstrich, z. B. 3_2_1.json):
   { "sectionId": "3.2.1", "paragraphs": [{
       "id": "3.2.1-p1", "type": "text|list|figure|table",
       "kernaussage": "<1 Satz>",
       "sentences": [{ "text": "<Satz wörtlich inkl. [^N]-Marker>", "einfach": "<einfache Erklärung>",
                       "kategorien": ["norm|frist|akteur|tech|these|luecke|zahl"],
                       "marks": [{ "snippet": "<wörtlicher Teilstring>", "kategorie": "…" }] }],
       "belege": [{ "num": <N>, "quellen": ["<id>"], "claim": "<was belegt wird>",
                    "fundstelle": "<vermutet>", "suchHinweis": "<2-4 WOERTLICH im Original vorkommende Zeichenketten (je 2-6 Woerter, exakte Schreibweise und Sprache des Originals, KEINE Umformulierung), mit | getrennt - jede muss ueber die PDF-Volltextsuche 1:1 auffindbar sein>" }] }] }
   REGELN: sentences[].text ergeben zusammengesetzt EXAKT den Absatztext; marks[].snippet ist
   wörtlicher Teilstring; jede Fußnote bekommt genau einen belege-Eintrag.

3. Quellen-Dossiers je Quelle (<id>-dossier.json): { "sourceId", "dossier": "<Markdown>",
   "keyPoints": ["…"], "zitierweise": "<Vollzitat>", "hinweisOhnePdf": "<1–2 Sätze>" }

4. kapitel-<n>.json: { "kurzfassung": "<Markdown>", "kernaussagen": ["…"],
   "begriffe": [{"begriff","erklaerung"}], "fristen": [{"datum","was"}],
   "abschnitte": [{"id","titel","einzeiler"}], "fazitBeitrag": "<1 Satz>" }

5. gesamt.json: { "executiveSummary", "ergebnisse": {"positiv":[…],"luecken":[…],"spannungen":[…]},
   "roterFaden": [{kapitel,label,text}], "timeline": [{datum,label,typ}] }

6. fazit-connections.json: { "findings": [{ "id","label","typ":"positiv|luecke|spannung|ausblick",
   "beschreibung","fazitParagraphId","abschnitte":["…"],"fristen":["…"] }], "kapitelFluss": [{von,nach,label}] }

7. connections.json — KI-erkannte inhaltliche Verbindungen zwischen Abschnitten:
   { "connections": [{ "id": "c1", "typ": "folgerung|grundlage|aufgriff|vergleich",
      "von": {"sectionId": "5.3.3", "paraId": "5.3.3-p2"}, "nach": {"sectionId": "6.0", "paraId": "6.0-p5"},
      "label": "<Kurzname>", "text": "<warum die Stellen zusammenhängen>" }] }
   (folgerung: B wird aus A gefolgert · grundlage: A trägt B · aufgriff: Thema kehrt wieder ·
    vergleich: gleiche Sache, andere Perspektive. 15–40 Stück, Qualität vor Menge.)

8. struktur.json / quellen.json / inhalt.json (Würdigung): { "titel", "markdown", "punkte": [{typ,text}] }

9. standards.json (optional, Gesamt-Bewertung): { "titel", "verdikt": "<Markdown>", "markdown",
   "kriterien": [{"name","note":"stark|solide|ausbaufaehig|schwach","text"}],
   "verbesserung": ["konkreter Verbesserungspunkt", …] }

10. instanzen.json (optional, eigene Absatz-Instanzen mit Farbe):
   { "defs": [{"id","label","color":"var(--cat-tech)|#hex","desc":"<GPT-Auftrag je Absatz>"}],
     "items": {"<instanz-id>": {"<absatz-id>":"<markdown>", …}} }

11. erklaerbuch.md (optional, eingebautes Buch): reines Markdown nach docs/ERKLAERBUCH.md —
   Charts/Tabellen/Mathe/include/figure/Rechenzellen; die Zellen greifen über `data` auf die
   echten Kennzahlen der Arbeit zu.

Arbeite Kapitel für Kapitel. Die vollständige Spezifikation liegt in docs/PROJEKT-FORMAT.md.''';
}

/// Gesamt-Prompt inkl. LaTeX-Anhang — der Trenner exakt wie
/// views_projekt.js:297: `'='.repeat(60) + '\nHIER DER LATEX-QUELLTEXT DER
/// ARBEIT:\n' + '='.repeat(60)`.
String masterPromptWithTex(String tex) {
  final line = '=' * 60;
  return '${masterPrompt()}\n\n$line\nHIER DER LATEX-QUELLTEXT DER ARBEIT:\n$line\n\n$tex';
}
