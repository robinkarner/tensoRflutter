# Inventar-Dossier 03 — `js/views_studio.js` (2523 Zeilen)

> Der Studio-Arbeitsraum: 3-Spalten-Layout (TOC links / Inhalt Mitte / Quellen-Spalte rechts) mit Drag-Resize + Einklappen, Modus-Leiste ☰ Lesen / ◉ Analyse (intern „pruefen") / ✎ LaTeX (intern „editor"), Beleg-Workflow mit PDF-Anker, Views/Instanz-Fenster, Referenzierungs-Vollbild-Split, `#/doc`-Gesamtdokument, Absatz-Doppelklick-Editing, Scroll-Restoration.

---

## 1. Zweck & Rolle

`views_studio.js` ist das **Hauptprogramm** der App (Kommentar views_studio.js:1-13): der „V5-Arbeitsraum". Ein Ort, drei Modi, umschaltbar pro URL (`#/studio/<id>/<modus>`). Es rendert das gesamte Studio-Gerüst (`renderStudio`, views_studio.js:40), den Kapitelbaum links (`studioTree`, :212), die Modus-Leiste (`studioBar`, :147), die drei Modi-Inhalte (`renderLesenMode` :360, `renderPruefenMode` :521, Editor wird an `renderEditorPane` aus editor.js delegiert, :129) und die Quellen-Spalte rechts (`renderFilePane`, :1250) mit PDF-Viewer, Quell-Karte und Beleg-Dock unten.

Zusätzlich enthält die Datei:
- Das **Views/Instanz-System** („Dock"): pro Absatz ein zweites Fenster neben der Karte (⤳ Connections-Graph, 🌐 Übersetzung, ✎ Erklärung, ✦ Analyse, eigene KI-Views), verwaltet über `dockDefs`/`paraDock`/`dockBySection` (views_studio.js:2111-2337) inkl. View-Verwaltungs-Modal (`instanzEditModal`, :2360) und KI-Generierung (`viewGenerate`, :2458; Prompts :2484-2522, :688-706).
- Den **Referenzierungsmodus** („Große Ansicht"): Vollbild-Overlay mit Zitierelementen links und PDF/Text/Register rechts (`openRefMode` :1704 ff., `RefMode`-State :1702).
- Die **`#/doc`-Ansicht** (`renderDoc`, :451): die ganze Arbeit als ein fortlaufendes Dokument mit LaTeX-Export/PDF-Druck.
- **Absatz-Doppelklick-Editing** direkt im Text (`paraEditStart`, :790) mit Persistenz als `paraEdits`-Override + LaTeX-Sync.
- **Erwähnungs-Workflow** (Autor-(Jahr)-Nennungen ohne Fußnote: bestätigen/verwerfen/mit Beleg zusammenführen, :947-1025).
- Den eingebetteten PDF-Viewer der Quellenseite (`renderDetailPdf`, :1657 — wird von views_quellen.js genutzt).
- `fileShow` (:1479): globaler Einstieg „diese Quelle/Fußnote rechts anzeigen" (auch aus app.js bei Klick auf Quellen-Markierung im Text).

---

## 2. Öffentliche API

Alle Funktionen/Konstanten sind top-level `const`/`function` in einem klassischen `<script>` — d. h. **global** (kein Modul-System).

### Exportiert (von anderen Dateien konsumiert)

| Symbol | Signatur | Zweck | Genutzt von |
|---|---|---|---|
| `Studio` | Objekt (views_studio.js:16-36) | zentraler Studio-State + `MODES`, `genFor(sectionId)`, `genPara(sectionId, paraId)` | enhance.js (`Studio.styleCheck`, `Studio.file.srcId`), app.js (`Studio.mode`), überall intern |
| `renderStudio` | `(root, sectionId, mode, focusPara)` :40 | baut den kompletten Arbeitsraum in `root` | app.js:229 (Routen `#/studio`, `#/home`, ``), app.js:240 (Fallback) |
| `renderDoc` | `(root)` :451 | `#/doc` Gesamtdokument-Ansicht | app.js:230 |
| `routeRefresh` | `()` :140 | `#app` leeren + `renderStudio(app, Studio.sectionId, Studio.mode)` | enhance.js (:107,124,141,171,451,533,925), intern überall |
| `fileShow` | `(srcId, fnNum)` :1479 | Quelle/Beleg in Quellen-Spalte aktivieren; in „lesen" → Moduswechsel zu „pruefen" | app.js:96-97 (Klick auf `mk-src`-Markierung), intern (Erwähnungen, Beleg-Klick) |
| `renderDetailPdf` | `async (body, srcId, fnNum)` :1657, plus statisches `renderDetailPdf._ctl` | PDF-Panel „Anhang (PDF)" der Quellenseite | views_quellen.js:556; app.js:214-216 (destroy beim Routenwechsel) |
| `sourcePickerModal` | `(sectionId, currentId, onPick)` :1217 | durchsuchbarer Quellen-Picker (Modal), gruppiert „Belege dieses Abschnitts"/„Alle Quellen" | editor.js:246-248, intern (sf-Bar :1407) |
| `marksPromptFor` | `(sectionId) → string` :688 | GPT-Prompt für Schlüsselstellen-Markierungen | enhance.js:103 |
| `instanzPrompt` | `() → string` :2484 | globaler Views-Prompt (alle Text-Views × alle Absätze) | enhance.js:137 |
| `sectionSources` | `(sectionId) → Map<srcId, fnNum[]>` :1202 | Quellen↔Fußnoten des Abschnitts | enhance.js:154, intern |
| `dockDefs` | `() → def[]` :2143 | effektive View-Definitionen (Defaults + Projekt + `instDefs`-Overrides) | views_analyse.js:128,225; enhance.js:203,271 |
| `dockGet` | `(mode, paraId) → md` :2168 | gespeicherter View-Inhalt eines Absatzes | views_analyse.js:188,235 |
| `dockAuto` | `(mode, sectionId, p) → md` :2184 | automatische Vorbefüllung (Übersetzung/Erklärung/Analyse/Projekt-Items) | views_analyse.js:188,235 |
| `studioHash` | `(id, mode) → '#/studio/<id>/<mode>'` :38 | Link-Helfer | intern, Links überall |

### Nur intern (aber global sichtbar)
`studioBar` :147, `studioHeader` :188, `studioTree` :212, `editTreeTitle` :272, `progDots` :302, `sectionNav` :310, `stripFigMarker` :319, `farbControl` :326, `renderLesenMode` :360, `lesenSection` :392, `kompaktSection` :492, `renderPruefenMode` :521, `applySrcView` :581, `applyStyleCheck` :610, `styleCheckModal` :625, `instanzBar` :646, `paraMarks` :681, `paragraphCard` :708, `paraEditStart` :790, `paraEditBadge` :836, `appendScFlag` :859, `refreshParagraphText` :869, `paraBelege` :897, `toggleParagraph` :902, `refreshResolution` :913, `buildResolution` :930, `belegRow` :1033, `showBelegSpan` :1134, `openSpanCtl` :1151, `selectBeleg` :1187, `renderFilePane` :1250, `renderFileDock` :1498, `belegChecklist` :1602, `afterLevelChange` :1646, `RefMode` :1702, `openRefMode` :1704, `refEsc` :1781, `closeRefMode` :1788, `refSetActive` :1800, `refActiveInfo` :1812, `refItem` :1821, `markWords` :1910, `refShowSource` :1925, `renderSrcTextPane` :2031, `DOCK_DEFAULTS` :2127, `projectInstDefs` :2139, `dockDef`/`dockLabel`/`dockIsText` :2163-2165, `dockStore`/`dockSet` :2167-2174, `dockModeFor` :2177, `dockClose` :2201, `psHead` :2211, `psResize` :2221, `paraSide` :2232, `sideGraph` :2296, `texMaterials` :2351, `instanzEditModal` :2360, `viewGenerate` :2458, `instanzPromptFor` :2485.

### Konsumierte Globals (aus anderen Modulen)
- **util.js `U`**: `storeGet/storeSet` (projekt-gescoptes localStorage), `el`, `esc`, `md`, `richText`, `modal`, `closeModal`, `copy`, `download`, `resizer`, `clearHighlight`/`setHighlight` (CSS Custom Highlight API), `domRangeFor`, `belegSpan`, `setSpanBack`, `searchTerms`, `srcShort`, `srcLinks`, `srcStripHtml`, `dossierModal`, `detectPdf`, `getSrcDoc`, `getSrcText`/`setSrcText`, `getFnEdits`/`setFnEdit`, `findBeleg`, `claudeConfigModal`.
- **Daten-Indizes (app.js/data)**: `UNIT_INDEX`, `FN_INDEX`, `SRC_BY_ID`, `FIG_BY_PARA`, `TAB_BY_PARA`, `CAT_ORDER`, `CAT_LABELS`, `KIND_ICONS`, `KIND_LABELS`, `orderedUnits()`, `fileIdOf()`, `rebuildDataIndexes()`, `provisionRegister()` (:1983).
- **window-Daten**: `window.DATA_SECTIONS` (Voranalyse je Datei-ID, :31), `window.DATA_THESIS` (Kapitelbaum + meta), `window.DATA_SOURCES`, `window.PROJECT_INSTANZEN` (`{defs, items}`, :2140, :2196).
- **Module**: `Levels` (Beleg-Level 1/2/3, Farben, `info/save/clear/entry`, `numsForSection/Source/Chapter`, `bar`, `dot`, `badge`, `countsFor`, `positionType`, `farbHex`, `farbeFor`, `autoFarbe`, `FARBEN`, `L`), `Mentions` (`forPara`, `setStatus`, `mergeTarget`, `_paraCache`), `PdfEngine` (`mount`, `assignPanel`, `renderDocView`, `marksForFn`, `missingInfo`), `PdfStore` (`has`, `open`, `getUrl`), `Editor` (`fullDocument`, `saveEdit`, `reconstruct`), `Connections` (`forSection`, `TYPES`), `StyleCheck` (`analyzePara`), `ClaudeAI` (`ready`, `run`, `clean`, `fmtTok`, `fmtEur`), `Enhance` (`_importInst`), `figureCard`/`tableCard` (figures.js), `renderEditorPane` (editor.js).

---

## 3. State & Persistenz

Alle Persistenz via `U.storeGet(key, default)` / `U.storeSet(key, val)` — **projekt-gescoptes localStorage** (Kommentar :269 „projekt-gescopt"; die Scoping-Mechanik liegt in util.js/projects.js).

### localStorage-Keys (Lesen & Schreiben in dieser Datei)

| Key | Datenform (Beispiel) | Gelesen | Geschrieben |
|---|---|---|---|
| `cats` | `["norm","frist","akteur","tech","these","luecke","zahl","abk","schlag"]` (Array aktiver Kategorien; Default `CAT_ORDER`) | :18 | :747 (Kategorie-Chip-Klick) |
| `studioMode` | `"pruefen"` (`lesen`\|`pruefen`\|`editor`; Default `pruefen`) | :20 | :43 (bei Routenwechsel mit gültigem Modus) |
| `lesenDichte` | `"normal"` \| `"kompakt"` | :21 | :176, :508 (Kompakt-Zeilen-Klick setzt zurück auf normal) |
| `lesenFast` | `true`/`false` — ⚡ Schnelllese-Anstrich im Lesen | :22 | :170 |
| `lesenMarks` | `true`/`false` — 🖍 dezente Markierungen im Lesen | :23 | :173 |
| `uiDockMode` | `"connections"` (View-ID) oder `null` (Ohne); Default `"connections"` | :24 | :672 (Instanz-Leiste), :2391 (View gelöscht) |
| `uiSfDockClosed` | `true`/`false` — Beleg-Dock eingeklappt | :27 | :1440, :1460 |
| `uiStyleCheck` | `true`/`false` — 🤖 Stil-Check an | :28 | (nur enhance.js:451) |
| `studioLast` | `"3.2"` (zuletzt geöffneter Abschnitt) | :41 | :49 |
| `uiFileOff` | `true`/`false` — Quellen-Spalte eingeklappt | :60 | :111 (Rail einblenden→false), :1281/:1432 (⇥ einklappen→true), :1490 (`fileShow`→false) |
| `uiTreeOff` | `true`/`false` — TOC eingeklappt | :61 | :119, :225 |
| `uiFileW` | `520` (px, Breite Quellen-Spalte) | :66 | via `U.resizer` store (:99); geklemmt auf `min(v, round(innerWidth*0.50))` (:64) |
| `uiTreeW` | `260` (px, Breite TOC) | :66 | via `U.resizer` (:83); Cap `round(innerWidth*0.26)` |
| `titleEdits` | `{"ch3": "Neuer Kapiteltitel", "3.2": "Neuer Abschnittstitel"}` (Key = `ch<num>` oder Abschnitts-ID; leer löschen = Original) | :285 | :288 (→ danach `rebuildDataIndexes()`) |
| `paraEdits` | `{"p-3.2-4": "Neuer Absatztext mit [^12] Marker …"}` — Absatz-Override | :816, :838 | :818 (Doppelklick-Edit), :847 (↺ Original) |
| `marksExtra` | `{"p-3.2-4": [{"snippet":"EHDS","kategorie":"abk"}]}` — zusätzliche (KI-)Markierungen je Absatz | :684 | (geschrieben von enhance.js-Import) |
| `uiPsW` | `320` (px, Breite Instanz-Fenster) | :536 | via `U.resizer` (:2227), min 200, max 560 |
| `uiSfDockH` | `260` (px, Höhe Beleg-Dock) | :1449 | via `U.resizer` (:1455); auf `null` beim Auto-Zuklappen (:1461) |
| `uiRefW` | `380` (px, Breite Zitierelemente-Spalte im Ref-Modus) | :1741 | via `U.resizer` (:1746), min 240 |
| `instDefs` | `[{"id":"uebersetzung","label":"🌐 Übersetzung","desc":"Eine präzise ÜBERSETZUNG …","color":"var(--cat-norm)","srcTex":""}, …]` — Views-Reihenfolge/Namen/Aufträge; `null` = Standard | :2149 | :2390 (`save`), :2447 (↺ Standard → null) |
| `paraDock` | `{"erklaerung": {"p-3.2-4": "**Kurz:** …"}, "meine-view": {…}}` — View-Inhalte (Markdown) je View-ID je Absatz-ID | :2167 | :2173 (`dockSet`), :2395 (`wipeContent`) |
| `dockBySection` | `{"3.2": null, "4.1": "analyse"}` — Abschnitts-Override der aktiven View (`null` = explizit geschlossen) | :2178 | :673 (globale Wahl leert alles auf `{}`), :2203-2206 (`dockClose`) |
| `srcExtras` | `{"Vallejo2022": [{"kind":"tex","name":"LaTeX","text":"\\section{…}"}]}` — nur **gelesen** (:2352, Σ-Materialien) | :2352 | (geschrieben in views_quellen.js) |

### In-Memory-State

- `Studio._scroll` (:29): `{ "<mode>|<sectionId>": scrollY }` — Scrollstand je Modus+Abschnitt; gesetzt vor Modus-/Dichte-/View-Wechsel (:165, :178, :674, :2205), wiederhergestellt in :136-137 via `requestAnimationFrame(() => window.scrollTo(0, back))` — außer `focusPara` gesetzt ist.
- `Studio.sel` (:25): `{ srcId, fn }` — aktiver Beleg (Ziel der PDF-Markierung); überlebt Re-Render/Moduswechsel (:555-560 öffnet die Karte des aktiven Belegs wieder).
- `Studio.file` (:26): `{ srcId, fn, ctl (PdfEngine-Controller), panel (Quell-Karte), el (aside-DOM), drawDock (Fn, :1340), gen (Race-Token, :1349) }`.
- `RefMode` (:1702): `{ el, sectionId, paraId, srcId, activeFn, engine, views: {srcId: 'pdf'|'text'|'register'} }` (views :1940-1945; `'datei'` ist transient, wird nie gemerkt :1944-1945).
- `renderDetailPdf._ctl` (:1660): Engine-Controller der Quellenseiten-PDF-Ansicht.
- `p._orig` (:814): Original-Absatztext vor Edit (nur Session). `fn._origText` (:1560): Original-Fußnotentext.
- `chosenByKey` (:956): Kandidaten-Auswahl bei mehrdeutigen Erwähnungen (überlebt Neuzeichnen der Liste, nicht den Re-Render).

---

## 4. UI-Struktur & Layout

### 4.1 Studio-Gerüst (`renderStudio`, :56-122; CSS app.css:164-209)

```
#app
└── div.studio                              ← CSS Grid
    ├── nav.card.flat.studio-tree           ← grid-area: tree (GANZ LINKS)
    │   ├── div.st-bar  (Kopf: „☰ Inhaltsverzeichnis" + ⇤-Button .sf-iconbtn.st-collapse)
    │   └── div.st-body (scrollt: overflow-y:auto)
    │       └── div.tree-ch[.open]* (je Kapitel)
    │           ├── button > span.tc-caret「▸」 span.tn(Nr) span.tc-title Levels.bar() span.tree-ren「✎」
    │           └── ul[hidden?] > li > a[.l3][.active] (span.tn span.ts-title span.prog) + span.tree-ren
    ├── div.pane-resize.tree-resize         ← grid-area: trs (7px Griff)
    ├── div.studio-content                  ← grid-area: content (minmax(0,1fr))
    │   ├── div.studio-bar                  ← sticky top:var(--topbar-h), z-40, min-height:54px
    │   │   ├── div.mode-switch[role=tablist] > a[role=tab]×3 (☰ Lesen · ◉ Analyse · ✎ LaTeX)
    │   │   ├── div.bar-mid  (nur „lesen": span.dichte-switch mit Normal/Kompakt/🖍/⚡)
    │   │   └── div.bar-tools (leer)
    │   ├── div.studio-head > div.sec-head>h2 + div.sec-meta
    │   └── div.studio-inner[.wide (editor)][.dock-on][.srcview-on][.fastread-on]
    │       └── (modusabhängig, siehe unten)
    ├── div.pane-resize.file-resize         ← grid-area: frs
    ├── aside.studio-file[aria-label=Quellen] ← grid-area: file (GANZ RECHTS)
    ├── button.file-rail  (nur wenn hasFile) > span.fr-ic「⇤」 span.fr-tx「Quellen」
    └── button.tree-rail  > span.fr-ic「⇥」 span.fr-tx「Inhaltsverzeichnis」
```

- **Grid**: `grid-template-columns: var(--tree-w-c) 7px minmax(0,1fr) 7px var(--file-w-c)`, areas `'tree trs content frs file'`, `gap: 0 10px`, `align-items:start` (app.css:170-174). Defaults: `--file-w: clamp(400px,30vw,640px)` gekappt auf `50vw`; `--tree-w: 240px` gekappt auf `26vw` (app.css:168-169). JS klemmt gespeicherte Breiten zusätzlich gegen den Viewport (:62-68).
- **Einklappen**: Klassen `file-off`/`tree-off` am `.studio` entfernen Spalte+Griff aus dem Grid (app.css:184-189). In „lesen" ist `file-off` immer aktiv (`hasFile = Studio.mode !== 'lesen'`, :59).
- **Rand-Leisten** (`file-rail`/`tree-rail`): nur sichtbar wenn Spalte eingeklappt; `position:fixed`, `top: calc(var(--topbar-h) + 78px)`, Breite 34px, vertikaler Text (`writing-mode: vertical-rl`), rechts/links am Rand angeschlagen mit einseitig abgerundeten Ecken (app.css:484-498).
- **Resize-Griffe**: `U.resizer` (util.js) — Drag ändert CSS-Var live, Doppelklick = Standard (`apply(null)`), Wert wird unter `store`-Key gemerkt. TOC: min 180, max `max(420, min(680, 40vw))` (:83). Quellen-Spalte: min 320, max `max(560, 50vw)`, `dir:-1` (Ziehen nach links vergrößert), `done` → `Studio.file.ctl.refresh()` (:96-101).
- **Sticky**: `.studio-bar` sticky unter der Topbar (app.css:292); `.studio-file` sticky mit fester Höhe `calc(100vh - var(--topbar-h) - 22px)` (app.css:435-437); `.studio-tree` analog (app.css:216 ff., mit 8×8px Accent-Eckmarker `::before`).
- **Responsive** (`max-width: 999px`, app.css:192-205): einspaltig gestapelt `'tree' 'content' 'file'`, Griffe weg, `.studio-file` static mit `height: min(78vh, 760px)`, Baum max-height 300px. Rails rutschen auf `top: topbar+12px` (app.css:501-503).
- **Print** (app.css:1293-1298): Topbar/Spalten/Bar/Rails ausgeblendet, Grid einspaltig — Grundlage für „🖨 Als PDF drucken".
- `.studio-inner`: `max-width: 980px; margin-inline:auto`; mit `.wide` (Editor) unbegrenzt; mit `.dock-on` `max-width:1320px; margin-inline:auto 0` (rechtsbündig, app.css:1489).

### 4.2 Lesen-Modus (:360-516)

```
studio-inner
├── div.inst-bar.row (Views-Leiste, s. 4.5)
└── div.lesen-doc[.kompakt]
    ├── div.lesen-sec[.fastread][data-sec=<id>]*   (je Abschnitt, rekursiv über Kapitelbaum)
    │   ├── h3 > span.sn(Label) Titel span.pg > a.mut(„S. n") + a.mut(„◉ Analyse")
    │   ├── p.lesen-p* | ul.lesen-list>li* | figureCard | tableCard | div.fig-missing
    │   └── div.lesen-inst (nur Text-View aktiv u. Inhalt da) > span.li-t(Label) div.li-b(Markdown)
    └── nav (flex spread): „← Kapitel n" / „Kapitel n →"
```
Kompakt (`kompaktSection`, :492): je Absatz ein `li` in `ul.kern-list` mit Kernaussage (bzw. „Aufzählung: N Punkte" oder Text-Anriss 180 Zeichen + ` …`); Klick → Dichte normal + Sprung in den Abschnitt (:506-511). Anfangs-Scroll: `[data-sec]` des aktiven Abschnitts via `scrollIntoView({block:'start', behavior:'instant'})`, außer Intro oder gemerkter Scrollstand (:384-389).

### 4.3 Prüfen-Modus (:521-575)

```
studio-inner[.dock-on|.fastread-on|.srcview-on]
├── div.inst-bar.row
├── (je Absatz)  entweder  article.card.para-card[data-para][data-sec]
│                oder      div.para-row > para-card + aside.para-side   (View aktiv)
│   └── para-card:
│       ├── div.para-body[tabindex=0][role=button][aria-expanded]
│       │   ├── div.para-text (U.richText mit marks/mentions)  |  ul.para-list  |  figureCard/tableCard
│       │   ├── div.para-cats > button.pc-cat[.off][data-cat]* (span.dot + Label)
│       │   └── div.para-hint („▸ N Belege — x belegt · y Original · z vermutet · <p.id>")
│       │       └── span.edit-badge (chip „✎ bearbeitet" + a「↺」) · button.sc-flag(„🤖 N")
│       └── div.resolution (nur offen)
│           ├── div.belege > eyebrow „Belege in diesem Absatz" + btn「⌖ Große Ansicht」
│           │   └── div.beleg[.sel][data-fn]* (s. 4.6)
│           └── div.mentions > eyebrow „Quellen-Erwähnungen im Text" + div.mention-row*
└── sectionNav (← 3.1 / 3.3 →)
```
`para-row` ist Grid `minmax(0,1fr) minmax(0, var(--ps-w, min(300px,34cqw)))` (app.css:1490); Karte und Fenster teilen sich die Naht (Karte ohne rechten Rand/Radius). Unter 999px stapeln sie (app.css:1525-1526).

### 4.4 Quellen-Spalte (`renderFilePane`, :1288-1312)

```
aside.studio-file (flex-col, sticky, volle Höhe)
├── div.sf-bar
│   ├── button.sf-srcbtn[data-sf=pick] > span.sfb-ic(Kind-Icon) span.sfb-name(Kürzel) span.sfb-caret「▾」
│   ├── 2× span[flex:1]
│   ├── button.sf-iconbtn[data-sf=big]「⤢」  („Große Ansicht")
│   └── button.sf-iconbtn[data-sf=collapse]「⇥」
├── div.sf-host (flex-col, surface-2)
│   ├── div.sf-card   ← PdfEngine.assignPanel (Quell-Karte, collapsed wenn Datei da)
│   └── div.sf-view   ← PdfEngine.mount (PDF) | renderDocView | „Lade Datei …" | Fehlertext
├── div.sfd-resize (7px, row-resize, Naht ÜBER dem Dock)
└── div.sf-dock[.closed][.sized]
    ├── div.sfd-tabs > select.sf-fn (Fußnoten-Dropdown) + span.sfd-fn-slot (Farbe+↺) + button.sfd-min「▾/▸」
    └── div.sfd-body  ← renderFileDock:
        ├── div.sfd-ki.l<level> (getönt): p.db-claim(„Was belegt wird: …") · div.sfd-fnrow(blockquote.sfd-fnq „Fußnotentext" + ✎/↺) · p.sfd-vermutet · div.sfd-such(sw-chips)
        └── div.bcheck.l<level> (Checkliste ⌖ Beleg-Nachweis, 3 Zeilen: 📍 Seite/Fundstelle · ❝ Zitat · 🖍 Markierung, Zähler „n/3")
```
Ohne Belege: nur `sf-bar` „▣ Quellen" + `.sf-empty`-Hinweistext (:1272-1275). Dock: `max-height: 38%` default, gezogen bis 72% (`--sfd-h`); Ziehen unter 110px Höhe klappt automatisch zu (:1457-1466).

### 4.5 Views-/Instanz-Leiste (`instanzBar`, :646-679)

```
div.inst-bar.row[role=group]
├── span.eyebrow „Views"
└── span.dock-switch
    ├── button[data-idock=none][.active] „∅ Ohne"
    ├── button[data-idock=<id>][.active][style=--inst-c:<color>]* > i.inst-dot + Label
    └── button[data-iact=edit] „✎"
```

### 4.6 Beleg-Zeile (`belegRow`, :1033-1130)

```
div.beleg[.sel][data-fn][tabindex=0][role=button]
├── div.b-head > span.num(Levels.dot + „[n]") · Levels.badge · button.chip.mini.mark-chip(„🖍 S. n"/„🖍 N") · span.srcs(a-Links „Kürzel · Kürzel") · span.acts > btn-primary „Prüfen"
├── div.claim (Aussage; title erklärt Doppelklick)
├── div.ki-line > span.br-vermutet(„vermutet <b>Fundstelle</b>")
├── div.ki-line.b-such > button.sw-chip.all「⧉」 + button.sw-chip(„🔎 <Begriff>")*
├── div.ki-line.b-ment („❞ im Text <snippet> — zeigt auf diesen Beleg" + btn-ghost「↺」)*
├── div.fund-stelle (Level≥2: „✓/❝ S. n <Fundstelle> „Zitat…"" + chip(herkunft))
└── div.span-ctl (nach Doppelklick): „Belegte Textspanne:" b.sc-n + „+ Satz davor" „− Satz" 「✕」
```

### 4.7 Referenzierungsmodus (`openRefMode`, :1721-1736)

```
div.refmode[role=dialog][aria-modal=true]   ← Vollbild-Overlay, body.overflow:hidden
├── div.ref-head: eyebrow「⌖ Referenzierung」· b(„Absatz <id>") · mut(Abschnittstitel) · flex · Hinweis „Im PDF Text markieren → Zitat + Seite landen im aktiven Beleg" · btn#refSide「⇔ Panel」 · btn#refClose「✕ Schließen」
└── div.ref-body (Grid: var(--ref-w,360px) 7px minmax(0,1fr))
    ├── aside.ref-side
    │   ├── details.ref-ctx > summary „Absatztext" + div.txt
    │   └── section.ref-src[.active][data-src]* (je Quelle)
    │       ├── header: span.dot b(Kürzel) chip(Kind) flex Levels.bar
    │       └── div.ref-item[data-fn][.focus]*   (s. Zitierelement)
    ├── div.pane-resize
    └── main.ref-main
        ├── div.ref-pdfbar: U.srcStripHtml · btn#refDossier「📚」 · flex · Tabs 「📄 PDF」「☰ Text」[「§ Register」] · [a「↗」] · btn#refTab「↗ Tab」[hidden] · btn#refFile「Datei …」
        └── div.ref-pdfhost#refHost (PDF-Engine | Text-Pane | Register | assignPanel | iframe-Fallback)
```
Zitierelement `ref-item` (:1828-1844): `ri-head` (dot, `[n]`, badge-slot, farb-slot, flex, btn `✥ aktiv`), optional `ri-claim`, `ri-fntext` („…"-gefasst, Suchwörter mit `<mark class="sw">` markiert), `br-vermutet` („✦ vermutet"), `ri-such` (⧉ alle + 🔎-Chips), `textarea.ri-zitat` (Placeholder „Zitat — im PDF markieren oder hier einfügen …"), `ri-foot` (bei Seiten-Typ: `label „S." input[type=number] + btn「→ Seite」`; sonst `input` „Fundstelle: Art/§ …"; immer btn-primary `✓ Speichern`).

### 4.8 `#/doc` (renderDoc, :451-490)

`div.page-head(h1+p.page-sub)` → `div.doc-wrap` → `div.doc-actions.no-print` (3 Buttons + Hinweis) → `instanzBar` → `div.lesen-doc` mit **allen** Kapiteln (immer `lesenSection`, keine Kompakt-Variante).

---

## 5. Design-Rohwerte

### Icon-Zeichen (exakt, Unicode)
- Modi: `☰ Lesen` · `◉ Analyse` · `✎ LaTeX` (:17). (Im Header-Kommentar noch „⌖ Prüfen" — die sichtbaren Labels sind die aus `Studio.MODES`.)
- Einklappen/Rails: `⇤` (nach links / Quellen zurück), `⇥` (nach rechts / TOC zurück) (:107, :115, :216, :1273, :1298).
- Baum: Caret `▸` (rotiert 90° bei open, CSS), Umbenennen `✎`, Intro-Kennzeichen `·` (:239).
- Dichte-Leiste: `Normal` `Kompakt` `🖍` `⚡` (:155-158).
- Beleg/Quelle: `⌖` (Beleg/Große Ansicht), `❝` (Zitat), `❞` (Erwähnung bestätigt/merged), `✦` (KI/offen), `✓`, `✗`, `↺` (zurücksetzen), `🖍` (PDF-Markierung), `📍` (Position), `🔎` (Suchen), `⧉` (kopieren), `✔` (kopiert), `📚` (Dossier), `↗` (extern/Tab), `▾`/`▸` (Dock zu/auf), `⤢` (Große Ansicht), `⇔` (Panel), `✥ aktiv`, `✕`/`×` (schließen).
- Views: `∅ Ohne`, `⚡ Schnelllesen`, `⤳ Connections`, `◘ Quelle`, `🌐 Übersetzung`, `✎ Erklärung`, `✦ Analyse`, `◻ Ohne` (Legacy-ID `clear`), `Σ` (LaTeX-Material), `➕`, `↻` (Recompile), `🗑` (löschen), `⏳` (lädt), `🔑` (Zugang), `🎛` (Instanzen-Dock, nur Textverweis).
- Doc-Aktionen: `⭳ Ganzes LaTeX (.tex)`, `🖨 Als PDF drucken`, `◱ LaTeX ansehen` (:461-463).
- Sonstiges: `🤖` (Stil-Check), `🖼 Abbildung`, `▦ Tabelle`, `📄` (Fallback-Kind-Icon), `▣ Quellen`, `▤` (Gesamtdokument, Kommentar :448).

### Inline-Farben im JS
- Fallback-Markierungsgelb `#e8c33f` (:1631 Checklisten-Dot, :2062 Text-Highlight).
- Graph-Kantenfarben (`sideGraph`, :2299): `folgerung: var(--accent-ink)`, `grundlage: var(--good)`, `aufgriff: var(--cat-frist)`, `vergleich: var(--cat-akteur)`, `fazit: var(--cat-tech)`, `quellen: var(--cat-norm)`, `xref: var(--muted)`.
- View-Farben (`DOCK_DEFAULTS`, :2127-2135): schnell `var(--cat-frist)`, connections `var(--accent-ink)`, srcview `var(--cat-norm)`, uebersetzung `var(--cat-norm)`, erklaerung `var(--good)`, analyse `var(--cat-akteur)`.
- Kategorie-Chips: `--c: var(--cat-<kat>)` (:743). Instanz-Buttons: `--inst-c: <color>` (:655). Fenster-Akzent: `--ps-accent` (:2239). Alle konkreten Hex-Werte leben im CSS-Token-System (base.css) — nicht in dieser Datei.
- Inline-Font im Modal: `font-family:var(--font-mono);font-size:11.5px` (Textarea LaTeX-Ansicht, :473); `min-height:340px`.

### Wichtige deutsche UI-Texte (wortwörtlich, Auswahl der laufend sichtbaren)
- „☰ Inhaltsverzeichnis" (:215); Tooltips „Baum-Breite ziehen · Doppelklick = Standard" (:78), „Breite der Quellen-Spalte ziehen · Doppelklick = Standard" (:91), „Inhaltsverzeichnis nach links einklappen" (:216), „Quellen-Spalte einblenden" (:107), „Inhaltsverzeichnis einblenden" (:115).
- Dichte-Tooltips: „🖍 Markierungen im Lesen-Modus dezent ein-/ausblenden" (:157), „⚡ Schnelllese-Anstrich: Markierungen voll ausgemalt — auch hier im Lesen-Modus" (:158).
- „Kapitel {n} · {Titel}" · „Original-PDF S. {n} ↗" (:197-198).
- Absatz-Hint: „▸ {N} Beleg(e) — {x} belegt · {y} Original · {z} vermutet" / „Keine Belege in diesem Absatz" (:759-761).
- „Belege in diesem Absatz" + „⌖ Große Ansicht" (Tooltip „Große Ansicht: Zitierelemente links, PDF mit Markierungen rechts") (:938-939); „Keine Belege in diesem Absatz." (:944); „Quellen-Erwähnungen im Text" (:962).
- Erwähnungen: „**Erkannt:** „{snippet}" → {Quelle} — im Text genannt, ohne Fußnote" · „bestätigte Erwähnung" · „mit Beleg [n] zusammengeführt … Fußnote nicht in dieser Liste" · „verworfen: „…"" (:979-982); Buttons „⇒ Beleg [n]", „Prüfen", „✓ Bestätigen", „✗", „↺" (:985-990).
- Edit: „✎ Bearbeitung · <kbd>Esc</kbd> fertig" (:795), Chip „✎ bearbeitet" + „↺" (Original wiederherstellen) (:842).
- Spannen-Steuerung: „Belegte Textspanne:" · „+ Satz davor" · „− Satz" · „{n} Satz/Sätze bis [n]" · „kein Absatztext markierbar" (:1155-1163).
- Quellen-Spalte leer: „Dieser Abschnitt hat keine Belege — sobald Zitierstellen existieren, steht hier das PDF der Quelle als Hauptanker: markieren übernimmt Zitat + Seite in den aktiven Beleg." (:1274-1275); „Lade Datei …" (:1356); „Die Markier-Engine konnte dieses PDF nicht rendern — „↗ Tab" auf der Quellenseite nutzen." (:1399).
- Dock: „Kein Beleg gewählt — diese Quelle ist (noch) nur als Erwähnung im Text referenziert." (:1505); „Was belegt wird:" (:1530); „Vermutete Stelle" (:1538); Checkliste „⌖ Beleg-Nachweis", „{n}/3", Zeilen „Seite"/„Fundstelle (Art/§)"/„Zitat"/„Markierung im PDF", Placeholder „fehlt — S. eintragen", „fehlt — z. B. Art 9 Abs 2 / § 22 Abs 4", „fehlt — Originalpassage (oder im PDF markieren)", „keine — im PDF markieren", „S. {n} →" (:1614-1632).
- Ref-Modus: „⌖ Referenzierung", „Absatz {id}", „Im PDF Text markieren → Zitat + Seite landen im aktiven Beleg", „⇔ Panel", „✕ Schließen", „Absatztext" (:1722-1729, :1756).
- Views-Leiste: „Views", „∅ Ohne — die normale Ansicht", „✎" (Tooltip „Views verwalten: neue View mit KI erstellen, recompilen, löschen") (:650-656). Fenster leer: „— leer — Doppelklick und einfach losschreiben (oder 🤖 Prompt in der Instanz-Leiste)" (:2251). Chips „✦ auto" / „✎" (:2250).
- Views-Modal (:2367-2386): Titel „✎ Views verwalten"; „➕ Neue View — die KI füllt sie aus dem LaTeX"; Placeholder „Name (z. B. „Kritik", „Beispiele")", „Auftrag je Absatz (z. B. „Nenne je Absatz ein konkretes Praxisbeispiel, 1–2 Sätze")"; „➕ Erstellen & Generieren"; „↺ Standard"; „Fertig"; Confirm-Texte :2420, :2445.
- `#/doc` (:453-464): Untertitel „— die ganze Arbeit als ein Dokument: komplettes LaTeX generieren oder direkt als PDF drucken."; Hinweis „Kompilierbares LaTeX (report-Klasse, Präambel + Titel + alle Abschnitte) — oder direkt PDF."
- Text-Pane (:2035-2043): „Noch kein Text hinterlegt", „.txt laden", „… oder Text hier einfügen", „Text übernehmen"; aktiv: „aktiv: **[n]** — Auswahl im Text wird diesem Beleg als Zitat zugeordnet" / Warnung „Kein Beleg aktiv — links einen Beleg wählen, dann Text auswählen." (:2081-2082).
- Stil-Check-Modal (:626-628): „Deterministische Heuristik (ohne KI): Floskeln, vage Einordnungen, Konnektor-Ketten, wertende Sätze ohne Beleg oder Konkretes. Ein Hinweis zum Selbst-Redigieren — kein Urteil."

---

## 6. Verhalten & Interaktionen

### Routing & Aufbau
1. `renderStudio(root, sectionId, mode, focusPara)` (:40): ungültige ID → `studioLast` → erste Unit. Gültiger Modus wird persistiert. Alte PDF-Controller/Panels werden zerstört, alle 4 Custom-Highlights geleert (`beleg-span`, `gpt-style`, `src-view`, `src-view-strong`, :51-54). Danach Layout, Bar, Header, Modusinhalt, ggf. `renderFilePane`, dann Scroll-Restore (:136-137).
2. `routeRefresh()` (:140): kompletter Re-Render **ohne** URL-Änderung (State-Wechsel wie Dichte, Kategorien, Views).

### Modus-Leiste
- Modus-Tabs sind **Links** auf `#/studio/<id>/<modus>`; vor Navigation wird `Studio._scroll[mode|sectionId] = scrollY` gesichert (:164-166).
- Dichte-/🖍/⚡-Buttons togglen State + persistieren + `routeRefresh` (:167-180).

### Kapitelbaum
- Kapitel-Button togglet `ul.hidden` + `.open` (Caret-Rotation) (:246-250); aktives Kapitel initial offen (:230).
- `✎`-Umbenennen (Delegation, Klick + Enter/Space, :256-265): Titel-Span wird durch `input.tree-edit` ersetzt; Enter/Blur = speichern (`titleEdits` + `rebuildDataIndexes` + `routeRefresh`), Esc = verwerfen, leeres Feld = Original zurück (:272-300).
- Fortschritts-Punkt je Abschnitt (`progDots`, :302-308): alles belegt → `lvl-dot l3` („alles belegt"), teils → `l2` („teilweise geprüft"), sonst `l1` („nur KI-vermutet").

### Lesen-Modus
- Abschnittsweise fortlaufender Text; `⚡`/`🖍` steuern `showMarks` (:409); View „Ohne (clear)" unterdrückt alles; nur **bestätigte/merged** Erwähnungen werden gerendert (:435). Text-Views erscheinen als `lesen-inst`-Block unter dem Absatz, nur wo Inhalt existiert (:404-408).
- Kompakt: Kernaussagen-Liste; Klick auf Zeile → Dichte normal + `location.hash`-Sprung (:506-511).
- Kapitel-Navigation unten (← Kapitel n / Kapitel n →) springt zum jeweils **ersten** Abschnitt mit Absätzen (:376-382).

### Prüfen-Modus / Absatzkarte
- **Klick** auf `para-body` (nicht auf `fn-chip, a, button, input, textarea, .fig-img, mark.hl, .mk-src`; nicht bei `e.detail>1`): `toggleParagraph` — öffnet/schließt `.resolution` (Belege + Erwähnungen); beim Schließen wird `beleg-span`-Highlight geleert (:767-772, :902-911). Enter/Space gleichwertig.
- **Doppelklick** auf Textabsatz: `paraEditStart` (:790) — `contentEditable='plaintext-only'` (Fallback `'true'`), Rohtext mit `[^n]`-Markern, Hint „✎ Bearbeitung · Esc fertig". **Esc oder Blur = übernehmen** (kein Verwerfen!). Whitespace wird normalisiert (:805). Bei Änderung: `paraEdits`-Override, `Editor.saveEdit(sectionId, Editor.reconstruct(sectionId))` (LaTeX-Sync), `Mentions._paraCache.delete(p.id)` (:812-822). Danach `refreshParagraphText` + `paraEditBadge`.
- **Kategorie-Chips** unter dem Text: Klick togglet Kategorie global (Set + `cats`-Store) und aktualisiert **alle** Karten + Chips live ohne Re-Render (:744-750).
- **Beleg-Zeile**: Klick irgendwo (außer Controls) = `selectBeleg` → `.sel`-Markierung, Satzspannen-Highlight im Absatz, `fileShow` rechts (:1040-1046, :1187-1194). **Doppelklick** = `openSpanCtl`: Spannen-Steuerung „+ Satz davor / − Satz / ✕", persistiert via `U.setSpanBack(fn, n)` (:1124-1128, :1151-1183). 🔎-Chips: Beleg aktivieren, dann Polling (20×200ms) bis `Studio.file.ctl.search` bereit, dann PDF-Suche (:1086-1095). ⧉ kopiert alle Suchbegriffe („✔" für 900ms).
- **Erwähnungen** (`drawMents`, :957-1023): Status-Maschine `offen → bestaetigt | verworfen`, `offen/bestaetigt → beleg` (Merge auf Fußnote gleicher Quelle via `Mentions.mergeTarget`), alle mit ↺ zurück. Mehrdeutige Kandidaten → `select.m-cand`, Wechsel zeichnet Zeile neu (Merge-Ziel hängt an Auswahl, :995). Zeilen-Klick/Enter = „Prüfen" (`fileShow` mit erster Fußnote der Quelle, :996).
- Nach Level-Änderungen: `refreshResolution` auf allen offenen Karten + `Studio.file.drawDock` (:1646-1650).
- **focusPara** (Deep-Link): Karte öffnen, `.jump-flash`-Klasse (2400ms), `scrollIntoView({block:'center'})` (:563-571).
- Aktiver Beleg überlebt Moduswechsel: Karte seiner Fußnote wird nach Render wieder geöffnet (:555-560).
- **Stil-Check** (wenn `uiStyleCheck`): Highlight `gpt-style` über alle auffälligen Sätze (Custom-Highlight-API; ohne Support nur 🤖-Zähler) (:610-623); 🤖-Chip → Modal mit Sätzen + Treffer-Chips (:625-633, :859-867).
- **◘ Quelle-View** (`applySrcView`, :581-606): markiert satzgenau alle Sätze, deren Fußnoten die aktive Quelle enthalten — Highlight `src-view`, „nachgeschärft" `src-view-strong` wenn Zitat erfasst oder PDF-Markierung existiert.

### Quellen-Spalte
- Quelle bestimmen (:1259-1267): `Studio.sel` hat Vorrang; sonst gemerkte Quelle; sonst erste des Abschnitts.
- `mount()` (:1348-1403) ist async mit **Generation-Token** `Studio.file.gen` gegen Races: nur der jüngste Aufruf darf den DOM übernehmen; verspätete Controller werden sofort zerstört (:1349, :1358, :1366, :1397).
- Quell-Karte via `PdfEngine.assignPanel` — eingeklappt wenn Datei/Definition vorhanden (:1361-1365); ohne PDF: `renderDocView` (Internetquelle/Bild) oder leer; `sf-host.no-view` lässt die Karte die ganze Fläche füllen (:1360, app.css:478-479).
- PDF-Markieren: `getActive()` liefert `{fn, farbe, label}`; `onCapture({text,page,fn})` speichert `Levels.save(fn, {zitat, seite, herkunft:'manuell'})` (Seite nur bei `positionType==='seite'`) und aktualisiert Dropdown/Dock/offene Karten (:1379-1395).
- Fußnoten-Dropdown: Wechsel setzt `Studio.file.fn` + `Studio.sel`, `refreshActive`, `goto(startPage)`, Dock neu (:1416-1422). `startPage`: erste PDF-Markierung der Fn, sonst `Levels.info(fn).seite`, sonst 1 (:1331-1335).
- `⤢` öffnet den Ref-Modus mit aktueller Quelle/Fn (:1423-1426). `⇥` klappt ein und zerstört Controller (:1428-1435). `▾/▸` togglet Dock (Icon wechselt, :1438-1443). Dock-Höhe per Naht ziehbar (axis y, dir -1); unter 110px → auto-zuklappen + Höhe verwerfen (:1451-1467).
- Dock-Inhalt (:1498-1596): Slot in der Tab-Zeile trägt `farbControl` (Farb-Punkt mit Popover: „A auto" + `Levels.FARBEN`-Swatches, :326-355) + „↺"-Reset (nur wenn `Levels.entry` existiert). Fußnotentext inline editierbar (✎, contentEditable, Esc/Blur speichert Override via `U.setFnEdit`, ↺ Original, :1545-1572). Checklisten-Inputs speichern bei `change` (Enter = blur) (:1635-1642). `bc-mark`-Buttons springen im PDF auf die Seite (:1591-1595).
- `fileShow` (:1479-1493): setzt `Studio.sel` + `Studio.file.*`; in „lesen" → nur Hash-Wechsel auf „pruefen" (Render nimmt Auswahl auf); sonst Spalte ggf. aufklappen + `renderFilePane`.

### Referenzierungsmodus (Vollbild)
- Öffnen (:1704): Overlay an `document.body`, `body.overflow='hidden'`, `keydown`-Listener für **Esc** (schließt nur, wenn kein `.modal-back`/`.cmdk-back` darüber, :1781-1786). Schließen: Engine zerstören, Overlay entfernen, offene Karten refreshen (:1788-1797).
- Aktiver Beleg: `refSetActive` (:1800) markiert `.focus`, `refreshActive` der Engine, springt automatisch zur Markierungs-/Beleg-Seite. `focusin` auf einem Item aktiviert es (und wechselt ggf. die Quelle) (:1902-1905).
- PDF-`onCapture` schreibt Zitat + Seite **in das Formular** des Items und speichert sofort via `item._refSave()` (:2009-2016).
- Rechts 3-4 Ansichten pro Quelle (`refShowSource`, :1925): `pdf` (Engine, iframe-Fallback :2020-2025), `text` (`renderSrcTextPane`), `register` (nur Rechtsquellen `recht-eu`/`recht-at`: Fundstellen-Register max. 18 Zeilen + Link Quellenseite, :1982-1993), `datei` (transient: `assignPanel`). Ansicht je Quelle gemerkt in `RefMode.views`; Auto-Wahl: PDF > Text > Register(Recht) > PDF (:1940-1943).
- „☰ Text": Text-Auswahl per `mouseup` (≥3 Zeichen, whitespace-normalisiert) → Zitat des aktiven Belegs + Auto-Save + Auswahl aufheben (:2094-2108). Erfasste Zitate werden im Text farbig vor-markiert (`mark.st-hl`, whitespace-tolerantes Regex, nur erster Treffer, :2057-2068). „✎ Text bearbeiten" leert den Text und befüllt das Setup-Textarea nach 50ms mit dem Backup (:2086-2092).
- Suchwort-Hervorhebung in Claim/Fußnotentext: `markWords` — Wörter ≥4 Zeichen aus `suchHinweis`, längste zuerst, case-insensitive, `<mark class="sw" style="--swc:<hex>">` (:1910-1920).

### Views/Instanzen
- Leisten-Klick: setzt `Studio.dock` global, **leert `dockBySection`**, sichert Scroll, re-rendert (Kontext-abhängig `#/doc` oder Studio) (:661-676).
- `dockModeFor(sectionId)`: Abschnitts-Override > global (:2177-2180). `×` am Fenster schließt **nur diesen Abschnitt** (`dockClose`: `null`-Override bzw. Löschen des Eintrags, :2201-2207).
- Fenster: Doppelklick = Markdown-Rohtext editieren (contentEditable, Esc/Blur übernimmt); unverändertes Auto zählt nicht als Edit (:2257-2289). Chips: „✦ auto" (nur Auto-Inhalt) / „✎" (gespeichert).
- ⤳ Connections-Fenster (:2296-2337): Kernaussage + max. 6 absatz-eigene Kanten; beim **ersten** Absatz zusätzlich „Abschnitt gesamt" (dedupliziert, max. 8). Kanten sind Links `#/studio/<other>/pruefen` mit Typ-Icon + Richtungs-Label + optionalem Label (52 Zeichen).
- Views-Verwaltung (:2360-2452): Name/Auftrag/Σ speichern sofort (`input`/`change`); ↻ Recompile ruft `viewGenerate` (Claude direkt; Demo-Modus zeigt nur Kosten-Modal; Antwort via `Enhance._importInst`; Button zeigt ⏳/Token-Zahl/✓, :2458-2480); 🗑 mit `confirm`; ➕ legt View an (`id` = slugifizierter Name, max 40 Zeichen, :2433) und startet sofort Generierung wenn Claude bereit; ↺ Standard mit `confirm` setzt `instDefs=null` und wischt Inhalte eigener Views.

### `#/doc`
- „⭳ Ganzes LaTeX" → `U.download('thesis.tex', Editor.fullDocument(), 'text/x-tex')` (:467); „🖨" → `window.print()` (Print-CSS blendet Chrome aus); „◱ LaTeX ansehen" → Modal mit Textarea (KB-Angabe), ⧉ Kopieren („✔ kopiert"), ⭳ laden (:469-477).

### Animationen/Transitions (CSS-seitig, hier ausgelöst)
- `.jump-flash` 2400ms auf Karten (:568-569); Caret-Rotation `.13s`; Mode-Switch-Hintergrund `.12s`; Rail-Hover `.12s`; sw-chip „✔"-Feedback 900-1000ms; `body.resizing` deaktiviert Transitions beim Ziehen (app.css:1100).

---

## 7. Datenformen

```jsonc
// Studio.genFor(sectionId) → window.DATA_SECTIONS[fileIdOf(sectionId)] — Voranalyse je Datei
{
  "paragraphs": [{
    "id": "p-3.2-4",
    "kernaussage": "Der EHDS schafft erstmals …",           // Kompakt-Lesen + Connections-Fenster
    "uebersetzung": "…",                                     // dockAuto('uebersetzung')
    "sentences": [{
      "text": "Der EHDS … [^12]",                            // mit Fußnoten-Markern
      "einfach": "Einfacher Satz.",                           // dockAuto('erklaerung')
      "marks": [{ "snippet": "EHDS", "kategorie": "abk" }]    // Schlüsselstellen (CAT_ORDER-Kategorien)
    }],
    "belege": [{
      "num": 12,                        // Fußnotennummer
      "quellen": ["Vallejo2022"],       // Quellen-IDs (Fallback: FN_INDEX[num].sources)
      "claim": "Was belegt wird …",
      "fundstelle": "Kap. 3, S. 45-48", // KI-Vermutung
      "suchHinweis": "health data space secondary use"
    }]
  }]
}

// Absatz p (UNIT_INDEX[id].unit.paragraphs[i])
{ "id": "p-3.2-4", "type": "text|list|figure|table", "text": "… [^12] …",
  "items": ["…"], "footnotes": [{ "num": 12, "sources": ["Vallejo2022"] }] }

// Mentions.forPara(...) → Erwähnung
{ "key": "p-3.2-4|vallejo|2022", "snippet": "Vallejo (2022)", "srcId": "Vallejo2022",
  "status": "offen|bestaetigt|verworfen|beleg", "fn": 12,
  "candidates": [{ "srcId": "Vallejo2022" }, { "srcId": "Vallejo2021" }] }

// Levels.info(fn)
{ "level": 1, "zitat": "„…"", "seite": 45, "fundstelle": "Art 9 Abs 2",
  "farbe": "gelb", "herkunft": "manuell" }

// U.belegSpan(...) → { "text": "Satz1 Satz2", "from": 2, "to": 3 }

// PdfEngine.marksForFn(srcId, fn) → [{ "page": 45, "farbe": "gelb", … }]

// View-Definition (DOCK_DEFAULTS / instDefs / PROJECT_INSTANZEN.defs)
{ "id": "erklaerung", "label": "✎ Erklärung", "color": "var(--good)",
  "desc": "Eine EINFACHE ERKLÄRUNG (2–4 Sätze, deutsch) …",
  "special": false, "project": false, "srcTex": "Vallejo2022" }

// window.PROJECT_INSTANZEN
{ "defs": [{ "id": "kritik", "label": "🗯 Kritik", "color": "#c05f5f" }],
  "items": { "kritik": { "p-3.2-4": "**Markdown** je Absatz" } } }

// KI-Antwortformate (verlangt in Prompts)
{ "sectionId": "3.2", "items": { "p-3.2-4": [{ "snippet": "wörtlich", "kategorie": "norm" }] } }  // marksPromptFor :700-701
{ "instanzen": { "erklaerung": { "p-3.2-4": "<markdown>" } } }                                     // instanzPromptFor :2516

// Connections.forSection(id) → { "out": [{ "typ": "folgerung", "von": {"paraId": "p-…"},
//   "nach": {"sectionId": "4.1"}, "label": "…" }], "in": [ … ] }
```

---

## 8. Abhängigkeiten

**Dieses Modul ruft auf**: util.js (`U.*` massiv), levels.js (`Levels`), mentions.js (`Mentions`), pdfengine.js (`PdfEngine`), pdfstore.js (`PdfStore`), editor.js (`Editor.fullDocument/saveEdit/reconstruct`, `renderEditorPane`), connections.js (`Connections`), stylecheck.js (`StyleCheck`), claude.js (`ClaudeAI`), enhance.js (`Enhance._importInst`), figures.js (`figureCard`, `tableCard`), app.js/Daten-Layer (`UNIT_INDEX`, `FN_INDEX`, `SRC_BY_ID`, `FIG_BY_PARA`, `TAB_BY_PARA`, `CAT_*`, `KIND_*`, `orderedUnits`, `fileIdOf`, `rebuildDataIndexes`, `provisionRegister`), window-Daten (`DATA_SECTIONS`, `DATA_THESIS`, `DATA_SOURCES`, `PROJECT_INSTANZEN`).

**Dieses Modul wird aufgerufen von**: app.js (Router: `renderStudio`, `renderDoc`; `fileShow` bei Klick auf `.mk-src`-Markierung im Prüfen-Modus; `renderDetailPdf._ctl`-Cleanup), views_quellen.js (`renderDetailPdf`), editor.js (`sourcePickerModal`), enhance.js (`marksPromptFor`, `instanzPrompt`, `routeRefresh`, `dockDefs`, `sectionSources`, `Studio.styleCheck`, `Studio.file.srcId`), views_analyse.js (`dockDefs`, `dockGet`, `dockAuto`).

Zyklen: Studio ↔ Enhance (Studio liefert Prompts/State, Enhance importiert und ruft `routeRefresh`), Studio ↔ Editor (Doppelklick-Edit ruft `Editor.saveEdit`; Editor-Modus rendert in Studios Gerüst).

---

## 9. Flutter-Hinweise

1. **Architektur**: `Studio` + localStorage-Keys → ein `StudioState` (Riverpod `Notifier`), persistiert projekt-gescopt (wie `U.storeGet`). `routeRefresh` entfällt — deklaratives Rebuild ersetzt den DOM-Neuaufbau; **aber** die Semantik „View-Wechsel setzt `dockBySection` zurück" und „Scroll je `mode|sectionId` merken" muss explizit nachgebaut werden (Map `ScrollController`-Offsets; Restore per `jumpTo` nach erstem Frame ≈ `requestAnimationFrame` :137).
2. **3-Spalten-Layout**: Grid mit CSS-Vars → `Row` mit fixen Breiten (State `treeW`, `fileW`) + `Expanded` Mitte; Resize-Griffe als 7px `MouseRegion(SystemMouseCursors.resizeColumn)` + `GestureDetector` (Pan), Doppelklick = Standard, Klemmen gegen Viewport (min/max wie :83, :99 und die CSS-Caps 26vw/50vw). Einklappen = Spalte aus dem Row-Children nehmen; Rand-Leisten als `Positioned`-Overlays mit `RotatedBox` für vertikalen Text. Breakpoint < 1000px: Spalten-Stapel (`ListView`), Griffe weg, Quellen-Spalte feste Höhe `min(78vh, 760px)`.
3. **Sticky-Verhalten**: `studio-bar` sticky → im Scrollbereich als pinned `SliverPersistentHeader` (Mitte-Spalte ist der Haupt-Scroller — im Original scrollt das **window**, nicht die Spalte; in Flutter besser: Mitte scrollt, TOC/Quellen-Spalte sind eigene, volle Höhe belegende Panels — das entspricht optisch dem Sticky-Original).
4. **Custom-Highlight-API** (`beleg-span`, `gpt-style`, `src-view`, `src-view-strong`) gibt es nicht in Flutter — stattdessen `TextSpan`-Komposition: Satz-/Phrasen-Ranges im Absatztext berechnen (Logik aus `U.domRangeFor`/`U.belegSpan` portieren) und als Hintergrund-Spans rendern. Der „ohne Support: echte Text-Auswahl"-Fallback (:1142-1146) entfällt.
5. **contentEditable-Editing** (Absatz :790, Fußnotentext :1545, View-Fenster :2257): jeweils `TextField`, das die gerenderte Ansicht in-place ersetzt (gleiche Schrift/Größe für den „maximal smooth"-Effekt). Wichtig: **Esc UND Fokusverlust = übernehmen** (kein Cancel!), nur Baum-Umbenennen hat Esc=verwerfen (:296). `plaintext-only` ist in Flutter der Normalfall.
6. **PDF-Viewer + Markieren** ist die härteste Stelle: `PdfEngine.mount` mit `getActive/onCapture/onMarksChange/search/goto/refreshActive` braucht ein Pendant (z. B. `pdfrx`/`syncfusion_flutter_pdfviewer` mit Text-Selektion → Callback `onCapture(text, page)`); das Generation-Token-Muster (:1348-1366) → in Flutter Abbruch über verworfene Futures/`mounted`-Checks.
7. **Ref-Modus** = Vollbild-`Dialog`/`Navigator`-Route mit eigenem Split (Resizable), Esc via `Shortcuts`; „nur schließen wenn kein Modal darüber" ergibt sich in Flutter gratis über den Navigator-Stack.
8. **Popover/Modals**: `farbControl`-Popover (:340-352, close-on-outside-click) → `MenuAnchor`/`OverlayPortal`; `U.modal`-Dialoge → `showDialog`; `confirm()`/`alert()` (:2420, :2435, :2445) → eigene Dialoge.
9. **U.richText** (Marks, Mentions, Fußnoten-Chips, xrefs) ist der zentrale Text-Renderer — als eigener `TextSpan`-Builder mit tappbaren Spans (Fußnoten-Chip → Beleg, `mk-src` → `fileShow`, xref → Navigation) nachbauen; Kategoriefarben als Theme-Tokens (`--cat-*` aus base.css übernehmen).
10. **Polling-Hack** (:1090-1094, 20×200ms auf `ctl.search`) nicht kopieren — in Flutter auf das Mount-Future warten und dann suchen.
11. **`#/doc` Drucken**: `window.print()` → `printing`-Package (PDF aus demselben Absatz-Renderer erzeugen); Print-CSS-Äquivalent = eigene Print-Layout-Funktion.
12. **Nicht 1:1 portierbar**: CSS Container-Queries (`34cqw` Fensterbreite), `backdrop-filter` der Bar (→ `BackdropFilter`), `writing-mode: vertical-rl` (→ `RotatedBox`), `scrollIntoView`-Anker (→ `Scrollable.ensureVisible`/`GlobalKey`s je Abschnitt), `CSS.escape` (entfällt).
13. **Reihenfolge-Effekte beachten**: `selectBeleg` → `fileShow` → in „lesen" nur Hash-Wechsel, Auswahl wird vom nächsten Render „aufgenommen" — in Flutter als expliziter State (`pendingSelection`) modellieren. Ebenso „aktiver Beleg öffnet seine Karte nach jedem Render wieder" (:555-560).

---

*Quellen: /home/user/thesoR/js/views_studio.js (vollständig), /home/user/thesoR/css/app.css:160-530, 1100, 1290-1300, 1489-1526 (Layout-Verifikation), Cross-Referenzen via grep über /home/user/thesoR/js.*
