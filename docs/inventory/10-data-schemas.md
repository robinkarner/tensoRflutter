# Dossier 10 — Datenmodell & Schemas (js/data-Bundles, data/parsed, data/generated, Docs, Build-Tools)

Inventar für die 1:1-Flutter-Konvertierung von "Thesis Studio" (thesoR).
Gegenstand: das **komplette Datenmodell** der App — alle Entitäten, IDs, Beziehungen, Dateiformate, Build-Pipeline. Grundlage für das Drift/SQLite-Schema.

Untersuchte Dateien:

| Datei | Größe | Inhalt |
|---|---|---|
| `js/data/data_thesis.js` | 199 KB, 1 Zeile | `window.DATA_THESIS` — Struktur + Originaltext der Arbeit |
| `js/data/data_sections.js` | 598 KB, 1 Zeile | `window.DATA_SECTIONS` — GPT-Satzauflösungen je Abschnitt |
| `js/data/data_sources.js` | 387 KB, 1 Zeile | `window.DATA_SOURCES` — 74 Quellen mit Dossiers + Zitierstellen |
| `js/data/data_meta.js` | 72 KB, 1 Zeile | `window.DATA_META` — Kapitel-Zusammenfassungen, Gesamt, Fazit, Analyse, Stats, Erklärbuch, Instanzen |
| `js/data/data_figures.js` | 4,6 KB, 1 Zeile | `window.DATA_FIGURES` — Abbildungs-/Tabellen-Manifest |
| `js/data/project_sensors.js` | 356 KB, 5 Zeilen | `window.BUILTIN_PROJECTS` — eingebaute Zweitarbeit (LLNCS-Paper, EN) |
| `data/parsed/*` | JSON | deterministischer Parser-Output (Ground Truth) |
| `data/generated/*` | JSON/MD | GPT-Voranalyse |
| `data/figures.json`, `data/resolutions/*` | JSON | Manifeste / Nachlade-Analysen |
| `docs/PROJEKT-FORMAT.md`, `docs/ERKLAERBUCH.md`, `docs/QUELLEN-WORKFLOW.md`, `docs/resolution.schema.json` | MD/JSON | Formatvorgaben |
| `tools/parse_thesis.js` (282 Z.), `tools/build_data.js` (194 Z.) | JS | Build-Pipeline |

---

## 1. Zweck & Rolle

**`js/data/data_thesis.js`** — Statisches Bundle mit der kompletten geparsten Bachelorarbeit ("Primärnutzung von Gesundheitsdaten im EHDS"): Meta → 6 Kapitel → 24 Sektionen (Level 2) → 43 Subsektionen (Level 3) → 2 Subsubsektionen (Level 4) → 233 Absätze → 397 Fußnoten. Der Text ist die **Ground Truth** der App (Lesen-Ansicht, Studio, alles). Fußnotenmarker stehen inline als `[^N]` im Absatztext. Wird von `tools/build_data.js` aus `data/parsed/thesis.json` 1:1 erzeugt (build_data.js:178).

**`js/data/data_sections.js`** — GPT-Voranalyse je Abschnitt: für jeden der 68 inhaltstragenden Abschnitte (Key = Section-ID mit Unterstrichen, z. B. `3_2_2_1`) eine Zerlegung jedes Absatzes in **Kernaussage, Sätze (mit einfacher Erklärung, Kategorien, Markierungen, Wichtigkeit)** und **Belege** (je Fußnote: Claim, Fundstelle, Suchhinweis). 688 Sätze, 397 Belege. Treibt die Studio-Ansicht (Satz-Modus, Marker-Highlights, Einfach-Erklärungen) und die Beleg-Prüfung.

**`js/data/data_sources.js`** — Array der 74 Quellen: bibliografische Metadaten (aus `tools/source-registry.js`), alle Zitierstellen (`citations` roh, `stellen` mit Beleg-Anreicherung), Markdown-`dossier`, `keyPoints`, `zitierweise`, Link-Vorschläge. 8 Quellen haben ein handgeschriebenes Dossier (`data/generated/sources/*.json`), 66 einen automatisch generierten Fallback (`dossierFallback: true`, siehe build_data.js:68-93, build-warnings.json).

**`js/data/data_meta.js`** — Aggregat aller "Analyse"-Inhalte: `kapitel` (6 Kapitel-Zusammenfassungen), `gesamt` (Executive Summary, roter Faden, Ergebnisse, Timeline), `fazit` (13 Findings + Kapitel-Fluss-Graph), `analyse` (4 Bewertungs-Dokumente), `stats` (deterministisch berechnete Kennzahlen), `erklaerbuch` (komplettes Markdown-Buch als String, ~183 Zeilen) und `instanzen` (hier `null`; nur die Sensors-Arbeit liefert welche).

**`js/data/data_figures.js`** — Manifest der 4 Abbildungen + 2 Tabellen der Arbeit, verknüpft mit `sectionId`/`paragraphId`/`quelle`. `file` ist `null`, wenn die Bilddatei fehlt (build_data.js:185-187 nullt fehlende Dateien und warnt) — App zeigt dann Platzhalter mit Upload.

**`js/data/project_sensors.js`** — Automatisch erzeugt von `tools/build_sensors_project.js` (Kopfkommentar Zeile 1-2). Hängt an `window.BUILTIN_PROJECTS` ein komplettes **Projekt-Instanz-Objekt** an: die englische Zweitarbeit "Mobile Sensors in Education (Paper)" mit rohem `tex` (50 KB LLNCS-LaTeX), `registry` (24 Quellen mit String-Aliassen), `parsed` (thesis/footnotes/sources), `generated` (sections/sources/chapters/gesamt/fazit/analyse/connections/instanzen/erklaerbuch) und `figures` (leer). Wird beim Boot in IndexedDB geseedet (projects.js:66-80) und beim Aktivieren via `Projects.buildRuntime()` in die `window.DATA_*`-Globals eingespielt (projects.js:154-224).

**`data/parsed/*`** — Output von `tools/parse_thesis.js`: `thesis.json` (identisch mit DATA_THESIS), `footnotes.json` (flache Liste aller 397 Fußnoten mit Fundort), `sources.json` (Quellen + rohe `citations`, ohne Dossier/Links/Stellen), `sections/<id>.json` (68 Einzelabschnitte als Agenten-Input, mit `title`/`chapter`/`chapterTitle`/`page`/`pdfPage` — Felder, die die generierte Fassung NICHT hat).

**`data/generated/*`** — GPT-Voranalyse (Eingabe für build_data.js): `sections/<id>.json` (68 Stück, identisches Schema wie DATA_SECTIONS-Werte), `sources/<id>.json` (8 Dossiers), `chapters/kapitel-1..6.json` + `gesamt.json`, `fazit-connections.json`, `analyse/{standards,struktur,quellen,inhalt}.json`, `erklaerbuch.md`, `build-warnings.json` (Array von Warn-Strings).

**`docs/PROJEKT-FORMAT.md`** — Die maßgebliche Formatvorgabe (241 Zeilen), die per "Master-Prompt kopieren" an ein GPT-Modell geht, um für eine neue Arbeit den `data/generated/`-Ordner zu erzeugen. Definiert alle generierten Schemata inkl. harter Validierungsregeln (Zeilen 87-94) und der 3-Schichten-Architektur (Zeile 8-17: parsed / generated / Laufzeit-Zustand im Browser).

**`docs/ERKLAERBUCH.md`** — Referenz des Erklärbuch-Formats (127 Zeilen): EIN Markdown-Dokument mit eingebetteten Blöcken ```chart/```table/```latex/```figure/```include/```math/```js/```py und dem `data`-Datenpaket (Zeilen 98-111) für Rechenzellen.

**`docs/QUELLEN-WORKFLOW.md` + `docs/resolution.schema.json`** — 3 Ausbaustufen je Quelle (nichts → PDF → PDF+Resolution) und das JSON-Schema der **Resolution** (Nachlade-Analyse eines Quell-PDFs). Vorrangregel (QUELLEN-WORKFLOW.md:74-75): manuelle Fundstellen > Resolution-Datei > vorab generiertes Dossier.

**`tools/parse_thesis.js`** — Deterministischer LaTeX-Parser (kein LLM): extrahiert brace-aware `\footnote{}` (Zeilen 35-53), bereinigt LaTeX-Makros (`cleanTex`, Zeilen 57-81), splittet an `\chapter/\section/\subsection/\subsubsection` (Zeile 87), erzeugt Absätze/Listen/Platzhalter (Zeilen 98-127), nummeriert Kapitel selbst durch, matcht Fußnoten per Regex-Aliassen auf Quellen (Zeilen 182-188), reichert Seitenzahlen aus der Hardcode-Tabelle `TOC_PAGES` + `PAGE_OFFSET=10` an (Zeilen 15-32, 216-227), schreibt `data/parsed/*`.

**`tools/build_data.js`** — Validator + Bundler: liest parsed + generated, prüft (a) Satz-Rekonstruktion `join(sentences.text) === paragraph.text` (Zeile 38-41, bei Abweichung `gp._reconstruct='abweichend'`), (b) `marks[].snippet` muss Teilstring des Satzes sein (ungültige werden **entfernt**, Zeile 43-51), baut den `belegIndex` (Fußnote → Beleg, Zeilen 58-63), merged Quellen + Dossier/Fallback + Links (`tools/source-links.js`) + `stellen` (Zeilen 100-124), berechnet `stats` deterministisch (Zeilen 149-172), schreibt die 5 Bundles als `window.X = <JSON>;` (Zeilen 174-188) und `build-warnings.json`.

---

## 2. Öffentliche API (window-Globals)

### Von diesen Modulen exportiert

| Global | Typ | Quelle | Konsumenten (js/) |
|---|---|---|---|
| `window.DATA_THESIS` | Objekt `{meta, chapters}` | data_thesis.js:1 | app.js, util.js, views_studio.js, editor.js, levels.js, mentions.js, connections.js, notebook.js, enhance.js, views_analyse.js, figures.js (29 Referenzen) |
| `window.DATA_SECTIONS` | Objekt `{ "1_1": Section, … }` (68 Keys) | data_sections.js:1 | views_studio.js, levels.js, util.js, projects.js (9 Referenzen) |
| `window.DATA_SOURCES` | Array\<Source\> (74) | data_sources.js:1 | views_quellen.js, util.js, mentions.js, notebook.js, projects.js (23 Referenzen) |
| `window.DATA_META` | Objekt `{kapitel, gesamt, fazit, analyse, stats, erklaerbuch, instanzen}` | data_meta.js:1 | views_analyse.js, notebook.js, connections.js, projects.js (22 Referenzen) |
| `window.DATA_FIGURES` | Objekt `{figuren, tabellen}` | data_figures.js:1 | figures.js, views_studio.js (7 Referenzen) |
| `window.BUILTIN_PROJECTS` | Array\<ProjectRecord\> (append-Pattern: `(window.BUILTIN_PROJECTS \|\| []).concat([...])`) | project_sensors.js:3 | projects.js (`seedBuiltins`, projects.js:66) |

### Abgeleitete Globals (setzt projects.js beim Boot, aus diesen Daten)

| Global | Inhalt | Gesetzt in |
|---|---|---|
| `window.PROJECT_ERKLAERBUCH` | Markdown-String des eingebauten Erklärbuchs oder `null` | projects.js:57 (default: aus `DATA_META.erklaerbuch`), projects.js:161 (Instanz: aus `generated.erklaerbuch`) |
| `window.PROJECT_INSTANZEN` | `{defs, items}` oder `null` | projects.js:58 / projects.js:160 |

**Wichtig für Flutter:** Bei einer aktiven Nicht-Default-Arbeit werden **alle** `DATA_*`-Globals von `Projects.buildRuntime(rec)` (projects.js:154-224) **überschrieben** — d. h. das Datenmodell des Projekts-Records ist das eigentliche kanonische Modell; die statischen Bundles sind nur die Materialisierung der eingebauten Arbeit. Unterschied: `buildRuntime` setzt zusätzlich `DATA_META.connections` (projects.js:213), während `build_data.js` für die eingebaute Arbeit **kein** `connections`-Feld in DATA_META schreibt (build_data.js:181 — die EHDS-Arbeit hat keine `generated/connections.json`).

---

## 3. State & Persistenz

Diese Module selbst sind **statisch/read-only**. Persistenz der Datenmodell-Ebene:

### Dateisystem (Build-Zeit)
- `data/parsed/{thesis,footnotes,sources}.json`, `data/parsed/sections/<id>.json` — geschrieben von parse_thesis.js:249-272, gelesen von build_data.js:16-18,28-31.
- `data/generated/**` — von GPT/Hand erzeugt, gelesen von build_data.js; `build-warnings.json` geschrieben von build_data.js:194.
- `js/data/*.js` — die 5 Bundles + project_sensors.js; von `index.html` als `<script>` geladen.
- `data/resolutions/<sourceId>.json` — optionale Nachlade-Analysen; im HTTP-Modus beim Öffnen eines Dossiers automatisch nachgeladen (QUELLEN-WORKFLOW.md:35-38). Nur `beispiel.cobrado2024.json.example` vorhanden.

### IndexedDB (Laufzeit, projects.js:23-30)
- DB **`ehds-projects`**, Version 1, ObjectStore **`projects`** (keyPath `id`).
- Enthält ProjectRecords (Schema siehe §7.9). Die eingebaute Sensors-Arbeit wird beim Boot hineingeseedet; Update nur wenn `builtinVersion` größer und `userModified` nicht gesetzt (projects.js:73-79).

### localStorage (Keys mit Bezug zum Datenmodell)
Alle App-Keys haben Präfix `ehds.`; projekt­gebundene Keys werden mit der Projekt-ID gescoped: `ehds.<projectId>.<key>` (util.js:199-210, `U.storeProject` + `U.PROJECT_KEYS`). Für die Default-Arbeit ohne Projekt-Segment: `ehds.<key>`.

| Key | Form | Zweck |
|---|---|---|
| `ehds.activeProject` | String, z. B. `"default"`, `"sensors-paper"` | aktive Arbeit (projects.js:21,38,49,96) |
| `ehds.builtinDeleted` | JSON-Array von Projekt-IDs | Tombstones gelöschter Builtin-Arbeiten (projects.js:70, views_projekt.js:309-311) |
| `ehds.[<pid>.]customSources` | Array von Custom-Source-Objekten | manuell hinzugefügte Quellen, beim Boot in `DATA_SOURCES` gemerged (projects.js:240-256) |
| `ehds.[<pid>.]resolutions` | `{ <sourceId>: Resolution }` | importierte Resolution-Dateien (util.js:226-230) |
| `ehds.[<pid>.]annotations` | `{ <sourceId>: [Fundstellen] }` | manuell eingetragene Fundstellen (util.js:214-222) |
| `ehds.[<pid>.]linkOverrides` | `{ <sourceId>: {official,file} }` | überschreibt `links`-Vorschläge (util.js:238-251) |
| weitere (`fileSearch`, `ocrText`, `belegSpans`, `fnEdits`, `dlStatus` …) | | Laufzeit-Prüfstand — Details im util.js-Dossier |

Der "Belegstand"-Export (PROJEKT-FORMAT.md:16-17, QUELLEN-WORKFLOW.md:118-121) sichert diesen Laufzeit-Zustand als eine JSON-Datei; er übersteht jeden Rebuild.

### In-Memory
Nach Boot leben alle Daten als globale JS-Objekte (`window.DATA_*`); keine Mutationen der Bundles außer: `mergeCustomSources` pusht in `DATA_SOURCES` (projects.js:243), build_data nullt fehlende `figures[].file`.

---

## 4. UI-Struktur & Layout

Diese Module rendern **kein UI** — sie sind reine Datencontainer. Die UI-Dossiers der jeweiligen Views (views_studio, views_quellen, views_analyse, figures, notebook) beschreiben die Darstellung. Für das Datenmodell relevant sind nur zwei Render-Verträge, die Feldnamen erzwingen:

- **Timeline** (charts.js:142-160): liest `datum` (ISO), `label`, `kategorie` (`'at'` → Farbe `var(--cat-tech)` + "🇦🇹 Österreich", sonst `var(--accent)` + "🇪🇺 EU"), `status` (`'erledigt'` → gefüllter Punkt "✔ erledigt", sonst "○ offen").
- **Kapitel-Fluss** (charts.js:30-60): liest Kanten `{from, to, label}` (Strings "1".."6"); Bogen-Kanten nur bei Abstand > 1, Nachbarn haben feste Pfeile.

---

## 5. Design-Rohwerte (in den Daten enthaltene UI-Konstanten)

- **Kategorie-Farb-Tokens** in `instanzen.defs[].color`: CSS-Variablen als String, z. B. `"var(--cat-tech)"`, `"var(--cat-these)"`; laut PROJEKT-FORMAT.md:169-170 auch `var(--good)`, `var(--accent-ink)` oder Hex-Werte erlaubt.
- **Instanz-Labels mit Emoji** (project_sensors.js, `generated.instanzen.defs`): `"📡 Sensor-Brille"`, `"🎓 Prüfungsfrage"`. Instanz-Inhalte nutzen Farb-Emojis als Sensor-Kategorie-Chips: `🟦` räumlich-zeitlich, `🟥` physiologisch, `🟩` verhaltensbasiert, `🟨` audiovisuell.
- **Timeline-Flaggen** (charts.js): `🇦🇹 Österreich`, `🇪🇺 EU`, `✔ erledigt`, `○ offen`; Legende wörtlich: `"🇪🇺 EU-Frist"`, `"🇦🇹 nationaler Termin"`, `"● gefüllt = erledigt · ○ Ring = offen"`.
- **Kind-Labels** (`DATA_META.stats.kindLabels`, build_data.js:162): `artikel: "Peer-Review-Artikel"`, `konferenz: "Konferenzbeitrag"`, `norm: "Norm"`, `report: "Report/Bericht"`, `online: "Online-Quelle"`, `recht-eu: "Rechtsquelle EU"`, `recht-at: "Rechtsquelle AT"`. (Fallback-Variante in build_data.js:65 weicht ab: `report: "Report/amtlicher Bericht"`, `recht-eu: "EU-Rechtsakt"`, `recht-at: "österreichische Rechtsquelle"` — wird nur im Fallback-Dossier-Text verwendet.)
- **Erklärbuch-Titel** (DATA_META.erklaerbuch): beginnt `"# 📓 Erklärbuch — Primärnutzung von Gesundheitsdaten im EHDS"`.
- **Fußnotenmarker-Syntax** im Text: `[^N]` (N = 1..397) — muss beim Rendern in hochgestellte Marker übersetzt werden.
- Meta der Arbeit wörtlich (data_thesis.js meta): Titel `"Primärnutzung von Gesundheitsdaten im EHDS"`, Untertitel `"Analyse der technologischen und regulatorischen Integration in das österreichische Gesundheitssystem"`, Autor `"Robin Karner"`, Universität `"Technische Universität Wien"`, Datum `"15. Juli 2026"`.

---

## 6. Verhalten & Interaktionen (Datenfluss-Logik)

### 6.1 Build-Pipeline (Reihenfolge)
1. `node tools/parse_thesis.js` — `.tex` → `data/parsed/` (Struktur, Fußnoten, Quellenregister mit Zitierstellen). Konsistenz-Checks: Fußnoten ohne Quellen-Match / ohne Absatz-Zuordnung (parse_thesis.js:274-282).
2. `node tools/build_data.js` — parsed + generated + figures + source-links → `js/data/*.js`. Validierungen s. §1; fehlende generierte Dateien ⇒ nur Warnung + Fallback (Dossier-Fallback, Platzhalter).
3. Browser-Boot (`Projects.boot()`, projects.js:20-61): activeProject lesen → IndexedDB öffnen → Builtins seeden → ggf. `buildRuntime(rec)` (überschreibt `DATA_*`) → `U.storeProject` setzen (**vor** dem Laufzeitaufbau, Kommentar projects.js:39-41) → `PROJECT_ERKLAERBUCH`/`PROJECT_INSTANZEN` → `mergeCustomSources()`.

### 6.2 Fehler-/Randfälle
- Aktive Arbeit nicht in IndexedDB ⇒ Warnung "Aktive Arbeit „X" nicht gefunden — zurück zur eingebauten Arbeit." + Reset auf `default` (projects.js:34-37).
- `buildRuntime` wirft ⇒ Warnung "Arbeit „NAME" ist nicht ladbar (MSG) — zurück zur eingebauten Arbeit. Fehlerhafte Analyse-Dateien über „⭱ Analysen" erneut importieren." (projects.js:46).
- Fehlende Section-Auflösung ⇒ Warnung `Auflösung fehlt: <id>`; fehlender Absatz in Auflösung ⇒ `"<id>: Absatz <pid> fehlt in Auflösung"`; ungültiger Mark ⇒ `"<id> <pid>: mark-Snippet nicht im Satz: …"` (build_data.js:32,36,48).
- Satz-Rekonstruktion weicht ab ⇒ `paragraph._reconstruct = "abweichend"` bleibt im Bundle (build_data.js:40) — UI kann das anzeigen.
- Abbildung fehlt auf Disk ⇒ `file: null` + Warnung `"Abbildung fehlt auf Disk: <pfad>"` (build_data.js:186).
- Import einer Arbeit mit existierender ID ⇒ `confirm("… Überschreiben? (Abbrechen = als Kopie importieren)")`, Kopie bekommt Suffix `-kopie-<rand3>` (projects.js:272-278).
- `applyGeneratedFile` (projects.js:130-151) routet importierte Analyse-Dateien **per Dateiname**: `^\d+(_\d+)*\.json$` → Section; `kapitel-(\d+).json` → Kapitel; `gesamt.json`, `fazit-connections.json` (braucht `findings`-Array), `connections.json` (braucht `connections`-Array), `struktur|quellen|inhalt|standards.json`, `instanzen.json` (braucht `defs`-Array), `figures.json`, `registry.json` (muss Array sein); inhaltsbasiert: Objekt mit `sourceId`+`dossier` → Quellen-Dossier; Objekt mit `sectionId`+`paragraphs` → Section. Jeder Import setzt `userModified = true`.

### 6.3 Resolution-Workflow (Quellen-Nachladung)
Stufen 0/1/2 (QUELLEN-WORKFLOW.md:5-11). PDF muss exakt `sources/<id>.pdf` heißen. Drei Erkennungswege: File-System-Access-Ordner, Datei-Upload in Browser-Speicher, HTTP-Server. Resolution per Datei `data/resolutions/<id>.json` (Auto-Nachladung im HTTP-Modus) oder ⬆-Import. Anzeige-Vorrang: manuell > Resolution > Dossier.

---

## 7. Datenformen (vollständige Schemata mit realen Beispielen)

### ID-Formate (überall gleich)

| Entität | Format | Beispiele |
|---|---|---|
| Kapitel-ID | String der Nummer | `"1"` … `"6"` (Sensors-Paper: auch `"0"` = Abstract) |
| Sektions-/Unit-ID | Punkt-getrennt, `<kap>.<sek>[.<sub>[.<subsub>]]`; Kapitel-Intro = `<kap>.0` | `"1.1"`, `"2.0"`, `"3.2.2.1"` |
| Datei-/Map-Key einer Sektion | Punkte → Unterstriche | `"3_2_2_1"`, Datei `3_2_1.json` |
| Absatz-ID | `<unitId>-p<n>` (n ab 1, je Unit) | `"1.1-p2"`, `"3.3.2-p4"` |
| Fußnote | globale Ganzzahl 1..397 (Reihenfolge im .tex) | `97` |
| Quellen-ID | lowercase, `[a-z0-9-]`; Artikel `autorjahr`, Rechtsakte sprechend | `"cobrado2024"`, `"ehds-vo"`, `"rh-elga2024"`, `"gtelg2012"`; Sensors: `"abowd_towards_1999"` (mit Unterstrichen!) |
| Abbildung/Tabelle | `abb-<sek-mit-bindestrichen>` / `tab-…`; Anzeige-`nummer` separat | `"abb-3-3-2"` + `"Abb. 3.1"`, `"tab-4-4-2"` + `"Tab. 4.1"` |
| Finding | `f<n>` | `"f1"`…`"f13"` |
| Connection | frei, kurz | `"c1"`, `"s1"` |
| Instanz-Definition | slug | `"sensorblick"`, `"pruefungsfrage"` |
| Projekt | `"default"` (implizit, nicht in DB), Builtin-Slug, `p-<name-slug≤30>-<rand4>`, `p-import-<rand6>` | `"sensors-paper"` (projects.js:107-108, 271) |

### 7.1 DATA_THESIS (= data/parsed/thesis.json)

```jsonc
{
  "meta": {
    "title": "Primärnutzung von Gesundheitsdaten im EHDS",
    "subtitle": "Analyse der technologischen und regulatorischen Integration…",
    "author": "Robin Karner",
    "university": "Technische Universität Wien",
    "date": "15. Juli 2026",
    "thesisPdf": "sources/thesis.pdf",     // Pfad zum Arbeits-PDF
    "pageOffset": 10                        // gedruckte Seite + offset = physische PDF-Seite
  },
  "chapters": [{                            // 6 Stück
    "id": "1", "num": 1, "title": "Einleitung",
    "page": 1, "pdfPage": 11,               // number|null (aus TOC_PAGES)
    "sections": [{                          // Level-2-Einheiten, 24 gesamt
      "id": "1.1", "title": "Aufgabenstellung", "level": 2,
      "page": 1, "pdfPage": 11,
      "isIntro": true,                      // OPTIONAL (5/24) — nur bei "<kap>.0"-Überblickssektionen; Titel dann "Überblick"
      "paragraphs": [ /* Paragraph, s. u. */ ],
      "children": [{                        // Level-3, 43 gesamt; rekursiv Level-4 (2 Stück: 3.2.2.1, 3.2.2.2)
        "id": "2.1.1", "title": "…", "level": 3, "page": 6, "pdfPage": 16,
        "paragraphs": [...], "children": [...]
      }]
    }]
  }]
}
```

**Paragraph (parsed)** — 4 Typen (`type`):

```jsonc
// type "text" (226 von 233):
{ "id": "1.1-p1", "type": "text",
  "text": "…Fließtext mit Markern.[^1]",     // Pflicht bei text/table/figure
  "footnotes": [ /* pro im Text vorkommendem Marker, in Reihenfolge */
    { "num": 1,
      "text": "Verordnung (EU) 2025/327 des Europäischen Parlaments…",  // bereinigter Fußnotentext
      "sources": ["ehds-vo", "cra", "rl-2011-24"] } ] }                 // 0..n Quellen-IDs (Alias-Match)

// type "list" (4 Stück): statt text →
{ "id": "2.1.1-p4", "type": "list",
  "items": ["legislative oder nicht-legislative Maßnahmen, …", "…"],    // Strings, können [^N] enthalten
  "footnotes": [] }

// type "table" (2) und "figure" (1): text = Platzhalterbeschreibung aus [TABELLE: …]/[ABBILDUNG: …]
{ "id": "4.4.2-p3", "type": "table", "text": "Situationen des Berechtigungssystems — …", "footnotes": [] }
```

Statistik: 6 Kapitel, 69 Units (24+43+2), 68 mit Absätzen, 233 Absätze, 397 Fußnoten, 75/354/8 Quellen-Referenzen je Ebene (Mehrfachquellen pro Fußnote möglich, z. B. Fußnote 1 → 3 Quellen).

### 7.2 data/parsed/footnotes.json (flach)

```jsonc
[ { "num": 1, "text": "Verordnung (EU) 2025/327 …",
    "sectionId": "1.1", "paragraphId": "1.1-p2" } ]   // 397 Einträge; sectionId/paragraphId = Fundort
```

### 7.3 data/parsed/sections/<id>.json (Agenten-Input; NUR hier: title/chapter/page)

```jsonc
{ "sectionId": "1.1", "title": "Aufgabenstellung",
  "chapter": 1, "chapterTitle": "Einleitung",
  "page": 1, "pdfPage": 11,
  "paragraphs": [ /* wie 7.1 Paragraph */ ] }
```

### 7.4 DATA_SECTIONS (= data/generated/sections/<id>.json, 68 Keys `1_1`…`6_0`)

```jsonc
{ "sectionId": "1.1",
  "paragraphs": [{
    "id": "1.1-p2", "type": "text",              // gleiche 4 Typen wie parsed
    "kernaussage": "Die EHDS-Verordnung (EU) 2025/327 schafft einen unmittelbar geltenden EU-Rechtsrahmen…",  // 1 Satz, immer da
    "beschreibung": "…",                          // OPTIONAL (3/233) — nur bei table/figure-Absätzen
    "sentences": [{                               // je Satz des Originalabsatzes; bei list: je item; bei table/figure: leer []
      "text": "Auf europäischer Ebene schafft die Verordnung (EU) 2025/327 (EHDS-Verordnung)[^1] …",  // WÖRTLICH inkl. [^N]-Marker; join aller texts == Absatztext (validiert)
      "einfach": "Die EU hat mit der Verordnung 2025/327 den europäischen Gesundheitsdatenraum … geregelt. …",  // einfache Sprache
      "kategorien": ["norm"],                     // Satz-Kategorien, Enum s. u.
      "marks": [{                                 // Markierungen (wörtliche Teilstrings, validiert)
        "snippet": "Verordnung (EU) 2025/327 (EHDS-Verordnung)",
        "kategorie": "norm" }],
      "wichtig": "kern"                           // "kern" | "stuetz" | "kontext" (Ampel der Satz-Wichtigkeit)
    }],
    "belege": [{                                  // genau 1 Eintrag je Fußnote des Absatzes (397 gesamt)
      "num": 1,                                   // Fußnotennummer
      "quellen": ["ehds-vo", "cra", "rl-2011-24"],
      "claim": "Belegt mit dem Vollzitat die Existenz und Fundstelle der Verordnung (EU) 2025/327…",  // was die Fußnote belegt
      "fundstelle": "ABl. L vom 5.3.2025, S. 1", // Vermutung aus Fußnotentext (Seite/Art/§)
      "suchHinweis": "Verordnung 2025/327 europäischer Gesundheitsdatenraum EHDS"  // Volltextsuche-Hilfe
    }],
    "_reconstruct": "abweichend"                  // OPTIONAL — nur wenn Satz-Join ≠ Absatztext (build_data.js:40)
  }] }
```

**Enums (real vorkommend, aus allen 688 Sätzen extrahiert):**
- `sentences[].kategorien`: `these`, `tech`, `frist`, `akteur`, `norm`, `luecke`, `zahl`, `kontext`
- `marks[].kategorie`: `these`, `tech`, `frist`, `akteur`, `norm`, `luecke`, `zahl`, `schlag`, `abk` (KEIN `kontext`; `schlag`=Schlagwort, `abk`=Abkürzung)
- `wichtig`: `kern`, `stuetz`, `kontext`
- ⚠ PROJEKT-FORMAT.md:93-94 listet nur `norm, frist, akteur, tech, these, luecke, zahl` — die Realdaten enthalten mehr (`kontext`, `schlag`, `abk`). Enum im Flutter-Schema offen halten.

### 7.5 DATA_SOURCES (Array, 74 Einträge)

```jsonc
{ // ---- aus tools/source-registry.js via parsed/sources.json ----
  "id": "dsgvo",
  "kind": "recht-eu",         // Enum: artikel(20) | konferenz(1) | norm(1) | report(8) | online(28) | recht-eu(10) | recht-at(6)
                              // kind steuert App-Logik: recht-eu/recht-at/online/norm → Beleg über Fundstellen (Art/§), sonst PDF-Seiten (PROJEKT-FORMAT.md:42-44)
  "author": "EU", "year": 2016,
  "title": "Verordnung (EU) 2016/679 (DSGVO)",
  "longTitle": "Verordnung (EU) 2016/679 des Europäischen Parlaments…",  // OPTIONAL (15/74), Vollzitat für Rechtsakte
  "container": "Journal of Medical Systems, Bd. 37…",  // OPTIONAL (21/74), nur Artikel
  "doi": "10.1007/s10916-013-9953-4",                   // OPTIONAL (21/74)
  "url": "https://eur-lex.europa.eu/eli/reg/2016/679/oj/deu",  // OPTIONAL (53/74)
  "expectedFile": "sources/dsgvo.pdf",                  // immer: erwarteter PDF-Pfad
  "citations": [{                                       // rohe Zitierstellen (437 über alle Quellen; 1 Fußnote kann bei n Quellen erscheinen)
    "footnote": 2, "sectionId": "1.1", "paragraphId": "1.1-p2",
    "footnoteText": "Verordnung (EU) 2016/679 … ABl. L 119 vom 4.5.2016, S. 1." }],
  // ---- aus generated/sources/<id>.json oder Fallback (build_data.js:100-124) ----
  "dossier": "## Was ist diese Quelle?\nDie **Datenschutz-Grundverordnung…",   // Markdown
  "keyPoints": ["Gesundheitsdaten sind besondere Kategorie (Art 9)…", "…"],   // [] beim Fallback
  "zitierweise": "Verordnung (EU) 2016/679 (DSGVO), ABl. L 119 vom 4.5.2016, S. 1",
  "hinweisOhnePdf": "Frei auf EUR-Lex; Fußnoten mit Art/Abs/lit. …",
  "dossierFallback": false,   // true bei 66/74 (auto-generiertes Dossier)
  "links": {                  // pre-KI-Link-Vorschläge (tools/source-links.js bzw. DOI/URL)
    "official": "https://eur-lex.europa.eu/eli/reg/2016/679/oj/deu",
    "file": "https://eur-lex.europa.eu/legal-content/DE/TXT/PDF/?uri=CELEX:32016R0679",  // string|null
    "vorschlag": true },      // immer true — UI kennzeichnet als "vorgeschlagen"; Overrides in localStorage linkOverrides
  "stellen": [{               // citations ⨝ belege (build_data.js:103-114): angereicherte Zitierstellen
    "footnote": 2, "sectionId": "1.1", "paragraphId": "1.1-p2",
    "footnoteText": "Verordnung (EU) 2016/679 …",
    "claim": "Belegt mit dem Vollzitat die Verordnung (EU) 2016/679 (DSGVO) als bestehendes Unionsrecht…",
    "fundstelle": "ABl. L 119 vom 4.5.2016, S. 1",
    "suchHinweis": "Verordnung 2016/679 Datenschutz-Grundverordnung Schutz natürlicher Personen" }]
                               // claim/fundstelle/suchHinweis = "" wenn kein Beleg existiert
}
```

Custom-Quellen (localStorage) erhalten zusätzlich `custom: true` und leere `citations`/`stellen` (projects.js:245-253).

### 7.6 data/generated/sources/<id>.json (Quell-Dossier, nur 8 vorhanden)

```jsonc
{ "sourceId": "dsgvo",
  "dossier": "## Was ist diese Quelle?\n…",   // Markdown, Abschnitte laut PROJEKT-FORMAT.md:100: Was ist diese Quelle? / Kerninhalte / Rolle in der Arbeit / Verlässlichkeit & Zugang
  "keyPoints": ["…"], "zitierweise": "…", "hinweisOhnePdf": "…" }
```

### 7.7 DATA_META

```jsonc
{
  "kapitel": {                    // Map "1".."6" → Kapitel-Zusammenfassung (= generated/chapters/kapitel-<n>.json)
    "1": {
      "chapter": 1, "title": "Einleitung",          // in kapitel-*.json vorhanden; PROJEKT-FORMAT-Beispiel nennt sie nicht
      "kurzfassung": "Markdown…",
      "kernaussagen": ["…", "…"],                    // 4-8 Strings
      "begriffe": [{ "begriff": "EHDS", "erklaerung": "European Health Data Space — …" }],
      "fristen": [{ "datum": "26. März 2029", "was": "…" }],   // datum = freier String!
      "abschnitte": [{ "id": "1.1", "titel": "Aufgabenstellung", "einzeiler": "…" }],
      "verbindungen": { "bautAuf": ["2","3"], "liefertFuer": ["5","6"] },  // Kapitel-IDs
      "fazitBeitrag": "Ein Satz."
    } },
  "gesamt": {                     // generated/chapters/gesamt.json
    "einSatz": "Österreichs ELGA erfüllt die Primärnutzungs-Anforderungen … schon heute — …",  // OPTIONAL (Sensors hat keins)
    "executiveSummary": "### Fragestellung und Vorgehen\n…",   // Markdown
    "roterFaden": [{ "schritt": 1, "kapitel": 1, "label": "Frage stellen", "text": "…" }],  // "schritt" optional (Sensors ohne)
    "ergebnisse": {
      "positiv":    [{ "titel": "Zugangsrecht umgesetzt", "text": "…" }],
      "luecken":    [{ "titel": "…", "text": "…", "frist": "26. März 2029" }],  // frist OPTIONAL (2/4)
      "spannungen": [{ "titel": "…", "text": "…" }] },
    "timeline": [{ "datum": "2025-03-26",            // ISO-Datum
      "label": "EHDS-Verordnung tritt in Kraft",
      "kategorie": "eu",                              // "eu" | "at"
      "status": "erledigt" }]                         // "erledigt" | "offen"
      // ⚠ PROJEKT-FORMAT.md:124 nennt stattdessen "typ": "frist" — Doku veraltet, App liest kategorie/status (charts.js:145-151)
  },
  "fazit": {                      // generated/fazit-connections.json
    "findings": [{ "id": "f1", "label": "Zugang & Portal erfüllt",
      "typ": "positiv",                               // positiv | luecke | spannung | ausblick
      "beschreibung": "…",
      "fazitParagraphId": "6.0-p2",                   // Absatz im Fazit
      "abschnitte": ["5.1.1", "2.3.1"],               // Herleitungs-Sektionen
      "fristen": ["26. März 2029"] }],                // freie Strings
    "rahmen": ["6.0-p1"],                             // Absätze ohne Finding (Rahmentext)
    "kapitelFluss": [{ "from": "1", "to": "2", "label": "Forschungsfrage → EU-Maßstab" }]
      // ⚠ PROJEKT-FORMAT.md:133 sagt {von,nach} mit Zahlen — real from/to als Strings; App liest from/to (charts.js:38)
  },
  "analyse": {
    "standards": { "titel": "Bewertung nach Bachelorarbeit-Standards",
      "verdikt": "**Solide bis stark.** …",           // Markdown 1-3 Sätze
      "markdown": "…",
      "kriterien": [{ "name": "Fragestellung & Methodik",
        "note": "stark",                              // stark | solide | ausbaufaehig | (schwach lt. Doku, kommt nicht vor)
        "text": "…" }],
      "verbesserung": ["konkreter Punkt", "…"] },
    "struktur": { "titel": "Struktur & roter Faden", "markdown": "…",
      "punkte": [{ "typ": "staerke", "text": "…" }] },  // typ: staerke | schwaeche | hinweis
    "quellen": { /* wie struktur */ },
    "inhalt":  { /* wie struktur */ } },
  "stats": {                      // deterministisch (build_data.js:149-172)
    "quellen": 74, "fussnoten": 397, "absaetze": 233, "saetze": 688, "belege": 397,
    "fnPerChapter":  { "1": 3, "2": 88, "3": 96, "4": 81, "5": 129, "6": 0 },
    "paraPerChapter": { "1": 10, "2": 52, "3": 47, "4": 58, "5": 55, "6": 11 },
    "byKind": { "artikel": 20, "konferenz": 1, "norm": 1, "report": 8, "online": 28, "recht-eu": 10, "recht-at": 6 },
    "kindLabels": { /* s. §5 */ },
    "topSources": [{ "id": "ehds-vo", "title": "Verordnung (EU) 2025/327 (EHDS-Verordnung)", "kind": "recht-eu", "cites": 107 }] },  // Top 10
  "erklaerbuch": "# 📓 Erklärbuch — …",   // string | null — komplettes Markdown-Buch
  "instanzen": null                        // {defs, items} | null (s. 7.10)
  // "connections" fehlt hier für die eingebaute Arbeit; bei Instanz-Arbeiten via buildRuntime gesetzt (s. §2)
}
```

Top-Quellen real: `ehds-vo` 107×, `gtelg2012` 88×, `elga-gesamtarchitektur2017` 33×, `elga-vo2015` 33×.

### 7.8 DATA_FIGURES (= data/figures.json, nach Disk-Check)

```jsonc
{ "figuren": [{
    "id": "abb-3-3-2", "nummer": "Abb. 3.1",
    "sectionId": "3.3.2", "paragraphId": "3.3.2-p4",   // Verankerung am Platzhalter-Absatz
    "file": "figures/abb-3-3-2-acm.png",                // string | null (null ⇒ Platzhalter + Upload); Formate .png/.webp
    "titel": "Beispiel der Access Control Mechanism (ACM) Funktionen",
    "credit": "Übernommen aus NIST, Hu et al. (2014): …, S. 15, Fig. 5.",
    "quelle": "nist-abac2014",                          // Quellen-ID | (lt. Doku auch null möglich)
    "beschreibung": "Die XACML-Referenzarchitektur der Zugriffskontrolle: …" }],
  "tabellen": [{
    "id": "tab-4-4-2", "nummer": "Tab. 4.1",
    "sectionId": "4.4.2", "paragraphId": "4.4.2-p3",
    "titel": "Situationen des Berechtigungssystems",
    "credit": "Quellen: §§ 15 Abs 2 und 3, 21, 24o, 24s GTelG 2012.",
    "kopf": ["Situation", "National (ELGA)", "Grenzüberschreitend (MyHealth@EU)"],
    "zeilen": [["Kein Widerspruch + Opt-In", "alle ELGA-Dokumente verfügbar", "EU-Rezept und EU-Patientenkurzakte verfügbar"], ["…","…","…"]] }] }
```

Real: 4 Figuren (davon `abb-3-4-2` mit `file: null` schon in figures.json), 2 Tabellen. Tabellen haben KEIN `file`/`quelle`/`beschreibung`, Figuren KEIN `kopf`/`zeilen`.

### 7.9 ProjectRecord (BUILTIN_PROJECTS[i] / IndexedDB `ehds-projects.projects` / Export-Format)

```jsonc
{
  "id": "sensors-paper",
  "name": "Mobile Sensors in Education (Paper)",
  "created": "2026-07-18T00:00:00.000Z",       // ISO
  "builtin": true,                              // nur Builtins
  "builtinVersion": 6,                          // Seed-Update-Vergleich (projects.js:77)
  "userModified": true,                         // OPTIONAL — verhindert Builtin-Update-Überschreibung
  "tex": "% This is samplepaper.tex…",          // kompletter LaTeX-Quelltext (50 KB)
  "registry": [{                                // In-App-Quellenregister (aliases = STRINGS, nicht Regex!)
    "id": "abowd_towards_1999", "kind": "konferenz",
    "author": "Abowd, G. D.; Dey, A. K.; …", "year": 1999,
    "title": "Towards a Better Understanding of Context and Context-Awareness",
    "container": "Handheld and Ubiquitous Computing (HUC ’99), Springer LNCS 1707",
    "doi": "10.1007/3-540-48157-5_29",          // string|null
    "url": null, "file": null,                  // file = Direkt-PDF-Link
    "aliases": ["abowd_towards_1999"] }],
  "parsed": {
    "thesis":    { /* wie 7.1; Sensors: chapter id "0" (Abstract), pageOffset 0, subtitle/date "" */ },
    "footnotes": [ /* wie 7.2; Sensors-Sonderfall: text = Citekey ("abowd_towards_1999"), da \cite-basiert */ ],
    "sources":   [ /* wie parsed/sources.json + url/file aus Registry */ ]
  },
  "generated": {
    "sections": { "0_0": { /* wie 7.4, ABER: Sätze OHNE kategorien & wichtig; Paragraph zusätzlich mit
                             "uebersetzung": "<deutsche Übersetzung des engl. Absatzes>" */ } },
    "sources":  { "abowd_towards_1999": { /* wie 7.6 */ } },   // Map, nicht Array!
    "chapters": { "1": { /* wie 7.7 kapitel[n], ohne chapter/title */ } },
    "gesamt":   { /* wie 7.7 gesamt; ohne einSatz; timeline leer; roterFaden ohne "schritt" */ },
    "fazit":    { /* wie 7.7 fazit */ },
    "analyse":  { "standards": …, "struktur": …, "quellen": …, "inhalt": … },
    "connections": { "connections": [{               // generated/connections.json-Format (PROJEKT-FORMAT.md:185-198)
      "id": "s1",
      "typ": "grundlage",                            // folgerung | grundlage | aufgriff | vergleich
      "von":  { "sectionId": "2.1",   "paraId": "2.1-p1" },
      "nach": { "sectionId": "3.1.1", "paraId": "3.1.1-p1" },
      "label": "Situiertes Lernen → Ortssensorik",
      "text": "Die räumlich-zeitliche Kategorie stützt sich auf den Theorieanker des situierten Lernens." }] },
    "instanzen": { /* s. 7.10 */ },
    "erklaerbuch": "…"                               // Markdown-String
  },
  "figures": { "figuren": [], "tabellen": [] }
}
```

Export/Import-Umschlag (projects.js:266-270): `{ "format": "thesis-studio-projekt", "version": 1, …rec }`.
Neu aus .tex (projects.js:105-118): `generated` leer initialisiert `{sections:{},sources:{},chapters:{},gesamt:null,fazit:null,analyse:{},connections:null}`.

### 7.10 Instanzen (generated/instanzen.json bzw. generated.instanzen)

```jsonc
{ "defs": [{
    "id": "sensorblick",
    "label": "📡 Sensor-Brille",                 // Chip-Label mit Emoji
    "color": "var(--cat-tech)",                  // CSS-Token oder Hex
    "desc": "Je Absatz: Durch welche der vier Sensorkategorien …" }],  // GPT-Auftrag
  "items": {
    "sensorblick": {                             // Map defId → (Map absatzId → Markdown)
      "1.1-p1": "🟦 Die Abowd/Dey-Definition ist bewusst sensor-agnostisch: …",
      "1.1-p2": "🟩 …" } } }
```

### 7.11 Resolution (docs/resolution.schema.json + data/resolutions/*.json)

```jsonc
{ "formatVersion": "1.0",                         // const, Pflicht
  "sourceId": "cobrado2024",                      // Pflicht, muss bekannte Quellen-ID sein
  "generatedBy": "claude",                        // frei: claude | gpt | manuell | …
  "erstellt": "2026-07-16",                       // ISO-Datum YYYY-MM-DD
  "datei": { "name": "cobrado2024.pdf", "seiten": 18 },
  "zusammenfassung": "Markdown …",
  "stellen": [{
    "footnote": 132,                              // Pflicht; 1..397 (Schema-max hardcoded!)
    "seite": 3,                                   // integer|null — PHYSISCHE PDF-Seite
    "zitat": "The main challenge of EHR systems is …",   // wörtlich
    "kommentar": "optional: Einordnung/Abweichung",
    "status": "bestaetigt" }] }                   // bestaetigt | teilweise | nicht_gefunden
```
Alle Felder außer formatVersion/sourceId/stellen[].footnote optional — teilgefüllte Dateien erlaubt.

### 7.12 build-warnings.json

`[ "Dossier fehlt (Fallback aktiv): aljarullah2013", … ]` — 66 Strings (aktuell alles Dossier-Fallbacks).

### 7.13 Erklärbuch-Datenpaket (Schnittstelle für Rechenzellen, ERKLAERBUCH.md:98-111)

```jsonc
{ "arbeit":  { "titel", "autor", "universitaet" },
  "kapitel": [{ "num", "titel", "abschnitte", "absaetze", "fussnoten" }],
  "quellen": [{ "id", "titel", "kurz", "typ", "jahr", "zitierstellen" }],
  "belegStatus": { "offen", "vermutet", "original", "belegt", "gesamt" },
  "verbindungen": { "gesamt", "nachTyp": { "folgerung", "fazit", "xref", "quellen" } },
  "abbildungen": [{ "id", "titel" }] }
```

---

## 8. Abhängigkeiten (ER-Bild in Textform)

```
Meta (1) ─── gehört zu ──> Arbeit/Projekt (1..n; "default" + IndexedDB-Records)
Arbeit 1─n Kapitel (id "1".."6"; Sensors auch "0")
Kapitel 1─n Unit (Section, level 2..4, Baum über children[]; "X.0" = Intro, isIntro)
Unit 1─n Paragraph (id = unitId+"-p"+n; type text|list|table|figure)
Paragraph 1─n FootnoteRef (num global eindeutig 1..397)
Footnote n─m Quelle (über Alias-Matching; sources: [id,…] am FootnoteRef)
Paragraph 1─1 ParagraphAnalyse (DATA_SECTIONS, Join über paragraph.id; kernaussage/beschreibung)
ParagraphAnalyse 1─n Satz (Reihenfolge; join(text) == paragraph.text)
Satz 1─n Mark (snippet ⊂ satz.text; kategorie)
ParagraphAnalyse 1─n Beleg (genau 1 je Fußnote des Absatzes; num = Fußnote, quellen[])
Quelle 1─n Zitierstelle ("citations" roh = Footnote×Quelle; "stellen" = citations ⨝ Beleg)
Quelle 0..1 Dossier (generated/sources; sonst Fallback, dossierFallback=true)
Quelle 0..1 Resolution (localStorage/data/resolutions; stellen[].footnote → Fußnote)
Quelle 0..1 LinkSet (links.official/file; Overrides in localStorage)
Abbildung/Tabelle n─1 Paragraph (paragraphId) und n─0..1 Quelle (quelle)
Finding (fazit) n─1 Fazit-Absatz (fazitParagraphId) und n─m Unit (abschnitte[])
KapitelFluss-Kante: Kapitel → Kapitel (from/to)
Connection (inhaltlich): Paragraph → Paragraph (von/nach {sectionId, paraId}; typ)
InstanzDef 1─n InstanzItem (items[defId][paragraphId] = Markdown)
Timeline-Event, RoterFaden-Schritt, Begriff, Frist, Kernaussage, Analyse-Punkt, Kriterium: n─1 Kapitel bzw. Gesamt
```

Modul-Abhängigkeiten: Bundles haben keine Abhängigkeiten (reine Daten, vor allen App-Skripten geladen — Ladereihenfolge siehe index.html-Dossier). `projects.js` konsumiert BUILTIN_PROJECTS + alle DATA_* und überschreibt sie ggf.; `util.js` (`U.storeGet/Set`, `U.PROJECT_KEYS`) liefert die Persistenz-Scoping-Schicht; `TexParse` (editor.js-Familie) erzeugt `parsed` für In-App-Arbeiten; `charts.js` definiert die Feld-Verträge für timeline/kapitelFluss.

---

## 9. Flutter-Hinweise (Drift/SQLite-Schema)

1. **Zwei Datenklassen sauber trennen:** (a) *unveränderliches Arbeitsmaterial* (parsed+generated je Arbeit) und (b) *Laufzeit-Prüfstand* (Belege-Status, Notizen, Resolutions, Custom-Quellen, Link-Overrides) — in der Web-App localStorage mit Projekt-Scoping `ehds.<pid>.<key>`. In Drift: alle Laufzeit-Tabellen mit `projectId`-Spalte + Fremdschlüssel auf `projects`.
2. **Empfohlene Tabellen:** `projects` (id, name, created, builtin, builtinVersion, userModified, tex BLOB/TEXT), `chapters`, `units` (id, projectId, parentUnitId nullable, chapterId, title, level, isIntro, page, pdfPage, orderIndex), `paragraphs` (id, unitId, type, text, itemsJson, orderIndex, kernaussage, beschreibung, uebersetzung, reconstructDivergent), `sentences` (paragraphId, orderIndex, text, einfach, wichtig), `sentence_categories`, `marks` (sentenceId, snippet, kategorie), `footnotes` (num, projectId, text, sectionId, paragraphId), `footnote_sources` (m:n), `sources` (+ optionale Felder nullable), `citations`/`stellen` (oder eine Tabelle mit nullable claim/fundstelle/suchHinweis), `belege`, `figures`, `tables_manifest` (kopf/zeilen als JSON), `findings` (+ `finding_abschnitte`, `finding_fristen`), `kapitel_meta` (+ begriffe/fristen/abschnitte/kernaussagen als Kind-Tabellen oder JSON), `gesamt` (JSON-Spalten sind hier legitim — reine Anzeige-Daten), `analyse_docs`, `connections`, `instanz_defs`, `instanz_items`, `resolutions` (+ `resolution_stellen`), `custom_sources`, `link_overrides`. Alternative pragmatisch: Anzeige-Aggregate (`gesamt`, `analyse`, `kapitel_meta`, `erklaerbuch`) als JSON-Blobs speichern und nur die abfragerelevanten Entitäten (Units/Paragraphs/Sentences/Footnotes/Sources/Belege/Figures/Connections/Findings) relational — das entspricht exakt dem tatsächlichen Zugriffsmuster der App.
3. **Reihenfolge ist Bedeutung:** paragraphs/sentences/marks/citations sind geordnete Arrays ohne eigene Order-Felder — überall `orderIndex` einführen. Fußnoten-Reihenfolge im Absatz = Marker-Reihenfolge im Text.
4. **`[^N]`-Marker:** Inline im Text; Flutter-Rendering braucht einen Parser Text→Spans (Marker → tappable Superscript). Marks werden per Substring-Suche (`snippet`) gehighlightet — Original-Snippets exakt speichern (inkl. Sonderzeichen wie „ “ — ü).
5. **Optionale Felder exakt abbilden** (nullable): `container`, `doi`, `url`, `longTitle`, `isIntro`, `page`/`pdfPage` (null möglich!), `beschreibung`, `frist` (luecken), `einSatz`, `schritt` (roterFaden), `wichtig`+`kategorien` (fehlen bei Sensors-Sätzen komplett!), `uebersetzung` (nur Sensors), `file`/`quelle` (figures), `custom`.
6. **Doku ≠ Realität:** PROJEKT-FORMAT.md ist an drei Stellen veraltet gegenüber Daten+Code: timeline `typ` vs. real `kategorie`+`status`; kapitelFluss `von/nach` (Zahlen) vs. real `from/to` (Strings); Kategorien-Enum unvollständig (fehlt `kontext`/`schlag`/`abk`). **Immer die Realdaten + charts.js als Vertrag nehmen.** Beim Import fremder Analyse-Dateien beide Varianten tolerant lesen.
7. **Zwei Registry-Alias-Formate:** `tools/source-registry.js` = echte RegExp-Objekte (Build-Zeit), In-App `registry.json`/ProjectRecord = Regex-**Strings** (PROJEKT-FORMAT.md:204). In Dart: Strings speichern, per `RegExp(s)` kompilieren.
8. **Fallback-Kaskaden nachbauen:** (a) Dossier fehlt → Fallback-Dossier-Markdown generieren (zwei leicht unterschiedliche Templates: build_data.js:68-93 ausführlich, projects.js:226-238 kurz — Flutter braucht die projects.js-Variante für Instanzen und sollte die Bundle-Variante der eingebauten Arbeit unverändert übernehmen); (b) `links.official` = linkSuggest > `https://doi.org/<doi>` > url > null; (c) Erklärbuch: eigenes (localStorage) > eingebautes (`erklaerbuch`) > Starter-Buch; (d) Fundstellen-Anzeige: manuell > Resolution > Dossier.
9. **`stats` nicht speichern, sondern berechnen** — sie sind deterministisch aus den Basistabellen ableitbar (build_data.js:149-172, projects.js:188-222); in Flutter als Query/Provider. Achtung: `build_data.js:128` iteriert Kapitel hart `1..6` — generisch machen (Sensors hat 5 Meta-Kapitel + Kapitel 0 ohne Meta).
10. **Builtin-Seeding-Semantik:** Beim App-Start Builtin-Projekte in die DB kopieren, außer id in Tombstone-Liste; Update nur bei höherer `builtinVersion` und `!userModified`. Tombstones + activeProject als Key-Value (shared_preferences oder eigene Drift-Tabelle).
11. **Resolution-Schema:** `stellen[].footnote` max 397 ist im JSON-Schema hart auf diese Arbeit kodiert — in Flutter gegen die tatsächliche Fußnotenzahl der aktiven Arbeit validieren.
12. **Größenordnung:** Gesamtvolumen der eingebauten Daten ~1,6 MB JSON. Problemlos als Assets bündeln und beim ersten Start in SQLite importieren (oder als vorbefüllte .db ausliefern). Die 1-zeiligen JS-Bundles sind nach `window.X = ` reines JSON — für die Konvertierung direkt `data/parsed/` + `data/generated/` als Quelle nehmen (sauberer als die Bundles zu strippen), aber dann den build_data-Merge (stellen, Fallback-Dossiers, stats, file-Nulling) in Dart nachimplementieren — oder einmalig die fertigen Bundles extrahieren.
13. **Nicht 1:1 portierbar:** Erklärbuch-Rechenzellen (```js via `Function`, ```py via Pyodide/CDN) — in Flutter kein Äquivalent ohne WebView/JS-Engine (Vorschlag: `flutter_js`/QuickJS für ```js-Zellen, ```py weglassen oder WebView); ```chart/```table/```math sind reine Renderer und mit CustomPaint/Tabellen/`flutter_math_fork` machbar. File-System-Access-API ("PDF-Ordner verbinden") → `file_picker`/SAF; IndexedDB → Drift; `location.reload()` beim Projektwechsel → State-Reset im Provider-Graph.
```

---

*Alle Zahlen aus den Realdaten extrahiert (Stand Repo-HEAD, 2026-07-23): 6 Kapitel, 69 Units (24 L2 + 43 L3 + 2 L4), 68 Sections mit Inhalt, 233 Absätze (226 text, 4 list, 2 table, 1 figure), 688 Sätze, 1369 Marks, 397 Fußnoten/Belege, 74 Quellen, 437 Zitierstellen, 4+2 Abbildungen/Tabellen, 13 Findings, 8 Fluss-Kanten, 14 Timeline-Events; Sensors-Paper: 6 Kapitel (0-5), 34 Sections, 24 Quellen, 90 Fußnoten, 14 Connections, 2 Instanz-Defs.*
