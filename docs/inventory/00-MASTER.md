# 00-MASTER — Synthese der Bestandsaufnahme „Thesis Studio" (thesoR) für die Flutter-Konvertierung

Quellen: Dossiers 01–10 in diesem Verzeichnis (vollständig gelesen und abgeglichen). Detailtiefe bleibt in den Einzeldossiers; dieses Dokument ist Landkarte, Prioritätenliste und Konfliktprotokoll.

---

## 1. Gesamtbild

**Was die App ist:** „Thesis Studio" ist eine serverlose Vanilla-JS-Single-Page-App (23 klassische `<script>`-Globals, kein Modul-System, kein Build) für **Quellen- und Belegarbeit an wissenschaftlichen Arbeiten**. Ground Truth ist immer der LaTeX-Quelltext einer Arbeit; darüber liegen (a) eine deterministisch geparste Struktur (Kapitel→Abschnitte→Absätze→Fußnoten→Quellen), (b) eine GPT-Voranalyse (Kernaussagen, Satz-Zerlegungen, Beleg-Vermutungen, Dossiers, Connections, Erklärbuch) und (c) der lokale „Prüfstand" des Nutzers (Beleg-Status, PDF-Markierungen, Zitate, Notizen, Edits) — komplett im Browser (localStorage + 3 IndexedDB-Datenbanken). Eine eingebaute Beispielarbeit (EHDS-Bachelorarbeit, dt.) plus eine zweite Builtin-Arbeit (Sensors-Paper, engl.) sind mitgeliefert; eigene Arbeiten werden aus `.tex` (oder PDF-Beta) importiert. Die zentrale Tätigkeit: Fußnote für Fußnote vom KI-vermuteten Beleg (Stufe 1 ✦) über gefundene Originalpassage (Stufe 2 ❝) zur gesicherten Position im PDF (Stufe 3 ✓) eskalieren — per PDF-Markieren, Text-Markieren oder Handeingabe.

**Die 4+2 Bereiche (Hash-Router `#/…`):**

| # | Bereich | Route | Kern |
|---|---|---|---|
| 1 | **Studio** (Hauptprogramm) | `#/studio/<sec>/<modus>/<para>` | 3-Spalten-Arbeitsraum (TOC · Inhalt · Quellen-Spalte mit PDF+Beleg-Dock), 3 Modi ☰ Lesen / ◉ Analyse („pruefen") / ✎ LaTeX, Beleg-Workflow, Erwähnungen, Views/Instanz-Fenster, Referenzierungs-Vollbild |
| 2 | **Quellen** (Bibliothek) | `#/quellen/<id>` | Zotero-artiges 3-Spalten-Layout, 74 Quellen, Datei-Beschaffung (Download/Import/ZIP-Datei-Auftrag), Dossiers, Zitierstellen, Fundstellen-Register |
| 3 | **Wissen** (Analyse) | `#/analyse/<tab>/<arg>` | eigene blaue Farbwelt; 8 Tabs: Erklärbuch (Notebook mit Chart/Mathe/Code-Zellen), Analysemodus, Instanzen, Überblick, Kapitel, Connections, Kennzahlen, Würdigung |
| 4 | **Status/Projekt** | `#/projekt` | Dashboard, Quellen-Setup, Bulk-Download, Referenzierungsdurchläufe, Arbeiten-Verwaltung (Mehrfach-Instanzen), Analysen-Import |
| +1 | **Hilfe** | `#/hilfe` | statische Produkt-Doku (5 Karten) |
| +2 | **PDF-Dokument** | `#/doc` | ganze Arbeit als EIN Dokument, LaTeX-Export, Drucken |

**Querschichten:** (a) **KI/GPT** („Generate GPT"-Hub, Enhance-Werkbank mit 7 Flows, ✦ Magic-Dock, Claude-SSE-Client mit Demo-Modus — jede KI-Funktion = Datenpaket: Prompt → Modell → Format-Checker → definierter Speicherort; alles auch ohne API-Key per ⧉ Kopieren/⭱ Einfügen nutzbar); (b) **PDF-Engine** (pdf.js-Viewer mit Endlos-Scroll, Text-Markieren → zoom-invariante 0..1-Rects, Kommentar-Pins, Volltextsuche, OCR, Quell-Karte `assignPanel`); (c) **Domänenlogik** (Levels-Kaskade, Connections, Mentions, StyleCheck, LaTeX-Editor/Parser, ZipUtil); (d) **Shell** (Router, Theme auto/light/dark, Command-Palette Strg+K, Passwort-Gate, projekt-gescoptes Storage).

**Designsystem „V5 Book Cloth":** EIN Akzent Terracotta `#b4552d` auf warmem Papier `#f4f2ec` (Dark: `#e28a5d` auf `#1e1c17`); Kernkonvention **RUND = Belegstatus, QUADRATISCH = Struktur/Datei** (8×8px-Eckmarker); „Wissen" überschreibt mit Marineblau; Magic-Buttons im „Retro-Spielmenü"-Stil (Baloo 2, harter Sockelschatten).

---

## 2. Feature-Matrix

Komplexität: S (<1 Tag) · M (1–3 Tage) · L (3–7 Tage) · XL (>1 Woche). Risiko = Flutter-Portierungsrisiko.

### Shell & Core (Dossier 01)

| Feature | Kurzbeschreibung | Kompl. | Risiko | Plugins |
|---|---|---|---|---|
| Boot-Sequenz | Projects.boot → PdfStore.ready → rebuildDataIndexes → einmaliger Belegstand-Import (strikte Reihenfolge!) | M | mittel | riverpod |
| Hash-Router | 6 Live-Routen + 4 Alt-Routen-Redirects, Studio-Fallback statt 404, Absatz-Anker als 4. Segment | S | niedrig | go_router |
| Passwort-Gate | SHA-256-Hash-Check, ohne Crypto/Storage: App offen | S | niedrig | crypto |
| Theme-Zyklus | auto→light→dark (◐☀☾), theme-color-Meta-Austausch | S | niedrig | shared_preferences |
| Command-Palette | Strg/⌘+K, 8 Ansichten + Abschnitte + Quellen, max 40 Treffer, Capture-Esc | M | niedrig | — |
| richText-Renderer | Fußnoten-Chips (U+0001-Sentinels!), Marks, Mentions, Xrefs — Insert-Reihenfolge verhaltensrelevant | L | **hoch** | — (eigener TextSpan-Builder) |
| Modal-System | Ein-Modal-Semantik mit `_modalCleanup`-Hook | S | niedrig | — |
| Fußnoten-Modal | globales Beleg-Detail (delegierter `.fn-chip`-Klick) | S | niedrig | — |
| gptModal | universelles KI-Dialog-Muster (Prompt/Stream/Import, Demo ohne Auto-Import) | M | mittel | — |
| U.resizer | ein Pointer-Capture-Pattern für alle Splits (min 220/max 1100, Doppelklick=Reset) | M | mittel | — |
| Tooltip (viz-tip) | +14px Versatz, Viewport-geklemmt | S | niedrig | — |
| Storage-Layer | `ehds.[<projekt>.]<key>` mit 26er-PROJECT_KEYS-Whitelist, JSON, Fehler still | M | **hoch** (Kompatibilität) | shared_preferences/drift |
| srcShort/matchSourceInText | Kurzname-Map (20 Rechtsquellen) + Quellen-Pattern-Matching | S | niedrig | — |
| splitSentences/belegSpan | abkürzungsfeste Satz-Zerlegung + Satzspannen-Heuristik | M | mittel | — |

### Studio (Dossier 03)

| Feature | Kurzbeschreibung | Kompl. | Risiko | Plugins |
|---|---|---|---|---|
| 3-Spalten-Layout | CSS-Grid mit `--tree-w`/`--file-w`, 7px-Griffe, Einklappen + fixe Rand-Leisten (Vertikaltext), Klemmen 26vw/50vw, Breakpoint 999px | L | mittel | — |
| Modus-Leiste | sticky, 3 Modi als Links, Dichte/⚡/🖍-Toggles | M | niedrig | — |
| Kapitelbaum | Kapitel-Toggle, ✎-Umbenennen (Esc=verwerfen — einzige Ausnahme!), Fortschritts-Dots | M | niedrig | — |
| Lesen-Modus | fortlaufender Text, Kompakt=Kernaussagen-Liste, Text-Views als Blöcke | M | mittel | — |
| Prüfen-Modus | Absatzkarten mit Kategorie-Chips, Belege+Erwähnungen aufklappbar, jump-flash-Anker | L | mittel | — |
| Beleg-Workflow | selectBeleg → Satzspannen-Highlight + fileShow; Checkliste „⌖ n/3"; Spannen-Steuerung ± Satz | L | **hoch** | — |
| Erwähnungs-Workflow | Status-Maschine offen→bestätigt/verworfen/beleg (Merge), Kandidaten-Dropdown, alles ↺-reversibel | M | mittel | — |
| Quellen-Spalte | sticky, assignPanel + PDF-Engine + Beleg-Dock (Höhe ziehbar, <110px Auto-Zuklappen), Generation-Token gegen Races | L | **hoch** | pdfrx |
| Referenzierungsmodus | Vollbild-Split Zitierelemente/PDF, 4 Ansichten je Quelle (PDF/Text/Register/Datei), Text-Auswahl→Zitat | L | **hoch** | pdfrx |
| Views/Instanz-System | DOCK_DEFAULTS + Projekt-Views + instDefs; Fenster neben Absatzkarte (`--ps-w` 200–560px), Doppelklick-Edit, ⤳ Graph-Fenster | L | mittel | — |
| Absatz-Doppelklick-Edit | contentEditable, **Esc UND Blur = übernehmen**, paraEdits-Override + LaTeX-Sync | M | mittel | — |
| ◘ Quelle-View / Stil-Check | satzgenaue Custom-Highlights (src-view, gpt-style) | M | **hoch** | — (TextSpan) |
| #/doc + Druck | ganze Arbeit, LaTeX-Export, window.print() | M | mittel | printing |
| LaTeX-Editor (editor.js) | Split 25–70%, 17-Befehle-Subset, Lint (dt. Meldungen), Live-Preview 220ms, Snippets, ＋ Quelle | L | mittel | — |
| sourcePickerModal | durchsuchbarer Quellen-Picker | S | niedrig | — |

### Quellen-Bibliothek & Dateispeicher (Dossier 04)

| Feature | Kurzbeschreibung | Kompl. | Risiko | Plugins |
|---|---|---|---|---|
| Bibliothek-Layout | 4-Spur-Grid (Rail 220px · Liste 18–60% · Griff · Detail), Breakpoints 1199/720 | M | niedrig | — |
| Sammlungen+Filter | alle/7 Typen/4 Smart-Filter/custom; Suche live; 4 Sortierungen | M | niedrig | — |
| Detailpanel | `<details>`-Sektionen mit konditionalem Default-open, Zitierstellen mit Level-Eskalation, Erwähnungen | L | mittel | — |
| Fundstellen-Register | Regex-Ableitung §/Art/ErwGr/Anhang aus Fußnotentexten | S | niedrig | — |
| PdfStore | IndexedDB `ehds-pdfstore` (blobs: srcId / inbox: / img: / ~x-Material), arbeitsübergreifend, Listener mit DOM-Anker-Autocleanup | L | mittel | path_provider, drift |
| Import PDF/ZIP | Matching-Kaskade (ts-Hash → id → Vorschlag → Ablage), „kein stiller Verlust" | L | mittel | archive, file_picker |
| Datei-Auftrag-ZIP | auftrag.json + ANLEITUNG.txt; Identität via `U.srcHash` = `ts-`+CRC32 | M | **hoch** (Bit-Kompatibilität) | archive |
| storeModal | Speicher-Übersicht + Zuweisen + Quelle-aus-Datei | M | niedrig | — |
| Neue Quelle / aus Datei | Modals mit id-Vorschlag live, Slug-Sanitizing | M | niedrig | — |
| 🤖 Ergänzung | GPT-Metadaten-Import (Whitelist, id nie überschreibbar) | M | niedrig | — |
| Belegstand Sichern/Laden | `ehds-belegstand` v2 (21 Bereiche, `notes`↔`srcNotes`!) | M | mittel | file_saver |
| Legacy-Ordner (FS-Access) | im Original bereits Altbestand — **Empfehlung: weglassen** | S | hoch | (entfällt) |

### PDF-Engine & Bilder (Dossier 05)

| Feature | Kurzbeschreibung | Kompl. | Risiko | Plugins |
|---|---|---|---|---|
| PDF-Viewer | Endlos-Scroll, IO-Lazy-Render, Speicherfreigabe >8 Seiten, Zoom fit/×1.2 (0.3–4), Tastatur ←→+−0, Ctrl+F | XL | **hoch** | pdfrx |
| Text-Markieren | Selektion → max 40 normalisierte 0..1-Rects (Ursprung oben links), Farbe je Beleg, Auto-Pin x=0.94, onCapture → Levels | XL | **hoch** | pdfrx (Selection-Rects!) |
| Highlights rendern | hex+55-Alpha, multiply (Dark: normal+opacity .55), datenbasierter Hit-Test, markChooser bei Überlapp | L | **hoch** | — |
| Kommentar-Pins | Drag (4px-Schwelle), Clamp 0–0.98, Popover-Editor | M | mittel | — |
| Volltextsuche | lazy Seitentext-Cache, zirkulär, OCR-Ersatz <20 Zeichen, Flash 2,6s | M | mittel | — |
| OCR | Tesseract.js 5.1.1 CDN `deu+eng`, Cache global `ocrText` | M | **hoch** | google_mlkit / tesseract_ocr |
| pdfToTex (Beta) | Schriftgrößen-Heuristik PDF→LaTeX — braucht per-Item-Fontgrößen | L | **hoch** (ggf. streichen) | pdfrx/pdfium-FFI |
| tryDownload | 1 fetch, 20s-Timeout, %PDF-Magic, dlStatus persistent | S | niedrig | dio |
| assignPanel | DIE Quell-Karte: 4 Datei-Zustände, 5-Tab-Material-Switch, Kandidaten-Preview (viewOnly), Download | XL | mittel | — |
| Kandidaten-Erkennung | NUR über ts-Hash/exakte id; „✗ passt nicht" persistent | M | mittel | — |
| FigStore + figureCard/tableCard | IndexedDB `ehds-figstore`, Upload-Platzhalter, Lightbox | M | niedrig | file_picker |

### Wissen / Analyse / Notebook (Dossier 06)

| Feature | Kurzbeschreibung | Kompl. | Risiko | Plugins |
|---|---|---|---|---|
| Tab-Cluster | 3 beschriftete Gruppen, 8 Tabs, Wissen-Farbwelt (Card-Topline 2px blau) | M | niedrig | — |
| Erklärbuch-Renderer | Markdown + Fenced-Blöcke chart/table/math/latex/figure/include/js/py; Fehler je Block gefangen | XL | **hoch** | flutter_markdown |
| Notebook-Editor | 1fr/1fr-Split-Modal, 350ms-Debounce-Live-Preview | M | niedrig | — |
| MathRender | eigenes LaTeX-Mathe-Subset (kein KaTeX), ⚠-Chip bei Unbekanntem | M | mittel | flutter_math_fork |
| Chart-Engine | 7 Typen SVG 760×300 (padL52/padB42, nice-Ticks, de-AT-Format, stacked, Vollkreis-Sonderfall) | L | mittel | — (CustomPainter) |
| js-Zellen | `new Function` mit API data/print/show/md/chart/table/figure/math, `auto`-Flag | M | **hoch** | flutter_js (QuickJS) |
| py-Zellen | Pyodide v0.26.4 CDN, nie auto, show_plt→PNG | L | **hoch** (weglassen/WebView) | webview_flutter? |
| Analysemodus | Original-Absätze + Linse (dockGet→dockAuto-Fallback), Abdeckungs-Meter, Scroll-Restore | M | niedrig | — |
| Instanzen-Tab | Absatz-Inhalte je View gruppiert | S | niedrig | — |
| Überblick | Executive Summary, Ergebnisse-Grid, Roter Faden, Fristen-Timeline (⚠ unstyled im Original!) | M | niedrig | — |
| Kapitel-Tab | Kurzfassung, Kernaussagen, Begriffe, Fristen, Fazit-Verbindung | M | niedrig | — |
| Connections-Tab | kapitelFluss (Bézier-Bögen) + fazitGraph (bipartit, Hover-Dimming 1/0.12/0.5) | L | mittel | — (CustomPainter+Stack) |
| Würdigung | Standards mit ★-Noten, 3 Akkordeons | S | niedrig | — |
| Kennzahlen | 5 Stat-Kacheln + 3 barH-Charts | S | niedrig | — |

### Projekt / Status / Arbeiten (Dossier 07)

| Feature | Kurzbeschreibung | Kompl. | Risiko | Plugins |
|---|---|---|---|---|
| Status-Dashboard | 6 Statkacheln (async PDF-Zählung), 2 Spalten 1.55fr/1fr (BP 999) | M | niedrig | — |
| Kapitel-Fortschritt | Levels.bar je Kapitel + ⌖-Sprung | S | niedrig | — |
| Quellen-Setup | Link-Vorschläge prüfen („✓ alle übernehmen" mit `https://`-Platzhalter-Randfall!), ⭳ Alle laden (sequentiell, Live-Redraw), Inline-assignPanel-Zeile | L | mittel | dio |
| Referenzierungsdurchläufe | je Quelle → Enhance.pasteModal('quellen') | S | niedrig | — |
| Arbeiten-Verwaltung (🗂) | Topbar-Dropdown, Aktivieren = **location.reload()**, Export/Import/Löschen mit Tombstones | L | mittel | — |
| Neue Arbeit aus .tex/PDF | Live-Parse 450ms-Debounce, Drag&Drop, PDF-Beta, id `p-<slug30>-<rand4>` | L | **hoch** | file_picker, desktop_drop |
| Analysen-Import | Multi-File, 11-stufiges Dateiname-Mapping, Registry ZULETZT, reload wenn aktiv | M | mittel | file_picker |
| Builtin-Seeding | sensors-paper v6, Update nur bei höherer Version + !userModified, Tombstones | M | mittel | — |
| masterPrompt | Vertragstext der GPT-Pipeline (11 Dateien) — zeichengenau | S | niedrig | — |
| Hilfe-Seite | rein statisch, 5 Karten, Texte = Produkt-Doku | S | niedrig | — |

### KI / GPT-Schicht (Dossier 08)

| Feature | Kurzbeschreibung | Kompl. | Risiko | Plugins |
|---|---|---|---|---|
| Flow-Registry | 7 Flows (all/buch/marks/conn/inst/quellen/style) mit build/run/check/reference/stat/done — alle UIs sind Projektionen | L | mittel | — |
| Generate-GPT-Hub | Topbar-Popover, root/child-Hierarchie, Brand-Buttons | M | niedrig | — |
| Werkbank-Panel | rechts einfahrend (.42s), Nav + Flow-Ansicht + _system/_access | L | mittel | — |
| Magic-Dock | Ein-Klick-Kochen: Breite einfrieren, Token-Live-Zähler, Vibration, SVG-Haken; Fehler → pasteModal nahtlos | M | mittel | (HapticFeedback) |
| pasteModal/infoModal/standModal | Einfügen+Auto-Check 350ms / Konzept-Tabs / Speicherstand-Log | M | niedrig | — |
| Format-Checker | je Flow, HTML-Ergebnis → strukturiertes Modell nötig | M | niedrig | — |
| ClaudeAI-Client | fetch SSE selbst geparst, `/v1/messages` + count_tokens, Header inkl. dangerous-direct-browser-access, Single-Turn ohne System-Prompt, adaptive thinking | L | mittel | http/dio (StreamedResponse) |
| Demo-Modus | fester Text wortweise 14ms, importiert nie | S | niedrig | — |
| Zugang/Config | Key **im Klartext** in localStorage (global) → Flutter: secure storage (dokumentierte Abweichung) | S | mittel | flutter_secure_storage |
| Modelle+Preise | 5 Modelle hart codiert ($5/25 … $10/50), fmtUsd/fmtEur/fmtTok-Schwellen exakt | S | niedrig | — |

### Domänenlogik (Dossier 09)

| Feature | Kurzbeschreibung | Kompl. | Risiko | Plugins |
|---|---|---|---|---|
| Levels | Status dynamisch: save() seite/fundstelle→3, zitat→2; info()-Kaskade gespeichert>Resolution/Annotation>PDF-Mark>KI→1; 8 Farben; Export v2 | M | niedrig | — |
| Connections | 4 Quellen (KI, Fazit, Text-Regex, seltene gemeinsame Quellen Top 40), 7 Typen mit Unicode-Icons, Dedupe | M | niedrig | — |
| Mentions | Jahres-Klammer-Regex + 55-Zeichen-Fenster, Nähe-Unterdrückung 320/90, Score, Kandidaten-Gruppen, **Alt-Format-Migration** | M | niedrig | — |
| StyleCheck | 31 FILLER + 12 VAGUE-Regexes, Konnektor-Ketten, Einordnung-ohne-Beleg; Schwelle ≥1 | S | niedrig | — |
| Editor (Logik) | reconstruct/inlineToTex/lint/preview/fullDocument (report-Klasse 11pt) | L | mittel | — |
| TexParse | 14-stufige Pipeline (Meta→Pakete→Zuschnitt→Code→Kommentare→\cite→Figuren→Mathe→Fußnoten→Struktur→Registry→Diagnose), dt. Fehlertexte, PKG_OK/PKG_NOTES | XL | mittel | — (Golden-Tests!) |
| ZipUtil | Eigen-ZIP: schreiben STORE-only, lesen STORE+DEFLATE, kein ZIP64/CRC-Check | M | mittel | archive (STORE erzwingen) |

---

## 3. Modulkarte

### Ladereihenfolge (hart, index.html) = Abhängigkeitsrichtung

```
gate.js (head, blockierend)
data_*.js (5 Bundles + project_sensors)      ← reine window.DATA_*-Daten
util.js          ← Fundament: U, Indizes, Storage, richText, Modal, gptModal
claude.js        ← ClaudeAI (nutzt U.store)
enhance.js       ← Enhance (nutzt U, ClaudeAI; ruft später Views-Funktionen)
ziputil.js       ← autark
levels.js        ← U, Indizes, optional PdfEngine
texparse.js      ← autark
projects.js      ← TexParse, U.storeProject, DATA_*  (überschreibt DATA_* beim Boot!)
connections.js   ← U, Levels, Indizes, DATA_META/SECTIONS
mentions.js      ← U, DATA_SOURCES, FN_INDEX
stylecheck.js    ← U.splitSentences
pdfstore.js      ← IndexedDB (Skript-const, NICHT window.PdfStore!)
pdfengine.js     ← pdf.js-Vendor, U, PdfStore, Levels.farbHex
figures.js       ← IndexedDB figstore, U
charts.js        ← U.showTip
editor.js        ← U, Indizes; optional sourcePickerModal
views_studio.js  ← fast alles; exportiert Studio, fileShow, dockDefs, renderDetailPdf, Prompts
views_quellen.js ← U, Levels, Mentions, PdfEngine, PdfStore, ZipUtil, Projects
notebook.js      ← U, Editor.preview/lint, Charts, figureCard, Levels, Connections
views_analyse.js ← Notebook, Charts, dock*-Funktionen aus views_studio
views_projekt.js ← Projects, PdfEngine, TexParse, Enhance, importFilesModal
views_hilfe.js   ← nur U.el
app.js (letztes) ← Bootstrap + Router; ruft alle render*-Funktionen
```

**Zyklen (nur zur Laufzeit, via typeof-Guards):** Studio ↔ Enhance (Prompts/Import/routeRefresh) · Studio ↔ Editor · pdfengine → linkEditModal (views_quellen) · util → Levels/ZipUtil/PdfStore/ClaudeAI (alle optional).

### Ziel-Struktur Flutter (Feature-First)

| JS-Module | Flutter-Ordner |
|---|---|
| util.js, app.js, gate.js, theme/css | `core/` (theme/, router/, storage/, widgets/ [modal, resizer, tooltip, richtext, gpt_dialog], boot/) |
| data_*.js, tools-Schemata, projects.js (Modell) | `data/` (models/, drift/, seeds/ [Assets], project_repository) |
| levels, connections, mentions, stylecheck, texparse, ziputil, editor (Logik) | `domain/` (reine Dart-Klassen, Golden-Tests gegen JS-Output) |
| views_studio.js, editor.js (UI) | `features/studio/` (layout/, lesen/, pruefen/, editor/, refmode/, views_dock/, beleg/) |
| views_quellen.js, pdfstore.js | `features/quellen/` (library/, detail/, import/, store/) |
| pdfengine.js, figures.js | `features/pdf/` (viewer/, marks/, search/, ocr/, assign_panel/, figures/) |
| views_analyse.js, notebook.js, charts.js | `features/wissen/` (tabs/, notebook/, math/, charts/, analysemodus/) |
| views_projekt.js, views_hilfe.js, projects.js (UI) | `features/projekt/` + `features/hilfe/` |
| enhance.js, claude.js | `features/ai/` (flows/, hub/, panel/, dock/, client/) |

---

## 4. Design-Token-Referenz kompakt (Details: Dossier 02)

### Kernfarben

| Token | Light | Dark | Zweck |
|---|---|---|---|
| --bg | `#f4f2ec` | `#1e1c17` | Seiten-Hintergrund |
| --bg-deep | `#ece9e1` | `#161411` | Vertiefungen |
| --surface / -2 / -3 | `#fefdfb` / `#f9f7f1` / `#efece4` | `#27231d` / `#2e2a24` / `#39342c` | Panels/Hover |
| --border / -strong | `#ddd8cd` / `#c4beb1` | `#403a30` / `#575048` | Linien |
| --ink / -2 / --muted | `#131316` / `#3a3c43` / `#51535c` | `#f0ede5` / `#beb8ac` / `#98917f` | Text |
| --accent | `#b4552d` | `#e28a5d` | Terracotta (EINZIGER Akzent) |
| --accent-soft / -line / -ink | `#f7ebe4` / `#e3c4b2` / `#a04a26` | `#3a2a1f` / `#6e452e` / `#e69670` | Akzent-Abstufungen |
| --good / --warn / --bad | `#3f7449` / `#96702c` / `#a04b3c` | `#8fb87f` / `#cfa05e` / `#d1806f` | Ampel |
| --ki | `#54687d` | `#94aabf` | KI-Schieferblau |
| --lvl1 / 2 / 3 | `#5d7186` / =warn / =good | `#8ba1b6` / … | Beleg-Stufen |
| --wissen / -ink / -soft / -line | `#3f5d8c` / `#38537d` / `#e8edf5` / `#c2cfe3` | `#8ba7d6` / `#9db5de` / `#232a3a` / `#3e4c68` | Wissen-Welt |
| --magic-top / -edge | `#f0591a` / `#a33305` | `#f2621f` / `#8f2e04` | Magic-CTA |
| 9× --cat-* | Petrol/Ocker/Violett/… (Dossier 02 §5.2) | | Mark-Kategorien |

Wichtige Hardcodes: PDF-Seite immer `#fff`; Suchtreffer `rgba(255,193,7,.6)`; Beleg-Palette 8 Farben (gelb `#e8c33f` … rot `#cf6d5c`, levels.js); Claude-Brand `#cf6a45`, OpenAI `#10a37f`; Magic-✓ `#2e7d32`.

### Fonts (lokal, woff2 → ttf konvertieren)

| Familie | Gewichte | Einsatz |
|---|---|---|
| Inter | 400/500/600/700 | UI-Grundschrift |
| Space Grotesk | 500/700 | Display/h1/h2/Eyebrows |
| JetBrains Mono | 400/600 | Code, IDs, fn-Chips |
| Baloo 2 | 500/700/800 | Magic-Buttons |
| Nunito | 800 | (Fallback Magic) |
| **Serif: KEINE Datei** | System (Iowan/Palatino/Georgia) | Lese-/Zitatflächen, sh-title — **Flutter: Serif bündeln, Entscheidung offen** |

### Maße

Radii 4/6/8/11px (Pills 999) · Topbar 56px · Schatten 3 Stufen · Fluid: `--fs-body` clamp(15..16), `--fs-lesen` clamp(16..17.5) · 12px = Boden für Text · Breakpoints 720/900/999/1200 (+560/620/640/760/860/1199) · Z-Index-Leiter 1…9999 (Dossier 02 §4.12) · color-mix >60× → zentrale `Color.mix`-Extension.

---

## 5. Datenmodell-Überblick (Details: Dossier 10)

```
Projekt (default virtuell + IndexedDB-Records; format 'thesis-studio-projekt' v1)
 ├─ tex (Ground Truth, LaTeX-String) + registry (Quellen, aliases als Regex-STRINGS)
 ├─ parsed:    Meta ─ Kapitel("1".."6") ─ Unit (Level 2–4, children-Baum, "X.0"=Intro/isIntro)
 │               ─ Paragraph (id "<unit>-p<n>"; type text|list|table|figure; text mit [^N])
 │               ─ FootnoteRef (num global 1..397) ── n:m ── Quelle (Alias-Match)
 ├─ generated: ParagraphAnalyse (kernaussage; sentences[text=wörtlich, einfach, kategorien,
 │               marks{snippet⊂Satz, kategorie}, wichtig kern|stuetz|kontext];
 │               belege[1 je Fußnote: claim/fundstelle/suchHinweis])
 │             + Quellen-Dossiers (66/74 Fallback!) + Kapitel-Meta + gesamt (Timeline!)
 │             + fazit (13 Findings ─ n:m Units, kapitelFluss from/to-Strings)
 │             + analyse (4 Docs, note stark|solide|ausbaufaehig|schwach)
 │             + connections (von/nach {sectionId,paraId}, typ folgerung|grundlage|aufgriff|vergleich)
 │             + instanzen {defs, items[defId][paraId]=Markdown} + erklaerbuch (MD-String)
 ├─ figures:   Figuren (file nullable→Upload) + Tabellen (kopf/zeilen)
 └─ Laufzeit-Prüfstand (localStorage, projekt-gescoped): belegLevels, pdfMarks, resolutions,
    annotations, mentions-Status, edits (para/fn/title/tex), notebook, customSources, …
```

**Invarianten:** join(sentences.text)==Absatztext (validiert, sonst `_reconstruct:'abweichend'`) · mark.snippet wörtlicher Teilstring · Reihenfolge trägt Semantik (keine Order-Felder → überall `orderIndex` einführen) · Fußnoten global nummeriert in .tex-Reihenfolge · `page`+`pdfPage`=page+pageOffset(10), beide nullable · Quellen-`kind` steuert Beleglogik (recht-eu/at/online/norm → Fundstelle, sonst PDF-Seite) · stats NIE speichern, immer berechnen · **buildRuntime überschreibt beim Projektwechsel ALLE `DATA_*`-Globals — der ProjectRecord ist das kanonische Modell**. Fallback-Kaskaden: Dossier→Fallback-Template; links official = Override>doi.org>url; Erklärbuch eigen>eingebaut>Starter; Fundstelle manuell>Resolution>Dossier. Umfang eingebaute Arbeit: 6 Kapitel, 69 Units, 233 Absätze, 688 Sätze, 1369 Marks, 397 Fußnoten, 74 Quellen, ~1,6 MB JSON (als Asset bündeln → Drift-Import).

---

## 6. State-Landkarte

### localStorage — Schema `'ehds.' + (key ∈ PROJECT_KEYS ? '<projektId>.' : '') + key`; Default-Arbeit unpräfixiert; Werte JSON (Ausnahmen RAW markiert)

**Projekt-gescoped (PROJECT_KEYS-Whitelist, util.js:200 — 26 Einträge lt. Dossier 01, siehe §8/W1):**

| Key | Inhalt | Schreiber |
|---|---|---|
| belegLevels | Fußnote→{zitat,seite,fundstelle,farbe,level,ts} | levels.js |
| annotations / resolutions | manuelle Fundstellen / KI-Durchläufe je Quelle | util/enhance |
| pdfMarks | srcId→Mark[] (0..1-Rects, farbe=KEY, comment-Pin) | pdfengine |
| pdfManual / dlStatus / fileSearch / assignDismissed | PDF-Flags, Download-Status, Recherche, „passt nicht" | util/pdfengine |
| linkOverrides / srcNotes / srcTexts / srcDoc / srcExtras | Links, Notizen, Quellentexte, Doku-Typ, Material | util/views_quellen |
| customSources | manuelle Quellen (Array) | projects |
| kiConnections / textMentions | KI-Kanten / Erwähnungs-Status (mit Alt-Format-Migration!) | connections/mentions |
| paraEdits / fnEdits / titleEdits / texEdits / belegSpans | Overrides (Absatz/Fußnote/Titel/LaTeX/Spannen) | studio/editor |
| paraDock / dockBySection / marksExtra / notebook | View-Inhalte, Abschnitts-Override, Extra-Marks, Erklärbuch | studio/enhance/notebook |
| studioLast | zuletzt geöffneter Abschnitt | studio |

**Global (nicht gescoped):**

| Key | Inhalt | Anmerkung |
|---|---|---|
| ehds.activeProject | Projekt-id | **RAW-String, kein JSON** |
| ehds.gateOk | Gate-Hash | **RAW-String** |
| ehds.builtinDeleted | Tombstone-Array | |
| ehds.theme / belegstandImported | Theme, Einmal-Import-Flag | |
| ehds.ocrText | srcId→page→Text | bewusst arbeitsübergreifend |
| ehds.claudeCfg / enhCfg / instDefs | **API-Key Klartext!**, per-Flow-Config, eigene Views | Flutter: secure storage |
| ehds.pdfZoomPref | `"fit"` ODER Zahl (Typ-Mix!) | |
| ehds.qColl / qSort / uiLibPct | Bibliothek-Filter/Sortierung/Breite | |
| UI-Keys: cats, studioMode, lesenDichte, lesenFast, lesenMarks, uiDockMode, uiStyleCheck, uiSfDockClosed, uiSfDockH, uiFileOff/uiTreeOff, uiFileW/uiTreeW, uiPsW, uiRefW, uiEdPct, wissenLens | Layout-/Modus-Zustand | Resizer-Werte px bzw. % |

### IndexedDB (alle **arbeitsübergreifend** — Zwei-Ebenen-Modell beachten!)

| DB | Store | Keys | Inhalt |
|---|---|---|---|
| `ehds-pdfstore` v1 | `handles` | `'dir'` | Legacy FileSystemDirectoryHandle |
| | `blobs` | `<srcId>` · `inbox:<name>` · `img:<srcId>` · `<srcId>~x<ts36><rand>` | PDF-/Bild-Blobs, Ablage, Material |
| `ehds-projects` v1 | `projects` (keyPath id) | Projekt-ids | komplette ProjectRecords (default NIE in DB) |
| `ehds-figstore` v1 | `imgs` | figId | hochgeladene Abbildungs-Blobs |

**Export-Formate (Kompatibilität = Pflicht):** `ehds-belegstand` v2 (21 Bereiche, Feld `notes`↔Store `srcNotes`; importState prüft nur format, nicht version; truthy-Overwrite-Semantik) · `thesis-studio-projekt` v1 · `thesis-studio-dateiauftrag` v1 (ZIP) · Resolution `formatVersion:"1.0"`.

---

## 7. Kritische Konvertierungsrisiken — Top 10

| # | Risiko | Kern des Problems | Empfehlung |
|---|---|---|---|
| 1 | **PDF-Engine mit Text-Selektion + Highlight-Overlay** | pdf.js-TextLayer-Selektion → normalisierte 0..1-Rects, multiply-Blend (Dark-Sonderfall), Pins, Endlos-Scroll, viewOnly, Suche-Flash — größte Portierungshürde, Contract `mount(getActive/onCapture/onMarksChange/search/goto/refresh/destroy)` | **pdfrx** (pdfium): Selection-Rects auf 0..1 normalisieren (max 40, Ankerseite-Beschnitt), Overlay als Stack/Positioned, `BlendMode.multiply` + Dark `opacity .55`. Mark-JSON 1:1 migrierbar. Früh Prototyp bauen — alles andere im Studio hängt daran |
| 2 | **CSS Custom Highlight API + richText-Renderer** | 4 Highlights (beleg-span/gpt-style/src-view/src-view-strong) + U+0001-Sentinel-Pipeline haben kein Flutter-Pendant | Eigener TextSpan-Builder auf dem ROHEN Text (Marker→WidgetSpan-Chips, Marks/Mentions/Spannen als Hintergrund-Spans); `domRangeFor` entfällt, splitSentences-Offsets sind die Basis. Als core-Widget zuerst bauen |
| 3 | **Pyodide-/js-Rechenzellen im Erklärbuch** | `new Function` + Pyodide-CDN nicht portierbar; Starter-Buch enthält beide Zelltypen | js-Zellen via **flutter_js/QuickJS** mit nachgebauter Host-API (data/print/show/md/chart/table/figure/math); py-Zellen: UI-Rahmen behalten + klare Meldung oder WebView — Produktentscheidung dokumentieren |
| 4 | **OCR** | Tesseract.js vom CDN entfällt | google_mlkit_text_recognition (mobil) bzw. tesseract-FFI (Desktop); Cache-Format `ocrText` (srcId→page→text) + Anhänge-Präfix `[S. n — OCR]` beibehalten |
| 5 | **TexParse + Editor-Interpreter + pdfToTex** | 14-stufige Parser-Pipeline, deutsche Fehlertexte = UI; Editor.preview/lint wird vom Notebook MITBENUTZT; pdfToTex braucht per-Item-Fontgrößen | Reine Dart-Ports mit **Golden-Tests gegen JS-Ausgaben** (gleiche Eingabe → identisches JSON); EIN geteilter LaTeX-Interpreter-Service; pdfToTex als Beta hinten anstellen oder streichen |
| 6 | **Drag-Resize-Layout-System** | CSS-Grid + JS-gesetzte Custom Properties (--tree-w/--file-w/--ps-w/--sfd-h/--ref-w/--lib-list-w/--ed-w), Klemmen gegen Viewport UND CSS-Caps, Einklapp-Rails, Sticky-Spalten, Breakpoints | Ein wiederverwendbares `ResizableSplit`-Widget (Pendant zu U.resizer: min/max/dir/store/Doppelklick-Reset); Spalten = viewport-hohe Panels mit eigenem Scroll (ersetzt sticky); Klemm-Werte exakt übernehmen |
| 7 | **Storage-Namespacing + Format-Kompatibilität** | `ehds.[<proj>.]key`-Whitelist, RAW-Keys, Typ-Mixe (`pdfZoomPref`), Export-Feld-Umbenennung `notes`↔`srcNotes`, truthy-Import-Semantik — Bruch = Datenverlust bei Migration | Zentraler Key-Builder + PROJECT_KEYS-Konstante 1:1; Import/Export-Roundtrip-Tests mit echten Web-App-Exporten; Scope setzen VOR Runtime-Aufbau (Boot-Reihenfolge) |
| 8 | **CRC32/srcHash-Bitkompatibilität + ZIP** | `ts-`+CRC32hex8(norm(titel)\|autor\|jahr) ist Identität des Datei-Auftrags; bestehende ZIP-Rückläufe müssen matchen | CRC32 (Polynom 0xedb88320) + NFD-Diakritika-Strip exakt in Dart; Testvektoren aus dem Original generieren; package:archive mit STORE erzwungen |
| 9 | **`location.reload()` als Architektur-Muster** | Arbeitswechsel/Analysen-Import/Belegstand-Import/Quelle-löschen erzwingen App-Neustart; DATA_*-Globals werden komplett überschrieben; Caches (`_hashCache`, `pdfStatusCache`) teils NICHT geleert | Kompletter Provider-Graph-Reset als expliziter „Reboot"-Flow (alle Caches, Panels, Scrollstände verwerfen); den Original-Cache-Bug dabei bewusst fixen (dokumentieren) |
| 10 | **Unicode-Symbole & Fonts** | ⭳⭱＋(U+FF0B)⌖⌗◌❝❞⇤⇥∅⤳◐ etc. sind Text, Emoji-Flaggen 🇪🇺🇦🇹 rendern auf Windows nicht; Serif-Font hat keine Datei; Baloo-500/Nunito-800-Fallback-Sprung | Noto Sans Symbols 2 als Fallback-Font bündeln; Flaggen ggf. als Assets; kanonischen Serif festlegen (z. B. PT Serif); Font-Smoke-Test aller Glyphen auf allen Targets |

Weitere nennenswerte (11–15): SSE-Streaming-Client + Abort-Semantik (StreamedResponse + cancel) · Magic-Dock-Animationssignatur (Breite einfrieren, SVG-Haken, Vibrationsmuster [10,40,10] ohne exaktes iOS-Pendant) · backdrop-filter-Blur-Performance · window.print()/`#/doc` → printing-Package · File-System-Access-Legacy-Ordner (weglassen, im Original schon Altbestand).

---

## 8. Offene Widersprüche & Lücken (dossierübergreifend)

**Widersprüche zwischen Dossiers / im Original:**

1. **W1 — PROJECT_KEYS-Anzahl:** Dossier 01 sagt „genau 26 Keys", Dossier 07 „25 Keys" — die Listen sind identisch (26 Einträge beim Nachzählen); Dossier 07 hat sich verzählt. Vor Implementierung an util.js:200 verifizieren.
2. **W2 — Doku ≠ Realdaten (3 Stellen, Dossier 10):** PROJEKT-FORMAT.md nennt Timeline-Feld `typ`, real sind es `kategorie:at|eu` + `status:erledigt|offen`; kapitelFluss lt. Doku `von/nach` (Zahlen), real `from/to` (Strings); Kategorien-Enum lt. Doku 7 Werte, real zusätzlich `kontext/schlag/abk`. **charts.js + Realdaten sind der Vertrag**; Import fremder Dateien beide Varianten tolerant lesen.
3. **W3 — `DATA_META.connections`:** existiert nur bei Instanz-Arbeiten (buildRuntime setzt es), NICHT im Bundle der eingebauten Arbeit — alle Konsumenten müssen null-tolerant sein; wie connections.js die Default-Arbeit versorgt, ist nur über die 4-Quellen-Logik (ohne KI-Bundle) abgedeckt.
4. **W4 — Modus-Label:** Header-Kommentar in views_studio.js sagt „⌖ Prüfen", gerendert wird „◉ Analyse" (interner Modus-Name bleibt `pruefen`). Maßgeblich: `Studio.MODES`-Labels.
5. **W5 — Zwei Fallback-Dossier-Templates + zwei kindLabels-Varianten** (build_data.js:68 ausführlich vs. projects.js:226 kurz; kindLabels-Fallback weicht ab). Festlegen: Bundle-Variante für die eingebaute Arbeit unverändert übernehmen, projects.js-Variante für Instanz-Arbeiten.
6. **W6 — connections.js-Kommentar** nennt 3 Verbindungs-Quellen, der Code hat 4 (gemeinsame seltene Quellen fehlen im Kommentar). Code gilt.
7. **W7 — Export-Feld `notes`** speist sich aus Store-Key `srcNotes` (einzige Umbenennung im Belegstand-Format) — leicht zu übersehende Kompatibilitätsfalle.
8. **W8 — `gptPromptForSource`** codiert „Bachelorarbeit über den EHDS" hart — inhaltlich falsch für fremde Arbeiten. Entscheidung: 1:1 übernehmen (Bug-Parität) oder projektabhängig machen (dokumentierte Abweichung).
9. **W9 — Editor-Randfall:** „＋ Quelle" fügt `\cite{id}` ein, aber `\cite` ist nicht in `ALLOWED` → Lint meldet sofort Fehler. Ist-Verhalten des Originals; bewusst übernehmen oder fixen.
10. **W10 — Resolution-Schema** hart auf `footnote ≤ 397` (die EHDS-Arbeit) kodiert — in Flutter dynamisch gegen die Fußnotenzahl der aktiven Arbeit validieren.

**Lücken / vor dem Nachbau zu verifizieren:**

11. **L1 — Timeline/Legende unstyled:** `.tl-*`, `.viz` (Container), `.legend`, `.li`, `.sw` haben KEINE CSS-Regeln — Fristen-Timeline und fazitGraph-Legende rendern im Original als ungestylte Divs. **IST-Optik per Screenshot festhalten**, nicht eine „gedachte" Timeline erfinden.
12. **L2 — Stale Caches:** `U._hashCache` und `U.pdfStatusCache` werden in `rebuildDataIndexes` nicht geleert (potenziell stale nach Projektwechsel mit customSources); `FigStore._urls` revoked nie. Beim Port bewusst fixen und als Abweichung dokumentieren.
13. **L3 — `cfBuzz`-Keyframes** in CSS definiert, Zuweisung per JS — konkreter Verwendungsort in keinem Dossier verifiziert.
14. **L4 — pdf.js-Vendor-Version** nicht exakt bestimmt (minifiziert, API-Bereich 3.x–4.x) — irrelevant, wenn pdfrx genutzt wird.
15. **L5 — `analyse.kriterien.note` = `schwach`** laut Doku möglich, kommt in Realdaten nie vor — UI-Styling dafür ungeprüft.
16. **L6 — `Notebook.get(projectAware)`-Parameter** ist toter Code (wird ignoriert) — nicht nachbauen.
17. **L7 — Überblick-Breakpoint ≤900px** wird nur einmalig beim Render ausgewertet (kein Live-Resize) — Original-Bug; in Flutter via LayoutBuilder automatisch korrekt (Verbesserung dokumentieren).
18. **L8 — Mobile ≤720px:** Original „stapelt" nur (keine echte Master-Detail-Navigation in der Bibliothek, kein Mobile-Drag&Drop) — Mobile-UX-Entscheidungen für Flutter offen.
19. **L9 — Timing-Hacks:** ctl.search-Polling (20×200ms), 50ms/800ms/1200ms/1800ms-Timeouts — in Flutter durch Futures ersetzen, sichtbare Feedback-Zeiten (✔ kopiert 900–1800ms) aber exakt übernehmen.
20. **L10 — Kanonischer Serif-Font** (--font-serif ohne Datei) und **Demo-/Preis-Konstanten-Update-Pfad** (Modell-IDs/Preise sind Momentaufnahme) — Produktentscheidungen vor Umsetzung treffen.

---

*Erstellt am 2026-07-23 aus den Dossiers 01–10. Bei Konflikten gilt: Realcode/Realdaten > Dossier > Doku (docs/*.md).*
