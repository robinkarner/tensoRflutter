# Inventar-Dossier 07 — Projekt/Status-Dashboard, Hilfe, Mehrfach-Instanzen-System

Dateien: `js/views_projekt.js` (563 Z.), `js/views_hilfe.js` (206 Z.), `js/projects.js` (285 Z.)
Kontext-Belege zusätzlich aus: `js/util.js` (Storage-Namespacing), `js/app.js:101-115` (🗂-Dropdown-Host), `css/app.css` (Layout-Rohwerte), `index.html:40-46`, `js/data/project_sensors.js` (eingebaute 2. Arbeit).

---

## 1. Zweck & Rolle

### js/views_projekt.js
Rendert die Route `#/projekt` — das **Status-Dashboard** der aktiven Arbeit (views_projekt.js:11-268). Oben Live-Statuskacheln (Abschnitte analysiert, PDFs, Links, Belege, Durchläufe, Abbildungen), darunter zwei Spalten: links Kapitel-Fortschritt, Quellen-Setup (Link-Vorschläge prüfen, „⭳ Alle laden", Import), Referenzierungsdurchläufe je Quelle; rechts Connections-Karte und eine Anleitung mit Akkordeons. Enthält außerdem die **Arbeiten-Karte** `projektArbeitenCard()` (views_projekt.js:271-338), die NICHT mehr auf der Projekt-Seite gerendert wird, sondern von `app.js:110` in das 🗂-Dropdown der Topbar eingehängt wird. Dazu die Modals `neueArbeitModal()` (neue Arbeit aus .tex/PDF, views_projekt.js:343-434), `importAnalysenModal()` (GPT-Analyse-Dateien importieren, views_projekt.js:437-490) und den `masterPrompt()`-Text für die Pre-Pipe (views_projekt.js:493-563).

### js/views_hilfe.js
Rendert die Route `#/hilfe` — eine rein statische, aber inhaltsreiche Hilfe-Seite (views_hilfe.js:8-206) mit 5 Karten: (1) Ablauf-Flussdiagramm LaTeX→Parsen→GPT→Prüfen→Belegstand, (2) Tabelle „KI-Teile nachträglich generieren & ersetzen", (3) Tabelle Speichermodell (localStorage/IndexedDB/Repo), (4) Web vs. Lokal, (5) große Bedienungs-/Barrierefreiheits-Liste (23 `<li>`-Punkte, die faktisch die Gesamtsoftware dokumentieren). Keine Interaktion außer Links und nativen `<details>`-Elementen (hier keine); alles wird einmalig per `innerHTML`/`U.el` gebaut.

### js/projects.js
Das **Mehrfach-Instanzen-System**: globales Objekt `Projects` (projects.js:12-285). Verwaltet mehrere Arbeiten (Paper/Thesen) parallel. Die eingebaute Arbeit `default` („EHDS-Bachelorarbeit") kommt aus statischen Bundles (`js/data/data_*.js`); weitere Instanzen (inkl. der eingebauten zweiten Arbeit `sensors-paper` aus `js/data/project_sensors.js`) leben in IndexedDB `ehds-projects`. Beim Boot (projects.js:20-61) wird die aktive Arbeit ermittelt, ihre Laufzeitdaten in die `window.DATA_*`-Globals eingespielt (`buildRuntime`, projects.js:154-220) und der localStorage-Namespace pro Arbeit gesetzt (`U.storeProject`). Zusätzlich: Seeding der Builtins mit Tombstones/Versionsvergleich, Import/Export von Arbeiten, Einsortieren von GPT-Analyse-Dateien und Verwaltung manueller Quellen (`mergeCustomSources`).

---

## 2. Öffentliche API

### views_projekt.js exportiert (window-Scope, klassische `function`-Deklarationen)
| Symbol | Signatur | Zweck | Genutzt von |
|---|---|---|---|
| `renderProjekt` | `(root: HTMLElement) → void` | Baut die komplette #/projekt-Seite in `root` | Router (app.js, Route `#/projekt`) |
| `projektArbeitenCard` | `() → HTMLElement` | Karte „Arbeiten (Instanzen)" mit Liste, Neu/Prompt/Import/Export/Löschen | `app.js:110` (🗂-Dropdown `#worksPop`) |
| `neueArbeitModal` | `() → void` | Modal „＋ Neue Arbeit aus LaTeX" | `projektArbeitenCard` (views_projekt.js:336) |
| `importAnalysenModal` | `(rec, onDone) → void` | Modal „⭱ Analysen importieren" | `projektArbeitenCard` (views_projekt.js:301) |
| `masterPrompt` | `() → string` | Gesamt-Prompt-Text (Formatvorgabe für externe GPT-Pipeline) | Gesamt-Prompt-Button (views_projekt.js:297); ggf. Enhance |

### views_hilfe.js exportiert
| Symbol | Signatur | Zweck | Genutzt von |
|---|---|---|---|
| `renderHilfe` | `(root: HTMLElement) → void` | Baut die #/hilfe-Seite | Router (app.js, Route `#/hilfe`) |

### projects.js exportiert: `const Projects = {…}` (Top-Level, damit global)
| Member | Signatur | Zweck |
|---|---|---|
| `Projects.DEFAULT` | `'default'` (projects.js:13) | id der eingebauten Arbeit |
| `Projects.db` | `IDBDatabase\|null` (projects.js:14) | Handle auf DB `ehds-projects` |
| `Projects.activeId` | `string`, init `'default'` (projects.js:15) | id der aktiven Arbeit |
| `Projects.activeName` | `string`, init `'EHDS-Bachelorarbeit (eingebaut)'` (projects.js:16) | Anzeigename (Chip auf Status-Seite, Topbar) |
| `Projects.bootWarnings` | `string[]` (projects.js:17) | Warnungen aus dem Boot, werden auf #/projekt als Notices gezeigt (views_projekt.js:28) |
| `Projects.boot()` | `async () → void` (projects.js:20-61) | Muss VOR dem ersten Render laufen: DB öffnen, Builtins seeden, aktive Arbeit laden, `U.storeProject` setzen, `mergeCustomSources` |
| `Projects.seedBuiltins()` | `async` (projects.js:66-79) | `window.BUILTIN_PROJECTS` in IndexedDB einspielen (Tombstones + Versionslogik) |
| `Projects._idb(op,…args)` | Promise-Wrapper (projects.js:81-89) | get/getAll/put/delete auf Store `projects`; ohne DB: getAll→`[]`, sonst `null` |
| `Projects.list()` / `get(id)` / `save(rec)` / `remove(id)` | `async` (projects.js:90-93) | CRUD |
| `Projects.setActive(id)` | `(id) → void` (projects.js:95-99) | Schreibt `ehds.activeProject`, setzt `location.hash='#/projekt'`, **`location.reload()`** |
| `Projects.createFromTex(name, tex, registry?)` | `async → {ok,errors,warnings,stats,thesis,…, id, rec}` (projects.js:102-116) | Parst .tex via `TexParse.parse`, legt Datensatz an |
| `Projects.applyRegistry(rec, registry)` | `async → parseResult` (projects.js:119-127) | Re-Parse mit Registry, `rec.userModified=true` |
| `Projects.applyGeneratedFile(rec, filename, obj)` | `→ string \| {registry} \| {registryError} \| null` (projects.js:130-151) | Dateiname→Ziel-Mapping der GPT-Ausgaben |
| `Projects.buildRuntime(rec)` | `(rec) → void` (projects.js:154-220) | Baut `window.DATA_THESIS/DATA_SECTIONS/DATA_FIGURES/DATA_SOURCES/DATA_META`, `PROJECT_INSTANZEN`, `PROJECT_ERKLAERBUCH` |
| `Projects.fallbackDossier(src)` | `→ string` (Markdown) (projects.js:222-235) | Auto-Kurz-Dossier wenn kein GPT-Dossier |
| `Projects.mergeCustomSources()` | `() → void` (projects.js:238-254) | Manuelle Quellen (localStorage `customSources`) in `window.DATA_SOURCES` mischen |
| `Projects.customSources()` | `→ array` (projects.js:255) | Rohliste aus Store |
| `Projects.saveCustomSource(src)` / `removeCustomSource(id)` | (projects.js:256-264) | Upsert/Delete in `customSources` |
| `Projects.exportProject(rec)` | `→ string` (projects.js:267-269) | `JSON.stringify({format:'thesis-studio-projekt',version:1,...rec},null,1)` |
| `Projects.importProject(json)` | `async → rec` wirft `Error` (projects.js:270-284) | Validierung + Kollisions-Dialog (Überschreiben/Kopie) |

### Konsumierte Globals (alle drei Dateien)
- `U.*` (util.js): `el, esc, modal, closeModal, copy, download, storeGet, storeSet, storeProject, srcLinks, setSrcLink, getDlStatus, getResolutions, detectPdf, pdfStatusCache, srcShort`
- `Levels.*`: `allNums, countsFor, numsForChapter, bar, positionType`
- `PdfStore.has(id)`, `PdfStore.onChange(cb, hostEl)`; `FigStore.has(id)`
- `PdfEngine.*`: `dlLinkFor(id)`, `tryDownload(id) → {ok,note}`, `assignPanel(host,id,{onDone,onCancel})`, `pdfToTex(arrayBuffer, progressCb) → {tex,title,pages,headings,footnotes}`
- `TexParse.parse(tex, {registry}) → {ok, errors[], warnings[], stats:{kapitel,abschnitte,fussnoten}, thesis, footnotes, sources}`
- `Enhance.pasteModal({srcId}, 'quellen', {})` — GPT-Dialog für Quellen-Durchlauf
- `importFilesModal(onDone, opts?)` — definiert in `views_quellen.js:718`
- `orderedUnits()`, `fileIdOf(id)`, `KIND_LABELS` (util.js:926)
- `window.DATA_THESIS, DATA_SOURCES, DATA_SECTIONS, DATA_FIGURES, DATA_META, BUILTIN_PROJECTS`

---

## 3. State & Persistenz

### localStorage-Keys (immer Präfix `ehds.`; via `U._storeKey`, util.js:202-205)
**Namespacing-Regel (kritisch!):** `U.storeProject` (util.js:199) ist `''` für die Default-Arbeit, sonst die Projekt-id. Nur Keys aus `U.PROJECT_KEYS` (util.js:200-201) werden gescoped: `ehds.<key>` (default) bzw. `ehds.<projectId>.<key>` (Instanz). PROJECT_KEYS = `['belegLevels','annotations','resolutions','pdfManual','linkOverrides','srcNotes','srcTexts','texEdits','pdfMarks','customSources','kiConnections','textMentions','fileSearch','dlStatus','paraDock','paraEdits','dockBySection','marksExtra','notebook','studioLast','assignDismissed','fnEdits','belegSpans','titleEdits','srcDoc','srcExtras']`. Gesetzt wird `U.storeProject` ausschließlich in `Projects.boot` (projects.js:42, 53) — VOR `buildRuntime`, damit ein Fehler nicht den Prüfstand der Default-Arbeit kontaminiert (Kommentar projects.js:40-41).

| Key (roh, ohne Scope-Präfix) | Wo gelesen/geschrieben | Form / Beispiel |
|---|---|---|
| `ehds.activeProject` | direkt (unscoped!): read projects.js:21, write projects.js:38/49/96 | `"p-masterarbeit-xy-a1b2"` (String, keine JSON-Hülle — `getItem`/`setItem` roh) |
| `ehds.builtinDeleted` | direkt (unscoped): read projects.js:70, write views_projekt.js:309-311 | `["sensors-paper"]` — Tombstone-Liste gelöschter Builtin-ids |
| `customSources` (gescoped) | `Projects.mergeCustomSources/saveCustomSource/removeCustomSource` (projects.js:239-264) | `[{"id":"mueller2023","title":"…","author":"Müller","year":2023,"doi":null,"url":"https://…","official":"https://…","file":null,"dossier":"## …","kind":"artikel"}]` |
| `kiConnections` (gescoped) | read views_projekt.js:227 | `{"connections":[{"id":"c1","typ":"folgerung","von":{"sectionId":"5.3.3","paraId":"5.3.3-p2"},"nach":{"sectionId":"6.0","paraId":"6.0-p5"},"label":"…","text":"…"}]}` |
| `resolutions` (gescoped) | read views_projekt.js:16, 209 (`U.getResolutions()`) | `{"cobrado2024":{"stellen":[{"num":12,"seite":"S. 4","zitat":"…","status":"gefunden"}]}}` |
| `linkOverrides` (gescoped) | via `U.srcLinks`/`U.setSrcLink` (views_projekt.js:32, 92, 96-98) | `{"cobrado2024":{"official":"https://doi.org/…","file":"https://…pdf"}}` — Existenz ⇒ `_override:true` |
| `dlStatus` (gescoped) | via `U.getDlStatus` (views_projekt.js:111) | `{"cobrado2024":{"ok":false,"note":"CORS blockiert — von Hand laden"}}` |

### IndexedDB
- **DB `ehds-projects`, Version 1, ObjectStore `projects` (keyPath `id`)** (projects.js:24-28). Datensatz-Form siehe §7. Gelesen: boot/list/get; geschrieben: save (seed, create, import, applyGeneratedFile→save im Modal views_projekt.js:482); gelöscht: remove.
- PDFs liegen in einer separaten, **NICHT projekt-gescoped**en DB (PdfStore) — „PDFs werden über die Quellen-id geteilt" (views_projekt.js:275).

### In-Memory-State
- `Projects.activeId/activeName/db/bootWarnings` (s.o.).
- `window.DATA_*`-Globals: für `default` aus statischen Bundles, sonst von `buildRuntime` überschrieben.
- `window.PROJECT_ERKLAERBUCH` (String|null), `window.PROJECT_INSTANZEN` ({defs,items}|null) — projects.js:57-58 (default aus `DATA_META`), 161-162 (Instanz).
- `U.pdfStatusCache` — wird bei Import/Change auf `{}` zurückgesetzt (views_projekt.js:50, 197).
- Modal-lokal: `lastResult` (Parse-Ergebnis, views_projekt.js:366), Debounce-Timer `checkT` (views_projekt.js:422).

---

## 4. UI-Struktur & Layout

### #/projekt (renderProjekt)
```
root
├─ .page-head
│  ├─ .row (gap:10px) → h1 "Status" (margin:0) + span.chip.accent = aktiver Arbeitsname
│  └─ p.page-sub  (Meta: Titel — Autor · Uni · Datum + Hinweistext)
├─ [je bootWarning] .notice.small (margin-bottom:10px) "⚠ …"
├─ .statgrid (margin-top:0)                 ← CSS: grid, repeat(auto-fit,minmax(155px,1fr)), gap 12px
│  ├─ .stat.ki  → .v "N/M" + .l "Abschnitte GPT-analysiert ✦"
│  ├─ .stat     → .v#pPdf "–/M" + .l "PDFs vorhanden (Artikel/Reports)"   (async befüllt)
│  ├─ .stat     → .v#pLinks + .l "Links geprüft/übernommen"
│  ├─ .stat.g   → .v + .l "Belege gesichert ✓"
│  ├─ .stat.a   → .v#pRes + .l "Quellen-Durchläufe importiert 🤖"
│  └─ .stat     → .v + .l "Abbildungen hinterlegt"
│     (.stat: border 1px var(--border), radius var(--radius), padding 12px 14px;
│      .v: 600 22px var(--font-display), tabular-nums; .v .mono: 15px var(--muted);
│      .l: 11.5px 600 var(--muted))
└─ .dash-cols (margin-top:16px)             ← grid 1.55fr/1fr, gap 16px, align-items:start;
   │                                           @media(max-width:999px) → 1 Spalte
   ├─ .stack (links)
   │  ├─ .card "Beleg-Fortschritt je Kapitel"
   │  │  ├─ .eyebrow · p.small.mut mit .lvl-dot.l1/.l2/.l3-Legende „vermutet → Original → belegt"
   │  │  └─ .chaps → je Kapitel .chaprow (flex, gap 12px, padding 9px 4px, border-bottom):
   │  │     span.n (mono 700 13px, width 20px) · span.t (flex:1, ellipsis) ·
   │  │     Levels.bar (…lvl-bar width 130px) · span.c "x/y ✓" (width 70px, right) ·
   │  │     a.btn.btn-sm "⌖" → #/studio/<num>.0/pruefen
   │  ├─ .card "Quellen-Setup — Dateien besorgen"
   │  │  ├─ .row.spread: .eyebrow + [span#qsCount klein + button#qsAll "✓ alle übernehmen"]
   │  │  ├─ p.small.mut (Erklärtext „⭳ Alle laden …")
   │  │  ├─ .row: button#qsDlAll.btn-primary "⭳ Alle laden" · button#qsImport "⭱ Import (PDF/ZIP)" · span#qsDlMsg
   │  │  └─ .qs-rows (flex-column, max-height:420px, overflow-y:auto) → je Quelle:
   │  │     .qs-row.rich[.ok|.dl-fail] (flex, align-items:flex-start, gap 9px, padding 8px 4px, border-bottom)
   │  │       span.st  "✓" | "✗" | "·"   (width 16px, Farbe: ok→var(--good), fail→var(--bad), sonst var(--ki))
   │  │       span.bd (flex:1, flex-column, gap 2px)
   │  │         .t: <b>Titel</b> <code>id</code> [chip.warn.mini "manuell"]
   │  │         .s.small.mut: Autor · Jahr · Container [· DOI x] · "N Zitierstellen"
   │  │         optional .s.small: chip.warn.mini "✗ <note>"  ODER  chip.ok.mini "✓ geladen & zugeordnet"
   │  │       span.acts (flex, gap 4px): btn[data-dl] "⭳" · a/span "↗" (.ai-dl-link, target=_blank) ·
   │  │         btn[data-file] "📄" · a "✎" → #/quellen/<id>
   │  │     [Toggle] .qs-assign-host (padding 8px 0 12px) direkt UNTER der Zeile → PdfEngine.assignPanel
   │  │     (.qs-row.dl-fail: border-left 3px var(--bad), bg color-mix(--bad 4%))
   │  └─ .card "Referenzierungsdurchläufe — je Quelle"
   │     └─ .qs-rows → je Quelle (sortiert nach citations DESC) .qs-row[.ok]:
   │        span.st "✓|·" · span.bd (<b>srcShort</b> + Titel auf 54 Zeichen gekürzt + "· N Stellen[· M importiert]") ·
   │        .acts: btn[data-gpt] "Durchlauf" · a "✎"
   └─ .stack (rechts)
      ├─ .card "Connections — inhaltliche Verbindungen"
      │  ├─ .eyebrow · p.small.mut (Erklärtext)
      │  └─ .row: span.chip "N aus Voranalyse" · span.chip[.ok] "M importiert" · span{flex:1}
      └─ .card "Anleitung — wie die Teile zusammenspielen"
         ├─ 4× details.acc (Akkordeon, nativ; summary mit ▸-Pseudoelement, rotiert 90° bei [open])
         │  Summaries: "GPT-Voranalyse (Basis)" · "Nachladbare Analysen (Resolutions)" ·
         │             "GPT — überall dasselbe Muster" · "Sichern & Umziehen"
         └─ p.small.mut: Links "PROJEKT-FORMAT.md ↗" · "QUELLEN-WORKFLOW.md ↗" (target=_blank)
```

### 🗂-Dropdown (projektArbeitenCard, gehostet in `#worksPop`)
`#worksPop.works-pop`: `position:absolute; top:calc(100%+8px); right:0; width:min(560px,94vw); z-index:90`; innere `.card` mit `box-shadow:var(--shadow-pop); max-height:72vh; overflow-y:auto` (app.css:1259-1260). Öffnen/Schließen: app.js:105-115 (Klick auf `#worksBtn` togglet; Klick außerhalb schließt; schließt das GPT-Popup und umgekehrt).
```
.card
├─ .row.spread: .eyebrow "Arbeiten (Instanzen)" + button#pjNew.btn-primary "＋ Neue Arbeit aus .tex"
├─ .pj-list (margin-top:8px; initial: .small.mut "Lade …")
│  ├─ .pj-row[.active] (flex, gap 9px, padding 8px 4px, border-bottom)   je Arbeit:
│  │  button.st.pj-pick [role=radio] "●" (aktiv) | "○"        (aktiv: color var(--accent))
│  │  span.bd (flex-column): <b>Name</b> [chip.mini "eingebaut"] + span.small.mut Untertitel
│  │  span.acts (flex-wrap, right): nur für Nicht-default:
│  │    btn "🤖 Gesamt-Prompt" · btn "⭱ Analysen" · btn "⭳ Export" · btn "🗑 Löschen"
│  │  — Zeile 1 ist immer: 'default' / "EHDS-Bachelorarbeit" / "eingebaut · js/data-Bundles" (ohne acts)
│  └─ .row: label.btn.btn-sm "⭱ Arbeit importieren (.json)" + verstecktes input[type=file][accept=application/json]
└─ p.small.mut "Jede Arbeit hat ihren eigenen Prüfstand … PDFs werden über die Quellen-id geteilt."
```

### Modal „＋ Neue Arbeit aus LaTeX" (neueArbeitModal)
Body: Erklärtext → `.row` mit drei Elementen: label.btn „.tex-Datei laden" (+hidden `#naFile` accept `.tex,text/plain`), label.btn „📄 PDF → LaTeX (Beta)" (+hidden `#naPdf` accept `application/pdf,.pdf`), label.small mit flex:1 „Name der Arbeit" + `#naName` (placeholder „z. B. Masterarbeit XY") → `textarea#naTex` (min-height:170px, font-family var(--font-mono), font-size 11.5px, placeholder `\documentclass… oder direkt der Hauptteil mit \chapter/\section … — Datei hierher ziehen geht auch`) → `.row` mit `#naCheck` „↻ Prüfen" und `#naCreate.btn-primary` „Anlegen & aktivieren" (initial disabled) → `#naReport` → Abschluss-Hinweis „**Danach:** …". Drag&Drop-Ziel ist das gesamte Modal (`body.closest('.modal')`), Textarea bekommt Klasse `droptarget` beim dragover.

### Modal „⭱ Analysen importieren — <Name>" (importAnalysenModal)
Erklärtext mit Liste erkannter Dateinamen → label.btn.btn-primary „Dateien wählen" (+hidden `#iaFiles`, accept application/json, `multiple`) → `#iaLog.small` (max-height:220px, overflow-y:auto) → button `#iaDone` „Fertig — Arbeit neu laden".

### #/hilfe (renderHilfe)
`root → .page-head (h1 "Hilfe & Anleitung" + p.page-sub) → .hilfe` (flex-column, gap 14px, **max-width 980px**, app.css:1325). Darin 5 `.card`s:
1. **„1 · So fließt alles zusammen"**: `.flow` (flex, gap 6px, overflow-x:auto, role="img" mit aria-label) mit 5 `.flow-step` (b 14px + span 12px muted) und 4 `.flow-arr` „→" dazwischen; Varianten `.flow-step.ki` (accent-Hintergrund 6%) und `.flow-step.ok` (border var(--good)).
2. **„2 · KI-Teile nachträglich generieren & ersetzen"**: `div[overflow-x:auto] > table.hilfe-tab` (100%, collapse, 13px; th uppercase 11px; td border-bottom dashed) — 7 Zeilen, Spalten „Baustein | Wo (Prompt + Import in EINEM Dialog) | Ersetzt".
3. **„3 · Wo liegen meine Daten — und wie ersetze ich sie"**: table.hilfe-tab (4 Zeilen) + `.notice.info.small` „Wichtig beim Umziehen: …".
4. **„4 · Im Web nutzen vs. lokal starten"**: `.grid.grid-2` (gap 12px) mit zwei `.well`-Boxen „🌐 Web (GitHub Pages)" / „💻 Lokal".
5. **„5 · Bedienung & Barrierefreiheit"**: `ul.small` (line-height:2) mit 23 Punkten.

---

## 5. Design-Rohwerte

**Farben/Styles nur über CSS-Variablen im JS referenziert:** `var(--bad)` (Fehler-Bordüren views_projekt.js:387, 416, 430, 464; Fehlertext-Farbe :417, 469), `var(--warn)` (:418), `var(--font-mono)` (:353). Keine Hex-Werte inline im JS dieser drei Dateien.

**Icon-/Symbol-Zeichen (exakt):**
- `⭳` (U+2B73) Download · `⭱` (U+2B71) Upload/Import · `↗` externer Link · `✓` ok · `✗` Fehler · `·` offen/neutral · `⏳` laufend · `📄` Datei-Panel/PDF · `✎` Quellenseite/Bearbeiten · `⌖` Studio-Sprung/Große Ansicht · `🤖` GPT · `🗑` Löschen · `＋` (U+FF0B, Vollbreite-Plus!) Neue Arbeit · `●`/`○` aktive/inaktive Arbeit (Radio) · `↻` Prüfen · `✔` kopiert-Feedback · `⚠` Warnung · `✦` KI-Vermutung · `🗂` Arbeiten-Menü · `◐` Theme-Toggle · `🔎`/`🔍` Suche/OCR · `🖍` Markierungen · `⤳` Connections · `⚡` Schnelllesen · `🌐` Web/Übersetzung · `📓` Erklärbuch · `🔬` Analysemodus · `📥` Dateiverzeichnis · `⌗` Datei-Auftrag/geteilte Quellen · `☰` Text · `▾` einklappen · `⇤`/`⇥` Spalten einklappen · `←`/`→`/`+`/`−`/`0` PDF-Tasten · `∅` leere Auswahl · `◻` Ohne · `💻`/`🌐` lokal/Web.

**Wichtige wörtliche UI-Texte (Auswahl, exakt):**
- Chips/Titel: „Status", Chip-Title „Aktive Arbeit — wechseln über 🗂 oben rechts"; „Fortschritt, Setup und die GPT-Pipeline — Arbeiten wechseln/anlegen über das 🗂-Menü oben rechts."
- Statkachel-Labels: „Abschnitte GPT-analysiert ✦" · „PDFs vorhanden (Artikel/Reports)" · „Links geprüft/übernommen" · „Belege gesichert ✓" · „Quellen-Durchläufe importiert 🤖" · „Abbildungen hinterlegt".
- Quellen-Setup: „Quellen-Setup — Dateien besorgen" · „✓ alle übernehmen" · „⭳ Alle laden" · „⭱ Import (PDF/ZIP)" · Zähler „N von M Links offen" / „alle M Links geprüft ✓" · Abschlussmeldung „fertig: ✓ N geladen & zugeordnet · ✗ M fehlgeschlagen (siehe Liste)" · „nichts zu laden — alle Dateien sind schon da" · Chip „✓ geladen & zugeordnet" · Button-Title „nicht verfügbar — kein öffentlicher Datei-Link bekannt".
- Durchläufe: „Referenzierungsdurchläufe — je Quelle", Button „Durchlauf", Erklärtext „Ein Durchlauf schlägt für jede Zitierstelle einer Quelle die konkrete Fundstelle vor (Seite/Art/§ + Suchbegriffe + Zitat). „Durchlauf" öffnet das Einfüge-Fenster: …".
- Connections: „Connections — inhaltliche Verbindungen", Chips „N aus Voranalyse" / „M importiert", Typen „(Folgerung, Wiederaufgriff, Grundlage, Vergleich)".
- Arbeiten-Karte: „Arbeiten (Instanzen)" · „＋ Neue Arbeit aus .tex" · Chip „eingebaut" · „🤖 Gesamt-Prompt" (nach Kopie 1800 ms „✔ kopiert (inkl. LaTeX)") · „⭱ Analysen" · „⭳ Export" · „🗑 Löschen" · Confirm „Arbeit „<name>" wirklich löschen? Der Prüfstand im Browser bleibt erhalten, die Arbeit selbst wird entfernt." · „⭱ Arbeit importieren (.json)" · Default-Zeile „EHDS-Bachelorarbeit" / „eingebaut · js/data-Bundles" · Untertitel-Muster „N Kapitel · M Fußnoten · K Abschnitte analysiert".
- Neue-Arbeit-Modal: Titel „＋ Neue Arbeit aus LaTeX"; Erfolg „✓ Ladbar: N Kapitel · M Abschnitte · K Fußnoten. Titel erkannt: **<title>**[ — <author>]"; Fehler „**✗ Nicht ladbar.** Gründe:"; PDF-Beta-Notice „📄 Beta: N Seiten extrahiert · M Überschriften erkannt[ · K Fußnoten-Kandidaten am Seitenende (als Kommentare, ohne Anker im Text)]. Die Gliederung stammt aus einer Schriftgrößen-Heuristik — unten prüfen und bei Bedarf nachbessern."; Progress „⏳ Seite N von M …"; „✗ PDF-Extraktion fehlgeschlagen: <msg>".
- Analysen-Import-Modal: Titel „⭱ Analysen importieren — <Name>"; Logzeilen „✓ …", „⚠ <file>: nicht zuordenbar oder ungültiger Inhalt (Dateiname/Struktur prüfen)", „⏳ Registry erkannt (N Quellen) — wird angewendet …", „✓ Registry angewendet — N Quellen, …/alle Fußnoten geprüft", „✓ Erklärbuch (N KB) übernommen", „Gespeichert." · Button „Fertig — Arbeit neu laden".
- Boot-Warnungen: „Aktive Arbeit „<id>" nicht gefunden — zurück zur eingebauten Arbeit." (projects.js:36) · „Arbeit „<name>" ist nicht ladbar (<msg>) — zurück zur eingebauten Arbeit. Fehlerhafte Analyse-Dateien über „⭱ Analysen" erneut importieren." (projects.js:47).
- Import-Fehler: „Unbekanntes Format — erwartet "thesis-studio-projekt" mit parsed.thesis." · „Arbeit unvollständig — parsed.thesis.chapters fehlt/leer." · Confirm „Eine Arbeit mit der id „<id>" („<name>") existiert bereits.\nÜberschreiben? (Abbrechen = als Kopie importieren)" · Suffix „ (Kopie)".
- Hilfe-Flow-Steps: „LaTeX / Quelltext der Arbeit (bleibt unverändert)" → „Parsen / Gliederung, Absätze, Fußnoten/\cite — im Browser" → „GPT-Voranalyse / extern per Prompt: Belege, Dossiers, Connections" → „Prüfen / Splitscreen: PDF/Text markieren, Zitat + Position sichern" → „Belegstand / ✓ belegt — exportierbar als eine JSON-Datei". (Alle weiteren Hilfe-Texte: views_hilfe.js:18-205 wortwörtlich übernehmen — sie sind die Produkt-Doku.)
- Master-Prompt: kompletter Text views_projekt.js:494-562 MUSS zeichengenau übernommen werden (definiert das JSON-Austauschformat mit dem externen GPT); Anhang-Trenner: `'='.repeat(60) + '\nHIER DER LATEX-QUELLTEXT DER ARBEIT:\n' + '='.repeat(60)` (views_projekt.js:297).

---

## 6. Verhalten & Interaktionen

### Status-Kacheln (live)
- `#pPdf` startet mit „–" und wird async durch `countPdfs()` befüllt: für jede Quelle mit `Levels.positionType(id)==='seite'` (Artikel/Report-Dokumente) `await U.detectPdf(id)` zählen (views_projekt.js:43-49). `PdfStore.onChange` (an `statGrid` gebunden, auto-unsubscribe bei DOM-Entfernung) leert `U.pdfStatusCache` und zählt neu (:50).
- `#pLinks` wird von `refreshLinkStat()` nach „✓ alle übernehmen" aktualisiert (:90-93, 171).

### Quellen-Setup
- **Zeilenstatus:** `hasFile` (PdfStore) → `.ok` + „✓"; sonst `dl && !dl.ok` → `.dl-fail` + „✗" + Fehler-Chip mit `dl.note`; sonst „·" (:114-120). `U.getDlStatus` ist persistent — Fehlschläge bleiben über Sessions sichtbar.
- **„✓ alle übernehmen" (#qsAll):** für jede Quelle ohne `_override` → `takeOver(id)` (:94-99): übernimmt `links.official`/`links.file` als Override; hat die Quelle gar keine Links, wird `official='https://'` gesetzt (Platzhalter, zählt als „geprüft"). Danach `drawSetup()` + `refreshLinkStat()`.
- **Einzel-⭳ (data-dl):** Button disabled wenn Datei schon da oder kein `PdfEngine.dlLinkFor(id)`; Klick → disabled, Text „⏳", `await PdfEngine.tryDownload(id)`, dann `countPdfs()` + kompletter Redraw (:133-139).
- **↗:** echter `<a target="_blank" rel="noopener">` auf den gefundenen Direktlink, sonst disabled-Span (:124-126).
- **📄 (data-file):** Inline-Toggle — existiert direkt unter der Zeile schon `.qs-assign-host`, wird sie entfernt (zu); sonst alle anderen Panels entfernen, neues Host-Div per `row.after()` einfügen und `PdfEngine.assignPanel` hineinrendern; `onDone` → Panel weg + count + redraw, `onCancel` → nur Panel weg (:140-152). **Nur ein Panel gleichzeitig offen.**
- **Mitgelieferte Dateien:** async-Nachlauf prüft `sources/<id>.pdf` via `U.detectPdf` und patcht die bereits gerenderten Zeilen in-place (Klasse `ok`, st „✓", ⭳ disabled) — per `CSS.escape(s.id)`-Selektor (:154-166).
- **„⭳ Alle laden" (#qsDlAll):** Button disabled; Zielliste = alle Quellen ohne PdfStore-Datei UND ohne detektierte Repo-Datei; dann **sequentiell** (bewusst nicht parallel): je Ziel `msg = "⏳ i/N — <id> …"`, `tryDownload`, Zähler ok/fail, nach JEDEM Versuch `drawSetup()` (Liste aktualisiert sich live); Ende: `countPdfs()`, Abschlussmeldung, Button wieder enabled (:175-196).
- **„⭱ Import (PDF/ZIP)" (#qsImport):** delegiert an `importFilesModal` (views_quellen.js:718) mit Callback Cache-Reset + Neuzählen + Redraw (:197).

### Referenzierungsdurchläufe
Sortierung: Quellen absteigend nach `citations.length` (:210). „Durchlauf" → `Enhance.pasteModal({srcId}, 'quellen', {})` — derselbe GPT-Dialog wie überall (:221). Kein Auto-Refresh nach Modal (Liste aktualisiert sich erst bei erneutem Seitenaufbau).

### Arbeiten-Karte (🗂)
- Öffnen: Klick `#worksBtn` → `worksPop.innerHTML=''` + frisches `projektArbeitenCard()` (app.js:105-112); Outside-Click schließt (app.js:113-115).
- Liste lädt async (`Projects.list()`), Platzhalter „Lade …".
- **Aktivieren:** Klick auf ○ (nur wenn nicht aktiv) → `Projects.setActive(id)` → Hash `#/projekt` + **Full-Reload** (:295; projects.js:95-99). Kein sanfter State-Wechsel!
- **🤖 Gesamt-Prompt:** `U.copy(masterPrompt() + Trenner + rec.tex)` → Buttontext 1800 ms „✔ kopiert (inkl. LaTeX)" (:296-300).
- **⭱ Analysen:** öffnet `importAnalysenModal(rec, draw)` (:301).
- **⭳ Export:** `U.download('<id>.thesis-studio.json', Projects.exportProject(rec))` (:302).
- **🗑 Löschen:** `confirm(…)` → `Projects.remove(id)`; bei Builtin zusätzlich Tombstone in `ehds.builtinDeleted` (sonst würde `seedBuiltins` sie beim nächsten Start wieder einspielen, :306-313). War sie aktiv → `setActive('default')` (Reload), sonst nur `draw()` (:314-315).
- **Import (.json):** File-Input → `Projects.importProject(text)`; Erfolg → sofort `setActive(rec.id)` (Reload); Fehler → `alert('Import fehlgeschlagen: '+msg)` (:326-331).

### Modal „Neue Arbeit"
- **Live-Parse:** `input`-Event auf Textarea → Debounce 450 ms → `check()` (:421-423); `check()` läuft auch nach Datei-Load, Drop und PDF-Extraktion; `#naCheck` erzwingt Wiederholung. Leerer Text → Report leer, Create disabled (:409).
- `check()` rendert Erfolgs-Notice (Stats + erkannter Titel/Autor) ODER Fehler-Notice + je Fehler eine rote Zeile (`color:var(--bad)`) + je Warnung eine gelbe (`color:var(--warn)`); `#naCreate.disabled = !r.ok` (:407-420).
- **.tex laden:** Dateiinhalt in Textarea; Name-Feld wird, falls leer, aus Dateinamen (ohne `.tex/.txt`) vorbelegt; Input-`value` wird resettet, damit dieselbe Datei erneut wählbar ist (:368-372, 391).
- **PDF → LaTeX (Beta):** `PdfEngine.pdfToTex(arrayBuffer, cb)` mit Seiten-Progress im Report; Ergebnis-Tex in Textarea, Name aus `r.title` bzw. Dateinamen; nach `check()` wird die Beta-Notice VOR den Report gestellt (`insertAdjacentHTML('afterbegin')`) (:374-389). Fehler → rote Notice.
- **Drag&Drop:** aufs ganze Modal; `dragover` → `preventDefault` + Textarea-Klasse `droptarget`; `drop`: `.pdf` (Name-Regex oder MIME) → PDF-Pfad, sonst Tex-Pfad (:394-405).
- **Anlegen & aktivieren:** Name = Eingabe || geparster Titel || „Neue Arbeit"; `Projects.createFromTex` (parst erneut); Fehler → rote Notice mit `errors.join(' · ')`; Erfolg → `U.closeModal()` + `Projects.setActive(r.id)` (Reload) (:426-433).

### Modal „Analysen importieren"
- Multi-File-Input; je Datei: `.md` → als Erklärbuch übernommen (`rec.generated.erklaerbuch`, `rec.userModified=true`) (:454-460); sonst `JSON.parse` → `Projects.applyGeneratedFile` mit vier Ergebnisklassen: `{registryError}` (rot), `{registry}` (merken, „⏳ Registry erkannt…"), String (grüne ✓-Zeile), `null` (gelbe ⚠-Zeile); JSON-/Lese-Fehler rot (:462-470).
- **Registry zuletzt anwenden** (nach der Schleife): `Projects.applyRegistry` → Erfolg-/Fehlerzeilen (:472-481). Danach IMMER `Projects.save(rec)` + „Gespeichert." (:482-483).
- „Fertig": Modal zu; ist die Arbeit aktiv → `location.reload()`, sonst `onDone()` (Liste neu zeichnen) (:485-489).

### Projects.boot-Ablauf (Reihenfolge kritisch)
1. `activeId` aus `ehds.activeProject` (try/catch, Fallback default) (projects.js:21).
2. IndexedDB öffnen; Fehler → `db=null`, alle CRUDs werden No-Ops (getAll→[]) (:22-29).
3. `seedBuiltins()`: für jedes `window.BUILTIN_PROJECTS`-Objekt (derzeit: `sensors-paper`, „Mobile Sensors in Education (Paper)", builtin:true, builtinVersion:6 — js/data/project_sensors.js): skip wenn Tombstone; einfügen wenn nicht vorhanden; überschreiben NUR wenn `ex.builtinVersion < bp.builtinVersion` UND `!ex.userModified` (:66-79).
4. Wenn `activeId !== 'default'`: Record laden. Fehlt er → Warnung + Fallback default. Sonst **erst `U.storeProject = activeId`**, dann `activeName` + `buildRuntime(rec)`; wirft buildRuntime → Warnung + Fallback default (Storage-Keys der Default-Arbeit werden aber erst in Schritt 5 wieder korrekt, siehe :53) (:33-52).
5. `U.storeProject` final setzen: `''` für default, sonst id (:53).
6. Default-Fall: `PROJECT_ERKLAERBUCH`/`PROJECT_INSTANZEN` aus `DATA_META` (:56-59).
7. `mergeCustomSources()` — hängt manuelle Quellen (bereits projekt-gescoped gelesen) an `window.DATA_SOURCES` an, Duplikat-ids werden übersprungen (:60, 238-254).

### buildRuntime-Details (projects.js:154-220)
- `DATA_SECTIONS`-Keys sind Abschnitts-ids mit Unterstrichen (`3_2_1`).
- Beleg-Index: Map Fußnotennummer→Beleg aus allen generierten Abschnitten (:165-168); je Quelle werden `stellen` = citations angereichert um `claim/fundstelle/suchHinweis` (:171-174).
- Quellen-Links: `official` = `https://doi.org/<doi>` wenn DOI, sonst `url`; `file` aus Parse; immer `vorschlag:true` (d. h. unbestätigt) (:182).
- Fehlendes Dossier → `fallbackDossier` + `dossierFallback:true`; `zitierweise`-Fallback: `"<author> (<year>): <title|id>"` (:177-179).
- `DATA_META.stats`: quellen, fussnoten, absaetze, saetze, fnPerChapter, paraPerChapter, byKind, kindLabels (=`KIND_LABELS` aus util.js:926), topSources (Top 10 nach citations) (:204-219).

### applyGeneratedFile-Mapping (projects.js:130-151) — Reihenfolge der Prüfungen
1. `^\d+(_\d+)*\.json$` → `g.sections[<name ohne .json>]` (braucht `paragraphs`-Array) → „Abschnitt <file>"
2. `^kapitel-(\d+)\.json$` → `g.chapters[n]`
3. `gesamt.json` → `g.gesamt` → „Gesamtzusammenfassung"
4. `fazit-connections.json` (braucht `findings`-Array) → `g.fazit` → „Fazit-Connections"
5. `connections.json` (braucht `connections`-Array) → `g.connections` → „Connections"
6. `^(struktur|quellen|inhalt|standards)\.json$` → `g.analyse[<name>]` → „Analyse: <file>"
7. `instanzen.json` (braucht `defs`-Array) → `g.instanzen` → „Instanz-Set (N Instanzen)"
8. `figures.json` → `rec.figures` → „Abbildungs-Manifest"
9. `registry.json` → muss ARRAY sein, sonst `{registryError}`; sonst `{registry}` (Anwendung separat)
10. Inhaltsbasiert: `obj.sourceId && obj.dossier` → `g.sources[sourceId]` → „Dossier <id>"; `obj.sectionId && paragraphs` → Abschnitt (Punkte→Unterstriche)
11. sonst `null` (⚠ im Log). Jeder Treffer setzt `rec.userModified = true` (:131).

### createFromTex-id-Schema (projects.js:105-106)
`'p-' + name.toLowerCase().replace(/[^a-z0-9]+/g,'-').Trim('-').slice(0,30) + '-' + random4(base36)` — z. B. `p-masterarbeit-xy-k3f9`. Import ohne id: `p-import-<random6>`; Kopie: `<id>-kopie-<random3>` (:274, 278).

---

## 7. Datenformen

### Projekt-Record (IndexedDB `ehds-projects/projects`, auch Export-JSON mit `format`/`version` davor)
```jsonc
{
  "id": "p-masterarbeit-xy-k3f9",       // 'default' existiert NICHT in der DB (nur virtuell)
  "name": "Masterarbeit XY",
  "created": "2026-07-23T10:00:00.000Z",
  "builtin": true,                       // nur eingebaute (sensors-paper)
  "builtinVersion": 6,                   // Versionssprung-Update nur wenn !userModified
  "userModified": true,                  // gesetzt bei jedem Analyse-Import/Registry-Apply
  "tex": "\\documentclass…",           // kompletter LaTeX-Quelltext (Ground Truth)
  "registry": [ { "id": "cobrado2024", "kind": "artikel", "author": "…", "year": 2024,
      "title": "…", "container": "…", "doi": "…", "url": "…",
      "links": { "official": "https://…", "file": "https://….pdf" },
      "aliases": ["Cobrado"] } ],
  "parsed": {
    "thesis":   { "meta": {"title":"…","author":"…","university":"…","date":"…"},
                  "chapters": [ { "num": 1, "title": "…", "sections": [
                      { "id":"1.1", "title":"…", "paragraphs":[{ "footnotes":[…] , …}], "children":[…] } ] } ] },
    "footnotes": [ { "num": 1, "text": "Vgl. …", "sourceIds": ["cobrado2024"] } ],
    "sources":   [ { "id":"cobrado2024","kind":"artikel","author":"…","year":2024,"title":"…",
                     "container":"…","longTitle":"…","doi":"…","url":"…","file":null,
                     "citations":[{"footnote":12,"sectionId":"3.2.1"}] } ]
  },
  "generated": {
    "sections": { "3_2_1": { "sectionId":"3.2.1", "paragraphs":[ {
        "id":"3.2.1-p1", "type":"text",
        "kernaussage":"…",
        "sentences":[{"text":"… [^12]","einfach":"…","kategorien":["norm"],
                      "marks":[{"snippet":"…","kategorie":"norm"}]}],
        "belege":[{"num":12,"quellen":["cobrado2024"],"claim":"…","fundstelle":"S. 4",
                   "suchHinweis":"exakte Passage|zweite Passage"}] } ] } },
    "sources":  { "cobrado2024": { "sourceId":"cobrado2024","dossier":"## …","keyPoints":["…"],
                                    "zitierweise":"…","hinweisOhnePdf":"…" } },
    "chapters": { "3": { "kurzfassung":"…","kernaussagen":["…"],"begriffe":[{"begriff":"…","erklaerung":"…"}],
                          "fristen":[{"datum":"…","was":"…"}],"abschnitte":[{"id":"…","titel":"…","einzeiler":"…"}],
                          "fazitBeitrag":"…" } },
    "gesamt": { "executiveSummary":"…","ergebnisse":{"positiv":[],"luecken":[],"spannungen":[]},
                "roterFaden":[{"kapitel":1,"label":"…","text":"…"}],"timeline":[{"datum":"…","label":"…","typ":"…"}] },
    "fazit": { "findings":[{"id":"…","label":"…","typ":"positiv","beschreibung":"…",
               "fazitParagraphId":"…","abschnitte":["…"],"fristen":["…"]}], "kapitelFluss":[{"von":1,"nach":2,"label":"…"}] },
    "analyse": { "struktur": {"titel":"…","markdown":"…","punkte":[{"typ":"…","text":"…"}]},
                 "standards": {"titel":"…","verdikt":"…","markdown":"…",
                   "kriterien":[{"name":"…","note":"solide","text":"…"}],"verbesserung":["…"]} },
    "connections": { "connections":[{"id":"c1","typ":"folgerung","von":{"sectionId":"5.3.3","paraId":"5.3.3-p2"},
                     "nach":{"sectionId":"6.0","paraId":"6.0-p5"},"label":"…","text":"…"}] },
    "instanzen": { "defs":[{"id":"…","label":"…","color":"var(--cat-tech)","desc":"…"}],
                   "items": { "<instanz-id>": { "<absatz-id>": "<markdown>" } } },
    "erklaerbuch": "<Markdown-String>"   // via .md-Import
  },
  "figures": { "figuren": [ { "id":"fig1", "file":"…", … } ], "tabellen": [] }
}
```

### Laufzeit-Quelle in `window.DATA_SOURCES` (Instanz-Arbeit, buildRuntime-Output)
```jsonc
{ "id":"cobrado2024", "kind":"artikel", "author":"…", "year":2024, "title":"…", "container":"…",
  "doi":"…", "citations":[{"footnote":12,"sectionId":"3.2.1"}],
  "dossier":"## …", "keyPoints":["…"], "zitierweise":"…", "hinweisOhnePdf":null, "dossierFallback":false,
  "links": { "official":"https://doi.org/…", "file":null, "vorschlag":true },
  "stellen":[{ "footnote":12, "sectionId":"3.2.1", "claim":"…", "fundstelle":"…", "suchHinweis":"a|b" }],
  "custom": true              // nur bei manuellen Quellen aus customSources
}
```

### PdfEngine.tryDownload-Ergebnis: `{ ok: boolean, note?: string }`; persistierter dlStatus: `{ ok, note }` je srcId.
### TexParse.parse-Ergebnis: `{ ok, errors:[], warnings:[], stats:{kapitel,abschnitte,fussnoten}, thesis, footnotes, sources }`.
### pdfToTex-Ergebnis: `{ tex, title, pages, headings, footnotes }`.

---

## 8. Abhängigkeiten

**views_projekt.js →** `Projects` (activeName, bootWarnings, list, setActive, remove, exportProject, importProject, createFromTex, applyGeneratedFile, applyRegistry, save, activeId), `U` (el, esc, modal, closeModal, copy, download, storeGet, srcLinks, setSrcLink, getDlStatus, getResolutions, detectPdf, pdfStatusCache, srcShort), `Levels`, `PdfStore`, `FigStore`, `PdfEngine` (dlLinkFor, tryDownload, assignPanel, pdfToTex), `TexParse.parse`, `Enhance.pasteModal`, `importFilesModal` (views_quellen.js:718), `orderedUnits`, `fileIdOf`, `KIND_LABELS`, `window.DATA_*`, `localStorage` (nur `ehds.builtinDeleted` direkt), `confirm`/`alert`, `CSS.escape`.
**views_projekt.js wird genutzt von:** Router (`renderProjekt`), app.js:110 (`projektArbeitenCard` ins `#worksPop`).

**views_hilfe.js →** nur `U.el`. Genutzt vom Router (`renderHilfe`). Verlinkt statisch auf `docs/PROJEKT-FORMAT.md`, `docs/QUELLEN-WORKFLOW.md`, `https://robinkarner.github.io/thesoR/`.

**projects.js →** `TexParse.parse`, `U.storeProject/storeGet/storeSet`, `KIND_LABELS`, `window.BUILTIN_PROJECTS` (js/data/project_sensors.js), `window.DATA_*`, `indexedDB`, `localStorage`, `confirm` (importProject).
**projects.js wird genutzt von:** App-Boot (muss `Projects.boot()` awaiten bevor irgendetwas rendert), views_projekt.js, enhance.js:743 (liest `BUILTIN_PROJECTS`-Eintrag `sensors-paper` direkt), Topbar (activeName), sämtliche Views indirekt über die `DATA_*`-Globals und das Storage-Scoping.

---

## 9. Flutter-Hinweise

1. **`location.reload()` als Architektur-Muster:** Arbeitswechsel/Analyse-Import erzwingen einen kompletten App-Neustart (projects.js:98, views_projekt.js:487). In Flutter stattdessen: Projektwechsel als State-Reset — alle Provider (DATA_THESIS/SOURCES/… als Riverpod-Provider) invalidieren und den Boot-Fluss (`Projects.boot`-Äquivalent) erneut ausführen; kein echter Neustart nötig, aber die Semantik „ALLES ist danach frisch" muss erhalten bleiben (auch offene Panels, Scrollstände etc. verwerfen).
2. **Storage-Namespacing exakt nachbauen:** Ein zentraler Key-Builder `'ehds.' + (scoped ? projectId + '.' : '') + key` mit der PROJECT_KEYS-Whitelist (util.js:200-205) — z. B. via SharedPreferences/Hive-Box je Projekt. Unscoped bleiben `ehds.activeProject` und `ehds.builtinDeleted`. Die Reihenfolge „Scope setzen VOR Runtime-Aufbau" (projects.js:40-42) unbedingt beibehalten, sonst Kontamination des Default-Prüfstands.
3. **IndexedDB `ehds-projects` → z. B. Drift/Hive/Isar:** Ein Store, keyPath `id`, Records sind große verschachtelte JSON-Objekte inkl. komplettem LaTeX-String (bei sensors-paper mehrere 100 KB). Als Blob/JSON-Spalte speichern, nicht normalisieren — Export/Import erwartet 1:1 dieselbe Struktur (`format:'thesis-studio-projekt', version:1`).
4. **Builtin-Seeding + Tombstones:** `sensors-paper` (builtinVersion 6) als Asset bündeln; beim Boot einspielen mit exakt der Logik „nicht vorhanden → rein; vorhanden → nur ersetzen wenn builtinVersion kleiner UND !userModified; Tombstone → nie" (projects.js:66-79). `default` ist eine rein virtuelle Zeile (nie in DB) — in der Arbeiten-Liste hart als erste Zeile gerendert (views_projekt.js:319).
5. **Statgrid/dash-cols:** `GridView`/`Wrap` mit `minmax(155px,1fr)`-Verhalten (z. B. `SliverGridDelegateWithMaxCrossAxisExtent`); Zwei-Spalten-Dashboard 1.55fr/1fr mit Breakpoint 999px → einspaltig (`LayoutBuilder`).
6. **`.qs-rows` max-height 420px mit eigenem Scroll** und das **Inline-Assign-Panel als einschiebbare Zeile unter der Quellzeile** (Toggle, nur eins offen) — in Flutter als expandierbares ListItem (AnimatedSize/ExpansionTile-artig), nicht als Dialog.
7. **Sequentieller Bulk-Download mit Live-Redraw** nach jedem Versuch (views_projekt.js:185-190): als Stream/async-Schleife mit `setState` pro Schritt; persistenter Fehlstatus (`dlStatus`) muss die ✗-Zeilen auch nach App-Neustart rot markieren. CORS-Problematik entfällt nativ — aber Paywalls/HTML-statt-PDF-Antworten weiterhin als Fehlernote behandeln.
8. **`U.detectPdf` (Repo-Ordner `sources/<id>.pdf`)** existiert in Flutter nicht als HTTP-HEAD auf eigene Origin — Ersatz: gebündelte Assets-Liste oder Verzeichnis-Scan; die async-Nachpatch-Logik (views_projekt.js:154-166) wird dann ein zweiter State-Durchlauf.
9. **Native `<details>`-Akkordeons** (Anleitung, ▸-Rotation aus CSS app.css:821-826) → `ExpansionTile`/custom mit 0.15s-Rotation.
10. **Hilfe-Seite ist reiner statischer Content** — als konstante Widget-Struktur oder Markdown-Assets; die Tabellen brauchen horizontales Scrollen (`overflow-x:auto` → `SingleChildScrollView(scrollDirection: horizontal)`); Flow-Diagramm als Row mit horizontalem Scroll.
11. **Clipboard + Datei-Dialoge:** `U.copy` → `Clipboard.setData`; `U.download` → file_saver/share_plus; Multi-File-JSON-Import + .tex/.pdf-Picker → file_picker (`allowMultiple`, Extension-Filter wie accepts). **Drag&Drop von Dateien** aufs Modal geht nur Desktop (desktop_drop) — auf Mobile Fallback auf Picker.
12. **`confirm`/`alert`-Dialoge** (Löschen, Import-Kollision mit Drei-Wege-Semantik OK=überschreiben/Abbrechen=Kopie!) → eigene Dialoge; die Kopie-Logik (id-Suffix `-kopie-xxx`, Name-Suffix „ (Kopie)") exakt übernehmen.
13. **masterPrompt() als konstanter String** 1:1 übernehmen (inkl. Backticks/Formatierung) — er ist Vertragstext gegenüber dem externen GPT; ebenso der Anhang-Trenner mit `'='*60`.
14. **PdfEngine.pdfToTex (pdf.js-Heuristik)** hat kein direktes Flutter-Pendant — Kandidaten: eigene Extraktion via pdfrx/pdfium-Textlayer + Schriftgrößen-Heuristik nachbauen; Beta-Charakter und Ergebnis-Metriken (pages/headings/footnotes-Kandidaten) in der UI beibehalten.
15. **Debounce 450 ms** für den Live-Parse (Timer), Buttontext-Rückstellung nach **1800 ms** (Gesamt-Prompt) — exakte Zeiten übernehmen.
16. **Icon-Zeichen:** `⭳ ⭱ ＋ ⌖ ◐ ⇤ ⇥ ∅ ⤳` sind Unicode-Textzeichen, keine Icons — Font-Abdeckung in Flutter prüfen (ggf. Noto Sans Symbols 2 einbetten), sonst brechen die Labels.

---
*Ende Dossier 07.*
